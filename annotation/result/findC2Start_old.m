function [LL, idxLL, tauLL] = findC2Start(C2, L, axisA)
% FINDC2START  C2's starting point (LL).
% Rule (as derived): SAME anterior line as C1 START (through L,
% perpendicular to axis a) - not a new line. Same sign-change +
% interpolation technique applied to C2's traced points.

    fprintf('========== C2 START (LL) DETECTION ==========\n');
    fprintf('Total C2 points: %d\n', size(C2,1));
    fprintf('Reference L = (%.3f, %.3f)  [SAME anterior line as C1 START]\n', L(1), L(2));
    fprintf('Axis a = (%.4f, %.4f)\n\n', axisA(1), axisA(2));

    [LL, idxLL, tauLL, sides] = findSignChangeCrossing(C2, L, axisA);

    for k = 1:numel(sides)
        fprintf('Candidate %d:\n  Index = %d\n  X = %.3f\n  Y = %.3f\n  side(Q) = %.4f\n\n', ...
                k, k, C2(k,1), C2(k,2), sides(k));
    end

    fprintf('Bracketing pair found: index %d (side=%.4f) -> index %d (side=%.4f)\n', ...
            idxLL, sides(idxLL), idxLL+1, sides(idxLL+1));
    fprintf('Interpolation fraction tau = %.4f\n\n', tauLL);

    fprintf('Selected C2 START (LL):\n  Index bracket = [%d, %d]\n  X = %.4f\n  Y = %.4f\n\n', ...
            idxLL, idxLL+1, LL(1), LL(2));
    fprintf('Reason: same anterior line as UL, guaranteeing UL and LL sit\n');
    fprintf('        at the same anatomical station (same x along axis a).\n');
    fprintf('================================================\n\n');
end
