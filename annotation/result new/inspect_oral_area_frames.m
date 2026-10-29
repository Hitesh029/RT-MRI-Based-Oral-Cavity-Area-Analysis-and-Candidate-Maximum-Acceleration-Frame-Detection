function inspect_oral_area_frames(matFilePath, summaryMatPath, frames)
% INSPECT_ORAL_AREA_FRAMES
% Visual diagnostic for the actual C1/C2 contour segments and area polygon.
%
% Example:
% inspect_oral_area_frames( ...
%   'M2_034_temp.mat', ...
%   fullfile(pwd,'oral_area_results_indexfix','M2_034_temp', ...
%            'M2_034_temp_oral_area_summary.mat'), [33 34]);
%
% Requires the existing project functions on the MATLAB path:
% loadData, preprocessData, identifyC1, identifyC2.

    if nargin < 1 || isempty(matFilePath)
        matFilePath = 'M2_034_temp.mat';
    end
    if nargin < 2 || isempty(summaryMatPath)
        error('Provide the path to the saved *_oral_area_summary.mat file.');
    end
    if nargin < 3 || isempty(frames)
        frames = [33 34];
    end

    D = load(summaryMatPath, 'results', 'areaPixels');
    if ~isfield(D,'results') || ~isfield(D,'areaPixels')
        error('Summary MAT file must contain results and areaPixels.');
    end

    frames = unique(round(frames(:).'));
    if any(frames < 1 | frames > numel(D.results))
        error('Requested frame number is outside the saved results.');
    end

    nPlot = numel(frames);
    nCols = min(2,nPlot);
    nRows = ceil(nPlot/nCols);
    fig = figure('Color','w','Name','Oral area polygon diagnostic');
    tiledlayout(nRows,nCols,'TileSpacing','compact','Padding','compact');

    for k = 1:nPlot
        f = frames(k);
        r = D.results{f};
        if ~isstruct(r) || isfield(r,'error')
            warning('Frame %d does not have usable saved detections.', f);
            continue;
        end

        data = loadData(matFilePath, f);
        C1 = identifyC1(preprocessData(data.C1, 'C1'));
        C2 = identifyC2(preprocessData(data.C2, 'C2'));

        upperArc = localArc(C1, r.idxUL, r.velIdx, r.UL, r.VEL);
        lowerArc = localArc(C2, r.idxLL, r.idxC2end, r.LL, r.C2end);
        areaPoly = [upperArc; flipud(lowerArc)];
        areaCheck = polyarea(areaPoly(:,1),areaPoly(:,2));

        ax = nexttile;
        imagesc(ax,data.image);
        colormap(ax,gray(256));
        axis(ax,'image');
        set(ax,'YDir','reverse');
        hold(ax,'on');

        % Fill the exact polygon passed to polyarea in the processing code.
        patch(ax,areaPoly(:,1),areaPoly(:,2),[1 0.75 0.1], ...
            'FaceAlpha',0.35,'EdgeColor',[0.9 0.4 0.05], ...
            'LineWidth',1.3,'DisplayName','Area polygon');

        % Full contours for reference; selected segments are overlaid thicker.
        plot(ax,C1(:,1),C1(:,2),'r-','LineWidth',1.0, ...
            'DisplayName','Full C1 contour');
        plot(ax,C2(:,1),C2(:,2),'g-','LineWidth',1.0, ...
            'DisplayName','Full C2 contour');
        plot(ax,upperArc(:,1),upperArc(:,2),'r-','LineWidth',2.8, ...
            'DisplayName','Selected C1 arc: UL to VEL');
        plot(ax,lowerArc(:,1),lowerArc(:,2),'m-','LineWidth',2.8, ...
            'DisplayName','Selected C2 arc: LL to C2 END');

        plot(ax,r.UL(1),r.UL(2),'y*','MarkerSize',10,'LineWidth',1.8, ...
            'DisplayName','UL');
        plot(ax,r.LL(1),r.LL(2),'y+','MarkerSize',10,'LineWidth',1.8, ...
            'DisplayName','LL');
        plot(ax,r.VEL(1),r.VEL(2),'b*','MarkerSize',10,'LineWidth',1.8, ...
            'DisplayName','VEL');
        plot(ax,r.C2end(1),r.C2end(2),'m*','MarkerSize',12,'LineWidth',2.2, ...
            'DisplayName','C2 END');

        % Draw the C2-END cutting line: perpendicular to the C1 tangent.
        t = double(r.tangentVec(:)).';
        if all(isfinite(t)) && norm(t) > eps
            t = t ./ norm(t);
            n = [-t(2), t(1)];
            q = [r.VEL - 100*n; r.VEL + 100*n];
            plot(ax,q(:,1),q(:,2),'c--','LineWidth',1.2, ...
                'DisplayName','C2 END cutting line');
        end

        title(ax,sprintf('Frame %d | saved area %.4f | polygon check %.4f px^2', ...
            f,D.areaPixels(f),areaCheck),'Interpreter','none');
        xlabel(ax,'X'); ylabel(ax,'Y');
        legend(ax,'Location','bestoutside','FontSize',7);
        xlim(ax,[0.5 size(data.image,2)+0.5]);
        ylim(ax,[0.5 size(data.image,1)+0.5]);

        fprintf('\nFrame %d diagnostics\n',f);
        fprintf('  Saved area: %.6f px^2; recomputed polygon area: %.6f px^2\n', ...
            D.areaPixels(f),areaCheck);
        fprintf('  UL=(%.4f, %.4f), indices=%s\n',r.UL(1),r.UL(2),mat2str(r.idxUL));
        fprintf('  VEL=(%.4f, %.4f), C1 index=%d\n',r.VEL(1),r.VEL(2),r.velIdx);
        fprintf('  LL=(%.4f, %.4f), indices=%s\n',r.LL(1),r.LL(2),mat2str(r.idxLL));
        fprintf('  C2 END=(%.4f, %.4f), indices=%s\n', ...
            r.C2end(1),r.C2end(2),mat2str(r.idxC2end));
        fprintf('  C1 selected arc points: %d; C2 selected arc points: %d\n', ...
            size(upperArc,1),size(lowerArc,1));
    end
end

function arc = localArc(C, iStartHint, iEndHint, pStart, pEnd)
    C = double(C);
    pStart = double(pStart(:)).';
    pEnd = double(pEnd(:)).';
    iStart = chooseCandidate(C, iStartHint, pStart);
    iEnd = chooseCandidate(C, iEndHint, pEnd);
    lo = min(iStart,iEnd);
    hi = max(iStart,iEnd);
    seg = C(lo:hi,:);

    forwardCost = norm(seg(1,:)-pStart) + norm(seg(end,:)-pEnd);
    reverseCost = norm(seg(end,:)-pStart) + norm(seg(1,:)-pEnd);
    if reverseCost < forwardCost
        seg = flipud(seg);
    end
    arc = [pStart; seg; pEnd];
    if size(arc,1) > 1
        keep = [true; any(abs(diff(arc,1,1)) > 1e-9,2)];
        arc = arc(keep,:);
    end
end

function idx = chooseCandidate(C, hint, p)
    candidates = round(double(hint(:)));
    candidates = candidates(isfinite(candidates));
    candidates = unique(candidates(candidates >= 1 & candidates <= size(C,1)));
    if isempty(candidates)
        error('No valid detector index candidates were saved for an endpoint.');
    end
    d2 = sum((C(candidates,:) - double(p(:)).').^2,2);
    [~,j] = min(d2);
    idx = candidates(j);
end
