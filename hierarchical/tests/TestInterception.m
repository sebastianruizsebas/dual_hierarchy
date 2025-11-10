addpath(genpath('../'));

fprintf('=== Testing Interception Detection Logic ===\n\n');

% Minimal config
config_struct = struct();
config_struct.n_L1_motor = 7;
config_struct.n_L2_motor = 20;
config_struct.n_L3_motor = 10;
config_struct.n_L1_plan = 7;
config_struct.n_L2_plan = 15;
config_struct.n_L3_plan = 8;
config_struct.dt = 0.02;
config_struct.T_per_trial = 100;
config_struct.n_trials = 1;
config_struct.log_level = 'INFO';
config_struct.motor_gain = 1.0;

config = Config(config_struct);
model = Model(config);

% Manually set player and ball at same location (should trigger interception)
model.state.x_player(1) = 0;
model.state.y_player(1) = 0;
model.state.z_player(1) = 0;

model.state.x_ball(1) = 0.1;  % Very close (0.1m away)
model.state.y_ball(1) = 0.1;
model.state.z_ball(1) = 0.1;

% Compute distance manually
dx = model.state.x_ball(1) - model.state.x_player(1);
dy = model.state.y_ball(1) - model.state.y_player(1);
dz = model.state.z_ball(1) - model.state.z_player(1);
distance = sqrt(dx^2 + dy^2 + dz^2);

fprintf('Distance: %.4f m\n', distance);
fprintf('Expected: ~0.1732 m (sqrt(0.1^2 + 0.1^2 + 0.1^2))\n\n');

% Call updateDistanceMetrics
model.state.updateDistanceMetrics(1);

fprintf('Stored distance: %.4f m\n', model.state.distance_to_target(1));
fprintf('Threshold: %.4f m\n', model.state.interception_threshold);
fprintf('Distance < Threshold: %d\n\n', model.state.distance_to_target(1) < model.state.interception_threshold);

% Check if interception properties exist
if isprop(model.state, 'interception_success')
    fprintf('Interception detected: %d\n', model.state.interception_success);
    if model.state.interception_success
        fprintf('✓ Interception logic is WORKING\n');
        fprintf('  Intercepted at step %d\n', model.state.interception_step);
    else
        fprintf('⚠ Interception NOT triggered\n');
        fprintf('  Distance (%.4f) should be < threshold (%.4f)\n', ...
            model.state.distance_to_target(1), model.state.interception_threshold);
    end
else
    fprintf('✗ SimulationState missing interception_success property\n');
    fprintf('  Need to add interception tracking to SimulationState.m\n');
end