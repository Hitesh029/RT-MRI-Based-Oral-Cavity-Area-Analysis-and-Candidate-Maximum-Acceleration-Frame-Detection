%% makeAllFramesVideo.m
% Generate an MP4 showing every MRI frame and available contours/landmarks.
% C1 = red, C2 = green, C3 = cyan. No circle markers are used.

clear;
clc;
close all;

%% CONFIGURATION
matFilePath = 'M2_358_temp.mat';
outputVideo = 'MRI_Anatomical_Contours_All_Frames.mp4';
tolerancePx = 3.0;
fps = 5;

%% LOAD DATASET
fprintf('\n============================================================\n');
fprintf('        ALL FRAME MRI VIDEO GENERATION\n');
fprintf('============================================================\n\n');

if ~isfile(matFilePath)
    error('MAT file not found: %s. Set matFilePath to the correct file.', matFilePath);
end

S = load(matFilePath);

if ~isfield(S,'annotation')
    error('Missing variable "annotation" in %s.', matFilePath);
end
if ~isfield(S,'imgs')
    error('Missing variable "imgs" in %s.', matFilePath);
end

annotation = S.annotation;
imgs = S.imgs;
numFrames = numel(annotation);

if size(imgs,1) < numFrames
    error('imgs has %d rows but annotation has %d frames.', size(imgs,1), numFrames);
end

fprintf('Total frames = %d\n', numFrames);

%% CREATE VIDEO
video = VideoWriter(outputVideo,'MPEG-4');
video.FrameRate = fps;
open(video);
videoCleanup = onCleanup(@() close(video)); %#ok<NASGU>

%% FIGURE
fig = figure('Color','black', ...
    'Name','MRI Anatomical Contour Video', ...
    'NumberTitle','off', ...
    'Visible','on');

framesWritten = 0;

