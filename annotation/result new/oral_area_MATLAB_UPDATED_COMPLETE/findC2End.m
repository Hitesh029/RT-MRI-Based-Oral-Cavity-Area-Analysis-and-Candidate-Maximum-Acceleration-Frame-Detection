function [C2end, idxC2end, tauC2end, tangentVec] = ...
    findC2End(C1, C2, VEL, velIdx)

% findC2End
%
% Determine the posterior endpoint of C2 using the local tangent
% of C1 approaching the VEL junction.
%
% VEL is treated as the endpoint of the anatomical C1 segment.
% Therefore the tangent is estimated from the C1 branch approaching
% VEL, rather than averaging the two traced branches around the
% corner.
%
% The C2 endpoint is then obtained by intersecting C2 with the
% line through VEL perpendicular to this incoming tangent.

    fprintf('\n');
    fprintf('========== C2 END DETECTION ==========\n');

    n1 = size(C1,1);

    if velIdx < 2 || velIdx > n1
        error('findC2End:invalidVELIndex', ...
            'VEL index must satisfy 2 <= velIdx <= size(C1,1).');
    end

    % ------------------------------------------------------------
    % Incoming tangent at VEL
    % ------------------------------------------------------------

    % Use the branch BEFORE VEL.
    %
    % A short multi-point direction is more stable than using
    % only C1(velIdx)-C1(velIdx-1).

    nBack = 4;

    firstIdx = max(1, velIdx - nBack);

    P0 = C1(firstIdx,:);
    P1 = C1(velIdx,:);

    rawTangent = P1 - P0;

    tangentNorm = norm(rawTangent);

    if tangentNorm < eps
        error('findC2End:zeroTangent', ...
            'Unable to estimate incoming C1 tangent at VEL.');
    end

    tangentVec = rawTangent / tangentNorm;

    fprintf('VEL = (%.4f, %.4f)\n', ...
        VEL(1), VEL(2));

    fprintf('VEL index = %d\n', velIdx);

    fprintf('Incoming tangent reference:\n');
    fprintf('  C1 index %d -> C1 index %d\n', ...
        firstIdx, velIdx);

    fprintf('  P0 = (%.4f, %.4f)\n', ...
        P0(1), P0(2));

    fprintf('  P1 = (%.4f, %.4f)\n', ...
        P1(1), P1(2));

    fprintf('Incoming tangent = (%.6f, %.6f)\n', ...
        tangentVec(1), tangentVec(2));

    % ------------------------------------------------------------
    % Find C2 intersection with line through VEL perpendicular
    % to incoming C1 tangent.
    %
    % The normal to tangentVec is:
    %
    %       n = [-ty, tx]
    %
    % For the sign test, the tangent vector itself is used:
    %
    %       (Q - VEL) . tangentVec = 0
    %
    % This represents the line through VEL perpendicular to
    % tangentVec.
    % ------------------------------------------------------------

    [C2end, idxC2end, tauC2end, ~] = ...
        findSignChangeCrossing( ...
            C2, VEL, tangentVec);

    % Normalize the returned index for both true crossings [i i+1]
    % and sampled/fallback results [i i].
    idxC2end = double(idxC2end(:).');
    if isempty(idxC2end)
        error('findC2End:emptyIndex','No C2 END index was returned.');
    elseif numel(idxC2end) == 1
        idxC2end = [idxC2end idxC2end];
    else
        idxC2end = idxC2end(1:2);
    end
    idxC2end = round(idxC2end);

    fprintf('\nSelected C2 END:\n');
    fprintf('  Point = (%.4f, %.4f)\n', ...
        C2end(1), C2end(2));
    fprintf('  Bracket = [%d, %d]\n', ...
        idxC2end(1), idxC2end(2));

    fprintf('  tau = %.6f\n', tauC2end);

    fprintf('======================================\n');

end