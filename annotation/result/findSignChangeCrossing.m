function [crossPoint, bracketIdx, tau, sides] = ...
    findSignChangeCrossing(contour, refPoint, testVec)

% FINDSIGNCHANGECROSSING
% Finds the intersection of an ordered contour with the line:
%       (Q - refPoint) . testVec = 0
%
% Primary method:
%   Sign-change interpolation between consecutive contour points.
%
% Secondary method:
%   If a sampled contour point is very close to the line, accept it.
%
% Final robust fallback:
%   If there is no crossing and no near-zero point, return the closest
%   contour point to the line instead of failing the whole frame.
%
% IMPORTANT:
%   The generic final fallback is intentionally retained here for backward
%   compatibility. C2-start has an additional anatomical fallback in
%   findC2Start.m that pairs LL with UL, which is what prevents the unwanted
%   area extension seen in the final polygon.

    if isempty(contour) || size(contour,2) ~= 2
        error('findSignChangeCrossing:invalidContour', ...
            'Contour must be an Nx2 non-empty array.');
    end

    if numel(refPoint) ~= 2 || numel(testVec) ~= 2
        error('findSignChangeCrossing:invalidReference', ...
            'refPoint and testVec must be 1x2 vectors.');
    end

    refPoint = double(refPoint(:)).';
    testVec  = double(testVec(:)).';

    testNorm = norm(testVec);
    if testNorm < eps
        error('findSignChangeCrossing:zeroTestVector', ...
            'testVec must be non-zero.');
    end
    testVec = testVec / testNorm;

    contour = double(contour);
    n = size(contour,1);

    % Signed distances from every contour point to the reference line.
    sides = zeros(n,1);
    for i = 1:n
        sides(i) = dot(contour(i,:) - refPoint, testVec);
    end

    % ------------------------------------------------------------
    % Primary method: sign-change crossings
    % ------------------------------------------------------------
    crossingPoints = zeros(0,2);
    crossingBrackets = zeros(0,2);
    crossingTau = zeros(0,1);
    crossingDistances = zeros(0,1);

    for k = 1:n-1
        s1 = sides(k);
        s2 = sides(k+1);

        if s1 == 0
            pt = contour(k,:);
            crossingPoints(end+1,:) = pt; %#ok<AGROW>
            crossingBrackets(end+1,:) = [k k]; %#ok<AGROW>
            crossingTau(end+1,1) = 0; %#ok<AGROW>
            crossingDistances(end+1,1) = norm(pt-refPoint); %#ok<AGROW>
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
    % Primary result / near-zero refinement
    % ------------------------------------------------------------
    if ~isempty(crossingPoints)
        [minCrossDist, ~] = min(crossingDistances);

        lineTolerance = 0.25;
        nearZeroMask = abs(sides) <= lineTolerance;

        if any(nearZeroMask)
            nearIdx = find(nearZeroMask);
            nearDistances = zeros(size(nearIdx));
            for j = 1:numel(nearIdx)
                nearDistances(j) = norm(contour(nearIdx(j),:) - refPoint);
            end

            [minNearDist, nearBestLocal] = min(nearDistances);
            bestNearIdx = nearIdx(nearBestLocal);

            if minNearDist < minCrossDist
                crossPoint = contour(bestNearIdx,:);
                bracketIdx = [bestNearIdx bestNearIdx];
                tau = 0;
                fprintf('\nNOTE: contour has a near-zero point closer to refPoint than the available sign-change crossings.\n');
                fprintf('Near-zero point index = %d\n', bestNearIdx);
                fprintf('Point = (%.4f, %.4f)\n', crossPoint(1), crossPoint(2));
                fprintf('|side| = %.6f px\n', abs(sides(bestNearIdx)));
                fprintf('Distance to refPoint = %.4f px\n', minNearDist);
                return;
            end
        end

        [~, bestCross] = min(crossingDistances);
        crossPoint = crossingPoints(bestCross,:);
        bracketIdx = crossingBrackets(bestCross,:);
        tau = crossingTau(bestCross);

        if size(crossingPoints,1) > 1
            fprintf('\nNOTE: %d sign-change crossings found; selecting the one closest to refPoint.\n', ...
                size(crossingPoints,1));
            for j = 1:size(crossingPoints,1)
                fprintf('  Crossing %d: index [%d,%d], point=(%.3f,%.3f), dist=%.3f\n', ...
                    j, crossingBrackets(j,1), crossingBrackets(j,2), ...
                    crossingPoints(j,1), crossingPoints(j,2), crossingDistances(j));
            end
        end
        return;
    end

    % ------------------------------------------------------------
    % No sign-change crossing: near-zero sampled point
    % ------------------------------------------------------------
    lineTolerance = 0.25;
    nearZeroMask = abs(sides) <= lineTolerance;

    if any(nearZeroMask)
        nearIdx = find(nearZeroMask);
        distances = zeros(size(nearIdx));
        for j = 1:numel(nearIdx)
            distances(j) = norm(contour(nearIdx(j),:) - refPoint);
        end

        [~, bestLocal] = min(distances);
        bestIdx = nearIdx(bestLocal);

        crossPoint = contour(bestIdx,:);
        bracketIdx = [bestIdx bestIdx];
        tau = 0;

        fprintf('\nNOTE: No sign-change crossing found.\n');
        fprintf('Using nearest near-zero contour point instead.\n');
        fprintf('Index = %d\n', bestIdx);
        fprintf('Point = (%.4f, %.4f)\n', crossPoint(1), crossPoint(2));
        fprintf('|side| = %.6f px\n', abs(sides(bestIdx)));
        return;
    end

    % ------------------------------------------------------------
    % Genuine geometric no-crossing fallback
    % ------------------------------------------------------------
    [~, bestIdx] = min(abs(sides));

    crossPoint = contour(bestIdx,:);
    bracketIdx = [bestIdx bestIdx];
    tau = 0;

    fprintf('\nWARNING: No sign-change crossing found.\n');
    fprintf('No near-zero contour point within %.2f px.\n', lineTolerance);
    fprintf('Generic fallback point = C%d = (%.4f, %.4f)\n', ...
        bestIdx, crossPoint(1), crossPoint(2));
    fprintf('|side| = %.6f px\n', abs(sides(bestIdx)));
    fprintf('Signed-distance range = [%.3f, %.3f] px\n', min(sides), max(sides));
    fprintf('Fallback status: REVIEW\n');
end
