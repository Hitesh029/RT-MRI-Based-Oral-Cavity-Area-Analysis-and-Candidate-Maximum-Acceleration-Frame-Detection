%% main_all_frames.m

% Run the established C1/C2 detection solution on every MRI frame

% and display each result sequentially in one figure.

%

% Required project functions:

% loadData, preprocessData, identifyC1, identifyC2,

% findC1Start, findC2Start, findC1End, findC2End,

% validatePoints, saveResults

clear; clc; close all;

%% CONFIGURATION

matFileName = 'M2_034_temp.mat';

matFilePath = fullfile(pwd, matFileName);

frameDelay = 0;                 % display delay only; NOT MRI temporal resolution

tolerancePx = 3.0;

% ================================================================

% TEMPORAL / KINEMATIC CONFIGURATION

% ================================================================

% IMPORTANT: set dt to the ACTUAL MRI time between consecutive frames

% (seconds/frame). Do NOT use frameDelay for dt.

% Example only: if MRI acquisition is 100 frames/s, dt = 1/100.

dt = 1;

% ================================================================
% PHONEME / PRONUNCIATION CONFIGURATION
% ================================================================
% 034.txt contains phoneme timing intervals, not word boundaries.
% Therefore this code can identify the phoneme at the selected MRI frame,
% but it cannot recover the spoken word from this TXT alone.
phonemeFileName = '034.txt';
phonemeFilePath = fullfile(pwd, phonemeFileName);
% 'normalized_sequence' maps MRI frame 1..N onto TXT 0..end time.
% Use 'direct_time' only if MRI time and TXT time are already synchronized.
phonemeAlignmentMode = 'normalized_sequence';

% Smoothing window used before numerical differentiation. Must be odd.

smoothWindow = 7;

% If true, missing oral-area frames are linearly interpolated ONLY for

% derivative calculation. Their original validity remains flagged.

interpolateMissingForDerivatives = true;

outDir = fullfile(pwd, 'results_all_frames');

showRawContours = false;        % set true to show raw contours instead

if ~isfile(matFilePath)

    error('MAT file not found: %s', matFilePath);

end

if ~exist(outDir, 'dir')

    mkdir(outDir);

end

% Read number of frames from the annotation data.

S = load(matFilePath, 'annotation');

if ~isfield(S, 'annotation') || isempty(S.annotation)

    error('MAT file does not contain a nonempty annotation variable.');

end

nFrames = numel(S.annotation);

fprintf('MAT file: %s\nTotal frames: %d\n', matFilePath, nFrames);

fprintf('Display duration: %.1f seconds/frame\n', frameDelay);

fprintf('Press Ctrl+C in the Command Window to stop.\n');

fig = figure('Color','k', 'Name','All-frame C1/C2 detection', ...
    'NumberTitle','off', 'Visible','on');

ax = axes('Parent',fig);

% Store per-frame results; failed frames remain marked as failed.

results = cell(nFrames,1);

status = strings(nFrames,1);

% Store oral cavity area and frame-specific geometry.

areaPixels = nan(nFrames,1);

C1_all = cell(nFrames,1);

C2_all = cell(nFrames,1);

C3_all = cell(nFrames,1);

MRI_all = cell(nFrames,1);

UL_all = nan(nFrames,2);

LL_all = nan(nFrames,2);

VEL_all = nan(nFrames,2);

C2end_all = nan(nFrames,2);

% Frames where C2 START returned a [i i] fallback/near-zero result.

c2StartReview = false(nFrames,1);

% Permanent per-frame error/status tracking. This prevents older Command

% Window output from hiding failures such as Frame 32.

failureReason = strings(nFrames,1);

failureReason(:) = "";

errorLogFile = fullfile(outDir,'frame_errors.txt');

fidErrorInit = fopen(errorLogFile,'w');

if fidErrorInit ~= -1

    fprintf(fidErrorInit,'FRAME ERROR LOG\n');

    fprintf(fidErrorInit,'MAT file: %s\n',matFilePath);

    fprintf(fidErrorInit,'Total frames: %d\n\n',nFrames);

    fclose(fidErrorInit);

end

