function [crossPoint, bracketIdx, tau, sides] = ...
    findSignChangeCrossing(contour, refPoint, testVec)

% findSignChangeCrossing
%
% Finds the intersection of an ordered contour with the line:
%
%       (Q - refPoint) . testVec = 0
%
% Primary method:
%   Sign-change interpolation between consecutive contour points.
%
% Robust fallback:
%   If the contour does not actually cross the line near refPoint,
%   but a traced point lies very close to the line, that point is
%   accepted as the crossing candidate.
%
% This handles discretized contours where the anatomical landmark
% lies on/very near the reference line but the sampled contour
% points do not straddle zero.

    if isempty(contour) || size(contour,2) ~= 2
        error('findSignChangeCrossing:invalidContour', ...
            'Contour must be an Nx2 non-empty array.');
    end

    if numel(refPoint) ~= 2 || numel(testVec) ~= 2
        error('findSignChangeCrossing:invalidReference', ...
            'refPoint and testVec must be 1x2 vectors.');
    end

    refPoint = refPoint(:).';
    testVec  = testVec(:).';

    testNorm = norm(testVec);

    if testNorm < eps
        error('findSignChangeCrossing:zeroTestVector', ...
            'testVec must be non-zero.');
    end

    testVec = testVec / testNorm;

    n = size(contour,1);

    % ------------------------------------------------------------
    % Signed distance/projection of every contour point
    % ------------------------------------------------------------

    sides = zeros(n,1);

    for i = 1:n
        sides(i) = dot(contour(i,:) - refPoint, testVec);
    end

    % ------------------------------------------------------------
    % Primary method: sign-change crossings
    % ------------------------------------------------------------

    crossingPoints = [];
    crossingBrackets = [];
    crossingTau = [];
    crossingDistances = [];

    for k = 1:n-1

        s1 = sides(k);
        s2 = sides(k+1);

        % Exact zero
        if s1 == 0

            pt = contour(k,:);

            crossingPoints(end+1,:) = pt; %#ok<AGROW>
            crossingBrackets(end+1,:) = [k k]; %#ok<AGROW>
            crossingTau(end+1,1) = 0; %#ok<AGROW>
            crossingDistances(end+1,1) = norm(pt-refPoint); %#ok<AGROW>

        % Sign change
        elseif sign(s1) ~= sign(s2)

            P1 = contour(k,:);
            P2 = contour(k+1,:);

            tauK = s1 / (s1 - s2);

            pt = P1 + tauK * (P2-P1);

            crossingPoints(end+1,:) = pt; %#ok<AGROW>
            crossingBrackets(end+1,:) = [k k+1]; %#ok<AGROW>
            crossingTau(end+1,1) = tauK; %#ok<AGROW>
            crossingDistances(end+1,1) = norm(pt-refPoint); %#ok<AGROW>
        end
    end

    % ------------------------------------------------------------
    % Primary result
    % ------------------------------------------------------------

    if ~isempty(crossingPoints)

        [minCrossDist, bestCross] = min(crossingDistances);

        % --------------------------------------------------------
        % Robust near-zero fallback
        %
        % If a contour point is almost exactly on the reference
        % line and is substantially closer to refPoint than the
        % detected crossing, prefer that anatomical local point.
        %
        % Tolerance = 0.25 px in the direction of testVec.
        % --------------------------------------------------------

        lineTolerance = 0.25;

        nearZeroMask = abs(sides) <= lineTolerance;

        if any(nearZeroMask)

            nearIdx = find(nearZeroMask);

            nearDistances = zeros(size(nearIdx));

            for j = 1:numel(nearIdx)
                nearDistances(j) = ...
                    norm(contour(nearIdx(j),:) - refPoint);
            end

            [minNearDist, nearBestLocal] = min(nearDistances);

            bestNearIdx = nearIdx(nearBestLocal);

            % Use near-zero point only when it is clearly closer
            % to the anatomical reference than a distant crossing.
            if minNearDist < minCrossDist

                crossPoint = contour(bestNearIdx,:);

                bracketIdx = [bestNearIdx bestNearIdx];

                tau = 0;

                fprintf('\n');
                fprintf(['  NOTE: contour has a near-zero point ' ...
                         'closer to refPoint than the available ' ...
                         'sign-change crossings.\n']);

                fprintf('  Near-zero point index = %d\n', ...
                    bestNearIdx);

                fprintf('  Point = (%.4f, %.4f)\n', ...
                    crossPoint(1), crossPoint(2));

                fprintf('  |side| = %.6f px\n', ...
                    abs(sides(bestNearIdx)));

                fprintf('  Distance to refPoint = %.4f px\n', ...
                    minNearDist);

                return;
            end
        end

        % Normal sign-change result
        [~, bestCross] = min(crossingDistances);

        crossPoint = crossingPoints(bestCross,:);
        bracketIdx = crossingBrackets(bestCross,:);
        tau = crossingTau(bestCross);

        if size(crossingPoints,1) > 1

            fprintf('\n');
            fprintf(['  NOTE: %d sign-change crossings found ' ...
                     'along this contour. Selecting the one ' ...
                     'closest to refPoint.\n'], ...
                     size(crossingPoints,1));

            for j = 1:size(crossingPoints,1)

                fprintf(['    Crossing %d: index [%d,%d], ' ...
                         'point=(%.3f,%.3f), ' ...
                         'dist to ref=%.3f\n'], ...
                    j, ...
                    crossingBrackets(j,1), ...
                    crossingBrackets(j,2), ...
                    crossingPoints(j,1), ...
                    crossingPoints(j,2), ...
                    crossingDistances(j));
            end
        end

        return;
    end

    % ------------------------------------------------------------
    % No sign-change crossing
    %
    % Try near-zero point directly.
    % ------------------------------------------------------------

    lineTolerance = 0.25;

    nearZeroMask = abs(sides) <= lineTolerance;

    if any(nearZeroMask)

        nearIdx = find(nearZeroMask);

        distances = zeros(size(nearIdx));

        for j = 1:numel(nearIdx)
            distances(j) = ...
                norm(contour(nearIdx(j),:) - refPoint);
        end

        [~, bestLocal] = min(distances);

        bestIdx = nearIdx(bestLocal);

        crossPoint = contour(bestIdx,:);
        bracketIdx = [bestIdx bestIdx];
        tau = 0;

        fprintf('\n');
        fprintf('  NOTE: No sign-change crossing found.\n');
        fprintf('  Using nearest near-zero contour point instead.\n');
        fprintf('  Index = %d\n', bestIdx);
        fprintf('  Point = (%.4f, %.4f)\n', ...
            crossPoint(1), crossPoint(2));
        fprintf('  |side| = %.6f px\n', abs(sides(bestIdx)));

        return;
    end

    % ------------------------------------------------------------
    % Robust fallback: no sign change and no near-zero point
    % ------------------------------------------------------------
    %
    % The contour can be entirely on one side of the ideal reference
    % line because of frame-to-frame anatomical motion and discrete
    % contour sampling. Do not fail the whole frame.
    %
    % Select the contour point with the smallest absolute signed
    % distance to the reference line. This is the best available
    % geometric approximation to the intended intersection.
    %
    % NOTE: this fallback is explicitly marked in the console so that
    % these frames can be reviewed later.

    [~, bestIdx] = min(abs(sides));

    crossPoint = contour(bestIdx,:);
    bracketIdx = [bestIdx bestIdx];
    tau = 0;

    fprintf('\n');
    fprintf('  WARNING: No sign-change crossing found.\n');
    fprintf('  No near-zero contour point within %.2f px.\n', lineTolerance);
    fprintf('  Using closest C2 contour point as robust fallback.\n');
    fprintf('  Index = %d\n', bestIdx);
    fprintf('  Point = (%.4f, %.4f)\n', ...
        crossPoint(1), crossPoint(2));
    fprintf('  |side| = %.6f px\n', abs(sides(bestIdx)));
    fprintf('  Signed-distance range = [%.3f, %.3f] px\n', ...
        min(sides), max(sides));
    fprintf('  Fallback status: REVIEW\n');

end