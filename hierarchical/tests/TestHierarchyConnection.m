% filepath: c:\Users\srseb\OneDrive\School\FSU\Fall 2025\Symbolic Numeric Computation w Alan Lemmon\New_Project1\dual_hierarchy\hierarchical\tests\TestHierarchyConnection.m

addpath(genpath('../'));

fprintf('=== Testing Planning → Motor Connection ===\n\n');

% Setup
config_struct = struct();
config_struct.n_L1_motor = 7;
config_struct.n_L2_motor = 20;
config_struct.n_L3_motor = 10;
config_struct.n_L1_plan = 7;
config_struct.n_L2_plan = 15;
config_struct.n_L3_plan = 8;
config_struct.gravity = 9.81;
config_struct.dt = 0.02;
config_struct.workspace_bounds = [-5, 5; -5, 5; 0, 5];
config_struct.eta_rep = 0.01;
config_struct.eta_W = 0.001;
config_struct.momentum = 0.9;
config_struct.weight_decay = 0.98;
config_struct.motor_gain = 1.0;  % Add this line
config_struct.T_per_trial = 100;
config_struct.n_trials = 1;

config = Config(config_struct);
model = Model(config);

% Test: Give planning hierarchy a ball position
fprintf('1. Planning Hierarchy Input: Ball at (3, 3, 0)\n');
model.planningHierarchy.setTargetObservation(3, 3, 0);

% CRITICAL: Manually call predict to generate predictions
model.planningHierarchy.predict();

pred_L1 = model.planningHierarchy.getPredL1();
fprintf('   Planning L1 prediction after predict(): (%.2f, %.2f, %.2f)\n', ...
    pred_L1(1), pred_L1(2), pred_L1(3));

model.planningHierarchy.updateRepresentations();
[x_pred, y_pred, z_pred] = model.planningHierarchy.predictTargetPosition();
fprintf('   Planning predicts: (%.2f, %.2f, %.2f)\n\n', x_pred, y_pred, z_pred);

% Test: Pass planning prediction to motor hierarchy
fprintf('2. Motor Hierarchy receives target from Planning\n');
model.motorHierarchy.setPositionObservation(0, 0, 0);  % Player at origin
model.motorHierarchy.setTargetPosition(x_pred, y_pred, z_pred);

% Check what was set as prediction
pred_L1_motor = model.motorHierarchy.getPredL1();
fprintf('   Motor L1 velocity prediction set to: (%.2f, %.2f, %.2f)\n', ...
    pred_L1_motor(model.motorHierarchy.idx_vel(1)), ...
    pred_L1_motor(model.motorHierarchy.idx_vel(2)), ...
    pred_L1_motor(model.motorHierarchy.idx_vel(3)));

% REMOVED: model.motorHierarchy.predict();  % Don't call this!
% It overwrites pred_L1 with learned predictions

model.motorHierarchy.updateRepresentations();
[vx_cmd, vy_cmd, vz_cmd] = model.motorHierarchy.extractMotorCommand();
fprintf('   Motor commands: vx=%.2f, vy=%.2f, vz=%.2f\n', vx_cmd, vy_cmd, vz_cmd);

if abs(vx_cmd) > 0.01 || abs(vy_cmd) > 0.01
    fprintf('\n✓ Connection working! Motor is responding to planning target\n');
else
    fprintf('\n✗ Connection broken! Motor not generating movement toward target\n');
end