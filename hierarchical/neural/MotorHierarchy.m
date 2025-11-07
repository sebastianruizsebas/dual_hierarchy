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
            
            % Get predicted velocity
            vel_pred = obj.pred_L1(obj.idx_vel);
            
            fprintf('DEBUG extractMotorCommand:\n');
            fprintf('  vel_pred: (%.2f, %.2f, %.2f)\n', vel_pred(1), vel_pred(2), vel_pred(3));
            fprintf('  motor_gain: %.4f\n', obj.motor_gain);
            fprintf('  idx_vel: [%d, %d, %d]\n', obj.idx_vel(1), obj.idx_vel(2), obj.idx_vel(3));
            
            % If prediction is zero, fall back to current velocity
            if norm(vel_pred) < 0.01
                fprintf('  -> vel_pred near zero, using R_L1\n');
                vel_pred = obj.R_L1(obj.idx_vel);
            end
            
            % Apply motor gain
            scaling = 0.8;
            vx = vel_pred(1) * obj.motor_gain * scaling;
            vy = vel_pred(2) * obj.motor_gain * scaling;
            vz = 0;
            if numel(vel_pred) >= 3
                vz = vel_pred(3) * obj.motor_gain * scaling * 0.5;
            end
            
            fprintf('  final commands: vx=%.2f, vy=%.2f, vz=%.2f\n', vx, vy, vz);
            
            % Clamp to reasonable velocity limits
            max_velocity = 2.0;
            vx = max(-max_velocity, min(max_velocity, vx));
            vy = max(-max_velocity, min(max_velocity, vy));
            vz = max(-max_velocity, min(max_velocity, vz));
        end
        
        function setPositionObservation(obj, x, y, z)
            % Set position observation in L1 (from physics/proprioception)
            obj.R_L1(obj.idx_pos) = [x, y, z];
        end
        
        function setVelocityObservation(obj, vx, vy, vz)
            % Set velocity observation in L1
            obj.R_L1(obj.idx_vel) = [vx, vy, vz];
        end
        
        function setBiasObservation(obj, bias)
            % Set bias term (constant input)
            obj.R_L1(obj.idx_bias) = bias;
        end
        
        function [x, y, z] = getPositionPrediction(obj)
            % Get predicted position from L1
            pos_pred = obj.pred_L1(obj.idx_pos);
            x = pos_pred(1);
            y = pos_pred(2);
            z = pos_pred(3);
        end
        
        function setTargetPosition(obj, x_target, y_target, z_target)
            % Set the target position that motor hierarchy should chase
            % Create an error signal that drives motor learning and commands
            
            % Get current position from observation
            current_pos = obj.R_L1(obj.idx_pos);
            current_x = current_pos(1);
            current_y = current_pos(2);
            current_z = current_pos(3);
            
            % Calculate direction to target
            dx = x_target - current_x;
            dy = y_target - current_y;
            dz = z_target - current_z;
            distance = sqrt(dx^2 + dy^2 + dz^2);
            
            % Normalize direction and create velocity target
            if distance > 0.1
                % Target velocity points toward goal
                target_speed = 1.0;  % m/s toward target
                vx_target = (dx / distance) * target_speed;
                vy_target = (dy / distance) * target_speed;
                vz_target = 0;  % No vertical movement
            else
                % At target, stop moving
                vx_target = 0;
                vy_target = 0;
                vz_target = 0;
            end
            
            % Set target velocity as L1 prediction (what we want to achieve)
            obj.pred_L1(obj.idx_vel) = [vx_target, vy_target, vz_target];
            
            % Also set position prediction to target
            obj.pred_L1(obj.idx_pos) = [x_target, y_target, z_target];
            
            % Store target for reference
            obj.target_pos_L2 = [x_target, y_target, z_target];
        end
    end
end