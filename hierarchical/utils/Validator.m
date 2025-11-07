classdef Validator
    % VALIDATOR Static validation utilities for hierarchical model
    %   Provides fail-fast validation for configs, states, and parameters
    
    methods (Static)
        function validateConfig(config)
            % Validate entire configuration struct
            
            % Network dimensions
            Validator.validatePositiveInteger(config.n_L1_motor, 'n_L1_motor');
            Validator.validatePositiveInteger(config.n_L2_motor, 'n_L2_motor');
            Validator.validatePositiveInteger(config.n_L3_motor, 'n_L3_motor');
            Validator.validatePositiveInteger(config.n_L1_plan, 'n_L1_plan');
            Validator.validatePositiveInteger(config.n_L2_plan, 'n_L2_plan');
            Validator.validatePositiveInteger(config.n_L3_plan, 'n_L3_plan');
            
            % Semantic indices
            Validator.validateIndices(config.idx_pos, config.n_L1_motor, 'idx_pos');
            Validator.validateIndices(config.idx_vel, config.n_L1_motor, 'idx_vel');
            Validator.validateIndex(config.idx_bias, config.n_L1_motor, 'idx_bias');
            
            % Learning parameters
            Validator.validatePositiveScalar(config.eta_rep, 'eta_rep');
            Validator.validatePositiveScalar(config.eta_W, 'eta_W');
            Validator.validateInRange(config.momentum, 0, 1, 'momentum');
            Validator.validateInRange(config.weight_decay, 0, 1, 'weight_decay');
            
            % Simulation parameters
            Validator.validatePositiveScalar(config.dt, 'dt');
            Validator.validatePositiveScalar(config.T_per_trial, 'T_per_trial');
            Validator.validatePositiveInteger(config.n_trials, 'n_trials');
            
            % Workspace bounds
            Validator.validateWorkspaceBounds(config.workspace_bounds);
            
            fprintf('✅ Configuration validation passed\n');
        end
        
        function validatePositiveInteger(value, name)
            % Validate positive integer
            assert(isscalar(value), '%s must be scalar', name);
            assert(value > 0, '%s must be positive', name);
            assert(mod(value, 1) == 0, '%s must be integer', name);
        end
        
        function validatePositiveScalar(value, name)
            % Validate positive scalar (real number)
            assert(isscalar(value), '%s must be scalar', name);
            assert(isreal(value) && isfinite(value), '%s must be finite real number', name);
            assert(value > 0, '%s must be positive', name);
        end
        
        function validateInRange(value, min_val, max_val, name)
            % Validate scalar is in range [min_val, max_val]
            assert(isscalar(value), '%s must be scalar', name);
            assert(isreal(value) && isfinite(value), '%s must be finite real number', name);
            assert(value >= min_val && value <= max_val, ...
                '%s must be in range [%.2f, %.2f]', name, min_val, max_val);
        end
        
        function validateIndices(indices, max_idx, name)
            % Validate vector of indices
            assert(isvector(indices), '%s must be vector', name);
            assert(all(indices > 0), '%s must contain positive integers', name);
            assert(all(mod(indices, 1) == 0), '%s must contain integers', name);
            assert(max(indices) <= max_idx, ...
                '%s exceeds maximum index %d', name, max_idx);
            assert(length(unique(indices)) == length(indices), ...
                '%s must contain unique indices', name);
        end
        
        function validateIndex(idx, max_idx, name)
            % Validate single index
            assert(isscalar(idx), '%s must be scalar', name);
            assert(idx > 0, '%s must be positive', name);
            assert(mod(idx, 1) == 0, '%s must be integer', name);
            assert(idx <= max_idx, '%s exceeds maximum index %d', name, max_idx);
        end
        
        function validateWorkspaceBounds(bounds)
            % Validate workspace bounds (3x2 matrix)
            assert(isequal(size(bounds), [3, 2]), ...
                'Workspace bounds must be 3x2 matrix');
            assert(all(isfinite(bounds(:))), ...
                'Workspace bounds must be finite');
            assert(all(bounds(:,1) < bounds(:,2)), ...
                'Workspace bounds: min must be < max for all dimensions');
        end
        
        function [values, was_clipped] = clipValues(values, bounds, name)
            % Clip values to bounds and report if clipping occurred
            %   values: array to clip
            %   bounds: [min, max]
            %   name: variable name (for warning message)
            
            was_clipped = any(values < bounds(1) | values > bounds(2));
            
            if was_clipped
                warning('Validator:Clipping', ...
                    '%s exceeded bounds [%.2e, %.2e] - clipping applied', ...
                    name, bounds(1), bounds(2));
            end
            
            values = max(bounds(1), min(bounds(2), values));
        end
        
        function validateFinite(values, name)
            % Validate all values are finite (no NaN/Inf)
            if any(~isfinite(values(:)))
                error('Validator:NonFinite', ...
                    '%s contains NaN or Inf values', name);
            end
        end
        
        function validateDimensions(matrix, expected_size, name)
            % Validate matrix dimensions
            actual_size = size(matrix);
            assert(isequal(actual_size, expected_size), ...
                '%s has incorrect dimensions. Expected [%s], got [%s]', ...
                name, num2str(expected_size), num2str(actual_size));
        end
        
        function validateHierarchyState(hierarchy)
            % Validate neural hierarchy state consistency
            
            % Check dimensions match
            n_L1 = hierarchy.n_L1;
            n_L2 = hierarchy.n_L2;
            n_L3 = hierarchy.n_L3;
            
            Validator.validateDimensions(hierarchy.R_L1, [1, n_L1], 'R_L1');
            Validator.validateDimensions(hierarchy.R_L2, [1, n_L2], 'R_L2');
            Validator.validateDimensions(hierarchy.R_L3, [1, n_L3], 'R_L3');
            
            Validator.validateDimensions(hierarchy.W_L3_to_L2, [n_L2, n_L3], 'W_L3_to_L2');
            Validator.validateDimensions(hierarchy.W_L2_to_L1, [n_L1, n_L2], 'W_L2_to_L1');
            
            % Check for non-finite values
            Validator.validateFinite(hierarchy.R_L1, 'R_L1');
            Validator.validateFinite(hierarchy.R_L2, 'R_L2');
            Validator.validateFinite(hierarchy.R_L3, 'R_L3');
            Validator.validateFinite(hierarchy.W_L3_to_L2, 'W_L3_to_L2');
            Validator.validateFinite(hierarchy.W_L2_to_L1, 'W_L2_to_L1');
        end
    end
end