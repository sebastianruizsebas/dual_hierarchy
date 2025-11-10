classdef PhysicsEngine < handle
    % PHYSICSENGINE Handles physics simulation (gravity, collisions, bounds)
    
    properties
        gravity
        air_drag
        restitution
        ground_friction
        workspace_bounds
        dt
    end
    
    methods
        function obj = PhysicsEngine(config)
            obj.gravity = config.gravity;
            obj.air_drag = config.air_drag;
            obj.restitution = config.restitution;
            obj.ground_friction = config.ground_friction;
            obj.workspace_bounds = config.workspace_bounds;
            obj.dt = config.dt;
        end
        
        function [x_new, y_new, z_new, vx_new, vy_new, vz_new] = integrateBall(...
                obj, x, y, z, vx, vy, vz, dt)
            % Integrate ball motion (no motor commands, pure physics)
            
            % Apply gravity and drag FIRST (before position update)
            vz_new = vz - obj.gravity * dt;
            
            drag = 1 - obj.air_drag * dt;
            vx_new = vx * drag;
            vy_new = vy * drag;
            vz_new = vz_new * drag;
            
            % Update position with NEW velocity
            x_new = x + vx_new * dt;
            y_new = y + vy_new * dt;
            z_new = z + vz_new * dt;
            
            % Handle collisions AFTER position update
            [x_new, y_new, z_new, vx_new, vy_new, vz_new] = ...
                obj.handleBallCollisions(x_new, y_new, z_new, vx_new, vy_new, vz_new);
        end
        
        function [x_new, y_new, z_new, vx_new, vy_new, vz_new] = integratePlayer(...
                obj, x, y, z, vx, vy, vz, vx_cmd, vy_cmd, vz_cmd, dt)
            % Integrate player motion with motor commands
            
            % Add command damping to blend old velocity with new command
            damping = 0.3;  % Keep 30% of old velocity
            vx_new = damping * vx + (1 - damping) * vx_cmd;
            vy_new = damping * vy + (1 - damping) * vy_cmd;
            
            % Apply gravity only to vz
            vz_new = vz + vz_cmd - obj.gravity * dt;
            
            % Apply air resistance
            drag = 1 - obj.air_drag * dt;
            vx_new = vx_new * drag;
            vy_new = vy_new * drag;
            vz_new = vz_new * drag;
            
            % Update position
            x_new = x + vx_new * dt;
            y_new = y + vy_new * dt;
            z_new = z + vz_new * dt;
            
            % Handle boundary collisions
            [x_new, y_new, z_new, vx_new, vy_new, vz_new] = ...
                obj.handleBoundaryCollisions(x_new, y_new, z_new, vx_new, vy_new, vz_new);
        end
        
        function [x, y, z, vx, vy, vz] = handleBallCollisions(obj, x, y, z, vx, vy, vz)
            % Handle ball collisions (BOUNCY - less friction)
            bounds = obj.workspace_bounds;
            
            % Ground collision - BOUNCY
            if z <= 0
                z = 0;  % Set exactly to ground
                
                % Only bounce if moving downward (prevent multiple bounces per step)
                if vz < 0
                    vz = -vz * obj.restitution;  % Reverse and scale
                    
                    % Apply horizontal friction ONLY on bounce
                    vx = vx * 0.995;
                    vy = vy * 0.995;
                end
            end
            
            % Wall bounces (same pattern)
            if x <= bounds(1,1)
                x = bounds(1,1);
                if vx < 0
                    vx = -vx * obj.restitution;
                end
            elseif x >= bounds(1,2)
                x = bounds(1,2);
                if vx > 0
                    vx = -vx * obj.restitution;
                end
            end
            
            if y <= bounds(2,1)
                y = bounds(2,1);
                if vy < 0
                    vy = -vy * obj.restitution;
                end
            elseif y >= bounds(2,2)
                y = bounds(2,2);
                if vy > 0
                    vy = -vy * obj.restitution;
                end
            end
            
            if z >= bounds(3,2)
                z = bounds(3,2);
                if vz > 0
                    vz = -vz * obj.restitution;
                end
            end
        end
        
        function [x, y, z, vx, vy, vz] = handleBoundaryCollisions(obj, x, y, z, vx, vy, vz)
            % Handle player collisions (friction/damping, NOT bouncy)
            bounds = obj.workspace_bounds;
            
            % Ground collision - FRICTION (not bouncy like ball)
            if z <= 0
                z = 0;
                
                % Heavy damping on vertical velocity (player sticks to ground)
                vz = vz * 0.1;  % Kill 90% of vertical velocity
                
                % Apply horizontal friction when on ground
                vx = vx * obj.ground_friction;
                vy = vy * obj.ground_friction;
            end
            
            % Wall collisions - FRICTION (not bouncy)
            if x <= bounds(1,1)
                x = bounds(1,1);
                vx = vx * 0.5;  % Damping on wall hit
            elseif x >= bounds(1,2)
                x = bounds(1,2);
                vx = vx * 0.5;  % Damping on wall hit
            end
            
            if y <= bounds(2,1)
                y = bounds(2,1);
                vy = vy * 0.5;  % Damping on wall hit
            elseif y >= bounds(2,2)
                y = bounds(2,2);
                vy = vy * 0.5;  % Damping on wall hit
            end
            
            % Ceiling - hard stop (player can't fly)
            if z >= bounds(3,2)
                z = bounds(3,2);
                vz = 0;  % Stop completely at ceiling
            end
        end
    end
end