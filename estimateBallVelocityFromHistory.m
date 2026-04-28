function [vel_est] = estimateBallVelocityFromHistory(pos_now, t_now, opts)
% estimateBallVelocityFromHistory
% Estimate baseball velocity from recent position history instead of trusting
% xhat(4:6). This is useful when the EKF state velocity is not being updated.
%
% Inputs
%   pos_now : 3x1 or 1x3 current ball position [x;y;z]
%   t_now   : scalar current time in seconds
%   opts    : optional struct:
%       opts.N_hist       = number of recent samples to keep, default 10
%       opts.speed_clip   = componentwise velocity clip in m/s, default 60
%       opts.use_polyfit  = true uses linear fit over history, default true
%       opts.reset        = true clears persistent history, default false
%
% Outputs
%   vel_est : 3x1 estimated velocity [vx;vy;vz]
%   debug   : struct containing posHist, timeHist, and method
%             currently removed (more issues than solutions

persistent posHist timeHist

opts.N_hist = 10; 
opts.speed_clip = 60; 
opts.use_polyfit = true; 

% if opts.reset
%     posHist = [];
%     timeHist = [];
% end

pos_now = pos_now(:);

coder.varsize('posHist', [3 opts.N_hist], [0 1]);
coder.varsize('timeHist', [1 opts.N_hist], [0 1]);

if numel(pos_now) ~= 3
    error('pos_now must have exactly 3 elements: [x; y; z].');
end

if isempty(posHist)
    posHist = pos_now;
    timeHist = t_now;
    vel_est = zeros(3,1);
    % debug = makeDebug(posHist, timeHist, 'initialized');
    return
end

% Avoid duplicate time samples, which can break slope estimates.
if ~isempty(timeHist) && t_now <= timeHist(end)
    vel_est = zeros(3,1);
	
	if size(posHist, 2) >= 2
	    dt = timeHist(end) - timeHist(1);
		if dt > 0
	        vel_est = (posHist(:, end) - posHist(:, 1)) / dt;
		end
	end
	
	vel_est = clipVelocity(vel_est, opts.speed_clip);
	% debug = makeDebug(posHist, timeHist, 'duplicate_or_nonmonotonic_time');
	return
end

% history update logic
if size(posHist,2) < opts.N_hist
	posHist = [posHist, pos_now];
	timeHist = [timeHist, t_now];
else
	% history is full, drop oldest and append newest
	posHist = [posHist(:, 2:end), pos_now];
	timeHist = [timeHist(2:end), t_now];
end

if size(posHist,2) == 1
    vel_est = zeros(3,1);
    % debug = makeDebug(posHist, timeHist, 'initialized');
    return
end

vel_est = zeros(3,1);
method = 'not_enough_samples';

if numel(timeHist) >= 3 && opts.use_polyfit
    % Fit x(t), y(t), z(t) with straight lines over recent history.
    % The slope of each line is the corresponding velocity component.
    tt = timeHist(:) - timeHist(end);

    % x, y: linear
    for j = 1:2
        p = polyfit(tt, posHist(j,:).', 1);
        vel_est(j) = p(1);
    end

    % z: quadratic
    pz = polyfit(tt, posHist(3,:).', 2);
    dpz = polyder(pz);
    vel_est(3) = polyval(dpz, 0);

    % for j = 1:3
    %     p = polyfit(tt, posHist(j,:).', 1);
    %     vel_est(j) = p(1);
    % end

    method = 'polyfit_recent_history';

elseif numel(timeHist) >= 2
    dt = timeHist(end) - timeHist(1);

    if dt > 0
        vel_est = (posHist(:,end) - posHist(:,1)) / dt;
        method = 'secant_recent_history';
    end
end

vel_est = clipVelocity(vel_est, opts.speed_clip);
% debug = makeDebug(posHist, timeHist, method);

end

function v = clipVelocity(v, speed_clip)
if ~isempty(speed_clip) && isfinite(speed_clip) && speed_clip > 0
    v = max(min(v, speed_clip), -speed_clip);
end
end

% function [debug_posHist, debug_timeHist, debug_method, debug_numSamples] = makeDebug(posHist, timeHist, method)
% debug_posHist = posHist;
% debug_timeHist = timeHist;
% debug_method = method;
% debug_numSamples = numel(timeHist);
% end
