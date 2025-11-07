classdef PSOWrapper < handle
    % PSOWRAPPER Interface for Particle Swarm Optimization of model parameters
    %   Wraps model execution for use with PSO optimizer
    
    properties
        model_config_template  % Base configuration
        param_bounds          % Parameter search bounds
        param_names          % Parameter names being optimized
        
        % PSO settings
        n_particles
        n_iterations
        inertia_weight
        cognitive_coeff
        social_coeff
        
        % Results tracking
        best_params
        best_fitness
        fitness_history
    end
    
    methods
        function obj = PSOWrapper(config_template, param_bounds)
            % Constructor
            %   config_template: base Config object
            %   param_bounds: struct with fields for each parameter
            %                 e.g., param_bounds.eta_rep = [0.001, 0.1]
            
            obj.model_config_template = config_template;
            obj.param_bounds = param_bounds;
            obj.param_names = fieldnames(param_bounds);
            
            % Default PSO settings
            obj.n_particles = 20;
            obj.n_iterations = 50;
            obj.inertia_weight = 0.7;
            obj.cognitive_coeff = 1.5;
            obj.social_coeff = 1.5;
        end
        
        function [best_params, best_fitness] = optimize(obj)
            % Run PSO optimization
            
            n_params = length(obj.param_names);
            
            % Initialize particles
            particles = obj.initializeParticles(n_params);
            velocities = zeros(obj.n_particles, n_params);
            
            % Initialize personal and global bests
            personal_best_positions = particles;
            personal_best_fitness = inf(obj.n_particles, 1);
            global_best_position = particles(1, :);
            global_best_fitness = inf;
            
            obj.fitness_history = zeros(obj.n_iterations, 1);
            
            fprintf('\n=== PSO OPTIMIZATION ===\n');
            fprintf('Parameters: %s\n', strjoin(obj.param_names, ', '));
            fprintf('Particles: %d, Iterations: %d\n', obj.n_particles, obj.n_iterations);
            
            % PSO iterations
            for iter = 1:obj.n_iterations
                fprintf('\nIteration %d/%d:\n', iter, obj.n_iterations);
                
                % Evaluate all particles
                for p = 1:obj.n_particles
                    % Create config with current particle's parameters
                    config = obj.createConfig(particles(p, :));
                    
                    % Run model and compute fitness
                    fitness = obj.evaluateFitness(config);
                    
                    % Update personal best
                    if fitness < personal_best_fitness(p)
                        personal_best_fitness(p) = fitness;
                        personal_best_positions(p, :) = particles(p, :);
                    end
                    
                    % Update global best
                    if fitness < global_best_fitness
                        global_best_fitness = fitness;
                        global_best_position = particles(p, :);
                        fprintf('  New best fitness: %.4f\n', global_best_fitness);
                    end
                end
                
                obj.fitness_history(iter) = global_best_fitness;
                fprintf('  Best fitness this iteration: %.4f\n', global_best_fitness);
                
                % Update velocities and positions
                for p = 1:obj.n_particles
                    r1 = rand(1, n_params);
                    r2 = rand(1, n_params);
                    
                    % Velocity update
                    velocities(p, :) = obj.inertia_weight * velocities(p, :) + ...
                                      obj.cognitive_coeff * r1 .* (personal_best_positions(p, :) - particles(p, :)) + ...
                                      obj.social_coeff * r2 .* (global_best_position - particles(p, :));
                    
                    % Position update
                    particles(p, :) = particles(p, :) + velocities(p, :);
                    
                    % Enforce bounds
                    particles(p, :) = obj.enforceBounds(particles(p, :));
                end
            end
            
            % Store results
            obj.best_params = obj.vectorToStruct(global_best_position);
            obj.best_fitness = global_best_fitness;
            
            best_params = obj.best_params;
            best_fitness = obj.best_fitness;
            
            fprintf('\n=== OPTIMIZATION COMPLETE ===\n');
            fprintf('Best fitness: %.4f\n', best_fitness);
            obj.displayBestParams();
        end
        
        function particles = initializeParticles(obj, n_params)
            % Initialize particle positions uniformly in search space
            particles = zeros(obj.n_particles, n_params);
            
            for i = 1:n_params
                param_name = obj.param_names{i};
                bounds = obj.param_bounds.(param_name);
                particles(:, i) = bounds(1) + (bounds(2) - bounds(1)) * rand(obj.n_particles, 1);
            end
        end
        
        function vector = enforceBounds(obj, vector)
            % Clip parameter vector to bounds
            for i = 1:length(vector)
                param_name = obj.param_names{i};
                bounds = obj.param_bounds.(param_name);
                vector(i) = max(bounds(1), min(bounds(2), vector(i)));
            end
        end
        
        function config = createConfig(obj, param_vector)
            % Create Config object from parameter vector
            config = obj.model_config_template;
            param_struct = obj.vectorToStruct(param_vector);
            
            % Override config fields with optimized parameters
            fields = fieldnames(param_struct);
            for i = 1:length(fields)
                config.(fields{i}) = param_struct.(fields{i});
            end
        end
        
        function param_struct = vectorToStruct(obj, vector)
            % Convert parameter vector to struct
            param_struct = struct();
            for i = 1:length(vector)
                param_struct.(obj.param_names{i}) = vector(i);
            end
        end
        
        function fitness = evaluateFitness(obj, config)
            % Run model and compute fitness (objective function)
            
            try
                % Run model
                model = Model(config);
                results = model.run();
                
                % Fitness: weighted combination of objectives
                % Minimize: final distance + mean free energy
                fitness = results.final_distance + 0.01 * mean(results.free_energy_combined);
                
            catch ME
                % Penalize failed runs heavily
                fprintf('  ERROR during evaluation: %s\n', ME.message);
                fitness = 1e6;
            end
        end
        
        function displayBestParams(obj)
            % Display best parameters found
            fprintf('\nBest Parameters:\n');
            fields = fieldnames(obj.best_params);
            for i = 1:length(fields)
                fprintf('  %s: %.6f\n', fields{i}, obj.best_params.(fields{i}));
            end
        end
        
        function plotConvergence(obj)
            % Plot PSO convergence history
            figure;
            plot(1:obj.n_iterations, obj.fitness_history, 'b-', 'LineWidth', 2);
            xlabel('Iteration');
            ylabel('Best Fitness');
            title('PSO Convergence');
            grid on;
        end
    end
end