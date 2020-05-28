classdef (Abstract) controller < mscope.generic.controller
%mscope.specific.audio.controller - more specific controller sub class, 
%implementing and overriding certain device specific methods, still 
%need to have implemented core audio record methods with another sub class
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    14.5.2020
% --------------------------
%% Constants
    properties (Constant)
        acqPeriod = 0.1              % acquisition period in sec
               
        defaulChan = 1               % want to plot only single channel
        defaultBits = 16             % default bit range
        defaultSampleRate = 44100    % default sample rate
        defaultVmax = 1              % default max voltage, refer to
                                     % controller protected member vMax
    end
    
%% Private Properties
    properties (Access = protected)
        hRecorder                    % audiorecorder handle
        
        settingsChanged = true       % helper flag to indicate setting chane
        devNames                     % found device names
        devIds                       % found device ids
        currDevId                    % current device id
        acqFormat                    % acquisition format - double / int16
    end
    
%% Public Methods
    methods % (Access = public) 
        %% constructor
        function obj = controller(model, view)
            % first call super constructor
            obj = obj@mscope.generic.controller(model, view); 
   
            % check view refs are ok
            assert(obj.devRefsValid());
            
            % assign callbacks
            obj.setDevCallbacks();
            
            % set default ui element value
            obj.view.hSampleRate.Value = obj.defaultSampleRate / 1000;
            obj.view.hBits.Value = obj.defaultBits;
            obj.view.hVmax.Value = obj.defaultVmax;
            
            % set default private member values
            obj.sampleRate = obj.defaultSampleRate;
            obj.vMax = obj.defaultVmax;
            obj.bitMax = obj.defaultBits;
            obj.bitMaxRange = 0.5 * 2^obj.bitMax;
                    
            % invoke main knobs to reinit settings
            obj.knobHChanged(obj.view.hKnobH);
            obj.knobVChanged(obj.view.hKnobV);
        end
    end
    
%% Private Methods     
    methods (Access = protected)
        %% check view refs valid
        function valid = devRefsValid(obj)
            valid = isvalid(obj.view.hDevices) && isvalid(obj.view.hSampleRate) && ...
                    isvalid(obj.view.hBits) && isvalid(obj.view.hEnabled) && ...
                    isvalid(obj.view.hStart);
        end
        
        %% set ui callbacks
        function setDevCallbacks(obj)                   
            obj.view.hDevices.ValueChangedFcn = @(src, event)devicesChanged(obj);
            obj.view.hSampleRate.ValueChangedFcn = @(src, event)sampleRateChanged(obj);
            obj.view.hBits.ValueChangedFcn = @(src, event)bitMaxChanged(obj);
            obj.view.hVmax.ValueChangedFcn = @(src, event)vMaxChanged(obj);
            obj.view.hStart.ButtonPushedFcn = @(src, event)startPushed(obj, src);
        end
        
        %% ui callback - device listbox
        function devicesChanged(obj)
            obj.settingsChanged = true;
        end
        
        %% ui callback - sample rate
        function sampleRateChanged(obj)
            obj.settingsChanged = true;
        end
        
        %% ui callback - bit range
        function bitMaxChanged(obj)
            obj.settingsChanged = true;
        end
        
        %% ui callback - vMax numeric input
        function vMaxChanged(obj)
            obj.settingsChanged = true;
        end
        
        %% ui callback - start button
        function startPushed(obj, src)           
            if obj.enabled == true
                obj.deviceEnable(false, false);           % disable device
                
                src.Text = 'Start';
                obj.enabled = false;
                
                obj.view.hEnabled.Color = '#A9A9A9';
                obj.view.enableDevControls(true);
            else
                if obj.deviceEnable(true, false) == true  % check enabling ok             
                    src.Text = 'Stop';
                    obj.enabled = true;

                    obj.view.hEnabled.Color = 'green';
                    obj.view.enableDevControls(false);
                end
            end
        end 
        
        %% load bit range list
        function setBits(obj, val)
            obj.view.hBits.ItemsData = val;
        end
    end
end