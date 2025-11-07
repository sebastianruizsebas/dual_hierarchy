% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\test_ball.m

% Test ball physics
addpath(genpath('../'));

% Initialize physics engine with configuration
config = struct();
config.dt = 0.02;  % time step
config.workspace_bounds = [-5,5; -5,5; 0,5];  % [x; y; z] bounds
config.gravity = 9.81;  % gravitational acceleration
config.air_drag = 0.01;  % air resistance coefficient
config.restitution = 0.8;  % bounce coefficient
config.ground_friction = 0.9;  % friction on ground
config.log_level = 'INFO';

physics = PhysicsEngine(config);

% Set initial ball state [x, y, z, vx, vy, vz]
initial_state = [0; 0; 2; 1; 0.5; 3];  % ball at (0,0,2) with velocity

% Simulate for several time steps
n_steps = 100;
states = zeros(6, n_steps);
times = zeros(1, n_steps);

for i = 1:n_steps
    if i == 1
        x = initial_state(1); y = initial_state(2); z = initial_state(3);
        vx = initial_state(4); vy = initial_state(5); vz = initial_state(6);
    end
    
    % Store state
    states(:, i) = [x; y; z; vx; vy; vz];
    times(i) = (i-1) * config.dt;
    
    % Integrate physics (no motor commands for ball)
    [x, y, z, vx, vy, vz] = physics.integratePlayer(...
        x, y, z, vx, vy, vz, 0, 0, 0, config.dt);
    
    % Stop if ball settles near ground
    if z < 0.01 && abs(vz) < 0.01
        break;
    end
end

% Plot trajectory
figure;
subplot(2,1,1);
plot3(states(1,:), states(2,:), states(3,:), 'b-', 'LineWidth', 2);
xlabel('X'); ylabel('Y'); zlabel('Z');
title('Ball Trajectory');
grid on;

subplot(2,1,2);
plot(times, states(3,:), 'r-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Height (m)');
title('Height vs Time');
grid on;