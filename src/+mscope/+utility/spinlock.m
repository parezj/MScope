classdef spinlock < handle
%mscope.utility.spinlock - class implementing simple mutual exclusion by 
%spinning lock, this can be a little bit cpu intensive, but effective, 
%and the only way, when semaphores are not availabe without java stuff
% --------------------------
% Author:  Jakub Parez
% Project: CTU/MTB - MScope
% Date:    19.5.2020
% --------------------------
%% Private Properties    
    properties (SetAccess = private, GetAccess = public)     
        locked = false  % state 
    end
        
%% Public Methods 
    methods % (Access = public) 
        function obj = spinlock()
        end
        
        %% wait for unlocked state, then lock (timeout <= 0, waits forever)
        function ok = lock(obj, timeoutSec)
            tStart = tic;
            while obj.locked
                %disp("timeout: " + timeoutSec);
                %disp("now: " + toc(tStart));
                %disp(" ");
                if timeoutSec > 0 && toc(tStart) >= timeoutSec
                    ok = false;
                    return;
                end
                pause(0.01)
            end
            obj.locked = true;
            ok = true;
        end
        
        %% returns ok, if state is changed from locked to unlocked
        function ok = unlock(obj)
            if obj.locked
                obj.locked = false;
                ok = true;
            else
                ok = false;
            end
        end
    end
end