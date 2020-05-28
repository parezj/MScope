classdef (Abstract) view < handle
%mscope.generic.view - create ui elements, hold their handles and manage
%only ui related things, like visibility or if element is enabled. values,
%callbacks and interactivity is left to controller. view can exist without
%controller or model, therefore doesnt have any handles or relation to them
%this class is abstract, becasue it needs to implement device speficic panel
%this can be done with property: hPanelDev 
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    11.5.2020
% --------------------------
    
%% Constants
    properties (Constant)
        figSize = [1500 900];     % main window initial size
        bgColor = [0.8 0.8 0.8];  % main window background color
    end
    
%% Properties - ui handles
    properties (SetAccess = private, GetAccess = ?mscope.generic.controller)  
        hFig            % main window
        hGrids          % all grids
        hPanels         % all panels
        
        hKnobHLabel     % knob h label (sec / div)
        hKnobVLabel     % knob v label (volts / div)
        hKnobH          % h scale knob
        hKnobV          % v scale knob
        hPosH           % h position knob
        hPosV           % v position knob
        
        hTrigVal        % trigger value
        hTrig           % trigger switch - enable / disable
        hTrigged        % trigger lamp - indicate if trigged
        hTrigMode       % trigger mode (rising / falling)
        
        hFft            % fft on / off switch
        hFftZoomOut     % fft zoom out button
        
        hMeasureLabel   % signal / fft measure label
        hFpsLabel       % fps label
        
        hAxes           % main plot axes
        hLine           % signal / fft line
        hZeroLine       % signal zero line
    end
    
%% Protected Properties
    properties (Access = protected)    
        hPanelDev       % empty panel to be implemented in sub class
    end
    
%% Public Methods
    methods % (Access = public)     
        %% constructor
        function obj = view() 
            obj.createStaticUi();
            obj.enableTrigControls(false);
        end
        
        %% enable / disable all main controls
        function enableControls(obj, value)
            val = 'on';
            if value ~= true 
                val = 'off';
            end
            
            obj.hKnobH.Enable = val;
            obj.hKnobV.Enable = val;
            obj.hPosH.Enable = val;
            obj.hPosV.Enable = val;
            obj.hTrig.Enable = val;
            obj.hKnobHLabel.Enable = val;
            obj.hKnobVLabel.Enable = val;
        end
        
        %% enable / disable trigger controls
        function enableTrigControls(obj, value)
            val =  'on';
            if value ~= true 
                val = 'off';
            end
            
            obj.hTrigVal.Enable = val;
            obj.hTrigged.Enable = val;
            obj.hTrigMode.Enable = val;
        end
                        
        %% set device panel title
        function setPanelDevTitle(obj, title)
            obj.hPanelDev.Title = title;
        end
        
        %% set trigger lamp color
        function trigLamp(obj, val)
            if val == true
                obj.hTrigged.Color = 'green';
            else
                obj.hTrigged.Color = '#A9A9A9';
            end
        end
    end
    
