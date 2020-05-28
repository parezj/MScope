classdef controller < mscope.specific.audio.controller
%mscope.specific.audio.audioDeviceReader.controller - specific sub class, 
%implementing core audio recording methods. audioDeviceReader is used
%to record sound. its better than audioRecorder, as it can be used for
%long time recording, but Audio Toolbox is needed. it uses simple timer
%callback with fixedSpacing, where just read data and write to buffer.
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    19.5.2020
% --------------------------
%% Constants
    properties (Constant)
        recPeriod = 0.1              % record period in sec
    end
    
%% Private Properties
    properties (Access = private)
        hRecTimer                    % record timer
    end

%% Public Methods
    methods % (Access = public) 
        %% constructor
        function obj = controller(model, view)
            % first call super constructor
            obj = obj@mscope.specific.audio.controller(model, view); 
            
            % set window specific title
            obj.view.hFig.Name = 'MScope - Audio Device Reader';

            % scan for available devices
            obj.deviceScan();   
            
            % set specific bit range
            obj.view.hBits.ItemsData = {'8-bit integer'; '16-bit integer'; ...
                                       '24-bit integer'; '32-bit float'};
            obj.view.hBits.Value = '16-bit integer';                              
            
            % init record timer
            obj.hRecTimer = timer;
            obj.hRecTimer.ExecutionMode = 'fixedSpacing';
            obj.hRecTimer.Period = obj.recPeriod;
            obj.hRecTimer.StartDelay = obj.recPeriod;
            obj.hRecTimer.TimerFcn = @(src, event)recorded(obj); 
        end

        %% device set override
        function ok = deviceSet(obj)
            ok = true;
            
            % save values
            obj.currDevId = obj.view.hDevices.Value;
            obj.sampleRate = obj.view.hSampleRate.Value * 1000;
            obj.bitMax = sscanf(obj.view.hBits.Value, '%d');
            obj.bitMaxRange = 0.5 * 2^obj.bitMax;
            obj.vMax = obj.view.hVmax.Value;
            obj.samplesPerPeriod = obj.sampleRate * obj.acqPeriod;        
            obj.acqFormat = 'int32'; % double?
            
            % invoke main knobs to reinit settings
            obj.knobHChanged(obj.view.hKnobH);
            obj.knobVChanged(obj.view.hKnobV);
            
            % determine acq format
            if obj.bitMax == 8 
                obj.acqFormat = 'uint8';
            elseif obj.bitMax == 16
                obj.acqFormat = 'int16';
            end
            
            try                              
                try
                    release(obj.hRecorder); % clear previous rec. instance
                catch
                end
                
                % create and set audiorecorder instance
                obj.hRecorder = audioDeviceReader('Device', obj.currDevId, ...
                    'OutputDataType', obj.acqFormat, ...
                    'NumChannels', obj.defaulChan, ...
                    'SamplesPerFrame', obj.samplesPerPeriod, ...
                    'SampleRate', obj.sampleRate, ...
                    'BitDepth', obj.view.hBits.Value);
                
            catch ex
                disp("device set error: " + getReport(ex));
                ok = false;
            end
        end   
        
        %% device scan override
        function ok = deviceScan(obj)
            err = false;
            ok = true;
            
            try
                % save values and fill view listbox
                deviceReader = audioDeviceReader;
                devices = getAudioDevices(deviceReader);

                obj.devNames = devices;
                obj.devIds = devices;
                obj.view.hDevices.Items = devices;
                obj.view.hDevices.ItemsData = devices;
            catch ex
                disp("device scan error: " + getReport(ex));
                err = true;
            end
            
            if err == true || isempty(obj.devIds)
                obj.view.hStart.Text = '0 audio devices';
                obj.view.hStart.Enable = 'off';
                ok = false;
            end
        end
        
        %% device enable override
        function ok = deviceEnable(obj, val, updateUi)
            % check if called from sub class
            if nargin > 1 && updateUi == true
                obj.startPushed(obj.view.hStart);
                return;
            end
            
            try
                if val == true                       % enable device
                    if obj.settingsChanged == true
                        if obj.deviceSet() == false  % set device
                            ok = false;
                            return
                        end   
                        obj.settingsChanged = false;
                    end
                    
                    start(obj.hRecTimer);           % start recorder
                    obj.enabled = true;
                    ok = true;
                else                                % disable device
                    stop(obj.hRecTimer);
                    obj.enabled = false;
                    ok = true;
                end
            catch ex
                disp("device enable error: " + getReport(ex));
                ok = false;
            end     
        end
        
        %% device delete override
        function ok = deviceDelete(obj)
            ok = true;
            try
                release(obj.hRecorder);
                stop(obj.hRecTimer);
                delete(obj.hRecTimer);
            catch
                ok = false;
            end
        end
    end
    
%% Private Methods     
    methods (Access = private)        
        %% recorder timer callback
        function recorded(obj)   
            try
                % write recorded portion of data to main buffer
                data = obj.hRecorder();
                %errBuffWrite = obj.model.lastError;   
                firstIdx = length(data) - obj.samplesPerPeriod + 1;
                if firstIdx > 0
                    obj.model.buffer = data(firstIdx:end);
                else
                    disp("recorded size wrong: " + length(data) + " < " + ...
                        obj.samplesPerPeriod);
                end
            catch ex
                disp("record error: " + getReport(ex));
                obj.startPushed(obj.view.hStart);
            end   
        end
    end
end