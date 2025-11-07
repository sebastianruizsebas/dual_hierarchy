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
    end
    
    methods
        function obj = Model(config_source)
            % Constructor: accepts config object or filepath/struct
            if isa(config_source, 'Config')
                obj.config = config_source;
            else
                obj.config = Config(config_source);
            end
            
            obj.logger = Logger(obj.config.log_level);
            obj.logger.info('Initializing hierarchical model...');
            
            obj.initialize();
        end
        
        function initialize(obj)
            % Create motor hierarchy
            motor_config = struct();
            motor_config.n_L1 = obj.config.n_L1_motor;
            motor_config.n_L2 = obj.config.n_L2_motor;
            motor_config.n_L3 = obj.config.n_L3_motor;
            motor_config.idx_pos = obj.config.idx_pos;
            motor_config.idx_vel = obj.config.idx_vel;
            motor_config.idx_bias = obj.config.idx_bias;
            motor_config.eta_rep = obj.config.eta_rep;
            motor_config.eta_W = obj.config.eta_W;
            motor_config.momentum = obj.config.momentum;
            motor_config.weight_decay = obj.config.weight_decay;
            motor_config.motor_gain = obj.config.motor_gain;
            motor_config.max_weight_value = obj.config.max_weight_value;
            motor_config.max_precision_value = obj.config.max_precision_value;
            motor_config.max_error_value = obj.config.max_error_value;
            
            obj.motorHierarchy = MotorHierarchy(motor_config);
            obj.logger.info('Motor hierarchy initialized (%dx%dx%d)', ...
                motor_config.n_L1, motor_config.n_L2, motor_config.n_L3);
            
            % Create planning hierarchy
            plan_config = motor_config;  % Copy motor config
            plan_config.n_L1 = obj.config.n_L1_plan;
            plan_config.n_L2 = obj.config.n_L2_plan;
            plan_config.n_L3 = obj.config.n_L3_plan;
            plan_config.n_tasks = obj.config.n_trials;
            
            obj.planningHierarchy = PlanningHierarchy(plan_config);
            obj.logger.info('Planning hierarchy initialized (%dx%dx%d, %d tasks)', ...
                plan_config.n_L1, plan_config.n_L2, plan_config.n_L3, plan_config.n_tasks);
            
            % Create physics engine
            obj.physics = PhysicsEngine(obj.config);
            obj.logger.info('Physics engine initialized');
            
            % Create state
            obj.state = SimulationState(obj.config);
            obj.logger.info('State arrays allocated (N=%d)', obj.config.N);
            
            % Initialize trajectories
            obj.initializeTrajectories();
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
                % Update target kinematics
                obj.updateTarget(i);
                
                % Update task context
                trial_idx = obj.getCurrentTrial(i);
                obj.planningHierarchy.setTask(trial_idx);
                
                % Motor hierarchy observes current state
                obj.motorHierarchy.setPositionObservation(...
                    obj.state.x_player(i), ...
                    obj.state.y_player(i), ...
                    obj.state.z_player(i));
                obj.motorHierarchy.setVelocityObservation(...
                    obj.state.vx_player(i), ...
                    obj.state.vy_player(i), ...
                    obj.state.vz_player(i));
                obj.motorHierarchy.setBiasObservation(1.0);
                
                % Planning hierarchy observes target
                obj.planningHierarchy.setTargetObservation(...
                    obj.state.x_ball(i), ...
                    obj.state.y_ball(i), ...
                    obj.state.z_ball(i));
                
                % Hierarchies perform inference
                motor_sensory = [obj.state.x_player(i); obj.state.y_player(i); obj.state.z_player(i); ...
                                 obj.state.vx_player(i); obj.state.vy_player(i); obj.state.vz_player(i); 1.0];
                obj.motorHierarchy.step(motor_sensory);
                
                plan_sensory = [obj.state.x_ball(i); obj.state.y_ball(i); obj.state.z_ball(i); ...
                                obj.state.vx_ball(i); obj.state.vy_ball(i); obj.state.vz_ball(i); 1.0];
                obj.planningHierarchy.step(plan_sensory);
                
                % Extract motor command
                [vx_cmd, vy_cmd, vz_cmd] = obj.motorHierarchy.extractMotorCommand();
                
                % Apply physics (integrate motion)
                [x_new, y_new, z_new, vx_new, vy_new, vz_new] = ...
                    obj.physics.integratePlayer(...
                        obj.state.x_player(i), obj.state.y_player(i), obj.state.z_player(i), ...
                        obj.state.vx_player(i), obj.state.vy_player(i), obj.state.vz_player(i), ...
                        vx_cmd, vy_cmd, vz_cmd, dt);
                
                % Update state
                obj.state.x_player(i+1) = x_new;
                obj.state.y_player(i+1) = y_new;
                obj.state.z_player(i+1) = z_new;
                obj.state.vx_player(i+1) = vx_new;
                obj.state.vy_player(i+1) = vy_new;
                obj.state.vz_player(i+1) = vz_new;
                
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
            
            % After the main simulation loop ends, compute final metrics
            
            % Find the last valid timestep
            last_step = min(i, obj.config.n_steps);
            
            % Compute final distance using the last timestep
            final_x_diff = obj.state.x_player(last_step) - obj.state.x_ball(last_step);
            final_y_diff = obj.state.y_player(last_step) - obj.state.y_ball(last_step);
            final_z_diff = obj.state.z_player(last_step) - obj.state.z_ball(last_step);
            final_distance = sqrt(final_x_diff^2 + final_y_diff^2 + final_z_diff^2);
            
            % Store in results
            obj.state.final_distance = final_distance;
            obj.state.mean_distance = mean(obj.state.distance_to_target(1:last_step));
            
            obj.logger.log('INFO', sprintf('Simulation complete. Final distance: %.3f', final_distance));
            
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
    end
end