%% Private Methods
    methods (Access = private)       
        function createStaticUi(obj)
            screenSize = get(groot, 'Screensize');
            pos = [(screenSize(3:4) - obj.figSize)/2 obj.figSize];
            
            %% Figure
            obj.hFig = uifigure('Position', pos, ...
                'Name', 'MScope');
            obj.hFig.Color = obj.bgColor;

            %% Main Grid
            obj.hGrids.hGridMain = uigridlayout(obj.hFig, ...
                'RowHeight', {'fit', '1x'}, ...
                'ColumnWidth', {'5x', '2x'});
            obj.hGrids.hGridRight = uigridlayout(obj.hGrids.hGridMain, ...
                'RowHeight', {'3x', '2x', '2x', '3x'}, ...
                'ColumnWidth', {'1x', '1x'});
            obj.hGrids.hGridRight.Layout.Row = [1 2];
            obj.hGrids.hGridRight.Layout.Column = 2;

            %% Horizontal elements Panels
            obj.hPanels.hPanelKnobH = uipanel(obj.hGrids.hGridRight, ...
                'Title', 'Horizontal Scale');
            obj.hPanels.hPanelKnobH.Layout.Row = 1;
            obj.hPanels.hPanelKnobH.Layout.Column = 1;

            obj.hPanels.hPanelPosH = uipanel(obj.hGrids.hGridRight, ...
                'Title', 'H Position (% of window samples)');
            obj.hPanels.hPanelPosH.Layout.Row = 2;
            obj.hPanels.hPanelPosH.Layout.Column = 1;
            
            %% Horizontal elements Grids
            obj.hGrids.hKnobHGrid = uigridlayout(obj.hGrids.hGridRight, ...
                 'Padding', [0 5 0 20], ...
                 'RowHeight', {10, 'fit', '1x'}, ...
                 'ColumnWidth', {'1x'});
            obj.hGrids.hKnobHGrid.Layout.Row = 1;
            obj.hGrids.hKnobHGrid.Layout.Column = 1;
            
            obj.hGrids.hPosHGrid = uigridlayout(obj.hGrids.hGridRight, ...
                 'Padding', [0 5 0 20], ...
                 'RowHeight', {'1x'}, ...
                 'ColumnWidth', {'1x'});
            obj.hGrids.hPosHGrid.Layout.Row = 2;
            obj.hGrids.hPosHGrid.Layout.Column = 1;
            
             %% Vertical elements Panels
            obj.hPanels.hPanelKnobV = uipanel(obj.hGrids.hGridRight, ...
                'Title', 'Vertical Scale');
            obj.hPanels.hPanelKnobV.Layout.Row = 1;
            obj.hPanels.hPanelKnobV.Layout.Column = 2;

            obj.hPanels.hPanelPosV = uipanel(obj.hGrids.hGridRight, ...
                'Title', 'V Position (% of y+ axis range)');
            obj.hPanels.hPanelPosV.Layout.Row = 2;
            obj.hPanels.hPanelPosV.Layout.Column = 2;
            
            %% Vertical elements Grids
            obj.hGrids.hKnobVGrid = uigridlayout(obj.hGrids.hGridRight, ...
                 'Padding', [0 5 0 20], ...
                 'RowHeight', {10, 'fit', '1x'}, ...
                 'ColumnWidth', {'1x'});
            obj.hGrids.hKnobVGrid.Layout.Row = 1;
            obj.hGrids.hKnobVGrid.Layout.Column = 2;
            
            obj.hGrids.hPosVGrid = uigridlayout(obj.hGrids.hGridRight, ...
                 'Padding', [0 5 0 20], ...
                 'RowHeight', {'1x'}, ...
                 'ColumnWidth', {'1x'});
            obj.hGrids.hPosVGrid.Layout.Row = 2;
            obj.hGrids.hPosVGrid.Layout.Column = 2;
            
            %% Trigger Panel + Grid
            obj.hPanels.hPanelTrig = uipanel(obj.hGrids.hGridRight, ...
                'Title', 'Trigger (% of y+ axis range) & FFT');
            obj.hPanels.hPanelTrig.Layout.Row = 3;
            obj.hPanels.hPanelTrig.Layout.Column = [1, 2];
            
            obj.hGrids.hGridPanelTrig = uigridlayout(obj.hPanels.hPanelTrig, ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'6x', '2x', '2x', '2x', '2x'});

            %% Device Panel
            obj.hPanelDev = uipanel(obj.hGrids.hGridRight, ...
                'Title', 'Device');
            obj.hPanelDev.Layout.Row = 4;
            obj.hPanelDev.Layout.Column = [1, 2];

            %% H/V Elements
            obj.hKnobHLabel = uilabel(obj.hGrids.hKnobHGrid, ...
                'Text', '?', ...
                'FontSize', 23, ...
                'HorizontalAlignment', 'center');
            obj.hKnobHLabel.Layout.Row = 2;
            
            obj.hKnobH = uiknob(obj.hGrids.hKnobHGrid, 'discrete', ...
                'Items', {'1 s', '500 ms', '250 ms', '100 ms', '50 ms', ...
                          '20 ms', '10 ms', '5 ms', '1 ms', '500 μs', '200 μs', ...
                          '100 μs', '50 μs', '20 μs', '10 μs'}, ...
                'ItemsData', [1 0.5 0.25 0.1 0.05 0.02 0.01 0.005 0.001 ... 
                              0.0005 0.0002 0.0001 0.00005 0.00002 0.00001]);
            obj.hKnobH.Layout.Row = 3;
                          
            obj.hKnobVLabel = uilabel(obj.hGrids.hKnobVGrid, ...
                'Text', '?', ...
                'FontSize', 23, ...
                'HorizontalAlignment', 'center');
            obj.hKnobVLabel.Layout.Row = 2;
            
            obj.hKnobV = uiknob(obj.hGrids.hKnobVGrid, 'discrete', ...
                'Items', {'10 V', '5 V', '2 V', '1 V', '500 mV', '250 mV', ...
                          '100 mV', '50 mV', '20 mV', '10 mV', '1 mV', '100 μV', '10 μV'}, ...
                'ItemsData', [10 5 2 1 0.5 0.25 0.1 0.05 0.02 0.01 0.001 0.0001 0.00001]);        
            obj.hKnobV.Layout.Row = 3;
                          
            obj.hPosH = uiknob(obj.hGrids.hPosHGrid, ...
                'Tooltip', '0 %', ...
                'Limits', [-100 0], ...
                'MajorTicksMode', 'manual', ...
                'MajorTicks', -100:10:0);
            obj.hPosV = uiknob(obj.hGrids.hPosVGrid, ...
                'Tooltip', '0 %', ...
                'Limits', [-100 100], ...
                'MajorTicksMode', 'manual', ...
                'MajorTicks', -100:20:100);

            %% Trigger Elements
            obj.hTrigVal = uiknob(obj.hGrids.hGridPanelTrig, ...
                'Tooltip', '0 mV', ...
                'Limits', [-100 100], ...
                'MajorTicksMode', 'manual', ...
                'MajorTicks', -100:20:100);
            obj.hTrigVal.Layout.Column = 1;
            
            obj.hTrigMode = uiswitch(obj.hGrids.hGridPanelTrig, 'toggle', ...
                'Orientation', 'vertical', ...
                'Items', { 'Rising', 'Falling' }, ...
                'ItemsData', [0 1]);
            obj.hTrigMode.Layout.Column = 2;
            
            obj.hTrig = uiswitch(obj.hGrids.hGridPanelTrig, 'toggle', ...
                'Orientation', 'vertical', ...
                'Items', { 'Trig Off', 'Trig On' }, ...
                'ItemsData', [0 1]);
            obj.hTrig.Layout.Column = 3;
            
            obj.hFft = uiswitch(obj.hGrids.hGridPanelTrig, 'toggle', ...
                'Orientation', 'vertical', ...
                'Items', { 'FFT Off', 'FFT On' }, ...
                'ItemsData', [0 1]);
            obj.hFft.Layout.Column = 4;

            obj.hGrids.hTriggedGrid = uigridlayout(obj.hGrids.hGridPanelTrig, ...
                 'Padding', [5 0 15 0], ...
                 'RowHeight', {'1x'}, ...
                 'ColumnWidth', {'1x'});
            obj.hGrids.hTriggedGrid.Layout.Row = 1;
            obj.hGrids.hTriggedGrid.Layout.Column = 5;
            
            obj.hTrigged = uilamp(obj.hGrids.hTriggedGrid, ...
                'Tooltip', 'Trigged', ...
                'Color', '#A9A9A9');
            
            %% FFT Zoom Out Switch           
            obj.hFftZoomOut = uiswitch(obj.hGrids.hGridPanelTrig, 'toggle', ...
                'Items', { 'Zoom +', 'Zoom -' }, ...
                'ItemsData', [1 0], ...
                'Value', 1, ...
                'Visible', 'off', ...
                'Tooltip', 'FFT Zoom');
            obj.hFftZoomOut.Layout.Row = 1;
            obj.hFftZoomOut.Layout.Column = 5;
            
            %% Scope Elements
            obj.hAxes = uiaxes(obj.hGrids.hGridMain, ...
                'BackgroundColor', obj.bgColor, ...
                'GridAlphaMode', 'manual', ...
                'GridAlpha', 0.25, ...
                'MinorGridAlphaMode', 'manual', ...
                'MinorGridAlpha', 0.15, ...
                'XGrid', 'on', ...
                'YGrid', 'on', ...
                'XMinorGrid', 'on', ...
                'YMinorGrid', 'on', ...
                'XTickMode', 'manual', ...
                'YTickMode', 'manual', ...
                'XTickLabel', [], ...
                'YTickLabel', []);
            disableDefaultInteractivity(obj.hAxes);  
            obj.hAxes.XAxis.Exponent = 0;
            obj.hAxes.Layout.Row = [1 2];
            obj.hAxes.Layout.Column = 1;
            obj.hAxes.Toolbar.Visible = 'off';
            
            obj.hZeroLine = yline('Parent', obj.hAxes, 0, '-k', ...
                'Alpha', 0.25, ...
                'LineWidth', 1.0);
            obj.hLine = line('Parent', obj.hAxes, ...
                'Color', [0 0.4470 0.7410], ... 
                'LineWidth', 1.0, ...
                'XData', [], ...
                'YData', []);
            
            %% FPS Label
            obj.hFpsLabel = uilabel(obj.hGrids.hGridMain, ...
                'Text', '', ...
                'FontSize', 15, ...
                'FontName', 'Courier New', ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'top');
            obj.hFpsLabel.Layout.Row = 1;
            obj.hFpsLabel.Layout.Column = 1;
                
            %% Measure Label
            obj.hMeasureLabel = uilabel(obj.hGrids.hGridMain, ...
                'Text', '', ...
                'FontSize', 15, ...
                'FontName', 'Courier New', ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'top');
            obj.hMeasureLabel.Layout.Row = 1;
            obj.hMeasureLabel.Layout.Column = 1;

        end
    end
    
%% Abstract Methods
    methods (Abstract) % this method needs to be implemented in sub class
        enableDevControls(obj, value)
    end
end