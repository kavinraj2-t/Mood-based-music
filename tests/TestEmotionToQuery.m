classdef TestEmotionToQuery < matlab.unittest.TestCase
    % TESTEMOTIONTOQUERY Unit tests for query string formatting.

    methods (Test)
        function testValidQueryConstruction(testCase)
            q = emotionToQuery("happy", "english", "pop");
            testCase.verifyEqual(q, "happy english pop");
        end

        function testNoFaceFallback(testCase)
            q = emotionToQuery("no_face", "hindi", "lofi");
            testCase.verifyEqual(q, "neutral hindi lofi");
        end

        function testCaseInsensitivity(testCase)
            q = emotionToQuery("SURPRISE", "English", "Rock");
            testCase.verifyEqual(q, "surprise english rock");
        end
    end
end
