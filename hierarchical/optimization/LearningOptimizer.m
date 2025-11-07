classdef LearningOptimizer < handle
    % LEARNINGOPTIMIZER Advanced gradient-based optimization for neural weights
    %   Implements Adam, RMSprop, and momentum-based optimizers
    
    properties
        algorithm  % 'sgd', 'momentum', 'adam', 'rmsprop'
        
        % Hyperparameters
        learning_rate
        momentum_coeff
        beta1  % Adam first moment decay
        beta2  % Adam second moment decay
        epsilon  % Numerical stability constant
        
        % Optimizer state
        velocity  % Momentum/Adam first moment
        square_grad  % Adam/RMSprop second moment
        timestep  % Iteration counter for Adam bias correction
    end
    
    methods
        function obj = LearningOptimizer(algorithm, config)
            % Constructor
            %   algorithm: 'sgd', 'momentum', 'adam', 'rmsprop'
            %   config: struct with hyperparameters
            
            obj.algorithm = lower(algorithm);
            obj.timestep = 0;
            
            % Set hyperparameters
            if isfield(config, 'learning_rate')
                obj.learning_rate = config.learning_rate;
            else
                obj.learning_rate = 0.001;
            end
            
            if isfield(config, 'momentum')
                obj.momentum_coeff = config.momentum;
            else
                obj.momentum_coeff = 0.9;
            end
            
            if isfield(config, 'beta1')
                obj.beta1 = config.beta1;
            else
                obj.beta1 = 0.9;
            end
            
            if isfield(config, 'beta2')
                obj.beta2 = config.beta2;
            else
                obj.beta2 = 0.999;
            end
            
            obj.epsilon = 1e-8;
        end
        
        function initializeState(obj, weight_shape)
            % Initialize optimizer state for given weight matrix shape
            
            switch obj.algorithm
                case 'momentum'
                    obj.velocity = zeros(weight_shape, 'single');
                case 'adam'
                    obj.square_grad = zeros(weight_shape, 'single');
                case 'rmsprop'
                    obj.square_grad = zeros(weight_shape, 'single');
            end
        end
        
        function weights_new = step(obj, weights, gradient)
            % Perform single optimization step
            %   weights: current weight matrix
            %   gradient: computed gradient
            %   Returns: updated weights
            
            obj.timestep = obj.timestep + 1;
            
            switch obj.algorithm
                case 'sgd'
                    weights_new = obj.stepSGD(weights, gradient);
                case 'momentum'
                    weights_new = obj.stepMomentum(weights, gradient);
                case 'adam'
                    weights_new = obj.stepAdam(weights, gradient);
                case 'rmsprop'
                    weights_new = obj.stepRMSprop(weights, gradient);
                otherwise
                    error('Unknown optimizer algorithm: %s', obj.algorithm);
            end
        end
        
        function weights_new = stepSGD(obj, weights, gradient)
            % Vanilla stochastic gradient descent
            weights_new = weights - obj.learning_rate * gradient;
        end
        
        function weights_new = stepMomentum(obj, weights, gradient)
            % SGD with momentum
            
            % Initialize velocity if needed
            if isempty(obj.velocity)
                obj.velocity = zeros(size(weights), 'single');
            end
            
            % Update velocity (exponential moving average of gradients)
            obj.velocity = obj.momentum_coeff * obj.velocity + gradient;
            
            % Update weights
            weights_new = weights - obj.learning_rate * obj.velocity;
        end
        
        function weights_new = stepAdam(obj, weights, gradient)
            % Adam optimizer (adaptive moment estimation)
            
            % Initialize moments if needed
            if isempty(obj.velocity)
                obj.velocity = zeros(size(weights), 'single');
                obj.square_grad = zeros(size(weights), 'single');
            end
            
            % Update biased first moment estimate
            obj.velocity = obj.beta1 * obj.velocity + (1 - obj.beta1) * gradient;
            
            % Update biased second raw moment estimate
            obj.square_grad = obj.beta2 * obj.square_grad + (1 - obj.beta2) * (gradient.^2);
            
            % Compute bias-corrected moments
            velocity_corrected = obj.velocity / (1 - obj.beta1^obj.timestep);
            square_grad_corrected = obj.square_grad / (1 - obj.beta2^obj.timestep);
            
            % Update weights
            weights_new = weights - obj.learning_rate * velocity_corrected ./ ...
                         (sqrt(square_grad_corrected) + obj.epsilon);
        end
        
        function weights_new = stepRMSprop(obj, weights, gradient)
            % RMSprop optimizer
            
            % Initialize squared gradient if needed
            if isempty(obj.square_grad)
                obj.square_grad = zeros(size(weights), 'single');
            end
            
            % Update squared gradient moving average
            obj.square_grad = obj.beta2 * obj.square_grad + (1 - obj.beta2) * (gradient.^2);
            
            % Update weights
            weights_new = weights - obj.learning_rate * gradient ./ ...
                         (sqrt(obj.square_grad) + obj.epsilon);
        end
        
        function reset(obj)
            % Reset optimizer state (e.g., between trials)
            obj.velocity = [];
            obj.square_grad = [];
            obj.timestep = 0;
        end
    end
end