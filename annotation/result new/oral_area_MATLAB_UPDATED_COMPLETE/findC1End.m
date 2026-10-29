function [VEL, velIdx, gapDist] = ...
    findC1End(C1, C3, tolerancePx, VEL_manual)

% findC1End
%
% C1 ending point = VEL.
%
% The manual VEL annotation is used as the anatomical reference
% because contour tracing order is not guaranteed to place VEL
% at the final C1 array element.
%
% The closest C1 traced point to the manual VEL is reported as
% velIdx.
%
% C3 is used only as a consistency check.

    fprintf('\n');
    fprintf('========== C1 END (VEL) DETECTION ==========\n');

    if isempty(C1)
        error('findC1End:emptyC1', ...
            'C1 contour is empty.');
    end

    if isempty(VEL_manual) || numel(VEL_manual) ~= 2 || ...
            any(~isfinite(VEL_manual))

        error('findC1End:invalidManualVEL', ...
            'A valid manual VEL point is required.');
    end

    VEL_manual = VEL_manual(:).';

    fprintf('Total C1 points: %d\n', size(C1,1));

    if ~isempty(C3)
        fprintf('Total C3 points: %d\n', size(C3,1));
    end

    fprintf('Manual VEL = (%.3f, %.3f)\n', ...
        VEL_manual(1), VEL_manual(2));

    fprintf('Tolerance = %.3f px\n', tolerancePx);

    % ------------------------------------------------------------
    % Find closest C1 traced point to manual VEL
    % ------------------------------------------------------------

    dC1 = sqrt(sum((C1 - VEL_manual).^2, 2));

    [minC1Dist, velIdx] = min(dC1);

    % The anatomical VEL itself is the manual/interpolated point.
    VEL = VEL_manual;

    fprintf('\n');
    fprintf('Closest C1 point to manual VEL:\n');
    fprintf('  Index = %d\n', velIdx);
    fprintf('  X = %.3f\n', C1(velIdx,1));
    fprintf('  Y = %.3f\n', C1(velIdx,2));
    fprintf('  Distance to manual VEL = %.4f px\n', minC1Dist);

    % ------------------------------------------------------------
    % C3 consistency check
    % ------------------------------------------------------------

    if ~isempty(C3)

        dC3 = sqrt(sum((C3 - VEL_manual).^2, 2));

        [minC3Dist, c3Idx] = min(dC3);

        fprintf('\nClosest C3 point to manual VEL:\n');
        fprintf('  Index = %d\n', c3Idx);
        fprintf('  X = %.3f\n', C3(c3Idx,1));
        fprintf('  Y = %.3f\n', C3(c3Idx,2));
        fprintf('  Distance to manual VEL = %.4f px\n', ...
            minC3Dist);

        gapDist = minC3Dist;

        if gapDist > tolerancePx

            warning('findC1End:VELC3Gap', ...
                ['Manual VEL and nearest C3 point are %.3f px ' ...
                 'apart, exceeding tolerance %.3f px. ' ...
                 'VEL is retained because it is the supplied ' ...
                 'anatomical landmark.'], ...
                 gapDist, tolerancePx);
        else

            fprintf('\nVEL-C3 consistency check PASSED.\n');
        end

    else

        gapDist = NaN;

        fprintf('\nC3 not available; VEL-C3 consistency check skipped.\n');
    end

    fprintf('\nSelected C1 END (VEL):\n');
    fprintf('  VEL = (%.4f, %.4f)\n', ...
        VEL(1), VEL(2));

    fprintf('  C1 index nearest VEL = %d\n', velIdx);

    fprintf('============================================\n');

end update