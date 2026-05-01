%{
EBK_AVOIDANCE.m

Description:
    Batch testing script for the AE403W Autonomous Collision Avoidance
    senior design project. Runs N near-collision trajectory pairs from the
    BAM Challenge Problem data sets, records avoidance performance, and
    generates aggregate figures suitable for a final presentation.

    Supports two modes:
      MODE 1 -- BATCH: Run many trajectory pairs sequentially (or in
               parallel via parsim), collect statistics, generate
               aggregate performance plots.
      MODE 2 -- DEMO: Run a single trajectory pair with ROS2 publishing
               enabled for real-time Unreal Engine visualization.

Instructions:
    1. Set MATLAB current folder to the BAM root directory
    2. Configure the settings in the CONFIGURATION section below
    3. Run:  >> batch_avoidance_test

Team: SDSU AE403W - Elite Ball Knowledge (EBK)
Date: April 2026
%}

%% ========================================================================
%  CONFIGURATION - EDIT THIS SECTION
%  ========================================================================
clear userStruct; clc; close all;

% ---- RUN MODE -----------------------------------------------------------
%   'batch' = Run N trajectory pairs sequentially, generate statistics
%   'demo'  = Run ONE pair with ROS2 + Unreal Engine visualization
run_mode = 'batch';

% ---- BATCH SETTINGS (only used when run_mode = 'batch') -----------------
N_runs      = 3;       % Number of trajectory pairs to run (max 3000)
start_pair  = 2;        % First trajectory pair index
use_parsim  = false;    % true = use parsim (Parallel Computing Toolbox)
                        % false = sequential for loop (more reliable)

% ---- DEMO SETTINGS  -----------------------------------------------------
demo_own_traj  = 64;       % Own-ship trajectory number for Unreal demo
demo_bball_traj = 64;      % Baseball trajectory number for Unreal demo

% ---- AVOIDANCE SETTINGS ------------------------------------------------
R_safe = 3.0;           % Safety radius the same as in Avoidance Controller 
                        % (meters)

% ---- OUTPUT SETTINGS ----------------------------------------------------
save_figures  = true;
out_dir       = './ChallengeProblem/Chal_Prob_Plots/BatchResults/';
model_name    = 'BAM';

%% ========================================================================
%  LOAD TRAJECTORY DATA (COMMON TO BOTH MODES)
%  ========================================================================
fprintf('\n==============================================\n');
fprintf('  AE403W Collision Avoidance - %s mode\n', upper(run_mode));
fprintf('==============================================\n\n');

file_obj_own  = matfile(['ChallengeProblem' filesep 'ref_trajectory_data.mat']);
file_obj_bb   = matfile(['ChallengeProblem' filesep 'bball_trajectory_data.mat']);

if save_figures && ~exist(out_dir, 'dir')
    mkdir(out_dir);
end % Makes the BatchResults directory if it doesn't exist

%% ========================================================================
%  MODE SELECTION
%  ========================================================================
if strcmpi(run_mode, 'demo')
    %% ====================================================================
    %  DEMO MODE - Single run with ROS2 + Unreal Engine
    %  ====================================================================
    fprintf('Running DEMO mode: Trajectory pair %d/%d with ROS2\n', ...
        demo_own_traj, demo_bball_traj);
    fprintf('*** Ensure Unreal Engine + Bam2Airsim are running ***\n\n');

    % --- Configure userStruct for ROS2 ---
    userStruct.variants.pubType           = 2;  % ROS2 publishing ON
    userStruct.variants.refInputTypeBball = 2;  % Bernstein baseball traj
    userStruct.variants.pubTypeBball      = 2;  % ROS2 baseball publishing ON

    % --- Load trajectory pair ---
    [userStruct, wptsX_cell, wptsY_cell, wptsZ_cell, ...
     time_wptsX_cell, time_wptsY_cell, time_wptsZ_cell, ...
     bb_wptsX_cell, bb_wptsY_cell, bb_wptsZ_cell, ...
     bb_time_wptsX_cell, bb_time_wptsY_cell, bb_time_wptsZ_cell] = ...
        load_trajectory_pair(userStruct, file_obj_own, file_obj_bb, ...
                             demo_own_traj, demo_bball_traj);

    % --- Setup and Run ---
    setup;
    open_system(model_name);
    simout = sim(model_name);
    fprintf('Demo simulation complete.\n');

    % --- Generate per-trajectory plots ---
    bball_pwcurve = genPWCurve( ...
        [bb_wptsX_cell, bb_wptsY_cell, bb_wptsZ_cell], ...
        [bb_time_wptsX_cell, bb_time_wptsY_cell, bb_time_wptsZ_cell]);

    demo_out_dir = fullfile(out_dir, sprintf('Demo_Traj%d_%d/', ...
                            demo_own_traj, demo_bball_traj));
    if ~exist(demo_out_dir, 'dir'), mkdir(demo_out_dir); end

    plot_trajectories(simout.logsout, bball_pwcurve, save_dir=demo_out_dir);
    plot_multirotor_states(simout.logsout, save_dir=demo_out_dir);

    % --- Compute and display miss distance ---
    [min_dist, t_cpa] = compute_miss_distance(simout, bball_pwcurve);
    fprintf('\n--- DEMO RESULTS ---\n');
    fprintf('  Min distance:  %.3f m\n', min_dist);
    fprintf('  Time of CPA:   %.3f s\n', t_cpa);
    if min_dist > R_safe
        fprintf('  Result:  COLLISION AVOIDED\n');
    else
        fprintf('  Result:  COLLISION / NEAR-MISS\n');
    end
    fprintf('  Plots saved to: %s\n\n', demo_out_dir);

    return;  % Exit - demo mode complete