for frameIdx = 1:nFrames

    fprintf('\n========== FRAME %d / %d ==========\n', frameIdx, nFrames);

    % clf(fig) in the previous iteration deletes axes handles.

    % Recreate a fresh axes before showing the processing status.

    if ~isgraphics(fig, 'figure')

        fig = figure('Color','k', 'Name','All-frame C1/C2 detection', ...
            'NumberTitle','off', 'Visible','on');

    else

        clf(fig);

    end

    ax = axes('Parent',fig);

    title(ax, sprintf('Processing frame %d / %d ...', frameIdx, nFrames), ...
        'Color','w');

    drawnow;

    try

        %% Load frame

        data = loadData(matFilePath, frameIdx);

        if isempty(data.L) || any(~isfinite(data.L))

            error('Frame %d has missing/invalid L.', frameIdx);

        end

        if ~isfield(data,'image') || isempty(data.image)

            error('Frame %d has no MRI image in loadData output.', frameIdx);

        end

        if isempty(data.VEL_manual) || any(~isfinite(data.VEL_manual))

            error('Frame %d has missing/invalid manual VEL.', frameIdx);

        end

        L = double(data.L(:)).';

        VEL_manual = double(data.VEL_manual(:)).';

        MRI = data.image;

        C1raw = data.C1; C2raw = data.C2; C3raw = data.C3;

        %% Preprocess and identify contours

        C1p = preprocessData(C1raw, 'C1');

        C2p = preprocessData(C2raw, 'C2');

        if ~isempty(C3raw)

            C3p = preprocessData(C3raw, 'C3');

        else

            C3p = [];

        end

        C1 = identifyC1(C1p);

        C2 = identifyC2(C2p);

        %% Anatomical axis: L toward manual VEL

        axisVec = VEL_manual - L;

        axisNorm = norm(axisVec);

        if axisNorm < eps

            error('Frame %d: L and manual VEL cannot define an axis.', frameIdx);

        end

        axisA = axisVec / axisNorm;

        %% Detect four points using the existing solution

        [UL, idxUL, tauUL] = findC1Start(C1, L, axisA);

        % Current recommended helper accepts UL so the no-crossing C2

        % fallback is paired anatomically with the detected UL. If an older

        % 3-input helper is still in the MATLAB folder, fall back to it

        % rather than stopping the complete frame run.

        try

            [LL, idxLL, tauLL] = findC2Start(C2, L, axisA, UL);

        catch ME_C2Start

            if contains(ME_C2Start.message,'Too many input arguments')

                warning('Using older 3-input findC2Start; UL-paired fallback is unavailable.');

                [LL, idxLL, tauLL] = findC2Start(C2, L, axisA);

            else

                rethrow(ME_C2Start);

            end

        end

        c2FallbackThisFrame = isnumeric(idxLL) && numel(idxLL) >= 2 && idxLL(1) == idxLL(2);

        [VEL, velIdx, gapDist] = ...
            findC1End(C1, C3p, tolerancePx, VEL_manual);

        [C2end, idxC2end, tauC2end, tangentVec] = ...
            findC2End(C1, C2, VEL, velIdx);

        [isValid, statusTable] = ...
            validatePoints(C1, C2, UL, LL, VEL, C2end);

        %% Stage-by-stage visualization (same geometry as main.m)

        % One figure is reused for every frame; six panels show the

        % intermediate construction and final detected points.

        if ~isgraphics(fig, 'figure')

            fig = figure('Color','k', 'Name','All-frame C1/C2 detection', ...
                'NumberTitle','off', 'Visible','on');

        else

            clf(fig);

        end

        ax1 = subplot(2,3,1,'Parent',fig);

        drawMRI(ax1,MRI); hold(ax1,'on');

        plotContour(ax1,C1raw,'r-','C1 raw');

        plotContour(ax1,C2raw,'b-','C2 raw');

        plotContour(ax1,C3raw,'g-','C3 raw');

        title(ax1,'Input: MRI + raw contours');

        ax2 = subplot(2,3,2,'Parent',fig);

        drawMRI(ax2,MRI); hold(ax2,'on');

        plotContour(ax2,C1,'r-','C1');

        plotPoint(ax2,L,'L','L');

        plotPoint(ax2,UL,'UL','UL');

        plotPoint(ax2,C1(idxUL(1),:),'C1_BRACKET','UL bracket i');

        if numel(idxUL)>=2 && idxUL(2) <= size(C1,1)

            plotPoint(ax2,C1(idxUL(2),:),'C1_BRACKET2','UL bracket i+1');

        end

        perpAxis = [-axisA(2), axisA(1)];

        plotLine(ax2,L,perpAxis,'c--','C1 START perpendicular');

        plotLine(ax2,L,axisA,'y-','C1 START anatomical axis');

        title(ax2,'C1 START: axis, L, perpendicular, UL');

        ax3 = subplot(2,3,3,'Parent',fig);

        drawMRI(ax3,MRI); hold(ax3,'on');

        plotContour(ax3,C1,'r-','C1');

        plotContour(ax3,C3p,'g-','C3');

        plotPoint(ax3,VEL,'VEL','VEL');

        plotPoint(ax3,C1(velIdx,:),'C1_NEAREST', ...
            sprintf('C1 index %d',velIdx));

        title(ax3,sprintf('C1 END / VEL (gap %.2f px)',gapDist));

        ax4 = subplot(2,3,4,'Parent',fig);

        drawMRI(ax4,MRI); hold(ax4,'on');

        plotContour(ax4,C2,'b-','C2');        

        plotPoint(ax4,L,'L','L');

        plotPoint(ax4,LL,'LL','LL');

        plotPoint(ax4,C2(idxLL(1),:),'C2_BRACKET','LL bracket i');

        if numel(idxLL) > 1 && ...
                idxLL(2) ~= idxLL(1) && ...
                idxLL(2) <= size(C2,1)

            plotPoint(ax4,C2(idxLL(2),:), ...
                'C2_BRACKET2','LL bracket i+1');

        end

        plotLine(ax4,L,perpAxis,'m--','C2 START perpendicular');

        plotLine(ax4,L,axisA,'m-','C2 START anatomical axis');

        title(ax4,'C2 START: axis, L, perpendicular, LL');

        ax5 = subplot(2,3,5,'Parent',fig);

        drawMRI(ax5,MRI); hold(ax5,'on');

        plotContour(ax5,C1,'r-','C1');

        plotContour(ax5,C2,'b-','C2');

        plotPoint(ax5,VEL,'VEL','VEL');

        plotPoint(ax5,C2(idxC2end(1),:), ...
            'C2_BRACKET','C2 END bracket i');

        if numel(idxC2end) > 1 && ...
                idxC2end(2) ~= idxC2end(1) && ...
                idxC2end(2) <= size(C2,1)

            plotPoint(ax5,C2(idxC2end(2),:), ...
                'C2_BRACKET2','C2 END bracket i+1');

        end

        plotPoint(ax5,C2end,'C2_END','C2 END');

        % C1 tangent at VEL and its perpendicular cutting line.

        t = double(tangentVec(:)).';

        t = t ./ max(norm(t),eps);

        n = [-t(2),t(1)];

        plotLine(ax5,VEL,t,'k-','C1 tangent at VEL');

        plotLine(ax5,VEL,n,'c--','Perpendicular C2 cutting line');

        plotPoint(ax5,C2end,'m*','C2 END');

        title(ax5,'C2 END: tangent + perpendicular cut');

        ax6 = subplot(2,3,6,'Parent',fig);

        drawMRI(ax6,MRI); hold(ax6,'on');

        % Build the oral-area polygon between C1 and C2.

        % C1 arc: UL to VEL. C2 arc: LL to C2 END.

        % LL is obtained from the updated findC2Start(C2,L,axisA,UL),

        % so no-crossing C2 frames use the UL-paired anatomical fallback.

        upperArc = getContourArc(C1, idxUL, velIdx, UL, VEL);

        lowerArc = getContourArc(C2, idxLL, idxC2end, LL, C2end);

        areaPoly = [upperArc; flipud(lowerArc)];

        areaValue = NaN;

        areaGeometryOK = false;

        if size(areaPoly,1) >= 3 && all(isfinite(areaPoly(:)))

            % Calculate oral cavity area in pixel^2.

            areaValue = polyarea(areaPoly(:,1), areaPoly(:,2));

            areaPixels(frameIdx) = areaValue;

            areaGeometryOK = true;

            % Fill is visualization only; C1/C2 are drawn afterward.

            % Therefore the red/green contour overlays do not affect polyarea.

            patch(ax6, areaPoly(:,1), areaPoly(:,2), [1 1 1], ...
                'FaceAlpha', 1.0, ...
                'EdgeColor', 'none', ...
                'DisplayName', 'Oral area (C1-C2)');

        end

        % Draw contours and landmarks over the white fill.

        plotContour(ax6,C1,'r-','C1');

        plotContour(ax6,C2,'b-','C2');

        plotContour(ax6,C3p,'g-','C3');

        plotPoint(ax6,UL,'y*','UL');

        plotPoint(ax6,LL,'LL','LL');

        plotPoint(ax6,VEL,'b*','VEL');

        plotPoint(ax6,C2end,'m*','C2 END');

        title(ax6,sprintf('FINAL | Frame %d/%d | %s',frameIdx,nFrames, ...
            chooseText(isValid,'VALID','VALIDATION WARNING')));

        sgtitle(fig,sprintf('Frame %d / %d — stage-by-stage anatomical detection', ...
            frameIdx,nFrames),'Color','w','FontWeight','bold');

        arrangeDetectionFigure(fig,ax1,ax2,ax3,ax4,ax5,ax6);

        drawnow;

        %% Store frame-specific geometry for later kinematic analysis / visualization

        MRI_all{frameIdx} = MRI;

        C1_all{frameIdx} = C1;

        C2_all{frameIdx} = C2;

        C3_all{frameIdx} = C3p;

        UL_all(frameIdx,:) = UL;

        LL_all(frameIdx,:) = LL;

        VEL_all(frameIdx,:) = VEL;

        C2end_all(frameIdx,:) = C2end;

        c2StartReview(frameIdx) = c2FallbackThisFrame;

        %% Save frame result

        saveResults(outDir, frameIdx, statusTable, UL, LL, VEL, C2end);

        results{frameIdx} = struct( ...
            'UL',UL,'LL',LL,'VEL',VEL,'C2end',C2end, ...
            'idxUL',idxUL,'tauUL',tauUL, ...
            'idxLL',idxLL,'tauLL',tauLL, ...
            'velIdx',velIdx,'gapDist',gapDist, ...
            'idxC2end',idxC2end,'tauC2end',tauC2end, ...
            'tangentVec',tangentVec,'isValid',isValid, ...
            'areaPixels',areaValue,'areaGeometryOK',areaGeometryOK, ...
            'c2StartReview',c2FallbackThisFrame);

        status(frameIdx) = chooseText(isValid,'VALID','VALIDATION WARNING');

        fprintf('Frame %d completed: UL, LL, VEL, C2 END detected.\n', frameIdx);

        fprintf('  UL=(%.3f, %.3f), LL=(%.3f, %.3f)\n', UL, LL);

        fprintf('  VEL=(%.3f, %.3f), C2 END=(%.3f, %.3f)\n', VEL, C2end);

        if areaGeometryOK

            fprintf('  Oral area = %.4f pixel^2\n', areaValue);

            if c2FallbackThisFrame

                fprintf(2,'  C2 START status: REVIEW (fallback/near-zero bracket)\n');

            end

        else

            fprintf('  Oral area = NOT COMPUTED (invalid polygon)\n');

        end

    catch ME

        status(frameIdx) = "FAILED";

        failureReason(frameIdx) = string(ME.message);

        results{frameIdx} = struct('error', ME.message);

        % Permanently save the complete error report for this frame.

        fidErr = fopen(errorLogFile,'a');

        if fidErr ~= -1

            fprintf(fidErr,'=============================================\n');

            fprintf(fidErr,'FRAME %d / %d FAILED\n',frameIdx,nFrames);

            fprintf(fidErr,'=============================================\n');

            fprintf(fidErr,'%s\n\n',getReport(ME,'extended','hyperlinks','off'));

            fclose(fidErr);

        end

        % Recreate axes because a failure may occur after clf(fig).

        if ~isgraphics(fig, 'figure')

            fig = figure('Color','k', 'Name','All-frame C1/C2 detection', ...
                'NumberTitle','off', 'Visible','on');

        else

            clf(fig);

        end

        ax = axes('Parent',fig);

        % Show MRI even if detection fails, so the sequence continues visibly.

        if exist('MRI','var') && ~isempty(MRI)

            imagesc(ax, MRI); colormap(ax,gray(256)); axis(ax,'image');

            set(ax,'YDir','reverse');

        end

        title(ax, sprintf('Frame %d / %d | DETECTION FAILED', frameIdx, nFrames), ...
            'Color','w','FontWeight','bold');

        % Display the actual exception on the figure as well as in the

        % Command Window, so the failed frame can be diagnosed.

        msg = regexprep(ME.message, '\s+', ' ');

        text(ax, 0.02, 0.02, sprintf('ERROR: %s', msg), ...
            'Units','normalized','Color','y','FontSize',8, ...
            'FontWeight','bold','Interpreter','none', ...
            'VerticalAlignment','bottom','BackgroundColor','k', ...
            'Margin',3,'Clipping','on');

        drawnow;

        fprintf(2,'Frame %d failed: %s\n', frameIdx, ...
            getReport(ME,'extended','hyperlinks','off'));

        warning('Frame %d failed: %s', frameIdx, ME.message);

    end

    pause(frameDelay);

