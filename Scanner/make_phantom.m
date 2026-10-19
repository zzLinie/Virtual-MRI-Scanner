% allows custom phantom with both ellipses and/or rectangles
function P = make_phantom(E, n)
    % default 4k phantom
    if nargin < 2
        fprintf('no dimensions specified, defaulting to 4k phantom');
        n = 4096;
    end

    % grid in [-1,1] x [-1,1]
    [x, y] = meshgrid(linspace(-1,1,n));
    P = zeros(n);
    
    for k = 1:size(E,1)
        A   = E(k,1); % signal intensity
        a   = E(k,2); % horizontal semiaxis length of ellipse | width of rectangle
        b   = E(k,3); % vertical semiaxis length of ellipse | height of rectangle
        x0  = E(k,4); % center x-coord
        y0  = E(k,5); % center y-coord
        phi = E(k,6) * pi/180; % rotation
        type = E(k,7); % shape of structure, 0 = ellipse | 1 = rectangle

        % translate
        xt = x - x0;
        yt = y - y0;

        % rotate coordinates by -phi (so phi is ellipse/rectangle rotation angle)
        c = cos(phi); s = sin(phi);
        xr =  c * xt + s * yt;
        yr = -s * xt + c * yt;

        if type == 0
            mask = (xr./a).^2 + (yr./b).^2 <= 1;
        else
            mask = (abs(xr) <= a) & (abs(yr) <= b);
        end

        % add each structure shape with signal intensity to phantom
        P(mask) = A;
    end
end