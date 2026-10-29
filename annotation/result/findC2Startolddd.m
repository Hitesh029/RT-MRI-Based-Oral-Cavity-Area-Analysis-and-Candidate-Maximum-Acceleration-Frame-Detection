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

    % A normal interpolation has two different bracket indices.
    % A fallback has [i i] and tau = 0.
    if idxLL(1) == idxLL(2)
        fprintf('C2 START (LL) used FALLBACK point.\n');
        fprintf('Nearest contour index = %d\n', idxLL(1));
        fprintf('X = %.4f, Y = %.4f\n', LL(1), LL(2));
        fprintf('tau = %.4f\n\n', tauLL);
    else
        fprintf('Bracketing pair found: index %d (side=%.4f) -> index %d (side=%.4f)\n', ...
                idxLL(1), sides(idxLL(1)), idxLL(2), sides(idxLL(2)));
        fprintf('Interpolation fraction tau = %.4f\n\n', tauLL);

        fprintf('Selected C2 START (LL):\n  Index bracket = [%d, %d]\n  X = %.4f\n  Y = %.4f\n\n', ...
                idxLL(1), idxLL(2), LL(1), LL(2));
    end

    fprintf('Reason: same anterior reference line as UL; when the discrete C2\n');
    fprintf('        contour does not cross it, the closest contour point is used.\n');
    fprintf('================================================\n\n');
end
