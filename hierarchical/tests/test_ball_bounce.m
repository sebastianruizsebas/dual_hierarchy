% Test ball bouncing physics
% Verifies that PhysicsEngine correctly handles ground collisions with restitution

clear; clc;

% Add path to core and physics
addpath('../core');
addpath('../physics');

% Create minimal config for physics
config_struct = struct();
config_struct.dt = 0.01;  % 10ms timestep
config = Config(config_struct);

% Create physics engine
physics = PhysicsEngine(config);

% Initial conditions: ball at 2m height, falling
x = 0;
y = 0;
z = 2.0;  % 2 meters up
vx = 0;
vy = -2;  % Initial horizontal velocity
vz = 0;  % Initial vertical velocity = 0 (free fall)

% Simulate 700 steps (7 seconds)
N = 700;
z_history = zeros(1, N);
vz_history = zeros(1, N);

fprintf('Testing ball bounce physics...\n');
fprintf('Initial: z=%.2f m, vz=%.2f m/s\n', z, vz);

for i = 1:N
    z_history(i) = z;
    vz_history(i) = vz;
    
    % Integrate ball physics (includes bounce detection)
    [x, y, z, vx, vy, vz] = physics.integrateBall(x, y, z, vx, vy, vz, config.dt);
    
    % Print bounce events
    if i > 1 && z_history(i-1) > 0.01 && z < 0.01 && vz > 0
        fprintf('BOUNCE at step %d: z=%.4f m, vz=%.2f→%.2f m/s\n', i, z_history(i-1), vz_history(i-1), vz);
    end
end

fprintf('\nFinal: z=%.4f m, vz=%.4f m/s\n', z, vz);

% Plot results
figure('Name', 'Ball Bounce Test', 'Position', [100, 100, 1200, 500]);

subplot(1,2,1);
t = (0:N-1) * config.dt;
plot(t, z_history, 'b-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Height z (m)');
title('Ball Height vs Time');
grid on;
ylim([-0.1, 2.2]);

subplot(1,2,2);
plot(t, vz_history, 'r-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Vertical Velocity vz (m/s)');
title('Vertical Velocity vs Time');
grid on;
yline(0, 'k--', 'LineWidth', 0.5);

% Check if bounces occurred
max_z = max(z_history(100:end));  % After first bounce
if max_z > 0.5
    fprintf('\n✓ TEST PASSED: Ball bounces detected (max rebound height = %.2f m)\n', max_z);
else
    fprintf('\n✗ TEST FAILED: No bounces detected (ball fell through ground)\n');
end
