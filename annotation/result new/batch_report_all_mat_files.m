%% batch_report_all_mat_files.m
% Batch report for ALL MAT files in a selected folder.
%
% What it does:
% 1) Finds every *.mat file in inputFolder.
% 2) Prints the variables stored in each MAT file.
% 3) Detects a numeric vector that looks like frame-wise oral area.
% 4) Reports frame count, valid area count, min/max area and selected frames.
% 5) Calculates simple finite-difference velocity/acceleration when possible.
% 6) Writes one combined CSV containing frame-wise results from all usable files.
% 7) Writes a summary CSV, including files where no area vector was found.
%
% IMPORTANT:
% - This script does NOT create anatomical annotations or calculate area from
%   raw video frames automatically.
% - For files containing contours but no precomputed area vector, it will
%   report that no area vector was found. Add your project's area-calculation
%   function/pipeline before expecting area/acceleration statistics.
% - The acceleration below is a simple second finite difference over frame
%   index. It may differ from the derivative method used by your main project.

clear; clc;

%% ---------------- USER SETTINGS ----------------
inputFolder = pwd;               % Folder containing all MAT files
searchSubfolders = false;        % true to include subfolders
areaVariablePriority = {'areaPixels','oralArea','oral_area','area', ...
                        'areas','areaSequence','areaValues'};
selectedFrames = [32 33 34];     % Frame numbers to report
frameRate = [];                  % Set e.g. 23.18 only if verified; [] = unknown
summaryCsv = fullfile(inputFolder, 'ALL_FILES_summary.csv');
frameCsv = fullfile(inputFolder, 'ALL_FILES_framewise.csv');
%% ------------------------------------------------

if ~isfolder(inputFolder)
    error('Folder not found: %s', inputFolder);
end

if searchSubfolders
    files = dir(fullfile(inputFolder, '**', '*.mat'));
else
    files = dir(fullfile(inputFolder, '*.mat'));
end

% Avoid re-reading report files if any happen to be MAT (normally none).
if isempty(files)
    error('No MAT files found in folder: %s', inputFolder);
end

fprintf('\n============================================================\n');
fprintf(' BATCH ORAL-AREA REPORT\n');
fprintf(' Folder: %s\n', inputFolder);
fprintf(' MAT files found: %d\n', numel(files));
fprintf('============================================================\n');

summaryRows = {};
allFrameTables = {};

