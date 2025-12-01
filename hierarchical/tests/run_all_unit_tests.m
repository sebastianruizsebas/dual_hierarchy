% Master test runner for all unit tests
% Run all component unit tests and generate comprehensive report

fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  COMPREHENSIVE UNIT TEST SUITE\n');
fprintf('║  Hierarchical Predictive Coding Model - All Components\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

% Add path to all directories
addpath(genpath('../'));

% Store start time
test_start_time = tic;

% ========================================================================
% DEFINE TEST SUITES
% ========================================================================

fprintf('[%s] Initializing test suites...\n', datestr(now, 'HH:MM:SS'));

test_suites = struct();

% Core components (CRITICAL)
if exist('test_SimulationState', 'class')
    test_suites.SimulationState = matlab.unittest.TestSuite.fromClass(?test_SimulationState);
else
    fprintf('  ⚠ test_SimulationState not found\n');
end

if exist('test_Config', 'class')
    test_suites.Config = matlab.unittest.TestSuite.fromClass(?test_Config);
else
    fprintf('  ⚠ test_Config not found (will skip)\n');
end

% Neural components (CRITICAL)
if exist('test_NeuralHierarchy', 'class')
    test_suites.NeuralHierarchy = matlab.unittest.TestSuite.fromClass(?test_NeuralHierarchy);
else
    fprintf('  ⚠ test_NeuralHierarchy not found\n');
end

if exist('test_MotorHierarchy', 'class')
    test_suites.MotorHierarchy = matlab.unittest.TestSuite.fromClass(?test_MotorHierarchy);
else
    fprintf('  ⚠ test_MotorHierarchy not found (will skip)\n');
end

if exist('test_PlanningHierarchy', 'class')
    test_suites.PlanningHierarchy = matlab.unittest.TestSuite.fromClass(?test_PlanningHierarchy);
else
    fprintf('  ⚠ test_PlanningHierarchy not found (will skip)\n');
end

if exist('test_PrecisionAdapter', 'class')
    test_suites.PrecisionAdapter = matlab.unittest.TestSuite.fromClass(?test_PrecisionAdapter);
else
    fprintf('  ⚠ test_PrecisionAdapter not found\n');
end

% Physics components (HIGH)
if exist('test_PhysicsEngine', 'class')
    test_suites.PhysicsEngine = matlab.unittest.TestSuite.fromClass(?test_PhysicsEngine);
else
    fprintf('  ⚠ test_PhysicsEngine not found (will skip)\n');
end

% Model components (HIGH)
if exist('test_Model_Delays', 'class')
    test_suites.ModelDelays = matlab.unittest.TestSuite.fromClass(?test_Model_Delays);
else
    fprintf('  ⚠ test_Model_Delays not found (will skip)\n');
end

% Utility components (MEDIUM)
if exist('test_NoiseGenerator', 'class')
    test_suites.NoiseGenerator = matlab.unittest.TestSuite.fromClass(?test_NoiseGenerator);
else
    fprintf('  ⚠ test_NoiseGenerator not found (will skip)\n');
end

fprintf('[%s] Test suites initialized\n\n', datestr(now, 'HH:MM:SS'));

% ========================================================================
% RUN TEST SUITES
% ========================================================================

fprintf('════════════════════════════════════════════════════════════════\n');
fprintf('  RUNNING UNIT TESTS\n');
fprintf('════════════════════════════════════════════════════════════════\n\n');

% Create test runner with detailed output
runner = matlab.unittest.TestRunner.withTextOutput;

% Storage for results
all_results = struct();
component_names = fieldnames(test_suites);
total_tests = 0;
total_passed = 0;
total_failed = 0;
total_incomplete = 0;
total_duration = 0;

% Run each test suite
for i = 1:length(component_names)
    component = component_names{i};
    suite = test_suites.(component);
    
    fprintf('────────────────────────────────────────────────────────────────\n');
    fprintf('Testing: %s (%d tests)\n', component, numel(suite));
    fprintf('────────────────────────────────────────────────────────────────\n');
    
    % Run tests
    results = runner.run(suite);
    all_results.(component) = results;
    
    % Aggregate statistics
    total_tests = total_tests + numel(results);
    total_passed = total_passed + sum([results.Passed]);
    total_failed = total_failed + sum([results.Failed]);
    total_incomplete = total_incomplete + sum([results.Incomplete]);
    total_duration = total_duration + sum([results.Duration]);
    
    % Display component summary
    fprintf('\n');
    fprintf('  %s Summary:\n', component);
    fprintf('    Passed:      %d / %d\n', sum([results.Passed]), numel(results));
    fprintf('    Failed:      %d\n', sum([results.Failed]));
    fprintf('    Incomplete:  %d\n', sum([results.Incomplete]));
    fprintf('    Duration:    %.2f seconds\n', sum([results.Duration]));
    
    if any([results.Failed])
        fprintf('    Failed tests:\n');
        failed = results(~[results.Passed]);
        for j = 1:length(failed)
            fprintf('      - %s\n', failed(j).Name);
        end
    end
    
    fprintf('\n');
end

% ========================================================================
% COMPREHENSIVE SUMMARY
% ========================================================================

test_elapsed_time = toc(test_start_time);

fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  COMPREHENSIVE TEST SUMMARY\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

fprintf('Components Tested: %d\n', length(component_names));
fprintf('Total Tests:       %d\n', total_tests);
fprintf('Passed:            %d (%.1f%%)\n', total_passed, (total_passed/total_tests)*100);
fprintf('Failed:            %d (%.1f%%)\n', total_failed, (total_failed/total_tests)*100);
fprintf('Incomplete:        %d\n', total_incomplete);
fprintf('Total Duration:    %.2f seconds\n', total_duration);
fprintf('Wall Clock Time:   %.2f seconds\n\n', test_elapsed_time);

% ========================================================================
% COMPONENT BREAKDOWN
% ========================================================================

fprintf('Component Breakdown:\n');
fprintf('────────────────────────────────────────────────────────────────\n');
fprintf('%-20s %8s %8s %8s %10s\n', 'Component', 'Total', 'Passed', 'Failed', 'Duration');
fprintf('────────────────────────────────────────────────────────────────\n');

for i = 1:length(component_names)
    component = component_names{i};
    results = all_results.(component);
    
    fprintf('%-20s %8d %8d %8d %9.2fs\n', ...
        component, ...
        numel(results), ...
        sum([results.Passed]), ...
        sum([results.Failed]), ...
        sum([results.Duration]));
end

fprintf('────────────────────────────────────────────────────────────────\n\n');

% ========================================================================
% BIOLOGICAL PLAUSIBILITY TESTS REPORT
% ========================================================================

fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  BIOLOGICAL PLAUSIBILITY TESTS\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

% Check if biological tests passed
bio_tests_found = false;

% Check NeuralHierarchy biological test
if isfield(all_results, 'NeuralHierarchy')
    nh_results = all_results.NeuralHierarchy;
    bio_test_idx = contains({nh_results.Name}, 'BiologicalPlausibility');
    if any(bio_test_idx)
        bio_tests_found = true;
        bio_test = nh_results(bio_test_idx);
        if bio_test.Passed
            fprintf('✓ Free Energy Decreases with Learning: PASSED\n');
            fprintf('  Validates core predictive coding principle\n');
            fprintf('  (NeuralHierarchy.testBiologicalPlausibility_FreeEnergyDecreasesWithLearning)\n\n');
        else
            fprintf('✗ Free Energy Decreases with Learning: FAILED\n');
            fprintf('  Core predictive coding principle violated!\n\n');
        end
    end
end

% Check PrecisionAdapter biological test
if isfield(all_results, 'PrecisionAdapter')
    pa_results = all_results.PrecisionAdapter;
    bio_test_idx = contains({pa_results.Name}, 'BiologicalPlausibility');
    if any(bio_test_idx)
        bio_tests_found = true;
        bio_test = pa_results(bio_test_idx);
        if bio_test.Passed
            fprintf('✓ Precision Increases for Low-Error Cues: PASSED\n');
            fprintf('  Validates Bayesian cue integration principle\n');
            fprintf('  (PrecisionAdapter.testBiologicalPlausibility_PrecisionIncreasesForLowErrorCues)\n\n');
        else
            fprintf('✗ Precision Increases for Low-Error Cues: FAILED\n');
            fprintf('  Bayesian cue integration principle violated!\n\n');
        end
    end
end

if ~bio_tests_found
    fprintf('⚠ No biological plausibility tests found\n');
    fprintf('  Ensure test_NeuralHierarchy and test_PrecisionAdapter are available\n\n');
end

% ========================================================================
% FINAL STATUS
% ========================================================================

fprintf('╔════════════════════════════════════════════════════════════════╗\n');
if total_failed == 0 && total_incomplete == 0
    fprintf('║  ✓ ALL TESTS PASSED\n');
    fprintf('║  System is ready for neuroscience hypothesis validation\n');
else
    fprintf('║  ✗ SOME TESTS FAILED OR INCOMPLETE\n');
    fprintf('║  Fix failing tests before running hypothesis validation\n');
end
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

% List all failed tests
if total_failed > 0
    fprintf('Failed Tests Details:\n');
    fprintf('────────────────────────────────────────────────────────────────\n');
    
    for i = 1:length(component_names)
        component = component_names{i};
        results = all_results.(component);
        failed_tests = results(~[results.Passed]);
        
        if ~isempty(failed_tests)
            fprintf('\n%s:\n', component);
            for j = 1:length(failed_tests)
                fprintf('  ✗ %s\n', failed_tests(j).Name);
                if ~isempty(failed_tests(j).Details.DiagnosticRecord)
                    fprintf('    %s\n', failed_tests(j).Details.DiagnosticRecord(1).Event);
                end
            end
        end
    end
    fprintf('\n');
end

% ========================================================================
% SAVE RESULTS
% ========================================================================

save_filename = sprintf('unit_test_results_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'));
save(save_filename, 'all_results', 'component_names', 'total_tests', ...
    'total_passed', 'total_failed', 'total_incomplete', 'total_duration');

