%{
EXAM_COLLISION_AVOIDANCE_RUNME

Description:
    This file demonstrates how to specify one of the own-ship trajectories
    and the corresponding baseball trajectory that will "collide" with ownship.
    The file is intended to show users how to specify a run from the
    ownship trajectory file and put the trajectory in the userStruct.  This
    demonstration is for running in simulink not for using an autocoded
    executable.

Input: None
Output: None
Dependencies: None
Details: Example script for the Collision Avoidance Challenge Problem running an
    example of the trajectories provided with BAM

Versions:
    2025-05-19: APP - moved to examples folder, with path changes
    2025-04-03: MJA - Initial script created. 
%}
%% Clean workspace
% remove workspace variables
clear userStruct
% clear command window
clc;

if ~any(contains({dir('*/').name}, 'setup'))
    error('BAM Error: Move example files into root directory for execution.');
end
if ~any(contains({dir().name}, 'ChallengeProblem'))
    error('BAM Error: Cannot find ChallengeProblem directory.');
end

plot_flag = 0; % plot_flag == 0 => perform setup only (user run in simulink)
               % plot_flag == 1 => perform setup, run sim and plot trajectories

% ************************************************************************
% If ROS2 publishing is to be utilized that must uncomment the userStruct 
% variant line below to utilize the ROS2 variant subsystem:

userStruct.variants.pubType = 1; % 1=>Default, no ROS2 publishing used
userStruct.variants.refInputTypeBball=2; % 2=> use BEZ bball ref trajectory
userStruct.variants.pubTypeBball=1; % 2=> publish bball pose via ROS2 msg

% NOTE: in order to use the ROS2 publishing variant, users must make sure
% that MATLAB has access to ROS2.  In order to do this on windows, use a
% developers cmd prompt (i.e. MS Visual Studio Community 2022). A standard
% command window in Windows won't work. The following instructions are for
% when ROS2 is installed on the machine)
% 1) Source ros in the and source developer command: > call
%   C:/ros2_humble/setup.bat
% 2) Call matlab from this command prompt:
%   C:/..your_path_to_matlab../bin/matlab
% 3) Now in Matlab command line verify that Matlab environment has access to ros2
%   >> ! ros2
%   This should result in ros2 help information, not an error message that
%   "ros2" is not a recognized internal or external command
% 4) Then uncomment the userStruct.variants.pubType = 2; variant line in
%   this script and run this m-file
% 5) To verify that ROS2 publishing messages are going out, then open a new
%   developers command prompt, and source ROS2 as in step one above.  Then
%   in this command window type: 
%   >ros2 topic echo /pub_pose
%   With the matlab simulation running, you should see the ROS2 messages
%   echoed.  Note if you don't use Matlab simulation pacing to real time
%   then some ROS2 messages may get missed.
% ************************************************************************


%% User Selected Parameters - userStruct
% If no custom values are provided, all user-modifiable parameters within 
% userStruct default to their initial settings. The file setup.m fully 
% populates userStruct, allowing you to identify which parameters can be 
% adjusted. Ensure that only information relevant to modifying the 
% simulation is included in userStruct.
%
% userStruct stores pre-setup values that guide simulation configuration. 
% These values are preferable to post-setup modifications, as they enable 
% computations necessary for aircraft setup, like using initial velocity 
% to determine vehicle pitch angle.

model_name = 'BAM'; % Define slx model name to run

% Specify the desired own-ship trajectory and the baseball trajectory
% numbers to execute in simulation and initialize the userStruct with their
% BP waypoints.
own_traj_num = 4; % Select desired own-ship traj number
bball_traj_num = 4; % Select desired bball traj number