for fileIdx = 1:numel(files)
    matPath = fullfile(files(fileIdx).folder, files(fileIdx).name);
    fprintf('\n\n------------------------------------------------------------\n');
    fprintf('FILE %d/%d: %s\n', fileIdx, numel(files), matPath);
    fprintf('------------------------------------------------------------\n');

    try
        S = load(matPath);
    catch ME
        fprintf('ERROR loading file: %s\n', ME.message);
        summaryRows(end+1,:) = {files(fileIdx).name, NaN, NaN, NaN, NaN, NaN, ...
            NaN, NaN, "LOAD_ERROR", ME.message}; %#ok<SAGROW>
        continue;
    end

    names = fieldnames(S);
    fprintf('Variables:\n');
    for k = 1:numel(names)
        v = S.(names{k});
        fprintf('  %-28s | %-12s | %s\n', names{k}, class(v), mat2str(size(v)));
    end

    % Find area vector by preferred names first.
    areaName = '';
    area = [];
    for k = 1:numel(areaVariablePriority)
        nm = areaVariablePriority{k};
        if isfield(S,nm) && isnumeric(S.(nm)) && isvector(S.(nm)) && ~isempty(S.(nm))
            areaName = nm;
            tmpArea = S.(nm); area = double(tmpArea(:));
            break;
        end
    end

    % If no known name matches, try unique numeric vectors that plausibly
    % contain multiple frame measurements. Do not choose arbitrarily if ambiguous.
    if isempty(areaName)
        possible = {};
        for k = 1:numel(names)
            v = S.(names{k});
            if isnumeric(v) && isvector(v) && numel(v) >= 3 && ...
                    ~isempty(v) && isreal(v)
                possible(end+1,:) = {names{k}, double(v(:))}; %#ok<SAGROW>
            end
        end
        if size(possible,1) == 1
            areaName = possible{1,1};
            area = possible{1,2};
            fprintf('Area vector candidate selected (only numeric vector): %s\n', areaName);
        elseif size(possible,1) > 1
            fprintf('No unambiguous area vector found. Numeric vector candidates:\n');
            for k = 1:size(possible,1)
                fprintf('  %s (length %d)\n', possible{k,1}, numel(possible{k,2}));
            end
        end
    end

    if isempty(areaName)
        fprintf('STATUS: NO_AREA_VECTOR_FOUND. This file may contain frames/contours only.\n');
        summaryRows(end+1,:) = {files(fileIdx).name, NaN, NaN, NaN, NaN, NaN, ...
            NaN, NaN, "NO_AREA_VECTOR", "Area vector not found or ambiguous"}; %#ok<SAGROW>
        continue;
    end

    area = area(:);
    nFrames = numel(area);
    valid = isfinite(area) & area >= 0;
    validFrames = find(valid);
    fprintf('\nArea variable: %s\n', areaName);
    fprintf('Frames in area vector: %d\n', nFrames);
    fprintf('Valid area frames: %d/%d\n', nnz(valid), nFrames);
    fprintf('Invalid/missing area frames: %d\n', nFrames - nnz(valid));

    if ~any(valid)
        summaryRows(end+1,:) = {files(fileIdx).name, nFrames, 0, NaN, NaN, NaN, ...
            NaN, NaN, "NO_VALID_AREA", "Area vector has no finite non-negative values"}; %#ok<SAGROW>
        continue;
    end

    vals = area(valid);
    [maxArea, iMax] = max(vals);
    [minArea, iMin] = min(vals);
    maxAreaFrame = validFrames(iMax);
    minAreaFrame = validFrames(iMin);
    fprintf('Maximum area: %.6f pixel^2 at frame %d\n', maxArea, maxAreaFrame);
    fprintf('Minimum area: %.6f pixel^2 at frame %d\n', minArea, minAreaFrame);

    for f = selectedFrames
        if f >= 1 && f <= nFrames && valid(f)
            fprintf('Area at frame %d: %.6f pixel^2\n', f, area(f));
        elseif f >= 1 && f <= nFrames
            fprintf('Area at frame %d: INVALID/MISSING\n', f);
        else
            fprintf('Area at frame %d: OUT OF RANGE (1-%d)\n', f, nFrames);
        end
    end

    % Consecutive difference for the last two selected frames.
    if numel(selectedFrames) >= 2
        f1 = selectedFrames(end-1);
        f2 = selectedFrames(end);
        if f1 >= 1 && f1 <= nFrames && f2 >= 1 && f2 <= nFrames && valid(f1) && valid(f2)
            fprintf('A(%d)-A(%d) = %.6f pixel^2\n', f2, f1, area(f2)-area(f1));
        end
    end

    % First difference: area change per frame interval.
    velocity = nan(nFrames,1);
    if nFrames >= 2
        pairValid = valid(1:end-1) & valid(2:end);
        dA = diff(area);
        vTmp = nan(nFrames-1,1);
        vTmp(pairValid) = dA(pairValid);
        velocity(1:end-1) = vTmp;
    end

    % Second difference at central frame i: A(i+1)-2A(i)+A(i-1).
    acceleration = nan(nFrames,1);
    if nFrames >= 3
        tripleValid = valid(1:end-2) & valid(2:end-1) & valid(3:end);
        d2A = area(3:end) - 2*area(2:end-1) + area(1:end-2);
        mid = (2:nFrames-1)';
        acceleration(mid(tripleValid)) = d2A(tripleValid);
    end

    accIdx = find(isfinite(acceleration));
    maxPositive = NaN; maxPositiveFrame = NaN;
    maxAbs = NaN; maxAbsFrame = NaN; minAcc = NaN; minAccFrame = NaN;
    if ~isempty(accIdx)
        [maxPositive, ii] = max(acceleration(accIdx));
        maxPositiveFrame = accIdx(ii);
        [maxAbs, ii] = max(abs(acceleration(accIdx)));
        maxAbsFrame = accIdx(ii);
        [minAcc, ii] = min(acceleration(accIdx));
        minAccFrame = accIdx(ii);
        fprintf('Max signed acceleration: %.6f pixel^2/frame^2 at frame %d\n', maxPositive, maxPositiveFrame);
        fprintf('Max absolute acceleration: %.6f pixel^2/frame^2 at frame %d (signed %.6f)\n', ...
            maxAbs, maxAbsFrame, acceleration(maxAbsFrame));
        fprintf('Minimum acceleration: %.6f pixel^2/frame^2 at frame %d\n', minAcc, minAccFrame);
        fprintf('NOTE: simple finite differences; may differ from the project pipeline.\n');
    else
        fprintf('Acceleration unavailable: not enough consecutive valid values.\n');
    end

    frame = (1:nFrames)';
    if isempty(frameRate)
        time_s = nan(nFrames,1);
    else
        if ~isscalar(frameRate) || ~isfinite(frameRate) || frameRate <= 0
            error('frameRate must be a positive finite scalar or [].');
        end
        time_s = (frame-1)/frameRate;
    end

    T = table(repmat(string(files(fileIdx).name),nFrames,1), frame, time_s, area, valid, velocity, acceleration, ...
        'VariableNames', {'File','Frame','Time_s','Area_pixel2','AreaValid', ...
        'AreaVelocity_pixel2_per_frame','AreaAcceleration_pixel2_per_frame2'});
    allFrameTables{end+1} = T; %#ok<SAGROW>

    summaryRows(end+1,:) = {files(fileIdx).name, nFrames, nnz(valid), maxArea, maxAreaFrame, ...
        minArea, minAreaFrame, maxPositive, maxPositiveFrame, "AREA_FOUND", ...
        sprintf('Area variable: %s; max abs accel %.6g at frame %g; min accel %.6g at frame %g', ...
        areaName, maxAbs, maxAbsFrame, minAcc, minAccFrame)}; %#ok<SAGROW>
