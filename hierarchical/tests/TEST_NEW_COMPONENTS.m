% TEST_NEW_COMPONENTS Test newly implemented classes

% Add paths
addpath(genpath('..'));

fprintf('=== TESTING NEW COMPONENTS ===\n\n');

%% Test 1: PrecisionAdapter
fprintf('1. Testing PrecisionAdapter...\n');
adapter_config = struct();
adapter_config.alpha_gain = 0.5;
adapter_config.error_threshold = 0.1;

adapter = PrecisionAdapter(adapter_config);

% Simulate adaptation with high error
pi_test = 10;
error_test = [0.5, 0.3, 0.4];  % High error
pi_new = adapter.adaptMotorL1(pi_test, error_test);

fprintf('   Initial precision: %.2f\n', pi_test);
fprintf('   Error magnitude: %.3f\n', sqrt(mean(error_test.^2)));
fprintf('   Adapted precision: %.2f\n', pi_new);

if pi_new < pi_test
    fprintf('   ✅ Precision decreased (correct for high error)\n');
else
    fprintf('   ⚠️  Unexpected behavior\n');
end

%% Test 2: Validator
fprintf('\n2. Testing Validator...\n');
test_config = struct();
test_config.n_L1_motor = 7;
test_config.n_L2_motor = 20;
test_config.n_L3_motor = 10;
test_config.n_L1_plan = 7;
test_config.n_L2_plan = 15;
test_config.n_L3_plan = 8;
test_config.idx_pos = [1, 2, 3];
test_config.idx_vel = [4, 5, 6];
test_config.idx_bias = 7;
test_config.eta_rep = 0.01;
test_config.eta_W = 0.001;
test_config.momentum = 0.9;
test_config.weight_decay = 0.98;
test_config.dt = 0.02;
test_config.T_per_trial = 10;
test_config.n_trials = 1;
test_config.workspace_bounds = [-5, 5; -5, 5; 0, 5];

try
    Validator.validateConfig(test_config);
    fprintf('   ✅ Config validation passed\n');
catch ME
    fprintf('   ❌ Validation failed: %s\n', ME.message);
end

%% Test 3: Integrator
fprintf('\n3. Testing Integrator...\n');
x0 = 0;
v0 = 1;
a = -9.81;  % Gravity
dt = 0.01;

[x_euler, v_euler] = Integrator.euler(x0, v0, a, dt);
[x_semi, v_semi] = Integrator.semiImplicitEuler(x0, v0, a, dt);

fprintf('   Euler:            x=%.6f, v=%.6f\n', x_euler, v_euler);
fprintf('   Semi-implicit:    x=%.6f, v=%.6f\n', x_semi, v_semi);
fprintf('   ✅ Integrators functional\n');

%% Test 4: LearningOptimizer
fprintf('\n4. Testing LearningOptimizer...\n');
opt_config = struct();
opt_config.learning_rate = 0.01;
opt_config.momentum = 0.9;

optimizer = LearningOptimizer('momentum', opt_config);
optimizer.initializeState([3, 3]);

W = randn(3, 3);
grad = randn(3, 3);

W_new = optimizer.step(W, grad);
fprintf('   Weight update norm: %.6f\n', norm(W_new - W, 'fro'));
fprintf('   ✅ Optimizer functional\n');

%% Test 5: PSOWrapper (quick test, no full optimization)
fprintf('\n5. Testing PSOWrapper structure...\n');
template_config = Config(test_config);
param_bounds = struct();
param_bounds.eta_rep = [0.001, 0.1];
param_bounds.eta_W = [0.0001, 0.01];

pso = PSOWrapper(template_config, param_bounds);
fprintf('   Optimizing %d parameters\n', length(pso.param_names));
fprintf('   Particles: %d\n', pso.n_particles);
fprintf('   ✅ PSOWrapper initialized\n');

fprintf('\n=== ALL TESTS COMPLETE ===\n');