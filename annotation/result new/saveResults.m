function saveResults(outDir, frameIdx, statusTable, UL, LL, VEL, C2end)
% SAVERESULTS  Save the result table (.csv), a .mat with all four
% points, and every currently-open figure, into outDir.

    fprintf('========== SAVE RESULTS ==========\n');

    if ~isfolder(outDir)
        mkdir(outDir);
        fprintf('Created output folder: %s\n', outDir);
    end

    csvPath = fullfile(outDir, sprintf('frame%d_results.csv', frameIdx));
    writetable(statusTable, csvPath);
    fprintf('Saved results table -> %s\n', csvPath);

    matPath = fullfile(outDir, sprintf('frame%d_points.mat', frameIdx));
    save(matPath, 'UL', 'LL', 'VEL', 'C2end', 'frameIdx');
    fprintf('Saved point data -> %s\n', matPath);

    figs = findall(0, 'Type', 'figure');
    for i = 1:numel(figs)
        figName = get(figs(i), 'Name');
        if isempty(figName)
            figName = sprintf('figure%d', i);
        end
        safeName = regexprep(figName, '[^a-zA-Z0-9_]', '_');
        figPath = fullfile(outDir, sprintf('frame%d_%s.png', frameIdx, safeName));
        exportgraphics(figs(i), figPath);
        fprintf('Saved figure -> %s\n', figPath);
    end

    fprintf('================================\n\n');
end
