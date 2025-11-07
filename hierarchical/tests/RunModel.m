% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\RunModel.m

% Example: Run the hierarchical model

% Add all paths
addpath(genpath('../'));

% Create a configuration from a struct
config_struct = struct();
config_struct.n_L1_motor = 7;
config_struct.n_L2_motor = 20;
config_struct.n_L3_motor = 10;
config_struct.n_L1_plan = 7;
config_struct.n_L2_plan = 15;
config_struct.n_L3_plan = 8;
config_struct.gravity = 9.81;
config_struct.air_drag = 0.001;
config_struct.restitution = 0.95;
config_struct.ground_friction = 0.9;
config_struct.dt = 0.02;
config_struct.workspace_bounds = [-5, 5; -5, 5; 0, 5];
config_struct.eta_rep = 0.01;
config_struct.eta_W = 0.001;
config_struct.momentum = 0.9;
config_struct.weight_decay = 0.98;
config_struct.T_per_trial = 10;
config_struct.n_trials = 100;

% Create config object from struct
config = Config(config_struct);

% Create and run model
model = Model(config);

% Set initial positions at ground level
model.state.x_player(1) = -2;     % Player on left
model.state.y_player(1) = -2;
model.state.z_player(1) = 0;      % Ground level

model.state.x_ball(1) = 2;        % Ball on right
model.state.y_ball(1) = 2;
model.state.z_ball(1) = 0;        % Ground level

% Optional: Give ball initial velocity
model.state.vx_ball(1) = -1.0;    % Moving toward player
model.state.vy_ball(1) = -1.0;
model.state.vz_ball(1) = 0;

results = model.run();

% Display results
fprintf('Simulation complete. Results stored in results structure.\n');
disp(results);