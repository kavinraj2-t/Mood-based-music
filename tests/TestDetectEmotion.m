classdef TestDetectEmotion < matlab.unittest.TestCase
    % TESTDETECTEMOTION Unit tests for face and emotion detection pipeline.

    methods (Test)
        function testSyntheticImageDetection(testCase)
            img = generateSampleData();
            [emotion, scores, ~] = detectEmotion(img);
            
            testCase.verifyNotEmpty(emotion);
            testCase.verifyEqual(numel(scores), 7);
            testCase.verifyTrue(ismember(emotion, ["happy", "neutral", "surprise", "sad", "no_face"]));
        end

        function testBlankImageNoFace(testCase)
            blankImg = uint8(zeros(200, 200, 3));
            [emotion, ~, bbox] = detectEmotion(blankImg);
            
            testCase.verifyEqual(emotion, "no_face");
            testCase.verifyEmpty(bbox);
        end
    end
end
