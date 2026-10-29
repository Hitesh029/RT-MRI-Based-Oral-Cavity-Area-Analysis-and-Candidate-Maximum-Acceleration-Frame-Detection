function C1 = identifyC1(C1raw)
% IDENTIFYC1  Validate that C1raw is a usable C1 (upper) contour.
% Does not alter point order or values - only checks structure.
    fprintf('========== IDENTIFY C1 ==========\n');
    if isempty(C1raw)
        error('identifyC1:missing', 'C1 is missing/empty for this frame.');
    end
    if size(C1raw, 2) ~= 2
        error('identifyC1:badShape', 'C1 must be Nx2. Got %s.', mat2str(size(C1raw)));
    end
    fprintf('C1 identified: %d points, x range [%.2f, %.2f], y range [%.2f, %.2f]\n', ...
        size(C1raw,1), min(C1raw(:,1)), max(C1raw(:,1)), min(C1raw(:,2)), max(C1raw(:,2)));
    fprintf('==================================\n\n');
    C1 = C1raw;
end
