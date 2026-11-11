function query = emotionToQuery(emotion, language, genre)
    % EMOTIONTOQUERY Maps emotion and user preferences to a Spotify search query.
    %
    %   Syntax:
    %       query = emotionToQuery(emotion, language, genre)
    %
    %   Example:
    %       q = emotionToQuery("happy", "english", "pop");
    %
    %   Inputs:
    %       emotion  - Detected emotion string (e.g. 'happy', 'sad', 'neutral').
    %       language - Selected language preference (e.g. 'english', 'hindi', 'punjabi').
    %       genre    - Selected genre preference (e.g. 'pop', 'rock', 'lofi').
    %
    %   Outputs:
    %       query    - Formatted query string for Spotify search API.

    arguments
        emotion (1,1) string {mustBeMember(emotion, ["happy", "sad", "angry", "surprise", "neutral", "fear", "disgust", "no_face"])}
        language (1,1) string {mustBeNonempty}
        genre (1,1) string {mustBeNonempty}
    end

    % Normalize 'no_face' to neutral fallback query
    cleanEmotion = emotion;
    if cleanEmotion == "no_face"
        cleanEmotion = "neutral";
    end

    % Preserves original query logic: "{emotion} {language} {genre}"
    query = sprintf("%s %s %s", lower(cleanEmotion), lower(language), lower(genre));
end
