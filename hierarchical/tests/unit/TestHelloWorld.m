function tests = TestHelloWorld
    tests = functiontests(localfunctions);
end

function testHelloWorldFunction(testCase)
    result = HelloWorld();
    testCase.verifyEqual(result, 'Hello, World!');
end

function tf = localfunctions
    tf = {@testHelloWorldFunction};
end