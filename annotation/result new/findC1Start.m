function [UL, idxUL, tauUL] = findC1Start(C1, L, axisA)
% FINDC1START  C1 starting point (UL).
% Rule: the anterior reference line passes through L, perpendicular to
% axisA. side(Q) = (Q-L)*axisA is evaluated in traced contour order.
% The selected consecutive sign-change pair brackets UL and linear
% interpolation gives the zero crossing.
%
% Visualization labels are handled by the main figure legend; this
% function intentionally does not print every contour candidate.

    fprintf('========== C1 START (UL) DETECTION ==========\n');
    fprintf('Total C1 points: %d\n', size(C1,1));
    fprintf('Reference L = (%.3f, %.3f)\n', L(1), L(2));
    fprintf('Axis a = (%.4f, %.4f)\n\n', axisA(1), axisA(2));

    [UL, idxUL, tauUL, sides] = findSignChangeCrossing(C1, L, axisA);

    % findSignChangeCrossing returns a two-element bracket [i i+1]
    % for a true crossing and [i i] for a sampled/nearest fallback.
    idxUL = double(idxUL(:).');
    if isempty(idxUL)
        error('findC1Start:emptyIndex','No C1 START index was returned.');
    end
    if numel(idxUL) == 1
        idxUL = [idxUL idxUL];
    else
        idxUL = idxUL(1:2);
    end

    i1 = round(idxUL(1));
    i2 = round(idxUL(2));

    if i1 < 1 || i1 > size(C1,1) || i2 < 1 || i2 > size(C1,1)
        error('findC1Start:badBracket','Returned C1 START bracket is outside C1.');
    end

    if i1 ~= i2
        fprintf('Bracketing pair found:\n');
        fprintf('  Point i   = %d   side = %.4f\n', i1, sides(i1));
        fprintf('  Point i+1 = %d   side = %.4f\n', i2, sides(i2));
        fprintf('  P(i)   = (%.4f, %.4f)\n', C1(i1,1), C1(i1,2));
        fprintf('  P(i+1) = (%.4f, %.4f)\n', C1(i2,1), C1(i2,2));
        fprintf('  Interpolation fraction tau = %.4f\n\n', tauUL);
        reason = 'first traced-order point pair whose side(Q) changes sign; interpolated zero-crossing.';
    else
        fprintf('Selected sampled/fallback point:\n');
        fprintf('  Index = %d\n', i1);
        fprintf('  Point = (%.4f, %.4f)\n', C1(i1,1), C1(i1,2));
        fprintf('  side(Q) = %.6f\n', sides(i1));
        fprintf('  tau = %.4f\n\n', tauUL);
        reason = 'near-zero or fallback contour point; review if marked REVIEW by crossing helper.';
    end

    fprintf('Selected C1 START (UL):\n');
    fprintf('  Index bracket = [%d, %d]\n', i1, i2);
    fprintf('  X = %.4f\n', UL(1));
    fprintf('  Y = %.4f\n', UL(2));
    fprintf('  Reason: %s\n', reason);
    fprintf('================================================\n\n');
end
