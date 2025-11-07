% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\TestInterception.m

% Test interception with tuned parameters

addpath(genpath('../'));

config_struct = struct();
config_struct.n_L1_motor = 7;
config_struct.n_L2_motor = 20;
config_struct.n_L3_motor = 10;
config_struct.n_L1_plan = 7;
config_struct.n_L2_plan = 15;
config_struct.n_L3_plan = 8;
config_struct.gravity = 9.81;
config_struct.air_drag = 0.01;
config_struct.restitution = 0.8;
config_struct.ground_friction = 0.9;
config_struct.dt = 0.02;
config_struct.workspace_bounds = [-5, 5; -5, 5; 0, 5];
config_struct.eta_rep = 0.01;
config_struct.eta_W = 0.001;
config_struct.momentum = 0.9;
config_struct.weight_decay = 0.98;
config_struct.motor_gain = 0.3;  % REDUCED GAIN
config_struct.T_per_trial = 500;
config_struct.n_trials = 1;
config_struct.log_level = 'INFO';

config = Config(config_struct);
model = Model(config);

% Set slower ball trajectory
model.state.x_ball(1) = 3;
model.state.y_ball(1) = 3;
model.state.z_ball(1) = 3;
model.state.vx_ball(1) = -0.3;  % Slower ball
model.state.vy_ball(1) = -0.3;
model.state.vz_ball(1) = 2.0;

results = model.run();

fprintf('Minimum distance achieved: %.4f\n', min(results.distance_to_target));