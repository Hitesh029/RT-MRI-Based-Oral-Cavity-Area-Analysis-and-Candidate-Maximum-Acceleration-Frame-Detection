%% report_video_area_details.m
% Report frame-wise oral-area statistics from an existing MAT file.
% The MAT file must contain a numeric area vector (one value per frame).
% This script does not infer oral area from a raw video without annotations.

clear; clc;

%% USER SETTINGS
inputMatFile = 'M2_034_temp.mat'; % Change to your MAT file
areaVariableName = 'areaPixels';  % Change to the actual area-vector variable
selectedFrames = [32 33 34];
frameRate = [];                   % e.g. 23.18; [] means unknown
outputCsvFile = 'oral_area_frame_report.csv';

if ~isfile(inputMatFile)
    error('MAT file not found: %s. Set inputMatFile to the correct path.', inputMatFile);
end

S = load(inputMatFile);
fprintf('\\n========== ORAL-AREA REPORT ==========\\n');
fprintf('Input MAT file: %s\\n\\n', inputMatFile);

% Show top-level MAT variables
names = fieldnames(S);
fprintf('Variables in MAT file:\\n');
for k = 1:numel(names)
    v = S.(names{k});
    fprintf('  %-28s | class: %-12s | size: %s\\n', names{k}, class(v), mat2str(size(v)));
end

% Find the configured area variable, or try common names
if ~isfield(S, areaVariableName)
    candidates = {'areaPixels','oralArea','oral_area','area','areas','areaSequence','areaValues'};
    foundName = '';
    for k = 1:numel(candidates)
        nm = candidates{k};
        if isfield(S,nm) && isnumeric(S.(nm)) && isvector(S.(nm))
            foundName = nm;
            break;
        end
    end
    if isempty(foundName)
        error(['Area vector not found. Set areaVariableName to the correct numeric vector in the MAT file. ' ...
               'A raw video or contour-only MAT file cannot provide these area statistics until area is calculated.']);
    end
    areaVariableName = foundName;
    fprintf('\\nAuto-detected area variable: %s\\n', areaVariableName);
end

area = S.(areaVariableName);
if ~isnumeric(area) || ~isvector(area)
    error('Variable "%s" must be a numeric vector with one area value per frame.', areaVariableName);
end
area = double(area(:));
nFrames = numel(area);
validMask = isfinite(area) & area >= 0;
validFrames = find(validMask);

fprintf('\\nArea variable: %s\\n', areaVariableName);
fprintf('Frames represented by area vector: %d\\n', nFrames);
fprintf('Valid area frames: %d/%d\\n', nnz(validMask), nFrames);
fprintf('Invalid/missing area frames: %d\\n', nFrames - nnz(validMask));

if nnz(validMask) == 0
    error('No valid area values were found.');
end

% Area extrema
validAreas = area(validMask);
[maximumArea, iMax] = max(validAreas);
[minimumArea, iMin] = min(validAreas);
maxAreaFrame = validFrames(iMax);
minAreaFrame = validFrames(iMin);

fprintf('\\nAREA SUMMARY\\n');
fprintf('Maximum area: %.6f pixel^2 at frame %d\\n', maximumArea, maxAreaFrame);
fprintf('Minimum area: %.6f pixel^2 at frame %d\\n', minimumArea, minAreaFrame);

% Selected frame values
fprintf('\\nSELECTED FRAME AREAS\\n');
for k = 1:numel(selectedFrames)
    f = selectedFrames(k);
    if f >= 1 && f <= nFrames && validMask(f)
        fprintf('Area at frame %d: %.6f pixel^2\\n', f, area(f));
    elseif f >= 1 && f <= nFrames
        fprintf('Area at frame %d: INVALID/MISSING\\n', f);
    else
        fprintf('Frame %d is out of range (available: 1-%d).\\n', f, nFrames);
    end
end

