classdef Integrator
    % INTEGRATOR Numerical integration methods for physics simulation
    %   Provides Euler, RK2, RK4 integrators
    
    methods (Static)
        function [x_new, v_new] = euler(x, v, accel, dt)
            % Explicit Euler integration (1st order)
            %   x: position
            %   v: velocity
            %   accel: acceleration
            %   dt: timestep
            
            v_new = v + accel * dt;
            x_new = x + v_new * dt;
        end
        
        function [x_new, v_new] = rk2(x, v, accel_func, dt)
            % Runge-Kutta 2nd order (midpoint method)
            %   x: position
            %   v: velocity
            %   accel_func: function handle that computes acceleration
            %               accel = accel_func(x, v)
            %   dt: timestep
            
            % Stage 1
            a1 = accel_func(x, v);
            v_mid = v + 0.5 * a1 * dt;
            x_mid = x + 0.5 * v * dt;
            
            % Stage 2
            a2 = accel_func(x_mid, v_mid);
            v_new = v + a2 * dt;
            x_new = x + v_mid * dt;
        end
        
        function [x_new, v_new] = rk4(x, v, accel_func, dt)
            % Runge-Kutta 4th order (classical RK4)
            %   x: position
            %   v: velocity
            %   accel_func: function handle that computes acceleration
            %   dt: timestep
            
            % Stage 1
            a1 = accel_func(x, v);
            v1 = v;
            
            % Stage 2
            v2 = v + 0.5 * a1 * dt;
            x2 = x + 0.5 * v1 * dt;
            a2 = accel_func(x2, v2);
            
            % Stage 3
            v3 = v + 0.5 * a2 * dt;
            x3 = x + 0.5 * v2 * dt;
            a3 = accel_func(x3, v3);
            
            % Stage 4
            v4 = v + a3 * dt;
            x4 = x + v3 * dt;
            a4 = accel_func(x4, v4);
            
            % Combine stages
            v_new = v + (dt / 6.0) * (a1 + 2*a2 + 2*a3 + a4);
            x_new = x + (dt / 6.0) * (v1 + 2*v2 + 2*v3 + v4);
        end
        
        function [x_new, v_new] = verlet(x, x_prev, accel, dt)
            % Velocity Verlet integration (symplectic, energy-conserving)
            %   x: current position
            %   x_prev: previous position
            %   accel: acceleration
            %   dt: timestep
            
            x_new = 2*x - x_prev + accel * dt^2;
            v_new = (x_new - x_prev) / (2*dt);
        end
        
        function [x_new, v_new] = semiImplicitEuler(x, v, accel, dt)
            % Semi-implicit Euler (symplectic Euler)
            %   More stable than explicit Euler for physical systems
            
            v_new = v + accel * dt;  % Update velocity first
            x_new = x + v_new * dt;  % Then use new velocity for position
        end
    end
end