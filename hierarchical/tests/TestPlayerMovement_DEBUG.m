% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\TestPlayerMovement_DEBUG.m

addpath(genpath('../'));

fprintf('=== DEBUGGING: Testing Player Movement ===\n\n');

% Minimal config
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
config_struct.T_per_trial = 100;  % Short trial
config_struct.log_level = 'INFO';
config_struct.motor_gain = 1.0;
config_struct.enable_delay = false;  % NO DELAY for debugging
config_struct.noise_enabled = false;  % NO NOISE

config = Config(config_struct);
model = Model(config);

% Set initial positions
model.state.x_player(1) = 0;
model.state.y_player(1) = 0;
model.state.z_player(1) = 0;

model.state.x_ball(1) = 3;
model.state.y_ball(1) = 3;
model.state.z_ball(1) = 0;

fprintf('Initial player: (%.2f, %.2f, %.2f)\n', ...
    model.state.x_player(1), model.state.y_player(1), model.state.z_player(1));
fprintf('Initial ball: (%.2f, %.2f, %.2f)\n', ...
    model.state.x_ball(1), model.state.y_ball(1), model.state.z_ball(1));

%% Manual single-step simulation to debug
fprintf('\n=== STEP-BY-STEP DEBUG ===\n');

% Get initial state
x_player = model.state.x_player(1);
y_player = model.state.y_player(1);
z_player = model.state.z_player(1);
vx_player = model.state.vx_player(1);
vy_player = model.state.vy_player(1);
vz_player = model.state.vz_player(1);

x_ball = model.state.x_ball(1);
y_ball = model.state.y_ball(1);
z_ball = model.state.z_ball(1);

fprintf('\n[STEP 1] Initial state:\n');
fprintf('  Player pos: (%.4f, %.4f, %.4f)\n', x_player, y_player, z_player);
fprintf('  Ball pos: (%.4f, %.4f, %.4f)\n', x_ball, y_ball, z_ball);

% Set observations
fprintf('\n[STEP 2] Setting motor hierarchy observations...\n');
model.motorHierarchy.setPositionObservation(x_player, y_player, z_player);
model.motorHierarchy.setVelocityObservation(vx_player, vy_player, vz_player);
model.motorHierarchy.setBiasObservation(1.0);
fprintf('  ✓ Observations set\n');

% Update representations
fprintf('\n[STEP 3] Updating motor hierarchy representations...\n');
model.motorHierarchy.predict();  % ADD THIS LINE - compute predictions
model.motorHierarchy.updateRepresentations();
fprintf('  ✓ Representations updated\n');

% Extract motor commands
fprintf('\n[STEP 4] Extracting motor commands...\n');
[vx_cmd, vy_cmd, vz_cmd] = model.motorHierarchy.extractMotorCommand();
fprintf('  Motor commands: vx=%.4f, vy=%.4f, vz=%.4f\n', vx_cmd, vy_cmd, vz_cmd);

if abs(vx_cmd) < 0.001 && abs(vy_cmd) < 0.001
    fprintf('  ⚠ WARNING: Motor commands are ZERO!\n');
    fprintf('     This means the motor hierarchy is not generating movement\n');
end

% Integrate physics
fprintf('\n[STEP 5] Integrating physics...\n');
[x_player_new, y_player_new, z_player_new, vx_player_new, vy_player_new, vz_player_new] = ...
    model.physics.integratePlayer(x_player, y_player, z_player, ...
                                  vx_player, vy_player, vz_player, ...
                                  vx_cmd, vy_cmd, vz_cmd, config_struct.dt);

fprintf('  Player pos after physics: (%.4f, %.4f, %.4f)\n', x_player_new, y_player_new, z_player_new);
fprintf('  Player vel after physics: (%.4f, %.4f, %.4f)\n', vx_player_new, vy_player_new, vz_player_new);

displacement = sqrt((x_player_new - x_player)^2 + (y_player_new - y_player)^2 + (z_player_new - z_player)^2);
fprintf('  Displacement in 1 step: %.6f\n', displacement);

if displacement < 0.0001
    fprintf('  ⚠ WARNING: Player did not move!\n');
    fprintf('     Check: Motor commands = %.4f, %.4f, %.4f\n', vx_cmd, vy_cmd, vz_cmd);
end

%% Now run full simulation
fprintf('\n\n=== RUNNING FULL SIMULATION ===\n');
results = model.run();

% Check results
fprintf('\n=== RESULTS ===\n');
fprintf('Player start: (%.2f, %.2f, %.2f)\n', results.x_player(1), results.y_player(1), results.z_player(1));
fprintf('Player end: (%.2f, %.2f, %.2f)\n', results.x_player(end), results.y_player(end), results.z_player(end));

total_disp = sqrt((results.x_player(end) - results.x_player(1))^2 + ...
                  (results.y_player(end) - results.y_player(1))^2 + ...
                  (results.z_player(end) - results.z_player(1))^2);

fprintf('Total displacement: %.4f\n', total_disp);

if total_disp < 0.01
    fprintf('\n❌ PROBLEM CONFIRMED: Player is not moving\n\n');
    fprintf('Possible causes:\n');
    fprintf('1. Motor hierarchy not generating commands\n');
    fprintf('2. Physics integration ignoring commands\n');
    fprintf('3. State arrays not being updated\n');
    fprintf('4. Motor gain is zero or very small\n');
else
    fprintf('\n✓ Player is moving normally\n');
end

% Plot
figure('Position', [100, 100, 1200, 500]);

subplot(1, 2, 1);
t = (0:length(results.x_player)-1) * config_struct.dt;
plot(t, results.x_player, 'b-', 'LineWidth', 2);
hold on;
plot(t, results.x_ball, 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('X Position');
title('X Position');
legend('Player', 'Ball');
grid on;

subplot(1, 2, 2);
plot3(results.x_player, results.y_player, results.z_player, 'b-', 'LineWidth', 2);
hold on;
plot3(results.x_ball, results.y_ball, results.z_ball, 'r--', 'LineWidth', 1.5);
xlabel('X'); ylabel('Y'); zlabel('Z');
title('3D Trajectory');
legend('Player', 'Ball');
grid on;
view(45, 30);