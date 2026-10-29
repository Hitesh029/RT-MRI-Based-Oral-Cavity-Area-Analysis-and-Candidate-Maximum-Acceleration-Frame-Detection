function [LL, idxLL, tauLL] = findC2Start(C2, L, axisA, UL)
% FINDC2START  C2 starting point (LL) paired with C1 start (UL).
%
% Primary rule (unchanged):
%   LL is the intersection of C2 with the same anterior reference line
%   through L, perpendicular to axisA. The existing sign-change and
%   interpolation method is used whenever that intersection exists.
%
% Robust no-crossing rule:
%   If C2 does not cross the anterior line, do NOT blindly accept the
%   geometrically closest point to the line. That can select the wrong
%   C2 branch and create an artificial white area when the final polygon
%   is closed. Instead, use the already detected UL as the anatomical
%   pairing reference and select the C2 point closest to UL.
%
% This keeps the normal solution unchanged and only changes the
% no-crossing fallback.

    if nargin < 4
        UL = [];
    end

    fprintf('========== C2 START (LL) DETECTION ==========\n');
    fprintf('Total C2 points: %d\n', size(C2,1));
    fprintf('Reference L = (%.3f, %.3f)  [SAME anterior line as C1 START]\n', L(1), L(2));
    fprintf('Axis a = (%.4f, %.4f)\n\n', axisA(1), axisA(2));

    [LL, idxLL, tauLL, sides] = findSignChangeCrossing(C2, L, axisA);

    % Normal crossing / near-zero result: preserve the established method.
    if idxLL(1) ~= idxLL(2)
        fprintf('Bracketing pair found: index %d (side=%.4f) -> index %d (side=%.4f)\n', ...
            idxLL(1), sides(idxLL(1)), idxLL(2), sides(idxLL(2)));
        fprintf('Interpolation fraction tau = %.4f\n\n', tauLL);
        fprintf('Selected C2 START (LL):\n  Index bracket = [%d, %d]\n  X = %.4f\n  Y = %.4f\n\n', ...
            idxLL(1), idxLL(2), LL(1), LL(2));
        fprintf('Reason: exact/near-exact anterior reference-line intersection.\n');
        fprintf('================================================\n\n');
        return;
    end

    % No sign change (or near-zero fallback) was returned as [i i].
    % A near-zero point is already a good solution, so only replace the
    % fallback when it is genuinely far from the anterior reference line.
    lineDistance = abs(sides(idxLL(1)));
    nearZeroTolerance = 0.25;

    if lineDistance <= nearZeroTolerance
        fprintf('C2 START (LL): near-zero contour point retained.\n');
        fprintf('Index = %d, |side| = %.4f px\n', idxLL(1), lineDistance);
        fprintf('================================================\n\n');
        return;
    end

    % Robust anatomical fallback.
    % The correct lower boundary point should be paired with UL, not merely
    % with the mathematical reference line. This prevents the lower arc from
    % starting on a remote/incorrect C2 branch and producing extra area.
    if isempty(UL) || numel(UL) ~= 2 || any(~isfinite(UL(:)))
        % Backward-compatible fallback if UL is not supplied.
        [~, bestIdx] = min(abs(sides));
        LL = C2(bestIdx,:);
        idxLL = [bestIdx bestIdx];
        tauLL = 0;
        fprintf('\nWARNING: C2 has no anterior-line crossing and UL was not supplied.\n');
        fprintf('Using closest C2 point to the anterior reference line.\n');
        fprintf('Index = %d, point = (%.4f, %.4f), |side| = %.4f px\n', ...
            bestIdx, LL(1), LL(2), abs(sides(bestIdx)));
        fprintf('Fallback status: REVIEW\n');
        fprintf('================================================\n\n');
        return;
    end

    UL = double(UL(:)).';
    distancesToUL = sqrt(sum((double(C2) - UL).^2, 2));
    [bestDist, bestIdx] = min(distancesToUL);

    LL = double(C2(bestIdx,:));
    idxLL = [bestIdx bestIdx];
    tauLL = 0;

    fprintf('\nWARNING: No sign-change crossing found for C2.\n');
    fprintf('Anterior-line distance of old fallback = %.4f px\n', lineDistance);
    fprintf('Using UL-paired C2 point instead of the old line-only fallback.\n');
    fprintf('UL = (%.4f, %.4f)\n', UL(1), UL(2));
    fprintf('Selected LL index = %d\n', bestIdx);
    fprintf('LL = (%.4f, %.4f)\n', LL(1), LL(2));
    fprintf('Distance LL-to-UL = %.4f px\n', bestDist);
    fprintf('|side(LL)| = %.4f px\n', abs(sides(bestIdx)));
    fprintf('Fallback status: REVIEW\n');
    fprintf('Reason: pair LL with the detected UL to avoid selecting a remote C2 branch.\n');
    fprintf('================================================\n\n');
end
