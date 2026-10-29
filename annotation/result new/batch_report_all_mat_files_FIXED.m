%% batch_report_all_mat_files_FIXED.m
% Batch report for all MAT files in a folder.
% This script reports existing frame-wise area vectors; it does NOT
% automatically annotate raw videos or derive area from contours.

clear; clc;
fprintf('\n[START] Batch area report script is running...\n');

%% USER SETTINGS
inputFolder = pwd;                 % Folder containing MAT files
searchSubfolders = false;          % true includes subfolders
areaVariablePriority = {'areaPixels','oralArea','oral_area','area', ...
                        'areas','areaSequence','areaValues'};
selectedFrames = [32 33 34];
frameRate = [];                    % Set only if verified, e.g. 23.18
summaryCsv = fullfile(inputFolder, 'ALL_FILES_summary.csv');
frameCsv = fullfile(inputFolder, 'ALL_FILES_framewise.csv');

fprintf('[INFO] Current folder: %s\n', inputFolder);

if ~isfolder(inputFolder)
    error('[ERROR] Folder does not exist: %s', inputFolder);
end

if searchSubfolders
    files = dir(fullfile(inputFolder, '**', '*.mat'));
else
    files = dir(fullfile(inputFolder, '*.mat'));
end

fprintf('[INFO] MAT files found: %d\n', numel(files));
if isempty(files)
    error(['[ERROR] No .mat files found in the current folder. ' ...
           'Change inputFolder to the folder containing your MAT files.']);
end

% Fixed-width table storage prevents inconsistent cell-row sizes.
summaryRows = cell(0,11);
allFrameTables = {};

