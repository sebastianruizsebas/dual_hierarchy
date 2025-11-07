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
            % Extract velocity command from L1 velocity predictions
            % Returns 3D velocity vector
            
            % Get predicted velocities (what motor system predicts it will do)
            vel_pred = obj.pred_L1(obj.idx_vel);
            
            % Scale by motor gain
            vel_cmd = obj.motor_gain * vel_pred;
            
            % Unpack into x, y, z components (with bounds checking)
            vx = 0; vy = 0; vz = 0;
            if numel(vel_cmd) >= 1, vx = vel_cmd(1); end
            if numel(vel_cmd) >= 2, vy = vel_cmd(2); end
            if numel(vel_cmd) >= 3, vz = vel_cmd(3); end
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
    end
end