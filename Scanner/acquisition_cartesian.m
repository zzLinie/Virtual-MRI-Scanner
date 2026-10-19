function cartesian_image = acquisition_cartesian(P, n_lines, point_density, orientation, image_size)
    % P = phantom image
    % n_lines = number of lines to be collecenter_targeted
    % point_density = number of samples collecenter_targeted per acquired line
    % orientation: 0 -> horizontal (lines are rows), otherwise vertical (lines are cols)
    
    % centered k-space of phantom
    P_fft = fftshift(fft2(P));
    
    % extracenter_target centered patch of size n_lines x point_density from P_fft
    [N_y, N_x] = size(P_fft);

    % center coords
    center_y = floor(N_y / 2) + 1;
    center_x = floor(N_x / 2) + 1;
    
    % row & col half sizes
    half_y = floor(n_lines / 2);
    half_x = floor(point_density / 2);
    
    % source indices
    source_y = (center_y - half_y):(center_y + (n_lines - 1) - half_y);
    source_x = (center_x - half_x):(center_x + (point_density - 1) - half_x);
    
    % ensure indices inside bounds (should be true per assumptions)
    source_y = max(1, min(N_y, source_y));
    source_x = max(1, min(N_x, source_x));
    
    patch = P_fft(source_y, source_x);
    
    % initialize target k-space of image_size
    K = zeros(image_size, image_size);
    
    % target center
    center_target = floor(image_size / 2) + 1;
    
    % basing acquisition around specified orientation
    if orientation == 0
        % horizontal, place patch as rows x cols centered
        half_y_t = floor(size(patch, 1) / 2);
        half_x_t = floor(size(patch, 2) / 2);
        y_t = (center_target - half_y_t):(center_target + (size(patch, 1) - 1) - half_y_t);
        x_t = (center_target - half_x_t):(center_target + (size(patch, 2) - 1) - half_x_t);
        y_t = max(1, min(image_size, y_t));
        x_t = max(1, min(image_size, x_t));
        K(y_t, x_t) = patch(1:numel(y_t), 1:numel(x_t));
    else
        % vertical, treat acquired lines as columns -> transpose placement
        half_y_t = floor(size(patch, 2) / 2);
        half_x_t = floor(size(patch, 1) / 2);
        y_t = (center_target - half_y_t):(center_target+(size(patch, 2) - 1) - half_y_t);
        x_t = (center_target - half_x_t):(center_target+(size(patch, 1) - 1) - half_x_t);
        y_t = max(1, min(image_size, y_t));
        x_t = max(1, min(image_size, x_t));
        % place transpose so patch rows -> columns
        K(y_t, x_t) = patch(1:numel(x_t), 1:numel(y_t)).';
    end
    
    % return acquired k-space (main program will ifft/display
    cartesian_image = K;
end