end

% Summary table
if ~isempty(summaryRows)
    % Pad rows to same number of columns in case a file failed early.
    maxCols = max(cellfun(@(r) size(r,2), num2cell(summaryRows,2)));
    % Standardize to fixed 11 columns.
    for r = 1:size(summaryRows,1)
        if size(summaryRows,2) < 11
            summaryRows{r,11} = '';
        end
    end
    summaryTable = cell2table(summaryRows, 'VariableNames', ...
        {'File','Frames','ValidAreaFrames','MaxArea_pixel2','MaxAreaFrame', ...
         'MinArea_pixel2','MinAreaFrame','MaxSignedAcceleration','MaxSignedAccelerationFrame', ...
         'Status','Notes'});
    try
        writetable(summaryTable, summaryCsv);
        fprintf('\n\nSummary CSV saved: %s\n', summaryCsv);
    catch ME
        warning('Could not write summary CSV: %s', ME.message);
    end
end

% Combined frame-wise table
if ~isempty(allFrameTables)
    combined = vertcat(allFrameTables{:});
    try
        writetable(combined, frameCsv);
        fprintf('Combined frame-wise CSV saved: %s\n', frameCsv);
    catch ME
        warning('Could not write combined CSV: %s', ME.message);
    end
else
    fprintf('\nNo frame-wise area tables were produced because no usable area vectors were found.\n');
end

fprintf('\nBatch processing complete.\n');
