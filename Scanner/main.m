classdef main < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        RunningScannerLabel_2           matlab.ui.control.Label
        RunningScannerLabel             matlab.ui.control.Label
        StatisticsTextArea              matlab.ui.control.TextArea
        StatisticsTextAreaLabel         matlab.ui.control.Label
        ResetDefaultValuesButton        matlab.ui.control.Button
        Panel                           matlab.ui.container.Panel
        HeightScalingSlider             matlab.ui.control.Slider
        HeightScalingSliderLabel        matlab.ui.control.Label
        WidthScalingSlider              matlab.ui.control.Slider
        WidthScalingSliderLabel         matlab.ui.control.Label
        RotationphiEditField            matlab.ui.control.NumericEditField
        RotationphiEditFieldLabel       matlab.ui.control.Label
        AdvancedStructureSettingsSwitch  matlab.ui.control.Switch
        AdvancedStructureSettingsSwitchLabel  matlab.ui.control.Label
        EmbeddedStructuresDropDown      matlab.ui.control.DropDown
        EmbeddedStructuresDropDownLabel  matlab.ui.control.Label
        OrientationDropDown             matlab.ui.control.DropDown
        OrientationDropDownLabel        matlab.ui.control.Label
        ImageSizeEditField              matlab.ui.control.NumericEditField
        ImageSizeEditFieldLabel         matlab.ui.control.Label
        AcquisitionSchemeDropDown       matlab.ui.control.DropDown
        AcquisitionSchemeDropDownLabel  matlab.ui.control.Label
        RunButton                       matlab.ui.control.Button
        PointDensityEditField           matlab.ui.control.NumericEditField
        PointDensityEditFieldLabel      matlab.ui.control.Label
        NumberofLinesEditField          matlab.ui.control.NumericEditField
        NumberofLinesEditFieldLabel     matlab.ui.control.Label
        PhantomSizeEditField            matlab.ui.control.NumericEditField
        PhantomSizeEditFieldLabel       matlab.ui.control.Label
        UIAxes_3                        matlab.ui.control.UIAxes
        UIAxes_2                        matlab.ui.control.UIAxes
        UIAxes                          matlab.ui.control.UIAxes
    end

    methods (Access = private)
        
        % helper function to redraw left-side original phantom
        function redrawPhantom(app)
            % read current inputs
            phantom_size = app.PhantomSizeEditField.Value;
            structure_type = app.EmbeddedStructuresDropDown.Value;
            width = app.WidthScalingSlider.Value;
            height = app.HeightScalingSlider.Value;
            phi = app.RotationphiEditField.Value;
        
            % build phantom P depending on choices
            phantom_SI = 0.5;
            structure_SI = 1.0;
            if structure_type == 0
                E = [phantom_SI, 0.9, 0.9, 0, 0, 0, 0;
                     structure_SI, 0.05 * width, 0.05 * height, -0.80, 0, phi, 0;
                     structure_SI, 0.1 * width, 0.1 * height, -0.60, 0, phi, 0;
                     structure_SI, 0.15 * width, 0.15 * height, -0.30, 0, phi, 0;
                     structure_SI, 0.2 * width, 0.2 * height, 0.1, 0, phi, 0;
                     structure_SI, 0.25 * width, 0.25 * height, 0.6, 0, phi, 0;];
            else
                E = [phantom_SI, 0.9, 0.9, 0, 0, phi, 0;
                      structure_SI, 0.4 * width, 0.4 * height, 0, 0, phi, 1];
            end
        
            % Create phantom and display to UIAxes
            P = make_phantom(E, phantom_size);
        
            cla(app.UIAxes_2);
            imshow(P, [], 'Parent', app.UIAxes_2, InitialMagnification='fit');
            axis(app.UIAxes_2, 'image');

            % ensure axes limits match image size to avoid top-left cropping
            app.UIAxes_2.XLim = [0.5, size(P,2) + 0.5];
            app.UIAxes_2.YLim = [0.5, size(P,1) + 0.5];
            title(app.UIAxes_2, sprintf('Original Phantom Image, N=%d', phantom_size));
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % set advanced options panel visibility off until toggled
            app.Panel.Visible = 'off';
            app.AdvancedStructureSettingsSwitch.Value = 'Off';
        
            % draw initial phantom with default settings
            redrawPhantom(app);
        end

        % Value changed function: PhantomSizeEditField
        function PhantomSizeEditFieldValueChanged(app, event)
            % get the new phantom size
            phantomSize = app.PhantomSizeEditField.Value;
        
            % if acquisition is Cartesian, enforce limits
            if strcmp(app.AcquisitionSchemeDropDown.Value, "Cartesian")
                % set limits for Number of Lines and Point Density
                app.NumberofLinesEditField.Limits = [1, phantomSize];
                app.PointDensityEditField.Limits = [1, phantomSize];
        
                % clamp current values if they exceed new limits
                if app.NumberofLinesEditField.Value > phantomSize
                    app.NumberofLinesEditField.Value = phantomSize;
                end
                if app.PointDensityEditField.Value > phantomSize
                    app.PointDensityEditField.Value = phantomSize;
                end
            else
                % for Radial acquisition, leave limits unconstrained
                % "unconstrained" but with size sanity check
                app.NumberofLinesEditField.Limits = [1, 8192];
                app.PointDensityEditField.Limits = [1, 8192];
            end
    
            % redraw phantom to reflect new size
            redrawPhantom(app);
        end

        % Button pushed function: RunButton
        function RunButtonPushed(app, event)
            cla(app.UIAxes, 'reset');
            cla(app.UIAxes_3, 'reset');
            app.RunningScannerLabel.Visible   = 'on';
            app.RunningScannerLabel.Position  = app.UIAxes.Position;   % overlay
            app.RunningScannerLabel.HorizontalAlignment = 'center';
            app.RunningScannerLabel.VerticalAlignment   = 'center';
        
            app.RunningScannerLabel_2.Visible = 'on';
            app.RunningScannerLabel_2.Position = app.UIAxes_3.Position;
            app.RunningScannerLabel_2.HorizontalAlignment = 'center';
            app.RunningScannerLabel_2.VerticalAlignment   = 'center';
        
            drawnow;
            % read in inputs
            phantom_size = app.PhantomSizeEditField.Value;
            n_lines = app.NumberofLinesEditField.Value;
            point_density = app.PointDensityEditField.Value;
            orientation = app.OrientationDropDown.Value; % "Horizontal"/"Vertical"
            orientation = strcmp(orientation, "Vertical"); % 0 or 1
            image_size = app.ImageSizeEditField.Value;
            acquisition = app.AcquisitionSchemeDropDown.Value; % "Cartesian"/"Radial"
            structure_type = app.EmbeddedStructuresDropDown.Value;
            width = app.WidthScalingSlider.Value;
            height = app.HeightScalingSlider.Value;
            phi = app.RotationphiEditField.Value;
    
            % size sanity check on output image
            if image_size < 128 || image_size > 4096
                uialert(app.UIFigure, 'Output image size must be between 256 and 4096','Input error'); return
            end
    
            % build phantom based on inputs
            phantom_SI = 0.5;
            structure_SI = 1.0;
            if structure_type == 0
                E = [phantom_SI, 0.9, 0.9, 0, 0, 0, 0;
                     structure_SI, 0.05 * width, 0.05 * height, -0.80, 0, phi, 0;
                     structure_SI, 0.1 * width, 0.1 * height, -0.60, 0, phi, 0;
                     structure_SI, 0.15 * width, 0.15 * height, -0.30, 0, phi, 0;
                     structure_SI, 0.2 * width, 0.2 * height, 0.1, 0, phi, 0;
                     structure_SI, 0.25 * width, 0.25 * height, 0.6, 0, phi, 0;];
            else
                E = [phantom_SI, 0.9, 0.9, 0, 0, phi, 0;
                      structure_SI, 0.4 * width, 0.4 * height, 0, 0, phi, 1];
            end
            P = make_phantom(E, phantom_size);
    
            % call acquisition function based on dropdown option
            if strcmp(acquisition, "Cartesian")
                c = acquisition_cartesian(P, n_lines, point_density, orientation, image_size);
            else
                c = acquisition_radial(P, n_lines, point_density, image_size);
            end
    
            % reconstruct image with ifft
            img_complex = ifft2(ifftshift(c));
            img_mag = abs(img_complex);

            % crop output image out of reconstructed padded image if radial
            if strcmp(acquisition, "Radial")
                img_mag = img_mag(1:image_size, 1:image_size);
            end
            
            % resize original phantom for loss comparison
            phantom_resized = imresize(P, size(img_mag));

            % normalize both images to [0,1] for fair comparison
            phantom_norm = phantom_resized / max(phantom_resized(:));
            img_norm = img_mag / max(img_mag(:));
            
            % compute loss image (difference between original and reconstructed)
            loss_image = abs(phantom_norm - img_norm);

            % compute statistics
            % mean and std of phantom and reconstruction
            phantom_mean = mean(phantom_norm(:));
            phantom_std = std(phantom_norm(:));
            recon_mean = mean(img_norm(:));
            recon_std = std(img_norm(:));
        
            % MSE and RMSE between phantom and reconstruction
            mse = mean((phantom_norm(:) - img_norm(:)).^2);
            rmse = sqrt(mse);
        
            % masks based on phantom intensities
            structure_mask  = (phantom_resized == 1.0);
            background_mask = (phantom_resized == 0.5);

            % average SI in reconstruction
            recon_structure_SI  = mean(img_norm(structure_mask));
            recon_background_SI = mean(img_norm(background_mask));

            % construct stats report string
            statsReport = sprintf([ ...
                'Phantom mean: %.4f\n' ...
                'Phantom std:  %.4f\n' ...
                'Recon mean:   %.4f\n' ...
                'Recon std:    %.4f\n' ...
                '\n' ...
                'MSE:          %.6f\n' ...
                'RMSE:         %.6f\n' ...
                '\n' ...
                'Recon structure SI:    %.4f\n' ...
                'Recon background SI:   %.4f\n'], ...
                phantom_mean, phantom_std, recon_mean, recon_std, ...
                mse, rmse, ...
                recon_structure_SI, recon_background_SI);

            app.RunningScannerLabel.Visible = 'off';
            app.RunningScannerLabel_2.Visible = 'off';
        
            % display in StatisticsTextArea
            app.StatisticsTextAreaLabel.Visible = "on";
            app.StatisticsTextArea.Visible = "on";
            app.StatisticsTextArea.Value = statsReport;
            time = n_lines * point_density;

            % show reconstructed and loss images on UIAxes
            % original phantom is already automatically updated and
            % displayed
            cla(app.UIAxes);
            imshow(img_mag, [], 'Parent', app.UIAxes, InitialMagnification='fit');
            title(app.UIAxes, sprintf('Reconstructed magnitude image, T=%d', time));

            cla(app.UIAxes_3);
            imshow(loss_image, 'Parent', app.UIAxes_3, InitialMagnification='fit');
            title(app.UIAxes_3, sprintf('Loss Image (Original - Reconstructed)'));
        end

        % Value changed function: EmbeddedStructuresDropDown
        function EmbeddedStructuresDropDownValueChanged(app, event)
            % reset default values when shape of embedded structures are
            % changed
            app.RotationphiEditField.Value = 0;
            app.WidthScalingSlider.Value = 1;
            app.HeightScalingSlider.Value = 1;
            redrawPhantom(app);
        end

        % Value changed function: RotationphiEditField
        function RotationphiEditFieldValueChanged(app, event)
            redrawPhantom(app);
            
        end

        % Value changed function: AdvancedStructureSettingsSwitch
        function AdvancedStructureSettingsSwitchValueChanged(app, event)
            % displays advanced settings when switch is toggled
            state = app.AdvancedStructureSettingsSwitch.Value; % 'on' or 'off'
            if islogical(state) || isa(state, 'matlab.lang.OnOffSwitchState')
                visible = matlab.lang.OnOffSwitchState.on == state; % logical
            else
                visible = strcmp(state, "On");
            end
        
            if visible
                app.Panel.Visible = 'on';
            else
                app.Panel.Visible = 'off';
            end
        end

        % Value changed function: WidthScalingSlider
        function WidthScalingSliderValueChanged(app, event)
            redrawPhantom(app);
            
        end

        % Value changed function: HeightScalingSlider
        function HeightScalingSliderValueChanged(app, event)
            redrawPhantom(app);
            
        end

        % Value changed function: AcquisitionSchemeDropDown
        function AcquisitionSchemeDropDownValueChanged(app, event)
            % impose new limits when acquisition scheme is changed
            acquisition = app.AcquisitionSchemeDropDown.Value;
            phantom_size = app.PhantomSizeEditField.Value;
            if strcmp(acquisition, "Cartesian")
                app.NumberofLinesEditField.Limits = [1, phantom_size];
                app.PointDensityEditField.Limits = [1, phantom_size];
                if app.NumberofLinesEditField.Value > phantom_size
                    app.NumberofLinesEditField.Value = phantom_size;
                end
                if app.PointDensityEditField.Value > phantom_size
                    app.PointDensityEditField.Value = phantom_size;
                end
                % enable orientation when Cartesian is selected
                app.OrientationDropDown.Enable = 'on';
                app.OrientationDropDownLabel.Enable = 'on';
            else
                app.OrientationDropDown.Enable = 'off';
                app.OrientationDropDownLabel.Enable = 'off';
                app.NumberofLinesEditField.Limits = [1, 8192];
                app.PointDensityEditField.Limits = [1, 8192];
            end
        end

        % Button pushed function: ResetDefaultValuesButton
        function ResetDefaultValuesButtonPushed(app, event)
            % button to reset default values (aside from acquisition and
            % structure shapes)
            app.PhantomSizeEditField.Value = 1024;
            app.WidthScalingSlider.Value = 1;
            app.HeightScalingSlider.Value = 1;
            app.RotationphiEditField.Value = 0;
            app.OrientationDropDown.Value = 0;
            app.NumberofLinesEditField.Value = 128;
            app.PointDensityEditField.Value = 128;
            app.ImageSizeEditField.Value = 256;
            redrawPhantom(app);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1010 647];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Reconstructed Image')
            app.UIAxes.XTick = [];
            app.UIAxes.YTick = [];
            app.UIAxes.GridColor = 'none';
            app.UIAxes.Position = [356 327 300 300];

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.UIFigure);
            title(app.UIAxes_2, 'Phantom Image')
            app.UIAxes_2.XTick = [];
            app.UIAxes_2.YTick = [];
            app.UIAxes_2.GridColor = 'none';
            app.UIAxes_2.Position = [26 327 300 300];

            % Create UIAxes_3
            app.UIAxes_3 = uiaxes(app.UIFigure);
            title(app.UIAxes_3, 'Loss Image')
            app.UIAxes_3.XTick = [];
            app.UIAxes_3.YTick = [];
            app.UIAxes_3.GridColor = 'none';
            app.UIAxes_3.Position = [676 327 300 300];

            % Create PhantomSizeEditFieldLabel
            app.PhantomSizeEditFieldLabel = uilabel(app.UIFigure);
            app.PhantomSizeEditFieldLabel.HorizontalAlignment = 'right';
            app.PhantomSizeEditFieldLabel.Position = [130 292 80 22];
            app.PhantomSizeEditFieldLabel.Text = 'Phantom Size';

            % Create PhantomSizeEditField
            app.PhantomSizeEditField = uieditfield(app.UIFigure, 'numeric');
            app.PhantomSizeEditField.Limits = [256 4096];
            app.PhantomSizeEditField.RoundFractionalValues = 'on';
            app.PhantomSizeEditField.ValueDisplayFormat = '%.0f';
            app.PhantomSizeEditField.ValueChangedFcn = createCallbackFcn(app, @PhantomSizeEditFieldValueChanged, true);
            app.PhantomSizeEditField.Placeholder = 'phantom size';
            app.PhantomSizeEditField.Position = [225 292 100 22];
            app.PhantomSizeEditField.Value = 1024;

            % Create NumberofLinesEditFieldLabel
            app.NumberofLinesEditFieldLabel = uilabel(app.UIFigure);
            app.NumberofLinesEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofLinesEditFieldLabel.Position = [410 217 93 22];
            app.NumberofLinesEditFieldLabel.Text = 'Number of Lines';

            % Create NumberofLinesEditField
            app.NumberofLinesEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumberofLinesEditField.RoundFractionalValues = 'on';
            app.NumberofLinesEditField.ValueDisplayFormat = '%.0f';
            app.NumberofLinesEditField.Position = [518 217 100 22];
            app.NumberofLinesEditField.Value = 128;

            % Create PointDensityEditFieldLabel
            app.PointDensityEditFieldLabel = uilabel(app.UIFigure);
            app.PointDensityEditFieldLabel.HorizontalAlignment = 'right';
            app.PointDensityEditFieldLabel.Position = [427 178 76 22];
            app.PointDensityEditFieldLabel.Text = 'Point Density';

            % Create PointDensityEditField
            app.PointDensityEditField = uieditfield(app.UIFigure, 'numeric');
            app.PointDensityEditField.RoundFractionalValues = 'on';
            app.PointDensityEditField.ValueDisplayFormat = '%.0f';
            app.PointDensityEditField.Position = [518 178 100 22];
            app.PointDensityEditField.Value = 128;

            % Create RunButton
            app.RunButton = uibutton(app.UIFigure, 'push');
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonPushed, true);
            app.RunButton.Position = [519 101 100 23];
            app.RunButton.Text = 'Run';

            % Create AcquisitionSchemeDropDownLabel
            app.AcquisitionSchemeDropDownLabel = uilabel(app.UIFigure);
            app.AcquisitionSchemeDropDownLabel.HorizontalAlignment = 'right';
            app.AcquisitionSchemeDropDownLabel.Position = [393 292 110 22];
            app.AcquisitionSchemeDropDownLabel.Text = 'Acquisition Scheme';

            % Create AcquisitionSchemeDropDown
            app.AcquisitionSchemeDropDown = uidropdown(app.UIFigure);
            app.AcquisitionSchemeDropDown.Items = {'Cartesian', 'Radial'};
            app.AcquisitionSchemeDropDown.ValueChangedFcn = createCallbackFcn(app, @AcquisitionSchemeDropDownValueChanged, true);
            app.AcquisitionSchemeDropDown.Position = [518 292 100 22];
            app.AcquisitionSchemeDropDown.Value = 'Cartesian';

            % Create ImageSizeEditFieldLabel
            app.ImageSizeEditFieldLabel = uilabel(app.UIFigure);
            app.ImageSizeEditFieldLabel.HorizontalAlignment = 'right';
            app.ImageSizeEditFieldLabel.Position = [439 142 65 22];
            app.ImageSizeEditFieldLabel.Text = 'Image Size';

            % Create ImageSizeEditField
            app.ImageSizeEditField = uieditfield(app.UIFigure, 'numeric');
            app.ImageSizeEditField.Limits = [128 4096];
            app.ImageSizeEditField.RoundFractionalValues = 'on';
            app.ImageSizeEditField.ValueDisplayFormat = '%.0f';
            app.ImageSizeEditField.Position = [519 142 100 22];
            app.ImageSizeEditField.Value = 256;

            % Create OrientationDropDownLabel
            app.OrientationDropDownLabel = uilabel(app.UIFigure);
            app.OrientationDropDownLabel.HorizontalAlignment = 'right';
            app.OrientationDropDownLabel.Position = [439 257 64 22];
            app.OrientationDropDownLabel.Text = 'Orientation';

            % Create OrientationDropDown
            app.OrientationDropDown = uidropdown(app.UIFigure);
            app.OrientationDropDown.Items = {'Horizontal', 'Vertical'};
            app.OrientationDropDown.ItemsData = [0 1];
            app.OrientationDropDown.Position = [518 257 100 22];
            app.OrientationDropDown.Value = 0;

            % Create EmbeddedStructuresDropDownLabel
            app.EmbeddedStructuresDropDownLabel = uilabel(app.UIFigure);
            app.EmbeddedStructuresDropDownLabel.HorizontalAlignment = 'right';
            app.EmbeddedStructuresDropDownLabel.Position = [89 251 121 22];
            app.EmbeddedStructuresDropDownLabel.Text = 'Embedded Structures';

            % Create EmbeddedStructuresDropDown
            app.EmbeddedStructuresDropDown = uidropdown(app.UIFigure);
            app.EmbeddedStructuresDropDown.Items = {'Ellipses', 'Rectangle'};
            app.EmbeddedStructuresDropDown.ItemsData = [0 1];
            app.EmbeddedStructuresDropDown.ValueChangedFcn = createCallbackFcn(app, @EmbeddedStructuresDropDownValueChanged, true);
            app.EmbeddedStructuresDropDown.Position = [225 251 100 22];
            app.EmbeddedStructuresDropDown.Value = 0;

            % Create AdvancedStructureSettingsSwitchLabel
            app.AdvancedStructureSettingsSwitchLabel = uilabel(app.UIFigure);
            app.AdvancedStructureSettingsSwitchLabel.HorizontalAlignment = 'center';
            app.AdvancedStructureSettingsSwitchLabel.Position = [73 217 157 22];
            app.AdvancedStructureSettingsSwitchLabel.Text = 'Advanced Structure Settings';

            % Create AdvancedStructureSettingsSwitch
            app.AdvancedStructureSettingsSwitch = uiswitch(app.UIFigure, 'slider');
            app.AdvancedStructureSettingsSwitch.ValueChangedFcn = createCallbackFcn(app, @AdvancedStructureSettingsSwitchValueChanged, true);
            app.AdvancedStructureSettingsSwitch.Position = [258 218 45 20];

            % Create Panel
            app.Panel = uipanel(app.UIFigure);
            app.Panel.BorderType = 'none';
            app.Panel.BackgroundColor = [0.902 0.902 0.902];
            app.Panel.Position = [71 69 256 145];

            % Create RotationphiEditFieldLabel
            app.RotationphiEditFieldLabel = uilabel(app.Panel);
            app.RotationphiEditFieldLabel.HorizontalAlignment = 'right';
            app.RotationphiEditFieldLabel.Position = [15 19 77 22];
            app.RotationphiEditFieldLabel.Text = 'Rotation (phi)';

            % Create RotationphiEditField
            app.RotationphiEditField = uieditfield(app.Panel, 'numeric');
            app.RotationphiEditField.Limits = [0 359];
            app.RotationphiEditField.RoundFractionalValues = 'on';
            app.RotationphiEditField.ValueDisplayFormat = '%.0f';
            app.RotationphiEditField.ValueChangedFcn = createCallbackFcn(app, @RotationphiEditFieldValueChanged, true);
            app.RotationphiEditField.Position = [107 19 100 22];

            % Create WidthScalingSliderLabel
            app.WidthScalingSliderLabel = uilabel(app.Panel);
            app.WidthScalingSliderLabel.HorizontalAlignment = 'right';
            app.WidthScalingSliderLabel.Position = [15 116 78 22];
            app.WidthScalingSliderLabel.Text = 'Width Scaling';

            % Create WidthScalingSlider
            app.WidthScalingSlider = uislider(app.Panel);
            app.WidthScalingSlider.Limits = [0.05 2];
            app.WidthScalingSlider.MajorTicks = [0.05 0.5 1 1.5 2];
            app.WidthScalingSlider.MajorTickLabels = {'0', '0.5', '1', '1.5', '2'};
            app.WidthScalingSlider.ValueChangedFcn = createCallbackFcn(app, @WidthScalingSliderValueChanged, true);
            app.WidthScalingSlider.MinorTicks = [0.05 0.15 0.25 0.35 0.45 0.55 0.65 0.75 0.85 0.95 1.05 1.15 1.25 1.35 1.45 1.55 1.65 1.75 1.85 2];
            app.WidthScalingSlider.Position = [115 125 120 3];
            app.WidthScalingSlider.Value = 1;

            % Create HeightScalingSliderLabel
            app.HeightScalingSliderLabel = uilabel(app.Panel);
            app.HeightScalingSliderLabel.HorizontalAlignment = 'right';
            app.HeightScalingSliderLabel.Position = [11 73 82 22];
            app.HeightScalingSliderLabel.Text = 'Height Scaling';

            % Create HeightScalingSlider
            app.HeightScalingSlider = uislider(app.Panel);
            app.HeightScalingSlider.Limits = [0.05 2];
            app.HeightScalingSlider.MajorTicks = [0.05 0.5 1 1.5 2];
            app.HeightScalingSlider.MajorTickLabels = {'0', '0.5', '1', '1.5', '2'};
            app.HeightScalingSlider.ValueChangedFcn = createCallbackFcn(app, @HeightScalingSliderValueChanged, true);
            app.HeightScalingSlider.MinorTicks = [0.05 0.15 0.25 0.35 0.45 0.55 0.65 0.75 0.85 0.95 1.05 1.15 1.25 1.35 1.45 1.55 1.65 1.75 1.85 2];
            app.HeightScalingSlider.Position = [115 82 120 3];
            app.HeightScalingSlider.Value = 1;

            % Create ResetDefaultValuesButton
            app.ResetDefaultValuesButton = uibutton(app.UIFigure, 'push');
            app.ResetDefaultValuesButton.ButtonPushedFcn = createCallbackFcn(app, @ResetDefaultValuesButtonPushed, true);
            app.ResetDefaultValuesButton.BackgroundColor = [0.9412 0.9412 0.9412];
            app.ResetDefaultValuesButton.FontColor = [0.5686 0 0];
            app.ResetDefaultValuesButton.Position = [675 101 127 23];
            app.ResetDefaultValuesButton.Text = 'Reset Default Values';

            % Create StatisticsTextAreaLabel
            app.StatisticsTextAreaLabel = uilabel(app.UIFigure);
            app.StatisticsTextAreaLabel.HorizontalAlignment = 'right';
            app.StatisticsTextAreaLabel.Visible = 'off';
            app.StatisticsTextAreaLabel.Position = [696 290 53 22];
            app.StatisticsTextAreaLabel.Text = 'Statistics';

            % Create StatisticsTextArea
            app.StatisticsTextArea = uitextarea(app.UIFigure);
            app.StatisticsTextArea.BackgroundColor = [0.9412 0.9412 0.9412];
            app.StatisticsTextArea.Visible = 'off';
            app.StatisticsTextArea.Position = [764 163 201 151];

            % Create RunningScannerLabel
            app.RunningScannerLabel = uilabel(app.UIFigure);
            app.RunningScannerLabel.Visible = 'off';
            app.RunningScannerLabel.Position = [460 466 107 22];
            app.RunningScannerLabel.Text = 'Running Scanner...';

            % Create RunningScannerLabel_2
            app.RunningScannerLabel_2 = uilabel(app.UIFigure);
            app.RunningScannerLabel_2.Visible = 'off';
            app.RunningScannerLabel_2.Position = [785 466 107 22];
            app.RunningScannerLabel_2.Text = 'Running Scanner...';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = main

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end