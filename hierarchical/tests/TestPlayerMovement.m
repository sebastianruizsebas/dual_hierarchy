% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\TestPlayerMovement.m

% Test to visualize player movement in real-time

addpath(genpath('../'));

%% Setup
fprintf('=== Testing Player Movement ===\n\n');

% Create simple configuration
config_struct = struct();
config_struct.n_L1_motor = 7;
config_struct.n_L2_motor = 20;
config_struct.n_L3_motor = 10;
config_struct.n_L1_plan = 7;
config_struct.n_L2_plan = 15;
config_struct.n_L3_plan = 8;
config_struct.gravity = 9.81;
config_struct.air_drag = 0.1;
config_struct.restitution = 0.85;
config_struct.ground_friction = 0.9;
config_struct.dt = 0.02;
config_struct.workspace_bounds = [-5, 5; -5, 5; 0, 5];
config_struct.eta_rep = 0.01;
config_struct.eta_W = 0.001;
config_struct.momentum = 0.9;
config_struct.weight_decay = 0.98;
config_struct.T_per_trial = 500;  % Single trial with 500 steps
config_struct.n_trials = 1;
config_struct.log_level = 'INFO';
config_struct.motor_gain = 0.3;  % Reduce from default (probably 1.0)
config_struct.visual_latency_ms = 300;

config_struct.position_noise_std = 0.80;
config_struct.velocity_noise_std = 0.80;

config_high_noise = Config(config_struct);
model_high_noise = Model(config_high_noise);

config = Config(config_struct);
model = Model(config);

% Set initial positions
% Set initial positions at ground level
model.state.x_player(1) = -1;     % Player on left
model.state.y_player(1) = -1;
model.state.z_player(1) = 0;      % Ground level

model.state.x_ball(1) = 0;        % Ball on right
model.state.y_ball(1) = 4;
model.state.z_ball(1) = 0;        % Ground level

% Optional: Give ball initial velocity
model.state.vx_ball(1) = -1.0;    % Moving toward player
model.state.vy_ball(1) = -3.0;
model.state.vz_ball(1) = 4.0;

fprintf('Initial player position: (%.2f, %.2f, %.2f)\n', ...
    model.state.x_player(1), model.state.y_player(1), model.state.z_player(1));
fprintf('Initial ball position: (%.2f, %.2f, %.2f)\n', ...
    model.state.x_ball(1), model.state.y_ball(1), model.state.z_ball(1));

%% Run simulation
fprintf('\nRunning simulation...\n');
results = model.run();

%% Analyze movement
fprintf('\n=== Movement Analysis ===\n');

% Check if player moved at all
player_displacement = sqrt(...
    (results.x_player(end) - results.x_player(1))^2 + ...
    (results.y_player(end) - results.y_player(1))^2 + ...
    (results.z_player(end) - results.z_player(1))^2);

fprintf('Player total displacement: %.4f\n', player_displacement);

% Check velocity changes
vx_changes = diff(results.vx_player);
vy_changes = diff(results.vy_player);
vz_changes = diff(results.vz_player);

fprintf('Velocity changes - X: %.4f, Y: %.4f, Z: %.4f\n', ...
    sum(abs(vx_changes)), sum(abs(vy_changes)), sum(abs(vz_changes)));

% Check motor commands
[vx_cmd, vy_cmd, vz_cmd] = model.motorHierarchy.extractMotorCommand();
fprintf('Final motor commands: vx=%.4f, vy=%.4f, vz=%.4f\n', vx_cmd, vy_cmd, vz_cmd);

%% Visualizations

% Create figure with multiple subplots
figure('Position', [100, 100, 1400, 900], 'Name', 'Player Movement Analysis');

