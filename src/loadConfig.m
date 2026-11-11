function config = loadConfig(configFilePath)
    % LOADCONFIG Reads application and API credentials from a JSON config file.
    %
    %   Syntax:
    %       config = loadConfig()
    %       config = loadConfig(configFilePath)
    %
    %   Example:
    %       cfg = loadConfig("config.json");
    %       disp(cfg.spotify.clientId);
    %
    %   Inputs:
    %       configFilePath - (Optional) Path to config JSON file.
    %                        Defaults to fullfile(projectRoot, 'config.json').
    %
    %   Outputs:
    %       config         - Struct containing configuration parameters.

    arguments
        configFilePath (1,1) string = ""
    end

    if configFilePath == ""
        baseDir = fileparts(fileparts(mfilename('fullpath')));
        configFilePath = fullfile(baseDir, "config.json");
    end

    % Default template config in case file is missing
    config = struct();
    config.spotify = struct('clientId', "", 'clientSecret', "");
    config.app = struct( ...
        'cameraIndex', 1, ...
        'detectIntervalSeconds', 5, ...
        'defaultLanguage', "english", ...
        'defaultGenre', "pop", ...
        'modelPath', "data/emotion-ferplus.onnx" ...
    );
    config.hasValidSpotify = false;

    if isfile(configFilePath)
        try
            rawText = fileread(configFilePath);
            loadedConfig = jsondecode(rawText);
            if isfield(loadedConfig, 'spotify')
                config.spotify = loadedConfig.spotify;
            end
            if isfield(loadedConfig, 'app')
                config.app = loadedConfig.app;
            end
        catch ME
            warning("loadConfig:InvalidJSON", "Failed to parse JSON config file: %s", ME.message);
        end
    end

    % Check if real Spotify credentials are provided
    if isfield(config.spotify, 'clientId') && ...
       isfield(config.spotify, 'clientSecret') && ...
       config.spotify.clientId ~= "" && ...
       config.spotify.clientSecret ~= "" && ...
       ~strcmpi(config.spotify.clientId, "YOUR_SPOTIFY_CLIENT_ID")
        config.hasValidSpotify = true;
    else
        config.hasValidSpotify = false;
    end
end
