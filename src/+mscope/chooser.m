classdef chooser < handle
%chooser - create MScope specific instance with ui selection
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    14.5.2020
% --------------------------

%% Private Properties
    properties (Access = private)   
        hFig                     % window handle
        hButtAudioRecorder       % audio recorder start button
        hButtAudioDeviceReader   % audio device reader start button
        hButtSim                 % simulation start button
    end
    
%% Public Constructor 
    methods % (Access = public) 
        function obj = chooser()
            obj.checkCompat();   % check compatibility (MATLAB 2020)
            obj.createUi();      % create static ui
            obj.setCallbacks();  % assing button callbacks
        end
    end
    
%% Private Methods
    methods (Access = private) 
        %% check MATLAB 2020 version or deployed es executable
        function checkCompat(~)
            if ~isdeployed
                v = sscanf(ver('MATLAB').Version, '%d.%d');
                if v(1) < 9 || (v(1) == 9 && v(2) < 8)
                    error("MATLAB 2020a or higher is needed.");
                end
            end
        end
        
        %% create static ui
        function createUi(obj)
            % create ui figure
            figSize = [220 175];
            screenSize = get(groot, 'Screensize');
            pos = [(screenSize(3:4) - figSize)/2 figSize];
            obj.hFig = uifigure('Position', pos, ...
                'Name', 'MScope', ...
                'Resize', 'off');

            % create ui buttons
            obj.hButtAudioRecorder = uibutton(obj.hFig, ...
                'Text', 'Audio Recorder', ...
                'Tooltip', 'Only for short-time session, memory continually grows', ...
                'FontSize', 18, ...
                'FontWeight', 'Bold', ...
                'BackgroundColor', [0.85 0.85 0.85], ...
                'Position', [10 120 200 45]);
            obj.hButtAudioDeviceReader = uibutton(obj.hFig, ...
                'Text', 'Audio Device Reader', ...
                'Tooltip', ['Ideal for long-running session, but needs Audio Toolbox.' ...
                            'This is significantly better solution.'], ...
                'FontSize', 18, ...
                'FontWeight', 'Bold', ...
                'BackgroundColor', [0.85 0.85 0.85], ...
                'Position', [10 65 200 45]);
            obj.hButtSim = uibutton(obj.hFig, 'Text', 'Simulation', ...
                'Tooltip', 'Timer based sofwtare function generator', ...
                'FontSize', 18, ...
                'FontWeight', 'Bold', ...
                'BackgroundColor', [0.85 0.85 0.85], ...
                'Position', [10 10 200 45]);
        end
        
        %% assign callbacks
        function setCallbacks(obj)
            obj.hButtAudioRecorder.ButtonPushedFcn = @(src, event)recorder(obj);
            obj.hButtAudioDeviceReader.ButtonPushedFcn = @(src, event)deviceReader(obj);
            obj.hButtSim.ButtonPushedFcn = @(src, event)simulation(obj);
        end
        
        %% create specific mscope instance of type audioRecorder
        function recorder(obj)
            close(obj.hFig);
            model = mscope.generic.model();            % create model
            view = mscope.specific.audio.view();       % create view 
            % and run it all
            mscope.specific.audio.audioRecorder.controller(model, view); 
        end

        %% create specific mscope instance of type audioDeviceReader
        function deviceReader(obj)
            close(obj.hFig);
            model = mscope.generic.model();            % create model
            view = mscope.specific.audio.view();       % create view 
            % and run it all
            mscope.specific.audio.audioDeviceReader.controller(model, view); 
        end

        %% create specific mscope instance of type simulation
        function simulation(obj)
            close(obj.hFig);
            model = mscope.generic.model();            % create model
            view = mscope.specific.simulation.view();  % create view 
            % and run it all
            mscope.specific.simulation.controller(model, view); 
        end
    end
end