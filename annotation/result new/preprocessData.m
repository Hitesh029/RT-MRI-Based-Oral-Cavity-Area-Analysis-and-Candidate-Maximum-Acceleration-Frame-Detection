
function contourClean = preprocessData(contour, name)
% PREPROCESSDATA Normalize and clean an annotated contour.
% Accepted formats: Nx2, 2xN, or a scalar cell containing either.
% Coordinates are [x y]. Point order is preserved.
    if nargin < 2, name = 'contour'; end
    if iscell(contour)
        if numel(contour) ~= 1
            error('preprocessData:cellShape','%s is a cell with %d elements; expected one contour.',name,numel(contour));
        end
        contour = contour{1};
    end
    if isempty(contour)
        error('preprocessData:empty','%s is empty in the MAT annotation.',name);
    end
    if ~isnumeric(contour) || ~isreal(contour) || ndims(contour) ~= 2
        error('preprocessData:badType','%s must be a real numeric 2-D array; got %s.',name,class(contour));
    end
    if size(contour,2) == 2
        % Already Nx2
    elseif size(contour,1) == 2 && size(contour,2) > 2
        contour = contour.';
    else
        error('preprocessData:badShape','%s must be Nx2 or 2xN; got %s.',name,mat2str(size(contour)));
    end
    contour = double(contour);
    bad = any(~isfinite(contour),2);
    contour = contour(~bad,:);
    if size(contour,1) >= 2
        keep = [true; any(diff(contour,1,1) ~= 0,2)];
        contour = contour(keep,:);
    end
    if size(contour,1) < 2
        error('preprocessData:tooFewPoints','%s has fewer than 2 valid points.',name);
    end
    contourClean = contour;
    fprintf('%s normalized contour: %d x 2\\n',name,size(contourClean,1));
end
