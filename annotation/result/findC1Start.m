function [UL, idxUL, tauUL] = findC1Start(C1, L, axisA)
% FINDC1START  C1's starting point (UL).
% Rule (as derived): the anterior reference line passes through
% landmark L, perpendicular to axis 'a'. side(Q) = (Q-L).a is computed
% for every C1 point in traced order; the first consecutive pair whose
% sign flips brackets UL; linear interpolation gives the exact point.

fprintf('========== C1 START (UL) DETECTION ==========\n');
fprintf('Total C1 points: %d\n', size(C1,1));
fprintf('Reference L = (%.3f, %.3f)\n', L(1), L(2));
fprintf('Axis a = (%.4f, %.4f)\n\n', axisA(1), axisA(2));

[UL, idxUL, tauUL, sides] = findSignChangeCrossing(C1, L, axisA);

for k = 1:numel(sides)
    fprintf('Candidate %d:\n  Index = %d\n  X = %.3f\n  Y = %.3f\n  side(Q) = %.4f\n\n', ...
        k, k, C1(k,1), C1(k,2), sides(k));
end

fprintf('Bracketing pair found: index %d (side=%.4f) -> index %d (side=%.4f)\n', ...
    idxUL, sides(idxUL), idxUL+1, sides(idxUL+1));
fprintf('Interpolation fraction tau = %.4f\n\n', tauUL);

fprintf('Selected C1 START (UL):\n  Index bracket = [%d, %d]\n  X = %.4f\n  Y = %.4f\n\n', ...
    idxUL, idxUL+1, UL(1), UL(2));
fprintf('Reason: first traced-order point pair on C1 whose side(Q)=(Q-L).a\n');
fprintf('        changes sign, interpolated to the exact zero-crossing.\n');
fprintf('================================================\n\n');
end