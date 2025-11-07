% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\TestNoiseRobustness.m

addpath(genpath('../'));

fprintf('=== Testing Sensory Noise Robustness ===\n\n');

% Test 1: No noise (baseline)
fprintf('Test 1: Baseline (no noise)\n');
config_struct = struct();
config_struct.n_L1_motor = 7;
config_struct.n_L2_motor = 20;
config_struct.n_L3_motor = 10;
config_struct.n_L1_plan = 7;
config_struct.n_L2_plan = 15;
config_struct.n_L3_plan = 8;
config_struct.gravity = 9.81;
config_struct.dt = 0.02;
config_struct.workspace_bounds = [-5, 5; -5, 5; 0, 5];
config_struct.noise_enabled = false;
config_struct.T_per_trial = 250;

config_no_noise = Config(config_struct);
model_no_noise = Model(config_no_noise);
model_no_noise.state.setInitialConditions(0, 0, 3, 3, -1.0, -1.0);
results_no_noise = model_no_noise.run();

fprintf('  Final distance: %.3f m\n', results_no_noise.final_distance);
fprintf('  Mean distance: %.3f m\n', results_no_noise.mean_distance);
fprintf('  Interception: %s\n\n', string(results_no_noise.interception_success));

% Test 2: Low noise (5cm position, 2cm/s velocity)
fprintf('Test 2: Low noise (5cm position, 2cm/s velocity)\n');
config_struct.noise_enabled = true;
config_struct.position_noise_std = 0.4;
config_struct.velocity_noise_std = 0.4;
config_struct.noise_type = 'gaussian';

config_low_noise = Config(config_struct);
model_low_noise = Model(config_low_noise);
model_low_noise.state.setInitialConditions(0, 0, 3, 3, -1.0, -1.0);
results_low_noise = model_low_noise.run();

fprintf('  Final distance: %.3f m\n', results_low_noise.final_distance);
fprintf('  Mean distance: %.3f m\n', results_low_noise.mean_distance);
fprintf('  Interception: %s\n\n', string(results_low_noise.interception_success));

% Test 3: High noise (20cm position, 10cm/s velocity)
fprintf('Test 3: High noise (20cm position, 10cm/s velocity)\n');
config_struct.position_noise_std = 0.20;
config_struct.velocity_noise_std = 0.10;

config_high_noise = Config(config_struct);
model_high_noise = Model(config_high_noise);
model_high_noise.state.setInitialConditions(0, 0, 3, 3, -1.0, -1.0);
results_high_noise = model_high_noise.run();

fprintf('  Final distance: %.3f m\n', results_high_noise.final_distance);
fprintf('  Mean distance: %.3f m\n', results_high_noise.mean_distance);
fprintf('  Interception: %s\n\n', string(results_high_noise.interception_success));

% Summary
fprintf('=== Performance Degradation ===\n');
fprintf('Baseline final distance:    %.3f m\n', results_no_noise.final_distance);
fprintf('Low noise final distance:   %.3f m (+%.1f%%)\n', ...
    results_low_noise.final_distance, ...
    (results_low_noise.final_distance - results_no_noise.final_distance) / results_no_noise.final_distance * 100);
fprintf('High noise final distance:  %.3f m (+%.1f%%)\n', ...
    results_high_noise.final_distance, ...
    (results_high_noise.final_distance - results_no_noise.final_distance) / results_no_noise.final_distance * 100);