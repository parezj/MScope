classdef (Abstract) controller < handle 
%mscope.generic.controller - this is the main logic of the scope. this
%class is abstract, because it needs to implement device specific methods
%like: set, scan, enable and delete. this class acts like bridge between
%model and view, holding refs to them. these instances can be injected to
%constructor, making unit tests easy. callbacks for ui elemenets are set in
%this class, also main display timer callback, that handles rendering, is
%implemented in here.
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    10.5.2020
% --------------------------

%% Constants
    properties (Constant)
        refreshRate = 0.1        % display refresh rate = 10 FPS
        bufferMaxLen = 2000000   % main buffer size
        
        gridCellsH = 10          % horizontal grid, should be even
        gridCellsV = 10          % vertical grid, should be even
        fftMeasPad = 17          % space padding for fft meas label
        sigMeasPad = 16          % space padding for sig meas label
        fftFocusCounterMax = 10  % after this number of renders refocus fft
        mtxTimout = 1;           % buffer read write mutex timeout
                
        defaultKnobV = 2         % default vertical scale knob value
        defaultKnobH = 0.005     % default horizontal scale knob value
        defaultPosV = 0          % default vertial position value
        defaultPosH = 0          % default horizontal poisition value
        defaultTrigVal = 0       % defualt trigger value
        defaultTrigMode = 0      % default trigger mode - rising  
    end
    
%% Private Properties
    properties (Access = private)   
        knobH                    % h scale value
        knobV                    % v scale value
        posH                     % h position value
        posV                     % v position value
        
        trigVal                  % trigger knob value
        trigMode                 % trigger mode
        trigger = nan            % if nan, trigger off, else trigger value
        
        fftFocusCounter = 0      % helps to reduce too fast fft refocusing
        fftNeedToFocus = true    % helper flag indicating fft X axis refocus
        fftZoomedOut = false     % by default, fft auto zoom
        fftEnabled = false       % fft mode enabled
        hannWindow = 1           % hanning window for fft
        
        xValuesChaged = true     % helper flag indicating X axis changed 
        windowLen = 2            % display window - number of points
        fpsTick                  % fps calc helper variable
        rmDisc = true            % remove discontinuities - only in sig mode
        
        posHrange = [0 1]        % horizontal position knob real range
        posVrange = [0 1]        % vertical position knob real range
        posHscaler = 1           % posh H scaling for being user friendly
    end
    
%% Protected Properties   
    properties (Access = protected)
        model                    % model instance
        view                     % view instance
        
        hDisplayTimer            % main display timer with refresh rate
        enabled = false          % indicate if device is enabled                           

        samplesPerPeriod         % samples per period of device
        sampleRate = 0           % sample rate of device
        
        bitMaxRange              % max bit value of positive bit range
        bitMax                   % sampling max bit range
        vMax                     % max voltage value for positive signal
                                 % every device has different specified val,
                                 % its absolute max Voltage device can sample  
    end
    
%% Public Constructor 
    methods % (Access = public) 
        function obj = controller(model, view)
            obj.model = model;
            obj.view = view;
            
            % check everything is ok
            assert(isvalid(obj.model));
            assert(obj.viewRefsValid());
            
            % init model
            obj.model.init(obj.bufferMaxLen, obj.mtxTimout);
            
            % set UI callbacks
            obj.setUiCallbacks();
            
            % init default private values
            obj.knobH = obj.defaultKnobH;
            obj.knobV = obj.defaultKnobV;
            obj.posH = obj.defaultPosH;
            obj.posV = obj.defaultPosV;
            obj.trigVal = obj.defaultTrigVal;
            obj.trigMode = obj.defaultTrigMode;
            
            % init default ui element value
            obj.view.hKnobH.Value = obj.defaultKnobH;
            obj.view.hKnobV.Value = obj.defaultKnobV;
            obj.view.hPosH.Value = obj.defaultPosH;
            obj.view.hPosV.Value = obj.defaultPosV;
            obj.view.hTrigVal.Value = obj.defaultTrigVal;
            obj.view.hTrigMode.Value = obj.defaultTrigMode;
            
            % invoke main knobs to init settings
            obj.knobHChanged(obj.view.hKnobH);
            obj.knobVChanged(obj.view.hKnobV);
            
            % create main display timer
            obj.hDisplayTimer = timer;
            obj.hDisplayTimer.ExecutionMode = 'fixedRate'; % fixedSpacing
            obj.hDisplayTimer.Period = obj.refreshRate;
            obj.hDisplayTimer.TimerFcn = @(src, event)render(obj);  
            
            % first fps tick
            obj.fpsTick = tic;
            
            % start rendering
            start(obj.hDisplayTimer);
        end
    end
    