end

%% PER-FRAME STATUS / ERROR SUMMARY

% This table is always written, even when dt is NaN and kinematic

% calculations are skipped. It provides a permanent record for every frame.

Frame = (1:nFrames)';

DetectionStatus = status;

ReviewStatus = strings(nFrames,1);

ReviewStatus(:) = "NORMAL";

ReviewStatus(c2StartReview) = "REVIEW_C2_START";

FailureReason = failureReason;

AreaStatus = strings(nFrames,1);

AreaStatus(:) = "AREA_VALID";

AreaStatus(isnan(areaPixels)) = "AREA_MISSING";

frameSummaryTable = table(Frame,DetectionStatus,ReviewStatus,AreaStatus,...
    areaPixels,FailureReason,...
    'VariableNames',{'Frame','DetectionStatus','ReviewStatus','AreaStatus',...
    'OralArea_pixel2','FailureReason'});

writetable(frameSummaryTable,fullfile(outDir,'frame_summary.csv'));

save(fullfile(outDir,'frame_status_summary.mat'),...
    'frameSummaryTable','failureReason','status','c2StartReview','areaPixels');

fprintf('\n========== FRAME STATUS SUMMARY ==========\n');

fprintf('Valid/Warning frames : %d\n',sum(status=="VALID" | status=="VALIDATION WARNING"));

fprintf('Failed frames        : %d\n',sum(status=="FAILED"));

fprintf('Missing area frames  : %d\n',sum(isnan(areaPixels)));

fprintf('Error log saved      : %s\n',errorLogFile);

fprintf('Frame summary saved  : %s\n',fullfile(outDir,'frame_summary.csv'));

failedFrames = find(status=="FAILED");

if ~isempty(failedFrames)

    fprintf('\nFailed frame details:\n');

    for kk = 1:numel(failedFrames)

        ff = failedFrames(kk);

        fprintf('  Frame %d: %s\n',ff,failureReason(ff));

    end

end


%% DATASET SUMMARY FOR PRESENTATION
% Added for reporting dataset/frame statistics.
% "Valid area" means a finite area value was produced; it does not imply
% that every landmark passed manual review.

totalFrames = nFrames;
validAreaFrames = sum(isfinite(areaPixels));
missingAreaFrames = sum(~isfinite(areaPixels));

validDetectionFrames = sum(status == "VALID");
warningFrames = sum(status == "VALIDATION WARNING");
failedFramesCount = sum(status == "FAILED");

% Count each frame once, even if it meets multiple review conditions.
reviewMask = c2StartReview | ...
             (status == "VALIDATION WARNING") | ...
             (status == "FAILED");
reviewFrames = sum(reviewMask);

datasetSummary = table( ...
    string(matFileName), totalFrames, validAreaFrames, ...
    missingAreaFrames, validDetectionFrames, warningFrames, ...
    failedFramesCount, reviewFrames, ...
    'VariableNames', {'Dataset','TotalFrames', ...
    'ValidAreaFrames','MissingOrInvalidAreaFrames', ...
    'ValidDetectionFrames','ValidationWarningFrames', ...
    'FailedFrames','FramesRequiringReview'});

writetable(datasetSummary, fullfile(outDir,'dataset_summary.csv'));

fprintf('\\n========== DATASET SUMMARY FOR PRESENTATION ==========\\n');
fprintf('Dataset                         : %s\\n', matFileName);
fprintf('Total MRI frames                : %d\\n', totalFrames);
fprintf('Frames with valid oral area     : %d\\n', validAreaFrames);
fprintf('Frames without valid oral area  : %d\\n', missingAreaFrames);
fprintf('Valid detection frames          : %d\\n', validDetectionFrames);
fprintf('Validation-warning frames       : %d\\n', warningFrames);
fprintf('Failed frames                   : %d\\n', failedFramesCount);
fprintf('Frames requiring review         : %d\\n', reviewFrames);
fprintf('Dataset summary CSV             : %s\\n', ...
    fullfile(outDir,'dataset_summary.csv'));

%% ORAL AREA + VELOCITY + ACCELERATION ANALYSIS

validArea = isfinite(areaPixels);

areaFrames = find(validArea);

areaValues = areaPixels(validArea);

time = (0:nFrames-1)' * dt;

fprintf('\n========== ORAL AREA RESULTS ==========\n');

fprintf('Frames with valid area: %d / %d\n', numel(areaValues), nFrames);

