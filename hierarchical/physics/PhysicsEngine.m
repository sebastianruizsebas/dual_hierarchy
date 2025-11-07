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
        
        function [x_new, y_new, z_new, vx_new, vy_new, vz_new] = integratePlayer(...
                obj, x, y, z, vx, vy, vz, vx_cmd, vy_cmd, vz_cmd, dt)
            % Integrate player motion with motor commands
            
            % Apply motor commands (with damping)
            damping = 0.95;  % Velocity decay per step
            vx_new = damping * vx + vx_cmd;
            vy_new = damping * vy + vy_cmd;
            vz_new = damping * vz + vz_cmd;
            
            % Apply gravity (z-axis only)
            vz_new = vz_new - obj.gravity * dt;
            
            % Apply air drag
            speed = sqrt(vx_new^2 + vy_new^2 + vz_new^2);
            if speed > 0
                drag_factor = 1 - obj.air_drag * speed * dt;
                drag_factor = max(0, drag_factor);
                vx_new = vx_new * drag_factor;
                vy_new = vy_new * drag_factor;
                vz_new = vz_new * drag_factor;
            end
            
            % Integrate position
            x_new = x + vx_new * dt;
            y_new = y + vy_new * dt;
            z_new = z + vz_new * dt;
            
            % Handle collisions with ground and walls
            [x_new, y_new, z_new, vx_new, vy_new, vz_new] = ...
                obj.handleBoundaryCollisions(x_new, y_new, z_new, ...
                                            vx_new, vy_new, vz_new);
        end
        
        function [x, y, z, vx, vy, vz] = handleBoundaryCollisions(...
                obj, x, y, z, vx, vy, vz)
            % Handle collisions with workspace boundaries
            
            bounds = obj.workspace_bounds;
            
            % X boundaries
            if x < bounds(1,1)
                x = bounds(1,1);
                vx = -vx * obj.restitution;
            elseif x > bounds(1,2)
                x = bounds(1,2);
                vx = -vx * obj.restitution;
            end
            
            % Y boundaries
            if y < bounds(2,1)
                y = bounds(2,1);
                vy = -vy * obj.restitution;
            elseif y > bounds(2,2)
                y = bounds(2,2);
                vy = -vy * obj.restitution;
            end
            
            % Z boundaries (ground collision)
            if z < bounds(3,1)
                z = bounds(3,1);
                vz = -vz * obj.restitution;
                
                % Apply ground friction to horizontal velocity
                vx = vx * obj.ground_friction;
                vy = vy * obj.ground_friction;
            elseif z > bounds(3,2)
                z = bounds(3,2);
                vz = -vz * obj.restitution;
            end
        end
    end
end