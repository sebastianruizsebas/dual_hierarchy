% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\TestLearning.m

% Test if the model is learning by tracking key metrics over trials

addpath(genpath('../'));

%% Setup
fprintf('=== Testing Model Learning ===\n\n');

% Create configuration
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
config_struct.T_per_trial = 200;  % Longer trials to see learning
config_struct.n_trials = 20;       % Multiple trials
config_struct.log_level = 'INFO';

%% Run multiple trials and track metrics
n_trials = config_struct.n_trials;
metrics = struct();
metrics.final_distance = zeros(n_trials, 1);
metrics.mean_distance = zeros(n_trials, 1);
metrics.final_free_energy_motor = zeros(n_trials, 1);
metrics.final_free_energy_plan = zeros(n_trials, 1);
metrics.mean_free_energy_motor = zeros(n_trials, 1);
metrics.mean_free_energy_plan = zeros(n_trials, 1);
metrics.prediction_accuracy = zeros(n_trials, 1);
metrics.motor_command_variance = zeros(n_trials, 1);

% Store weight norms to see if they're changing
metrics.W_L2_to_L1_norm = zeros(n_trials, 1);
metrics.W_L3_to_L2_norm = zeros(n_trials, 1);

config = Config(config_struct);
model = Model(config);

fprintf('Running %d trials to test learning...\n\n', n_trials);

for trial = 1:n_trials
    fprintf('--- Trial %d/%d ---\n', trial, n_trials);
    
    % Reset ball/player positions for new trial
    model.state.x_ball(1) = randn() * 2;  % Random initial positions
    model.state.y_ball(1) = randn() * 2;
    model.state.z_ball(1) = 3 + randn();
    
    % Run single trial
    results = model.run();
    
    % Collect metrics
    metrics.final_distance(trial) = results.final_distance;
    metrics.mean_distance(trial) = results.mean_distance;
    
    % Free energy metrics (last values)
    metrics.final_free_energy_motor(trial) = results.free_energy_motor(end);
    metrics.final_free_energy_plan(trial) = results.free_energy_plan(end);
    metrics.mean_free_energy_motor(trial) = mean(results.free_energy_motor);
    metrics.mean_free_energy_plan(trial) = mean(results.free_energy_plan);
    
    % Compute prediction accuracy (how well predictions match actual movement)
    pred_error = sqrt(diff(results.x_player).^2 + diff(results.y_player).^2 + diff(results.z_player).^2);
    metrics.prediction_accuracy(trial) = 1 / (1 + mean(pred_error));  % Higher = better
    
    % Motor command variance (should decrease as learning stabilizes)
    motor_changes = diff([results.vx_player, results.vy_player, results.vz_player]);
    metrics.motor_command_variance(trial) = mean(var(motor_changes));
    
    % Weight matrix norms (should change during learning)
    metrics.W_L2_to_L1_norm(trial) = norm(model.motorHierarchy.getW_L2_to_L1(), 'fro');
    metrics.W_L3_to_L2_norm(trial) = norm(model.motorHierarchy.getW_L3_to_L2(), 'fro');
    
    fprintf('  Distance: %.3f (mean: %.3f)\n', results.final_distance, results.mean_distance);
    fprintf('  Free Energy - Motor: %.2f, Plan: %.2f\n', ...
        metrics.final_free_energy_motor(trial), metrics.final_free_energy_plan(trial));
end

%% Analyze learning trends
fprintf('\n=== Learning Analysis ===\n\n');

% 1. Performance improvement: distance should decrease
early_distance = mean(metrics.final_distance(1:5));
late_distance = mean(metrics.final_distance(end-4:end));
distance_improvement = (early_distance - late_distance) / early_distance * 100;

fprintf('1. PERFORMANCE IMPROVEMENT:\n');
fprintf('   Early trials (1-5) avg distance: %.3f\n', early_distance);
fprintf('   Late trials (%d-%d) avg distance: %.3f\n', n_trials-4, n_trials, late_distance);
fprintf('   Improvement: %.1f%%\n', distance_improvement);
if distance_improvement > 10
    fprintf('   ✓ Model is learning (>10%% improvement)\n');
elseif distance_improvement > 0
    fprintf('   ~ Modest learning (0-10%% improvement)\n');
else
    fprintf('   ✗ No learning detected (distance increased)\n');
end

