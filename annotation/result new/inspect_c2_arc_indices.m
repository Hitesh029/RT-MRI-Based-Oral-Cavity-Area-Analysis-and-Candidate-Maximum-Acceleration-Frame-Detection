function inspect_c2_arc_indices(matFilePath, summaryMatPath, frames)
% INSPECT_C2_ARC_INDICES
% Diagnose which C2 contour sample indices are used between LL and C2 END.
% This is a visualization/report only; it does not modify the oral-area pipeline.
%
% Example:
% inspect_c2_arc_indices('M2_034_temp.mat', ...
%   fullfile(pwd,'oral_area_results_indexfix','M2_034_temp', ...
%   'M2_034_temp_oral_area_summary.mat'), [33 34]);

    if nargin < 1 || isempty(matFilePath)
        matFilePath = 'M2_034_temp.mat';
    end
    if nargin < 2 || isempty(summaryMatPath)
        error('Provide the path to the saved oral-area summary MAT file.');
    end
    if nargin < 3 || isempty(frames)
        frames = [33 34];
    end

    D = load(summaryMatPath, 'results', 'areaPixels');
    frames = unique(round(frames(:).'));
    if any(frames < 1 | frames > numel(D.results))
        error('Requested frame index is outside the saved results.');
    end

    nF = numel(frames);
    fig = figure('Color','w','Name','C2 arc sample-index diagnostic');
    tiledlayout(1,nF,'TileSpacing','compact','Padding','compact');
    reportRows = {};

    for k = 1:nF
        f = frames(k);
        r = D.results{f};
        if ~isstruct(r) || isfield(r,'error')
            warning('Frame %d has no usable detection result.',f);
            continue;
        end

        data = loadData(matFilePath, f);
        C2 = identifyC2(preprocessData(data.C2,'C2'));

        iLL = chooseCandidate(C2, r.idxLL, r.LL);
        iEnd = chooseCandidate(C2, r.idxC2end, r.C2end);
        lo = min(iLL,iEnd);
        hi = max(iLL,iEnd);
        pathIdx = (lo:hi).';
        seg = C2(pathIdx,:);

        forwardCost = norm(seg(1,:)-r.LL) + norm(seg(end,:)-r.C2end);
        reverseCost = norm(seg(end,:)-r.LL) + norm(seg(1,:)-r.C2end);
        if reverseCost < forwardCost
            pathIdx = flipud(pathIdx);
            seg = flipud(seg);
        end

        ax = nexttile;
        imagesc(ax,data.image);
        colormap(ax,gray(256)); axis(ax,'image');
        set(ax,'YDir','reverse'); hold(ax,'on');

        % Show the full contour (green), then the selected segment (magenta).
        plot(ax,C2(:,1),C2(:,2),'-','Color',[0.1 0.75 0.2], ...
            'LineWidth',1.0,'DisplayName','Full C2 contour');
        plot(ax,seg(:,1),seg(:,2),'m-','LineWidth',2.8, ...
            'DisplayName','Selected LL-to-C2 END segment');
        plot(ax,C2(:,1),C2(:,2),'g.','MarkerSize',7, ...
            'HandleVisibility','off');
        plot(ax,r.LL(1),r.LL(2),'y+','MarkerSize',12,'LineWidth',2, ...
            'DisplayName','Detected LL');
        plot(ax,r.C2end(1),r.C2end(2),'m*','MarkerSize',12,'LineWidth',2, ...
            'DisplayName','Detected C2 END');
        plot(ax,C2(iLL,1),C2(iLL,2),'bo','MarkerSize',7,'LineWidth',1.5, ...
            'DisplayName',sprintf('LL candidate index %d',iLL));
        plot(ax,C2(iEnd,1),C2(iEnd,2),'cs','MarkerSize',7,'LineWidth',1.5, ...
            'DisplayName',sprintf('C2 END candidate index %d',iEnd));

        % Label selected sample indices, spaced to keep figure readable.
        nLabel = min(10,numel(pathIdx));
        labelPos = unique(round(linspace(1,numel(pathIdx),nLabel)));
        for q = labelPos(:).'
            ii = pathIdx(q);
            text(ax,C2(ii,1)+0.45,C2(ii,2)-0.55,sprintf('%d',ii), ...
                'Color','c','FontSize',8,'FontWeight','bold', ...
                'BackgroundColor','k','Margin',1,'Clipping','on');
        end

        title(ax,sprintf('Frame %d | LL idx %d | END idx %d | %d contour samples', ...
            f,iLL,iEnd,numel(pathIdx)),'Interpreter','none');
        xlabel(ax,'X'); ylabel(ax,'Y');
        xlim(ax,[0.5 size(data.image,2)+0.5]);
        ylim(ax,[0.5 size(data.image,1)+0.5]);
        legend(ax,'Location','bestoutside','FontSize',7);

        fprintf('\n===== FRAME %d: C2 ARC INDEX REPORT =====\n',f);
        fprintf('Contour points after preprocessing/identifyC2: %d\n',size(C2,1));
        fprintf('Saved LL hint: %s | Selected actual C2 index: %d | Coordinate: (%.4f, %.4f)\n', ...
            mat2str(r.idxLL),iLL,C2(iLL,1),C2(iLL,2));
        fprintf('Saved C2 END hint: %s | Selected actual C2 index: %d | Coordinate: (%.4f, %.4f)\n', ...
            mat2str(r.idxC2end),iEnd,C2(iEnd,1),C2(iEnd,2));
        fprintf('Selected contiguous contour index range: %d through %d (%d samples)\n', ...
            lo,hi,numel(pathIdx));
        fprintf('Selected path orientation: %d -> %d\n',pathIdx(1),pathIdx(end));
        fprintf('Saved oral area: %.6f px^2\n',D.areaPixels(f));
        fprintf('Labelled selected-path sample indices and coordinates (oriented LL -> C2 END):\n');
        for q = 1:numel(pathIdx)
            ii = pathIdx(q);
            fprintf('  %3d: x=%8.4f, y=%8.4f\n',ii,C2(ii,1),C2(ii,2));
        end

        reportRows(end+1,:) = {f,iLL,iEnd,lo,hi,numel(pathIdx),D.areaPixels(f)}; %#ok<AGROW>
    end

    if ~isempty(reportRows)
        report = cell2table(reportRows,'VariableNames', ...
            {'Frame','SelectedLLIndex','SelectedC2EndIndex','RangeStart','RangeEnd','SampleCount','Area_px2'});
        outCsv = fullfile(fileparts(summaryMatPath),'C2_arc_index_report.csv');
        writetable(report,outCsv);
        fprintf('\nIndex summary CSV saved: %s\n',outCsv);
    end
end

function idx = chooseCandidate(C, hint, endpoint)
    candidates = round(double(hint(:)));
    candidates = candidates(isfinite(candidates));
    candidates = unique(candidates(candidates >= 1 & candidates <= size(C,1)));
    if isempty(candidates)
        error('No valid detector candidate indices were saved for an endpoint.');
    end
    d2 = sum((C(candidates,:) - double(endpoint(:)).').^2,2);
    [~,j] = min(d2);
    idx = candidates(j);
end
