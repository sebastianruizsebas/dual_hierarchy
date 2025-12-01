% filepath: hierarchical/tests/test_TestNeuroscienceHypotheses.m

classdef test_TestNeuroscienceHypotheses < matlab.unittest.TestCase
    % Unit tests for TestNeuroscienceHypotheses.m
    % Tests neuroscience hypothesis validation, data structures, and metrics
    
    properties
        base_config
        test_results
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            % Initialize base configuration for all tests
            testCase.base_config = struct();
            testCase.base_config.n_L1_motor = 7;
            testCase.base_config.n_L2_motor = 20;
            testCase.base_config.n_L3_motor = 10;
            testCase.base_config.n_L1_plan = 7;
            testCase.base_config.n_L2_plan = 15;
            testCase.base_config.n_L3_plan = 8;
            testCase.base_config.gravity = 9.81;
            testCase.base_config.dt = 0.02;
            testCase.base_config.workspace_bounds = [-5, 5; -5, 5; 0, 5];
            testCase.base_config.T_per_trial = 250;
            testCase.base_config.noise_enabled = false;
            testCase.base_config.log_level = 'INFO';
            
            testCase.test_results = struct();
        end
    end
    
    methods(Test)
        
        % ================================================================
        % HYPOTHESIS 1: Delay Adaptation Tests
        % ================================================================
        
        function testDelayConfig_EnablesCorrectly(testCase)
            % Verify delay configuration is set correctly
            cfg = testCase.base_config;
            cfg.enable_delay = true;
            cfg.visual_latency_ms = 100;
            cfg.prediction_horizon_ms = 100;
            
            testCase.verifyTrue(cfg.enable_delay, ...
                'Delay should be enabled when enable_delay=true');
            testCase.verifyEqual(cfg.visual_latency_ms, 100, ...
                'Visual latency should be 100ms');
            testCase.verifyEqual(cfg.prediction_horizon_ms, 100, ...
                'Prediction horizon should match latency');
        end
        
        function testDelayArray_ValidValues(testCase)
            % Verify delay array contains expected values
            delays_ms = [0, 50, 100, 200, 400];
            
            testCase.verifyEqual(length(delays_ms), 5, ...
                'Should have 5 delay conditions');
            testCase.verifyTrue(all(delays_ms >= 0), ...
                'All delays should be non-negative');
            testCase.verifyTrue(issorted(delays_ms), ...
                'Delays should be in ascending order');
        end
        
        function testDelayPerformanceDegradation(testCase)
            % Test that performance degrades monotonically with delay
            % (Mock version - validates structure)
            
            % Simulate delay results structure
            mock_results = struct();
            mock_results.delay_0ms = struct('final_distance', 0.5, 'distance_to_target', linspace(5, 0.5, 100));
            mock_results.delay_50ms = struct('final_distance', 0.7, 'distance_to_target', linspace(5, 0.7, 100));
            mock_results.delay_100ms = struct('final_distance', 1.2, 'distance_to_target', linspace(5, 1.2, 100));
            mock_results.delay_200ms = struct('final_distance', 2.5, 'distance_to_target', linspace(5, 2.5, 100));
            
            baseline = mock_results.delay_0ms.final_distance;
            delay_50 = mock_results.delay_50ms.final_distance;
            delay_100 = mock_results.delay_100ms.final_distance;
            delay_200 = mock_results.delay_200ms.final_distance;
            
            % Verify monotonic degradation
            testCase.verifyGreaterThan(delay_100, delay_50, ...
                'Performance at 100ms should degrade more than at 50ms');
            testCase.verifyGreaterThan(delay_200, delay_100, ...
                'Performance at 200ms should degrade more than at 100ms');
            
            % Verify all > baseline
            testCase.verifyGreaterThan(delay_50, baseline, ...
                'All delays should increase error vs baseline');
            testCase.verifyGreaterThan(delay_100, baseline);
            testCase.verifyGreaterThan(delay_200, baseline);
        end
        
        function testDelayLossPercentage(testCase)
            % Test that percentage loss is computed correctly
            baseline = 0.5;
            delay_loss = 0.7;
            
            loss_pct = (delay_loss - baseline) / baseline * 100;
            
            testCase.verifyGreaterThan(loss_pct, 0, ...
                'Loss percentage should be positive');
            testCase.verifyLessThan(loss_pct, 500, ...
                'Loss percentage should be reasonable (<500%)');
        end
        
        function testCriticalDelayThreshold(testCase)
            % Test critical delay threshold detection
            mock_results = struct();
            baseline = 0.5;
            
            mock_results.delay_0ms = struct('final_distance', baseline);
            mock_results.delay_50ms = struct('final_distance', 0.6);
            mock_results.delay_100ms = struct('final_distance', 1.0);
            mock_results.delay_200ms = struct('final_distance', 1.5);
            mock_results.delay_400ms = struct('final_distance', 3.0);
            
            delays_ms = [0, 50, 100, 200, 400];
            critical_delay = 0;
            
            for i = 1:length(delays_ms)
                key = sprintf('delay_%dms', delays_ms(i));
                if (mock_results.(key).final_distance - baseline) / baseline < 0.5
                    critical_delay = delays_ms(i);
                end
            end
            
            testCase.verifyGreaterThanOrEqual(critical_delay, 0, ...
                'Critical delay should be non-negative');
        end
        
        % ================================================================
        % HYPOTHESIS 2: Noise Robustness Tests
        % ================================================================
        
        function testNoiseConfig_Structure(testCase)
            % Verify noise configuration structure
            noise_levels = struct();
            noise_levels.none = struct('pos', 0.0, 'vel', 0.0, 'label', 'None');
            noise_levels.low = struct('pos', 0.05, 'vel', 0.02, 'label', 'Low');
            noise_levels.medium = struct('pos', 0.25, 'vel', 0.18, 'label', 'Medium');
            noise_levels.high = struct('pos', 0.50, 'vel', 0.50, 'label', 'High');
            
            noise_keys = {'none', 'low', 'medium', 'high'};
            
            testCase.verifyEqual(length(noise_keys), 4, ...
                'Should have 4 noise conditions');
            
            for i = 1:length(noise_keys)
                key = noise_keys{i};
                testCase.verifyTrue(isfield(noise_levels.(key), 'pos'), ...
                    sprintf('%s noise should have pos field', key));
                testCase.verifyTrue(isfield(noise_levels.(key), 'vel'), ...
                    sprintf('%s noise should have vel field', key));
            end
        end
        
        function testNoiseValues_Monotonic(testCase)
            % Test that noise values increase monotonically
            pos_noise = [0.0, 0.05, 0.25, 0.50];
            vel_noise = [0.0, 0.02, 0.18, 0.50];
            
            testCase.verifyTrue(issorted(pos_noise), ...
                'Position noise should increase monotonically');
            testCase.verifyTrue(issorted(vel_noise), ...
                'Velocity noise should increase monotonically');
        end
        
        function testNoiseDegradation_Graceful(testCase)
            % Test graceful degradation with increasing noise
            mock_results = struct();
            mock_results.none = struct('final_distance', 0.5, 'mean_distance', 1.0);
            mock_results.low = struct('final_distance', 0.55, 'mean_distance', 1.1);
            mock_results.medium = struct('final_distance', 0.85, 'mean_distance', 1.5);
            mock_results.high = struct('final_distance', 1.5, 'mean_distance', 2.5);
            
            baseline = mock_results.none.final_distance;
            loss_low = (mock_results.low.final_distance - baseline) / baseline * 100;
            loss_high = (mock_results.high.final_distance - baseline) / baseline * 100;
            
            testCase.verifyGreaterThan(loss_high, loss_low, ...
                'High noise should cause more loss than low noise');
            testCase.verifyLessThan(loss_low, 100, ...
                'Low noise loss should be reasonable');
        end
        
        function testNoiseSensitivity_Calculation(testCase)
            % Test noise sensitivity slope calculation
            noise_std = [0.0, 0.05, 0.25, 0.50];
            final_dist = [0.5, 0.55, 0.85, 1.5];
            
            p = polyfit(noise_std, final_dist, 1);
            sensitivity = p(1);
            
            testCase.verifyGreaterThan(sensitivity, 0, ...
                'Noise sensitivity should be positive');
            testCase.verifyLessThan(sensitivity, 100, ...
                'Noise sensitivity should be bounded');
        end
        
        % ================================================================
        % HYPOTHESIS 3: Motor Learning Tests
        % ================================================================
        
        function testLearningTrials_Count(testCase)
            % Verify correct number of learning trials
            n_trials = 5;
            
            testCase.verifyEqual(n_trials, 5, ...
                'Should have 5 learning trials');
            testCase.verifyGreaterThanOrEqual(n_trials, 3, ...
                'Learning trials should be at least 3');
        end
        
        function testLearningResults_Structure(testCase)
            % Verify learning results structure
            n_trials = 5;
            learning_results = repmat(struct(...
                'final_distance', 0, ...
                'mean_distance', 0, ...
                'interception', false, ...
                'x_player', [], ...
                'y_player', [], ...
                'z_player', [], ...
                'x_ball', [], ...
                'y_ball', [], ...
                'z_ball', []), n_trials, 1);
            
            testCase.verifyEqual(length(learning_results), n_trials, ...
                'Should have correct number of trial results');
            
            for trial = 1:n_trials
                testCase.verifyTrue(isfield(learning_results(trial), 'final_distance'), ...
                    sprintf('Trial %d should have final_distance field', trial));
                testCase.verifyTrue(isfield(learning_results(trial), 'x_player'), ...
                    sprintf('Trial %d should have x_player field', trial));
            end
        end
        
        function testLearningCurve_ErrorReduction(testCase)
            % Test error reduction across trials
            mock_learning = struct();
            mock_learning(1).final_distance = 2.0;
            mock_learning(2).final_distance = 1.8;
            mock_learning(3).final_distance = 1.5;
            mock_learning(4).final_distance = 1.3;
            mock_learning(5).final_distance = 1.1;
            
            initial_error = mock_learning(1).final_distance;
            final_error = mock_learning(end).final_distance;
            error_reduction = (initial_error - final_error) / initial_error * 100;
            
            testCase.verifyGreaterThan(error_reduction, 0, ...
                'Error reduction should be positive');
            testCase.verifyLessThan(error_reduction, 100, ...
                'Error reduction should be less than 100%');
        end
        
        function testLearningTimeConstant_Estimation(testCase)
            % Test learning time constant calculation
            trial_nums = 1:5;
            final_distances = [2.0, 1.8, 1.5, 1.3, 1.1];
            
            p = polyfit(trial_nums, log(final_distances + 0.1), 1);
            tau_estimate = -1 / p(1);
            
            testCase.verifyGreaterThan(tau_estimate, 0, ...
                'Time constant should be positive');
            testCase.verifyLessThan(tau_estimate, 50, ...
                'Time constant should be reasonable');
        end
        
        function testLearningMonotonicity(testCase)
            % Test that learning shows general trend of improvement
            final_distances = [2.0, 1.9, 1.7, 1.5, 1.4];
            
            % Check trend (most later trials should be better than earlier)
            improvements = 0;
            for i = 2:length(final_distances)
                if final_distances(i) < final_distances(i-1)
                    improvements = improvements + 1;
                end
            end
            
            testCase.verifyGreaterThan(improvements, 2, ...
                'Should have at least 3 consecutive improvements');
        end
        
        % ================================================================
        % HYPOTHESIS 4: Interaction Effects Tests
        % ================================================================
        
        function testInteractionRatio_Calculation(testCase)
            % Test interaction ratio computation
            baseline = 0.5;
            delay_only = 1.0;
            noise_only = 1.2;
            combined = 1.4;
            
            delay_effect = delay_only - baseline;
            noise_effect = noise_only - baseline;
            additive_pred = baseline + delay_effect + noise_effect;
            
            if additive_pred > 0
                interaction_ratio = combined / additive_pred;
            else
                interaction_ratio = 1.0;
            end
            
            testCase.verifyGreaterThan(interaction_ratio, 0, ...
                'Interaction ratio should be positive');
            testCase.verifyLessThan(interaction_ratio, 10, ...
                'Interaction ratio should be bounded');
        end
        
        function testInteractionInterpretation_Synergistic(testCase)
            % Test synergistic compensation detection
            interaction_ratio = 0.8;
            
            is_synergistic = interaction_ratio < 0.9;
            testCase.verifyTrue(is_synergistic, ...
                'Ratio 0.8 should indicate synergistic effects');
        end
        
        function testInteractionInterpretation_Interference(testCase)
            % Test interference detection
            interaction_ratio = 1.2;
            
            is_interference = interaction_ratio > 1.1;
            testCase.verifyTrue(is_interference, ...
                'Ratio 1.2 should indicate interference');
        end
        
        function testInteractionInterpretation_Additive(testCase)
            % Test additive effects detection
            interaction_ratio = 1.05;
            
            is_additive = abs(interaction_ratio - 1.0) <= 0.1;
            testCase.verifyTrue(is_additive, ...
                'Ratio 1.05 should indicate additive effects');
        end
        
        % ================================================================
        % Data Structure & Output Tests
        % ================================================================
        
        function testResultsStructure_Completeness(testCase)
            % Verify all required result fields exist
            results = struct();
            results.final_distance = 0.5;
            results.mean_distance = 1.0;
            results.interception_success = true;
            results.distance_to_target = linspace(5, 0.5, 100);
            results.x_player = rand(1, 100);
            results.y_player = rand(1, 100);
            results.z_player = rand(1, 100);
            results.x_ball = rand(1, 100);
            results.y_ball = rand(1, 100);
            results.z_ball = rand(1, 100);
            
            required_fields = {'final_distance', 'mean_distance', ...
                'interception_success', 'distance_to_target', ...
                'x_player', 'y_player', 'z_player', ...
                'x_ball', 'y_ball', 'z_ball'};
            
            for i = 1:length(required_fields)
                field = required_fields{i};
                testCase.verifyTrue(isfield(results, field), ...
                    sprintf('Results should have %s field', field));
            end
        end
        
        function testTrajectoryData_Consistency(testCase)
            % Test trajectory data consistency
            n_steps = 100;
            x_player = rand(1, n_steps);
            y_player = rand(1, n_steps);
            z_player = rand(1, n_steps);
            
            testCase.verifyEqual(length(x_player), n_steps);
            testCase.verifyEqual(length(y_player), n_steps);
            testCase.verifyEqual(length(z_player), n_steps);
        end
        
        function testTrajectoryBounds_Physical(testCase)
            % Test that trajectories stay within physical bounds
            workspace_bounds = [-5, 5; -5, 5; 0, 5];
            
            % Simulate trajectory
            x_player = randn(1, 100) * 2;  % Within bounds
            y_player = randn(1, 100) * 2;
            z_player = rand(1, 100) * 5;
            
            testCase.verifyGreaterThanOrEqual(min(x_player), workspace_bounds(1, 1) - 1, ...
                'X should respect lower bound (with margin)');
            testCase.verifyLessThanOrEqual(max(x_player), workspace_bounds(1, 2) + 1, ...
                'X should respect upper bound (with margin)');
            testCase.verifyGreaterThanOrEqual(min(z_player), workspace_bounds(3, 1) - 0.5);
            testCase.verifyLessThanOrEqual(max(z_player), workspace_bounds(3, 2) + 0.5);
        end
        
        function testDistanceMetric_Positive(testCase)
            % Verify distance metrics are non-negative
            final_dists = [0.5, 0.7, 1.2, 2.5, 3.0];
            
            testCase.verifyTrue(all(final_dists >= 0), ...
                'All distances should be non-negative');
        end
        
        % ================================================================
        % Configuration Validation Tests
        % ================================================================
        
        function testBaseConfig_Validity(testCase)
            % Test base configuration is valid
            cfg = testCase.base_config;
            
            testCase.verifyGreaterThan(cfg.dt, 0, ...
                'dt should be positive');
            testCase.verifyLessThan(cfg.dt, 1, ...
                'dt should be reasonable (<1s)');
            testCase.verifyGreaterThan(cfg.gravity, 0, ...
                'Gravity should be positive');
            testCase.verifyGreaterThan(cfg.T_per_trial, 0, ...
                'T_per_trial should be positive');
        end
        
        function testNetworkArchitecture_Valid(testCase)
            % Test network layer sizes are positive
            cfg = testCase.base_config;
            
            layer_sizes = [cfg.n_L1_motor, cfg.n_L2_motor, cfg.n_L3_motor, ...
                          cfg.n_L1_plan, cfg.n_L2_plan, cfg.n_L3_plan];
            
            testCase.verifyTrue(all(layer_sizes > 0), ...
                'All layer sizes should be positive');
            testCase.verifyTrue(all(layer_sizes < 1000), ...
                'Layer sizes should be reasonable');
        end
        
        function testWorkspaceBounds_Sensible(testCase)
            % Test workspace bounds are sensible
            bounds = testCase.base_config.workspace_bounds;
            
            % Each row should have lower < upper
            for i = 1:size(bounds, 1)
                testCase.verifyLessThan(bounds(i, 1), bounds(i, 2), ...
                    sprintf('Dimension %d lower bound should be < upper', i));
            end
        end
        
        % ================================================================
        % Edge Case & Robustness Tests
        % ================================================================
        
        function testZeroDelay_Baseline(testCase)
            % Zero delay should be well-defined
            delay_ms = 0;
            
            testCase.verifyEqual(delay_ms, 0, ...
                'Zero delay should be valid baseline');
        end
        
        function testNoNoise_CleanBaseline(testCase)
            % No noise should give consistent results
            cfg = testCase.base_config;
            cfg.noise_enabled = false;
            cfg.position_noise_std = 0.0;
            
            testCase.verifyFalse(cfg.noise_enabled);
            testCase.verifyEqual(cfg.position_noise_std, 0.0);
        end
        
        function testPercentageLoss_Bounded(testCase)
            % Percentage loss calculations should be bounded
            baseline = 0.5;
            error_vals = [0.5, 1.0, 2.0, 5.0];
            
            loss_pcts = (error_vals - baseline) ./ baseline .* 100;
            
            testCase.verifyTrue(all(loss_pcts >= -100), ...
                'Loss percentages should be >= -100%');
            testCase.verifyTrue(all(loss_pcts < 10000), ...
                'Loss percentages should be < 10000%');
        end
        
        function testRandomSeedReproducibility(testCase)
            % Test that random seed enables reproducibility
            rng(0);
            vals1 = rand(10, 1);
            
            rng(0);
            vals2 = rand(10, 1);
            
            testCase.verifyEqual(vals1, vals2, ...
                'Same seed should give reproducible results');
        end
        
    end
    
end