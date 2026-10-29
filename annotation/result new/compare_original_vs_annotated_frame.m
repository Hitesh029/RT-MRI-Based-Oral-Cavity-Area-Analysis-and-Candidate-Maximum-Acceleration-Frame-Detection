%% Compare an unannotated rt-MRI frame with its annotated version
% Expected MAT variables: imgs (N x 68*68) and annotation struct.
% This script displays existing annotations; it does NOT create annotations.

clear; clc; close all;

matFile = fullfile('annotation','result new', 'M2_034_temp.mat');
frameIdx = 1;  % Actual frame index, from 1 to number of frames
frameSize = [68 68];

if ~isfile(matFile)
    error('MAT file not found: %s. Update matFile to your actual path.', matFile);
end

S = load(matFile);
if ~isfield(S,'imgs') || ~isfield(S,'annotation')
    error('MAT file must contain variables named imgs and annotation.');
end
imgs = S.imgs;
ann = S.annotation;

if frameIdx < 1 || frameIdx > size(imgs,1) || frameIdx ~= floor(frameIdx)
    error('frameIdx must be an integer from 1 to %d.', size(imgs,1));
end
if numel(imgs(frameIdx,:)) ~= prod(frameSize)
    error('Frame size does not match %d x %d. Update frameSize.', frameSize(1), frameSize(2));
end
frame = reshape(double(imgs(frameIdx,:)), frameSize);

fig = figure('Color','w','Name',sprintf('Frame %d: Original vs Annotated',frameIdx), ...
    'Position',[100 100 1100 520]);

% LEFT: original frame without overlays
ax1 = subplot(1,2,1,'Parent',fig);
imagesc(ax1,frame); colormap(ax1,gray(256)); axis(ax1,'image');
set(ax1,'YDir','reverse');
xlim(ax1,[1 frameSize(2)]); ylim(ax1,[1 frameSize(1)]);
title(ax1,sprintf('Original Frame %d (No Annotation)',frameIdx),'FontWeight','bold');
xlabel(ax1,'X (pixels)'); ylabel(ax1,'Y (pixels)');

% RIGHT: frame with saved contours and landmarks
ax2 = subplot(1,2,2,'Parent',fig);
imagesc(ax2,frame); colormap(ax2,gray(256)); axis(ax2,'image');
set(ax2,'YDir','reverse');
xlim(ax2,[1 frameSize(2)]); ylim(ax2,[1 frameSize(1)]);
hold(ax2,'on');
title(ax2,sprintf('Annotated Frame %d',frameIdx),'FontWeight','bold');
xlabel(ax2,'X (pixels)'); ylabel(ax2,'Y (pixels)');

if frameIdx > numel(ann)
    text(ax2,2,5,'No annotation entry for this frame','Color','y','FontWeight','bold');
else
    a = ann(frameIdx);
    contourFields = {'contour1','contour2','contour3'};
    contourNames = {'C1','C2','C3'};
    contourColors = {[1 0.15 0.15],[0.15 0.55 1],[0.2 1 0.35]};

    for k = 1:numel(contourFields)
        fn = contourFields{k};
        if isfield(a,fn) && ~isempty(a.(fn))
            xy = a.(fn);
            if isnumeric(xy) && size(xy,2)==2 && size(xy,1)>=2
                plot(ax2,xy(:,1),xy(:,2),'-','Color',contourColors{k}, ...
                    'LineWidth',1.5,'DisplayName',contourNames{k});
            else
                warning('Frame %d: %s is not a valid Nx2 contour.',frameIdx,fn);
            end
        else
            warning('Frame %d: %s is empty or missing.',frameIdx,fn);
        end
    end

    landmarkFields = {'UL','LL','AVR','VEL','GLTB'};
    landmarkColors = {[0 1 1],[1 0.2 1],[1 0.85 0],[1 1 1],[1 0.5 0]};

    for k = 1:numel(landmarkFields)
        fn = landmarkFields{k};
        if isfield(a,fn) && isnumeric(a.(fn)) && numel(a.(fn))>=2
            pt = a.(fn);
            if all(isfinite(pt(1:2)))
                px = pt(1); py = pt(2);
                plot(ax2,px,py,'o','Color',landmarkColors{k}, ...
                    'MarkerFaceColor',landmarkColors{k},'MarkerSize',6, ...
                    'HandleVisibility','off');
                text(ax2,px+1,py-1,fn,'Color',landmarkColors{k}, ...
                    'FontSize',8,'FontWeight','bold','Interpreter','none','Clipping','on');
            else
                warning('Frame %d: landmark %s contains non-finite values.',frameIdx,fn);
            end
        else
            warning('Frame %d: landmark %s is empty or missing.',frameIdx,fn);
        end
    end
    legend(ax2,'Location','southoutside','Orientation','horizontal');
end
hold(ax2,'off');

outputPng = sprintf('F3_027_frame_%03d_comparison.png',frameIdx);
exportgraphics(fig,outputPng,'Resolution',200);
fprintf('Displayed frame %d. Comparison image saved as: %s\n',frameIdx,outputPng);