if ~isempty(areaValues)

    fprintf('Minimum oral area: %.4f pixel^2\n', min(areaValues));

    fprintf('Maximum oral area: %.4f pixel^2\n', max(areaValues));

    [maxArea, maxAreaLocalIdx] = max(areaValues);

    maxAreaFrame = areaFrames(maxAreaLocalIdx);

    fprintf('Maximum oral area frame: %d\n', maxAreaFrame);

    fprintf('Maximum oral area: %.4f pixel^2\n', maxArea);

    % Area vs frame

    figAreaFrame = figure('Color','w','Name','Oral Area vs Frame','NumberTitle','off');

    plot(1:nFrames, areaPixels, '-o', 'LineWidth', 1.2, 'MarkerSize', 4);

    xlabel('Frame');

    ylabel('Oral Area (pixel^2)');

    title('Oral Area vs Frame');

    grid on;

    saveas(figAreaFrame, fullfile(outDir,'Oral_Area_vs_Frame.png'));

    savefig(figAreaFrame, fullfile(outDir,'Oral_Area_vs_Frame.fig'));

    % ============================================================

    % KINEMATIC ANALYSIS REQUIRES REAL dt

    % ============================================================

    if ~isfinite(dt) || dt <= 0

        warning(['dt is not set. Area results and area-vs-frame graph were ', ...
                 'saved, but velocity/acceleration were NOT calculated. ', ...
                 'Set dt to the actual MRI seconds/frame and rerun.']);

        fprintf(2,['\nWARNING: dt is NaN/invalid. Set the actual MRI temporal ', ...
                   'interval in the CONFIGURATION section.\n']);

    else

        % ------------------------------------------------------------

        % Prepare area sequence for differentiation

        % ------------------------------------------------------------

        areaForDerivative = areaPixels;

        if any(~validArea)

            if interpolateMissingForDerivatives

                if sum(validArea) < 3

                    error('At least 3 valid oral-area frames are required for derivative calculation.');

                end

                areaForDerivative(~validArea) = interp1( ...
                    time(validArea), areaPixels(validArea), time(~validArea), ...
                    'linear', 'extrap');

                fprintf('Missing area frames interpolated only for derivative calculation: %d\n', ...
                    sum(~validArea));

            else

                warning('Missing area frames exist and interpolation is disabled; derivative calculation may contain NaNs.');

            end

        end

        % ------------------------------------------------------------

        % Smooth before differentiation to reduce second-derivative noise

        % ------------------------------------------------------------

        nValidForSmooth = sum(isfinite(areaForDerivative));

        win = smoothWindow;

        if win < 3

            win = 3;

        end

        if mod(win,2) == 0

            win = win + 1;

        end

        maxOdd = 2*floor((nValidForSmooth-1)/2)+1;

        if win > maxOdd

            win = maxOdd;

        end

        if win >= 3 && nValidForSmooth >= 3

            areaSmooth = smoothdata(areaForDerivative,'sgolay',win);

        else

            areaSmooth = areaForDerivative;

            warning('Not enough frames for Savitzky-Golay smoothing; using raw/interpolated area.');

        end

        % ------------------------------------------------------------

        % Velocity and acceleration

        % ------------------------------------------------------------

        areaVelocity = gradient(areaSmooth, dt);

        areaAcceleration = gradient(areaVelocity, dt);

        % ------------------------------------------------------------

        % Maximum positive acceleration

        % ------------------------------------------------------------

        finiteAcc = isfinite(areaAcceleration);

        if ~any(finiteAcc)

            error('No finite acceleration values were produced.');

        end

        accIdx = find(finiteAcc);

        [maxAcceleration, localIdx] = max(areaAcceleration(finiteAcc));

        maxAccFrame = accIdx(localIdx);

        maxAccTime = time(maxAccFrame);

        maxAccArea = areaPixels(maxAccFrame);

        % Maximum acceleration magnitude (reported separately)

        [maxAbsAcceleration, localAbsIdx] = max(abs(areaAcceleration(finiteAcc)));

        maxAbsAccFrame = accIdx(localAbsIdx);

        maxAbsAccTime = time(maxAbsAccFrame);

        maxAbsAccArea = areaPixels(maxAbsAccFrame);

        maxAbsSignedAcceleration = areaAcceleration(maxAbsAccFrame);

        fprintf('\n========== VELOCITY / ACCELERATION RESULTS ==========\n');

        fprintf('dt = %.9f s/frame\n', dt);

        fprintf('Smoothing window actually used = %d\n', win);

        fprintf('Maximum positive acceleration:\n');

        fprintf('  Frame       : %d\n', maxAccFrame);

        fprintf('  Time        : %.9f s\n', maxAccTime);

        fprintf('  Area        : %.6f pixel^2\n', maxAccArea);

        fprintf('  Acceleration: %.6f pixel^2/s^2\n', maxAcceleration);

        fprintf('Maximum acceleration magnitude:\n');

        fprintf('  Frame       : %d\n', maxAbsAccFrame);

        fprintf('  Time        : %.9f s\n', maxAbsAccTime);

        fprintf('  Area        : %.6f pixel^2\n', maxAbsAccArea);

        fprintf('  Signed accel.: %.6f pixel^2/s^2\n', maxAbsSignedAcceleration);

        fprintf('  Magnitude    : %.6f pixel^2/s^2\n', maxAbsAcceleration);

        % ------------------------------------------------------------

        % Kinematic graphs

        % ------------------------------------------------------------

        figAreaTime = figure('Color','w','Name','Oral Area vs Time','NumberTitle','off');

        plot(time,areaSmooth,'-o','LineWidth',1.2,'MarkerSize',4);

        xlabel('Time (s)'); ylabel('Oral Area (pixel^2)');

        title('Oral Area vs Time'); grid on;

        saveas(figAreaTime,fullfile(outDir,'Oral_Area_vs_Time.png'));

        savefig(figAreaTime,fullfile(outDir,'Oral_Area_vs_Time.fig'));

        figVelocity = figure('Color','w','Name','Oral Area Velocity','NumberTitle','off');

        plot(time,areaVelocity,'-o','LineWidth',1.2,'MarkerSize',4);

        xlabel('Time (s)'); ylabel('Area Velocity (pixel^2/s)');

        title('Oral Area Velocity vs Time'); grid on;

        saveas(figVelocity,fullfile(outDir,'Oral_Area_Velocity_vs_Time.png'));

        savefig(figVelocity,fullfile(outDir,'Oral_Area_Velocity_vs_Time.fig'));

        figAcceleration = figure('Color','w','Name','Oral Area Acceleration','NumberTitle','off');

        plot(time,areaAcceleration,'-o','LineWidth',1.2,'MarkerSize',4);

        hold on;

        plot(maxAccTime,maxAcceleration,'o','MarkerSize',9,'LineWidth',2);

        xline(maxAccTime,'--');

        xlabel('Time (s)'); ylabel('Area Acceleration (pixel^2/s^2)');

        title(sprintf('Oral Area Acceleration vs Time | max positive = frame %d',maxAccFrame));

        grid on; hold off;

        saveas(figAcceleration,fullfile(outDir,'Oral_Area_Acceleration_vs_Time.png'));

        savefig(figAcceleration,fullfile(outDir,'Oral_Area_Acceleration_vs_Time.fig'));

        figCombined = figure('Color','w','Name','Oral Area Kinematic Analysis','NumberTitle','off');

        subplot(3,1,1); plot(time,areaSmooth,'LineWidth',1.2); grid on;

        xlabel('Time (s)'); ylabel('Area (pixel^2)'); title('Oral Area');

        subplot(3,1,2); plot(time,areaVelocity,'LineWidth',1.2); grid on;

        xlabel('Time (s)'); ylabel('Velocity (pixel^2/s)'); title('Area Velocity');

        subplot(3,1,3); plot(time,areaAcceleration,'LineWidth',1.2); grid on;

        xlabel('Time (s)'); ylabel('Acceleration (pixel^2/s^2)'); title('Area Acceleration');

        saveas(figCombined,fullfile(outDir,'Oral_Area_Velocity_Acceleration.png'));

        savefig(figCombined,fullfile(outDir,'Oral_Area_Velocity_Acceleration.fig'));

        figMax = figure('Color','w','Name','Maximum Acceleration','NumberTitle','off');

        plot(time,areaAcceleration,'LineWidth',1.5); hold on;

        plot(maxAccTime,maxAcceleration,'o','MarkerSize',10,'LineWidth',2);

        xline(maxAccTime,'--'); grid on;

        xlabel('Time (s)'); ylabel('Acceleration (pixel^2/s^2)');

        title(sprintf('Maximum Positive Acceleration | Frame %d',maxAccFrame));

        saveas(figMax,fullfile(outDir,'Maximum_Acceleration.png'));

        savefig(figMax,fullfile(outDir,'Maximum_Acceleration.fig')); hold off;

        % ------------------------------------------------------------

        % Frame-wise kinematic table

        % ------------------------------------------------------------

        derivativeStatus = strings(nFrames,1);

        derivativeStatus(:) = "MEASURED";

        derivativeStatus(~validArea) = "AREA_INTERPOLATED_FOR_DERIVATIVE";

        reviewStatus = strings(nFrames,1);

        reviewStatus(:) = "NORMAL";

        reviewStatus(c2StartReview) = "REVIEW_C2_START";

        finalStatus = status;

        for k = 1:nFrames

            if c2StartReview(k) && finalStatus(k) ~= "FAILED"

                finalStatus(k) = finalStatus(k) + " | C2 START REVIEW";

            end

        end

        Frame = (1:nFrames)';

        UL_X = UL_all(:,1); UL_Y = UL_all(:,2);

        LL_X = LL_all(:,1); LL_Y = LL_all(:,2);

        VEL_X = VEL_all(:,1); VEL_Y = VEL_all(:,2);

        C2End_X = C2end_all(:,1); C2End_Y = C2end_all(:,2);

        resultTable = table(Frame,time,UL_X,UL_Y,LL_X,LL_Y,VEL_X,VEL_Y,...
            C2End_X,C2End_Y,areaPixels,areaSmooth,areaVelocity,areaAcceleration,...
            finalStatus,reviewStatus,derivativeStatus,...
            'VariableNames',{'Frame','Time_s','UL_X','UL_Y','LL_X','LL_Y',...
            'VEL_X','VEL_Y','C2End_X','C2End_Y','OralArea_pixel2',...
            'SmoothedArea_pixel2','AreaVelocity_pixel2_per_s',...
            'AreaAcceleration_pixel2_per_s2','DetectionStatus','ReviewStatus',...
            'DerivativeStatus'});

        writetable(resultTable,fullfile(outDir,'Oral_Area_Velocity_Acceleration.csv'));

        % Add kinematic values back into the per-frame results before

        % saving the MAT file, so the saved results contain the full pipeline.

        for k = 1:nFrames

            if isempty(results{k}), continue; end

            results{k}.time_s = time(k);

            results{k}.smoothedArea = areaSmooth(k);

            results{k}.areaVelocity = areaVelocity(k);

            results{k}.areaAcceleration = areaAcceleration(k);

            results{k}.reviewStatus = reviewStatus(k);

        end

        % ------------------------------------------------------------

        % Save complete MAT analysis

        % ------------------------------------------------------------

        save(fullfile(outDir,'Oral_Area_Velocity_Acceleration.mat'),...
            'time','dt','smoothWindow','win','areaPixels','areaForDerivative',...
            'areaSmooth','areaVelocity','areaAcceleration','validArea',...
            'results','status','c2StartReview','resultTable',...
            'maxAcceleration','maxAccFrame','maxAccTime','maxAccArea',...
            'maxAbsAcceleration','maxAbsAccFrame','maxAbsAccTime',...
            'maxAbsAccArea','maxAbsSignedAcceleration','maxAreaFrame','maxArea');

        % ------------------------------------------------------------

        % Save text summary

        % ------------------------------------------------------------

        fid = fopen(fullfile(outDir,'Acceleration_Summary.txt'),'w');

        if fid ~= -1

            fprintf(fid,'ORAL AREA KINEMATIC ANALYSIS\n');

            fprintf(fid,'============================\n\n');

            fprintf(fid,'dt = %.12g s/frame\n',dt);

            fprintf(fid,'Smoothing window requested = %d\n',smoothWindow);

            fprintf(fid,'Smoothing window used = %d\n\n',win);

            fprintf(fid,'Maximum positive acceleration\n');

            fprintf(fid,'Frame = %d\nTime = %.12g s\nArea = %.12g pixel^2\nAcceleration = %.12g pixel^2/s^2\n\n',...
                maxAccFrame,maxAccTime,maxAccArea,maxAcceleration);

            fprintf(fid,'Maximum acceleration magnitude\n');

            fprintf(fid,'Frame = %d\nTime = %.12g s\nArea = %.12g pixel^2\nSigned acceleration = %.12g pixel^2/s^2\nMagnitude = %.12g pixel^2/s^2\n',...
                maxAbsAccFrame,maxAbsAccTime,maxAbsAccArea,maxAbsSignedAcceleration,maxAbsAcceleration);

            fclose(fid);

        end

        % ------------------------------------------------------------

        % ------------------------------------------------------------
        % Pronunciation / phoneme lookup at maximum-acceleration frames
        % ------------------------------------------------------------
        if isfile(phonemeFilePath)
            try
                phonemeData = readPhonemeAlignment(phonemeFilePath);

                maxAccAudioTime = mapFrameToAudioTime(maxAccFrame,nFrames,...
                    maxAccTime,phonemeData.endTime(end),phonemeAlignmentMode);
                maxAccPhoneme = findPhonemeAtTime(phonemeData,maxAccAudioTime);

                maxAbsAudioTime = mapFrameToAudioTime(maxAbsAccFrame,nFrames,...
                    maxAbsAccTime,phonemeData.endTime(end),phonemeAlignmentMode);
                maxAbsPhoneme = findPhonemeAtTime(phonemeData,maxAbsAudioTime);

                fprintf('\nPRONUNCIATION / PHONEME ALIGNMENT\n');
                fprintf('==================================\n');
                fprintf('TXT file       : %s\n',phonemeFilePath);
                fprintf('Alignment mode : %s\n',phonemeAlignmentMode);
                fprintf('TXT duration   : %.6f s\n',phonemeData.endTime(end));
                fprintf('\nMaximum positive acceleration:\n');
                fprintf('  MRI frame          : %d / %d\n',maxAccFrame,nFrames);
                fprintf('  Aligned audio time : %.6f s\n',maxAccAudioTime);
                fprintf('  Phoneme            : %s\n',maxAccPhoneme.label);
                fprintf('  Phoneme interval   : %.6f - %.6f s\n',maxAccPhoneme.startTime,maxAccPhoneme.endTime);
                fprintf('  Word               : unavailable from phoneme-only TXT\n');
                fprintf('\nMaximum absolute acceleration:\n');
                fprintf('  MRI frame          : %d / %d\n',maxAbsAccFrame,nFrames);
                fprintf('  Aligned audio time : %.6f s\n',maxAbsAudioTime);
                fprintf('  Phoneme            : %s\n',maxAbsPhoneme.label);
                fprintf('  Phoneme interval   : %.6f - %.6f s\n',maxAbsPhoneme.startTime,maxAbsPhoneme.endTime);
                fprintf('  Word               : unavailable from phoneme-only TXT\n');

                fidP = fopen(fullfile(outDir,'Maximum_Acceleration_Phoneme.txt'),'w');
                if fidP ~= -1
                    fprintf(fidP,'MAXIMUM ACCELERATION PHONEME ANALYSIS\n');
                    fprintf(fidP,'====================================\n');
                    fprintf(fidP,'TXT file = %s\n',phonemeFilePath);
                    fprintf(fidP,'Alignment mode = %s\n',phonemeAlignmentMode);
                    fprintf(fidP,'TXT duration = %.9f s\n\n',phonemeData.endTime(end));
                    fprintf(fidP,'Maximum positive acceleration\n');
                    fprintf(fidP,'MRI frame = %d / %d\n',maxAccFrame,nFrames);
                    fprintf(fidP,'Aligned audio time = %.9f s\n',maxAccAudioTime);
                    fprintf(fidP,'Phoneme = %s\n',maxAccPhoneme.label);
                    fprintf(fidP,'Phoneme interval = %.9f - %.9f s\n',maxAccPhoneme.startTime,maxAccPhoneme.endTime);
                    fprintf(fidP,'Word = NOT AVAILABLE (TXT contains phoneme timing only)\n\n');
                    fprintf(fidP,'Maximum absolute acceleration\n');
                    fprintf(fidP,'MRI frame = %d / %d\n',maxAbsAccFrame,nFrames);
                    fprintf(fidP,'Aligned audio time = %.9f s\n',maxAbsAudioTime);
                    fprintf(fidP,'Phoneme = %s\n',maxAbsPhoneme.label);
                    fprintf(fidP,'Phoneme interval = %.9f - %.9f s\n',maxAbsPhoneme.startTime,maxAbsPhoneme.endTime);
                    fprintf(fidP,'Word = NOT AVAILABLE (TXT contains phoneme timing only)\n');
                    fclose(fidP);
                end
            catch MEphon
                warning('Phoneme alignment could not be performed: %s',MEphon.message);
                maxAccAudioTime = NaN; maxAbsAudioTime = NaN;
                maxAccPhoneme = emptyPhonemeResult();
                maxAbsPhoneme = emptyPhonemeResult();
            end
        else
            warning('Phoneme TXT not found: %s. Phoneme display disabled.',phonemeFilePath);
            maxAccAudioTime = NaN; maxAbsAudioTime = NaN;
            maxAccPhoneme = emptyPhonemeResult();
            maxAbsPhoneme = emptyPhonemeResult();
        end

        % Visualize the MRI frame corresponding to maximum positive accel

        % ------------------------------------------------------------

        if maxAccFrame >= 1 && maxAccFrame <= nFrames && ...
                ~isempty(MRI_all{maxAccFrame}) && ...
                ~isempty(C1_all{maxAccFrame}) && ~isempty(C2_all{maxAccFrame})

            MRImax = MRI_all{maxAccFrame};

            C1max = C1_all{maxAccFrame};

            C2max = C2_all{maxAccFrame};

            C3max = C3_all{maxAccFrame};

            ULmax = UL_all(maxAccFrame,:);

            LLmax = LL_all(maxAccFrame,:);

            VELmax = VEL_all(maxAccFrame,:);

            C2endmax = C2end_all(maxAccFrame,:);

            [idxULmax,idxVELmax,idxLLmax,idxC2endmax] = deal([],[],[],[]); %#ok<ASGLU>

            if isfield(results{maxAccFrame},'idxUL'), idxULmax = results{maxAccFrame}.idxUL; end

            if isfield(results{maxAccFrame},'velIdx'), idxVELmax = results{maxAccFrame}.velIdx; end

            if isfield(results{maxAccFrame},'idxLL'), idxLLmax = results{maxAccFrame}.idxLL; end

            if isfield(results{maxAccFrame},'idxC2end'), idxC2endmax = results{maxAccFrame}.idxC2end; end

            try

                upperArcMax = getContourArc(C1max,idxULmax,idxVELmax,ULmax,VELmax);

                lowerArcMax = getContourArc(C2max,idxLLmax,idxC2endmax,LLmax,C2endmax);

                areaPolyMax = [upperArcMax; flipud(lowerArcMax)];

                figMaxFrame = figure('Color','k','Name','Maximum Acceleration MRI Frame','NumberTitle','off');

                axm = axes('Parent',figMaxFrame);

                drawMRI(axm,MRImax); hold(axm,'on');

                plotContour(axm,C1max,'r-','C1');

                plotContour(axm,C2max,'b-','C2');

                plotContour(axm,C3max,'g-','C3');

                if size(areaPolyMax,1) >= 3 && all(isfinite(areaPolyMax(:)))

                    patch(axm,areaPolyMax(:,1),areaPolyMax(:,2),'w',...
                        'FaceAlpha',0.55,'EdgeColor','none','DisplayName','Oral area');

                end

                plotPoint(axm,ULmax,'UL','UL');

                plotPoint(axm,LLmax,'LL','LL');

                plotPoint(axm,VELmax,'b*','VEL');

                plotPoint(axm,C2endmax,'m*','C2 END');

                title(axm,sprintf(['MAXIMUM POSITIVE ACCELERATION | Frame %d / %d\n' ...
                    'Audio time = %.6f s | PHONEME = %s | TXT interval = %.3f - %.3f s'],...
                    maxAccFrame,nFrames,maxAccAudioTime,maxAccPhoneme.label,...
                    maxAccPhoneme.startTime,maxAccPhoneme.endTime),...
                    'Color','w','FontWeight','bold','Interpreter','none');

                addPhonemeAnnotation(axm,maxAccAudioTime,maxAccPhoneme, ...
                    maxAccFrame,nFrames,maxAcceleration,'Maximum positive acceleration');

                saveas(figMaxFrame,fullfile(outDir,'Maximum_Acceleration_MRI_Frame.png'));

                savefig(figMaxFrame,fullfile(outDir,'Maximum_Acceleration_MRI_Frame.fig'));

                hold(axm,'off');

            catch MEmax

                warning('Could not create maximum-acceleration MRI visualization: %s',MEmax.message);

            end

        end

        % Also save the maximum-absolute-acceleration frame separately.

        if maxAbsAccFrame >= 1 && maxAbsAccFrame <= nFrames && ...
                ~isempty(MRI_all{maxAbsAccFrame}) && ~isempty(C1_all{maxAbsAccFrame}) && ~isempty(C2_all{maxAbsAccFrame})

            try

                MRIabs = MRI_all{maxAbsAccFrame};

                C1abs = C1_all{maxAbsAccFrame};

                C2abs = C2_all{maxAbsAccFrame};

                C3abs = C3_all{maxAbsAccFrame};

                ULabs = UL_all(maxAbsAccFrame,:); LLabs = LL_all(maxAbsAccFrame,:);

                VELabs = VEL_all(maxAbsAccFrame,:); C2endabs = C2end_all(maxAbsAccFrame,:);

                rabs = results{maxAbsAccFrame};

                upperAbs = getContourArc(C1abs,rabs.idxUL,rabs.velIdx,ULabs,VELabs);

                lowerAbs = getContourArc(C2abs,rabs.idxLL,rabs.idxC2end,LLabs,C2endabs);

                polyAbs = [upperAbs; flipud(lowerAbs)];

                figAbs = figure('Color','k','Name','Maximum Absolute Acceleration MRI Frame','NumberTitle','off');

                axabs = axes('Parent',figAbs); drawMRI(axabs,MRIabs); hold(axabs,'on');

                plotContour(axabs,C1abs,'r-','C1'); plotContour(axabs,C2abs,'b-','C2'); plotContour(axabs,C3abs,'g-','C3');

                if size(polyAbs,1)>=3 && all(isfinite(polyAbs(:)))

                    patch(axabs,polyAbs(:,1),polyAbs(:,2),'w','FaceAlpha',0.55,'EdgeColor','none');

                end

                plotPoint(axabs,ULabs,'UL','UL'); plotPoint(axabs,LLabs,'LL','LL');

                plotPoint(axabs,VELabs,'b*','VEL'); plotPoint(axabs,C2endabs,'m*','C2 END');

                title(axabs,sprintf(['MAXIMUM ABSOLUTE ACCELERATION | Frame %d / %d\n' ...
                    'Audio time = %.6f s | PHONEME = %s | TXT interval = %.3f - %.3f s'],...
                    maxAbsAccFrame,nFrames,maxAbsAudioTime,maxAbsPhoneme.label,...
                    maxAbsPhoneme.startTime,maxAbsPhoneme.endTime),...
                    'Color','w','FontWeight','bold','Interpreter','none');

                addPhonemeAnnotation(axabs,maxAbsAudioTime,maxAbsPhoneme, ...
                    maxAbsAccFrame,nFrames,maxAbsSignedAcceleration,'Maximum absolute acceleration');

                saveas(figAbs,fullfile(outDir,'Maximum_Absolute_Acceleration_MRI_Frame.png'));

                savefig(figAbs,fullfile(outDir,'Maximum_Absolute_Acceleration_MRI_Frame.fig'));

                hold(axabs,'off');

            catch MEabs

                warning('Could not create maximum-absolute-acceleration MRI visualization: %s',MEabs.message);

            end

        end

    end

