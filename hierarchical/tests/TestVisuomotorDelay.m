% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\TestVisuomotorDelay.m

addpath(genpath('../'));

fprintf('=== Testing Visuomotor Delay & Predictive Compensation ===\n\n');

% Base configuration
config_struct = struct();
config_struct.n_L1_motor = 7;
config_struct.n_L2_motor = 20;
config_struct.n_L3_motor = 10;
config_struct.n_L1_plan = 7;
config_struct.n_L2_plan = 15;
config_struct.n_L3_plan = 8;
config_struct.gravity = 9.81;
config_struct.dt = 0.02;  % 20ms timestep
config_struct.workspace_bounds = [-5, 5; -5, 5; 0, 5];
config_struct.noise_enabled = false;
config_struct.T_per_trial = 250;
config_struct.motor_gain = 1.0;

% Test different delay conditions
delays_ms = [0, 50, 100, 150, 200];  % 0ms to 200ms delays
results_by_delay = struct();

for delay_idx = 1:length(delays_ms)
    delay_ms = delays_ms(delay_idx);
    
    fprintf('Testing with visual latency: %.0f ms\n', delay_ms);
    
    % Set delay configuration
    config_struct.enable_delay = (delay_ms > 0);
    config_struct.visual_latency_ms = delay_ms;
    config_struct.prediction_horizon_ms = delay_ms;  % Predict ahead by delay amount
    
    config = Config(config_struct);
    model = Model(config);
    model.state.setInitialConditions(0, 0, 3, 3, -1.0, -1.0);
    
    % Run simulation
    results = model.run();
    
    % Store results
    key = sprintf('delay_%dms', delay_ms);
    results_by_delay.(key) = results;
    
    fprintf('  Final distance: %.3f m\n', results.final_distance);
    fprintf('  Mean distance: %.3f m\n', results.mean_distance);
    fprintf('  Interception: %s\n\n', string(results.interception_success));
end

% ============================================================
% ANALYSIS: Does predictive compensation work?
% ============================================================

fprintf('=== Performance vs. Delay ===\n');
fprintf('Delay (ms) | Final Distance (m) | Performance Loss %%\n');
fprintf('---------------------------------------------------\n');

baseline_distance = results_by_delay.delay_0ms.final_distance;

for delay_idx = 1:length(delays_ms)
    delay_ms = delays_ms(delay_idx);
    key = sprintf('delay_%dms', delay_ms);
    
    final_dist = results_by_delay.(key).final_distance;
    perf_loss = ((final_dist - baseline_distance) / baseline_distance) * 100;
    
    fprintf('%10.0f | %18.3f | %18.1f\n', delay_ms, final_dist, perf_loss);
end

% ============================================================
% HYPOTHESIS TEST
% ============================================================

fprintf('\n=== Hypothesis Testing ===\n');
fprintf('Q1: Does performance degrade with delay?\n');

loss_50ms = ((results_by_delay.delay_50ms.final_distance - baseline_distance) / baseline_distance);
loss_100ms = ((results_by_delay.delay_100ms.final_distance - baseline_distance) / baseline_distance);

if loss_100ms > loss_50ms > 0
    fprintf('   ✓ YES: Performance degrades monotonically with delay\n\n');
else
    fprintf('   ✗ NO: Performance does not degrade smoothly\n\n');
end

fprintf('Q2: Does prediction compensate for short delays (50ms)?\n');
if abs(loss_50ms) < 0.1  % Less than 10% degradation
    fprintf('   ✓ YES: Model predicts ahead to compensate for delay\n\n');
else
    fprintf('   ✗ MAYBE: Compensation not sufficient for 50ms delay\n\n');
end

fprintf('Q3: Is there a critical delay where performance breaks down?\n');

max_delay_good = 0;
for delay_idx = 1:length(delays_ms)
    delay_ms = delays_ms(delay_idx);
    key = sprintf('delay_%dms', delay_ms);
    loss = ((results_by_delay.(key).final_distance - baseline_distance) / baseline_distance);
    
    if loss < 0.5  % Less than 50% degradation
        max_delay_good = delay_ms;
    end
end

fprintf('   Critical delay threshold: ~%.0f ms\n\n', max_delay_good);

% ============================================================
% PLOT RESULTS
% ============================================================

figure('Name', 'Visuomotor Delay Test', 'NumberTitle', 'off');

delays_values = delays_ms;
final_distances = [];
mean_distances = [];
success_rates = [];

for delay_idx = 1:length(delays_ms)
    delay_ms = delays_ms(delay_idx);
    key = sprintf('delay_%dms', delay_ms);
    
    final_distances(delay_idx) = results_by_delay.(key).final_distance;
    mean_distances(delay_idx) = results_by_delay.(key).mean_distance;
    success_rates(delay_idx) = results_by_delay.(key).interception_success;
end

% Plot 1: Final distance vs delay
subplot(2, 2, 1);
plot(delays_values, final_distances, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Visual Latency (ms)');
ylabel('Final Distance (m)');
title('Interception Error vs. Delay');
grid on;

% Plot 2: Mean distance vs delay
subplot(2, 2, 2);
plot(delays_values, mean_distances, 's-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Visual Latency (ms)');
ylabel('Mean Distance (m)');
title('Tracking Error vs. Delay');
grid on;

% Plot 3: Success rate vs delay
subplot(2, 2, 3);
bar(delays_values, success_rates);
xlabel('Visual Latency (ms)');
ylabel('Interception Success');
title('Success Rate vs. Delay');
ylim([0 1.1]);
grid on;

% Plot 4: Performance loss vs delay
perf_loss_pct = ((final_distances - baseline_distance) / baseline_distance) * 100;
subplot(2, 2, 4);
plot(delays_values, perf_loss_pct, 'd-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Visual Latency (ms)');
ylabel('Performance Loss (%)');
title('Performance Degradation vs. Delay');
grid on;
hold on;
plot([0, max(delays_values)], [0, 0], 'k--', 'LineWidth', 1);
hold off;

sgtitle('Visuomotor Delay & Predictive Compensation');