%% Private Methods   
    methods (Access = private)
        %% check view refs valid
        function valid = viewRefsValid(obj)
            valid = isvalid(obj.view) && isvalid(obj.view.hKnobH) && ...
                    isvalid(obj.view.hKnobV) && isvalid(obj.view.hPosH) && ...
                    isvalid(obj.view.hPosV) && isvalid(obj.view.hTrigVal) && ...
                    isvalid(obj.view.hTrig) && isvalid(obj.view.hTrigged) && ...
                    isvalid(obj.view.hFig);
        end
        
        %% set ui callbacks
        function setUiCallbacks(obj)                   
            obj.view.hFig.CloseRequestFcn = @(src, evet)closingFig(obj);
            obj.view.hKnobH.ValueChangedFcn = @(src, event)knobHChanged(obj, src);
            obj.view.hKnobV.ValueChangedFcn = @(src, event)knobVChanged(obj, src);
            obj.view.hPosH.ValueChangingFcn = @(src, event)posHChanged(obj, src, event);
            obj.view.hPosV.ValueChangingFcn = @(src, event)posVChanged(obj, src, event);
            obj.view.hTrigVal.ValueChangingFcn = @(src, event)trigValChanged(obj, src, event);
            obj.view.hTrigMode.ValueChangedFcn = @(src, event)trigModeChanged(obj, event);
            obj.view.hTrig.ValueChangedFcn = @(src, event)trigChanged(obj, event);     
            obj.view.hFft.ValueChangedFcn = @(src, event)fftChanged(obj, event);
            obj.view.hFftZoomOut.ValueChangedFcn = @(src, event)fftZoomOut(obj);
        end
        
        %% ui callback - horizontal position knob 
        function posHChanged(obj, src, event)
            obj.posH = event.Value / 100 * obj.windowLen;
            
            if ~isempty(obj.sampleRate)
                tipVal = obj.posH / obj.sampleRate;
                src.Tooltip = ...
                    mscope.generic.controller.formatSeconds(tipVal, 3);
            end

            if ~obj.fftEnabled
                obj.fftNeedToFocus = true;
            end
        end
        
        %% ui callback - vertical position knob 
        function posVChanged(obj, src, event)
            obj.posV = event.Value / 100 * obj.posVrange(2);  
                        
            if ~isempty(obj.vMax) && ~isempty(obj.bitMaxRange)
                tipVal = obj.posV;
                if obj.bitMax > 0 % real device
                    tipVal = obj.posV / obj.bitMaxRange * obj.vMax;
                end
                src.Tooltip = ...
                    mscope.generic.controller.formatVolts(tipVal, 3);
            end
            
            if ~obj.fftEnabled
                obj.fftNeedToFocus = true;
            end
        end
        
        %% ui callback - trigger value knob 
        function trigValChanged(obj, src, event)
            val = event.Value / 100 * obj.posVrange(2);
            obj.trigVal = val;
            obj.trigger = val;
            
            if ~isempty(obj.vMax) && ~isempty(obj.bitMaxRange)
                tipVal = val;
                if obj.bitMax > 0 % real device
                    tipVal = val / obj.bitMaxRange * obj.vMax;
                end
                src.Tooltip = ...
                    mscope.generic.controller.formatVolts(tipVal, 3);
            end
       
            obj.fftNeedToFocus = true;
        end
        
        %% ui callback - trigger switch - on / off
        function trigChanged(obj, event)
            if event.Value == true
                obj.trigger = obj.trigVal;
            else
                obj.trigger = nan;
            end
            obj.fftNeedToFocus = true;
            obj.view.enableTrigControls(event.Value);
        end
        
        %% ui callback - trigger mode - raising / falling
        function trigModeChanged(obj, event)
            obj.trigMode = event.Value;
            obj.fftNeedToFocus = true;
        end
        
        %% ui callback - fft zoom out
        function fftZoomOut(obj)
            if obj.fftZoomedOut == false
                obj.fftZoomedOut = true;
            else
                obj.fftZoomedOut = false;
            end
            obj.fftFocusCounter = obj.fftFocusCounterMax + 1;
        end
        
        %% ui callback - fft switch - on / off
        function fftChanged(obj, event)   
            obj.xValuesChaged = true;
            obj.fftEnabled = event.Value;
            
            if event.Value == 1 % fft mode
                % change axes properites
                %obj.view.hAxes.XTickLabelMode = 'auto';
                obj.view.hAxes.YTickLabelMode = 'auto';
                %obj.view.hAxes.XTickMode = 'auto';
                obj.view.hAxes.YTickMode = 'auto';
                obj.view.hAxes.XLabel.String = 'Frequency [Hz]';
                obj.view.hAxes.YLabel.String = 'Gain [dB]';         
                obj.view.hAxes.YLim = [-100 0];
                obj.view.hZeroLine.LineWidth = 0.5;
                %obj.view.hAxes.XAxis.Exponent = 0;
                obj.fftFocusCounter = obj.fftFocusCounterMax + 1;
                %obj.view.hAxes.Toolbar.Visible = 'on'; % keep crashing
                %enableDefaultInteractivity(obj.view.hAxes);  
                
                % fft zoom out controls
                obj.view.hFftZoomOut.Visible = 'on';
                obj.view.hTrigged.Visible = 'off';
                
                % change private helper variables
                obj.fftNeedToFocus = true;
                obj.rmDisc = false;
                
            else % signal mode
                % change axes properites
                %obj.view.hAxes.XTickLabelMode = 'manual';
                obj.view.hAxes.YTickLabelMode = 'manual';
                %obj.view.hAxes.XTickMode = 'manual';
                obj.view.hAxes.YTickMode = 'manual';
                obj.view.hAxes.XTickLabel = [];
                obj.view.hAxes.YTickLabel = [];  
                obj.view.hAxes.XLabel.String = '';
                obj.view.hAxes.YLabel.String = '';
                obj.view.hZeroLine.LineWidth = 0.8;
                %obj.view.hAxes.Toolbar.Visible = 'off';
                %disableDefaultInteractivity(obj.view.hAxes); 
                obj.fftZoomedOut = false;
                
                % fft zoom out controls
                obj.view.hFftZoomOut.Value = 1; % -
                obj.view.hFftZoomOut.Enable = 'on';
                obj.view.hFftZoomOut.Visible = 'off';
                obj.view.hTrigged.Visible = 'on';
                
                % invoke scale knobs change to reinit
                obj.knobVChanged(obj.view.hKnobV);
                obj.knobHChanged(obj.view.hKnobH);
                
                % change private helper variables
                obj.rmDisc = true;        
            end
        end
        
        %% main display render timer callback
        function render(obj)     
            try
                % render
                if ~obj.model.bufferEmpty

                    % get data from buffer                   
                    buff = obj.model.getBuffer(obj.windowLen, obj.posH, ...
                        obj.rmDisc, obj.trigger, obj.trigMode, obj.posHscaler);
                    
                    % throw error if buffer read criticaly failed
                    err = obj.model.lastError;
                    if ~isempty(err)
                        error(err);
                    end
                        
                    if obj.fftEnabled == false % display signal
                        % change x values only when needed to speed up
                        if obj.xValuesChaged == true
                            obj.view.hLine.XData = (1:obj.windowLen) + obj.posH;
                            obj.xValuesChaged = false;
                        end
                        
                        % check if we have valid x and y size (mem corrupt)
                        if length(buff) == length(obj.view.hLine.XData) 
                            obj.view.hLine.YData = buff + obj.posV;  % display data
                            obj.view.trigLamp(obj.model.isTrigged);  % trigger lamp
                            obj.signalMeas(buff);                    % display meas
                        else
                            disp("(mem corupt) wrong x y size! " + length(buff) + ...
                                " ~= " + length(obj.view.hLine.XData));
                        end                      
                    else % display fft
                        % calculate fft and max freq and gain
                        [f, y, mf, my, nfft] = obj.fftCalc(buff);
                        
                        obj.view.hLine.XData = f;   % display frequencies
                        obj.view.hLine.YData = y;   % display gain values   
                        obj.fftFocusAndDispMeas(mf, my, nfft); % display meas
                    end
                end
                
                obj.calcFps(); % calc and show FPS label

            catch ex
                disp("render error: " + getReport(ex)); %);  ex.message
                %obj.model.reset();
                %obj.deviceEnable(false, true);
            end       
        end
        
        %% FFT calc
        function [freq, spectr, maxFreq, maxGain, NFFT] = fftCalc(obj, buff)     
            n = length(buff);                      % length of signal
            NFFT = 2^nextpow2(n);                  % trim to power of 2
            spectr = fft(buff.*obj.hannWindow, NFFT)/n; % fft and normalize
            spectr = 20*log10(abs(spectr));        % get decibels

            %df = 1 / n / obj.sampleRate;           % get step
            %freq = 0:df:(obj.sampleRate/2)-df;     % get x axis as freqs
            freq = obj.sampleRate/2*linspace(0,1,NFFT/2+1);
            
            spectr = spectr(1:length(freq));       % check length match
            %spectr(spectr > 0) = 0;               % trim positive values
                        
            maxGain = max(spectr);                 % get max db
            maxFreq = freq(spectr == maxGain);     % get max freq
            if length(maxFreq) > 1
                maxFreq = maxFreq(1);              % trim multiple max freq
            end
            if maxGain > 0 && maxGain < Inf
                spectr = spectr - maxGain;         % normalize to 0 dB
                maxGain = 0;
            end
            
            %[S,F,T] = spectrogram(spectr, 100, 20, [], obj.sampleRate);
            %imagesc(T, F, 20*log10(abs(S)));
        end
        
        %% focus on FFT max freq and display meas
        function fftFocusAndDispMeas(obj, max_f, max_y, nfft)
            % focus on freq range where max gain is. there are some
            % problems with uiaxes interactivity, while updating data,
            % so this flag is just not used right now, maybe later
            
            %if obj.fftNeedToFocus == true
            if obj.fftFocusCounter > obj.fftFocusCounterMax
                obj.fftFocusCounter = 0;
                obj.fftNeedToFocus = false;
                minf = -max_f*2; % focus twice freq up and down
                maxf = max_f*2;
                if minf < 0
                    minf = 0;
                end

                maxf_rng = obj.sampleRate / 2; % zoom out max range
                zoomOutAvailable = false;
                
                % check if focus is available - only when gain is good
                if ~isempty(max_y) && ~isempty(max_f) && maxf < maxf_rng && ...
                    minf < maxf && max_y > -15  % max gain higher than -15 
                    zoomOutAvailable = true;
                end
                
                % if focus available, allow zoom out button. set freq range
                if zoomOutAvailable == true
                    rng = [minf maxf];      % focus near max freq
                    obj.view.hFftZoomOut.Enable = 'on';
                    if obj.fftZoomedOut == true
                        rng = [0 maxf_rng]; % focus on whole range
                    end
                else
                    rng = [0 maxf_rng];     % focus on whole range
                    obj.fftZoomedOut = true;
                    obj.view.hFftZoomOut.Value = 0; % +
                    obj.view.hFftZoomOut.Enable = 'off';
                end
                
                % adjust axes limits and ticks with calculated range vals    
                obj.view.hAxes.XLim = rng;
                obj.view.hAxes.XTick = linspace(rng(1), rng (2), 11);
                obj.view.hAxes.XTickLabel = compose("%.1f", obj.view.hAxes.XTick);

            else
                obj.fftFocusCounter = obj.fftFocusCounter + 1;
            end

            % get string values and units
            max_f_s = sprintf('%0.1f [Hz]   ', max_f);
            max_y_s = sprintf('%0.1f [dB]   ', max_y);
            nfft_s = sprintf('%0.0f        ', nfft);
            
            % get complete label strings
            max_f_s = sprintf('max freq:%s', pad(max_f_s, obj.fftMeasPad, 'left'));
            max_y_s = sprintf('max gain:%s', pad(max_y_s, obj.fftMeasPad, 'left'));
            nfft_s = sprintf('nfft:%s', pad(nfft_s, obj.fftMeasPad, 'left'));
            wind_s = 'window:  hanning        ';
            
            % finally update ui label
            obj.view.hMeasureLabel.Text = {''; max_f_s; max_y_s; nfft_s; wind_s};
        end
        
        %% calc signal meas and display label
        function signalMeas(obj, data)    
            % calc stats
            max_y = max(data);
            min_y = min(data);
            vpp_val = abs(max_y - min_y);
            
            dat = data(~isnan(data));  
            rms_val = sqrt(1/length(dat).*(sum(dat.^2)));
            avg_val = sum(dat) / length(dat);
            
            % scale to real voltage levels
            if obj.bitMax > 0
                vScaler = obj.vMax / (2^obj.bitMax / 2); % voltage rescaler
                
                max_y = max_y * vScaler;
                min_y = min_y * vScaler;
                vpp_val = vpp_val * vScaler;
                rms_val = rms_val * vScaler;
                avg_val = avg_val * vScaler;
            end
            
            % meas label format
            measFormat = '%0.4f [V]  ';
            
            % pad with spaces from left
            max_s = sprintf(measFormat, max_y);
            min_s = sprintf(measFormat, min_y);
            vpp_s = sprintf(measFormat, vpp_val);
            pts_s = sprintf('%0.f      ', length(data));
            rms_s = sprintf(measFormat, rms_val);
            avg_s = sprintf(measFormat, avg_val);
            
            % get final strings
            max_s = sprintf('max:%s', pad(max_s, obj.sigMeasPad, 'left'));
            min_s = sprintf('min:%s', pad(min_s, obj.sigMeasPad, 'left'));
            vpp_s = sprintf('Vpp:%s', pad(vpp_s, obj.sigMeasPad, 'left'));
            rms_s = sprintf('RMS:%s', pad(rms_s, obj.sigMeasPad, 'left'));
            avg_s = sprintf('avg:%s', pad(avg_s, obj.sigMeasPad, 'left'));
            pts_s = sprintf('pts:%s', pad(pts_s, obj.sigMeasPad, 'left'));
            
            % finally update ui label
            obj.view.hMeasureLabel.Text = ...
                {''; max_s;min_s;rms_s;avg_s;vpp_s;pts_s};
        end
        
        %% FPS calc and display label
        function calcFps(obj)
            fpsInFft = '  ';
            if obj.fftEnabled == true
                fpsInFft = '       ';
            end

            %ram = memory;
            %ramUsed = ram.MemUsedMATLAB / 10^9;
            %ramFree = ram.MemAvailableAllArrays / 10^9;
            
            fps = sprintf('%0.1f FPS', 1 / toc(obj.fpsTick));
            %ramUsed_s = sprintf(' %0.1f GB used', ramUsed);
            %ramFree_s = sprintf(' %0.1f GB free', ramFree);
            
            fps = pad(fps, 8, 'left');
            obj.view.hFpsLabel.Text = {' ';[fpsInFft, fps];}; %...
                %[fpsInFft, ramFree_s];[fpsInFft, ramUsed_s]};
            obj.fpsTick = tic;
        end
        
        %% on close cleanup timers
        function closingFig(obj)
            try
                stop(obj.hDisplayTimer);
                delete(obj.hDisplayTimer);
                obj.deviceDelete();
                delete(obj.view.hFig);
            catch ex
                disp("closing error: " + getReport(ex));
            end
        end  
    end
    