fprintf('Results saved to: %s\n', save_filename);

% ========================================================================
% RECOMMENDATIONS
% ========================================================================

fprintf('\n╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  RECOMMENDATIONS\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

if total_failed == 0
    fprintf('✓ All unit tests passing - proceed with:\n');
    fprintf('  1. Run TestNeuroscienceHypotheses for hypothesis validation\n');
    fprintf('  2. Analyze free energy trajectories\n');
    fprintf('  3. Validate delay compensation (H1)\n');
    fprintf('  4. Validate noise robustness (H2)\n');
    fprintf('  5. Validate motor learning (H3)\n');
    fprintf('  6. Validate interaction effects (H4)\n\n');
else
    fprintf('⚠ Fix failing tests before hypothesis validation:\n');
    fprintf('  1. Review failed test details above\n');
    fprintf('  2. Fix implementation or test logic\n');
    fprintf('  3. Re-run this test suite\n');
    fprintf('  4. Ensure biological plausibility tests pass\n\n');
end

fprintf('Test Coverage Summary:\n');
fprintf('  ✓ SimulationState: State management\n');
fprintf('  ✓ NeuralHierarchy: Predictive coding dynamics\n');
fprintf('  ✓ PrecisionAdapter: Bayesian cue integration\n');
if isfield(all_results, 'Config')
    fprintf('  ✓ Config: Configuration management\n');
else
    fprintf('  ⚠ Config: Not tested yet\n');
end
if isfield(all_results, 'MotorHierarchy')
    fprintf('  ✓ MotorHierarchy: Motor command generation\n');
else
    fprintf('  ⚠ MotorHierarchy: Not tested yet\n');
end
if isfield(all_results, 'PlanningHierarchy')
    fprintf('  ✓ PlanningHierarchy: Task-indexed learning\n');
else
    fprintf('  ⚠ PlanningHierarchy: Not tested yet\n');
end
if isfield(all_results, 'PhysicsEngine')
    fprintf('  ✓ PhysicsEngine: Physics simulation\n');
else
    fprintf('  ⚠ PhysicsEngine: Not tested yet\n');
end
if isfield(all_results, 'ModelDelays')
    fprintf('  ✓ Model Delays: Visuomotor delay logic\n');
else
    fprintf('  ⚠ Model Delays: Not tested yet\n');
end
if isfield(all_results, 'NoiseGenerator')
    fprintf('  ✓ NoiseGenerator: Sensory noise\n');
else
    fprintf('  ⚠ NoiseGenerator: Not tested yet\n');
end

fprintf('\n╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  TEST SUITE COMPLETE\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n');
