classdef Config < handle
    % CONFIG Configuration management for hierarchical model
    %   Manages all configuration parameters for hierarchies, physics, and learning
    
    properties
        config_struct           % Original config struct (reference)
        
        % Generic layer sizes (set based on hierarchy type)
        n_L1                    % Current L1 size
        n_L2                    % Current L2 size
        n_L3                    % Current L3 size
        
        % Motor-specific layer sizes
        n_L1_motor
        n_L2_motor
        n_L3_motor
        
        % Planning-specific layer sizes
        n_L1_plan
        n_L2_plan
        n_L3_plan
        
        % Physics parameters
        gravity
        air_drag
        restitution
        ground_friction
        workspace_bounds
        dt
        
        % Learning parameters
        eta_rep                 % Representation learning rate
        eta_W                   % Weight learning rate
        momentum                % Momentum for weight updates
        weight_decay            % L2 regularization
        motor_gain              % Scaling for motor commands
        max_weight_value        % Maximum weight magnitude
        max_error_value
        max_precision_value         % Maximum error magnitude
        
        % Trial parameters
        T_per_trial             % Duration of one trial (steps)
        n_trials                % Number of trials
        N                       % Total number of timesteps
        
        % Noise parameters
        noise_enabled
        position_noise_std
        velocity_noise_std
        noise_type
        
        % Visuomotor delay parameters
        visual_latency_ms
        enable_delay
        prediction_horizon_ms
        
        % Logging parameters
        log_level
        
        % Semantic indices (for motor/planning hierarchies)
        idx_pos                 % Position indices in L1 [1,2,3]
        idx_vel                 % Velocity indices in L1 [4,5,6]
        idx_bias                % Bias index in L1 [7]
        
        % Task configuration (for planning hierarchy)
        n_tasks
        
        % Target trajectories (for multi-target learning)
        target_trajectories
    end
    
    methods
        function obj = Config(config_struct)
            % Constructor: initialize from struct
            obj.config_struct = config_struct;
            obj.applyDefaults();
        end
        
        function applyDefaults(obj)
            % Apply default values for all configuration parameters
            cfg = obj.config_struct;
            
            % ========== NETWORK ARCHITECTURE ==========
            % Motor hierarchy
            obj.n_L1_motor = obj.getField(cfg, 'n_L1_motor', 7);
            obj.n_L2_motor = obj.getField(cfg, 'n_L2_motor', 20);
            obj.n_L3_motor = obj.getField(cfg, 'n_L3_motor', 10);
            
            % Planning hierarchy
            obj.n_L1_plan = obj.getField(cfg, 'n_L1_plan', 7);
            obj.n_L2_plan = obj.getField(cfg, 'n_L2_plan', 15);
            obj.n_L3_plan = obj.getField(cfg, 'n_L3_plan', 8);
            
            % ========== PHYSICS PARAMETERS ==========
            obj.gravity = obj.getField(cfg, 'gravity', 9.81);
            obj.air_drag = obj.getField(cfg, 'air_drag', 0.01);
            obj.restitution = obj.getField(cfg, 'restitution', 0.95);
            obj.ground_friction = obj.getField(cfg, 'ground_friction', 0.9);
            obj.workspace_bounds = obj.getField(cfg, 'workspace_bounds', [-5, 5; -5, 5; 0, 5]);
            obj.dt = obj.getField(cfg, 'dt', 0.02);
            
            % ========== LEARNING PARAMETERS ==========
            obj.eta_rep = obj.getField(cfg, 'eta_rep', 0.01);
            obj.eta_W = obj.getField(cfg, 'eta_W', 0.001);
            obj.momentum = obj.getField(cfg, 'momentum', 0.9);
            obj.weight_decay = obj.getField(cfg, 'weight_decay', 0.98);
            obj.motor_gain = obj.getField(cfg, 'motor_gain', 1.0);
            obj.max_weight_value = obj.getField(cfg, 'max_weight_value', 10.0);
            obj.max_error_value = obj.getField(cfg, 'max_error_value', 10.0);
            
            % ========== TRIAL PARAMETERS ==========
            obj.T_per_trial = obj.getField(cfg, 'T_per_trial', 250);
            obj.n_trials = obj.getField(cfg, 'n_trials', 1);
            obj.N = round(obj.T_per_trial / obj.dt);
            
            % ========== NOISE PARAMETERS ==========
            obj.noise_enabled = obj.getField(cfg, 'noise_enabled', false);
            obj.position_noise_std = obj.getField(cfg, 'position_noise_std', 0.05);
            obj.velocity_noise_std = obj.getField(cfg, 'velocity_noise_std', 0.02);
            obj.noise_type = obj.getField(cfg, 'noise_type', 'gaussian');
            
            % ========== VISUOMOTOR DELAY PARAMETERS ==========
            obj.enable_delay = obj.getField(cfg, 'enable_delay', false);
            obj.visual_latency_ms = obj.getField(cfg, 'visual_latency_ms', 0);
            obj.prediction_horizon_ms = obj.getField(cfg, 'prediction_horizon_ms', 0);
            
            % ========== LOGGING PARAMETERS ==========
            obj.log_level = obj.getField(cfg, 'log_level', 'INFO');
            
            % ========== SEMANTIC INDICES ==========
            obj.idx_pos = obj.getField(cfg, 'idx_pos', [1, 2, 3]);
            obj.idx_vel = obj.getField(cfg, 'idx_vel', [4, 5, 6]);
            obj.idx_bias = obj.getField(cfg, 'idx_bias', 7);
            
            % ========== TASK CONFIGURATION ==========
            obj.n_tasks = obj.getField(cfg, 'n_tasks', 1);
            obj.target_trajectories = obj.getField(cfg, 'target_trajectories', []);
        end
        
        function value = getField(~, struct_var, field_name, default_value)
            % Helper function: safely get field from struct with default
            if isfield(struct_var, field_name)
                value = struct_var.(field_name);
            else
                value = default_value;
            end
        end
        
        function setForMotor(obj)
            % Set generic layer sizes for motor hierarchy
            obj.n_L1 = obj.n_L1_motor;
            obj.n_L2 = obj.n_L2_motor;
            obj.n_L3 = obj.n_L3_motor;
        end
        
        function setForPlanning(obj)
            % Set generic layer sizes for planning hierarchy
            obj.n_L1 = obj.n_L1_plan;
            obj.n_L2 = obj.n_L2_plan;
            obj.n_L3 = obj.n_L3_plan;
        end
    end
end