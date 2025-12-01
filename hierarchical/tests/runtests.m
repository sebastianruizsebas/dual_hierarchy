function tests = runtests
    tests = functiontests(localfunctions);
end

function testHelloWorld(testCase)
    result = HelloWorld(); 
    testCase.verifyEqual(result, 'Hello, World!');
end

function tests = localfunctions
    tests = {@testHelloWorld};
end