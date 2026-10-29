function [VEL, velIdx, gapDist] = findC1End(C1, C3, tolerancePx, VEL_manual)

fprintf('\n');
fprintf('========== C1 END (VEL) DETECTION ==========\n');

if nargin < 4
    error('findC1End:notEnoughInputs', ...
        'findC1End requires C1, C3, tolerancePx, and VEL_manual.');
end

if isempty(C1) || size(C1,2) ~= 2
    error('findC1End:invalidC1', ...
        'C1 must be a non-empty N x 2 contour.');
end

if ~isempty(C3) && size(C3,2) ~= 2
    error('findC1End:invalidC3', ...
        'C3 must be empty or an M x 2 contour.');
end

if ~isscalar(tolerancePx) || ~isfinite(tolerancePx) || tolerancePx < 0
    error('findC1End:invalidTolerance', ...
        'tolerancePx must be a finite non-negative scalar.');
end

if isempty(VEL_manual) || numel(VEL_manual) ~= 2 || ...
        any(~isfinite(VEL_manual))
    error('findC1End:invalidManualVEL', ...
        'A valid manual VEL point [x y] is required.');
end

VEL_manual = double(VEL_manual(:).');

fprintf('Total C1 points: %d\n', size(C1,1));

if ~isempty(C3)
    fprintf('Total C3 points: %d\n', size(C3,1));
end

fprintf('Manual VEL = (%.3f, %.3f)\n', ...
    VEL_manual(1), VEL_manual(2));

fprintf('Tolerance = %.3f px\n', tolerancePx);

% ---------------------------------------------------------
% Find nearest traced C1 point to manual VEL
% ---------------------------------------------------------

dC1 = sqrt(sum((double(C1) - VEL_manual).^2, 2));

[minC1Dist, velIdx] = min(dC1);

% IMPORTANT:
% VEL remains the manual anatomical landmark.
VEL = VEL_manual;

fprintf('\n');
fprintf('Closest C1 point to manual VEL:\n');
fprintf('  Index = %d\n', velIdx);
fprintf('  X = %.3f\n', C1(velIdx,1));
fprintf('  Y = %.3f\n', C1(velIdx,2));
fprintf('  Distance to manual VEL = %.4f px\n', minC1Dist);

% ---------------------------------------------------------
% C3 consistency check
% ---------------------------------------------------------

if ~isempty(C3)

    dC3 = sqrt(sum((double(C3) - VEL_manual).^2, 2));

    [minC3Dist, c3Idx] = min(dC3);

    fprintf('\n');
    fprintf('Closest C3 point to manual VEL:\n');
    fprintf('  Index = %d\n', c3Idx);
    fprintf('  X = %.3f\n', C3(c3Idx,1));
    fprintf('  Y = %.3f\n', C3(c3Idx,2));
    fprintf('  Distance to manual VEL = %.4f px\n', minC3Dist);

    gapDist = minC3Dist;

    if gapDist > tolerancePx

        warning('findC1End:VELC3Gap', ...
            ['Manual VEL and nearest C3 point are %.3f px ' ...
             'apart, exceeding tolerance %.3f px. ' ...
             'VEL is retained because it is the supplied ' ...
             'anatomical landmark.'], ...
             gapDist, tolerancePx);

        fprintf('VEL-C3 consistency status: REVIEW\n');

    else

        fprintf('\nVEL-C3 consistency check PASSED.\n');
        fprintf('VEL-C3 consistency status: OK\n');

    end

else

    gapDist = NaN;

    fprintf('\n');
    fprintf('C3 not available; VEL-C3 consistency check skipped.\n');
    fprintf('VEL-C3 consistency status: NOT CHECKED\n');

end

fprintf('\n');
fprintf('Selected C1 END (VEL):\n');
fprintf('  VEL = (%.4f, %.4f)\n', VEL(1), VEL(2));
fprintf('  C1 index nearest VEL = %d\n', velIdx);
fprintf('============================================\n\n');

end