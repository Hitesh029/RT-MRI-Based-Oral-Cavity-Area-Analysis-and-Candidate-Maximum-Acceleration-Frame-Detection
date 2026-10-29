%% batch_oral_area_results_tables.m
% Creates a separate Word-friendly result table for EVERY MAT file/video
% and a combined summary table for all files.
%
% OUTPUTS:
%   1) ALL_FILES_ORAL_AREA_RESULTS.csv
%   2) ALL_FILES_FRAMEWISE.csv
%   3) ONE individual CSV per MAT file: <filename>_OralAreaResults.csv
%   4) Prints a formatted table for each file in Command Window.
%
% IMPORTANT:
% - This script uses an existing area vector only. It does NOT calculate
%   oral area from raw video/contour points by itself.
% - It will ONLY treat a vector as area if its variable name matches a name
%   in areaVariableNames below. It deliberately will NOT guess from arbitrary
%   numeric vectors (e.g., randind), because that can produce false results.
% - Add your actual area-vector variable name to areaVariableNames if needed.
% - Acceleration is calculated with simple second finite differences over
%   frame index; verify against your project's derivative method.
%
% RUN:
%   1) Set inputFolder to the folder containing your MAT files.
%   2) Run this script.

clear; clc;
fprintf('\n[START] Batch Oral-Area Results Tables\n');

%% USER SETTINGS
inputFolder = pwd;       % Change to folder containing all relevant MAT files
searchSubfolders = false;
areaVariableNames = {'areaPixels','oralArea','oral_area','area', ...
                      'areas','areaSequence','areaValues'};
frameRate = [];          % Set only if verified, e.g. 23.18; [] = unknown
outputFolder = fullfile(inputFolder, 'Oral_Area_Reports');
if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

%% FIND MAT FILES
if searchSubfolders
    files = dir(fullfile(inputFolder,'**','*.mat'));
else
    files = dir(fullfile(inputFolder,'*.mat'));
end
fprintf('[INFO] Folder: %s\n', inputFolder);
fprintf('[INFO] MAT files found: %d\n', numel(files));
if isempty(files)
    error('No MAT files found. Set inputFolder to the correct folder.');
end

% Combined result rows:
% File, Metric, ReportedResult, EvidenceSource, Status
allRows = cell(0,5);
allFrameTables = {};

