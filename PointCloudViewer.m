classdef PointCloudViewer < matlab.System
    % Live point cloud viewer for Simulink
    % Inputs:
    %   xyz: [N x 3]
    %   pos: [3 x 1] detection point (use [NaN;NaN;NaN] to hide)

    properties
        PointSize (1,1) double = 3
        XLim (1,2) double = [0 60]
        YLim (1,2) double = [-30 30]
        ZLim (1,2) double = [-10 10]
        Decimate (1,1) double = 2
        ShowDetection (1,1) logical = true
    end

    properties(Access=private)
        Fig
        Ax
        Sc
        DetSc
        Txt
        FrameCount (1,1) uint32 = 0
    end

    methods(Access=protected)
        function setupImpl(obj)
            obj.Fig = figure('Name','Live Point Cloud','NumberTitle','off');
            obj.Ax = axes(obj.Fig);
            grid(obj.Ax,'on');
            view(obj.Ax,3);

            xlabel(obj.Ax,'N');
            ylabel(obj.Ax,'E');
            zlabel(obj.Ax,'D');

            xlim(obj.Ax, obj.XLim);
            ylim(obj.Ax, obj.YLim);
            zlim(obj.Ax, obj.ZLim);
            axis(obj.Ax,'equal');

            obj.Sc = scatter3(obj.Ax, NaN,NaN,NaN, obj.PointSize, '.');
            hold(obj.Ax,'on');
            obj.DetSc = scatter3(obj.Ax, NaN,NaN,NaN, 60, 'o', 'filled');
            hold(obj.Ax,'off');

            obj.Txt = title(obj.Ax,'Frame 0');
            drawnow;
        end

        function stepImpl(obj, xyz, nValid, pos)
        obj.FrameCount = obj.FrameCount + uint32(1);
    
        if isempty(xyz) || size(xyz,2) ~= 3
            return;
        end
    
        % Clamp nValid safely
        nv = double(nValid);
        if ~isfinite(nv) || nv < 0
            nv = 0;
        end
        if nv > size(xyz,1)
            nv = size(xyz,1);
        end
    
        if nv == 0
            set(obj.Sc, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
        else
            xyz = xyz(1:nv,:);
    
            % Remove NaNs/Infs (still useful if you later use NaN filler)
            good = isfinite(xyz(:,1)) & isfinite(xyz(:,2)) & isfinite(xyz(:,3));
            xyz = xyz(good,:);
    
            % Decimate for speed
            if obj.Decimate > 1 && size(xyz,1) > obj.Decimate
                xyz = xyz(1:obj.Decimate:end,:);
            end
    
            set(obj.Sc, 'XData', xyz(:,1), 'YData', xyz(:,2), 'ZData', xyz(:,3));
        end
    
        if obj.ShowDetection && numel(pos) == 3 && all(isfinite(pos(:)))
            set(obj.DetSc, 'XData', pos(1), 'YData', pos(2), 'ZData', pos(3), 'Visible', 'on');
        else
            set(obj.DetSc, 'Visible', 'off');
        end
    
        obj.Txt.String = sprintf('Frame %u', obj.FrameCount);
        drawnow limitrate;
    end

        function resetImpl(obj)
            obj.FrameCount = uint32(0);
        end

        function num = getNumInputsImpl(~)
        num = 3; % xyz, nValid, pos
    end

        function flag = isInputSizeMutableImpl(~,~)
            flag = true; % allow variable N for xyz
        end
    end
end