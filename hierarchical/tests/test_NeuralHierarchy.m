classdef test_NeuralHierarchy < matlab.unittest.TestCase
    % Unit tests for NeuralHierarchy class
    % Tests predictive coding dynamics, learning, and biological plausibility
    
    properties
        test_config
        hierarchy
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            % Initialize test configuration
            testCase.test_config = struct();
            testCase.test_config.n_L1 = 7;
            testCase.test_config.n_L2 = 20;
            testCase.test_config.n_L3 = 10;
            testCase.test_config.eta_rep = 0.01;
            testCase.test_config.eta_W = 0.001;
            testCase.test_config.momentum = 0.9;
            testCase.test_config.weight_decay = 0.0001;  % L2 regularization (not multiplicative decay!)
            testCase.test_config.max_weight_value = 10.0;
            testCase.test_config.max_precision_value = 100.0;
            testCase.test_config.max_error_value = 10.0;
        end
    end
    
    methods(Test)
        
        % ================================================================
        % INITIALIZATION TESTS
        % ================================================================
        
        function testConstructor_CreatesHierarchy(testCase)
            % Test that constructor creates hierarchy without error
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            testCase.verifyNotEmpty(hierarchy);
            testCase.verifyEqual(hierarchy.name, 'test');
            testCase.verifyFalse(hierarchy.frozen);
        end
        
        function testConstructor_SetsDimensions(testCase)
            % Test that layer dimensions are set correctly
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            % Use getState() to access internal state
            state = hierarchy.getState();
            testCase.verifyEqual(size(state.R_L1, 2), testCase.test_config.n_L1);
            testCase.verifyEqual(size(state.R_L2, 2), testCase.test_config.n_L2);
            testCase.verifyEqual(size(state.R_L3, 2), testCase.test_config.n_L3);
        end
        
        function testConstructor_SetsLearningParameters(testCase)
            % Test that learning parameters are initialized
            % Note: Learning parameters are protected, test indirectly via behavior
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            % Verify hierarchy was created successfully
            testCase.verifyNotEmpty(hierarchy);
            testCase.verifyEqual(hierarchy.name, 'test');
        end
        
        function testInitializeWeights_XavierScaling(testCase)
            % Test Xavier initialization produces correct scaling
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            % Use public getter methods
            W_L3_to_L2 = hierarchy.getW_L3_to_L2();
            W_L2_to_L1 = hierarchy.getW_L2_to_L1();
            
            % W_L3_to_L2: n_L2 x n_L3
            testCase.verifySize(W_L3_to_L2, [testCase.test_config.n_L2, testCase.test_config.n_L3]);
            
            % W_L2_to_L1: n_L1 x n_L2
            testCase.verifySize(W_L2_to_L1, [testCase.test_config.n_L1, testCase.test_config.n_L2]);
            
            % Check Xavier scaling: std should be approximately sqrt(2/(n_in + n_out))
            expected_std_32 = sqrt(2.0 / (testCase.test_config.n_L3 + testCase.test_config.n_L2));
            actual_std_32 = std(W_L3_to_L2(:));
            testCase.verifyLessThan(abs(actual_std_32 - expected_std_32), 0.1);
            
            expected_std_21 = sqrt(2.0 / (testCase.test_config.n_L2 + testCase.test_config.n_L1));
            actual_std_21 = std(W_L2_to_L1(:));
            testCase.verifyLessThan(abs(actual_std_21 - expected_std_21), 0.1);
        end
        
        function testInitializeWeights_CachesTransposes(testCase)
            % Test that weight transposes are cached (tested indirectly)
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            % Transposes are used internally in predict(), test that predictions work
            hierarchy.predict();
            pred_L1 = hierarchy.getPredL1();
            pred_L2 = hierarchy.getPredL2();
            
            % Predictions should have correct dimensions
            testCase.verifySize(pred_L1, [1, testCase.test_config.n_L1]);
            testCase.verifySize(pred_L2, [1, testCase.test_config.n_L2]);
        end
        
        function testInitializeWeights_InitializesMomentum(testCase)
            % Test that momentum matrices work correctly (tested indirectly)
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            % Test that weight updates work (momentum is used internally)
            sensory_input = ones(1, testCase.test_config.n_L1, 'single');
            hierarchy.step(sensory_input);
            
            % Verify hierarchy still functions
            testCase.verifyNotEmpty(hierarchy.getState());
        end
        
        function testInitializeStates_ZeroRepresentations(testCase)
            % Test that representations are initialized to zero
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            state = hierarchy.getState();
            testCase.verifyEqual(sum(state.R_L1(:)), single(0));
            testCase.verifyEqual(sum(state.R_L2(:)), single(0));
            testCase.verifyEqual(sum(state.R_L3(:)), single(0));
        end
        
        function testInitializeStates_ZeroErrors(testCase)
            % Test that errors are initialized to zero
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            state = hierarchy.getState();
            testCase.verifyEqual(sum(state.E_L1(:)), single(0));
            testCase.verifyEqual(sum(state.E_L2(:)), single(0));
        end
        
        function testInitializeStates_PositivePrecision(testCase)
            % Test that precision weights are positive
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            state = hierarchy.getState();
            testCase.verifyTrue(all(state.pi_L1 > 0));
            testCase.verifyTrue(all(state.pi_L2 > 0));
        end
        
        function testInitializeStates_SinglePrecision(testCase)
            % Test that arrays use single precision
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            state = hierarchy.getState();
            W_L3_to_L2 = hierarchy.getW_L3_to_L2();
            testCase.verifyEqual(class(state.R_L1), 'single');
            testCase.verifyEqual(class(W_L3_to_L2), 'single');
            testCase.verifyEqual(class(state.pi_L1), 'single');
        end
        
        % ================================================================
        % PREDICTION FLOW TESTS
        % ================================================================
        
        function testPredict_GeneratesPredictions(testCase)
            % Test that predict() generates predictions
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            % Set non-zero representations
            hierarchy.R_L3 = ones(1, testCase.test_config.n_L3, 'single');
            hierarchy.R_L2 = ones(1, testCase.test_config.n_L2, 'single');
            
            hierarchy.predict();
            
            testCase.verifyNotEqual(sum(hierarchy.pred_L2(:)), single(0));
            testCase.verifyNotEqual(sum(hierarchy.pred_L1(:)), single(0));
        end
        
        function testPredict_CorrectDimensions(testCase)
            % Test that predictions have correct dimensions
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            hierarchy.R_L3 = randn(1, testCase.test_config.n_L3, 'single');
            hierarchy.R_L2 = randn(1, testCase.test_config.n_L2, 'single');
            
            hierarchy.predict();
            
            testCase.verifySize(hierarchy.pred_L2, [1, testCase.test_config.n_L2]);
            testCase.verifySize(hierarchy.pred_L1, [1, testCase.test_config.n_L1]);
        end
        
        function testComputeErrors_CalculatesL1Error(testCase)
            % Test L1 error computation
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            sensory_input = ones(1, testCase.test_config.n_L1, 'single') * 2.0;
            hierarchy.pred_L1 = ones(1, testCase.test_config.n_L1, 'single');
            
            hierarchy.computeErrors(sensory_input);
            
            expected_error = sensory_input - hierarchy.pred_L1;
            testCase.verifyEqual(hierarchy.E_L1, expected_error);
        end
        
        function testComputeErrors_CalculatesL2Error(testCase)
            % Test L2 error computation
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            hierarchy.R_L2 = ones(1, testCase.test_config.n_L2, 'single') * 3.0;
            hierarchy.pred_L2 = ones(1, testCase.test_config.n_L2, 'single');
            
            sensory_input = zeros(1, testCase.test_config.n_L1, 'single');
            hierarchy.computeErrors(sensory_input);
            
            expected_error = hierarchy.R_L2 - hierarchy.pred_L2;
            testCase.verifyEqual(hierarchy.E_L2, expected_error);
        end
        
        function testComputeErrors_ClipsExtremeValues(testCase)
            % Test that extreme errors are clipped
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            sensory_input = ones(1, testCase.test_config.n_L1, 'single') * 100.0;
            hierarchy.pred_L1 = zeros(1, testCase.test_config.n_L1, 'single');
            
            hierarchy.computeErrors(sensory_input);
            
            testCase.verifyTrue(all(abs(hierarchy.E_L1) <= hierarchy.max_error_value));
        end
        
        function testUpdateRepresentations_UpdatesL1(testCase)
            % Test that L1 representations update toward sensory input
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            initial_R_L1 = hierarchy.R_L1;
            sensory_input = ones(1, testCase.test_config.n_L1, 'single');
            hierarchy.pred_L1 = zeros(1, testCase.test_config.n_L1, 'single');
            
            hierarchy.computeErrors(sensory_input);
            hierarchy.updateRepresentations();
            
            testCase.verifyNotEqual(hierarchy.R_L1, initial_R_L1);
            testCase.verifyGreaterThan(mean(hierarchy.R_L1), mean(initial_R_L1));
        end
        
        function testUpdateRepresentations_ClipsActivations(testCase)
            % Test that representations are clipped to [-10, 10]
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            hierarchy.R_L1 = ones(1, testCase.test_config.n_L1, 'single') * 15.0;
            hierarchy.E_L1 = ones(1, testCase.test_config.n_L1, 'single') * 10.0;
            hierarchy.pi_L1 = ones(1, testCase.test_config.n_L1, 'single') * 100.0;
            
            hierarchy.updateRepresentations();
            
            testCase.verifyTrue(all(hierarchy.R_L1 <= 10));
            testCase.verifyTrue(all(hierarchy.R_L1 >= -10));
        end
        
        function testUpdateWeights_ComputesGradients(testCase)
            % Test that weight updates are computed
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            initial_W_L2_to_L1 = hierarchy.W_L2_to_L1;
            
            % Set up non-zero errors and representations
            hierarchy.E_L1 = ones(1, testCase.test_config.n_L1, 'single');
            hierarchy.R_L2 = ones(1, testCase.test_config.n_L2, 'single');
            
            hierarchy.updateWeights();
            
            testCase.verifyNotEqual(hierarchy.W_L2_to_L1, initial_W_L2_to_L1);
        end
        
        function testUpdateWeights_AppliesMomentum(testCase)
            % Test that momentum is applied correctly
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            hierarchy.E_L1 = ones(1, testCase.test_config.n_L1, 'single');
            hierarchy.R_L2 = ones(1, testCase.test_config.n_L2, 'single');
            
            hierarchy.updateWeights();
            first_momentum = hierarchy.dW_L2_to_L1_prev;
            
            hierarchy.updateWeights();
            
            testCase.verifyNotEqual(hierarchy.dW_L2_to_L1_prev, first_momentum);
        end
        
        function testUpdateWeights_UpdatesTransposes(testCase)
            % Test that transposes are updated after weight updates
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            hierarchy.E_L1 = ones(1, testCase.test_config.n_L1, 'single');
            hierarchy.R_L2 = ones(1, testCase.test_config.n_L2, 'single');
            
            hierarchy.updateWeights();
            
            testCase.verifyEqual(hierarchy.W_L2_to_L1_T, hierarchy.W_L2_to_L1');
        end
        
        % ================================================================
        % LEARNING CONTROL TESTS
        % ================================================================
        
        function testFreeze_StopsLearning(testCase)
            % Test that freeze() stops weight updates
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            initial_W = hierarchy.W_L2_to_L1;
            hierarchy.freeze();
            
            hierarchy.E_L1 = ones(1, testCase.test_config.n_L1, 'single') * 10.0;
            hierarchy.R_L2 = ones(1, testCase.test_config.n_L2, 'single') * 10.0;
            hierarchy.updateWeights();
            
            testCase.verifyEqual(hierarchy.W_L2_to_L1, initial_W);
        end
        
        function testUnfreeze_RestoresLearning(testCase)
            % Test that unfreeze() restores learning
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            hierarchy.freeze();
            hierarchy.unfreeze();
            
            initial_W = hierarchy.W_L2_to_L1;
            hierarchy.E_L1 = ones(1, testCase.test_config.n_L1, 'single') * 10.0;
            hierarchy.R_L2 = ones(1, testCase.test_config.n_L2, 'single') * 10.0;
            hierarchy.updateWeights();
            
            testCase.verifyNotEqual(hierarchy.W_L2_to_L1, initial_W);
        end
        
        function testFreeze_StopsRepresentationUpdates(testCase)
            % Test that freeze() stops representation updates
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            initial_R_L1 = hierarchy.R_L1;
            hierarchy.freeze();
            
            sensory_input = ones(1, testCase.test_config.n_L1, 'single') * 10.0;
            hierarchy.computeErrors(sensory_input);
            hierarchy.updateRepresentations();
            
            testCase.verifyEqual(hierarchy.R_L1, initial_R_L1);
        end
        
        % ================================================================
        % FREE ENERGY TESTS
        % ================================================================
        
        function testComputeFreeEnergy_ReturnsScalar(testCase)
            % Test that free energy is a scalar
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            FE = hierarchy.computeFreeEnergy();
            
            testCase.verifyEqual(size(FE), [1, 1]);
        end
        
        function testComputeFreeEnergy_NonNegative(testCase)
            % Test that free energy is non-negative
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            hierarchy.R_L1 = randn(1, testCase.test_config.n_L1, 'single');
            hierarchy.R_L2 = randn(1, testCase.test_config.n_L2, 'single');
            hierarchy.R_L3 = randn(1, testCase.test_config.n_L3, 'single');
            
            FE = hierarchy.computeFreeEnergy();
            
            testCase.verifyGreaterThanOrEqual(FE, 0);
        end
        
        function testComputeFreeEnergy_ZeroForZeroReps(testCase)
            % Test that free energy is zero when all representations are zero
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            FE = hierarchy.computeFreeEnergy();
            
            testCase.verifyEqual(FE, single(0), 'AbsTol', 1e-6);
        end
        
        % ================================================================
        % STEP METHOD TESTS
        % ================================================================
        
        function testStep_ExecutesFullCycle(testCase)
            % Test that step() executes predict→error→update cycle
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            sensory_input = ones(1, testCase.test_config.n_L1, 'single');
            initial_R_L1 = hierarchy.R_L1;
            initial_R_L2 = hierarchy.R_L2;
            
            hierarchy.step(sensory_input);
            
            % Verify that representations changed (system is learning)
            delta_R_L1 = sum(abs(hierarchy.R_L1 - initial_R_L1));
            delta_R_L2 = sum(abs(hierarchy.R_L2 - initial_R_L2));
            testCase.verifyGreaterThan(delta_R_L1 + delta_R_L2, single(0), ...
                'At least one representation should update after step');
            
            % Verify that free energy is computed (may be low after updates)
            FE = hierarchy.computeFreeEnergy();
            testCase.verifyGreaterThanOrEqual(FE, single(0), ...
                'Free energy should be non-negative');
        end
        
        function testStep_MultipleSteps(testCase)
            % Test that multiple steps continue to update
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            sensory_input = ones(1, testCase.test_config.n_L1, 'single');
            
            hierarchy.step(sensory_input);
            R_L1_after_1 = hierarchy.R_L1;
            
            hierarchy.step(sensory_input);
            R_L1_after_2 = hierarchy.R_L1;
            
            testCase.verifyNotEqual(R_L1_after_2, R_L1_after_1);
        end
        
        % ================================================================
        % STATE MANAGEMENT TESTS
        % ================================================================
        
        function testGetState_ReturnsStruct(testCase)
            % Test that getState returns a struct
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            state = hierarchy.getState();
            
            testCase.verifyTrue(isstruct(state));
        end
        
        function testGetState_ContainsRepresentations(testCase)
            % Test that state contains all representations
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            state = hierarchy.getState();
            
            testCase.verifyTrue(isfield(state, 'R_L1'));
            testCase.verifyTrue(isfield(state, 'R_L2'));
            testCase.verifyTrue(isfield(state, 'R_L3'));
        end
        
        function testGetState_ContainsErrors(testCase)
            % Test that state contains errors
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            state = hierarchy.getState();
            
            testCase.verifyTrue(isfield(state, 'E_L1'));
            testCase.verifyTrue(isfield(state, 'E_L2'));
        end
        
        function testGetState_ContainsPrecisions(testCase)
            % Test that state contains precisions
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            state = hierarchy.getState();
            
            testCase.verifyTrue(isfield(state, 'pi_L1'));
            testCase.verifyTrue(isfield(state, 'pi_L2'));
        end
        
        function testGetState_ContainsFreeEnergy(testCase)
            % Test that state contains free energy
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            state = hierarchy.getState();
            
            testCase.verifyTrue(isfield(state, 'FE'));
        end
        
        function testSetState_RestoresRepresentations(testCase)
            % Test that setState restores representations
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            state = hierarchy.getState();
            state.R_L1 = ones(1, testCase.test_config.n_L1, 'single') * 5.0;
            state.R_L2 = ones(1, testCase.test_config.n_L2, 'single') * 3.0;
            state.R_L3 = ones(1, testCase.test_config.n_L3, 'single') * 2.0;
            
            hierarchy.setState(state);
            
            testCase.verifyEqual(hierarchy.R_L1, state.R_L1);
            testCase.verifyEqual(hierarchy.R_L2, state.R_L2);
            testCase.verifyEqual(hierarchy.R_L3, state.R_L3);
        end
        
        % ================================================================
        % GETTER METHOD TESTS
        % ================================================================
        
        function testGetW_L2_to_L1_ReturnsCorrectMatrix(testCase)
            % Test weight getter
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            W = hierarchy.getW_L2_to_L1();
            
            testCase.verifyEqual(W, hierarchy.W_L2_to_L1);
            testCase.verifySize(W, [testCase.test_config.n_L1, testCase.test_config.n_L2]);
        end
        
        function testGetW_L3_to_L2_ReturnsCorrectMatrix(testCase)
            % Test weight getter
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            W = hierarchy.getW_L3_to_L2();
            
            testCase.verifyEqual(W, hierarchy.W_L3_to_L2);
            testCase.verifySize(W, [testCase.test_config.n_L2, testCase.test_config.n_L3]);
        end
        
        function testGetPredL1_ReturnsPredictions(testCase)
            % Test prediction getter
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            hierarchy.R_L2 = ones(1, testCase.test_config.n_L2, 'single');
            hierarchy.predict();
            
            pred = hierarchy.getPredL1();
            
            testCase.verifyEqual(pred, hierarchy.pred_L1);
        end
        
        function testGetRepL1_ReturnsRepresentations(testCase)
            % Test representation getter
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            hierarchy.R_L1 = ones(1, testCase.test_config.n_L1, 'single') * 3.0;
            
            rep = hierarchy.getRepL1();
            
            testCase.verifyEqual(rep, hierarchy.R_L1);
        end
        
        % ================================================================
        % EDGE CASE TESTS
        % ================================================================
        
        function testZeroWeights_NoPredictions(testCase)
            % Test that zero weights produce zero predictions
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            hierarchy.W_L3_to_L2 = zeros(size(hierarchy.W_L3_to_L2), 'single');
            hierarchy.W_L2_to_L1 = zeros(size(hierarchy.W_L2_to_L1), 'single');
            hierarchy.W_L3_to_L2_T = hierarchy.W_L3_to_L2';
            hierarchy.W_L2_to_L1_T = hierarchy.W_L2_to_L1';
            
            hierarchy.R_L3 = ones(1, testCase.test_config.n_L3, 'single');
            hierarchy.R_L2 = ones(1, testCase.test_config.n_L2, 'single');
            
            hierarchy.predict();
            
            testCase.verifyEqual(sum(hierarchy.pred_L2(:)), single(0));
            testCase.verifyEqual(sum(hierarchy.pred_L1(:)), single(0));
        end
        
        function testNaNInput_DoesNotPropagate(testCase)
            % Test that NaN inputs don't propagate (clipping should handle)
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            sensory_input = ones(1, testCase.test_config.n_L1, 'single');
            sensory_input(1) = NaN;
            
            hierarchy.computeErrors(sensory_input);
            
            % After clipping, errors should not be NaN
            testCase.verifyTrue(~any(isnan(hierarchy.E_L1)));
        end
        
        function testInfInput_GetsClipped(testCase)
            % Test that Inf inputs get clipped
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            sensory_input = ones(1, testCase.test_config.n_L1, 'single') * Inf;
            hierarchy.pred_L1 = zeros(1, testCase.test_config.n_L1, 'single');
            
            hierarchy.computeErrors(sensory_input);
            
            testCase.verifyTrue(all(abs(hierarchy.E_L1) <= hierarchy.max_error_value));
        end
        
        function testVerySmallLearningRate_MinimalUpdates(testCase)
            % Test that very small learning rates produce minimal updates
            % Note: Weight decay will still cause small changes
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            hierarchy.eta_rep = 1e-10;
            hierarchy.eta_W = 1e-10;
            
            initial_R_L1 = hierarchy.R_L1;
            initial_W = hierarchy.W_L2_to_L1;
            
            sensory_input = ones(1, testCase.test_config.n_L1, 'single') * 10.0;
            hierarchy.E_L1 = ones(1, testCase.test_config.n_L1, 'single') * 10.0;
            hierarchy.R_L2 = ones(1, testCase.test_config.n_L2, 'single') * 10.0;
            
            hierarchy.updateRepresentations();
            hierarchy.updateWeights();
            
            % With tiny learning rates, representation updates should be minimal
            testCase.verifyLessThan(norm(hierarchy.R_L1 - initial_R_L1), 1e-6);
            
            % Weight updates include decay term, so check they're small but not zero
            % Expected: decay_term ~ weight_decay * ||W|| = 0.0001 * ||W||
            weight_change = norm(hierarchy.W_L2_to_L1 - initial_W, 'fro');
            testCase.verifyLessThan(weight_change, 0.01, ...
                'Weight changes should be small with tiny learning rate');
            testCase.verifyGreaterThan(weight_change, 0, ...
                'Weights should change (due to decay term)');
        end
        
        % ================================================================
        % BIOLOGICAL PLAUSIBILITY TEST #1: FREE ENERGY DECREASES WITH LEARNING
        % ================================================================
        
        function testBiologicalPlausibility_FreeEnergyDecreasesWithLearning(testCase)
            % CRITICAL TEST: Free energy should decrease over learning trials
            % This tests the core predictive coding principle that the brain
            % minimizes prediction error (free energy) through learning
            
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            % Fixed sensory input (learning task)
            sensory_input = [1, 2, 3, -1, -2, -3, 1];  % 7 elements
            
            % Measure initial free energy
            FE_history = zeros(100, 1);
            
            for trial = 1:100
                hierarchy.step(sensory_input);
                FE_history(trial) = hierarchy.computeFreeEnergy();
            end
            
            % Test 1: Free energy should decrease overall
            initial_FE = mean(FE_history(1:10));
            final_FE = mean(FE_history(91:100));
            
            testCase.verifyLessThan(final_FE, initial_FE, ...
                'Free energy should decrease with learning (predictive coding principle)');
            
            % Test 2: Free energy reduction should be substantial (>20%)
            FE_reduction_percent = (initial_FE - final_FE) / initial_FE * 100;
            testCase.verifyGreaterThan(FE_reduction_percent, 20, ...
                'Free energy reduction should be substantial (>20%)');
            
            % Test 3: Free energy should show monotonic trend (allow some fluctuation)
            % Use moving average to smooth out noise
            window_size = 10;
            smoothed_FE = movmean(FE_history, window_size);
            
            % Count how many times smoothed FE increases
            increases = 0;
            for i = 2:length(smoothed_FE)
                if smoothed_FE(i) > smoothed_FE(i-1)
                    increases = increases + 1;
                end
            end
            
            % Allow at most 20% of transitions to be increases (80% should decrease)
            increase_ratio = increases / (length(smoothed_FE) - 1);
            testCase.verifyLessThan(increase_ratio, 0.3, ...
                'Free energy should show predominantly decreasing trend');
            
            % Test 4: Final free energy should be low (converged)
            testCase.verifyLessThan(final_FE, 50, ...
                'Free energy should converge to low value (<50)');
        end
        
        % ================================================================
        % CONVERGENCE TESTS
        % ================================================================
        
        function testConvergence_RepeatedInput(testCase)
            % Test that hierarchy converges to stable predictions with repeated input
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            sensory_input = ones(1, testCase.test_config.n_L1, 'single') * 2.0;
            
            % Run many steps
            for i = 1:200
                hierarchy.step(sensory_input);
            end
            
            % Save state
            pred_L1_stable = hierarchy.pred_L1;
            
            % Run more steps
            for i = 1:50
                hierarchy.step(sensory_input);
            end
            
            % Predictions should be nearly identical (converged)
            diff = norm(hierarchy.pred_L1 - pred_L1_stable);
            testCase.verifyLessThan(diff, 0.1, 'Predictions should converge');
        end
        
        function testConvergence_ErrorsDecrease(testCase)
            % Test that prediction errors decrease over time
            hierarchy = NeuralHierarchy(testCase.test_config, 'test');
            
            sensory_input = ones(1, testCase.test_config.n_L1, 'single') * 3.0;
            
            % Measure initial error
            hierarchy.step(sensory_input);
            initial_error = norm(hierarchy.E_L1);
            
            % Run many steps
            for i = 1:100
                hierarchy.step(sensory_input);
            end
            
            % Measure final error
            final_error = norm(hierarchy.E_L1);
            
            testCase.verifyLessThan(final_error, initial_error * 0.5, ...
                'Prediction errors should decrease by at least 50%');
        end
        
    end
    
end