else

    warning('No valid oral-area measurements were obtained.');

end

% Always save the detection/area summary, even when dt is not yet set.

save(fullfile(outDir,'all_frames_detection_summary.mat'), ...
    'results','status','areaPixels','matFilePath','frameDelay','tolerancePx',...
    'dt','smoothWindow','C1_all','C2_all','C3_all','MRI_all','UL_all','LL_all',...
    'VEL_all','C2end_all','c2StartReview');

fprintf('\nAll frames processed. Valid/Warning: %d, Failed: %d\n', ...
    sum(status=="VALID" | status=="VALIDATION WARNING"), sum(status=="FAILED"));

fprintf('Summary saved in: %s\n', outDir);

%% Local plotting helpers

function drawMRI(ax,MRI)

    imagesc(ax,MRI);

    colormap(ax,gray(256));

    axis(ax,'image');

    set(ax,'YDir','reverse','Color','k','XColor','w','YColor','w');

    xlim(ax,[0.5 size(MRI,2)+0.5]);

    ylim(ax,[0.5 size(MRI,1)+0.5]);

    

end

function plotContour(ax,C,style,label)

    if isnumeric(C) && size(C,2)==2 && ~isempty(C)

        plot(ax,C(:,1),C(:,2),style,'LineWidth',1.3,'DisplayName',label);

    end

