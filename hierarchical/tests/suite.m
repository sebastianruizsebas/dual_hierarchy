function tests = suite
    tests = functiontests(localfunctions);
end

function testSuite(testCase)
    results = runtests('unit');
    disp(results);
end