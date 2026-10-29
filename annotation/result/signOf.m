function side = signOf(Q, refPoint, testVec)
% SIGNOF  side(Q) = (Q - ref) . testVec  (a signed scalar, not a direction)
    side = dot(Q - refPoint, testVec);
end
