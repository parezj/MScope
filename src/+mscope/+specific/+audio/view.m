classdef view < mscope.generic.view
%mscope.specific.audio.view - create specific device panel elements.
%it extends generic.view class with device specific functionality, holding
%ui element handles and providing only basic ui related things, like
%enabling / disabling elements.
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    14.5.2020
% --------------------------
    
%% Properties - ui handles   
    properties (SetAccess = private, GetAccess = ?mscope.specific.audio.controller)  
        hGridPanelDev  % device panel main grid
        hDevices       % devices listbox
        hSampleRate    % sample rate listbox
        hBits          % bit rate listbox
        hVmax          % vMax numeric input
        hVmaxLabel     % vMax label
        hEnabled       % main on / off indication lamp
        hStart         % main on / off start button
    end
    
%% Public Methods
    methods % (Access = public) 
        %% constructor
        function obj = view()      
            obj.createDeviceUi();          % create ui
            obj.enableDevControls(true);   % enable controls
        end
        
        %% enable / disable device controls override
        function enableDevControls(obj, value)
            val =  'on';
            if value ~= true 
                val = 'off';
            end
            
            obj.hDevices.Enable = val;
            obj.hSampleRate.Enable = val;
            obj.hBits.Enable = val;
            obj.hVmax.Enable = val;
            obj.hVmaxLabel.Enable = val;
        end
    end
    
%% Private Methods
    methods (Access = private)       
        function createDeviceUi(obj)
            %% grid
            obj.hGridPanelDev = uigridlayout(obj.hPanelDev, ...
                'RowHeight', {'1x','2x','2x','2x','3x'}, ...
                'ColumnWidth', {'10x','4x','4x'});
            
            %% devices listbox
            obj.hDevices = uilistbox(obj.hGridPanelDev);
            obj.hDevices.Layout.Row = [1 4];
            obj.hDevices.Layout.Column = 1;

            %% sample rate listbox
            obj.hSampleRate = uilistbox(obj.hGridPanelDev, ...
                'Items', {'8 kHz','16 kHz','44.1 kHz','48 kHz','96 kHz','192 kHz'}, ...
                'ItemsData', [8, 16, 44.1, 48, 96, 192]);
            obj.hSampleRate.Layout.Row = [1 4];
            obj.hSampleRate.Layout.Column = 2;

            %% bits listbox
            obj.hBits = uilistbox(obj.hGridPanelDev, ...
                'Items', {'8 bit','16 bit','24 bit','32 bit'}, ...
                'ItemsData', [8, 16, 24, 32]);
            obj.hBits.Layout.Row = [3 4];
            obj.hBits.Layout.Column = 3;
            
            %% vMax input numeric and label
            obj.hVmaxLabel = uilabel(obj.hGridPanelDev, ...
                'Text', 'V max:', ...
                'FontSize', 15, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom');
            obj.hVmaxLabel.Layout.Row = 1;
            obj.hVmaxLabel.Layout.Column = 3;
            
            obj.hVmax = uispinner(obj.hGridPanelDev, ...
                'FontSize', 16, ...
                'Tooltip', ['This value is absolute maximum voltage your '...
                           'audiocard cant sample without clip, eg. voltage '...
                           'proportional to max bit value.'], ...
                'ValueDisplayFormat','%.2f V', ...
                'Limits', [0.01, 10]);
            obj.hVmax.Layout.Row = 2;
            obj.hVmax.Layout.Column = 3;

            %% enabled lamp
            obj.hEnabled = uilamp(obj.hGridPanelDev, ...
                'Tooltip', 'Device Enabled', ...
                'Color', '#A9A9A9');
            obj.hEnabled.Layout.Row = 5;
            obj.hEnabled.Layout.Column = 3;

            %% start button
            obj.hStart = uibutton(obj.hGridPanelDev, ...
                'BackgroundColor', [0.85 0.85 0.85], ...
                'Text', 'Start', ...
                'FontSize', 20, ...
                'FontWeight', 'Bold');
            obj.hStart.Layout.Row = 5;
            obj.hStart.Layout.Column = [1 2]; 
        end
    end
end