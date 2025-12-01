% filepath: hierarchical/tests/test_SimulationState.m

classdef test_SimulationState < matlab.unittest.TestCase
    % Unit tests for SimulationState class
    % Tests initialization, state management, and metric computation
    
    properties
        test_config
        state
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            % Create mock config for testing
            testCase.test_config = struct();
            testCase.test_config.N = 100;
            testCase.test_config.dt = 0.02;
        end
    end
    
    methods(Test)
        
        % ================================================================
        % Initialization Tests
        % ================================================================
        
        function testConstructor_AllocatesArrays(testCase)
            % Test that constructor pre-allocates all arrays
            state = SimulationState(testCase.test_config);
            
            testCase.verifyEqual(length(state.x_player), testCase.test_config.N);
            testCase.verifyEqual(length(state.y_player), testCase.test_config.N);
            testCase.verifyEqual(length(state.z_player), testCase.test_config.N);
            testCase.verifyEqual(length(state.x_ball), testCase.test_config.N);
            testCase.verifyEqual(length(state.y_ball), testCase.test_config.N);
            testCase.verifyEqual(length(state.z_ball), testCase.test_config.N);
        end
        
        function testConstructor_InitializesMetrics(testCase)
            % Test that metrics are initialized to zero
            state = SimulationState(testCase.test_config);
            
            testCase.verifyEqual(state.current_step, 1);
            testCase.verifyEqual(state.final_distance, 0);
            testCase.verifyEqual(state.mean_distance, 0);
            testCase.verifyFalse(state.interception_success);
            testCase.verifyEqual(state.interception_step, 0);
        end
        
        function testConstructor_AllocatesObservedStates(testCase)
            % Test that observed and true ball states are allocated
            state = SimulationState(testCase.test_config);
            
            testCase.verifyEqual(length(state.x_ball_obs), testCase.test_config.N);
            testCase.verifyEqual(length(state.y_ball_obs), testCase.test_config.N);
            testCase.verifyEqual(length(state.z_ball_obs), testCase.test_config.N);
            testCase.verifyEqual(length(state.x_ball_true), testCase.test_config.N);
            testCase.verifyEqual(length(state.y_ball_true), testCase.test_config.N);
            testCase.verifyEqual(length(state.z_ball_true), testCase.test_config.N);
        end
        
        function testConstructor_SinglePrecision(testCase)
            % Test that arrays use single precision for memory efficiency
            state = SimulationState(testCase.test_config);
            
            testCase.verifyEqual(class(state.x_player), 'single');
            testCase.verifyEqual(class(state.x_ball), 'single');
            testCase.verifyEqual(class(state.distance_to_target), 'single');
        end
        
        function testConstructor_InterceptionThreshold(testCase)
            % Test that interception threshold is set
            state = SimulationState(testCase.test_config);
            
            testCase.verifyGreaterThan(state.interception_threshold, 0);
            testCase.verifyLessThan(state.interception_threshold, 2);
        end
        
        % ================================================================
        % State Setter Tests
        % ================================================================
        
        function testSetInitialPlayerState_SetsValues(testCase)
            % Test setting initial player state
            state = SimulationState(testCase.test_config);
            
            x = 1.0; y = 2.0; z = 3.0;
            vx = 0.5; vy = 0.6; vz = 0.7;
            
            state.setInitialPlayerState(x, y, z, vx, vy, vz);
            
            testCase.verifyEqual(state.x_player(1), single(x));
            testCase.verifyEqual(state.y_player(1), single(y));
            testCase.verifyEqual(state.z_player(1), single(z));
            testCase.verifyEqual(state.vx_player(1), single(vx));
            testCase.verifyEqual(state.vy_player(1), single(vy));
            testCase.verifyEqual(state.vz_player(1), single(vz));
        end
        
        function testSetInitialTargetState_SetsValues(testCase)
            % Test setting initial ball/target state
            state = SimulationState(testCase.test_config);
            
            x = 3.0; y = 4.0; z = 5.0;
            vx = -1.0; vy = -1.5; vz = 2.0;
            
            state.setInitialTargetState(x, y, z, vx, vy, vz);
            
            testCase.verifyEqual(state.x_ball(1), single(x));
            testCase.verifyEqual(state.y_ball(1), single(y));
            testCase.verifyEqual(state.z_ball(1), single(z));
            testCase.verifyEqual(state.vx_ball(1), single(vx));
            testCase.verifyEqual(state.vy_ball(1), single(vy));
            testCase.verifyEqual(state.vz_ball(1), single(vz));
        end
        
        function testSetInitialTargetState_InitializesObserved(testCase)
            % Test that observed states match initial target state
            state = SimulationState(testCase.test_config);
            
            x = 3.0; y = 4.0; z = 5.0;
            vx = -1.0; vy = -1.5; vz = 2.0;
            
            state.setInitialTargetState(x, y, z, vx, vy, vz);
            
            testCase.verifyEqual(state.x_ball_obs(1), single(x));
            testCase.verifyEqual(state.y_ball_obs(1), single(y));
            testCase.verifyEqual(state.x_ball_true(1), single(x));
            testCase.verifyEqual(state.y_ball_true(1), single(y));
        end
        
        function testSetInitialConditions_GroundLevel(testCase)
            % Test that setInitialConditions places entities at ground level
            state = SimulationState(testCase.test_config);
            
            state.setInitialConditions(0, 0, 3, 3, -1, -1);
            
            testCase.verifyEqual(state.z_player(1), single(0));
            testCase.verifyEqual(state.z_ball(1), single(0));
            testCase.verifyEqual(state.vz_player(1), single(0));
            testCase.verifyEqual(state.vz_ball(1), single(0));
        end
        
        function testSetInitialConditions_SetsPositions(testCase)
            % Test that setInitialConditions sets x,y correctly
            state = SimulationState(testCase.test_config);
            
            player_x = 1.5; player_y = 2.5;
            ball_x = 4.0; ball_y = 5.0;
            ball_vx = -0.5; ball_vy = -1.0;
            
            state.setInitialConditions(player_x, player_y, ball_x, ball_y, ball_vx, ball_vy);
            
            testCase.verifyEqual(state.x_player(1), single(player_x));
            testCase.verifyEqual(state.y_player(1), single(player_y));
            testCase.verifyEqual(state.x_ball(1), single(ball_x));
            testCase.verifyEqual(state.y_ball(1), single(ball_y));
            testCase.verifyEqual(state.vx_ball(1), single(ball_vx));
            testCase.verifyEqual(state.vy_ball(1), single(ball_vy));
        end
        
        % ================================================================
        % Distance Metric Tests
        % ================================================================
        
        function testUpdateDistanceMetrics_ComputesEuclidean(testCase)
            % Test that distance is computed correctly
            state = SimulationState(testCase.test_config);
            
            % Set known positions
            state.x_player(1) = 0;
            state.y_player(1) = 0;
            state.z_player(1) = 0;
            
            state.x_ball(1) = 3;
            state.y_ball(1) = 4;
            state.z_ball(1) = 0;
            
            state.updateDistanceMetrics(1);
            
            expected_dist = 5.0;  % 3-4-5 triangle
            testCase.verifyEqual(double(state.distance_to_target(1)), expected_dist, 'AbsTol', 1e-5);
        end
        
        function testUpdateDistanceMetrics_3D(testCase)
            % Test 3D distance calculation
            state = SimulationState(testCase.test_config);
            
            state.x_player(1) = 0;
            state.y_player(1) = 0;
            state.z_player(1) = 0;
            
            state.x_ball(1) = 1;
            state.y_ball(1) = 1;
            state.z_ball(1) = 1;
            
            state.updateDistanceMetrics(1);
            
            expected_dist = sqrt(3);
            testCase.verifyEqual(double(state.distance_to_target(1)), expected_dist, 'AbsTol', 1e-5);
        end
        
        function testUpdateDistanceMetrics_DetectsInterception(testCase)
            % Test that interception is detected when distance < threshold
            state = SimulationState(testCase.test_config);
            
            state.x_player(1) = 0;
            state.y_player(1) = 0;
            state.z_player(1) = 0;
            
            state.x_ball(1) = 0.3;  % Within threshold (0.5)
            state.y_ball(1) = 0.3;
            state.z_ball(1) = 0;
            
            state.updateDistanceMetrics(1);
            
            testCase.verifyTrue(state.interception_success);
            testCase.verifyEqual(state.interception_step, 1);
        end
        
        function testUpdateDistanceMetrics_InterceptionOnlyOnce(testCase)
            % Test that interception is only triggered once
            state = SimulationState(testCase.test_config);
            
            % First interception
            state.x_player(1) = 0;
            state.y_player(1) = 0;
            state.z_player(1) = 0;
            state.x_ball(1) = 0.2;
            state.y_ball(1) = 0.2;
            state.z_ball(1) = 0;
            state.updateDistanceMetrics(1);
            
            testCase.verifyEqual(state.interception_step, 1);
            
            % Second close approach (should not update interception_step)
            state.x_player(2) = 0;
            state.y_player(2) = 0;
            state.z_player(2) = 0;
            state.x_ball(2) = 0.1;
            state.y_ball(2) = 0.1;
            state.z_ball(2) = 0;
            state.updateDistanceMetrics(2);
            
            testCase.verifyEqual(state.interception_step, 1);  % Should not change
        end
        
        function testUpdateDistanceMetrics_CumulativeError(testCase)
            % Test that cumulative error is integrated over time
            state = SimulationState(testCase.test_config);
            
            state.x_player(1) = 0;
            state.y_player(1) = 0;
            state.z_player(1) = 0;
            state.x_ball(1) = 3;
            state.y_ball(1) = 4;
            state.z_ball(1) = 0;
            state.updateDistanceMetrics(1);
            
            dist1 = state.distance_to_target(1);
            
            state.x_player(2) = 0;
            state.y_player(2) = 0;
            state.z_player(2) = 0;
            state.x_ball(2) = 2;
            state.y_ball(2) = 3;
            state.z_ball(2) = 0;
            state.updateDistanceMetrics(2);
            
            dist2 = state.distance_to_target(2);
            
            expected_cumulative = dist1 + dist2;
            testCase.verifyEqual(double(state.cumulative_error(2)), double(expected_cumulative), 'AbsTol', 1e-5);
        end
        
        % ================================================================
        % Results Packaging Tests
        % ================================================================
        
        function testGetResults_ReturnsStruct(testCase)
            % Test that getResults returns a struct
            state = SimulationState(testCase.test_config);
            results = state.getResults();
            
            testCase.verifyTrue(isstruct(results));
        end
        
        function testGetResults_ContainsTrajectories(testCase)
            % Test that results contain trajectory arrays
            state = SimulationState(testCase.test_config);
            results = state.getResults();
            
            testCase.verifyTrue(isfield(results, 'x_player'));
            testCase.verifyTrue(isfield(results, 'y_player'));
            testCase.verifyTrue(isfield(results, 'z_player'));
            testCase.verifyTrue(isfield(results, 'x_ball'));
            testCase.verifyTrue(isfield(results, 'y_ball'));
            testCase.verifyTrue(isfield(results, 'z_ball'));
        end
        
        function testGetResults_ContainsObservedStates(testCase)
            % Test that results contain observed/true ball states
            state = SimulationState(testCase.test_config);
            results = state.getResults();
            
            testCase.verifyTrue(isfield(results, 'x_ball_obs'));
            testCase.verifyTrue(isfield(results, 'y_ball_obs'));
            testCase.verifyTrue(isfield(results, 'z_ball_obs'));
            testCase.verifyTrue(isfield(results, 'x_ball_true'));
            testCase.verifyTrue(isfield(results, 'y_ball_true'));
            testCase.verifyTrue(isfield(results, 'z_ball_true'));
        end
        
        function testGetResults_ContainsMetrics(testCase)
            % Test that results contain performance metrics
            state = SimulationState(testCase.test_config);
            results = state.getResults();
            
            testCase.verifyTrue(isfield(results, 'distance_to_target'));
            testCase.verifyTrue(isfield(results, 'cumulative_error'));
            testCase.verifyTrue(isfield(results, 'final_distance'));
            testCase.verifyTrue(isfield(results, 'mean_distance'));
            testCase.verifyTrue(isfield(results, 'interception_success'));
            testCase.verifyTrue(isfield(results, 'interception_step'));
        end
        
        function testGetResults_ComputesFinalDistance(testCase)
            % Test that final_distance is computed from last timestep
            state = SimulationState(testCase.test_config);
            
            state.distance_to_target(end) = 2.5;
            results = state.getResults();
            
            testCase.verifyEqual(results.final_distance, single(2.5));
        end
        
        function testGetResults_ComputesMeanDistance(testCase)
            % Test that mean_distance is computed correctly
            state = SimulationState(testCase.test_config);
            
            state.distance_to_target(:) = 3.0;
            results = state.getResults();
            
            testCase.verifyEqual(double(results.mean_distance), 3.0, 'AbsTol', 1e-5);
        end
        
        % ================================================================
        % Snapshot Tests
        % ================================================================
        
        function testGetSnapshot_ReturnsStruct(testCase)
            % Test that getSnapshot returns a struct
            state = SimulationState(testCase.test_config);
            snapshot = state.getSnapshot(1);
            
            testCase.verifyTrue(isstruct(snapshot));
        end
        
        function testGetSnapshot_ContainsPlayerState(testCase)
            % Test that snapshot contains player state
            state = SimulationState(testCase.test_config);
            
            state.x_player(1) = 1.5;
            state.y_player(1) = 2.5;
            state.z_player(1) = 3.5;
            
            snapshot = state.getSnapshot(1);
            
            testCase.verifyEqual(snapshot.x_player, single(1.5));
            testCase.verifyEqual(snapshot.y_player, single(2.5));
            testCase.verifyEqual(snapshot.z_player, single(3.5));
        end
        
        function testGetSnapshot_ContainsBallState(testCase)
            % Test that snapshot contains ball state
            state = SimulationState(testCase.test_config);
            
            state.x_ball(1) = 4.0;
            state.y_ball(1) = 5.0;
            state.z_ball(1) = 6.0;
            
            snapshot = state.getSnapshot(1);
            
            testCase.verifyEqual(snapshot.x_ball, single(4.0));
            testCase.verifyEqual(snapshot.y_ball, single(5.0));
            testCase.verifyEqual(snapshot.z_ball, single(6.0));
        end
        
        function testGetSnapshot_DifferentTimesteps(testCase)
            % Test that snapshots differ at different timesteps
            state = SimulationState(testCase.test_config);
            
            state.x_player(1) = 1.0;
            state.x_player(2) = 2.0;
            
            snap1 = state.getSnapshot(1);
            snap2 = state.getSnapshot(2);
            
            testCase.verifyNotEqual(snap1.x_player, snap2.x_player);
        end
        
        % ================================================================
        % Edge Cases & Robustness
        % ================================================================
        
        function testConstructor_LargeN(testCase)
            % Test that large N doesn't cause issues
            large_config = testCase.test_config;
            large_config.N = 10000;
            
            state = SimulationState(large_config);
            
            testCase.verifyEqual(length(state.x_player), 10000);
        end
        
        function testUpdateDistanceMetrics_ZeroDistance(testCase)
            % Test zero distance (perfect interception)
            state = SimulationState(testCase.test_config);
            
            state.x_player(1) = 1.0;
            state.y_player(1) = 2.0;
            state.z_player(1) = 3.0;
            
            state.x_ball(1) = 1.0;
            state.y_ball(1) = 2.0;
            state.z_ball(1) = 3.0;
            
            state.updateDistanceMetrics(1);
            
            testCase.verifyEqual(double(state.distance_to_target(1)), 0.0, 'AbsTol', 1e-6);
            testCase.verifyTrue(state.interception_success);
        end
        
        function testUpdateDistanceMetrics_NegativeCoordinates(testCase)
            % Test with negative coordinates
            state = SimulationState(testCase.test_config);
            
            state.x_player(1) = -1.0;
            state.y_player(1) = -2.0;
            state.z_player(1) = 0.0;
            
            state.x_ball(1) = -4.0;
            state.y_ball(1) = -6.0;
            state.z_ball(1) = 0.0;
            
            state.updateDistanceMetrics(1);
            
            expected_dist = 5.0;  % 3-4-5 triangle
            testCase.verifyEqual(double(state.distance_to_target(1)), expected_dist, 'AbsTol', 1e-5);
        end
        
        function testSetInitialConditions_PrintsMessage(testCase)
            % Test that setInitialConditions prints (no error)
            state = SimulationState(testCase.test_config);
            
            % Should not throw error
            state.setInitialConditions(0, 0, 3, 3, -1, -1);
        end
        
        function testGetResults_EmptyMotorStates(testCase)
            % Test that empty motor_states doesn't cause error
            state = SimulationState(testCase.test_config);
            
            results = state.getResults();
            
            % Fixed logic: Check if motor_states is either not present OR empty
            if isfield(results, 'motor_states')
                testCase.verifyTrue(isempty(results.motor_states) || iscell(results.motor_states), ...
                    'motor_states should be empty or a cell array');
            else
                % If field doesn't exist, that's also acceptable
                testCase.verifyTrue(true, 'motor_states field not present (acceptable)');
            end
        end
        
        function testInterceptionThreshold_Modifiable(testCase)
            % Test that interception threshold can be modified
            state = SimulationState(testCase.test_config);
            
            state.interception_threshold = 1.0;
            testCase.verifyEqual(state.interception_threshold, 1.0);
        end
        
    end
    
end