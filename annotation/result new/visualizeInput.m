function visualizeInput(MRI, C1raw, C2raw, C3raw)
% VISUALIZEINPUT
% Original MRI frame with raw C1/C2/C3 contours.
%
% NO circle markers.
% NO contour point markers.

    figure( ...
        'Name', 'Original MRI Frame - Raw Contours', ...
        'NumberTitle', 'off', ...
        'Color', 'w');

    imagesc(MRI);
    colormap gray;
    axis image;
    hold on;

    % C1
    if ~isempty(C1raw)
        plot(C1raw(:,1), C1raw(:,2), ...
            'r-', ...
            'LineWidth', 1.5, ...
            'DisplayName', 'C1');
    end

    % C2
    if ~isempty(C2raw)
        plot(C2raw(:,1), C2raw(:,2), ...
            'g-', ...
            'LineWidth', 1.5, ...
            'DisplayName', 'C2');
    end

    % C3
    if ~isempty(C3raw)
        plot(C3raw(:,1), C3raw(:,2), ...
            'c-', ...
            'LineWidth', 1.5, ...
            'DisplayName', 'C3');
    end

    title('Original MRI Frame - Raw Contours');

    xlabel('X');
    ylabel('Y');

    legend('show', 'Location', 'best');

    set(gca, 'YDir', 'reverse');

    hold off;

end