for fileIdx = 1:numel(files)
    matPath = fullfile(files(fileIdx).folder, files(fileIdx).name);
    fprintf('\n============================================================\n');
    fprintf('[FILE %d/%d] %s\n', fileIdx, numel(files), matPath);

    try
        S = load(matPath);
    catch ME
        fprintf(2, '[LOAD ERROR] %s\n', ME.message);
        summaryRows(end+1,:) = {files(fileIdx).name, NaN, NaN, NaN, NaN, ...
            NaN, NaN, NaN, NaN, 'LOAD_ERROR', ME.message};
        continue;
    end

    names = fieldnames(S);
    fprintf('[INFO] Variables in MAT file:\n');
    for k = 1:numel(names)
        v = S.(names{k});
        fprintf('  %-25s class=%-12s size=%s\n', ...
            names{k}, class(v), mat2str(size(v)));
    end

    % Search configured common names first.
    areaName = '';
    area = [];
    for k = 1:numel(areaVariablePriority)
        nm = areaVariablePriority{k};
        if isfield(S,nm)
            tmp = S.(nm);
            if isnumeric(tmp) && isvector(tmp) && ~isempty(tmp) && isreal(tmp)
                areaName = nm;
                area = double(tmp(:));
                break;
            end
        end
    end

    % If not found by name, only auto-select if there is exactly one numeric
    % vector with 3+ elements. Otherwise avoid guessing.
    if isempty(areaName)
        candidateNames = {};
        candidateValues = {};
        for k = 1:numel(names)
            tmp = S.(names{k});
            if isnumeric(tmp) && isvector(tmp) && numel(tmp) >= 3 && ...
                    ~isempty(tmp) && isreal(tmp)
                candidateNames{end+1} = names{k}; %#ok<SAGROW>
                candidateValues{end+1} = double(tmp(:)); %#ok<SAGROW>
            end
        end

        if numel(candidateNames) == 1
            areaName = candidateNames{1};
            area = candidateValues{1};
            fprintf('[INFO] Using only numeric-vector candidate: %s\n', areaName);
        elseif numel(candidateNames) > 1
            fprintf(2, '[WARN] Area variable ambiguous. Candidate vectors:\n');
            for k = 1:numel(candidateNames)
                fprintf(2, '  %s (length %d)\n', candidateNames{k}, numel(candidateValues{k}));
            end
        end
    end

    if isempty(areaName)
        fprintf(2, ['[WARN] NO_AREA_VECTOR_FOUND in %s. This MAT file may contain ' ...
            'contours/frames but no precomputed area vector.\n'], files(fileIdx).name);
        summaryRows(end+1,:) = {files(fileIdx).name, NaN, NaN, NaN, NaN, ...
            NaN, NaN, NaN, NaN, 'NO_AREA_VECTOR', ...
            'Area vector not found or ambiguous; inspect variable list'};
        continue;
    end

    nFrames = numel(area);
    valid = isfinite(area) & area >= 0;
    validFrames = find(valid);
    fprintf('[INFO] Area variable: %s\n', areaName);
    fprintf('[RESULT] Frames in area vector: %d\n', nFrames);
    fprintf('[RESULT] Valid area frames: %d/%d\n', nnz(valid), nFrames);
    fprintf('[RESULT] Invalid/missing area frames: %d\n', nFrames - nnz(valid));

    if ~any(valid)
        summaryRows(end+1,:) = {files(fileIdx).name, nFrames, 0, NaN, NaN, ...
            NaN, NaN, NaN, NaN, 'NO_VALID_AREA', ...
            'Area vector has no finite non-negative values'};
        continue;
    end

    vals = area(valid);
    [maxArea, iMax] = max(vals);
    [minArea, iMin] = min(vals);
    maxAreaFrame = validFrames(iMax);
    minAreaFrame = validFrames(iMin);
    fprintf('[RESULT] Maximum area: %.6f pixel^2 at frame %d\n', maxArea, maxAreaFrame);
    fprintf('[RESULT] Minimum area: %.6f pixel^2 at frame %d\n', minArea, minAreaFrame);

    for f = selectedFrames
        if f >= 1 && f <= nFrames && valid(f)
            fprintf('[FRAME] Area at frame %d: %.6f pixel^2\n', f, area(f));
        elseif f >= 1 && f <= nFrames
            fprintf('[FRAME] Area at frame %d: INVALID/MISSING\n', f);
        else
            fprintf('[FRAME] Frame %d is out of range (1-%d)\n', f, nFrames);
        end
    end

    if numel(selectedFrames) >= 2
        f1 = selectedFrames(end-1);
        f2 = selectedFrames(end);
        if f1 >= 1 && f1 <= nFrames && f2 >= 1 && f2 <= nFrames && valid(f1) && valid(f2)
            fprintf('[RESULT] A(%d)-A(%d) = %.6f pixel^2\n', f2, f1, area(f2)-area(f1));
        end
    end

    % First differences: area change per frame interval.
    velocity = nan(nFrames,1);
    if nFrames >= 2
        pairValid = valid(1:end-1) & valid(2:end);
        dA = diff(area);
        tmpV = nan(nFrames-1,1);
        tmpV(pairValid) = dA(pairValid);
        velocity(1:end-1) = tmpV;
    end

    % Second differences assigned to middle frame.
    acceleration = nan(nFrames,1);
    if nFrames >= 3
        tripleValid = valid(1:end-2) & valid(2:end-1) & valid(3:end);
        d2A = area(3:end) - 2*area(2:end-1) + area(1:end-2);
        mid = (2:nFrames-1)';
        acceleration(mid(tripleValid)) = d2A(tripleValid);
    end

    accIdx = find(isfinite(acceleration));
    maxPositive = NaN; maxPositiveFrame = NaN;
    maxAbs = NaN; maxAbsFrame = NaN;
    minAcc = NaN; minAccFrame = NaN;
    if ~isempty(accIdx)
        [maxPositive, ii] = max(acceleration(accIdx));
        maxPositiveFrame = accIdx(ii);
        [maxAbs, ii] = max(abs(acceleration(accIdx)));
        maxAbsFrame = accIdx(ii);
        [minAcc, ii] = min(acceleration(accIdx));
        minAccFrame = accIdx(ii);
        fprintf('[RESULT] Max signed acceleration: %.6f pixel^2/frame^2 at frame %d\n', ...
            maxPositive, maxPositiveFrame);
        fprintf('[RESULT] Max absolute acceleration: %.6f pixel^2/frame^2 at frame %d (signed %.6f)\n', ...
            maxAbs, maxAbsFrame, acceleration(maxAbsFrame));
        fprintf('[RESULT] Minimum acceleration: %.6f pixel^2/frame^2 at frame %d\n', ...
            minAcc, minAccFrame, minAccFrame);
        fprintf('[NOTE] Acceleration uses simple second finite differences; it may differ from your project method.\n');
    else
        fprintf('[WARN] Acceleration unavailable: insufficient consecutive valid samples.\n');
    end

    frame = (1:nFrames)';
    if isempty(frameRate)
        time_s = nan(nFrames,1);
    else
        if ~isscalar(frameRate) || ~isfinite(frameRate) || frameRate <= 0
            error('frameRate must be positive or []');
        end
        time_s = (frame-1)/frameRate;
    end

    fileColumn = repmat({files(fileIdx).name}, nFrames, 1);
    T = table(fileColumn, frame, time_s, area, valid, velocity, acceleration, ...
        'VariableNames', {'File','Frame','Time_s','Area_pixel2','AreaValid', ...
        'AreaVelocity_pixel2_per_frame','AreaAcceleration_pixel2_per_frame2'});
    allFrameTables{end+1} = T; %#ok<SAGROW>

    noteText = sprintf('Area variable=%s; max abs accel=%.6g at frame %g; min accel=%.6g at frame %g', ...
        areaName, maxAbs, maxAbsFrame, minAcc, minAccFrame);
    summaryRows(end+1,:) = {files(fileIdx).name, nFrames, nnz(valid), maxArea, ...
        maxAreaFrame, minArea, minAreaFrame, maxPositive, maxPositiveFrame, ...
        'AREA_FOUND', noteText};
end

% Export one summary row per file.
if ~isempty(summaryRows)
    summaryTable = cell2table(summaryRows, 'VariableNames', ...
        {'File','Frames','ValidAreaFrames','MaxArea_pixel2','MaxAreaFrame', ...
         'MinArea_pixel2','MinAreaFrame','MaxSignedAcceleration', ...
         'MaxSignedAccelerationFrame','Status','Notes'});
    try
        writetable(summaryTable, summaryCsv);
        fprintf('\n[SAVED] Summary CSV: %s\n', summaryCsv);
    catch ME
        fprintf(2, '[CSV ERROR] Could not save summary CSV: %s\n', ME.message);
    end
end

% Export combined frame-wise report.
if ~isempty(allFrameTables)
    try
        combined = vertcat(allFrameTables{:});
        writetable(combined, frameCsv);
        fprintf('[SAVED] Frame-wise CSV: %s\n', frameCsv);
    catch ME
        fprintf(2, '[CSV ERROR] Could not save frame-wise CSV: %s\n', ME.message);
    end
else
    fprintf(2, '\n[WARN] No frame-wise CSV created: no usable area vectors found.\n');
end

fprintf('\n[DONE] Batch report finished.\n');
