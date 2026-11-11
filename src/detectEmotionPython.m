function dominantEmotion = detectEmotionPython(rgbImage)
    % DETECTEMOTIONPYTHON Bridge calling Python's FER library via MATLAB pyenv.
    %
    %   Syntax:
    %       emotion = detectEmotionPython(rgbImage)
    %
    %   Example:
    %       img = imread("face.jpg");
    %       emotion = detectEmotionPython(img);
    %
    %   Inputs:
    %       rgbImage - RGB image matrix (uint8).
    %
    %   Outputs:
    %       dominantEmotion - Emotion string detected by Python FER package.

    arguments
        rgbImage (:,:,3) uint8 {mustBeNonempty}
    end

    persistent pyDetector;

    try
        if isempty(pyDetector)
            py.importlib.import_module('fer');
            pyDetector = py.fer.FER(pyargs('mtcnn', false));
        end

        % Convert MATLAB uint8 matrix to Python numpy array
        pyImg = py.numpy.array(rgbImage);
        result = pyDetector.detect_emotions(pyImg);

        if result.__len__() == 0
            dominantEmotion = "neutral";
            return;
        end

        emotionsDict = result{1}{'emotions'};
        keys = cell(py.list(emotionsDict.keys()));
        vals = double(py.array.array('d', py.list(emotionsDict.values())));
        
        [~, maxIdx] = max(vals);
        dominantEmotion = string(keys{maxIdx});
    catch ME
        warning("detectEmotionPython:PythonBridgeFailed", ...
            "Python FER bridge failed (%s). Defaulting to 'neutral'.", ME.message);
        dominantEmotion = "neutral";
    end
end
