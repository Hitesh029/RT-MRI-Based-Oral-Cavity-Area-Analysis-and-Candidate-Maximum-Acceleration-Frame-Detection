function [C2end, idxC2end, tauC2end, tangentVec, candidates] = findC2End_review(C1, C2, VEL, velIdx)
% FINDC2END_REVIEW
% Diagnostic C2 END detector using the incoming C1 tangent at VEL.
% It reports EVERY intersection of the perpendicular cutting line with C2.
% The closest-to-VEL candidate is returned for compatibility, but if there
% are multiple crossings the result is explicitly marked REVIEW: geometry
% alone cannot determine which crossing is anatomically intended.
%
% Inputs: C1, C2 are ordered Nx2 contours; VEL is [x y]; velIdx is nearest
% traced C1 index to VEL. Outputs match findC2End plus candidate diagnostics.

    validateattributes(C1, {'numeric'}, {'2d','ncols',2,'nonempty','finite'});
    validateattributes(C2, {'numeric'}, {'2d','ncols',2,'nonempty','finite'});
    validateattributes(VEL, {'numeric'}, {'vector','numel',2,'finite'});
    validateattributes(velIdx, {'numeric'}, {'scalar','integer','>=',2,'<=',size(C1,1)});

    C1 = double(C1); C2 = double(C2); VEL = double(VEL(:)).';

    % Estimate tangent from the C1 branch approaching VEL.
    nBack = min(4, velIdx-1);
    firstIdx = velIdx - nBack;
    rawTangent = C1(velIdx,:) - C1(firstIdx,:);
    tangentNorm = norm(rawTangent);
    if tangentNorm < eps
        error('findC2End_review:zeroTangent', ...
            'Cannot estimate incoming tangent: selected C1 points coincide.');
    end
    tangentVec = rawTangent / tangentNorm;

    % Cutting line through VEL, perpendicular to tangent:
    % side(Q) = (Q - VEL) dot tangentVec = 0.
    sides = (C2 - VEL) * tangentVec(:);
    candidates = struct('bracket',{},'tau',{},'point',{},'distanceToVEL',{},'sideBefore',{},'sideAfter',{});
    tol = 1e-10;
    for k = 1:size(C2,1)-1
        s1 = sides(k); s2 = sides(k+1);
        if abs(s1) <= tol
            p = C2(k,:); tau = 0; bracket = [k k];
        elseif s1*s2 < 0
            tau = s1/(s1-s2);
            p = C2(k,:) + tau*(C2(k+1,:)-C2(k,:));
            bracket = [k k+1];
        else
            continue;
        end
        % Avoid duplicate detection of the same sampled zero point.
        if ~isempty(candidates) && norm(candidates(end).point-p) < 1e-9
            continue;
        end
        candidates(end+1) = struct('bracket',bracket,'tau',tau,'point',p, ...
            'distanceToVEL',norm(p-VEL),'sideBefore',s1,'sideAfter',s2); %#ok<AGROW>
    end

    fprintf('\n===== C2 END CROSSING REVIEW =====\n');
    fprintf('VEL=(%.4f, %.4f), nearest C1 index=%d\n', VEL(1), VEL(2), velIdx);
    fprintf('Incoming tangent from C1(%d) -> C1(%d): (%.6f, %.6f)\n', ...
        firstIdx, velIdx, tangentVec(1), tangentVec(2));
    fprintf('C2 candidates found: %d\n', numel(candidates));

    if isempty(candidates)
        [~, bestIdx] = min(abs(sides));
        C2end = C2(bestIdx,:); idxC2end = [bestIdx bestIdx]; tauC2end = 0;
        warning('findC2End_review:noCrossing', ...
            'No true C2 intersection. Nearest-to-line point returned for inspection only.');
        fprintf('Fallback point C2(%d)=(%.4f, %.4f), |side|=%.4f [REVIEW]\n', ...
            bestIdx, C2end(1), C2end(2), abs(sides(bestIdx)));
        return;
    end

    for j = 1:numel(candidates)
        b = candidates(j).bracket;
        fprintf('Candidate %d: bracket [%d %d], tau=%.5f, point=(%.4f, %.4f), distance-to-VEL=%.4f\n', ...
            j, b(1), b(2), candidates(j).tau, candidates(j).point(1), ...
            candidates(j).point(2), candidates(j).distanceToVEL);
    end

    [~, best] = min([candidates.distanceToVEL]);
    C2end = candidates(best).point;
    idxC2end = candidates(best).bracket;
    tauC2end = candidates(best).tau;

    if numel(candidates) > 1
        warning('findC2End_review:multipleCrossings', ...
            ['Multiple C2 intersections found. Closest-to-VEL candidate is returned provisionally; ' ...
             'inspect the candidate plot/indices to confirm the anatomical crossing.']);
        fprintf('Provisional selection: candidate %d [REVIEW REQUIRED]\n', best);
    else
        fprintf('Single crossing found; still verify anatomy on MRI.\n');
    end
    fprintf('Selected point=(%.4f, %.4f), bracket=[%d %d], tau=%.5f\n', ...
        C2end(1), C2end(2), idxC2end(1), idxC2end(2), tauC2end);
    fprintf('==================================\n\n');
end