%% PROCESS EVERY FRAME
for frameIdx = 1:numFrames
    fprintf('Processing frame %d / %d\n',frameIdx,numFrames);

    fr = annotation(frameIdx);

    % MRI image: support flattened 68x68 rows or already-shaped frames.
    frameVector = imgs(frameIdx,:);
    if numel(frameVector) ~= 68*68
        warning('Frame %d: expected 4624 image pixels, got %d. Skipping frame.', ...
            frameIdx,numel(frameVector));
        continue;
    end
    MRI = reshape(frameVector,68,68);

    % Read contours safely.
    C1raw = getFieldOrEmpty(fr,'contour1');
    C2raw = getFieldOrEmpty(fr,'contour2');
    C3raw = getFieldOrEmpty(fr,'contour3');

    C1 = preprocessIfValid(C1raw,'C1',frameIdx);
    C2 = preprocessIfValid(C2raw,'C2',frameIdx);
    C3 = preprocessIfValid(C3raw,'C3',frameIdx);

    % Manual landmarks.
    UL_manual = getFieldOrEmpty(fr,'UL');
    LL_manual = getFieldOrEmpty(fr,'LL');
    VEL_manual = getFieldOrEmpty(fr,'VEL');

    % Initialize outputs so every frame can still be written.
    UL = UL_manual;
    LL = LL_manual;
    VEL = VEL_manual;
    C2end = [];
    velIdx = [];
    idxUL = [];
    idxLL = [];
    idxC2end = [];
    tangentVec = [];

    % Reference point L = midpoint of manual UL and LL where available.
    L = [];
    if isValidPoint(UL_manual) && isValidPoint(LL_manual)
        L = (UL_manual(:).' + LL_manual(:).') / 2;
    elseif isValidPoint(UL_manual)
        L = UL_manual(:).';
    elseif isValidPoint(LL_manual)
        L = LL_manual(:).';
    end

    % Axis from L toward manual VEL.
    axisA = [];
    if isValidPoint(L) && isValidPoint(VEL_manual)
        axisVec = VEL_manual(:).' - L;
        axisNorm = norm(axisVec);
        if axisNorm > eps
            axisA = axisVec / axisNorm;
        end
    end

    % C1 start.
    if ~isempty(C1) && ~isempty(L) && ~isempty(axisA)
        try
            [UL,idxUL,~] = findC1Start(C1,L,axisA);
        catch ME
            warning('Frame %d: C1 start failed; showing manual UL if available. %s', ...
                frameIdx,ME.message);
            UL = UL_manual;
        end
    end

    % C2 start (LL): manual annotation disambiguates crossings when available.
    if ~isempty(C2) && ~isempty(L) && ~isempty(axisA)
        try
            if isValidPoint(LL_manual)
                [LL,idxLL,~] = findC2Start(C2,L,axisA,LL_manual(:).');
            else
                [LL,idxLL,~] = findC2Start(C2,L,axisA);
            end
        catch ME
            warning('Frame %d: C2 start failed; showing manual LL if available. %s', ...
                frameIdx,ME.message);
            LL = LL_manual;
        end
    end

    % C1 end / VEL. If automatic detection fails, retain manual VEL.
    if ~isempty(C1) && isValidPoint(VEL_manual)
        try
            [VEL,velIdx,~] = findC1End(C1,C3,tolerancePx,VEL_manual(:).');
        catch ME
            warning('Frame %d: C1 end failed; using manual VEL. %s', ...
                frameIdx,ME.message);
            VEL = VEL_manual(:).';
            [~,velIdx] = min(vecnorm(C1 - VEL,2,2));
        end
    end

    % C2 end.
    if ~isempty(C1) && ~isempty(C2) && isValidPoint(VEL) && ...
            ~isempty(velIdx) && ~isempty(velIdx) && velIdx >= 1 && velIdx <= size(C1,1)
        try
            [C2end,idxC2end,~,tangentVec] = findC2End(C1,C2,VEL,velIdx);
        catch ME
            warning('Frame %d: C2 end could not be detected. %s', ...
                frameIdx,ME.message);
            C2end = [];
        end
    end

    %% DRAW FRAME (always draw MRI, even when contours are missing)
    clf(fig);
    ax = axes('Parent',fig);
    imagesc(ax,MRI);
    colormap(ax,gray(256));
    axis(ax,'image');
    hold(ax,'on');

    if ~isempty(C1)
        plot(ax,C1(:,1),C1(:,2),'r-','LineWidth',1.5);
    end
    if ~isempty(C2)
        plot(ax,C2(:,1),C2(:,2),'g-','LineWidth',1.5);
    end
    if ~isempty(C3)
        plot(ax,C3(:,1),C3(:,2),'c-','LineWidth',1.5);
    end

    % Landmarks use star/plus markers, never circle markers.
    drawLandmark(ax,UL,'y*','UL');
    drawLandmark(ax,LL,'y+','LL');
    drawLandmark(ax,VEL,'b*','VEL');
    drawLandmark(ax,C2end,'m*','C2 END');

    title(ax,sprintf('MRI Frame %d / %d',frameIdx,numFrames), ...
        'Color','white','FontWeight','bold');
    xlabel(ax,'X');
    ylabel(ax,'Y');
    set(ax,'YDir','reverse','Color','black','XColor','white','YColor','white');
    xlim(ax,[0.5 68.5]);
    ylim(ax,[0.5 68.5]);
    hold(ax,'off');

    drawnow;
    videoFrame = getframe(fig);
    writeVideo(video,videoFrame);
    framesWritten = framesWritten + 1;
end

% Close explicitly before reporting, so the MP4 container is finalized.
close(video);
close(fig);

fprintf('\n============================================================\n');
fprintf('VIDEO COMPLETE\n');
fprintf('Frames written : %d / %d\n',framesWritten,numFrames);
fprintf('FPS            : %g\n',fps);
fprintf('Output file    : %s\n',outputVideo);
fprintf('============================================================\n');

%% LOCAL FUNCTIONS
function value = getFieldOrEmpty(s,fieldName)
    if isfield(s,fieldName)
        value = s.(fieldName);
    else
        value = [];
    end
end

function tf = isValidPoint(p)
    tf = isnumeric(p) && numel(p) == 2 && all(isfinite(p(:)));
end

function contour = preprocessIfValid(raw,name,frameIdx)
    contour = [];
    if isempty(raw) || ~isnumeric(raw) || size(raw,2) ~= 2 || size(raw,1) < 2
        warning('Frame %d: %s contour is empty or invalid.',frameIdx,name);
        return;
    end
    try
        contour = preprocessData(raw,name);
    catch ME
        warning('Frame %d: %s preprocessing failed: %s', ...
            frameIdx,name,ME.message);
        contour = [];
    end
end

function drawLandmark(ax,p,style,labelText)
    if ~isValidPoint(p)
        return;
    end
    p = p(:).';
    plot(ax,p(1),p(2),style,'MarkerSize',12,'LineWidth',2);
    text(ax,p(1)+1.2,p(2),labelText, ...
        'Color',style(1),'FontWeight','bold','FontSize',8, ...
        'Clipping','on');
end