% Load the ownship reference trajectory of interest
file_obj = matfile(['ChallengeProblem' filesep 'ref_trajectory_data.mat']); %
wptsX_cell      = file_obj.own_traj(own_traj_num,1);
wptsY_cell      = file_obj.own_traj(own_traj_num,2);
wptsZ_cell      = file_obj.own_traj(own_traj_num,3);
time_wptsX_cell = file_obj.own_traj(own_traj_num,4);
time_wptsY_cell = file_obj.own_traj(own_traj_num,5);
time_wptsZ_cell = file_obj.own_traj(own_traj_num,6);

% Set the own-ship traj information in userStruct
userStruct.simulation_defaults.RefInputs.waypointsX = wptsX_cell{1};
userStruct.simulation_defaults.RefInputs.waypointsY = wptsY_cell{1};
userStruct.simulation_defaults.RefInputs.waypointsZ = wptsZ_cell{1};
userStruct.simulation_defaults.RefInputs.time_wptsX = time_wptsX_cell{1};
userStruct.simulation_defaults.RefInputs.time_wptsY = time_wptsY_cell{1};
userStruct.simulation_defaults.RefInputs.time_wptsZ = time_wptsZ_cell{1}; 

% Set the sim stop time to the last time of the BP
userStruct.model_params.stop_time = time_wptsX_cell{1}(end);

% Load the baseball trajectory of interest
file_obj = matfile(['ChallengeProblem' filesep 'bball_trajectory_data.mat']);
wptsX_cell      = file_obj.bball_traj(bball_traj_num,1);
wptsY_cell      = file_obj.bball_traj(bball_traj_num,2);
wptsZ_cell      = file_obj.bball_traj(bball_traj_num,3);
time_wptsX_cell = file_obj.bball_traj(bball_traj_num,4);
time_wptsY_cell = file_obj.bball_traj(bball_traj_num,5);
time_wptsZ_cell = file_obj.bball_traj(bball_traj_num,6);

% Set the own-ship traj information in userStruct
userStruct.simulation_defaults.RefInputsBball.waypointsX = wptsX_cell{1};
userStruct.simulation_defaults.RefInputsBball.waypointsY = wptsY_cell{1};
userStruct.simulation_defaults.RefInputsBball.waypointsZ = wptsZ_cell{1};
userStruct.simulation_defaults.RefInputsBball.time_wptsX = time_wptsX_cell{1};
userStruct.simulation_defaults.RefInputsBball.time_wptsY = time_wptsY_cell{1};
userStruct.simulation_defaults.RefInputsBball.time_wptsZ = time_wptsZ_cell{1}; 

%% Setup Model

% setup must be run again after userStruct input is specified..
% setup is in the BAM top level folder, so call it from there if currently
% in the ChallengeProblem directory
setup;

%% =====================================================================
% EKF Initial State Seeding
% =====================================================================
% Problem: The EKF block inside "Ball is Moving" initializes its internal
% state to [0;0;0;0;0;0] by default. When the action subsystem activates
% (ball detected), the EKF sees measurements at the ball's actual position
% but its state is at the origin. This causes a large innovation spike on
% the first timestep, producing a transient from 0 -> actual position that
% takes several samples to settle. Downstream, buildTraj's velocity
% estimator interprets this jump as an enormous velocity, causing wildly
% wrong trajectory predictions.
%
% Fix: Compute the ball's position at its launch time from the Bernstein
% polynomial waypoints and set the EKF's initial state to that position.
% This way, when "Ball is Moving" first activates, the EKF starts at (or
% very near) the ball's actual position, and the first innovation is just
% the measurement noise — not a 90-meter jump.
%
% Note: We set initial velocity to [0;0;0] because we don't have a good
% velocity estimate at launch. The EKF will converge to the true velocity
% within a few samples, and the startup guard in buildTraj suppresses
% velocity estimation during this window anyway.
% =====================================================================

% Build the baseball piecewise Bernstein polynomial curve
bball_pwcurve_setup = genPWCurve( ...
    {wptsX_cell{1}, wptsY_cell{1}, wptsZ_cell{1}}, ...
    {time_wptsX_cell{1}, time_wptsY_cell{1}, time_wptsZ_cell{1}});