for fileIdx = 1:numel(files)
    matPath = fullfile(files(fileIdx).folder, files(fileIdx).name);
    [~, stem] = fileparts(files(fileIdx).name);
    fprintf('\n\n============================================================\n');
    fprintf('TABLE: %s\n', files(fileIdx).name);
    fprintf('============================================================\n');

    try
        S = load(matPath);
    catch ME
        fprintf(2,'[LOAD ERROR] %s\n', ME.message);
        metrics = {
            'Input MAT file', files(fileIdx).name, 'MAT file', 'Reported';
            'Frames loaded', 'Not available', 'MAT file could not be loaded', 'Load error';
            'Valid area frames', 'Not available', 'Area vector unavailable', 'Not computed';
            'Maximum area', 'Not available', 'Area vector unavailable', 'Not computed';
            'Minimum area', 'Not available', 'Area vector unavailable', 'Not computed';
            'Maximum signed acceleration', 'Not available', 'Acceleration unavailable', 'Not computed';
            'Maximum absolute acceleration', 'Not available', 'Acceleration unavailable', 'Not computed';
            'Minimum acceleration', 'Not available', 'Acceleration unavailable', 'Not computed';
            'Frame/time of selected event', 'Not available', 'No verified peak event', 'Not computed';
            'Peak sensitivity', 'Not evaluated', 'Sensitivity experiment required', 'Not evaluated'};
        for r=1:size(metrics,1), allRows(end+1,:) = [{files(fileIdx).name}, metrics(r,:)]; end %#ok<SAGROW>
        continue;
    end

    % Show all top-level variables to help map area variable names.
    varNames = fieldnames(S);
    fprintf('Variables in MAT file:\n');
    for k = 1:numel(varNames)
        v = S.(varNames{k});
        fprintf('  %-25s | class %-12s | size %s\n', ...
            varNames{k}, class(v), mat2str(size(v)));
    end

    % Strict detection: only use known area variable names.
    areaName = '';
    area = [];
    for k = 1:numel(areaVariableNames)
        nm = areaVariableNames{k};
        if isfield(S,nm)
            candidate = S.(nm);
            if isnumeric(candidate) && isvector(candidate) && ~isempty(candidate) && isreal(candidate)
                areaName = nm;
                area = double(candidate(:));
                break;
            end
        end
    end

    % Build default row values.
    framesText = 'Not available';
    validText = 'Not computed';
    maxAreaText = 'Not computed';
    minAreaText = 'Not computed';
    maxSignedText = 'Not computed';
    maxAbsText = 'Not computed';
    minAccText = 'Not computed';
    eventText = 'Not computed';
    statusText = 'Not computed';
    evidenceArea = 'Area vector unavailable';
    evidenceAccel = 'Acceleration unavailable';

    if isempty(areaName)
        fprintf(2,'[WARN] No recognised area vector in %s. Not guessing from other numeric vectors.\n', files(fileIdx).name);
        fprintf(2,'[WARN] If this MAT file contains contours only, integrate the project area calculation first.\n');
        metrics = {
            'Input MAT file', files(fileIdx).name, 'MAT-file metadata', 'Reported';
            'Frames loaded', 'Not available', 'MAT-file metadata / area vector unavailable', 'To verify';
            'Valid area frames', 'Not available', 'No recognised area vector', 'To compute';
            'Maximum area', 'Not available', 'No recognised area vector', 'To compute';
            'Minimum area', 'Not available', 'No recognised area vector', 'To compute';
            'Maximum signed acceleration', 'Not available', 'Acceleration output unavailable', 'To compute';
            'Maximum absolute acceleration', 'Not available', 'Acceleration output unavailable', 'To compute';
            'Minimum acceleration', 'Not available', 'Acceleration output unavailable', 'To compute';
            'Frame/time of selected event', 'Not available', 'No verified peak event', 'To compute';
            'Peak sensitivity', 'Not evaluated', 'Sensitivity experiment required', 'To evaluate'};
        for r=1:size(metrics,1), allRows(end+1,:) = [{files(fileIdx).name}, metrics(r,:)]; end %#ok<SAGROW>
        writeIndividualTable(outputFolder, stem, files(fileIdx).name, metrics);
        continue;
    end

    nFrames = numel(area);
    valid = isfinite(area) & area >= 0;
    validIdx = find(valid);
    framesText = sprintf('%d', nFrames);
    validText = sprintf('%d/%d', nnz(valid), nFrames);
    evidenceArea = areaName;

    if any(valid)
        vals = area(valid);
        [maxArea, imax] = max(vals);
        [minArea, imin] = min(vals);
        maxAreaFrame = validIdx(imax);
        minAreaFrame = validIdx(imin);
        maxAreaText = sprintf('%.6f pixel^2 at frame %d', maxArea, maxAreaFrame);
        minAreaText = sprintf('%.6f pixel^2 at frame %d', minArea, minAreaFrame);
    else
        maxAreaText = 'Not available';
        minAreaText = 'Not available';
    end

    % First difference velocity, and central second difference acceleration.
    velocity = nan(nFrames,1);
    if nFrames >= 2
        pairOK = valid(1:end-1) & valid(2:end);
        dA = diff(area);
        vtmp = nan(nFrames-1,1);
        vtmp(pairOK) = dA(pairOK);
        velocity(1:end-1) = vtmp;
    end

    acceleration = nan(nFrames,1);
    if nFrames >= 3
        tripleOK = valid(1:end-2) & valid(2:end-1) & valid(3:end);
        d2 = area(3:end) - 2*area(2:end-1) + area(1:end-2);
        mids = (2:nFrames-1)';
        acceleration(mids(tripleOK)) = d2(tripleOK);
    end

    ai = find(isfinite(acceleration));
    maxPositive = NaN; maxPositiveFrame = NaN;
    maxAbs = NaN; maxAbsFrame = NaN; minAcc = NaN; minAccFrame = NaN;
    if ~isempty(ai)
        [maxPositive, ii] = max(acceleration(ai)); maxPositiveFrame = ai(ii);
        [maxAbs, ii] = max(abs(acceleration(ai))); maxAbsFrame = ai(ii);
        [minAcc, ii] = min(acceleration(ai)); minAccFrame = ai(ii);
        maxSignedText = sprintf('%.6f pixel^2/frame^2 at frame %d', maxPositive, maxPositiveFrame);
        maxAbsText = sprintf('%.6f pixel^2/frame^2 at frame %d (signed %.6f)', ...
            maxAbs, maxAbsFrame, acceleration(maxAbsFrame));
        minAccText = sprintf('%.6f pixel^2/frame^2 at frame %d', minAcc, minAccFrame);
        evidenceAccel = 'Batch script finite-difference calculation';
        eventText = sprintf('Max positive: frame %d; max absolute: frame %d', ...
            maxPositiveFrame, maxAbsFrame);
        statusText = 'Computed; verify against project method';
    else
        maxSignedText = 'Not available';
        maxAbsText = 'Not available';
        minAccText = 'Not available';
        eventText = 'Not available';
        statusText = 'Insufficient valid samples';
    end

    metrics = {
        'Input MAT file', files(fileIdx).name, 'Batch summary / MAT-file metadata', 'Reported';
        'Frames loaded', framesText, sprintf('Area vector length: %s', areaName), 'Reported';
        'Valid area frames', validText, areaName, 'Reported';
        'Maximum area', maxAreaText, areaName, 'Reported';
        'Minimum area', minAreaText, areaName, 'Reported';
        'Maximum signed acceleration', maxSignedText, evidenceAccel, statusText;
        'Maximum absolute acceleration', maxAbsText, evidenceAccel, statusText;
        'Minimum acceleration', minAccText, evidenceAccel, statusText;
        'Frame/time of selected event', eventText, 'Acceleration output table', 'Frame index; timestamp not set';
        'Peak sensitivity', 'Not evaluated', 'Requires a defined sensitivity experiment', 'Not evaluated'};

    fprintf('\n%-34s | %-52s | %-38s | %s\n','Metric','Reported result','Evidence/source','Status');
    fprintf('%s\n',repmat('-',1,145));
    for r=1:size(metrics,1)
        fprintf('%-34s | %-52s | %-38s | %s\n', ...
            metrics{r,1}, char(string(metrics{r,2})), char(string(metrics{r,3})), char(string(metrics{r,4})));
        allRows(end+1,:) = [{files(fileIdx).name}, metrics(r,:)]; %#ok<SAGROW>
    end

    frame = (1:nFrames)';
    if isempty(frameRate), time_s = nan(nFrames,1); else, time_s = (frame-1)/frameRate; end
    fileCol = repmat({files(fileIdx).name},nFrames,1);
    T = table(fileCol, frame, time_s, area, valid, velocity, acceleration, ...
        'VariableNames', {'File','Frame','Time_s','Area_pixel2','AreaValid', ...
        'AreaVelocity_pixel2_per_frame','AreaAcceleration_pixel2_per_frame2'});
    allFrameTables{end+1} = T; %#ok<SAGROW>

    % Individual Word-friendly CSV for this file.
    writeIndividualTable(outputFolder, stem, files(fileIdx).name, metrics);
