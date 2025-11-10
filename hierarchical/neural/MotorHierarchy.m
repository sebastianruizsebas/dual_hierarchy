classdef MotorHierarchy < NeuralHierarchy
    % MOTORHIERARCHY Motor-specific predictive coding hierarchy
    %   Extends NeuralHierarchy with motor-specific features:
    %   - Semantic indexing (position, velocity, bias)
    %   - Motor command extraction
    %   - Velocity control predictions
    
    properties
        % Semantic indices into L1 representation
        idx_pos   % Position indices (e.g., 1:3)
        idx_vel   % Velocity indices (e.g., 4:6)
        idx_bias  % Bias index (e.g., 7)
        
        % Motor output parameters
        motor_gain  % Scaling factor for velocity commands
        target_pos_L2  % Target position from planning hierarchy
    end
    
    methods
        function obj = MotorHierarchy(config)
            % Call parent constructor
            obj@NeuralHierarchy(config, 'motor');
            
            % Motor-specific indices
            obj.idx_pos = config.idx_pos;
            obj.idx_vel = config.idx_vel;
            obj.idx_bias = config.idx_bias;
            
            % Motor gain
            if isfield(config, 'motor_gain')
                obj.motor_gain = config.motor_gain;
            else
                obj.motor_gain = 1.0;
            end
            
            % Validate semantic indices
            obj.validateIndices();
        end
        
        function validateIndices(obj)
            % Ensure indices are within bounds
            assert(max(obj.idx_pos) <= obj.n_L1, ...
                'Position indices exceed L1 dimension');
            assert(max(obj.idx_vel) <= obj.n_L1, ...
                'Velocity indices exceed L1 dimension');
            assert(obj.idx_bias <= obj.n_L1, ...
                'Bias index exceeds L1 dimension');
        end
        
        function [vx, vy, vz] = extractMotorCommand(obj)
            % Extract velocity commands from representation
            
            % Get goal direction
            goal_direction = obj.R_L1(obj.idx_vel);
            distance_to_goal = norm(goal_direction);
            
            % Adaptive gain: increase gain when close to target
            if distance_to_goal < 1.0
                k_p = 5.0;  % Higher gain when close
            else
                k_p = 2.0;  % Normal gain when far
            end
            
            % Generate velocities proportional to distance
            vx = k_p * goal_direction(1);
            vy = k_p * goal_direction(2);
            vz = k_p * goal_direction(3);
            
            % Apply motor gain
            vx = obj.motor_gain * vx;
            vy = obj.motor_gain * vy;
            vz = obj.motor_gain * vz;
            
            % Safety limits
            max_velocity = 5.0;
            vx = max(-max_velocity, min(max_velocity, vx));
            vy = max(-max_velocity, min(max_velocity, vy));
            vz = max(-max_velocity, min(max_velocity, vz));
        end
        
        function setPositionObservation(obj, x_pos, y_pos, z_pos)
            % Set player position observation at L1
            obj.R_L1(obj.idx_pos) = [x_pos, y_pos, z_pos];
        end
        
        function setVelocityObservation(obj, vx_vel, vy_vel, vz_vel)
            % Set player velocity observation at L1
            obj.R_L1(obj.idx_vel) = [vx_vel, vy_vel, vz_vel];
        end
        
        function setBiasObservation(obj, bias_value)
            % Set bias observation (always 1.0)
            obj.R_L1(obj.idx_bias) = bias_value;
        end
        
        function [x, y, z] = getPositionPrediction(obj)
            % Get predicted position from L1
            pos_pred = obj.pred_L1(obj.idx_pos);
            x = pos_pred(1);
            y = pos_pred(2);
            z = pos_pred(3);
        end
        
        function setTargetPosition(obj, x_target, y_target, z_target)
            % Set target position for motor control
            % This modifies the representation to drive movement toward the goal
            
            target_pos = [x_target, y_target, z_target];
            current_pos = obj.R_L1(obj.idx_pos);
            
            % Compute direction to target
            direction = target_pos - current_pos;
            distance = norm(direction);
            
            if distance > 0.01
                % Normalize and scale
                direction = direction / distance;
                
                % Add goal-directed bias to L2 representation
                % This creates a "pull" toward the target
                goal_signal = direction * min(distance, 1.0);  % Saturate at 1.0
                
                % Modulate L2 to encode goal direction
                obj.R_L2(1:3) = obj.R_L2(1:3) + 0.1 * goal_signal;
            end
        end
        
        function step(obj, sensory_input)
            % Single step: predict → observe → error → update → learn
            % Override parent to ensure L1 is set to sensory input (not accumulated)
            
            obj.predict();  % Generate predictions from L2, L3
            obj.R_L1 = sensory_input;  % SET (not accumulate) sensory input
            obj.computeErrors(sensory_input);
            obj.updateRepresentations();  % Updates L2, L3 only (L1 stays at observation)
            obj.updateWeights();  % Learn from errors
        end
    end
end