% 2. Free energy should stabilize or decrease
fe_motor_trend = polyfit(1:n_trials, metrics.mean_free_energy_motor', 1);
fe_plan_trend = polyfit(1:n_trials, metrics.mean_free_energy_plan', 1);

fprintf('\n2. FREE ENERGY TRENDS:\n');
fprintf('   Motor hierarchy slope: %.2f (negative = decreasing)\n', fe_motor_trend(1));
fprintf('   Planning hierarchy slope: %.2f (negative = decreasing)\n', fe_plan_trend(1));
if fe_motor_trend(1) < -5 && fe_plan_trend(1) < -5
    fprintf('   ✓ Both hierarchies reducing prediction errors\n');
else
    fprintf('   ~ Free energy not consistently decreasing\n');
end

% 3. Weight changes indicate learning
early_weights = mean([metrics.W_L2_to_L1_norm(1:3); metrics.W_L3_to_L2_norm(1:3)]);
late_weights = mean([metrics.W_L2_to_L1_norm(end-2:end); metrics.W_L3_to_L2_norm(end-2:end)]);
weight_change = abs(late_weights - early_weights) / early_weights * 100;

fprintf('\n3. WEIGHT ADAPTATION:\n');
fprintf('   Total weight change: %.1f%%\n', weight_change);
if weight_change > 5
    fprintf('   ✓ Weights are adapting (>5%% change)\n');
else
    fprintf('   ✗ Minimal weight changes (<5%%)\n');
end

% 4. Motor control should stabilize
early_variance = mean(metrics.motor_command_variance(1:5));
late_variance = mean(metrics.motor_command_variance(end-4:end));

fprintf('\n4. MOTOR CONTROL STABILITY:\n');
fprintf('   Early variance: %.4f\n', early_variance);
fprintf('   Late variance: %.4f\n', late_variance);
if late_variance < early_variance * 0.8
    fprintf('   ✓ Motor commands becoming more stable\n');
else
    fprintf('   ~ Motor commands not stabilizing\n');
end

%% Visualizations
figure('Position', [100, 100, 1200, 800]);

% Plot 1: Distance over trials
subplot(2, 3, 1);
plot(1:n_trials, metrics.final_distance, 'b-o', 'LineWidth', 2);
hold on;
plot(1:n_trials, metrics.mean_distance, 'r--', 'LineWidth', 1.5);
xlabel('Trial');
ylabel('Distance');
title('Performance Over Trials');
legend('Final Distance', 'Mean Distance', 'Location', 'best');
grid on;

% Plot 2: Free energy trends
subplot(2, 3, 2);
plot(1:n_trials, metrics.mean_free_energy_motor, 'b-o', 'LineWidth', 2);
hold on;
plot(1:n_trials, metrics.mean_free_energy_plan, 'r-s', 'LineWidth', 2);
xlabel('Trial');
ylabel('Free Energy');
title('Free Energy Trends');
legend('Motor', 'Planning', 'Location', 'best');
grid on;

% Plot 3: Weight norms
subplot(2, 3, 3);
plot(1:n_trials, metrics.W_L2_to_L1_norm, 'b-o', 'LineWidth', 2);
hold on;
plot(1:n_trials, metrics.W_L3_to_L2_norm, 'r-s', 'LineWidth', 2);
xlabel('Trial');
ylabel('Weight Norm');
title('Weight Matrix Changes');
legend('W_{L2→L1}', 'W_{L3→L2}', 'Location', 'best');
grid on;

% Plot 4: Prediction accuracy
subplot(2, 3, 4);
plot(1:n_trials, metrics.prediction_accuracy, 'g-o', 'LineWidth', 2);
xlabel('Trial');
ylabel('Prediction Accuracy');
title('Prediction Accuracy Over Time');
grid on;

% Plot 5: Motor variance
subplot(2, 3, 5);
plot(1:n_trials, metrics.motor_command_variance, 'm-o', 'LineWidth', 2);
xlabel('Trial');
ylabel('Variance');
title('Motor Command Variance');
grid on;

% Plot 6: Summary learning curve with trend
subplot(2, 3, 6);
plot(1:n_trials, metrics.final_distance, 'b-o', 'LineWidth', 2);
hold on;
p = polyfit(1:n_trials, metrics.final_distance', 1);
trend = polyval(p, 1:n_trials);
plot(1:n_trials, trend, 'r--', 'LineWidth', 2);
xlabel('Trial');
ylabel('Final Distance');
title(sprintf('Learning Curve (slope=%.3f)', p(1)));
legend('Actual', 'Trend', 'Location', 'best');
grid on;

%% Save results
save('learning_test_results.mat', 'metrics', 'config_struct');
fprintf('\n✓ Results saved to learning_test_results.mat\n');

%% Summary
fprintf('\n=== LEARNING SUMMARY ===\n');
learning_score = 0;
if distance_improvement > 10, learning_score = learning_score + 1; end
if fe_motor_trend(1) < -5, learning_score = learning_score + 1; end
if weight_change > 5, learning_score = learning_score + 1; end
if late_variance < early_variance * 0.8, learning_score = learning_score + 1; end

fprintf('Learning Score: %d/4\n', learning_score);
if learning_score >= 3
    fprintf('✓ Model shows strong evidence of learning\n');
elseif learning_score >= 2
    fprintf('~ Model shows some learning\n');
else
    fprintf('✗ Model shows minimal learning\n');
end