end

% Combined long-form results CSV
if ~isempty(allRows)
    resultTable = cell2table(allRows, 'VariableNames', ...
        {'InputFile','Metric','ReportedResult','EvidenceSource','Status'});
    writetable(resultTable, fullfile(outputFolder,'ALL_FILES_ORAL_AREA_RESULTS.csv'));
    fprintf('\n[SAVED] %s\n', fullfile(outputFolder,'ALL_FILES_ORAL_AREA_RESULTS.csv'));
end

% Combined frame-wise CSV
if ~isempty(allFrameTables)
    frameTable = vertcat(allFrameTables{:});
    writetable(frameTable, fullfile(outputFolder,'ALL_FILES_FRAMEWISE.csv'));
    fprintf('[SAVED] %s\n', fullfile(outputFolder,'ALL_FILES_FRAMEWISE.csv'));
else
    fprintf(2,'[INFO] No frame-wise area CSV created because no recognised area vectors were found.\n');
end

fprintf('\n[DONE] All files processed. Reports folder: %s\n', outputFolder);

%% Local helper: write one 4-column Word-friendly table per MAT file.
function writeIndividualTable(outFolder, stem, inputName, metrics)
    T = cell2table(metrics, 'VariableNames', ...
        {'Metric','ReportedResult','EvidenceSource','Status'});
    outPath = fullfile(outFolder, [stem '_OralAreaResults.csv']);
    try
        writetable(T, outPath);
        fprintf('[SAVED] Individual table: %s\n', outPath);
    catch ME
        fprintf(2,'[CSV ERROR] %s: %s\n', inputName, ME.message);
    end
end