end

function plotPoint(ax,p,style,label)

    if isnumeric(p) && numel(p)==2 && all(isfinite(p(:)))

        p = double(p(:));

        switch style

            % ========================================================

            % L

            % ========================================================

            case 'L'

                plot(ax,p(1),p(2),'s', ...
                    'MarkerSize',10, ...
                    'MarkerFaceColor','w', ...
                    'MarkerEdgeColor','k', ...
                    'LineWidth',2.2, ...
                    'DisplayName',label);

            % ========================================================

            % UL

            % ========================================================

            case 'UL'

                plot(ax,p(1),p(2),'*', ...
                    'MarkerSize',15, ...
                    'Color',[1 0.5 0], ...
                    'MarkerEdgeColor','k', ...
                    'LineWidth',2.2, ...
                    'DisplayName',label);

            % ========================================================

            % LL

            % ========================================================

            case 'LL'
                plot(ax,p(1),p(2),'+', ...
                    'MarkerSize',15, ...
                    'Color',[0 1 1], ...
                    'LineWidth',3, ...
                    'DisplayName',label);            % ========================================================

            % VEL / C1 END

            % BLUE DIAMOND

            % ========================================================

            case 'VEL'

                plot(ax,p(1),p(2),'d', ...
                    'MarkerSize',12, ...
                    'MarkerFaceColor','b', ...
                    'MarkerEdgeColor','w', ...
                    'Color','b', ...
                    'LineWidth',2.2, ...
                    'DisplayName',label);

            % ========================================================

            % C1 nearest point to VEL

            % BLUE HOLLOW CIRCLE

            % ========================================================

            case 'C1_NEAREST'

                plot(ax,p(1),p(2),'o', ...
                    'MarkerSize',10, ...
                    'MarkerFaceColor','none', ...
                    'MarkerEdgeColor','b', ...
                    'Color','b', ...
                    'LineWidth',2.2, ...
                    'DisplayName',label);

            % ========================================================

            % C1 bracket i

            % BLUE SQUARE

            % ========================================================

            case 'C1_BRACKET'

                plot(ax,p(1),p(2),'s', ...
                    'MarkerSize',10, ...
                    'MarkerFaceColor','none', ...
                    'MarkerEdgeColor','b', ...
                    'Color','b', ...
                    'LineWidth',2.2, ...
                    'DisplayName',label);

            % ========================================================

            % C1 bracket i+1

            % CYAN SQUARE

            % ========================================================

            case 'C1_BRACKET2'

                plot(ax,p(1),p(2),'s', ...
                    'MarkerSize',10, ...
                    'MarkerFaceColor','none', ...
                    'MarkerEdgeColor','c', ...
                    'Color','c', ...
                    'LineWidth',2.2, ...
                    'DisplayName',label);

            % ========================================================

            % C2 bracket i

            % ORANGE SQUARE

            % ========================================================

            case 'C2_BRACKET'

                plot(ax,p(1),p(2),'s', ...
                    'MarkerSize',10, ...
                    'MarkerFaceColor','none', ...
                    'MarkerEdgeColor',[1 0.5 0], ...
                    'Color',[1 0.5 0], ...
                    'LineWidth',2.2, ...
                    'DisplayName',label);

            % ========================================================

            % C2 bracket i+1

            % MAGENTA SQUARE

            % ========================================================

            case 'C2_BRACKET2'

                plot(ax,p(1),p(2),'s', ...
                    'MarkerSize',10, ...
                    'MarkerFaceColor','none', ...
                    'MarkerEdgeColor','m', ...
                    'Color','m', ...
                    'LineWidth',2.2, ...
                    'DisplayName',label);

            % ========================================================

            % C2 END

            % C2 END = MAGENTA TRIANGLE

            % ========================================================

            case 'C2_END'

                plot(ax,p(1),p(2),'^', ...
                    'MarkerSize',13, ...
                    'MarkerFaceColor','m', ...
                    'MarkerEdgeColor','w', ...
                    'Color','m', ...
                    'LineWidth',2.2, ...
                    'DisplayName',label);

            otherwise

                plot(ax,p(1),p(2),style, ...
                    'MarkerSize',11, ...
                    'LineWidth',2, ...
                    'DisplayName',label);

        end

    end