% The ball's flight starts at the first time waypoint
bball_t_launch = time_wptsX_cell{1}(1);

% Evaluate the ball's position at launch time
% evalPWCurve returns [1x3] row vector: [x, y, z]
% The 0 argument requests position (0th derivative)
bb_launch_pos = evalPWCurve(bball_pwcurve_setup, bball_t_launch, 0);

% Also get launch velocity (1st derivative) for a better initial estimate
% This helps the EKF converge faster, especially at high noise levels
bb_launch_vel = evalPWCurve(bball_pwcurve_setup, bball_t_launch, 1);

% Assemble EKF initial state: [pos_x; pos_y; pos_z; vel_x; vel_y; vel_z]
% NOTE: Check whether your EKF state vector is 6-element [pos; vel] or
% includes additional states (e.g., acceleration). Pad with zeros if needed.
ekf_x0 = [bb_launch_pos(:); bb_launch_vel(:)]';

fprintf('EKF initial state seeded to ball launch position:\n');
fprintf('  Position: [%.2f, %.2f, %.2f] m\n', bb_launch_pos(1), bb_launch_pos(2), bb_launch_pos(3));
fprintf('  Velocity: [%.2f, %.2f, %.2f] m/s\n', bb_launch_vel(1), bb_launch_vel(2), bb_launch_vel(3));

%% =====================================================================
% Set the EKF block's initial state parameter
% =====================================================================
% IMPORTANT: The exact parameter name depends on which EKF block you're
% using. To find the correct parameter name, run:
%
%   get_param('<EKF_block_path>', 'DialogParameters')
%
% Common parameter names:
%   Simulink Extended Kalman Filter block: 'InitialState' or 'x0'
%   Custom MATLAB Function EKF:           check your implementation
%   Simulink EKF block from System ID:    'InitialStates'
%
% Uncomment and adjust the path below to match your model. The path
% should be the full path to the EKF block inside "Ball is Moving".
% You may need to open BAM.slx and right-click the EKF block -> 
% "Copy Block Path" to get the exact path string.
% =====================================================================

% --- UNCOMMENT AND ADJUST THIS PATH ---
EKF_BLOCK_PATH = 'BAM/BAM Controller/Avoidance Planner/Ball is Moving/EKF';

% Discover available parameters (run once to find the right name):
% disp(get_param(EKF_BLOCK_PATH, 'DialogParameters'));

set_param(EKF_BLOCK_PATH, 'InitialState', mat2str(ekf_x0));
fprintf('EKF block initial state set successfully.\n');
% --- END UNCOMMENT BLOCK ---


%% Exit if setup only
if plot_flag==0
    return;
end

%% Post-Setup Processing 
% During development, it is often convenient to directly change the
% parameters of the simulation after setup. This can lead to problems, and
% conflicts with related or interconnected variables that will need to be
% identified and added to the setup process before inclusion in userStruct.
%
% Also note, this will not modify SimPar which is used for compiled models.

% change initial position
% SimIn.IC.Pos_bii = [0; 0; 10]; 


%% Run Simulation
% load_system(model_name);  % load without graphic interface for running
open_system(model_name);  % load with graphics for monitoring or editing
simout = sim(model_name); % run simulation

%% Post Run Processing
% Process post-run simulation varaibles, plot and save data.
close all

% Create a pw Bernstein polynomial curve for the baseball
bball_pwcurve = genPWCurve( ...
    [wptsX_cell, wptsY_cell, wptsZ_cell], ...
    [time_wptsX_cell, time_wptsY_cell, time_wptsZ_cell]);

out_fpath = sprintf('./ChallengeProblem/Chal_Prob_Plots/Exam_CA_Traj%i/', ...
                    own_traj_num);
if ~exist(out_fpath, 'dir')
    mkdir(out_fpath)
end

plot_trajectories(simout.logsout, bball_pwcurve, save_dir=out_fpath);
plot_multirotor_states(simout.logsout, save_dir=out_fpath);
