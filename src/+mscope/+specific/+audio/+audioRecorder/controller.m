classdef controller < mscope.specific.audio.controller
%mscope.specific.audio.audioRecorder.controller - specific sub class, 
%implementing core audio recording methods. audirecorder is used
%to record sound. it is not intended for long running recording, as sound
%is cummulated in ram, so use it only for short time use. timer callback
%used to read the last portion of recorded signal from growing buffer
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    19.5.2020
% --------------------------
%% Private Properties
    properties (Access = private)
        lastBuffLen = 0   % last length of continuously growing buffer
    end
    
%% Public Methods
    methods % (Access = public) 
        %% constructor
        function obj = controller(model, view)
            % first call super constructor
            obj = obj@mscope.specific.audio.controller(model, view); 
            
            % set window specific title
            obj.view.hFig.Name = 'MScope - Audio Recorder';

            % scan for available devices
            obj.deviceScan();             
        end

        %% device set override
        function ok = deviceSet(obj)
            ok = true;
            
            % save values
            obj.currDevId = obj.view.hDevices.Value;
            obj.sampleRate = obj.view.hSampleRate.Value * 1000;
            obj.bitMax = obj.view.hBits.Value;
            obj.bitMaxRange = 0.5 * 2^obj.bitMax;
            obj.vMax = obj.view.hVmax.Value;
            obj.samplesPerPeriod = obj.sampleRate * obj.acqPeriod;        
            obj.acqFormat = 'int32'; % double?
            
            % invoke main knobs to reinit settings
            obj.knobHChanged(obj.view.hKnobH);
            obj.knobVChanged(obj.view.hKnobV);
            
            % determine acq format
            if obj.bitMax == 8 
                obj.acqFormat = 'int8';
            elseif obj.bitMax == 16
                obj.acqFormat = 'int16';
            end
            
            try
                % check settings is valid for specific device
                if ~audiodevinfo(1, obj.currDevId, obj.sampleRate, ...
                    obj.bitMax, obj.defaulChan)
                
                    disp('Unsupported settings.');
                    ok = false;
                    return
                end
                               
                try
                    delete(obj.hRecorder); % clear previous rec. instance
                catch
                end
                
                % create and set audiorecorder instance
                obj.hRecorder = audiorecorder(obj.sampleRate, obj.bitMax, ...
                    obj.defaulChan, obj.currDevId);
                obj.hRecorder.TimerFcn = @(src, event)recorded(obj);
                obj.hRecorder.TimerPeriod = obj.acqPeriod;
                
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
                allAudioDevices = audiodevinfo;
                obj.devNames = {allAudioDevices.input.Name}.';
                obj.devIds = {allAudioDevices.input.ID}';
                obj.view.hDevices.Items = obj.devNames;
                obj.view.hDevices.ItemsData = obj.devIds;
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
                    
                    record(obj.hRecorder);           % start recorder
                    obj.enabled = true;
                    ok = true;
                else                                 % disable device
                    stop(obj.hRecorder);
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
                stop(obj.hRecorder);
                delete(obj.hRecorder);
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
                data = getaudiodata(obj.hRecorder, obj.acqFormat); 
            catch ex
                % if record failed, disable device
                disp("record error: " + getReport(ex));
                obj.startPushed(obj.view.hStart);
                return;
            end    
            
            buffLen = length(data); % get actual buffer length
            newDataLen = buffLen - obj.lastBuffLen; % subtract from last
            
            if newDataLen > 0
                obj.model.buffer = data(end-newDataLen+1:end);
                %errBuffWrite = obj.model.lastError;  
            else
                %disp("record error: 0 new data");
            end
            
            obj.lastBuffLen = buffLen; % save buffer length
        end
    end
end