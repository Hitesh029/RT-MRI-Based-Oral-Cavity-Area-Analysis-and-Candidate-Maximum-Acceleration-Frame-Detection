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
matFileName = 'M1_034_temp.mat';
matFilePath = fullfile(pwd, matFileName);
frameDelay = 0.1;                 % seconds each frame remains visible
tolerancePx = 3.0;
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

% Store oral cavity area for every frame (pixel^2)
areaPixels = nan(nFrames,1);

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
        [LL, idxLL, tauLL] = findC2Start(C2, L, axisA, UL);
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
        plotContour(ax1,C2raw,'g-','C2 raw');
        plotContour(ax1,C3raw,'c-','C3 raw');
        title(ax1,'Input: MRI + raw contours');

        ax2 = subplot(2,3,2,'Parent',fig);
        drawMRI(ax2,MRI); hold(ax2,'on');
        plotContour(ax2,C1,'r-','C1');
        plotPoint(ax2,L,'ks','L');
        plotPoint(ax2,UL,'y*','UL');
        plotPoint(ax2,C1(idxUL,:),'bs','UL bracket i');
        plotPoint(ax2,C1(idxUL+1,:),'ms','UL bracket i+1');
        perpAxis = [-axisA(2), axisA(1)];
        plotLine(ax2,L,perpAxis,'c--','Anterior perpendicular through L');
        plotLine(ax2,L,axisA,'y--','Axis L to manual VEL');
        title(ax2,'C1 START: axis, L, perpendicular, UL');

        ax3 = subplot(2,3,3,'Parent',fig);
        drawMRI(ax3,MRI); hold(ax3,'on');
        plotContour(ax3,C1,'r-','C1');
        plotContour(ax3,C3p,'c-','C3');
        plotPoint(ax3,VEL,'b*','VEL');
        plotPoint(ax3,C1(velIdx,:),'bs',sprintf('C1 index %d',velIdx));
        title(ax3,sprintf('C1 END / VEL (gap %.2f px)',gapDist));

        ax4 = subplot(2,3,4,'Parent',fig);
        drawMRI(ax4,MRI); hold(ax4,'on');
        plotContour(ax4,C2,'g-','C2');
        plotPoint(ax4,L,'ks','L');
        plotPoint(ax4,LL,'y+','LL');
        plotPoint(ax4,C2(idxLL(1),:),'bs','LL bracket i');
        if numel(idxLL) > 1 && idxLL(2) ~= idxLL(1) && idxLL(2) <= size(C2,1)
            plotPoint(ax4,C2(idxLL(2),:),'ms','LL bracket i+1');
        end
        plotLine(ax4,L,perpAxis,'c--','Anterior perpendicular through L');
        plotLine(ax4,L,axisA,'y--','Axis L to manual VEL');
        title(ax4,'C2 START: axis, L, perpendicular, LL');

        ax5 = subplot(2,3,5,'Parent',fig);
        drawMRI(ax5,MRI); hold(ax5,'on');
        plotContour(ax5,C1,'r-','C1');
        plotContour(ax5,C2,'g-','C2');
        plotPoint(ax5,VEL,'b*','VEL');
        plotPoint(ax5,C2(idxC2end(1),:),'bs','C2 bracket i');
        if numel(idxC2end) > 1 && idxC2end(2) ~= idxC2end(1) && idxC2end(2) <= size(C2,1)
            plotPoint(ax5,C2(idxC2end(2),:),'ms','C2 bracket i+1');
        end
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
        plotContour(ax6,C2,'g-','C2');
        plotContour(ax6,C3p,'c-','C3');
        plotPoint(ax6,UL,'y*','UL');
        plotPoint(ax6,LL,'y+','LL');
        plotPoint(ax6,VEL,'b*','VEL');
        plotPoint(ax6,C2end,'m*','C2 END');
        title(ax6,sprintf('FINAL | Frame %d/%d | %s',frameIdx,nFrames, ...
            chooseText(isValid,'VALID','VALIDATION WARNING')));

        sgtitle(fig,sprintf('Frame %d / %d — stage-by-stage anatomical detection', ...
            frameIdx,nFrames),'Color','w','FontWeight','bold');
        drawnow;

        %% Save frame result
        saveResults(outDir, frameIdx, statusTable, UL, LL, VEL, C2end);
        results{frameIdx} = struct( ...
            'UL',UL,'LL',LL,'VEL',VEL,'C2end',C2end, ...
            'idxUL',idxUL,'tauUL',tauUL, ...
            'idxLL',idxLL,'tauLL',tauLL, ...
            'velIdx',velIdx,'gapDist',gapDist, ...
            'idxC2end',idxC2end,'tauC2end',tauC2end, ...
            'tangentVec',tangentVec,'isValid',isValid, ...
            'areaPixels',areaValue,'areaGeometryOK',areaGeometryOK);
        status(frameIdx) = chooseText(isValid,'VALID','VALIDATION WARNING');
        fprintf('Frame %d completed: UL, LL, VEL, C2 END detected.\n', frameIdx);
        fprintf('  UL=(%.3f, %.3f), LL=(%.3f, %.3f)\n', UL, LL);
        fprintf('  VEL=(%.3f, %.3f), C2 END=(%.3f, %.3f)\n', VEL, C2end);
        if areaGeometryOK
            fprintf('  Oral area = %.4f pixel^2\n', areaValue);
        else
            fprintf('  Oral area = NOT COMPUTED (invalid polygon)\n');
        end

    catch ME
        status(frameIdx) = "FAILED";
        results{frameIdx} = struct('error', ME.message);
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

