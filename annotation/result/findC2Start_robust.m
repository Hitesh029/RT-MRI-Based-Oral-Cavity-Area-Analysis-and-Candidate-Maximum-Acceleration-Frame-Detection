function [LL, idxLL, tauLL] = findC2Start(C2, L, axisA)
% FINDC2START  Robust C2 starting point (LL).
%
% Primary rule:
%   SAME anterior line as C1 START (through L, perpendicular to axis a).
%   The original sign-change + interpolation method is preserved whenever
%   the C2 contour actually crosses that line.
%
% Robustness:
%   Some frames have C2 entirely on one side of the reference line, so
%   findSignChangeCrossing cannot find a crossing. In that case, use the
%   C2 point closest to the reference line as a controlled fallback.
%   This prevents otherwise valid frames from being lost.

    fprintf('========== C2 START (LL) DETECTION ==========\n');
    fprintf('Total C2 points: %d\n', size(C2,1));
    fprintf('Reference L = (%.3f, %.3f)  [SAME anterior line as C1 START]\n', L(1), L(2));
    fprintf('Axis a = (%.4f, %.4f)\n\n', axisA(1), axisA(2));

    try
        % =========================================================
        % PRIMARY METHOD: existing sign-change + interpolation
        % =========================================================
        [LL, idxLL, tauLL, sides] = ...
            findSignChangeCrossing(C2, L, axisA);

        usedFallback = false;

    catch ME
        % =========================================================
        % FALLBACK: C2 does not cross the reference line
        % =========================================================
        if contains(ME.message, 'No sign change found along this contour')

            C2 = double(C2);
            L = double(L(:)).';
            axisA = double(axisA(:)).';

            % Perpendicular to anatomical axis.
            testVec = [-axisA(2), axisA(1)];
            testVec = testVec / max(norm(testVec), eps);

            % Signed distance of every C2 point from the anterior line.
            rel = C2 - L;
            sides = rel * testVec(:);

            % Select the C2 point closest to the reference line.
            [~, idxLL] = min(abs(sides));

            % No interpolation bracket exists in this case.
            tauLL = 0;
            LL = C2(idxLL,:);

            usedFallback = true;

            fprintf(2, ['WARNING: C2 does not cross the reference line. ', ...
                        'Using nearest valid C2 point as LL.\n']);
            fprintf('Fallback: minimum absolute signed distance = %.6f\n', ...
                    abs(sides(idxLL)));
        else
            % Do not hide unrelated errors.
            rethrow(ME);
        end
    end

    % Print all candidate side values for debugging.
    for k = 1:numel(sides)
        fprintf('Candidate %d:\n  Index = %d\n  X = %.3f\n  Y = %.3f\n  side(Q) = %.4f\n\n', ...
                k, k, C2(k,1), C2(k,2), sides(k));
    end

    if ~usedFallback
        fprintf('Bracketing pair found: index %d (side=%.4f) -> index %d (side=%.4f)\n', ...
                idxLL, sides(idxLL), idxLL+1, sides(idxLL+1));
        fprintf('Interpolation fraction tau = %.4f\n\n', tauLL);

        fprintf('Selected C2 START (LL):\n  Index bracket = [%d, %d]\n  X = %.4f\n  Y = %.4f\n\n', ...
                idxLL, idxLL+1, LL(1), LL(2));
    else
        fprintf('Selected C2 START (LL) [FALLBACK]:\n');
        fprintf('  Nearest contour index = %d\n', idxLL);
        fprintf('  X = %.4f\n  Y = %.4f\n', LL(1), LL(2));
        fprintf('  tau = %.4f\n\n', tauLL);
    end

    fprintf('Reason: same anterior reference line as UL; fallback is used only\n');
    fprintf('        when this C2 contour does not geometrically cross that line.\n');
    fprintf('================================================\n\n');
end