end

function plotLine(ax,p,d,style,label)

    p=double(p(:)).'; d=double(d(:)).';

    if numel(p)==2 && numel(d)==2 && all(isfinite([p d])) && norm(d)>eps

        d=d./norm(d);

        % Clip a long construction line to the 68x68 image rectangle.

        q=[p-100*d; p+100*d];

        plot(ax,q(:,1),q(:,2),style,'LineWidth',2.2,'DisplayName',label,'Clipping','on');

    end

end

function arrangeDetectionFigure(fig,ax1,ax2,ax3,ax4,ax5,ax6)

    % ================================================================

    % ARRANGE SIX DETECTION PANELS + FIXED ANNOTATION LEGEND

    %

    % Important:

    %   - Detection geometry is NOT changed.

    %   - All point/bracket symbols remain on the MRI panels.

    %   - Point names are NOT written beside the MRI points.

    %   - A fixed legend is placed on the right side.

    % ================================================================

    % ------------------------------------------------

    % Arrange the six main panels

    % ------------------------------------------------

    pos = [

        0.025 0.53 0.245 0.37;

        0.285 0.53 0.245 0.37;

        0.545 0.53 0.245 0.37;

        0.025 0.07 0.245 0.37;

        0.285 0.07 0.245 0.37;

        0.545 0.07 0.245 0.37

        ];

    axs = [ax1 ax2 ax3 ax4 ax5 ax6];

    for k = 1:6

        if isgraphics(axs(k),'axes')

            set(axs(k),'Position',pos(k,:));

        end

    end

    % ------------------------------------------------

    % Remove old legend axes if figure is reused

    % ------------------------------------------------

    old = findall(fig,'Type','axes','Tag','AnnotationLegendAxes');

    if ~isempty(old)

        delete(old);

    end

    % ------------------------------------------------

    % Create fixed legend area

    % ------------------------------------------------

    legAx = axes( ...
        'Parent',fig, ...
        'Position',[0.805 0.08 0.175 0.81], ...
        'Visible','off', ...
        'Tag','AnnotationLegendAxes');

    hold(legAx,'on');

    % ================================================================

    % Create dummy graphics objects for legend

    %

    % IMPORTANT:

    % Do NOT use add(...).

    % MATLAB does not have an add() function here.

    % ================================================================

% ================================================================

% LEGEND SYMBOLS

% These MUST exactly match plotPoint()

% ================================================================

h = gobjects(18,1);

% ------------------------------------------------

% Contours

% ------------------------------------------------

h(1) = plot(legAx,NaN,NaN,'r-', ...
    'LineWidth',1.8);

h(2) = plot(legAx,NaN,NaN,'b-', ...
    'LineWidth',1.8);

h(3) = plot(legAx,NaN,NaN,'g-', ...
    'LineWidth',1.8);

% ------------------------------------------------

% L

% ------------------------------------------------

h(4) = plot(legAx,NaN,NaN,'s', ...
    'MarkerSize',8, ...
    'MarkerFaceColor','w', ...
    'MarkerEdgeColor','k', ...
    'Color','k', ...
    'LineWidth',1.8);

% ------------------------------------------------

% UL

% ------------------------------------------------

h(5) = plot(legAx,NaN,NaN,'*', ...
    'MarkerSize',12, ...
    'Color',[1 0.5 0], ...
    'LineWidth',2.0);

% ------------------------------------------------

% LL

% ------------------------------------------------

h(6) = plot(legAx,NaN,NaN,'+', ...
    'MarkerSize',12, ...
    'Color',[0 1 1], ...
    'LineWidth',2.5);

% ------------------------------------------------

% VEL / C1 END

% BLUE DIAMOND

% ------------------------------------------------

h(7) = plot(legAx,NaN,NaN,'d', ...
    'MarkerSize',10, ...
    'MarkerFaceColor','b', ...
    'MarkerEdgeColor','w', ...
    'Color','b', ...
    'LineWidth',1.8);

% ------------------------------------------------

% C1 nearest VEL

% BLUE HOLLOW CIRCLE

% ------------------------------------------------

h(8) = plot(legAx,NaN,NaN,'o', ...
    'MarkerSize',9, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor','b', ...
    'Color','b', ...
    'LineWidth',1.8);

% ------------------------------------------------

% C1 bracket i

% BLUE HOLLOW SQUARE

% ------------------------------------------------

h(9) = plot(legAx,NaN,NaN,'s', ...
    'MarkerSize',9, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor','b', ...
    'Color','b', ...
    'LineWidth',1.8);

% ------------------------------------------------

% C1 bracket i+1

% CYAN HOLLOW SQUARE

% ------------------------------------------------

h(10) = plot(legAx,NaN,NaN,'s', ...
    'MarkerSize',9, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor','c', ...
    'Color','c', ...
    'LineWidth',1.8);

% ------------------------------------------------

% C2 bracket i

% ORANGE HOLLOW SQUARE

% ------------------------------------------------

h(11) = plot(legAx,NaN,NaN,'s', ...
    'MarkerSize',9, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor',[1 0.5 0], ...
    'Color',[1 0.5 0], ...
    'LineWidth',1.8);

% ------------------------------------------------

