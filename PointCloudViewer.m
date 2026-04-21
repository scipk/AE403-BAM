 classdef PointCloudViewer < matlab.System
    properties
        XLimits = [-100 100];
        YLimits = [-100 100];
        ZLimits = [-20 20];
    end

    properties(Access = private)
        viewer
        stepCount = 0
    end

    methods(Access = protected)
        function setupImpl(obj, xyz)
            obj.viewer = pcplayer(obj.XLimits, obj.YLimits, obj.ZLimits);
            xlabel(obj.viewer.Axes, 'X');
            ylabel(obj.viewer.Axes, 'Y');
            zlabel(obj.viewer.Axes, 'Z');
            title(obj.viewer.Axes, 'Live LiDAR Point Cloud');
        end

        function stepImpl(obj, xyz)
            obj.stepCount = obj.stepCount + 1;

            if isempty(xyz)
                if mod(obj.stepCount, 20) == 0
                    disp('PointCloudViewer: xyz is empty');
                end
                return;
            end

            % Handle both [N x 3] and [M x N x 3]
            if ndims(xyz) == 3
                xyz = reshape(xyz, [], 3);
            elseif size(xyz,2) ~= 3 && size(xyz,1) == 3
                xyz = xyz.';
            end

            valid = all(isfinite(xyz), 2);
            xyz = xyz(valid, :);

            if isempty(xyz)
                if mod(obj.stepCount, 20) == 0
                    disp('PointCloudViewer: xyz has no valid points');
                end
                return;
            end

            if mod(obj.stepCount, 20) == 0
                fprintf('PointCloudViewer: showing %d points\n', size(xyz,1));
            end

            ptCloud = pointCloud(xyz);
            view(obj.viewer, ptCloud);
            drawnow limitrate;
        end

        function releaseImpl(obj)
            obj.viewer = [];
        end

        function num = getNumInputsImpl(~)
            num = 1;
        end

        function num = getNumOutputsImpl(~)
            num = 0;
        end

        function flag = isInputSizeMutableImpl(~,~)
            flag = true;
        end

        function flag = isInputComplexityMutableImpl(~,~)
            flag = false;
        end

        function simMode = getSimulateUsingImpl(~)
            simMode = "Interpreted execution";
        end

        function show = showSimulateUsingImpl(~)
            show = true;
        end
    end
end
