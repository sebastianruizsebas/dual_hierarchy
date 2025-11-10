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
            
            % Initialize sensory buffers (always, even if delay disabled)
            obj.buffer_size = max(2, ceil(obj.config.visual_latency_ms / (obj.config.dt * 1000)) + 1);
            obj.ball_observation_buffer = zeros(obj.buffer_size, 6);
            obj.player_observation_buffer = zeros(obj.buffer_size, 6);
            obj.buffer_index = 1;
            
            if obj.config.enable_delay
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
                % Update target kinematics (ball physics)
                obj.updateTarget(i);
                
                % Get CURRENT true states
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
                
                % Store current observation in buffer
                obj.storeObservation(x_ball, y_ball, z_ball, vx_ball, vy_ball, vz_ball, ...
                                    x_player, y_player, z_player, vx_player, vy_player, vz_player);
                
                % Get delayed observations
                [x_ball_obs, y_ball_obs, z_ball_obs, vx_ball_obs, vy_ball_obs, vz_ball_obs] = ...
                    obj.getDelayedBallObservation();
                [x_player_obs, y_player_obs, z_player_obs, vx_player_obs, vy_player_obs, vz_player_obs] = ...
                    obj.getDelayedPlayerObservation();
                
                % Add noise if enabled
                if obj.config.noise_enabled
                    x_ball_obs = x_ball_obs + obj.noise_generator.generate('position');
                    y_ball_obs = y_ball_obs + obj.noise_generator.generate('position');
                    z_ball_obs = z_ball_obs + obj.noise_generator.generate('position');
                    vx_ball_obs = vx_ball_obs + obj.noise_generator.generate('velocity');
                    vy_ball_obs = vy_ball_obs + obj.noise_generator.generate('velocity');
                    vz_ball_obs = vz_ball_obs + obj.noise_generator.generate('velocity');
                    
                    x_player_obs = x_player_obs + obj.noise_generator.generate('position');
                    y_player_obs = y_player_obs + obj.noise_generator.generate('position');
                    z_player_obs = z_player_obs + obj.noise_generator.generate('position');
                    vx_player_obs = vx_player_obs + obj.noise_generator.generate('velocity');
                    vy_player_obs = vy_player_obs + obj.noise_generator.generate('velocity');
                    vz_player_obs = vz_player_obs + obj.noise_generator.generate('velocity');
                end
                
                % Update task context
                trial_idx = obj.getCurrentTrial(i);
                obj.planningHierarchy.setTask(trial_idx);
                
                % ============================================================
                % PLANNING HIERARCHY - Predicts ball motion
                % ============================================================
                plan_sensory = [x_ball_obs; y_ball_obs; z_ball_obs; ...
                               vx_ball_obs; vy_ball_obs; vz_ball_obs; 1.0];
                obj.planningHierarchy.step(plan_sensory);
                
                % Get predicted ball position (where ball will be)
                [x_ball_pred, y_ball_pred, z_ball_pred] = obj.planningHierarchy.predictTargetPosition();
                
                % ============================================================
                % MOTOR HIERARCHY - Generates movement toward predicted ball
                % ============================================================
                
                % Construct motor sensory input with TARGET information
                % Instead of just player state, include goal direction
                dx_to_ball = x_ball_pred - x_player_obs;
                dy_to_ball = y_ball_pred - y_player_obs;
                dz_to_ball = z_ball_pred - z_player_obs;
                
                % Create augmented sensory input with goal information
                motor_sensory = [x_player_obs; y_player_obs; z_player_obs; ...
                                dx_to_ball; dy_to_ball; dz_to_ball; 1.0];
                
                obj.motorHierarchy.step(motor_sensory);
                
                % Extract motor commands
                [vx_cmd, vy_cmd, vz_cmd] = obj.motorHierarchy.extractMotorCommand();
                
                % ============================================================
                % PHYSICS - Integrate using TRUE states
                % ============================================================
                [x_player, y_player, z_player, vx_player, vy_player, vz_player] = ...
                    obj.physics.integratePlayer(x_player, y_player, z_player, ...
                    vx_player, vy_player, vz_player, vx_cmd, vy_cmd, vz_cmd, dt);
                
                % Update state
                obj.state.x_player(i+1) = x_player;
                obj.state.y_player(i+1) = y_player;
                obj.state.z_player(i+1) = z_player;
                obj.state.vx_player(i+1) = vx_player;
                obj.state.vy_player(i+1) = vy_player;
                obj.state.vz_player(i+1) = vz_player;
                
                % CRITICAL: Compute distance and check interception
                obj.state.updateDistanceMetrics(i+1);  % Use i+1 for new position
                
                % Early termination if interception achieved
                if obj.state.interception_success
                    obj.logger.info('INTERCEPTION at step %d (t=%.2fs, dist=%.3fm)', ...
                        obj.state.interception_step, obj.state.interception_step * dt, ...
                        obj.state.distance_to_target(obj.state.interception_step));
                    break;  % Exit early
                end
                
                % Compute metrics
                obj.state.updateDistanceMetrics(i);
                
                % Log free energy
                FE_motor = obj.motorHierarchy.computeFreeEnergy();
                FE_plan = obj.planningHierarchy.computeFreeEnergy();
                obj.state.free_energy_motor(i) = FE_motor;
                obj.state.free_energy_plan(i) = FE_plan;
                obj.state.free_energy_combined(i) = FE_motor + FE_plan;
                
                % Periodic logging
                if mod(i, 500) == 0
                    obj.logger.info('Step %d/%d: FE_motor=%.2e, FE_plan=%.2e, dist=%.3f', ...
                        i, N, FE_motor, FE_plan, obj.state.distance_to_target(i));
                end
            end
            
            obj.state.final_distance = obj.state.distance_to_target(end);
            results = obj.state.getResults();
        end
        
        function updateTarget(obj, i)
            % Update ball kinematics using physics
    
            x_ball = obj.state.x_ball(i);
            y_ball = obj.state.y_ball(i);
            z_ball = obj.state.z_ball(i);
            vx_ball = obj.state.vx_ball(i);
            vy_ball = obj.state.vy_ball(i);
            vz_ball = obj.state.vz_ball(i);
            
            % Integrate ball physics
            [x_ball, y_ball, z_ball, vx_ball, vy_ball, vz_ball] = ...
                obj.physics.integrateBall(x_ball, y_ball, z_ball, ...
                vx_ball, vy_ball, vz_ball, obj.config.dt);
            
            % CRITICAL: Store the updated values!
            obj.state.x_ball(i+1) = x_ball;
            obj.state.y_ball(i+1) = y_ball;
            obj.state.z_ball(i+1) = z_ball;
            obj.state.vx_ball(i+1) = vx_ball;
            obj.state.vy_ball(i+1) = vy_ball;
            obj.state.vz_ball(i+1) = vz_ball;
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
            % Always store, regardless of delay setting (for consistency)
            
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
            
            % If delay not enabled or buffer empty, return from buffer (most recent stored)
            if ~obj.config.enable_delay || isempty(obj.ball_observation_buffer)
                % Return most recently stored observation from buffer
                read_idx = obj.buffer_index - 1;
                if read_idx < 1
                    read_idx = obj.buffer_size;
                end
                
                obs = obj.ball_observation_buffer(read_idx, :);
                x_ball = obs(1);
                y_ball = obs(2);
                z_ball = obs(3);
                vx_ball = obs(4);
                vy_ball = obs(5);
                vz_ball = obs(6);
                return;
            end
            
            % Apply delay: look back in circular buffer
            delay_steps = ceil(obj.config.visual_latency_ms / (obj.config.dt * 1000));
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
            
            % If delay not enabled or buffer empty, return from buffer (most recent stored)
            if ~obj.config.enable_delay || isempty(obj.player_observation_buffer)
                read_idx = obj.buffer_index - 1;
                if read_idx < 1
                    read_idx = obj.buffer_size;
                end
                
                obs = obj.player_observation_buffer(read_idx, :);
                x_player = obs(1);
                y_player = obs(2);
                z_player = obs(3);
                vx_player = obs(4);
                vy_player = obs(5);
                vz_player = obs(6);
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