% C2 bracket i+1

% MAGENTA HOLLOW SQUARE

% ------------------------------------------------

h(12) = plot(legAx,NaN,NaN,'s', ...
    'MarkerSize',9, ...
    'MarkerFaceColor','none', ...
    'MarkerEdgeColor','m', ...
    'Color','m', ...
    'LineWidth',1.8);

% ------------------------------------------------

% C2 END

% MAGENTA PENTAGRAM

% ------------------------------------------------

h(13) = plot(legAx,NaN,NaN,'^', ...
    'MarkerSize',11, ...
    'MarkerFaceColor','m', ...
    'MarkerEdgeColor','w', ...
    'Color','m', ...
    'LineWidth',1.8);

% ------------------------------------------------

% Construction lines

% ------------------------------------------------

h(14) = plot(legAx,NaN,NaN,'c--', ...
    'LineWidth',1.1);

h(15) = plot(legAx,NaN,NaN,'y-', ...
    'LineWidth',1.1);

h(16) = plot(legAx,NaN,NaN,'k-', ...
    'LineWidth',1.1);

h(17) = plot(legAx,NaN,NaN,'m--', ...
    'LineWidth',1.1);

h(18) = plot(legAx,NaN,NaN,'m-', ...
    'LineWidth',1.1);

labels = { ...
    'C1 contour', ...
    'C2 contour', ...
    'C3 contour', ...
    'L (reference)', ...
    'UL - Upper Lip', ...
    'LL - Lower Lip', ...
    'VEL / C1 END', ...
    'C1 index nearest VEL', ...
    'UL bracket i', ...
    'UL bracket i+1', ...
    'LL bracket i', ...
    'LL bracket i+1', ...
    'C2 END', ...
    'C1 START perpendicular', ...
    'C1 START anatomical axis', ...
    'C1 incoming tangent', ...
    'C2 START perpendicular', ...
    'C2 START anatomical axis' ...
    };

    % ================================================================

    % Create MATLAB legend

    % ================================================================

    lgd = legend( ...
        legAx, ...
        h, ...
        labels, ...
        'Location','northwest', ...
        'Box','on', ...
        'FontSize',8, ...
        'Interpreter','none');

    % Legend appearance

    lgd.Color = 'w';

    lgd.TextColor = 'k';

    lgd.EdgeColor = [0.2 0.2 0.2];

    % Legend title

    lgd.Title.String = 'ANNOTATION LEGEND';

    lgd.Title.FontWeight = 'bold';

    hold(legAx,'off');

end

function arc = getContourArc(C, iStart, iEnd, pStart, pEnd)

    % Build a contour arc using the nearest actual contour indices.

    % Detection helper outputs may be vectors or interpolated values, so

    % do not use them directly as MATLAB colon operands.

    if isempty(C) || ~isnumeric(C) || size(C,2) ~= 2

        error('Cannot construct oral area: contour must be a nonempty Nx2 array.');

    end

    C = double(C);

    pStart = double(pStart(:)).';

    pEnd = double(pEnd(:)).';

    if numel(pStart) ~= 2 || numel(pEnd) ~= 2 || ...
            any(~isfinite([pStart pEnd]))

        error('Cannot construct oral area: invalid endpoint coordinates.');

    end

    % Find scalar contour indices from endpoint coordinates.

    dStart = sum((C - pStart).^2, 2);

    dEnd = sum((C - pEnd).^2, 2);

    [~, iStartScalar] = min(dStart);

    [~, iEndScalar] = min(dEnd);

    lo = min(iStartScalar, iEndScalar);

    hi = max(iStartScalar, iEndScalar);

    segment = C(lo:hi,:);

    % Orient the arc from pStart to pEnd.

    forwardCost = norm(segment(1,:) - pStart) + ...
                  norm(segment(end,:) - pEnd);

    reverseCost = norm(segment(end,:) - pStart) + ...
                  norm(segment(1,:) - pEnd);

    if reverseCost < forwardCost

        segment = flipud(segment);

    end

    arc = [pStart; segment; pEnd];

    % Remove consecutive duplicate vertices.

    if size(arc,1) > 1

        keep = [true; any(abs(diff(arc,1,1)) > 1e-9, 2)];

        arc = arc(keep,:);

    end

end

function data = readPhonemeAlignment(filePath)

    raw = readlines(filePath);
    raw = strtrim(raw);
    starts = [];
    ends = [];
    labels = strings(0,1);

    for i = 1:numel(raw)
        line = char(raw(i));
        if isempty(strtrim(line)), continue; end
        tok = regexp(line,'^\s*([0-9]*\.?[0-9]+)\s+([0-9]*\.?[0-9]+)\s+(\S+)\s*$','tokens','once');
        if isempty(tok), continue; end
        starts(end+1,1) = str2double(tok{1}); %#ok<AGROW>
        ends(end+1,1) = str2double(tok{2}); %#ok<AGROW>
        labels(end+1,1) = string(tok{3}); %#ok<AGROW>
    end

    if isempty(starts)
        error('No valid phoneme timing rows found in %s.',filePath);
    end

    [starts,ord] = sort(starts);
    ends = ends(ord);
    labels = labels(ord);
    if any(ends < starts)
        error('Phoneme alignment contains an end time earlier than its start time.');
    end

    data.startTime = starts;
    data.endTime = ends;
    data.label = labels;
end

function audioTime = mapFrameToAudioTime(frameIdx,nFrames,frameTime,audioEndTime,mode)

    switch lower(mode)
        case 'direct_time'
            audioTime = frameTime;
        case 'normalized_sequence'
            if nFrames <= 1
                audioTime = 0;
            else
                audioTime = (double(frameIdx)-1) / (double(nFrames)-1) * audioEndTime;
            end
        otherwise
            error('Unknown phonemeAlignmentMode: %s',mode);
    end
end

function out = findPhonemeAtTime(data,t)

    out = emptyPhonemeResult();
    if isempty(data) || ~isfinite(t), return; end

    idx = find(t >= data.startTime & t < data.endTime,1,'first');
    if isempty(idx) && abs(t-data.endTime(end)) < 1e-9
        idx = numel(data.endTime);
    end

    if isempty(idx)
        dist = zeros(numel(data.startTime),1);
        for k = 1:numel(dist)
            if t < data.startTime(k)
                dist(k) = data.startTime(k)-t;
            elseif t > data.endTime(k)
                dist(k) = t-data.endTime(k);
            end
        end
        [~,idx] = min(dist);
        out.outsideRange = true;
    else
        out.outsideRange = false;
    end

    out.label = char(data.label(idx));
    out.startTime = data.startTime(idx);
    out.endTime = data.endTime(idx);
end

function out = emptyPhonemeResult()
    out.label = 'N/A';
    out.startTime = NaN;
    out.endTime = NaN;
    out.outsideRange = true;
end

function addPhonemeAnnotation(ax,audioTime,phoneme,frameIdx,nFrames,accValue,accLabel)

    if isempty(phoneme) || ~isfinite(audioTime), return; end

    if isfield(phoneme,'outsideRange') && phoneme.outsideRange
        rangeNote = 'nearest TXT interval';
    else
        rangeNote = 'matched TXT interval';
    end

    % Draw the information INSIDE the MRI axes. This is more reliable than
    % annotation(), especially when saving the figure as PNG.
    txt = sprintf(['PHONEME ANALYSIS\n' ...
                   'Frame: %d / %d\n' ...
                   'Audio time: %.6f s\n' ...
                   'PHONEME: %s\n' ...
                   'TXT interval: %.3f - %.3f s\n' ...
                   '%s: %.6f\n' ...
                   '%s'], ...
                   frameIdx,nFrames,audioTime,phoneme.label,...
                   phoneme.startTime,phoneme.endTime,accLabel,accValue,rangeNote);

    text(ax,2,65,txt, ...
        'Color','w', ...
        'BackgroundColor','k', ...
        'EdgeColor','w', ...
        'FontSize',7, ...
        'FontWeight','bold', ...
        'Interpreter','none', ...
        'VerticalAlignment','bottom', ...
        'HorizontalAlignment','left', ...
        'Margin',2, ...
        'Clipping','on');
end

function out=chooseText(condition,a,b)

    if condition, out=a; else, out=b; end

end
