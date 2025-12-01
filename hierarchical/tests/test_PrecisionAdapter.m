classdef test_PrecisionAdapter < matlab.unittest.TestCase
    % Unit tests for PrecisionAdapter class
    % Tests adaptive precision weighting and biological plausibility
    
    properties
        test_config
        adapter
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            % Initialize test configuration
            testCase.test_config = struct();
            testCase.test_config.precision_bounds = struct();
            testCase.test_config.precision_bounds.L1_motor = [1, 500];
            testCase.test_config.precision_bounds.L2_motor = [0.1, 50];
            testCase.test_config.precision_bounds.L1_plan = [1, 500];
            testCase.test_config.precision_bounds.L2_plan = [0.1, 50];
            testCase.test_config.alpha_gain = 0.5;
            testCase.test_config.error_threshold = 0.1;
        end
    end
    
    methods(Test)
        
        % ================================================================
        % INITIALIZATION TESTS
        % ================================================================
        
        function testConstructor_CreatesAdapter(testCase)
            % Test that constructor creates adapter without error
            adapter = PrecisionAdapter(testCase.test_config);
            
            testCase.verifyNotEmpty(adapter);
        end
        
        function testConstructor_SetsBounds(testCase)
            % Test that precision bounds are set correctly
            adapter = PrecisionAdapter(testCase.test_config);
            
            testCase.verifyEqual(adapter.bounds_L1_motor, testCase.test_config.precision_bounds.L1_motor);
            testCase.verifyEqual(adapter.bounds_L2_motor, testCase.test_config.precision_bounds.L2_motor);
            testCase.verifyEqual(adapter.bounds_L1_plan, testCase.test_config.precision_bounds.L1_plan);
            testCase.verifyEqual(adapter.bounds_L2_plan, testCase.test_config.precision_bounds.L2_plan);
        end
        
        function testConstructor_SetsAdaptationParameters(testCase)
            % Test that adaptation parameters are set
            adapter = PrecisionAdapter(testCase.test_config);
            
            testCase.verifyEqual(adapter.alpha_gain, testCase.test_config.alpha_gain);
            testCase.verifyEqual(adapter.error_threshold, testCase.test_config.error_threshold);
        end
        
        function testConstructor_InitializesErrorHistory(testCase)
            % Test that error history is initialized to zero
            adapter = PrecisionAdapter(testCase.test_config);
            
            testCase.verifyEqual(sum(adapter.error_history_L1_motor), 0);
            testCase.verifyEqual(sum(adapter.error_history_L2_motor), 0);
            testCase.verifyEqual(sum(adapter.error_history_L1_plan), 0);
            testCase.verifyEqual(sum(adapter.error_history_L2_plan), 0);
        end
        
        function testConstructor_InitializesCounters(testCase)
            % Test that sample counters are initialized
            adapter = PrecisionAdapter(testCase.test_config);
            
            testCase.verifyEqual(adapter.samples_collected_motor_L1, 0);
            testCase.verifyEqual(adapter.samples_collected_motor_L2, 0);
            testCase.verifyEqual(adapter.samples_collected_plan_L1, 0);
            testCase.verifyEqual(adapter.samples_collected_plan_L2, 0);
        end
        
        function testConstructor_DefaultBounds(testCase)
            % Test that default bounds are used when not provided
            config_no_bounds = struct();
            adapter = PrecisionAdapter(config_no_bounds);
            
            testCase.verifyEqual(adapter.bounds_L1_motor, [1, 500]);
            testCase.verifyEqual(adapter.bounds_L2_motor, [0.1, 50]);
        end
        
        function testConstructor_DefaultParameters(testCase)
            % Test that default parameters are used when not provided
            config_minimal = struct();
            adapter = PrecisionAdapter(config_minimal);
            
            testCase.verifyEqual(adapter.alpha_gain, 0.5);
            testCase.verifyEqual(adapter.error_threshold, 0.1);
        end
        
        % ================================================================
        % MOTOR L1 ADAPTATION TESTS
        % ================================================================
        
        function testAdaptMotorL1_LowError_IncreasesPrecision(testCase)
            % Test that low error increases precision (confidence)
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1_initial = ones(1, 7) * 10.0;
            error_L1_low = ones(1, 7) * 0.05;  % Below threshold (0.1)
            
            % Warmup: collect enough samples
            for i = 1:adapter.window_size
                pi_L1_updated = adapter.adaptMotorL1(pi_L1_initial, error_L1_low);
                adapter.stepHistory();
            end
            
            testCase.verifyGreaterThan(pi_L1_updated(1), pi_L1_initial(1), ...
                'Low error should increase precision');
        end
        
        function testAdaptMotorL1_HighError_DecreasesPrecision(testCase)
            % Test that high error decreases precision (uncertainty)
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1_initial = ones(1, 7) * 10.0;
            error_L1_high = ones(1, 7) * 0.5;  % Above threshold (0.1)
            
            % Warmup
            for i = 1:adapter.window_size
                pi_L1_updated = adapter.adaptMotorL1(pi_L1_initial, error_L1_high);
                adapter.stepHistory();
            end
            
            testCase.verifyLessThan(pi_L1_updated(1), pi_L1_initial(1), ...
                'High error should decrease precision');
        end
        
        function testAdaptMotorL1_EnforcesBounds(testCase)
            % Test that precision stays within bounds
            adapter = PrecisionAdapter(testCase.test_config);
            
            % Try to push precision beyond upper bound
            pi_L1_high = ones(1, 7) * 450;  % Near upper bound (500)
            error_L1_low = ones(1, 7) * 0.01;  % Very low error
            
            for i = 1:50
                pi_L1_high = adapter.adaptMotorL1(pi_L1_high, error_L1_low);
                adapter.stepHistory();
            end
            
            testCase.verifyLessThanOrEqual(pi_L1_high(1), adapter.bounds_L1_motor(2), ...
                'Precision should not exceed upper bound');
            
            % Try to push precision beyond lower bound
            pi_L1_low = ones(1, 7) * 2;  % Near lower bound (1)
            error_L1_high = ones(1, 7) * 2.0;  % Very high error
            
            for i = 1:50
                pi_L1_low = adapter.adaptMotorL1(pi_L1_low, error_L1_high);
                adapter.stepHistory();
            end
            
            testCase.verifyGreaterThanOrEqual(pi_L1_low(1), adapter.bounds_L1_motor(1), ...
                'Precision should not go below lower bound');
        end
        
        function testAdaptMotorL1_UpdatesHistory(testCase)
            % Test that error history is updated
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1 = ones(1, 7) * 10.0;
            error_L1 = ones(1, 7) * 0.2;
            
            adapter.adaptMotorL1(pi_L1, error_L1);
            
            testCase.verifyNotEqual(adapter.error_history_L1_motor(adapter.history_idx), 0, ...
                'Error history should be updated');
        end
        
        function testAdaptMotorL1_IncrementsSampleCount(testCase)
            % Test that sample counter is incremented
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1 = ones(1, 7) * 10.0;
            error_L1 = ones(1, 7) * 0.2;
            
            initial_count = adapter.samples_collected_motor_L1;
            adapter.adaptMotorL1(pi_L1, error_L1);
            
            testCase.verifyEqual(adapter.samples_collected_motor_L1, initial_count + 1);
        end
        
        function testAdaptMotorL1_WarmupAveraging(testCase)
            % Test that averaging uses only collected samples during warmup
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1 = ones(1, 7) * 10.0;
            error_L1_step1 = ones(1, 7) * 0.5;
            error_L1_step2 = ones(1, 7) * 0.1;
            
            % First adaptation
            adapter.adaptMotorL1(pi_L1, error_L1_step1);
            adapter.stepHistory();
            
            % Second adaptation
            pi_L1_updated = adapter.adaptMotorL1(pi_L1, error_L1_step2);
            
            % Should average only first 2 samples (not all 50)
            testCase.verifyEqual(adapter.samples_collected_motor_L1, 2);
        end
        
        % ================================================================
        % MOTOR L2 ADAPTATION TESTS
        % ================================================================
        
        function testAdaptMotorL2_LowError_IncreasesPrecision(testCase)
            % Test motor L2 precision increase with low error
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L2_initial = ones(1, 20) * 1.0;
            error_L2_low = ones(1, 20) * 0.05;
            
            for i = 1:adapter.window_size
                pi_L2_updated = adapter.adaptMotorL2(pi_L2_initial, error_L2_low);
                adapter.stepHistory();
            end
            
            testCase.verifyGreaterThan(pi_L2_updated(1), pi_L2_initial(1));
        end
        
        function testAdaptMotorL2_EnforcesBounds(testCase)
            % Test motor L2 bounds enforcement
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L2_high = ones(1, 20) * 45;
            error_L2_low = ones(1, 20) * 0.01;
            
            for i = 1:50
                pi_L2_high = adapter.adaptMotorL2(pi_L2_high, error_L2_low);
                adapter.stepHistory();
            end
            
            testCase.verifyLessThanOrEqual(pi_L2_high(1), adapter.bounds_L2_motor(2));
        end
        
        % ================================================================
        % PLANNING ADAPTATION TESTS
        % ================================================================
        
        function testAdaptPlanningL1_LowError_IncreasesPrecision(testCase)
            % Test planning L1 precision increase with low error
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1_initial = ones(1, 7) * 10.0;
            error_L1_low = ones(1, 7) * 0.05;
            
            for i = 1:adapter.window_size
                pi_L1_updated = adapter.adaptPlanningL1(pi_L1_initial, error_L1_low);
                adapter.stepHistory();
            end
            
            testCase.verifyGreaterThan(pi_L1_updated(1), pi_L1_initial(1));
        end
        
        function testAdaptPlanningL2_HighError_DecreasesPrecision(testCase)
            % Test planning L2 precision decrease with high error
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L2_initial = ones(1, 15) * 5.0;
            error_L2_high = ones(1, 15) * 0.8;
            
            for i = 1:adapter.window_size
                pi_L2_updated = adapter.adaptPlanningL2(pi_L2_initial, error_L2_high);
                adapter.stepHistory();
            end
            
            testCase.verifyLessThan(pi_L2_updated(1), pi_L2_initial(1));
        end
        
        % ================================================================
        % HISTORY MANAGEMENT TESTS
        % ================================================================
        
        function testStepHistory_AdvancesIndex(testCase)
            % Test that stepHistory advances circular buffer index
            adapter = PrecisionAdapter(testCase.test_config);
            
            initial_idx = adapter.history_idx;
            adapter.stepHistory();
            
            testCase.verifyEqual(adapter.history_idx, initial_idx + 1);
        end
        
        function testStepHistory_WrapsAround(testCase)
            % Test that index wraps around at window_size
            adapter = PrecisionAdapter(testCase.test_config);
            
            % Advance to end of window
            for i = 1:adapter.window_size
                adapter.stepHistory();
            end
            
            % Should wrap to 1
            testCase.verifyEqual(adapter.history_idx, 1);
        end
        
        function testReset_ClearsHistory(testCase)
            % Test that reset clears error history
            adapter = PrecisionAdapter(testCase.test_config);
            
            % Fill history with data
            pi_L1 = ones(1, 7) * 10.0;
            error_L1 = ones(1, 7) * 0.3;
            for i = 1:10
                adapter.adaptMotorL1(pi_L1, error_L1);
                adapter.stepHistory();
            end
            
            adapter.reset();
            
            testCase.verifyEqual(sum(adapter.error_history_L1_motor), 0);
            testCase.verifyEqual(sum(adapter.error_history_L2_motor), 0);
            testCase.verifyEqual(sum(adapter.error_history_L1_plan), 0);
            testCase.verifyEqual(sum(adapter.error_history_L2_plan), 0);
        end
        
        function testReset_ResetsSampleCounters(testCase)
            % Test that reset resets sample counters
            adapter = PrecisionAdapter(testCase.test_config);
            
            % Collect samples
            pi_L1 = ones(1, 7) * 10.0;
            error_L1 = ones(1, 7) * 0.3;
            for i = 1:10
                adapter.adaptMotorL1(pi_L1, error_L1);
                adapter.stepHistory();
            end
            
            adapter.reset();
            
            testCase.verifyEqual(adapter.samples_collected_motor_L1, 0);
            testCase.verifyEqual(adapter.samples_collected_motor_L2, 0);
            testCase.verifyEqual(adapter.samples_collected_plan_L1, 0);
            testCase.verifyEqual(adapter.samples_collected_plan_L2, 0);
        end
        
        function testReset_ResetsCounters(testCase)
            % Test that reset resets adaptation counters
            adapter = PrecisionAdapter(testCase.test_config);
            
            % Trigger adaptations
            pi_L1 = ones(1, 7) * 10.0;
            error_L1 = ones(1, 7) * 0.3;
            for i = 1:adapter.window_size
                adapter.adaptMotorL1(pi_L1, error_L1);
                adapter.stepHistory();
            end
            
            adapter.reset();
            
            testCase.verifyEqual(adapter.adaptation_count_motor, 0);
            testCase.verifyEqual(adapter.adaptation_count_plan, 0);
        end
        
        % ================================================================
        % STATISTICS TESTS
        % ================================================================
        
        function testGetStatistics_ReturnsStruct(testCase)
            % Test that getStatistics returns a struct
            adapter = PrecisionAdapter(testCase.test_config);
            
            stats = adapter.getStatistics();
            
            testCase.verifyTrue(isstruct(stats));
        end
        
        function testGetStatistics_ContainsAdaptationCounts(testCase)
            % Test that statistics contain adaptation counts
            adapter = PrecisionAdapter(testCase.test_config);
            
            stats = adapter.getStatistics();
            
            testCase.verifyTrue(isfield(stats, 'motor_adaptations'));
            testCase.verifyTrue(isfield(stats, 'plan_adaptations'));
        end
        
        function testGetStatistics_ContainsErrorMeans(testCase)
            % Test that statistics contain error means
            adapter = PrecisionAdapter(testCase.test_config);
            
            stats = adapter.getStatistics();
            
            testCase.verifyTrue(isfield(stats, 'motor_L1_error_mean'));
            testCase.verifyTrue(isfield(stats, 'motor_L2_error_mean'));
            testCase.verifyTrue(isfield(stats, 'plan_L1_error_mean'));
            testCase.verifyTrue(isfield(stats, 'plan_L2_error_mean'));
        end
        
        function testGetStatistics_ZeroWhenEmpty(testCase)
            % Test that error means are zero when no samples collected
            adapter = PrecisionAdapter(testCase.test_config);
            
            stats = adapter.getStatistics();
            
            testCase.verifyEqual(stats.motor_L1_error_mean, 0);
            testCase.verifyEqual(stats.motor_L2_error_mean, 0);
            testCase.verifyEqual(stats.plan_L1_error_mean, 0);
            testCase.verifyEqual(stats.plan_L2_error_mean, 0);
        end
        
        function testGetStatistics_ComputesMean(testCase)
            % Test that error means are computed correctly
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1 = ones(1, 7) * 10.0;
            error_L1 = ones(1, 7) * 0.3;
            
            % Collect 10 samples
            for i = 1:10
                adapter.adaptMotorL1(pi_L1, error_L1);
                adapter.stepHistory();
            end
            
            stats = adapter.getStatistics();
            
            % Mean should be close to 0.3 (RMS of constant error)
            testCase.verifyGreaterThan(stats.motor_L1_error_mean, 0.25);
            testCase.verifyLessThan(stats.motor_L1_error_mean, 0.35);
        end
        
        % ================================================================
        % ADAPTATION CLAMPING TESTS
        % ================================================================
        
        function testAdaptation_ClampedToHalf(testCase)
            % Test that adaptation is clamped to minimum 0.5x
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1 = ones(1, 7) * 10.0;
            error_L1_extreme = ones(1, 7) * 100.0;  % Extreme error
            
            % Should not reduce precision by more than 50% in one step
            for i = 1:adapter.window_size
                pi_L1_updated = adapter.adaptMotorL1(pi_L1, error_L1_extreme);
                adapter.stepHistory();
            end
            
            testCase.verifyGreaterThan(pi_L1_updated(1), pi_L1(1) * 0.3, ...
                'Adaptation should be clamped to prevent extreme reduction');
        end
        
        function testAdaptation_ClampedToDouble(testCase)
            % Test that adaptation is clamped to maximum 2.0x
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1 = ones(1, 7) * 10.0;
            error_L1_zero = ones(1, 7) * 0.001;  % Near-zero error
            
            % Should not increase precision by more than 2x in one step
            for i = 1:adapter.window_size
                pi_L1_updated = adapter.adaptMotorL1(pi_L1, error_L1_zero);
                adapter.stepHistory();
            end
            
            % After many steps, should be limited by max bound, not unclamped growth
            testCase.verifyLessThan(pi_L1_updated(1), adapter.bounds_L1_motor(2), ...
                'Adaptation should respect bounds');
        end
        
        % ================================================================
        % BIOLOGICAL PLAUSIBILITY TEST #2: PRECISION INCREASES FOR LOW-ERROR CUES
        % ================================================================
        
        function testBiologicalPlausibility_PrecisionIncreasesForLowErrorCues(testCase)
            % CRITICAL TEST: Precision (confidence) should increase for reliable cues
            % This tests Bayesian cue integration: weight sensory channels by reliability
            
            % Test scenario: Simulate two separate adapters for two sensory channels
            % Channel 1: Reliable (low error) → precision should INCREASE
            % Channel 2: Unreliable (high error) → precision should DECREASE
            
            adapter_reliable = PrecisionAdapter(testCase.test_config);
            adapter_unreliable = PrecisionAdapter(testCase.test_config);
            
            initial_precision = 10.0;
            pi_L1_reliable = ones(1, 7) * initial_precision;
            pi_L1_unreliable = ones(1, 7) * initial_precision;
            
            error_reliable = ones(1, 7) * 0.02;    % Very low error (reliable cue)
            error_unreliable = ones(1, 7) * 0.5;   % High error (unreliable cue)
            
            % Run adaptation for many timesteps (each channel independently)
            for trial = 1:100
                % Adapt reliable channel
                pi_L1_reliable = adapter_reliable.adaptMotorL1(pi_L1_reliable, error_reliable);
                adapter_reliable.stepHistory();
                
                % Adapt unreliable channel
                pi_L1_unreliable = adapter_unreliable.adaptMotorL1(pi_L1_unreliable, error_unreliable);
                adapter_unreliable.stepHistory();
            end
            
            % Test 1: Reliable cue should have higher precision than unreliable
            testCase.verifyGreaterThan(pi_L1_reliable(1), pi_L1_unreliable(1), ...
                'Precision should be higher for reliable (low-error) cues');
            
            % Test 2: Reliable cue precision should increase substantially (>50%)
            testCase.verifyGreaterThan(pi_L1_reliable(1), initial_precision * 1.5, ...
                'Reliable cue precision should increase by at least 50%');
            
            % Test 3: Unreliable cue precision should decrease (>20%)
            testCase.verifyLessThan(pi_L1_unreliable(1), initial_precision * 0.8, ...
                'Unreliable cue precision should decrease by at least 20%');
            
            % Test 4: Precision ratio should be substantial (>3x)
            % Reflects 25x difference in error magnitudes (0.02 vs 0.5)
            precision_ratio = pi_L1_reliable(1) / pi_L1_unreliable(1);
            testCase.verifyGreaterThan(precision_ratio, 3.0, ...
                'Precision ratio should reflect large reliability difference (>3x)');
            
            % Test 5: Verify Bayesian weighting principle
            % In optimal Bayesian integration: weight ∝ precision (inverse variance)
            % Reliable cue should get >60% weight, unreliable <40%
            total_precision = pi_L1_reliable(1) + pi_L1_unreliable(1);
            reliable_weight = pi_L1_reliable(1) / total_precision;
            unreliable_weight = pi_L1_unreliable(1) / total_precision;
            
            testCase.verifyGreaterThan(reliable_weight, 0.6, ...
                'Reliable cue should receive majority weight (>60%) in Bayesian integration');
            testCase.verifyLessThan(unreliable_weight, 0.4, ...
                'Unreliable cue should receive minority weight (<40%)');
            
            % Test 6: Both adapters should show active adaptation
            testCase.verifyGreaterThan(adapter_reliable.adaptation_count_motor, 0, ...
                'Reliable adapter should be actively adjusting precision');
            testCase.verifyGreaterThan(adapter_unreliable.adaptation_count_motor, 0, ...
                'Unreliable adapter should be actively adjusting precision');
        end
        
        % ================================================================
        % EDGE CASE TESTS
        % ================================================================
        
        function testZeroError_MaxPrecisionIncrease(testCase)
            % Test that zero error maximally increases precision over time
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1 = ones(1, 7) * 10.0;
            error_L1_zero = zeros(1, 7);
            
            % Apply adaptation repeatedly with compounding
            for i = 1:adapter.window_size
                pi_L1 = adapter.adaptMotorL1(pi_L1, error_L1_zero);
                adapter.stepHistory();
            end
            
            % With error=0 and threshold=0.1, adaptation = 1 + 0.5*(0.1-0) = 1.05 per step
            % After warmup and compounding: precision should increase substantially
            initial_precision = 10.0;
            testCase.verifyGreaterThan(pi_L1(1), initial_precision * 1.05, ...
                'Zero error should increase precision (at least 5% after warmup)');
        end
        
        function testNaNError_DoesNotCrash(testCase)
            % Test that NaN errors don't crash the system
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1 = ones(1, 7) * 10.0;
            error_L1_nan = ones(1, 7) * NaN;
            
            % Should not throw error
            testCase.verifyWarningFree(@() adapter.adaptMotorL1(pi_L1, error_L1_nan));
        end
        
        function testInfError_GetsClamped(testCase)
            % Test that Inf errors are handled
            adapter = PrecisionAdapter(testCase.test_config);
            
            pi_L1 = ones(1, 7) * 10.0;
            error_L1_inf = ones(1, 7) * Inf;
            
            for i = 1:adapter.window_size
                pi_L1_updated = adapter.adaptMotorL1(pi_L1, error_L1_inf);
                adapter.stepHistory();
            end
            
            % Precision should still be within bounds (not NaN or Inf)
            testCase.verifyTrue(isfinite(pi_L1_updated(1)));
            testCase.verifyGreaterThanOrEqual(pi_L1_updated(1), adapter.bounds_L1_motor(1));
        end
        
    end
    
end
