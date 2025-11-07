classdef PrecisionAdapter < handle
    % PRECISIONADAPTER Adaptive precision (confidence) weighting for hierarchies
    %   Dynamically adjusts precision based on prediction error history
    %   Implements gain scheduling for stable learning
    
    properties
        % Precision bounds for each layer
        bounds_L1_motor
        bounds_L2_motor
        bounds_L1_plan
        bounds_L2_plan
        
        % Adaptation parameters
        alpha_gain      % Base adaptation rate
        error_threshold % Error threshold for adaptation trigger
        
        % Smoothing window for error history
        window_size
        error_history_L1_motor
        error_history_L2_motor
        error_history_L1_plan
        error_history_L2_plan
        
        % Current position in circular buffer
        history_idx
        
        % Number of samples collected (for proper averaging during warmup)
        samples_collected_motor_L1
        samples_collected_motor_L2
        samples_collected_plan_L1
        samples_collected_plan_L2
        
        % Adaptation statistics (for monitoring)
        adaptation_count_motor
        adaptation_count_plan
    end
    
    methods
        function obj = PrecisionAdapter(config)
            % Constructor
            %   config: struct with precision bounds and adaptation params
            
            % Set precision bounds (min, max) for each layer
            if isfield(config, 'precision_bounds')
                bounds = config.precision_bounds;
                obj.bounds_L1_motor = bounds.L1_motor;
                obj.bounds_L2_motor = bounds.L2_motor;
                obj.bounds_L1_plan = bounds.L1_plan;
                obj.bounds_L2_plan = bounds.L2_plan;
            else
                % Default bounds
                obj.bounds_L1_motor = [1, 500];
                obj.bounds_L2_motor = [0.1, 50];
                obj.bounds_L1_plan = [1, 500];
                obj.bounds_L2_plan = [0.1, 50];
            end
            
            % Adaptation parameters
            if isfield(config, 'alpha_gain')
                obj.alpha_gain = config.alpha_gain;
            else
                obj.alpha_gain = 0.5;  % Conservative default
            end
            
            if isfield(config, 'error_threshold')
                obj.error_threshold = config.error_threshold;
            else
                obj.error_threshold = 0.1;
            end
            
            % Error history window (for smoothing)
            obj.window_size = 50;
            obj.error_history_L1_motor = zeros(obj.window_size, 1);
            obj.error_history_L2_motor = zeros(obj.window_size, 1);
            obj.error_history_L1_plan = zeros(obj.window_size, 1);
            obj.error_history_L2_plan = zeros(obj.window_size, 1);
            obj.history_idx = 1;
            
            % Sample counters (for proper averaging during warmup)
            obj.samples_collected_motor_L1 = 0;
            obj.samples_collected_motor_L2 = 0;
            obj.samples_collected_plan_L1 = 0;
            obj.samples_collected_plan_L2 = 0;
            
            % Statistics
            obj.adaptation_count_motor = 0;
            obj.adaptation_count_plan = 0;
        end
        
        function pi_L1 = adaptMotorL1(obj, pi_L1_current, error_L1)
            % Adapt motor L1 precision based on prediction error
            %   pi_L1_current: current precision values (1 x n_L1)
            %   error_L1: prediction error (1 x n_L1)
            %   Returns: updated precision values
            
            % Compute error magnitude (RMS across features)
            error_magnitude = sqrt(mean(error_L1.^2));
            
            % Update error history (circular buffer)
            obj.error_history_L1_motor(obj.history_idx) = error_magnitude;
            obj.samples_collected_motor_L1 = min(obj.samples_collected_motor_L1 + 1, obj.window_size);
            
            % Compute smoothed error (only over collected samples)
            if obj.samples_collected_motor_L1 < obj.window_size
                % During warmup: average only collected samples
                smoothed_error = mean(obj.error_history_L1_motor(1:obj.samples_collected_motor_L1));
            else
                % After warmup: average full window
                smoothed_error = mean(obj.error_history_L1_motor);
            end
            
            % Adaptation rule: increase precision if error is low (confident)
            %                  decrease precision if error is high (uncertain)
            if smoothed_error < obj.error_threshold
                % Low error -> increase confidence (higher precision)
                adaptation = 1 + obj.alpha_gain * (obj.error_threshold - smoothed_error);
            else
                % High error -> decrease confidence (lower precision)
                adaptation = 1 - obj.alpha_gain * (smoothed_error - obj.error_threshold);
            end
            
            % Clamp adaptation to prevent extreme changes
            adaptation = max(0.5, min(2.0, adaptation));
            
            % Apply adaptation with bounds
            pi_L1 = pi_L1_current * adaptation;
            pi_L1 = max(obj.bounds_L1_motor(1), min(obj.bounds_L1_motor(2), pi_L1));
            
            % Track adaptations
            if abs(adaptation - 1.0) > 0.01
                obj.adaptation_count_motor = obj.adaptation_count_motor + 1;
            end
        end
        
        function pi_L2 = adaptMotorL2(obj, pi_L2_current, error_L2)
            % Adapt motor L2 precision
            
            error_magnitude = sqrt(mean(error_L2.^2));
            obj.error_history_L2_motor(obj.history_idx) = error_magnitude;
            obj.samples_collected_motor_L2 = min(obj.samples_collected_motor_L2 + 1, obj.window_size);
            
            if obj.samples_collected_motor_L2 < obj.window_size
                smoothed_error = mean(obj.error_history_L2_motor(1:obj.samples_collected_motor_L2));
            else
                smoothed_error = mean(obj.error_history_L2_motor);
            end
            
            if smoothed_error < obj.error_threshold
                adaptation = 1 + obj.alpha_gain * (obj.error_threshold - smoothed_error);
            else
                adaptation = 1 - obj.alpha_gain * (smoothed_error - obj.error_threshold);
            end
            
            adaptation = max(0.5, min(2.0, adaptation));
            
            pi_L2 = pi_L2_current * adaptation;
            pi_L2 = max(obj.bounds_L2_motor(1), min(obj.bounds_L2_motor(2), pi_L2));
        end
        
        function pi_L1 = adaptPlanningL1(obj, pi_L1_current, error_L1)
            % Adapt planning L1 precision
            
            error_magnitude = sqrt(mean(error_L1.^2));
            obj.error_history_L1_plan(obj.history_idx) = error_magnitude;
            obj.samples_collected_plan_L1 = min(obj.samples_collected_plan_L1 + 1, obj.window_size);
            
            if obj.samples_collected_plan_L1 < obj.window_size
                smoothed_error = mean(obj.error_history_L1_plan(1:obj.samples_collected_plan_L1));
            else
                smoothed_error = mean(obj.error_history_L1_plan);
            end
            
            if smoothed_error < obj.error_threshold
                adaptation = 1 + obj.alpha_gain * (obj.error_threshold - smoothed_error);
            else
                adaptation = 1 - obj.alpha_gain * (smoothed_error - obj.error_threshold);
            end
            
            adaptation = max(0.5, min(2.0, adaptation));
            
            pi_L1 = pi_L1_current * adaptation;
            pi_L1 = max(obj.bounds_L1_plan(1), min(obj.bounds_L1_plan(2), pi_L1));
            
            if abs(adaptation - 1.0) > 0.01
                obj.adaptation_count_plan = obj.adaptation_count_plan + 1;
            end
        end
        
        function pi_L2 = adaptPlanningL2(obj, pi_L2_current, error_L2)
            % Adapt planning L2 precision
            
            error_magnitude = sqrt(mean(error_L2.^2));
            obj.error_history_L2_plan(obj.history_idx) = error_magnitude;
            obj.samples_collected_plan_L2 = min(obj.samples_collected_plan_L2 + 1, obj.window_size);
            
            if obj.samples_collected_plan_L2 < obj.window_size
                smoothed_error = mean(obj.error_history_L2_plan(1:obj.samples_collected_plan_L2));
            else
                smoothed_error = mean(obj.error_history_L2_plan);
            end
            
            if smoothed_error < obj.error_threshold
                adaptation = 1 + obj.alpha_gain * (obj.error_threshold - smoothed_error);
            else
                adaptation = 1 - obj.alpha_gain * (smoothed_error - obj.error_threshold);
            end
            
            adaptation = max(0.5, min(2.0, adaptation));
            
            pi_L2 = pi_L2_current * adaptation;
            pi_L2 = max(obj.bounds_L2_plan(1), min(obj.bounds_L2_plan(2), pi_L2));
        end
        
        function stepHistory(obj)
            % Advance circular buffer index
            obj.history_idx = mod(obj.history_idx, obj.window_size) + 1;
        end
        
        function reset(obj)
            % Reset adaptation history (e.g., between trials)
            obj.error_history_L1_motor(:) = 0;
            obj.error_history_L2_motor(:) = 0;
            obj.error_history_L1_plan(:) = 0;
            obj.error_history_L2_plan(:) = 0;
            obj.history_idx = 1;
            obj.samples_collected_motor_L1 = 0;
            obj.samples_collected_motor_L2 = 0;
            obj.samples_collected_plan_L1 = 0;
            obj.samples_collected_plan_L2 = 0;
            obj.adaptation_count_motor = 0;
            obj.adaptation_count_plan = 0;
        end
        
        function stats = getStatistics(obj)
            % Get adaptation statistics
            stats = struct();
            stats.motor_adaptations = obj.adaptation_count_motor;
            stats.plan_adaptations = obj.adaptation_count_plan;
            
            % Use only collected samples for statistics
            if obj.samples_collected_motor_L1 > 0
                stats.motor_L1_error_mean = mean(obj.error_history_L1_motor(1:obj.samples_collected_motor_L1));
            else
                stats.motor_L1_error_mean = 0;
            end
            
            if obj.samples_collected_motor_L2 > 0
                stats.motor_L2_error_mean = mean(obj.error_history_L2_motor(1:obj.samples_collected_motor_L2));
            else
                stats.motor_L2_error_mean = 0;
            end
            
            if obj.samples_collected_plan_L1 > 0
                stats.plan_L1_error_mean = mean(obj.error_history_L1_plan(1:obj.samples_collected_plan_L1));
            else
                stats.plan_L1_error_mean = 0;
            end
            
            if obj.samples_collected_plan_L2 > 0
                stats.plan_L2_error_mean = mean(obj.error_history_L2_plan(1:obj.samples_collected_plan_L2));
            else
                stats.plan_L2_error_mean = 0;
            end
        end
    end
end