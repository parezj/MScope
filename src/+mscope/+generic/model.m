classdef model < handle 
%mscope.generic.model - this is the main buffer for the scope. can exist 
%without controller or model, therefore doesnt have any handles or relation 
%to them. from the outside it looks simple: buffer write is property setter 
%and buffer read is simple method, but from the inside its more complex. 
%basically, its circular buffer, overwriting old samples from left to right. 
%
% writing to buffer:
%    is pretty straightforward, either fits all samples or split them,
%    keeping currPos (first valid data pointer), newDataLen (sum of
%    new data, that was not display yet), datLen (last size of written data)
%    bufferMaxLen must be larger then single write data length. 
%
% reading from buffer:
% 1. get last and first pointer (index) as start and end of display window
% 2. if trigger enabled (trigVal is not nan), traverse back from firstPos
%    trying to find trigged value, limiting to windowLen
%    - if found, change first and last pointers - firstPos / currPos
% 3. get solid piece of data of size windowLen based on pointers
% 4. advance display pointer (windowPos) based on newDataLen. this needs
%    to be done, because of sync between write (record) and read (display)
% 5. transform the solid piece of data based on conditions:
%    a. trigger mode enabled
%       -> the most simple. display data from start to end (1:windowLen)
%    b. windowLen is smaller then single buffer write
%       -> display data from end to end-windowLen (end-windowLen+1:end)
%    c. windowLen is larger then single buffer write
%       -> the most complicated. data needs to be sliced to simulate the
%          movement in time. windowPos is the key to it.
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    14.5.2020
% --------------------------

%% Private Properties    
    properties (Access = private)
        bufferMaxLen = 1        % buffer total allocated size
        dataLen = 0             % last buffer data write length
        newDataLen = 0          % new data count, didnt display yet
        
        currPos = 1             % next buffer write pointer
        windowPos = 1           % next display window write pointer
    
        privIsTrigged = false   % indicate if trigger is active
        privBuffer              % circular main data buffer
        privBufferEmpty = true  % true if buffer empty
        privError = []          % last error string
        
        mtxTimeout = 1          % spin lock timeout
        mtx                     % spin lock instance
    end
    
%% Public Setters & Getters    
    properties (Dependent)
        buffer                  % privBuffer set
        bufferEmpty             % privBufferEmpty get
        isTrigged               % privIsTrigged get
        lastError               % get privError and clear it
    end
    