%% Protected Methods       
    methods (Access = protected)
        %% ui callback - horizontal scale knob
        function knobHChanged(obj, src)
            obj.view.hPosH.Value = 0;  % reset h position
            obj.fftNeedToFocus = true; % invoke fft x axis refocus
            obj.posH = 0;
            
            obj.knobH = src.Value;     % save h scale value  
            
            % calculate new window lenght - points to be displayed
            obj.windowLen = ceil(src.Value * obj.gridCellsH * obj.sampleRate);
            if obj.windowLen < 2
                obj.windowLen = 2;
            end
            
            % create hanning window vector for fft
            obj.hannWindow = 0.5 - 0.5*cos(2*pi*linspace(0, 1, obj.windowLen));
            
            % invoke signal x axis values change
            obj.xValuesChaged = true;  
            
            % if signal display mode, set x limits, ticks and pos knob lim
            if obj.fftEnabled == false 
                obj.view.hAxes.XLim = [1 obj.windowLen];
                obj.view.hAxes.XTick = ...
                    linspace(1, obj.windowLen, obj.gridCellsH + 1);
            end
            
            % change posH limits according to horizontal scale
            if src.Value > 0.1
                obj.posHscaler = 1;
            elseif src.Value > 0.01
                obj.posHscaler = 1.5;
            elseif src.Value > 0.001
                obj.posHscaler = 2.0;
            elseif src.Value > 0.0001
                obj.posHscaler = 3.0;
            elseif src.Value > 0.00001
                obj.posHscaler = 4.0;
            else
                obj.posHscaler = 5.0;
            end
            
            % adjust posH knob to suit user needs
            obj.posHrange = [-obj.windowLen*obj.posHscaler 0]; % set real rng
            obj.view.hPosH.Limits = [-100*obj.posHscaler 0]; % set percent rng
            obj.view.hPosH.MajorTicks = ...
                linspace(obj.view.hPosH.Limits(1), obj.view.hPosH.Limits(2), 11);
            
            event.Value = obj.view.hPosH.Value; % create event
            obj.posHChanged(obj.view.hPosH, event); % invoke pos H callback
            
            % create label
            obj.view.hKnobHLabel.Text = ...
                mscope.generic.controller.formatSeconds(src.Value, 0) + " / div";
        end
        
        %% ui callback - vertical scale knob
        function knobVChanged(obj, src)           
            obj.knobV = src.Value;       % save value
            valuePerDiv = src.Value;     % helper var for pos V range
            obj.fftNeedToFocus = true;   % invoke fft x axis refocus
            
            % calculate real current voltage range from bit values
            % maxBit  ... vMax
            % currBit ... currVolt
            currVoltRange = (obj.gridCellsV / 2) * src.Value;   
            if obj.bitMax > 0 % real device with real bit settings
                currBitRange = (currVoltRange / obj.vMax) * obj.bitMaxRange; 
                valuePerDiv = valuePerDiv * (obj.bitMaxRange / obj.vMax);
            else % simulation
                currBitRange = currVoltRange;
            end
            
            % set pos V knob real range and value
            obj.posVrange = [-0.5 0.5] .* (valuePerDiv * obj.gridCellsV); 
            event.Value = obj.view.hPosV.Value; % create event
            obj.posVChanged(obj.view.hPosV, event); % invoke pos V callback
            
            % if signal display mode, set y limits, ticks and pos knob lim
            if obj.fftEnabled == false
                obj.view.hAxes.YLim = [-currBitRange currBitRange];
                obj.view.hAxes.YTick = linspace(-currBitRange, currBitRange, ...
                    obj.gridCellsV + 1);     
            end
            
            % create label
            obj.view.hKnobVLabel.Text = ...
                mscope.generic.controller.formatVolts(src.Value, 0) + " / div";
        end
    end
    
%% Abstract Methods      
    methods (Abstract) % these methods needs to be implemented in sub class
        ok = deviceSet(obj)
        ok = deviceEnable(obj, val, updateUi)
        ok = deviceScan(obj)
        ok = deviceDelete(obj)
    end 
    
%% Static Helper Methods   
    methods (Static)
        %% format volts to friendly units
        function str = formatVolts(val, precision)
            unit = 'V';
            absVal = abs(val);
            
            if absVal < 0.001
                val = val * 1000000;
                unit = 'μV';
            elseif absVal < 1
                val = val * 1000;
                unit = 'mV';
            end 
            
            str = sprintf(['%0.' num2str(precision) 'f %s'], val, unit);
        end
        
        %% format seconds to friendly units
        function str = formatSeconds(val, precision)
            unit = 's';
            absVal = abs(val);

            if absVal < 0.001
                val = val * 1000000;
                unit = 'μs';
            elseif absVal < 1
                val = val * 1000;
                unit = 'ms';
            end 
            
            str = sprintf(['%0.' num2str(precision) 'f %s'], val, unit);
        end
    end
end