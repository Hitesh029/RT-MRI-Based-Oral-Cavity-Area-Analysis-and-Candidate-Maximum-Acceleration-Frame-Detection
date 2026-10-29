function t = localTangent(C1, k)
% localTangent
%
% Estimate the tangent of C1 at point k.
%
% IMPORTANT:
% At VEL, k is an endpoint/corner of C1. Therefore a centered
% difference would mix the incoming C1 branch with the outgoing
% traced branch. For an endpoint such as VEL, use the incoming
% contour direction.
%
% For interior points, a centered finite difference is used.

    n = size(C1,1);

    if n < 2
        error('localTangent:tooFewPoints', ...
            'C1 must contain at least two points.');
    end

    if k < 1 || k > n
        error('localTangent:invalidIndex', ...
            'Tangent index is outside C1.');
    end

    % ------------------------------------------------------------
    % Endpoint: use incoming direction
    % ------------------------------------------------------------

    if k == n

        raw = C1(k,:) - C1(k-1,:);

    % ------------------------------------------------------------
    % First point: use outgoing direction
    % ------------------------------------------------------------

    elseif k == 1

        raw = C1(2,:) - C1(1,:);

    % ------------------------------------------------------------
    % Interior point: centered tangent
    % ------------------------------------------------------------

    else

        raw = C1(k+1,:) - C1(k-1,:);

    end

    normRaw = norm(raw);

    if normRaw < eps
        error('localTangent:zeroTangent', ...
            'Cannot calculate tangent: neighboring C1 points are identical.');
    end

    t = raw / normRaw;

end