% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\TestBallBounce.m

% Test ball bouncing physics

addpath(genpath('../'));

fprintf('=== Testing Ball Bouncing ===\n\n');

% Setup physics engine
config_struct = struct();
config_struct.dt = 0.02;
config_struct.workspace_bounds = [-10, 10; -10, 10; 0, 5];
config_struct.gravity = 9.81;
config_struct.air_drag = 0.01;
config_struct.restitution = 0.95;  % 95% energy retained on bounce
config_struct.ground_friction = 0.98;

physics = PhysicsEngine(config_struct);

% Initial ball state - dropped from height with horizontal velocity
x = 0; y = 0; z = 3;
vx = 2; vy = 1; vz = 0;

fprintf('Initial state: pos=(%.2f, %.2f, %.2f), vel=(%.2f, %.2f, %.2f)\n', ...
    x, y, z, vx, vy, vz);

% Simulate for several seconds
n_steps = 500;
states = zeros(n_steps, 6);
times = zeros(n_steps, 1);
bounce_count = 0;
last_vz = vz;

for i = 1:n_steps
    states(i, :) = [x, y, z, vx, vy, vz];
    times(i) = (i-1) * config_struct.dt;
    
    % Detect bounce: velocity changes from negative to positive (reverses)
    % AND z is near ground
    if z <= 0.01 && last_vz < -0.1 && vz > 0
        bounce_count = bounce_count + 1;
        fprintf('Bounce #%d at t=%.2fs, vz changed from %.2f to %.2f\n', ...
            bounce_count, times(i), last_vz, vz);
    end
    last_vz = vz;
    
    % Integrate using BALL physics (not player physics!)
    [x, y, z, vx, vy, vz] = physics.integrateBall(...
        x, y, z, vx, vy, vz, config_struct.dt);
    
    % Stop if ball is at rest
    if z < 0.01 && abs(vz) < 0.01 && sqrt(vx^2 + vy^2) < 0.01
        fprintf('Ball came to rest at step %d (t=%.2fs)\n', i, times(i));
        states = states(1:i, :);
        times = times(1:i);
        break;
    end
end

fprintf('\nTotal bounces detected: %d\n', bounce_count);

% Calculate max bounce heights
if bounce_count > 0
    fprintf('\nBounce heights:\n');
    % Find local maxima in z
    peaks = [];
    for i = 2:length(states)-1
        if states(i,3) > states(i-1,3) && states(i,3) > states(i+1,3) && states(i,3) > 0.1
            peaks = [peaks; i, states(i,3)];
        end
    end
    if ~isempty(peaks)
        for i = 1:min(5, size(peaks,1))
            fprintf('  Peak %d: height = %.2f m at t=%.2fs\n', i, peaks(i,2), times(peaks(i,1)));
        end
    end
end

% Visualize
figure('Position', [100, 100, 1200, 400]);

% 3D trajectory
subplot(1, 3, 1);
plot3(states(:,1), states(:,2), states(:,3), 'b-', 'LineWidth', 2);
hold on;
plot3(states(1,1), states(1,2), states(1,3), 'go', 'MarkerSize', 12, 'MarkerFaceColor', 'g');
plot3(states(end,1), states(end,2), states(end,3), 'rs', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
% Draw ground plane
[X, Y] = meshgrid(-10:2:10, -10:2:10);
Z = zeros(size(X));
surf(X, Y, Z, 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'FaceColor', [0.7 0.7 0.7]);
xlabel('X'); ylabel('Y'); zlabel('Z');
title('Ball Trajectory with Bounces');
grid on;
axis equal;
view(45, 30);

% Height over time
subplot(1, 3, 2);
plot(times, states(:,3), 'b-', 'LineWidth', 2);
hold on;
yline(0, 'k--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Height (m)');
title(sprintf('Height vs Time (%d bounces)', bounce_count));
grid on;
ylim([-0.2, max(states(:,3))*1.1]);

% Velocity magnitude over time
subplot(1, 3, 3);
v_mag = sqrt(states(:,4).^2 + states(:,5).^2 + states(:,6).^2);
plot(times, v_mag, 'r-', 'LineWidth', 2);
hold on;
plot(times, states(:,6), 'b--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Speed (m/s)');
title('Speed vs Time');
legend('Total Speed', 'Vertical Speed (vz)', 'Location', 'best');
grid on;

% Check if bouncing occurred
if bounce_count > 0
    fprintf('\n✓ Ball bouncing is working (%d bounces)\n', bounce_count);
    fprintf('  Restitution = %.2f (retains %.0f%% energy)\n', ...
        config_struct.restitution, config_struct.restitution*100);
else
    fprintf('\n✗ No bounces detected\n');
    fprintf('  Check the height plot - if you see peaks, bouncing is working\n');
    fprintf('  The detection logic may need adjustment\n');
    
    % Alternative check: look for peaks in z
    max_z = max(states(10:end,3));  % Skip initial state
    if max_z > 0.5
        fprintf('  → Height peaks detected (max=%.2f), ball IS bouncing!\n', max_z);
    end
end