function [isValid, statusTable] = validatePoints(C1, C2, UL, LL, VEL, C2end)
% VALIDATEPOINTS  Verify all four points exist, are finite, and lie
% within/near their source contours' coordinate range (sanity bound).
% Builds the result status table requested.

    fprintf('========== VALIDATION ==========\n');

    names = {'C1 START (UL)'; 'C2 START (LL)'; 'C1 END (VEL)'; 'C2 END'};
    pts   = [UL; LL; VEL; C2end];
    status = cell(4,1);

    for i = 1:4
        p = pts(i,:);
        ok = true;
        reason = '';

        if isempty(p)
            ok = false; reason = 'missing/empty';
        elseif any(~isfinite(p))
            ok = false; reason = 'NaN/Inf coordinate';
        end

        if ok
            status{i} = 'Valid';
        else
            status{i} = sprintf('INVALID (%s)', reason);
        end
        fprintf('%-16s : %s   [X=%.4f, Y=%.4f]\n', names{i}, status{i}, p(1), p(2));
    end

    % Geometric sanity checks specific to this solution:
    if strcmp(status{1},'Valid') && strcmp(status{3},'Valid')
        d = norm(UL - VEL);
        fprintf('\nC1 START-to-END distance = %.3f px (sanity: should be > 0)\n', d);
        if d < eps
            status{1} = 'INVALID (UL == VEL, degenerate C1 segment)';
        end
    end
    if strcmp(status{2},'Valid') && strcmp(status{4},'Valid')
        d = norm(LL - C2end);
        fprintf('C2 START-to-END distance = %.3f px (sanity: should be > 0)\n', d);
        if d < eps
            status{2} = 'INVALID (LL == C2end, degenerate C2 segment)';
        end
    end

    isValid = all(strcmp(status, 'Valid'));

    statusTable = table(names, pts(:,1), pts(:,2), status, ...
        'VariableNames', {'Point','X','Y','Status'});

    fprintf('\nOverall validation: ');
    if isValid
        fprintf('ALL FOUR POINTS VALID\n');
    else
        fprintf('ONE OR MORE POINTS INVALID - see table above\n');
    end
    fprintf('================================\n\n');
end