end

%% ========================================================================
%  BATCH MODE - Run N trajectory pairs, collect statistics
%  ========================================================================
traj_indices = start_pair : (start_pair + N_runs - 1);
fprintf('Running BATCH: %d trajectory pairs (%d to %d)\n\n', ...
    N_runs, traj_indices(1), traj_indices(end));

% --- Preallocate results ---
results = struct();
results.traj_num      = traj_indices(:);
results.min_dist      = NaN(N_runs, 1);
results.t_cpa         = NaN(N_runs, 1);
results.avoided       = false(N_runs, 1);
results.sim_time      = NaN(N_runs, 1);
results.errored       = false(N_runs, 1);
results.logsout_data  = cell(N_runs, 1);
results.bball_pw_data = cell(N_runs, 1);

% --- Configure for batch (NO ROS2) ---
batch_userStruct.variants.pubType           = 1;  % No ROS2
batch_userStruct.variants.refInputTypeBball = 2;  % Bernstein baseball traj
batch_userStruct.variants.pubTypeBball      = 1;  % No ROS2 baseball

% --- Load model and pre-compile ONCE before the loop -------------------
% Run full setup exactly once so that environment, vehicle, FCS, variants,
% buses, paths, etc. are all configured. Only trajectory-dependent steps
% (ref inputs, baseball inputs, ICs, params) need to re-run per iteration.
fprintf('Loading model and building target (one-time) ... \n');
build_tic = tic;

userStruct = batch_userStruct;
[userStruct, ~, ~, ~, ~, ~, ~, ...
 ~, ~, ~, ~, ~, ~] = ...
    load_trajectory_pair(userStruct, file_obj_own, file_obj_bb, ...
                         traj_indices(1), traj_indices(1));
assignin('base', 'userStruct', userStruct);
evalin('base', 'setup;');
[~, model_name, ~] = fileparts(model_name);  % setup may append .slx

load_system(model_name);

EKF_BLOCK_PATH = 'BAM/BAM Controller/Avoidance Planner/Ball is Moving/EKF';

set_param(model_name, 'SimulationMode', 'normal');

% --- Warm-up: burn first-call initialization with a throwaway sim -------
fprintf('Warming up model (first-call init)... ');
warmup_stop = get_param(model_name, 'StopTime');
set_param(model_name, 'StopTime', '0.01');
sim(model_name);
set_param(model_name, 'StopTime', warmup_stop);
fprintf('done.\n');

% Save the fully-populated userStruct as the per-run template.
full_userStruct = userStruct;

fprintf('done [%.1f s]\n\n', toc(build_tic));

% --- Batch timer ---
batch_tic = tic;