%% ORAL AREA ANALYSIS

validArea = isfinite(areaPixels);
areaFrames = find(validArea);
areaValues = areaPixels(validArea);

fprintf('\n========== ORAL AREA RESULTS ==========\n');
fprintf('Frames with valid area: %d / %d\n', numel(areaValues), nFrames);

if ~isempty(areaValues)
    fprintf('Minimum oral area: %.4f pixel^2\n', min(areaValues));
    fprintf('Maximum oral area: %.4f pixel^2\n', max(areaValues));

    [maxArea, maxAreaLocalIdx] = max(areaValues);
    maxAreaFrame = areaFrames(maxAreaLocalIdx);

    fprintf('Maximum oral area frame: %d\n', maxAreaFrame);
    fprintf('Maximum oral area: %.4f pixel^2\n', maxArea);

    figure('Color','w','Name','Oral Area vs Frame','NumberTitle','off');
    plot(areaFrames, areaValues, 'LineWidth', 2);
    xlabel('Frame');
    ylabel('Oral Area (pixel^2)');
    title('Oral Area vs Frame');
    grid on;
else
    warning('No valid oral-area measurements were obtained.');
end

save(fullfile(outDir,'all_frames_detection_summary.mat'), ...
    'results','status','areaPixels','matFilePath','frameDelay','tolerancePx');
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
    xlabel(ax,'X'); ylabel(ax,'Y');
end

function plotContour(ax,C,style,label)
    if isnumeric(C) && size(C,2)==2 && ~isempty(C)
        plot(ax,C(:,1),C(:,2),style,'LineWidth',1.3,'DisplayName',label);
    end
end

function plotPoint(ax,p,style,label)
    if isnumeric(p) && numel(p)==2 && all(isfinite(p(:)))
        p=double(p(:));
        plot(ax,p(1),p(2),style,'MarkerSize',9,'LineWidth',1.8, ...
            'DisplayName',label);
        text(ax,p(1)+1,p(2),label,'Color',style(1), ...
            'FontWeight','bold','FontSize',7,'Clipping','on');
    end
end

function plotLine(ax,p,d,style,label)
    p=double(p(:)).'; d=double(d(:)).';
    if numel(p)==2 && numel(d)==2 && all(isfinite([p d])) && norm(d)>eps
        d=d./norm(d);
        % Clip a long construction line to the 68x68 image rectangle.
        q=[p-100*d; p+100*d];
        plot(ax,q(:,1),q(:,2),style,'LineWidth',1.1,'DisplayName',label);
    end
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

function out=chooseText(condition,a,b)
    if condition, out=a; else, out=b; end
end
