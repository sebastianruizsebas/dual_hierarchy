classdef NeuralHierarchy < handle
    % NEURALHIERARCHY Base class for predictive coding hierarchies
    %   Implements core prediction, error computation, and learning
    
    properties (Access = protected)
        % Layer dimensions
        n_L1  % Sensory layer size
        n_L2  % Middle layer size
        n_L3  % Top layer size
        
        % Weight matrices (feedforward predictions)
        W_L3_to_L2  % Top-down to middle
        W_L2_to_L1  % Middle-down to sensory
        
        % Weight matrix transposes (cached for performance)
        W_L3_to_L2_T
        W_L2_to_L1_T
        
        % Momentum matrices for learning
        dW_L3_to_L2_prev
        dW_L2_to_L1_prev
        
        % Layer states (current timestep)
        R_L1  % Sensory layer representations
        R_L2  % Middle layer representations
        R_L3  % Top layer representations
        
        % Predictions (what each layer predicts about layer below)
        pred_L2  % L3's prediction of L2
        pred_L1  % L2's prediction of L1
        
        % Prediction errors
        E_L2  % Error at L2: R_L2 - pred_L2
        E_L1  % Error at L1: R_L1 - pred_L1
        
        % Precision (inverse variance - confidence in each error)
        pi_L1  % Precision at L1
        pi_L2  % Precision at L2
        
        % Learning parameters
        eta_rep      % Representation learning rate
        eta_W        % Weight learning rate
        momentum     % Momentum coefficient
        weight_decay % Weight decay per step
        
        % Safety bounds
        max_weight_value
        max_precision_value
        max_error_value
    end
    
    properties (Access = public)
        name  % Hierarchy identifier (e.g., 'motor', 'planning')
        frozen  % Learning frozen flag
    end
    
    methods
        function obj = NeuralHierarchy(config, name)
            % Constructor
            %   config: struct with layer dims and learning params
            %   name: string identifier
            
            obj.name = name;
            obj.frozen = false;
            
            % Extract dimensions
            obj.n_L1 = config.n_L1;
            obj.n_L2 = config.n_L2;
            obj.n_L3 = config.n_L3;
            
            % Learning parameters
            obj.eta_rep = config.eta_rep;
            obj.eta_W = config.eta_W;
            obj.momentum = config.momentum;
            obj.weight_decay = config.weight_decay;
            
            % Safety bounds
            obj.max_weight_value = config.max_weight_value;
            obj.max_precision_value = config.max_precision_value;
            obj.max_error_value = config.max_error_value;
            
            % Initialize weights (Xavier initialization)
            obj.initializeWeights();
            
            % Initialize layer states
            obj.initializeStates();
        end
        
        function initializeWeights(obj)
            % Xavier initialization for better gradient flow
            
            % W_L3_to_L2: n_L2 x n_L3
            scale_32 = sqrt(2.0 / (obj.n_L3 + obj.n_L2));
            obj.W_L3_to_L2 = scale_32 * randn(obj.n_L2, obj.n_L3, 'single');
            obj.W_L3_to_L2_T = obj.W_L3_to_L2';
            
            % W_L2_to_L1: n_L1 x n_L2
            scale_21 = sqrt(2.0 / (obj.n_L2 + obj.n_L1));
            obj.W_L2_to_L1 = scale_21 * randn(obj.n_L1, obj.n_L2, 'single');
            obj.W_L2_to_L1_T = obj.W_L2_to_L1';
            
            % Initialize momentum matrices
            obj.dW_L3_to_L2_prev = zeros(size(obj.W_L3_to_L2), 'single');
            obj.dW_L2_to_L1_prev = zeros(size(obj.W_L2_to_L1), 'single');
        end
        
        function initializeStates(obj)
            % Initialize layer representations and errors
            
            obj.R_L1 = zeros(1, obj.n_L1, 'single');
            obj.R_L2 = zeros(1, obj.n_L2, 'single');
            obj.R_L3 = zeros(1, obj.n_L3, 'single');
            
            obj.pred_L2 = zeros(1, obj.n_L2, 'single');
            obj.pred_L1 = zeros(1, obj.n_L1, 'single');
            
            obj.E_L2 = zeros(1, obj.n_L2, 'single');
            obj.E_L1 = zeros(1, obj.n_L1, 'single');
            
            % Initialize precision (moderate initial confidence)
            obj.pi_L1 = ones(1, obj.n_L1, 'single') * 10.0;
            obj.pi_L2 = ones(1, obj.n_L2, 'single') * 1.0;
        end
        
        function predict(obj)
            % Top-down predictions (feedforward through hierarchy)
            % NOTE: Uses cached transposes for performance
            
            % L3 predicts L2 state
            obj.pred_L2 = obj.R_L3 * obj.W_L3_to_L2_T;
            
            % L2 predicts L1 state
            obj.pred_L1 = obj.R_L2 * obj.W_L2_to_L1_T;
        end
        
        function computeErrors(obj, sensory_input)
            % Compute prediction errors at each layer
            %   sensory_input: observed state at L1 (1 x n_L1)
            
            % L1 error: observation vs prediction
            obj.E_L1 = sensory_input - obj.pred_L1;
            
            % L2 error: current state vs prediction from L3
            obj.E_L2 = obj.R_L2 - obj.pred_L2;
            
            % Safety: clip errors to prevent numerical instability
            obj.E_L1 = max(-obj.max_error_value, ...
                          min(obj.max_error_value, obj.E_L1));
            obj.E_L2 = max(-obj.max_error_value, ...
                          min(obj.max_error_value, obj.E_L2));
        end
        
        function updateRepresentations(obj)
            % Update layer representations via precision-weighted errors
            % Implements predictive coding dynamics
            
            if obj.frozen
                return;  % No updates if learning frozen
            end
            
            % L1 update: move toward sensory evidence
            % (precision-weighted error pulls representation toward observation)
            obj.R_L1 = obj.R_L1 + obj.eta_rep * (obj.pi_L1 .* obj.E_L1);
            
            % L2 update: balance bottom-up and top-down
            % Bottom-up: weighted error from L1
            % Top-down: weighted error from L3
            bottom_up = (obj.W_L2_to_L1' * (obj.pi_L1 .* obj.E_L1)')';
            top_down = obj.pi_L2 .* obj.E_L2;
            
            obj.R_L2 = obj.R_L2 + obj.eta_rep * (bottom_up + top_down);
            
            % L3 update: integrate error from L2
            obj.R_L3 = obj.R_L3 + obj.eta_rep * ...
                      ((obj.W_L3_to_L2' * (obj.pi_L2 .* obj.E_L2)')');
            
            % Safety: prevent runaway activations
            obj.R_L1 = max(-10, min(10, obj.R_L1));
            obj.R_L2 = max(-10, min(10, obj.R_L2));
            obj.R_L3 = max(-10, min(10, obj.R_L3));
        end
        
        function updateWeights(obj)
            if obj.frozen
                return;
            end
            
            % Compute gradients
            dW_L2_to_L1 = obj.eta_W * (obj.E_L1' * obj.R_L2);
            dW_L3_to_L2 = obj.eta_W * (obj.E_L2' * obj.R_L3);
            
            % Apply momentum
            dW_L2_to_L1 = obj.momentum * obj.dW_L2_to_L1_prev + (1 - obj.momentum) * dW_L2_to_L1;
            dW_L3_to_L2 = obj.momentum * obj.dW_L3_to_L2_prev + (1 - obj.momentum) * dW_L3_to_L2;
            
            % Update weights with L2 regularization (proper weight decay)
            obj.W_L2_to_L1 = obj.W_L2_to_L1 + dW_L2_to_L1 - obj.weight_decay * obj.W_L2_to_L1;
            obj.W_L3_to_L2 = obj.W_L3_to_L2 + dW_L3_to_L2 - obj.weight_decay * obj.W_L3_to_L2;
            
            % Store momentum
            obj.dW_L2_to_L1_prev = dW_L2_to_L1;
            obj.dW_L3_to_L2_prev = dW_L3_to_L2;
            
            % Update transposes
            obj.W_L2_to_L1_T = obj.W_L2_to_L1';
            obj.W_L3_to_L2_T = obj.W_L3_to_L2';
        end
        
        function FE = computeFreeEnergy(obj)
            % Compute total free energy as sum of squared representation magnitudes
            % This is a simplified measure until prediction errors are properly computed
            % Returns: scalar total free energy
            
            FE_L1 = sum(obj.R_L1(:).^2);
            FE_L2 = sum(obj.R_L2(:).^2);
            FE_L3 = sum(obj.R_L3(:).^2);
            
            FE = FE_L1 + FE_L2 + FE_L3;
        end
        
        function step(obj, sensory_input)
            % Single inference step
            %   1. Make predictions
            %   2. Compute errors
            %   3. Update representations
            %   4. Update weights
            
            obj.predict();
            obj.computeErrors(sensory_input);
            obj.updateRepresentations();
            obj.updateWeights();
        end
        
        function freeze(obj)
            % Freeze learning (for task-selective freezing)
            obj.frozen = true;
        end
        
        function unfreeze(obj)
            % Unfreeze learning
            obj.frozen = false;
        end
        
        function state = getState(obj)
            % Get current state snapshot (for logging/visualization)
            state.R_L1 = obj.R_L1;
            state.R_L2 = obj.R_L2;
            state.R_L3 = obj.R_L3;
            state.pred_L1 = obj.pred_L1;
            state.pred_L2 = obj.pred_L2;
            state.E_L1 = obj.E_L1;
            state.E_L2 = obj.E_L2;
            state.pi_L1 = obj.pi_L1;
            state.pi_L2 = obj.pi_L2;
            state.FE = obj.computeFreeEnergy();
        end
        
        function setState(obj, state)
            % Restore state from snapshot
            obj.R_L1 = state.R_L1;
            obj.R_L2 = state.R_L2;
            obj.R_L3 = state.R_L3;
        end
        
        % Remove these two methods - they reference non-existent properties:
        % function W = getW_L1_to_L2(obj)
        % function W = getW_L2_to_L3(obj)
        
        % Keep only these two:
        function W = getW_L2_to_L1(obj)
            % Get weight matrix from L2 to L1
            W = obj.W_L2_to_L1;
        end
        
        function W = getW_L3_to_L2(obj)
            % Get weight matrix from L3 to L2
            W = obj.W_L3_to_L2;
        end
        
        function pred = getPredL1(obj)
            % Get L1 predictions
            pred = obj.pred_L1;
        end
        
        function pred = getPredL2(obj)
            % Get L2 predictions
            pred = obj.pred_L2;
        end
        
        function pred = getPredL3(obj)
            % Get L3 predictions
            pred = obj.pred_L3;
        end
        
        function rep = getRepL1(obj)
            % Get L1 representations
            rep = obj.R_L1;
        end
        
        function rep = getRepL2(obj)
            % Get L2 representations
            rep = obj.R_L2;
        end
        
        function rep = getRepL3(obj)
            % Get L3 representations
            rep = obj.R_L3;
        end
        
        function err = getErrorL1(obj)
            % Get L1 errors
            err = obj.err_L1;
        end
        
        function err = getErrorL2(obj)
            % Get L2 errors
            err = obj.err_L2;
        end
        
        function err = getErrorL3(obj)
            % Get L3 errors
            err = obj.err_L3;
        end
    end
end