for run_idx = 1:N_runs
    pair_num = traj_indices(run_idx);
    run_tic  = tic;

    fprintf('[%3d/%3d] Trajectory pair %d ... ', run_idx, N_runs, pair_num);

    try
        % --- Reset per-run variables but keep a clean userStruct template ---
        clear SimPar simout
        userStruct = full_userStruct;

        % --- Load trajectory pair ---
        [userStruct, ~, ~, ~, ~, ~, ~, ...
         bb_wptsX_cell, bb_wptsY_cell, bb_wptsZ_cell, ...
         bb_time_wptsX_cell, bb_time_wptsY_cell, bb_time_wptsZ_cell] = ...
            load_trajectory_pair(userStruct, file_obj_own, file_obj_bb, ...
                                 pair_num, pair_num);

        % --- Only re-run trajectory-dependent setup steps ---------------
        % Everything else (environment, vehicle, FCS, variants, buses,
        % units, paths) is identical across runs and was set once above.
        SimIn = setupRefInputs(SimIn, userStruct);
        SimIn = setupBballRefInputs(SimIn, userStruct);
        SimIn = setupIC(SimIn, userStruct);
        [SimIn, SimPar] = setupParams(SimIn, userStruct);

        % --- Seed EKF initial state to ball launch position/velocity ----
        bball_pwcurve = genPWCurve( ...
            [bb_wptsX_cell, bb_wptsY_cell, bb_wptsZ_cell], ...
            [bb_time_wptsX_cell, bb_time_wptsY_cell, bb_time_wptsZ_cell]);

        bball_t_launch = bb_time_wptsX_cell{1}(1);
        bb_launch_pos  = evalPWCurve(bball_pwcurve, bball_t_launch, 0);
        bb_launch_vel  = evalPWCurve(bball_pwcurve, bball_t_launch, 1);
        ekf_x0 = [bb_launch_pos(:); bb_launch_vel(:)]';

        % --- Build per-run SimulationInput (no set_param dirtying) ------
        simIn = Simulink.SimulationInput(model_name);
        simIn = simIn.setBlockParameter(EKF_BLOCK_PATH, ...
                    'InitialState', mat2str(ekf_x0));
        simIn = simIn.setModelParameter('StopTime', ...
                    num2str(userStruct.model_params.stop_time));

        % --- Run simulation ---------------------------------------------
        simout = sim(simIn);

        % --- Compute miss distance ---
        [min_dist, t_cpa] = compute_miss_distance(simout, bball_pwcurve);

        results.min_dist(run_idx) = min_dist;
        results.t_cpa(run_idx)    = t_cpa;
        results.avoided(run_idx)  = min_dist > R_safe;
        results.sim_time(run_idx) = toc(run_tic);

        % Store logsout and bball for post-hoc selected plots
        results.logsout_data{run_idx}  = simout.logsout;
        results.bball_pw_data{run_idx} = bball_pwcurve;

        if results.avoided(run_idx)
            fprintf('AVOIDED (%.2f m) [%.1f s]\n', min_dist, results.sim_time(run_idx));
        else
            fprintf('DID NOT AVOID (%.2f m) [%.1f s]\n', min_dist, results.sim_time(run_idx));
        end

    catch ME
        results.errored(run_idx)  = true;
        results.sim_time(run_idx) = toc(run_tic);
        fprintf('ERROR: %s [%.1f s]\n', ME.message, results.sim_time(run_idx));
    end
end

batch_elapsed = toc(batch_tic);

%% ========================================================================
%  SAVE RAW RESULTS
%  ========================================================================
save(fullfile(out_dir, 'batch_results.mat'), 'results', 'R_safe', ...
     'N_runs', 'traj_indices');
fprintf('\nResults saved to %s\n', fullfile(out_dir, 'batch_results.mat'));

%% ========================================================================
%  CONSOLE SUMMARY
%  ========================================================================
valid       = ~results.errored;
n_valid     = sum(valid);
n_avoided   = sum(results.avoided(valid));
n_collision = n_valid - n_avoided;
n_errors    = sum(results.errored);

fprintf('\n==============================================\n');
fprintf('  BATCH RESULTS SUMMARY\n');
fprintf('==============================================\n');
fprintf('  Total runs:          %d\n', N_runs);
fprintf('  Successful runs:     %d\n', n_valid);
fprintf('  Errors:              %d\n', n_errors);
fprintf('  -------------------------------------------\n');
fprintf('  Collisions avoided:  %d / %d  (%.1f%%)\n', ...
    n_avoided, n_valid, 100*n_avoided/max(n_valid,1));
fprintf('  Collisions/misses:   %d / %d  (%.1f%%)\n', ...
    n_collision, n_valid, 100*n_collision/max(n_valid,1));
fprintf('  -------------------------------------------\n');

if n_valid > 0
    fprintf('  Min miss distance:   %.3f m\n', min(results.min_dist(valid)));
    fprintf('  Max miss distance:   %.3f m\n', max(results.min_dist(valid)));
    fprintf('  Mean miss distance:  %.3f m\n', mean(results.min_dist(valid)));
    fprintf('  Median miss distance:%.3f m\n', median(results.min_dist(valid)));