%% Public Methods 
    methods % (Access = public) 
        %% constructor
        function obj = model()
        end
        
        %% init buffer
        function init(obj, bufferMaxLen, mtxTimeout)
            assert(nargin > 2)
            obj.bufferMaxLen = bufferMaxLen;             % set max len
            obj.privBuffer = nan(1, obj.bufferMaxLen);   % init array
            obj.mtx = mscope.utility.spinlock();         % create mutex
            obj.mtxTimeout = mtxTimeout;                 % set mtx timeout
        end
        
        %% reset buffer
        function reset(obj)
            obj.privBuffer(1:obj.bufferMaxLen) = nan;
            obj.currPos = 1;
        end
        
        %% buffer setter - write data into circular buffer
        % data : IN - monolithic piece of data to insert into circ buff
        % =============================================================
        function set.buffer(obj, data)
            if ~isempty(data)   
                %% wait for free mutex and then lock. if timeout, return
                %if ~obj.mtx.lock(obj.mtxTimeout)
                %    obj.privError = "write - spinlock timeout (" + obj.mtxTimeout + " s)";
                %    return;
                %end

                try
                    %% get data len and offset from end
                    obj.dataLen = length(data);
                    endOffset = obj.bufferMaxLen - obj.currPos + 1;

                    %% write data
                    % usually, buffer is larger than input data len
                    if obj.dataLen < obj.bufferMaxLen
                       
                        if endOffset >= obj.dataLen        % data fits buffer
                            nextIdx = obj.currPos + obj.dataLen;
                            obj.privBuffer(obj.currPos:nextIdx - 1) = data;
                            if nextIdx > obj.bufferMaxLen  % +1 -> accurate fit, rewind
                                obj.currPos = 1;
                            else                           % advance currPos
                                obj.currPos = nextIdx;
                            end
                        else                               % need to be splitted
                            remainLen = obj.dataLen - endOffset;
                            obj.privBuffer(obj.currPos:obj.bufferMaxLen) = ...
                                data(1:endOffset);
                            
                            obj.privBuffer(1:remainLen) = data(endOffset+1:end);
                            obj.currPos = remainLen;
                        end 
                    else % in case of buffer smaller than input data len
                        obj.currPos = 1;
                        obj.privBuffer(1:obj.bufferMaxLen) = data(1:obj.bufferMaxLen);
                    end
                    
                    %% accumulate written data len
                    obj.newDataLen = obj.newDataLen + obj.dataLen;
                    obj.privBufferEmpty = false;
                    
                catch ex
                    disp("buffer write error: " + getReport(ex));
                end
                
                %obj.mtx.unlock(); % unlock mutex
            end
        end
        
        %% buffer read - get transformed data from circular buffer
        % buff      : OUT []   - output monolithic piece of data to be displayed
        % windowLen : IN  int  - number of points to be dispayed
        % delay     : IN  int  - number samples to go back in time
        % rmDiscont : IN  bool - remove discontinuities when overwriting signal
        % trigVal   : IN  int  - if nan, trig is off, else, try to trigger
        % trigMode  : IN  int  - 0 is rising, 1 is falling
        % hScaler   : IN  int  - scaling how far back to go to find trigger
        % ====================================================================================
        function buff = getBuffer(obj, windowLen, delay, rmDiscont, trigVal, trigMode, hScaler)
            buff = [];
            assert(nargin > 6);
            
            %% wait for free mutex and then lock. if timeout, return
            %if ~obj.mtx.lock(obj.mtxTimeout)
            %    obj.privError = "read - spinlock timeout (" + obj.mtxTimeout + " s)";
            %    return;
            %end
            
            obj.privIsTrigged = false;
            %% check if buffer empty
            if obj.privBufferEmpty == true
                buff = [];
                obj.mutex = false;
                return;
            end
            
            try                                                                  
                %% first, get index of first data from circullar buffer
                firstIdx = obj.currPos - windowLen;
                if firstIdx < 1
                    firstIdx = obj.bufferMaxLen + firstIdx;
                end
                
                %% next, if trigger mode, try to move back and find trig index
                if ~isnan(trigVal)     
                    trigCnt = windowLen * hScaler; % limit searching for window len
                    if windowLen < 5000 % dont limit it too much
                        trigCnt = 5000;
                    end
                    prevVal = obj.privBuffer(firstIdx); % save prev val
                    dif = firstIdx - trigCnt;
                    it = firstIdx:-1:firstIdx-trigCnt;  % get iterator
                    if dif < 1
                        it = [firstIdx:-1:1 obj.bufferMaxLen:-1:dif]; % join intervals
                    end
                    for x = it
                        if obj.checkTrigger(obj.privBuffer(x), prevVal, trigVal, trigMode)
                            firstIdx = x; 
                            obj.privIsTrigged = true;   % trigged
                            break;
                        end
                        
                        if trigCnt > 0                  % keep searching
                            trigCnt = trigCnt - 1;
                        else                            % timeout
                            break;
                        end
                        prevVal = obj.privBuffer(x);    % save prev val
                    end
                end 
                           
                %% then, get solid piece of data, that fits windowLen
                currPos2 = firstIdx + windowLen + ceil(delay);
                if currPos2 > obj.bufferMaxLen
                    currPos2 = currPos2 - obj.bufferMaxLen; % get last real index
                end
                firstIdx = currPos2 - windowLen; % get first index again
                if firstIdx < 1 % needs to be splitted and joined
                    buff = [obj.privBuffer(end+firstIdx:end) obj.privBuffer(1:currPos2 - 1)];
                else            % fits well
                    buff = obj.privBuffer(firstIdx:currPos2 - 1); 
                end
                
                %% next, advance display pointer
                obj.windowPos = obj.windowPos + obj.newDataLen;
                obj.newDataLen = 0;
                if obj.windowPos > windowLen
                    obj.windowPos = obj.windowPos - windowLen;
                    if obj.windowPos > windowLen
                        obj.windowPos = mod(obj.windowPos, windowLen);
                    end
                end
                
                %% last, transform buffer to match windowLen and display mode
                if obj.privIsTrigged == true % if trigged, display from start
                    buff = buff(1:windowLen);
                % window smaller then single buffer write, display from end
                elseif obj.dataLen > windowLen || obj.privIsTrigged == true
                    buff = buff(end-windowLen+1:end);
                % window is larger, need to slice it, to simulate movement
                elseif obj.dataLen < windowLen 
                    buff = [buff(end-obj.windowPos+2:end) buff(1:end-obj.windowPos+1)];
                    buff = buff(1:windowLen); % check that we have correct length
                    if rmDiscont == true && obj.windowPos > 0
                        buff(obj.windowPos) = nan; % separate discontinuity
                    end
                end

            catch ex
                disp("buffer read error: " + getReport(ex));
            end
                        
            %obj.mtx.unlock(); % unlock mutex
        end
        
        %% bufferEmpty getter
        function val = get.bufferEmpty(obj)
            val = obj.privBufferEmpty;
        end
                
        %% isTrigged getter
        function val = get.isTrigged(obj)
            val = obj.privIsTrigged;
        end
        
        %% privError getter
        function val = get.lastError(obj)
            val = obj.privError;
            obj.privError = [];
        end
        
    end
    
    %% Private Methods
    methods (Access = private)
        function trigged = checkTrigger(~, currVal, prevVal, trigVal, trigMode)
            trigged = false;
            if ((prevVal <= trigVal && currVal >= trigVal) && trigMode == 1) || ...
               ((prevVal >= trigVal && currVal <= trigVal) && trigMode == 0)
           
                trigged = true;
            end
        end
    end
end