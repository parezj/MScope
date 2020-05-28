classdef controller < mscope.generic.controller
%mscope.specific.simulation.controller - specific controller sub class, 
%implementing and overriding device specific methods. simple timer-based
%signal generation is used. this class is intended as a demo or an example.
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    14.5.2020
% --------------------------
%% Constants
    properties (Constant)
        genPeriod = 0.1              % generator period in sec
        
        defaultSampleRate = 48000    % default sample rate
        defaultFreq = 501            % default frequency
        defaultAmpl = 2              % default amplitude
        defaultMode = 0              % default mode (sine, square..)
    end
    
%% Private Properties
    properties (Access = private)     
        hGenTimer                    % generator timer handle
        
        tStart                       % start time of generation
        f                            % frequency
        A                            % amplitude
        mode                         % mode
    end
    
%% Public Methods
    methods % (Access = public) 
        %% constructor
        function obj = controller(model, view)
            % first call super constructor
            obj = obj@mscope.generic.controller(model, view); 
            
            % set window specific title
            obj.view.hFig.Name = 'MScope - Simulation';
            
            % check view refs are ok
            assert(obj.devRefsValid());
            
            % assign callbacks
            obj.setDevCallbacks();
            
            % set default ui element value
            obj.view.hFrequency.Value = obj.defaultFreq;
            obj.view.hAmplitude.Value = obj.defaultAmpl;
            obj.view.hMode.Value = obj.defaultMode;
            obj.view.setPanelDevTitle("Device (sample rate: " + ...
                string(obj.defaultSampleRate) + " Hz)");
            
            % init device settings
            obj.deviceSet();
            
            % set vMax as default amplitude 1:1
            obj.vMax = obj.defaultAmpl;
            obj.bitMax = 0;
            obj.bitMaxRange = 0;
            
            % create and set generator timer
            obj.hGenTimer = timer;
            obj.hGenTimer.ExecutionMode = 'fixedRate';
            obj.hGenTimer.Period = obj.genPeriod;
            obj.hGenTimer.StartDelay = obj.genPeriod;
            obj.hGenTimer.TimerFcn = @(src, event)generate(obj); 
                     
            % invoke main knobs to reinit settings
            obj.knobHChanged(obj.view.hKnobH);
            obj.knobVChanged(obj.view.hKnobV);
        end

        %% device set override
        function ok = deviceSet(obj)
            ok = true;
            
            % save values
            obj.f = obj.defaultFreq;
            obj.A = obj.defaultAmpl;
            obj.mode = obj.defaultMode;
            obj.vMax = obj.A;
            
            % set sample rate
            obj.sampleRate = obj.defaultSampleRate;
            obj.samplesPerPeriod = obj.sampleRate * obj.genPeriod; 
        end

        %% device scan override
        function ok = deviceScan(~) % override
            ok = true;
        end
        
        %% device enable override
        function ok = deviceEnable(obj, val, updateUi)
            % check if called from sub class
            if nargin > 1 && updateUi == true
                obj.startPushed(obj.view.hStart);
                return;
            end
            
            if val == true
                obj.tStart = 0;
                start(obj.hGenTimer); % start generator timer
            else
                stop(obj.hGenTimer);  % stop generator timer
            end   
            obj.enabled = val;
            ok = true;
        end
        
        %% device delete override
        function ok = deviceDelete(obj)
            stop(obj.hGenTimer);
            delete(obj.hGenTimer);
            ok = true;
        end
    end
    
%% Private Methods      
    methods (Access = private)
        %% check view refs valid
        function valid = devRefsValid(obj)
            valid = isvalid(obj.view.hMode) && isvalid(obj.view.hFrequency) && ...
                    isvalid(obj.view.hAmplitude) && isvalid(obj.view.hEnabled) && ...
                    isvalid(obj.view.hStart);
        end
        
        %% set ui callbacks
        function setDevCallbacks(obj)                    
            obj.view.hMode.ValueChangedFcn = @(src, event)modeChanged(obj, event);
            obj.view.hFrequency.ValueChangingFcn = @(src, event)freqRateChanged(obj, event);
            obj.view.hAmplitude.ValueChangingFcn = @(src, event)amplChanged(obj, event);
            obj.view.hStart.ButtonPushedFcn = @(src, event)startPushed(obj, src);                
        end
        
        %% control freq knob
        function enableFreq(obj)
            obj.view.enableFrequency();
        end
        
        %% ui callback - mode knob
        function modeChanged(obj, event)
            obj.mode = event.Value;
            obj.enableFreq();
        end
        
        %% ui callback - frequency
        function freqRateChanged(obj, event)
            obj.f = event.Value;
        end
        
        %% ui callback - amplitude
        function amplChanged(obj, event)
            obj.A = event.Value;
            obj.vMax = obj.A;
            % invoke knobV change?
        end
        
        %% ui callback - start button
        function startPushed(obj, src)
            if obj.enabled == true
                src.Text = 'Start';
                obj.enabled = false;      
                obj.view.hEnabled.Color = '#A9A9A9';
            else
                src.Text = 'Stop';
                obj.enabled = true;          
                obj.view.hEnabled.Color = 'green';
            end
            obj.deviceEnable(obj.enabled, false); % disable / enable device
            obj.enableFreq();                     % check freq enabled
        end
        
        %% signal generator timer callback
        function generate(obj)        
            try
                % get end of time interval
                tEnd = obj.tStart + obj.genPeriod;
                % create time interval
                t = linspace(obj.tStart, tEnd, obj.samplesPerPeriod);
                % save next start of time interval
                obj.tStart = tEnd;

                switch obj.mode
                    case 0    % sine
                        obj.model.buffer = sin(2*pi*obj.f*t) .* obj.A;
                    case 1    % triangle
                        obj.model.buffer = obj.triangle(t, obj.A, 0.5/obj.f);
                    case 2    % saw
                        obj.model.buffer = obj.sawtooth(2*pi*obj.f*t) .* obj.A;
                    case 3    % square
                        obj.model.buffer = obj.square(2*pi*obj.f*t) .* obj.A;
                    otherwise % rand
                        obj.model.buffer = (rand(obj.samplesPerPeriod, 1) .* ...
                            (2 * obj.A)) - obj.A;
                end   
                errBuffWrite = obj.model.lastError;
            catch ex
                errBuffWrite = ex.message;
                %obj.model.reset();
                %obj.deviceEnable(false, true);
            end
            % disable generator if buffer-write failed
            if ~isempty(errBuffWrite)
                disp("generate error: " + errBuffWrite);
                obj.startPushed(obj.view.hStart);
            end
        end
        
        %% create square signal
        function y = square(~, x)
            inp = sin(x) >= 0;
            y(~inp) = -1;
            y(inp) = 1;
        end
        
        %% create square signal
        function y = sawtooth(~, x)
            y = ((mod(x, 2 * pi) / (pi * 2)) * 2) - 1;
        end
        
        %% create triangle signal
        function y = triangle(~, x, A, p)
            y = ((2 * A / p) .* (p - abs(mod(x, (2 * p)) - p))) - A;
        end
    end
end