else
    fprintf('  Min miss distance:   N/A\n');
    fprintf('  Max miss distance:   N/A\n');
    fprintf('  Mean miss distance:  N/A\n');
    fprintf('  Median miss distance:N/A\n');
end

fprintf('  -------------------------------------------\n');
fprintf('  R_safe threshold:    %.1f m\n', R_safe);
fprintf('  Total batch time:    %.1f s (%.1f min)\n', ...
    batch_elapsed, batch_elapsed/60);
fprintf('  Avg time per run:    %.1f s\n', mean(results.sim_time(valid)));
fprintf('==============================================\n\n');

%% ========================================================================
%  FIGURE 1: SUCCESS RATE PIE CHART
%  ========================================================================
fig1 = figure('Name', 'Success Rate', 'Color', 'w', ...
    'Position', [50 400 500 400]);

if n_errors > 0
    pie_data = [n_avoided, n_collision, n_errors];
    pie_labels = {sprintf('Avoided (%d)', n_avoided), ...
                  sprintf('Collision (%d)', n_collision), ...
                  sprintf('Error (%d)', n_errors)};
    pie_colors = [0.3 0.8 0.3; 0.9 0.3 0.3; 0.7 0.7 0.7];
else
    pie_data = [n_avoided, n_collision];
    pie_labels = {sprintf('Avoided (%d)', n_avoided), ...
                  sprintf('Collision (%d)', n_collision)};
    pie_colors = [0.3 0.8 0.3; 0.9 0.3 0.3];
end

% Remove zero entries for pie chart
nonzero = pie_data > 0;
p = pie(pie_data(nonzero));
colormap(fig1, pie_colors(nonzero, :));
legend(pie_labels(nonzero), 'Location', 'southoutside', ...
    'FontSize', 12, 'Orientation', 'horizontal');
title(sprintf('Avoidance Success Rate  |  %d Trajectory Pairs', n_valid), ...
    'FontSize', 14, 'FontWeight', 'bold');

if save_figures
    exportgraphics(fig1, fullfile(out_dir, 'SuccessRate.png'), 'Resolution', 200);
end

%% ========================================================================
%  FIGURE 2: MISS DISTANCE HISTOGRAM
%  ========================================================================
fig2 = figure('Name', 'Miss Distance Distribution', 'Color', 'w', ...
    'Position', [100 350 700 450]);

valid_dists = results.min_dist(valid);
histogram(valid_dists, 25, 'FaceColor', [0.3 0.5 0.8], ...
    'EdgeColor', 'w', 'FaceAlpha', 0.85);
hold on;
xline(R_safe, 'r--', 'LineWidth', 2);
text(R_safe + 0.2, max(ylim)*0.9, sprintf('R_{safe} = %.1f m', R_safe), ...
    'FontSize', 12, 'Color', 'r', 'FontWeight', 'bold');
hold off;

xlabel('Minimum Drone-to-Baseball Distance (m)', 'FontSize', 12);
ylabel('Number of Trajectory Pairs', 'FontSize', 12);
title('Distribution of Closest Approach Distances', ...
    'FontSize', 14, 'FontWeight', 'bold');
grid on; box on;

if save_figures
    exportgraphics(fig2, fullfile(out_dir, 'MissDistHistogram.png'), 'Resolution', 200);
end

%% ========================================================================
%  FIGURE 3: MISS DISTANCE VS TRAJECTORY PAIR (SCATTER)
%  ========================================================================
fig3 = figure('Name', 'Miss Distance by Trajectory', 'Color', 'w', ...
    'Position', [150 300 900 450]);

avoided_idx   = valid & results.avoided;
collision_idx = valid & ~results.avoided;

hold on;
if any(avoided_idx)
    scatter(results.traj_num(avoided_idx), results.min_dist(avoided_idx), ...
        50, [0.3 0.8 0.3], 'filled', 'DisplayName', 'Avoided');
end
if any(collision_idx)
    scatter(results.traj_num(collision_idx), results.min_dist(collision_idx), ...
        50, [0.9 0.3 0.3], 'filled', 'DisplayName', 'Collision');
