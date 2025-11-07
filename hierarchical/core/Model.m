classdef Model < handle
    % MODEL Main simulation orchestrator using modular hierarchies
    
    properties
        % Configuration
        config
        
        % Neural components
        motorHierarchy
        planningHierarchy
        
        % Physics
        physics
        
        % State
        state
        
        % Logging
        logger
        
        % Noise
        noise_generator       % NoiseGenerator instance
        
        % Sensory buffers for visuomotor delay
        ball_observation_buffer     % Circular buffer of past ball states
        player_observation_buffer   % Circular buffer of past player states
        buffer_size                 % Size of circular buffers
        buffer_index                % Current write position
    end
    
    methods
        function obj = Model(config)
            % Constructor: accepts config object or filepath/struct
            obj.config = config;
            
            obj.logger = Logger(obj.config.log_level);
            obj.logger.info('Initializing hierarchical model...');
            
            obj.initialize();
        end
        
        function initialize(obj)
            % Initialize all model components
            
            obj.logger = Logger(obj.config.log_level);
            obj.logger.info('Initializing hierarchical model...');
            
            % Set config for motor hierarchy FIRST
            obj.config.setForMotor();
            obj.motorHierarchy = MotorHierarchy(obj.config);
            obj.logger.info('Motor hierarchy initialized (%dx%dx%d)', ...
                obj.config.n_L1_motor, obj.config.n_L2_motor, obj.config.n_L3_motor);
            
            % Set config for planning hierarchy FIRST
            obj.config.setForPlanning();
            obj.planningHierarchy = PlanningHierarchy(obj.config);
            obj.logger.info('Planning hierarchy initialized (%dx%dx%d)', ...
                obj.config.n_L1_plan, obj.config.n_L2_plan, obj.config.n_L3_plan);
            
            % Create physics engine - pass config only
            obj.physics = PhysicsEngine(obj.config);
            obj.logger.info('Physics engine initialized');
            
            % Create state arrays - pass config, NOT N
            obj.state = SimulationState(obj.config);
            obj.logger.info('State arrays allocated (N=%d)', obj.config.N);
            
            % Initialize noise generator
            obj.noise_generator = NoiseGenerator(obj.config.noise_type);
            
            % Initialize sensory buffers for delay
            if obj.config.enable_delay
                obj.buffer_size = ceil(obj.config.visual_latency_ms / (obj.config.dt * 1000)) + 1;
                obj.ball_observation_buffer = zeros(obj.buffer_size, 6);
                obj.player_observation_buffer = zeros(obj.buffer_size, 6);
                obj.buffer_index = 1;
                
                obj.logger.info('Sensory buffer initialized: size=%d, delay=%.0fms', ...
                    obj.buffer_size, obj.config.visual_latency_ms);
            end
        end
        
        function initializeTrajectories(obj)
            % Set initial conditions from config
            
            % Player starts at origin (or from config if specified)
            obj.state.setInitialPlayerState(0, 0, 0, 0, 0, 0);
            
            % Target initial conditions (from first trajectory)
            if ~isempty(obj.config.target_trajectories)
                traj = obj.config.target_trajectories{1};
                obj.state.setInitialTargetState(...
                    traj.start_pos(1), traj.start_pos(2), traj.start_pos(3), ...
                    traj.velocity(1), traj.velocity(2), traj.velocity(3));
            else
                obj.state.setInitialTargetState(2, 2, 1, -0.5, -0.5, 0);
            end
        end
        
        function results = run(obj)
            % Main simulation loop
            
            N = obj.config.N;
            dt = obj.config.dt;
            
            obj.logger.info('Starting simulation (%d steps, dt=%.3f)', N, dt);
            
            for i = 1:N-1
                % Get CURRENT true states from physics
                x_player = obj.state.x_player(i);
                y_player = obj.state.y_player(i);
                z_player = obj.state.z_player(i);
                vx_player = obj.state.vx_player(i);
                vy_player = obj.state.vy_player(i);
                vz_player = obj.state.vz_player(i);
                
                x_ball = obj.state.x_ball(i);
                y_ball = obj.state.y_ball(i);
                z_ball = obj.state.z_ball(i);
                vx_ball = obj.state.vx_ball(i);
                vy_ball = obj.state.vy_ball(i);
                vz_ball = obj.state.vz_ball(i);
                
                % Store current observation in buffer for later retrieval
                obj.storeObservation(x_ball, y_ball, z_ball, vx_ball, vy_ball, vz_ball, ...
                                    x_player, y_player, z_player, vx_player, vy_player, vz_player);
                
                % ============================================================
                % GET DELAYED OBSERVATIONS (what the brain "sees")
                % ============================================================
                [x_ball_obs, y_ball_obs, z_ball_obs, vx_ball_obs, vy_ball_obs, vz_ball_obs] = ...
                    obj.getDelayedBallObservation();
                
                [x_player_obs, y_player_obs, z_player_obs, vx_player_obs, vy_player_obs, vz_player_obs] = ...
                    obj.getDelayedPlayerObservation();
                
                % Add sensory noise
                if obj.config.noise_enabled
                    [x_ball_obs, y_ball_obs, z_ball_obs] = ...
                        obj.noise_generator.addPositionNoise(x_ball_obs, y_ball_obs, z_ball_obs, ...
                        obj.config.position_noise_std);
                    
                    [vx_ball_obs, vy_ball_obs, vz_ball_obs] = ...
                        obj.noise_generator.addVelocityNoise(vx_ball_obs, vy_ball_obs, vz_ball_obs, ...
                        obj.config.velocity_noise_std);
                end
                
                % ============================================================
                % PLANNING HIERARCHY - Uses DELAYED observations
                % Predict FUTURE ball position (compensate for delay)
                % ============================================================
                obj.planningHierarchy.setTargetObservation(x_ball_obs, y_ball_obs, z_ball_obs);
                obj.planningHierarchy.setVelocityObservation(vx_ball_obs, vy_ball_obs, vz_ball_obs);
                
                % KEY: Predict ahead by prediction_horizon
                obj.planningHierarchy.predict();
                [x_ball_pred, y_ball_pred, z_ball_pred] = obj.planningHierarchy.predictTargetPosition();
                
                % ============================================================
                % MOTOR HIERARCHY - Uses DELAYED observations
                % ============================================================
                obj.motorHierarchy.setPositionObservation(x_player_obs, y_player_obs, z_player_obs);
                obj.motorHierarchy.setVelocityObservation(vx_player_obs, vy_player_obs, vz_player_obs);
                obj.motorHierarchy.setBiasObservation(1.0);
                
                % Set target from planning hierarchy
                obj.motorHierarchy.setTargetPosition(x_ball_pred, y_ball_pred, z_ball_pred);
                obj.motorHierarchy.updateRepresentations();
                
                % Extract motor commands
                [vx_cmd, vy_cmd, vz_cmd] = obj.motorHierarchy.extractMotorCommand();
                
                % ============================================================
                % PHYSICS - Integrate using TRUE (current) states
                % ============================================================
                [x_player, y_player, z_player, vx_player, vy_player, vz_player] = ...
                    obj.physics.integratePlayer(x_player, y_player, z_player, ...
                    vx_player, vy_player, vz_player, vx_cmd, vy_cmd, vz_cmd, obj.config.dt);
                
                [x_ball, y_ball, z_ball, vx_ball, vy_ball, vz_ball] = ...
                    obj.physics.integrateBall(x_ball, y_ball, z_ball, ...
                    vx_ball, vy_ball, vz_ball, obj.config.dt);
                
                % Store in state
                obj.state.x_player(i+1) = x_player;
                obj.state.y_player(i+1) = y_player;
                obj.state.z_player(i+1) = z_player;
                obj.state.vx_player(i+1) = vx_player;
                obj.state.vy_player(i+1) = vy_player;
                obj.state.vz_player(i+1) = vz_player;
                
                obj.state.x_ball(i+1) = x_ball;
                obj.state.y_ball(i+1) = y_ball;
                obj.state.z_ball(i+1) = z_ball;
                obj.state.vx_ball(i+1) = vx_ball;
                obj.state.vy_ball(i+1) = vy_ball;
                obj.state.vz_ball(i+1) = vz_ball;
                
                % Check interception
                if obj.state.distance_to_target(i) < 0.5
                    obj.state.interception_success = true;
                    obj.state.interception_step = i;
                end
            end
            
            % Final results
            obj.state.final_distance = obj.state.distance_to_target(end);
            results = obj.state.getResults();
        end
        
        function updateTarget(obj, i)
            % Target kinematics (constant velocity model)
            dt = obj.config.dt;
            trial_idx = obj.getCurrentTrial(i);
            
            if ~isempty(obj.config.target_trajectories)
                traj = obj.config.target_trajectories{trial_idx};
                accel = traj.acceleration;
            else
                accel = [0, 0, 0];
            end
            
            % Integrate velocity
            obj.state.vx_ball(i+1) = obj.state.vx_ball(i) + accel(1) * dt;
            obj.state.vy_ball(i+1) = obj.state.vy_ball(i) + accel(2) * dt;
            obj.state.vz_ball(i+1) = obj.state.vz_ball(i) + accel(3) * dt;
            
            % Integrate position
            obj.state.x_ball(i+1) = obj.state.x_ball(i) + dt * obj.state.vx_ball(i+1);
            obj.state.y_ball(i+1) = obj.state.y_ball(i) + dt * obj.state.vy_ball(i+1);
            obj.state.z_ball(i+1) = obj.state.z_ball(i) + dt * obj.state.vz_ball(i+1);
            
            % Clamp to workspace
            bounds = obj.config.workspace_bounds;
            obj.state.x_ball(i+1) = max(bounds(1,1), min(bounds(1,2), obj.state.x_ball(i+1)));
            obj.state.y_ball(i+1) = max(bounds(2,1), min(bounds(2,2), obj.state.y_ball(i+1)));
            obj.state.z_ball(i+1) = max(bounds(3,1), min(bounds(3,2), obj.state.z_ball(i+1)));
        end
        
        function trial_idx = getCurrentTrial(obj, i)
            % Determine which trial we're in based on timestep
            trial_duration_steps = round(obj.config.T_per_trial / obj.config.dt);
            trial_idx = ceil(i / trial_duration_steps);
            trial_idx = max(1, min(obj.config.n_trials, trial_idx));
        end
        
        function [target_x, target_y, target_z] = predictInterceptionPoint(obj, i)
            % Predict where ball will be based on current trajectory
            lookahead_time = 1.0;  % Seconds to look ahead
            
            target_x = obj.state.x_ball(i) + obj.state.vx_ball(i) * lookahead_time;
            target_y = obj.state.y_ball(i) + obj.state.vy_ball(i) * lookahead_time;
            target_z = obj.state.z_ball(i) + obj.state.vz_ball(i) * lookahead_time;
            
            % Clamp to workspace
            bounds = obj.config.workspace_bounds;
            target_x = max(bounds(1,1), min(bounds(1,2), target_x));
            target_y = max(bounds(2,1), min(bounds(2,2), target_y));
            target_z = max(bounds(3,1), min(bounds(3,2), target_z));
        end
        
        function storeObservation(obj, x_ball, y_ball, z_ball, vx_ball, vy_ball, vz_ball, ...
                                   x_player, y_player, z_player, vx_player, vy_player, vz_player)
            % Store current observations in circular buffers
            
            if ~obj.config.enable_delay
                return;  % Skip buffering if delay disabled
            end
            
            % Store ball observation
            obj.ball_observation_buffer(obj.buffer_index, :) = ...
                [x_ball, y_ball, z_ball, vx_ball, vy_ball, vz_ball];
            
            % Store player observation
            obj.player_observation_buffer(obj.buffer_index, :) = ...
                [x_player, y_player, z_player, vx_player, vy_player, vz_player];
            
            % Move to next buffer position (circular)
            obj.buffer_index = mod(obj.buffer_index, obj.buffer_size) + 1;
        end
        
        function [x_ball, y_ball, z_ball, vx_ball, vy_ball, vz_ball] = getDelayedBallObservation(obj)
            % Retrieve ball observation from delay_steps ago
            
            % If delay not enabled OR buffer not initialized, return current state
            if ~obj.config.enable_delay || isempty(obj.ball_observation_buffer)
                % No delay - return current state from state arrays
                % This is called during loop, so use the most recent stored values
                x_ball = obj.state.x_ball(1);
                y_ball = obj.state.y_ball(1);
                z_ball = obj.state.z_ball(1);
                vx_ball = obj.state.vx_ball(1);
                vy_ball = obj.state.vy_ball(1);
                vz_ball = obj.state.vz_ball(1);
                return;
            end
            
            % Apply delay: look back in circular buffer
            delay_steps = ceil(obj.config.visual_latency_ms / (obj.config.dt * 1000));
            
            % Clamp delay to buffer size
            delay_steps = min(delay_steps, obj.buffer_size - 1);
            
            % Calculate delayed index
            delayed_idx = obj.buffer_index - delay_steps - 1;
            if delayed_idx < 1
                delayed_idx = delayed_idx + obj.buffer_size;
            end
            
            obs = obj.ball_observation_buffer(delayed_idx, :);
            
            x_ball = obs(1);
            y_ball = obs(2);
            z_ball = obs(3);
            vx_ball = obs(4);
            vy_ball = obs(5);
            vz_ball = obs(6);
        end
        
        function [x_player, y_player, z_player, vx_player, vy_player, vz_player] = getDelayedPlayerObservation(obj)
            % Retrieve player observation from delay_steps ago
            
            % If delay not enabled OR buffer not initialized, return current state
            if ~obj.config.enable_delay || isempty(obj.player_observation_buffer)
                % No delay - return current state
                x_player = obj.state.x_player(1);
                y_player = obj.state.y_player(1);
                z_player = obj.state.z_player(1);
                vx_player = obj.state.vx_player(1);
                vy_player = obj.state.vy_player(1);
                vz_player = obj.state.vz_player(1);
                return;
            end
            
            delay_steps = ceil(obj.config.visual_latency_ms / (obj.config.dt * 1000));
            delay_steps = min(delay_steps, obj.buffer_size - 1);
            
            delayed_idx = obj.buffer_index - delay_steps - 1;
            if delayed_idx < 1
                delayed_idx = delayed_idx + obj.buffer_size;
            end
            
            obs = obj.player_observation_buffer(delayed_idx, :);
            
            x_player = obs(1);
            y_player = obs(2);
            z_player = obs(3);
            vx_player = obs(4);
            vy_player = obs(5);
            vz_player = obs(6);
        end
    end
end