if numel(selectedFrames) >= 2
    f1 = selectedFrames(end-1);
    f2 = selectedFrames(end);
    fprintf('\\nAREA DIFFERENCE\\n');
    if f1 >= 1 && f2 <= nFrames && f1 <= nFrames && f2 >= 1 ...
            && validMask(f1) && validMask(f2)
        fprintf('A(%d) - A(%d) = %.6f pixel^2\\n', f2, f1, area(f2)-area(f1));
    else
        fprintf('Cannot calculate A(%d)-A(%d): value missing or frame out of range.\\n', f2, f1);
    end
end

% First finite difference: area change per frame interval
velocity = nan(nFrames,1);
if nFrames >= 2
    pairValid = validMask(1:end-1) & validMask(2:end);
    dA = diff(area);
    temp = nan(nFrames-1,1);
    temp(pairValid) = dA(pairValid);
    velocity(1:end-1) = temp;
end

% Second finite difference, assigned to the middle frame
acceleration = nan(nFrames,1);
if nFrames >= 3
    tripleValid = validMask(1:end-2) & validMask(2:end-1) & validMask(3:end);
    d2A = area(3:end) - 2*area(2:end-1) + area(1:end-2);
    middleFrames = (2:nFrames-1)';
    acceleration(middleFrames(tripleValid)) = d2A(tripleValid);
end

validAccFrames = find(isfinite(acceleration));
fprintf('\\nACCELERATION SUMMARY (simple finite differences)\\n');
if isempty(validAccFrames)
    fprintf('Not enough consecutive valid frames to calculate acceleration.\\n');
else
    [maxPositive, idx] = max(acceleration(validAccFrames));
    maxPositiveFrame = validAccFrames(idx);
    [maxAbs, idx] = max(abs(acceleration(validAccFrames)));
    maxAbsFrame = validAccFrames(idx);
    [minAcc, idx] = min(acceleration(validAccFrames));
    minAccFrame = validAccFrames(idx);

    fprintf('Maximum signed acceleration: %.6f pixel^2/frame^2 at frame %d\\n', maxPositive, maxPositiveFrame);
    fprintf('Maximum absolute acceleration: %.6f pixel^2/frame^2 at frame %d (signed %.6f)\\n', ...
        maxAbs, maxAbsFrame, acceleration(maxAbsFrame));
    fprintf('Minimum acceleration: %.6f pixel^2/frame^2 at frame %d\\n', minAcc, minAccFrame);
    fprintf('NOTE: These are simple second differences; they may differ from your project pipeline.\\n');
end

% Optional timestamp calculation
frameIndex = (1:nFrames)';
if isempty(frameRate)
    timeSeconds = nan(nFrames,1);
    fprintf('\\nFrame rate not set; timestamps are left as NaN.\\n');
else
    if ~isscalar(frameRate) || ~isfinite(frameRate) || frameRate <= 0
        error('frameRate must be a positive finite scalar, or [] if unknown.');
    end
    timeSeconds = (frameIndex-1)/frameRate;
    fprintf('\\nFrame rate: %.6f frames/second; frame 1 timestamp = 0 s.\\n', frameRate);
end

% Export frame-wise table
T = table(frameIndex, timeSeconds, area, validMask, velocity, acceleration, ...
    'VariableNames', {'Frame','Time_s','Area_pixel2','AreaValid', ...
    'AreaVelocity_pixel2_per_frame','AreaAcceleration_pixel2_per_frame2'});
try
    writetable(T, outputCsvFile);
    fprintf('CSV report saved: %s\\n', outputCsvFile);
catch ME
    warning('Could not save CSV: %s', ME.message);
end

fprintf('\\nFRAME-WISE AREA LIST\\n');
fprintf('%8s %16s %10s\\n', 'Frame', 'Area(pixel^2)', 'Valid');
for f = 1:nFrames
    if validMask(f)
        fprintf('%8d %16.6f %10s\\n', f, area(f), 'Yes');
    else
        fprintf('%8d %16s %10s\\n', f, 'NaN/Invalid', 'No');
    end
end
fprintf('\\nReport complete.\\n');
