classdef view < mscope.generic.view
%mscope.specific.simulation.view - create specific device panel elements.
%it extends generic.view class with device specific functionality, holding
%ui element handles and providing only basic ui related things, like
%enabling / disabling elements.
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    14.5.2020
% --------------------------

%% Properties - ui handles  
    properties (SetAccess = private, GetAccess = ?mscope.specific.simulation.controller)  
        hGridPanelDev  
        hGridFreqAmp
        
        hMode
        hFrequency
        hFrequencyLabel
        hAmplitude
        hAmplitudeLabel
        hEnabled
        hStart
    end
    
%% Public Methods
    methods % (Access = public) 
        %% constructor
        function obj = view()      
            obj.createDeviceUi();          % create ui
            obj.enableDevControls(true);   % enable controls
        end
        %% 
        function enableFrequency(obj)
            if obj.hMode.Value == 4 % rnd
                obj.hFrequency.Enable = 'off';
                obj.hFrequencyLabel.Enable = 'off';
            else
                obj.hFrequency.Enable = 'on';
                obj.hFrequencyLabel.Enable = 'on';
            end
        end
        
        %% enable / disable device controls override
        function enableDevControls(obj, value)
            val =  'on';
            if value ~= true 
                val = 'off';
            end
            
            obj.hMode.Enable = val;
            obj.hFrequency.Enable = val;
            obj.hAmplitude.Enable = val;
        end
    end
    
%% Private Methods
    methods (Access = private)       
        function createDeviceUi(obj)
            %% grids
            obj.hGridPanelDev = uigridlayout(obj.hPanelDev, ...
                'Padding', [10 10 10 0], ...
                'RowHeight', {'2x', '1x'}, ...
                'ColumnWidth', {'8x','5x','3x'});
            
            obj.hGridFreqAmp = uigridlayout(obj.hGridPanelDev, ...
                'Padding', [10 10 10 0], ...
                'RowHeight', {'1x', '1x', '2x', '1x'}, ...
                'ColumnWidth', {'5x','4x'});
            obj.hGridFreqAmp.Layout.Row = 1;
            obj.hGridFreqAmp.Layout.Column = [2 3];
            
            %% mode
            obj.hMode = uiknob(obj.hGridPanelDev, 'discrete', ...
                'Tooltip', 'Generator Mode', ...
                'Items', {'Sine', 'Triangle', 'Saw', 'Square', 'Rnd'}, ...
                'ItemsData', [0 1 2 3 4]);
            obj.hMode.Layout.Row = 1;
            obj.hMode.Layout.Column = 1;
            
            %% frequency label
            obj.hFrequencyLabel = uilabel(obj.hGridFreqAmp, ...
                'Text', 'Frequency:', ...
                'FontSize', 15, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom');
            obj.hFrequencyLabel.Layout.Row = 2;
            obj.hFrequencyLabel.Layout.Column = 1;
            
            %% frequency input numeric
            obj.hFrequency = uispinner(obj.hGridFreqAmp, ...
                'Tooltip', 'Frequency', ...
                'FontSize', 16, ...
                'ValueDisplayFormat','%.0f Hz', ...
                'Limits', [1 1000000]);
            obj.hFrequency.Layout.Row = 3;
            obj.hFrequency.Layout.Column = 1;

            %% amplitude label
            obj.hAmplitudeLabel = uilabel(obj.hGridFreqAmp, ...
                'Text', 'Amplitude:', ...
                'FontSize', 15, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom');
            obj.hAmplitudeLabel.Layout.Row = 2;
            obj.hAmplitudeLabel.Layout.Column = 2;
            
            %% amplitude input numeric
            obj.hAmplitude = uispinner(obj.hGridFreqAmp, ...
                'Tooltip', 'Amplitude', ...
                'FontSize', 16, ...
                'ValueDisplayFormat','%.1f V', ...
                'Limits', [-10 10]);
            obj.hAmplitude.Layout.Row = 3;
            obj.hAmplitude.Layout.Column = 2;

            %% enabled lamp
            obj.hEnabled = uilamp(obj.hGridPanelDev, ...
                'Tooltip', 'Device Enabled', ...
                'Color', '#A9A9A9');
            obj.hEnabled.Layout.Row = 2;
            obj.hEnabled.Layout.Column = 3;

            %% start button
            obj.hStart = uibutton(obj.hGridPanelDev, ...
                'BackgroundColor', [0.85 0.85 0.85], ...
                'Text', 'Start', ...
                'FontSize', 20, ...
                'FontWeight', 'Bold');
            obj.hStart.Layout.Row = 2;
            obj.hStart.Layout.Column = [1 2];
        end
    end
end