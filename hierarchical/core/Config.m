classdef Config < handle
    % CONFIG Configuration management for hierarchical model
    %   Loads parameters from file or struct, validates, provides defaults
    
    properties
        % Network architecture
        n_L1_motor
        n_L2_motor
        n_L3_motor
        n_L1_plan
        n_L2_plan
        n_L3_plan
        
        % Semantic indices
        idx_pos
        idx_vel
        idx_bias
        
        % Learning parameters
        eta_rep
        eta_W
        momentum
        weight_decay
        motor_gain
        
        % Simulation parameters
        dt
        T_per_trial
        n_trials
        N  % Total timesteps
        t  % Time vector
        
        % Physics parameters
        gravity
        restitution
        ground_friction
        air_drag
        
        % Workspace bounds
        workspace_bounds  % 3x2 matrix [min, max] for x,y,z
        
        % Task configuration
        target_trajectories  % Cell array of trajectory structs
        
        % Logging
        log_level  % 'DEBUG', 'INFO', 'WARN', 'ERROR'
        
        % Safety bounds
        max_weight_value
        max_precision_value
        max_error_value
    end
    
    methods
        function obj = Config(source)
            % Constructor: load from file or struct
            %   source: filepath (string) or params struct
            
            if ischar(source) || isstring(source)
                % Load from file
                obj.loadFromFile(source);
            elseif isstruct(source)
                % Load from struct (e.g., PSO params)
                obj.loadFromStruct(source);
            else
                error('Config source must be filepath or struct');
            end
            
            % Apply defaults for missing fields
            obj.applyDefaults();
            
            % Validate configuration
            obj.validate();
            
            % Compute derived parameters
            obj.computeDerived();
        end
        
        function loadFromFile(obj, filepath)
            % Load configuration from YAML or MAT file
            [~, ~, ext] = fileparts(filepath);
            
            switch ext
                case '.mat'
                    data = load(filepath);
                    obj.loadFromStruct(data);
                case {'.yaml', '.yml'}
                    % Requires yaml toolbox or custom parser
                    data = yaml.ReadYaml(filepath);
                    obj.loadFromStruct(data);
                otherwise
                    error('Unsupported config file format: %s', ext);
            end
        end
        
        function loadFromStruct(obj, params)
            % Load parameters from struct (copy all fields)
            fields = fieldnames(params);
            for i = 1:length(fields)
                field = fields{i};
                if isprop(obj, field)
                    obj.(field) = params.(field);
                end
            end
        end
        
        function applyDefaults(obj)
            % Apply default values for missing parameters
            
            % Network architecture defaults
            if isempty(obj.n_L1_motor), obj.n_L1_motor = 7; end
            if isempty(obj.n_L2_motor), obj.n_L2_motor = 20; end
            if isempty(obj.n_L3_motor), obj.n_L3_motor = 10; end
            if isempty(obj.n_L1_plan), obj.n_L1_plan = 7; end
            if isempty(obj.n_L2_plan), obj.n_L2_plan = 15; end
            if isempty(obj.n_L3_plan), obj.n_L3_plan = 8; end
            
            % Semantic indices
            if isempty(obj.idx_pos), obj.idx_pos = 1:3; end
            if isempty(obj.idx_vel), obj.idx_vel = 4:6; end
            if isempty(obj.idx_bias), obj.idx_bias = 7; end
            
            % Learning parameters
            if isempty(obj.eta_rep), obj.eta_rep = 0.01; end
            if isempty(obj.eta_W), obj.eta_W = 0.001; end
            if isempty(obj.momentum), obj.momentum = 0.9; end
            if isempty(obj.weight_decay), obj.weight_decay = 0.98; end
            if isempty(obj.motor_gain), obj.motor_gain = 1.0; end
            
            % Simulation parameters
            if isempty(obj.dt), obj.dt = 0.02; end
            if isempty(obj.T_per_trial), obj.T_per_trial = 50; end
            if isempty(obj.n_trials), obj.n_trials = 3; end
            
            % Physics
            if isempty(obj.gravity), obj.gravity = 9.81; end
            if isempty(obj.restitution), obj.restitution = 0.75; end
            if isempty(obj.ground_friction), obj.ground_friction = 0.90; end
            if isempty(obj.air_drag), obj.air_drag = 0.001; end
            
            % Workspace bounds
            if isempty(obj.workspace_bounds)
                obj.workspace_bounds = [-5, 5; -5, 5; 0, 5];
            end
            
            % Logging
            if isempty(obj.log_level), obj.log_level = 'INFO'; end
            
            % Safety bounds
            if isempty(obj.max_weight_value), obj.max_weight_value = 100; end
            if isempty(obj.max_precision_value), obj.max_precision_value = 500; end
            if isempty(obj.max_error_value), obj.max_error_value = 10; end
        end
        
        function validate(obj)
            % Validate configuration consistency
            
            % Network dimensions must be positive integers
            assert(obj.n_L1_motor > 0 && obj.n_L2_motor > 0 && obj.n_L3_motor > 0, ...
                'Motor hierarchy dimensions must be positive');
            assert(obj.n_L1_plan > 0 && obj.n_L2_plan > 0 && obj.n_L3_plan > 0, ...
                'Planning hierarchy dimensions must be positive');
            
            % Semantic indices must fit in L1
            assert(max(obj.idx_pos) <= obj.n_L1_motor, ...
                'Position indices exceed motor L1 dimension');
            assert(max(obj.idx_vel) <= obj.n_L1_motor, ...
                'Velocity indices exceed motor L1 dimension');
            assert(obj.idx_bias <= obj.n_L1_motor, ...
                'Bias index exceeds motor L1 dimension');
            
            % Learning rates must be positive
            assert(obj.eta_rep > 0 && obj.eta_W > 0, ...
                'Learning rates must be positive');
            
            % Timestep must be positive
            assert(obj.dt > 0, 'Timestep must be positive');
            
            % Workspace bounds must be valid
            assert(size(obj.workspace_bounds, 1) == 3, ...
                'Workspace bounds must be 3x2 matrix');
            assert(all(obj.workspace_bounds(:,1) < obj.workspace_bounds(:,2)), ...
                'Workspace bounds: min must be < max');
        end
        
        function computeDerived(obj)
            % Compute derived parameters from base config
            
            % Total simulation time and timesteps
            T = obj.T_per_trial * obj.n_trials;
            obj.t = 0:obj.dt:T;
            obj.N = length(obj.t);
        end
        
        function saveToFile(obj, filepath)
            % Save configuration to MAT file
            params = obj.toStruct();
            save(filepath, '-struct', 'params');
        end
        
        function s = toStruct(obj)
            % Convert config object to struct (for saving/passing)
            props = properties(obj);
            s = struct();
            for i = 1:length(props)
                s.(props{i}) = obj.(props{i});
            end
        end
    end
    
    methods (Static)
        function createFromParams(params, output_file)
            % Convert old params struct to new config file
            %   Utility for migrating from old code
            
            config = Config(params);
            config.saveToFile(output_file);
            fprintf('Created config file: %s\n', output_file);
        end
    end
end