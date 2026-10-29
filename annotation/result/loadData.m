function data = loadData(matFilePath, frameIdx)
% LOADDATA
% Load one MRI frame + annotations for the requested frame.
%
% Supported file arrangement:
%
%   1) *_temp.mat
%      contains imgs + annotation
%
%   2) *.mat
%      contains the completed annotation structure, while the matching
%      *_temp.mat contains the original MRI images.
%
% For the second case, annotations are loaded ONLY from the requested
% *.mat file, and MRI images are loaded from the matching *_temp.mat.
%
% This keeps the completed annotations safe while allowing the original
% MRI image to be displayed.

    fprintf('========== LOAD DATA ==========\n');

    % ------------------------------------------------------------
    % CHECK MAIN FILE
    % ------------------------------------------------------------

    if ~isfile(matFilePath)
        error('loadData:fileNotFound', ...
            'File not found: %s', matFilePath);
    end

    S = load(matFilePath);

    if ~isfield(S, 'annotation')
        error('loadData:missingField', ...
            ['Variable ''annotation'' not found in %s. ' ...
             'Check the MAT file contents.'], ...
            matFilePath);
    end

    ann = S.annotation;
    nFrames = numel(ann);

    fprintf('Annotation file: %s\n', matFilePath);
    fprintf('Total annotation frames available: %d\n', nFrames);

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

    % L = midpoint between manual UL and LL
    if ~isempty(UL_m) && ~isempty(LL_m) && ...
            numel(UL_m) >= 2 && numel(LL_m) >= 2

        data.L = (UL_m + LL_m) / 2;

        fprintf('L computed as midpoint of manual UL and LL.\n');

    elseif ~isempty(UL_m) && numel(UL_m) >= 2

        data.L = UL_m;

        warning('loadData:noLLField', ...
            ['LL not found for frame %d - falling back to ' ...
             'L = UL.'], frameIdx);

    else

        data.L = [];

        warning('loadData:noLandmarks', ...
            'Neither valid UL nor LL found for frame %d.', frameIdx);

    end

    % ------------------------------------------------------------
    % MRI IMAGE
    %
    % First try the selected MAT file.
    % If imgs is not present there, use the matching *_temp.mat.
    % ------------------------------------------------------------

    data.image = [];

    imgs = [];

    % Case A: selected file itself contains imgs
    if isfield(S, 'imgs') && ~isempty(S.imgs)
        imgs = S.imgs;
        fprintf('MRI source: selected MAT file.\n');

    else
        % Case B: selected final annotation file does not contain imgs.
        % Look for matching *_temp.mat in the same folder.

        [folder, baseName, ext] = fileparts(matFilePath);

        % Only append _temp if this is not already a temp file.
        if endsWith(baseName, '_temp')
            tempPath = matFilePath;
        else
            tempPath = fullfile(folder, [baseName '_temp' ext]);
        end

        fprintf('MRI source not found in selected file.\n');
        fprintf('Looking for matching image file:\n  %s\n', tempPath);

        if isfile(tempPath)

            T = load(tempPath, 'imgs');

            if isfield(T, 'imgs') && ~isempty(T.imgs)
                imgs = T.imgs;
                fprintf('MRI source: matching *_temp.mat.\n');
            else
                warning('loadData:noImgsInTemp', ...
                    'Matching temp file exists but contains no imgs.');
            end

        else
            warning('loadData:noMatchingTemp', ...
                ['No matching *_temp.mat found for %s. ' ...
                 'Original MRI frame cannot be displayed.'], ...
                matFilePath);
        end
    end

    % ------------------------------------------------------------
    % RECONSTRUCT REQUESTED MRI FRAME
    % ------------------------------------------------------------

    if ~isempty(imgs)

        if size(imgs, 1) < frameIdx
            warning('loadData:frameMissingInImgs', ...
                ['MRI image file has only %d frames, but frame %d ' ...
                 'was requested.'], ...
                size(imgs,1), frameIdx);

        else

            frameVector = imgs(frameIdx, :);
            expectedPixels = 68 * 68;

            if numel(frameVector) == expectedPixels

                data.image = reshape(frameVector, 68, 68);

            elseif numel(frameVector) == 68 && size(imgs,2) == 68*68
                % Defensive branch; normally unreachable.
                data.image = reshape(frameVector, 68, 68);

            else

                warning('loadData:unexpectedImageSize', ...
                    ['Frame %d has %d pixels instead of ' ...
                     '68x68=%d. Original image will not be displayed.'], ...
                    frameIdx, numel(frameVector), expectedPixels);

            end
        end
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
    else
        fprintf('  L = EMPTY\n');
    end

    if ~isempty(data.VEL_manual)
        fprintf('  VEL = (%.3f, %.3f)\n', ...
            data.VEL_manual(1), data.VEL_manual(2));
    else
        fprintf('  VEL = EMPTY\n');
    end

    if ~isempty(data.image)
        fprintf('  Original MRI frame: %dx%d\n', ...
            size(data.image,1), size(data.image,2));
    else
        fprintf('  Original MRI frame: EMPTY\n');
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
