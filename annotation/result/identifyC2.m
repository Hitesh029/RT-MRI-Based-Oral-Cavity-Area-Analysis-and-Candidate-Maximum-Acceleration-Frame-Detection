function C2 = identifyC2(C2raw)
% IDENTIFYC2  Validate that C2raw is a usable C2 (lower) contour.
    fprintf('========== IDENTIFY C2 ==========\n');
    if isempty(C2raw)
        error('identifyC2:missing', 'C2 is missing/empty for this frame.');
    end
    if size(C2raw, 2) ~= 2
        error('identifyC2:badShape', 'C2 must be Nx2. Got %s.', mat2str(size(C2raw)));
    end
    fprintf('C2 identified: %d points, x range [%.2f, %.2f], y range [%.2f, %.2f]\n', ...
        size(C2raw,1), min(C2raw(:,1)), max(C2raw(:,1)), min(C2raw(:,2)), max(C2raw(:,2)));
    fprintf('==================================\n\n');
    C2 = C2raw;
end
