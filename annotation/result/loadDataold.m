function data = loadData(matFilePath, frameIdx)
% LOADDATA
% Load one MRI frame, contours, and anatomical landmarks.
%
% Original MRI image is loaded from:
%   S.imgs
%
% Each frame is stored as a 68x68 grayscale image flattened into
% a 1x4624 vector.

    fprintf('========== LOAD DATA ==========\n');

    if ~isfile(matFilePath)
        error('loadData:fileNotFound', ...
            'File not found: %s', matFilePath);
    end

    S = load(matFilePath);

    if ~isfield(S, 'annotation')
        error('loadData:missingField', ...
            ['Variable ''annotation'' not found in %s. ' ...
             'Check the .mat file contents with whos().'], ...
             matFilePath);
    end

    ann = S.annotation;

    nFrames = numel(ann);

    fprintf('Loaded %s\n', matFilePath);
    fprintf('Total frames available: %d\n', nFrames);

    if frameIdx < 1 || frameIdx > nFrames
        error('loadData:badFrameIdx', ...
            'frameIdx=%d out of range (1..%d).', ...
            frameIdx, nFrames);
    end

    fr = ann(frameIdx);

    data = struct();

    data.frameIdx = frameIdx;

    % ------------------------------------------------------------
    % CONTOURS
    % ------------------------------------------------------------

    data.C1 = getFieldSafe(fr, 'contour1');
    data.C2 = getFieldSafe(fr, 'contour2');
    data.C3 = getFieldSafe(fr, 'contour3');

    % ------------------------------------------------------------
    % MANUAL LANDMARKS
    % ------------------------------------------------------------

    data.VEL_manual = getFieldSafe(fr, 'VEL');

    UL_m = getFieldSafe(fr, 'UL');
    LL_m = getFieldSafe(fr, 'LL');

    data.UL_manual = UL_m;
    data.LL_manual = LL_m;

    % L = midpoint between UL and LL
    if ~isempty(UL_m) && ~isempty(LL_m)

        data.L = (UL_m + LL_m) / 2;

        fprintf('L computed as midpoint of manual UL and LL.\n');

    elseif ~isempty(UL_m)

        data.L = UL_m;

        warning('loadData:noLLField', ...
            ['LL not found for frame %d - falling back to ' ...
             'L = UL.'], frameIdx);

    else

        data.L = [];

        warning('loadData:noLandmarks', ...
            'Neither UL nor LL found for frame %d.', frameIdx);

    end

    % ------------------------------------------------------------
    % ORIGINAL MRI FRAME
    % ------------------------------------------------------------

    data.image = [];

    if isfield(S, 'imgs') && ~isempty(S.imgs)

        imgs = S.imgs;

        if size(imgs,1) >= frameIdx

            frameVector = imgs(frameIdx,:);

            expectedPixels = 68 * 68;

            if numel(frameVector) == expectedPixels

                data.image = reshape(frameVector, 68, 68);

            else
                warning('loadData:unexpectedImageSize', ...
                    ['Frame %d has %d pixels instead of 68x68=%d. ' ...
                     'Original image will not be displayed.'], ...
                    frameIdx, numel(frameVector), expectedPixels);
            end

        end

    else

        warning('loadData:noImgs', ...
            ['Variable ''imgs'' was not found in MAT file. ' ...
             'Original MRI frame cannot be displayed.']);

    end

    % ------------------------------------------------------------
    % DEBUG INFORMATION
    % ------------------------------------------------------------

    fprintf('Frame %d loaded.\n', frameIdx);
    fprintf('  C1 points: %d\n', sizeOrZero(data.C1));
    fprintf('  C2 points: %d\n', sizeOrZero(data.C2));
    fprintf('  C3 points: %d\n', sizeOrZero(data.C3));

    if ~isempty(data.L)
        fprintf('  L = (%.3f, %.3f)\n', ...
            data.L(1), data.L(2));
    end

    if ~isempty(data.image)
        fprintf('  Original MRI frame: %dx%d\n', ...
            size(data.image,1), size(data.image,2));
    end

    fprintf('================================\n\n');

end


% ================================================================
% SAFE FIELD ACCESS
% ================================================================

function v = getFieldSafe(s, fname)

    if isfield(s, fname)
        v = s.(fname);
    else
        v = [];
    end

end


% ================================================================
% SIZE HELPER
% ================================================================

function n = sizeOrZero(x)

    if isempty(x)
        n = 0;
    else
        n = size(x,1);
    end

end