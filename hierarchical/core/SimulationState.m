classdef SimulationState < handle
    % SIMULATIONSTATE Manages all simulation state variables
    %   Pre-allocates arrays, provides getter/setter interfaces
    
    properties
        % Dimensions
        N  % Number of timesteps
        
        % Player state (position and velocity)
        x_player
        y_player
        z_player
        vx_player
        vy_player
        vz_player
        
        % Target/ball state
        x_ball
        y_ball
        z_ball
        vx_ball
        vy_ball
        vz_ball
        
        % Free energy tracking
        free_energy_motor
        free_energy_plan
        free_energy_combined  % ADD THIS LINE
        
        % Neural state snapshots (optional detailed logging)
        motor_states  % Cell array of state snapshots
        plan_states
        
        % Performance metrics
        distance_to_target  % Euclidean distance at each step
        cumulative_error
        
        % Current timestep
        current_step
    end
    
    methods
        function obj = SimulationState(config)
            % Initialize state arrays based on config
            
            obj.N = config.N;
            obj.current_step = 1;
            
            % Pre-allocate arrays (single precision for memory efficiency)
            obj.x_player = zeros(obj.N, 1, 'single');
            obj.y_player = zeros(obj.N, 1, 'single');
            obj.z_player = zeros(obj.N, 1, 'single');
            obj.vx_player = zeros(obj.N, 1, 'single');
            obj.vy_player = zeros(obj.N, 1, 'single');
            obj.vz_player = zeros(obj.N, 1, 'single');
            
            obj.x_ball = zeros(obj.N, 1, 'single');
            obj.y_ball = zeros(obj.N, 1, 'single');
            obj.z_ball = zeros(obj.N, 1, 'single');
            obj.vx_ball = zeros(obj.N, 1, 'single');
            obj.vy_ball = zeros(obj.N, 1, 'single');
            obj.vz_ball = zeros(obj.N, 1, 'single');
            
            obj.free_energy_motor = zeros(obj.N, 1, 'single');
            obj.free_energy_plan = zeros(obj.N, 1, 'single');
            obj.free_energy_combined = zeros(1, obj.N);  % Initialize combined free energy
            
            obj.distance_to_target = zeros(obj.N, 1, 'single');
            obj.cumulative_error = zeros(obj.N, 1, 'single');
            
            % Optional: detailed neural state logging (memory intensive)
            obj.motor_states = cell(obj.N, 1);
            obj.plan_states = cell(obj.N, 1);
        end
        
        function setInitialPlayerState(obj, x, y, z, vx, vy, vz)
            % Set initial player position and velocity
            obj.x_player(1) = x;
            obj.y_player(1) = y;
            obj.z_player(1) = z;
            obj.vx_player(1) = vx;
            obj.vy_player(1) = vy;
            obj.vz_player(1) = vz;
        end
        
        function setInitialTargetState(obj, x, y, z, vx, vy, vz)
            % Set initial target position and velocity
            obj.x_ball(1) = x;
            obj.y_ball(1) = y;
            obj.z_ball(1) = z;
            obj.vx_ball(1) = vx;
            obj.vy_ball(1) = vy;
            obj.vz_ball(1) = vz;
        end
        
        function updateDistanceMetrics(obj, i)
            % Compute distance to target at step i
            dx = obj.x_player(i) - obj.x_ball(i);
            dy = obj.y_player(i) - obj.y_ball(i);
            dz = obj.z_player(i) - obj.z_ball(i);
            
            obj.distance_to_target(i) = sqrt(dx^2 + dy^2 + dz^2);
            
            % Cumulative error (integral of distance over time)
            if i > 1
                obj.cumulative_error(i) = obj.cumulative_error(i-1) + ...
                                         obj.distance_to_target(i);
            else
                obj.cumulative_error(i) = obj.distance_to_target(i);
            end
        end
        
        function results = getResults(obj)
            % Package state into results struct (for compatibility with old code)
            
            results = struct();
            
            % Trajectories
            results.x_player = obj.x_player;
            results.y_player = obj.y_player;
            results.z_player = obj.z_player;
            results.vx_player = obj.vx_player;
            results.vy_player = obj.vy_player;
            results.vz_player = obj.vz_player;
            
            results.x_ball = obj.x_ball;
            results.y_ball = obj.y_ball;
            results.z_ball = obj.z_ball;
            results.vx_ball = obj.vx_ball;
            results.vy_ball = obj.vy_ball;
            results.vz_ball = obj.vz_ball;
            
            % Free energy
            results.free_energy_motor = obj.free_energy_motor;
            results.free_energy_plan = obj.free_energy_plan;
            results.free_energy_combined = obj.free_energy_combined;
            
            % Metrics
            results.distance_to_target = obj.distance_to_target;
            results.cumulative_error = obj.cumulative_error;
            results.final_distance = obj.distance_to_target(end);
            results.mean_distance = mean(obj.distance_to_target);
            
            % Neural snapshots (if logged)
            if ~isempty(obj.motor_states{1})
                results.motor_states = obj.motor_states;
                results.plan_states = obj.plan_states;
            end
        end
        
        function snapshot = getSnapshot(obj, i)
            % Get immutable snapshot of state at timestep i
            snapshot = struct();
            snapshot.x_player = obj.x_player(i);
            snapshot.y_player = obj.y_player(i);
            snapshot.z_player = obj.z_player(i);
            snapshot.vx_player = obj.vx_player(i);
            snapshot.vy_player = obj.vy_player(i);
            snapshot.vz_player = obj.vz_player(i);
            
            snapshot.x_ball = obj.x_ball(i);
            snapshot.y_ball = obj.y_ball(i);
            snapshot.z_ball = obj.z_ball(i);
        end
    end
end