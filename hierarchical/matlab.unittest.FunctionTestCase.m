classdef FunctionTestCase < matlab.unittest.TestCase
    methods (Test)
        function testHelloWorld(testCase)
            result = HelloWorld();
            testCase.verifyEqual(result, 'Hello, World!');
        end
    end
end