% Plot 1: 3D trajectory
subplot(2, 3, 1);
plot3(results.x_player, results.y_player, results.z_player, 'b-', 'LineWidth', 2);
hold on;
plot3(results.x_ball, results.y_ball, results.z_ball, 'r--', 'LineWidth', 1.5);
plot3(results.x_player(1), results.y_player(1), results.z_player(1), 'go', 'MarkerSize', 12, 'MarkerFaceColor', 'g');
plot3(results.x_player(end), results.y_player(end), results.z_player(end), 'bs', 'MarkerSize', 12, 'MarkerFaceColor', 'b');
plot3(results.x_ball(1), results.y_ball(1), results.z_ball(1), 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
xlabel('X'); ylabel('Y'); zlabel('Z');
title('3D Trajectory');
legend('Player Path', 'Ball Path', 'Player Start', 'Player End', 'Ball Start', 'Location', 'best');
grid on;
% Set equal aspect ratio and reasonable Z scale
axis equal;
zlim([min(results.z_player)-0.1, max(results.z_player)+0.5]);
view(45, 30);

% Plot 2: X position over time
subplot(2, 3, 2);
t = (0:length(results.x_player)-1) * config_struct.dt;
plot(t, results.x_player, 'b-', 'LineWidth', 2);
hold on;
plot(t, results.x_ball, 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('X Position');
title('X Position Over Time');
legend('Player', 'Ball', 'Location', 'best');
grid on;

% Plot 3: Y position over time
subplot(2, 3, 3);
plot(t, results.y_player, 'b-', 'LineWidth', 2);
hold on;
plot(t, results.y_ball, 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Y Position');
title('Y Position Over Time');
legend('Player', 'Ball', 'Location', 'best');
grid on;

% Plot 4: Z position over time
subplot(2, 3, 4);
plot(t, results.z_player, 'b-', 'LineWidth', 2);
hold on;
plot(t, results.z_ball, 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Z Position');
title('Z Position Over Time');
legend('Player', 'Ball', 'Location', 'best');
grid on;

% Plot 5: Player velocities
subplot(2, 3, 5);
plot(t, results.vx_player, 'r-', 'LineWidth', 1.5);
hold on;
plot(t, results.vy_player, 'g-', 'LineWidth', 1.5);
plot(t, results.vz_player, 'b-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Velocity');
title('Player Velocities');
legend('Vx', 'Vy', 'Vz', 'Location', 'best');
grid on;

% Plot 6: Distance to target
subplot(2, 3, 6);
plot(t, results.distance_to_target, 'k-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Distance');
title('Distance to Target Over Time');
grid on;

%% Add diagnosis
fprintf('\n=== Movement Direction Analysis ===\n');
dx_player = results.x_player(end) - results.x_player(1);
dy_player = results.y_player(end) - results.y_player(1);
dz_player = results.z_player(end) - results.z_player(1);

dx_ball = results.x_ball(end) - results.x_ball(1);
dy_ball = results.y_ball(end) - results.y_ball(1);

fprintf('Player displacement: (%.2f, %.2f, %.2f)\n', dx_player, dy_player, dz_player);
fprintf('Ball displacement: (%.2f, %.2f, %.2f)\n', dx_ball, dy_ball, 0);

% Check if player is moving toward or away from ball
initial_distance = sqrt((results.x_ball(1)-results.x_player(1))^2 + ...
                       (results.y_ball(1)-results.y_player(1))^2);
final_distance = sqrt((results.x_ball(end)-results.x_player(end))^2 + ...
                     (results.y_ball(end)-results.y_player(end))^2);

fprintf('\nDistance analysis:\n');
fprintf('  Initial distance: %.2f\n', initial_distance);
fprintf('  Final distance: %.2f\n', final_distance);
if final_distance < initial_distance
    fprintf('  ✓ Player is moving TOWARD ball\n');
else
    fprintf('  ✗ Player is moving AWAY from ball\n');
end

% Check bouncing frequency
z_crossings = sum(abs(diff(sign(results.z_player))) > 0);
fprintf('\nBounce analysis:\n');
fprintf('  Ground level crossings: %d (should be low for walking)\n', z_crossings);
if z_crossings > 50
    fprintf('  ⚠ Too much bouncing - player should walk smoothly\n');
end

%% Print detailed diagnostics
fprintf('\n=== Detailed Diagnostics ===\n');
fprintf('Position changes:\n');
fprintf('  X: %.4f -> %.4f (change: %.4f)\n', ...
    results.x_player(1), results.x_player(end), results.x_player(end) - results.x_player(1));
fprintf('  Y: %.4f -> %.4f (change: %.4f)\n', ...
    results.y_player(1), results.y_player(end), results.y_player(end) - results.y_player(1));
fprintf('  Z: %.4f -> %.4f (change: %.4f)\n', ...
    results.z_player(1), results.z_player(end), results.z_player(end) - results.z_player(1));

fprintf('\nVelocity statistics:\n');
fprintf('  Vx - mean: %.4f, max: %.4f, std: %.4f\n', ...
    mean(results.vx_player), max(abs(results.vx_player)), std(results.vx_player));
fprintf('  Vy - mean: %.4f, max: %.4f, std: %.4f\n', ...
    mean(results.vy_player), max(abs(results.vy_player)), std(results.vy_player));
fprintf('  Vz - mean: %.4f, max: %.4f, std: %.4f\n', ...
    mean(results.vz_player), max(abs(results.vz_player)), std(results.vz_player));

fprintf('\nDistance statistics:\n');
fprintf('  Initial: %.4f\n', results.distance_to_target(1));
fprintf('  Final: %.4f\n', results.distance_to_target(end));
fprintf('  Mean: %.4f\n', mean(results.distance_to_target));
fprintf('  Min: %.4f\n', min(results.distance_to_target));

% Check for stuck player
if player_displacement < 0.01
    fprintf('\n⚠ WARNING: Player barely moved (displacement < 0.01)\n');
    fprintf('   Possible causes:\n');
    fprintf('   - Motor commands are not being applied\n');
    fprintf('   - Physics integration is not working\n');
    fprintf('   - Motor hierarchy is not generating commands\n');
else
    fprintf('\n✓ Player is moving (displacement = %.4f)\n', player_displacement);
end

% Check if distance is changing
distance_change = abs(results.distance_to_target(end) - results.distance_to_target(1));
if distance_change < 0.01
    fprintf('\n⚠ WARNING: Distance to target not changing\n');
    fprintf('   Distance update may not be working properly\n');
else
    fprintf('✓ Distance is updating (change = %.4f)\n', distance_change);
end