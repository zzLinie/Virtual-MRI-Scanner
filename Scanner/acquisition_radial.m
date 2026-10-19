function radial_image = acquisition_radial(P, n_lines, point_density, image_size)
    % P = phantom image
    % n_lines = number of lines (spokes) to be collected
    % point_density = number of samples collected per acquired line

    % resize phantom and top-left pad
    P_resized = imresize(P, [image_size, image_size]);
    [prows, pcols] = size(P);
    padding_factor = prows / image_size;
    kspace_size = round(image_size * padding_factor);
    P_big = zeros(kspace_size, kspace_size);
    P_big(1:image_size, 1:image_size) = P_resized;

    % centered enlarged k-space
    P_fft = fftshift(fft2(P_big));
    [N_y, N_x] = size(P_fft);

    % center coords
    center_y = floor(N_y / 2) + 1;
    center_x = floor(N_x / 2) + 1;

    % map radial spokes angles on enlarged grid
    thetas = linspace(0, pi, n_lines+1);
    thetas = thetas(1:end-1);
    % radius
    radius_max_source = min([center_x-1, N_x-center_x, center_y-1, N_y-center_y]);
    radius_source = linspace(-radius_max_source, +radius_max_source, point_density);

    % count accumulated pixel samples for averaging
    K_sum   = zeros(N_y, N_x, 'like', P_fft);
    K_count = zeros(N_y, N_x);

    % sample radial spokes and interpolate to output grid
    for i = 1:numel(thetas)
        th = thetas(i);

        % compute cartesian coordinates of the sampling points
        source_kx = center_x + radius_source .* cos(th);
        source_ky = center_y + radius_source .* sin(th);
        spoke = interp2(1:N_x, 1:N_y, P_fft, source_kx, source_ky, 'linear', 0);

        % round acquired coordinates to nearest pixel
        xi = round(source_kx);
        yi = round(source_ky);
        valid = xi>=1 & xi<=N_x & yi>=1 & yi<=N_y;
        xi = xi(valid);
        yi = yi(valid);
        s = spoke(valid);

        % place interpolated values onto output k-space grid
        for j = 1:numel(xi)
            idx = sub2ind([N_y, N_x], yi(j), xi(j));
            K_sum(idx)   = K_sum(idx)   + s(j);
            K_count(idx) = K_count(idx) + 1;
        end
    end

    % per-pixel averaging
    K_enlarged = zeros(N_y, N_x, 'like', K_sum);
    mask_filled = K_count > 0;
    K_enlarged(mask_filled) = K_sum(mask_filled) ./ K_count(mask_filled);

    % apply circular mask
    [X, Y] = meshgrid(1:N_x, 1:N_y);
    R = sqrt((X - center_x).^2 + (Y - center_y).^2);
    r_circ = (image_size/2 - 1) * (N_y / image_size);
    circ_mask = R <= r_circ;

    % return acquired radial k-space (main program will ifft and display)
    radial_image = K_enlarged .* circ_mask;
end
