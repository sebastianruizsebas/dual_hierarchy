% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\RunOptimization.m

% Run PSO optimization on the hierarchical model

% Add all paths
addpath(genpath('../'));

% Create base configuration
config_struct = struct();
config_struct.n_L1_motor = 7;
config_struct.n_L2_motor = 20;
config_struct.n_L3_motor = 10;
config_struct.n_L1_plan = 7;
config_struct.n_L2_plan = 15;
config_struct.n_L3_plan = 8;
config_struct.gravity = 9.81;
config_struct.air_drag = 0.01;
config_struct.restitution = 0.8;
config_struct.ground_friction = 0.9;
config_struct.dt = 0.02;
config_struct.workspace_bounds = [-5, 5; -5, 5; 0, 5];
config_struct.eta_rep = 0.01;
config_struct.eta_W = 0.001;
config_struct.momentum = 0.9;
config_struct.weight_decay = 0.98;
config_struct.T_per_trial = 10;
config_struct.n_trials = 50;  % Fewer trials for optimization

% Define parameters to optimize
param_names = {'eta_rep', 'eta_W', 'momentum', 'weight_decay'};

% Define bounds for each parameter [lower, upper]
param_bounds = [
    0.001, 0.1;      % eta_rep
    0.0001, 0.01;    % eta_W
    0.5, 0.99;       % momentum
    0.9, 0.999       % weight_decay
];

% PSO settings
pso_options = struct();
pso_options.SwarmSize = 20;
pso_options.MaxIterations = 30;
pso_options.Display = 'iter';
pso_options.UseParallel = false;  % Set to true if you have Parallel Computing Toolbox

% Create PSO wrapper
pso = PSOWrapper(config_struct, param_names, param_bounds, pso_options);

% Define objective function (minimize final distance)
objective_fn = @(params) evaluateModel(params, config_struct, param_names);

% Run optimization
fprintf('Starting PSO optimization...\n');
[best_params, best_cost] = pso.optimize(objective_fn);

% Display results
fprintf('\n=== Optimization Results ===\n');
fprintf('Best cost (final distance): %.4f\n', best_cost);
fprintf('Best parameters:\n');
for i = 1:length(param_names)
    fprintf('  %s = %.6f\n', param_names{i}, best_params(i));
end

% Run final simulation with best parameters
fprintf('\nRunning final simulation with optimized parameters...\n');
for i = 1:length(param_names)
    config_struct.(param_names{i}) = best_params(i);
end

config = Config(config_struct);
model = Model(config);
results = model.run();

fprintf('Final optimized distance: %.4f\n', results.final_distance);

% Save results
save('optimization_results.mat', 'best_params', 'best_cost', 'param_names', 'results');
fprintf('Results saved to optimization_results.mat\n');

%% Helper function to evaluate model with given parameters
function cost = evaluateModel(params, base_config, param_names)
    % Update config with new parameters
    config_struct = base_config;
    for i = 1:length(param_names)
        config_struct.(param_names{i}) = params(i);
    end
    
    % Run model
    try
        config = Config(config_struct);
        model = Model(config);
        results = model.run();
        
        % Cost function: minimize final distance + penalty for instability
        cost = results.final_distance;
        
        % Add penalty for NaN/Inf values
        if isnan(cost) || isinf(cost)
            cost = 1e6;
        end
    catch ME
        % If simulation fails, return large cost
        fprintf('Simulation failed: %s\n', ME.message);
        cost = 1e6;
    end
end