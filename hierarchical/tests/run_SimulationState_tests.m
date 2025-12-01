% filepath: hierarchical/tests/run_SimulationState_tests.m

% Run all SimulationState unit tests
fprintf('Running SimulationState Unit Tests...\n');
fprintf('═══════════════════════════════════════\n\n');

% Add path to core directory
addpath(genpath('../'));

% Create test suite
suite = matlab.unittest.TestSuite.fromClass(?test_SimulationState);

% Run tests with detailed output
runner = matlab.unittest.TestRunner.withTextOutput;
results = runner.run(suite);

% Display summary
fprintf('\n═══════════════════════════════════════\n');
fprintf('TEST SUMMARY\n');
fprintf('═══════════════════════════════════════\n');
fprintf('Total Tests: %d\n', numel(results));
fprintf('Passed:      %d\n', sum([results.Passed]));
fprintf('Failed:      %d\n', sum([results.Failed]));
fprintf('Incomplete:  %d\n', sum([results.Incomplete]));
fprintf('Duration:    %.2f seconds\n', sum([results.Duration]));

if all([results.Passed])
    fprintf('\n✓ ALL TESTS PASSED\n');
else
    fprintf('\n✗ SOME TESTS FAILED\n');
    fprintf('\nFailed tests:\n');
    failed_tests = results(~[results.Passed]);
    for i = 1:length(failed_tests)
        fprintf('  - %s\n', failed_tests(i).Name);
    end
end

fprintf('═══════════════════════════════════════\n');