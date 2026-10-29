
%% makeAllFramesVideo.m
% Render all MRI frames with stored C1/C2/C3 contours and manual landmarks.
% This visualization does not require automatic UL/LL/VEL detection.
clear; clc; close all;

matFilePath = fullfile(pwd, 'M1_034_temp.mat');
outputVideo = 'M3_034_Anatomical_Contours_All_Frames.mp4';
fps = 0.2;
imageSize = [68 68];

if ~isfile(matFilePath)
    error('MAT file not found: %s',matFilePath);
end
S = load(matFilePath,'annotation','imgs');
if ~isfield(S,'annotation') || ~isfield(S,'imgs')
    error('MAT file must contain annotation and imgs.');
end
annotation = S.annotation;
imgs = S.imgs;
nFrames = numel(annotation);
if size(imgs,1) < nFrames
    error('imgs rows (%d) are fewer than annotation frames (%d).',size(imgs,1),nFrames);
end

fprintf('MAT file: %s\\nFrames: %d\\n',matFilePath,nFrames);
fprintf('Frame 1 contour field sizes (raw):\\n');
for nm = {'contour1','contour2','contour3'}
    raw = getField(annotation(1),nm{1});
    fprintf('  %s: %s, class=%s, empty=%d\\n',nm{1},mat2str(size(raw)),class(raw),isempty(raw));
end

vw = VideoWriter(outputVideo,'MPEG-4');
vw.FrameRate = fps;
open(vw);
cleanupObj = onCleanup(@() safeClose(vw)); %#ok<NASGU>
fig = figure('Color','black','Name','MRI contours','NumberTitle','off','Visible','on');
ax = axes('Parent',fig);
counts = zeros(1,3);
written = 0;

for k = 1:nFrames
    fr = annotation(k);
    imageRow = imgs(k,:);
    if numel(imageRow) ~= prod(imageSize)
        warning('Frame %d: image has %d values; expected %d. Skipping.',k,numel(imageRow),prod(imageSize));
        continue;
    end
    MRI = reshape(imageRow,imageSize);

    raw1=getField(fr,'contour1'); raw2=getField(fr,'contour2'); raw3=getField(fr,'contour3');
    C1=safeContour(raw1,'C1',k); C2=safeContour(raw2,'C2',k); C3=safeContour(raw3,'C3',k);
    counts = counts + [~isempty(C1),~isempty(C2),~isempty(C3)];

    % Detect C2 END using the established geometric solution:
    % estimate the incoming C1 tangent at VEL, then intersect C2 with
    % the line through VEL perpendicular to that tangent.
    C2end = [];
    vel = getField(fr,'VEL');
    if ~isempty(C1) && ~isempty(C2) && isnumeric(vel) && numel(vel)==2 && all(isfinite(vel(:)))
        vel = double(vel(:)).';
        [~, velIdx] = min(sum((double(C1) - vel).^2, 2));
        try
            [C2end, ~, ~, ~] = findC2End(C1, C2, vel, velIdx);
        catch ME
            warning('Frame %d: C2 END could not be detected: %s',k,ME.message);
        end
    else
        warning('Frame %d: C2 END skipped (C1/C2/VEL unavailable or invalid).',k);
    end

    cla(ax);
    imagesc(ax,MRI); colormap(ax,gray(256)); axis(ax,'image'); hold(ax,'on');
    if ~isempty(C1), plot(ax,C1(:,1),C1(:,2),'r-','LineWidth',1.6); end
    if ~isempty(C2), plot(ax,C2(:,1),C2(:,2),'g-','LineWidth',1.6); end
    if ~isempty(C3), plot(ax,C3(:,1),C3(:,2),'c-','LineWidth',1.6); end

    drawPoint(ax,getField(fr,'UL'),'y*','UL');
    drawPoint(ax,getField(fr,'LL'),'y+','LL');
    drawPoint(ax,getField(fr,'VEL'),'b*','VEL');
    if ~isempty(C2end)
        drawPoint(ax,C2end,'mo','C2 END');
    end
    title(ax,sprintf('MRI Frame %d / %d',k,nFrames),'Color','w','FontWeight','bold');
    xlabel(ax,'X'); ylabel(ax,'Y');
    set(ax,'YDir','reverse','Color','black','XColor','w','YColor','w');
    xlim(ax,[0.5 imageSize(2)+0.5]); ylim(ax,[0.5 imageSize(1)+0.5]);
    hold(ax,'off'); drawnow;
    writeVideo(vw,getframe(fig)); written=written+1;
end
close(vw); close(fig);
fprintf('\\nVideo finalized: %s\\nFrames written: %d/%d\\n',outputVideo,written,nFrames);
fprintf('Frames with C1: %d/%d | C2: %d/%d | C3: %d/%d\\n',counts(1),nFrames,counts(2),nFrames,counts(3),nFrames);
if all(counts==0)
    warning('All contour fields were empty/unsupported. Video contains MRI and any valid manual landmarks only. Inspect raw field sizes printed above.');
end

function v=getField(s,name)
    if isfield(s,name), v=s.(name); else, v=[]; end
end
function C=safeContour(raw,name,frameIdx)
    C=[];
    if isempty(raw)
        warning('Frame %d: %s is empty in annotation.',frameIdx,name); return;
    end
    try
        C=preprocessData(raw,name);
    catch ME
        warning('Frame %d: %s could not be normalized: %s',frameIdx,name,ME.message);
    end
end
function drawPoint(ax,p,style,label)
    if isnumeric(p) && numel(p)==2 && all(isfinite(p(:)))
        p=double(p(:)); plot(ax,p(1),p(2),style,'MarkerSize',11,'LineWidth',2);
        text(ax,p(1)+1,p(2),label,'Color',style(1),'FontWeight','bold','FontSize',8,'Clipping','on');
    end
end
function safeClose(vw)
    try, if isvalid(vw), close(vw); end, catch, end
end