end
yline(R_safe, 'r--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
text(traj_indices(end) - 5, R_safe + 0.3, sprintf('R_{safe} = %.1f m', R_safe), ...
    'FontSize', 11, 'Color', 'r', 'HorizontalAlignment', 'right');
hold off;

xlabel('Trajectory Pair Number', 'FontSize', 12);
ylabel('Minimum Distance (m)', 'FontSize', 12);
title('Closest Approach Distance per Trajectory Pair', ...
    'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11);
xlim([traj_indices(1)-1, traj_indices(end)+1]);
grid on; box on;

if save_figures
    exportgraphics(fig3, fullfile(out_dir, 'MissDistScatter.png'), 'Resolution', 200);
end

%% ========================================================================
%  FIGURE 4: SELECTED 3D TRAJECTORY CASES
%  ========================================================================
valid_dists_vec  = results.min_dist(valid);
valid_indices    = find(valid);

if isempty(valid_indices)
    fig4 = figure('Name', 'Selected Trajectories', 'Color', 'w');
    axis off;
    text(0.5, 0.5, 'No valid runs available', ...
        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
        'FontSize', 14, 'FontWeight', 'bold');
else
    % Best avoidance (largest miss distance)
    [~, best_local]    = max(valid_dists_vec);
    best_idx           = valid_indices(best_local);

    % Tightest successful avoidance (smallest miss > R_safe)
    avoided_dists      = valid_dists_vec(results.avoided(valid));
    avoided_local_idx  = find(results.avoided(valid));
    if ~isempty(avoided_dists)
        [~, tight_local]   = min(avoided_dists);
        tight_idx          = valid_indices(avoided_local_idx(tight_local));
    else
        tight_idx = best_idx;
    end

    % Worst case (smallest miss distance overall)
    [~, worst_local]   = min(valid_dists_vec);
    worst_idx          = valid_indices(worst_local);

    case_indices = [best_idx, tight_idx, worst_idx];
    case_labels  = {'Best Avoidance', 'Tightest Dodge', 'Closest Approach'};
    case_colors  = {[0.2 0.6 0.2], [0.9 0.6 0.1], [0.9 0.2 0.2]};

    fig4 = figure('Name', 'Selected Trajectories', 'Color', 'w', ...
        'Position', [200 100 1400 450]);

    for c = 1:3
        ci = case_indices(c);
        subplot(1, 3, c);
        hold on; box on; grid on;

        if ci <= length(results.logsout_data) && ~isempty(results.logsout_data{ci})
            sim_data  = results.logsout_data{ci}{1}.Values;
            drone_pos = sim_data.EOM.InertialData.Pos_bii.Data;
            ref_pos   = sim_data.RefInputs.pos_i.Data;

            plot3(drone_pos(:,1), drone_pos(:,2), -drone_pos(:,3), ...
                '-', 'Color', case_colors{c}, 'LineWidth', 2);
            plot3(ref_pos(:,1), ref_pos(:,2), -ref_pos(:,3), ...
                'k--', 'LineWidth', 1);

            if ~isempty(results.bball_pw_data{ci})
                bpw = results.bball_pw_data{ci};
                t_range = [bpw{1}{1}.tint(1), bpw{1}{end}.tint(end)];
                t_eval  = linspace(t_range(1), t_range(2), ...
                    round((t_range(2)-t_range(1))/0.01));
                bball_pos = evalPWCurve(bpw, t_eval, 0);
                plot3(bball_pos(:,1), bball_pos(:,2), -bball_pos(:,3), ...
                    'r:', 'LineWidth', 2);
            end
        end

        ax = gca; ax.YDir = 'reverse';
        xlabel('N (m)'); ylabel('E (m)'); zlabel('Alt (m)');
        title(sprintf('{\\bf %s}\nPair %d | Miss = %.2f m', ...
            case_labels{c}, results.traj_num(ci), results.min_dist(ci)), ...
            'FontSize', 11);
        view(-25, 35);
        axis equal;
        hold off;
    end
end

if save_figures
    exportgraphics(fig4, fullfile(out_dir, 'SelectedTrajectories.png'), ...
        'Resolution', 200);
end

%% ========================================================================
%  FIGURE 5: CUMULATIVE DISTRIBUTION - MISS DISTANCE
%  ========================================================================
fig5 = figure('Name', 'CDF of Miss Distance', 'Color', 'w', ...
    'Position', [250 250 600 400]);

sorted_dists = sort(valid_dists);
cdf_y = (1:length(sorted_dists)) / length(sorted_dists) * 100;

plot(sorted_dists, cdf_y, 'b-', 'LineWidth', 2);
hold on;
xline(R_safe, 'r--', 'LineWidth', 1.5);
% Mark the % below R_safe
pct_below = 100 * sum(sorted_dists <= R_safe) / length(sorted_dists);
plot(R_safe, pct_below, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
text(R_safe + 0.3, pct_below, sprintf('%.1f%% below R_{safe}', pct_below), ...
    'FontSize', 11, 'Color', 'r');
hold off;

xlabel('Minimum Distance (m)', 'FontSize', 12);
ylabel('Cumulative Percentage (%)', 'FontSize', 12);
title('Cumulative Distribution of Closest Approach Distances', ...
    'FontSize', 14, 'FontWeight', 'bold');
grid on; box on;
ylim([0 105]);

if save_figures
    exportgraphics(fig5, fullfile(out_dir, 'MissDistCDF.png'), 'Resolution', 200);
end

%% ========================================================================
%  DONE
%  ========================================================================
fprintf('All figures saved to: %s\n', out_dir);
fprintf('Batch testing complete.\n\n');

%% ========================================================================
%  LOCAL FUNCTIONS
%  ========================================================================

function [uStruct, wpX, wpY, wpZ, twpX, twpY, twpZ, ...
          bbwpX, bbwpY, bbwpZ, bbtwpX, bbtwpY, bbtwpZ] = ...
    load_trajectory_pair(uStruct, file_own, file_bb, own_num, bb_num)
%LOAD_TRAJECTORY_PAIR Load a matched own-ship / baseball trajectory pair
%   into userStruct and return the raw waypoint cells for plotting.

    % Own-ship
    wpX  = file_own.own_traj(own_num, 1);
    wpY  = file_own.own_traj(own_num, 2);
    wpZ  = file_own.own_traj(own_num, 3);
    twpX = file_own.own_traj(own_num, 4);
    twpY = file_own.own_traj(own_num, 5);
    twpZ = file_own.own_traj(own_num, 6);

    uStruct.simulation_defaults.RefInputs.waypointsX = wpX{1};
    uStruct.simulation_defaults.RefInputs.waypointsY = wpY{1};
    uStruct.simulation_defaults.RefInputs.waypointsZ = wpZ{1};
    uStruct.simulation_defaults.RefInputs.time_wptsX = twpX{1};
    uStruct.simulation_defaults.RefInputs.time_wptsY = twpY{1};
    uStruct.simulation_defaults.RefInputs.time_wptsZ = twpZ{1};

    uStruct.model_params.stop_time = twpX{1}(end);

    % Baseball
    bbwpX  = file_bb.bball_traj(bb_num, 1);
    bbwpY  = file_bb.bball_traj(bb_num, 2);
    bbwpZ  = file_bb.bball_traj(bb_num, 3);
    bbtwpX = file_bb.bball_traj(bb_num, 4);
    bbtwpY = file_bb.bball_traj(bb_num, 5);
    bbtwpZ = file_bb.bball_traj(bb_num, 6);

    uStruct.simulation_defaults.RefInputsBball.waypointsX = bbwpX{1};
    uStruct.simulation_defaults.RefInputsBball.waypointsY = bbwpY{1};
    uStruct.simulation_defaults.RefInputsBball.waypointsZ = bbwpZ{1};
    uStruct.simulation_defaults.RefInputsBball.time_wptsX = bbtwpX{1};
    uStruct.simulation_defaults.RefInputsBball.time_wptsY = bbtwpY{1};
    uStruct.simulation_defaults.RefInputsBball.time_wptsZ = bbtwpZ{1};
end

function [min_dist, t_closest] = compute_miss_distance(simout, bball_pwcurve)
%COMPUTE_MISS_DISTANCE Post-process simulation output to find the minimum
%   distance between drone and baseball during the simulation.

    sim_data  = simout.logsout{1}.Values;
    time_sim  = sim_data.EOM.InertialData.Pos_bii.Time;
    drone_pos = sim_data.EOM.InertialData.Pos_bii.Data;  % Nx3

    % Baseball time window
    t_bb_start = bball_pwcurve{1}{1}.tint(1);
    t_bb_end   = bball_pwcurve{1}{end}.tint(end);

    valid = (time_sim >= t_bb_start) & (time_sim <= t_bb_end);

    if ~any(valid)
        min_dist  = Inf;
        t_closest = NaN;
        return;
    end

    % Evaluate baseball position at valid sim times
    bball_pos = evalPWCurve(bball_pwcurve, time_sim(valid), 0);  % Mx3

    % Compute distance (both in NED inertial frame)
    rel = bball_pos - drone_pos(valid, :);
    dist = vecnorm(rel, 2, 2);

    [min_dist, idx] = min(dist);
    valid_times = time_sim(valid);
    t_closest = valid_times(idx);
end