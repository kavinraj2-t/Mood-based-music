% MAIN Standalone script executing the full pipeline in the Command Window.
%
%   Steps:
%       1. Setup environment and load configuration
%       2. Obtain Spotify Bearer Token
%       3. Capture one frame from webcam
%       4. Detect facial emotion
%       5. Query Spotify for matching tracks
%       6. Display results and play audio preview

clear; clc;
setupProject();

fprintf('=== Emotion Music Player (MATLAB Pipeline) ===\n\n');

%% 1. Load Configuration
cfg = loadConfig();
fprintf('[1/5] Loaded config. Client ID: %s\n', cfg.spotify.clientId);

%% 2. Authenticate with Spotify
token = "";
if cfg.hasValidSpotify
    token = getSpotifyToken(cfg.spotify.clientId, cfg.spotify.clientSecret);
    fprintf('[2/5] Successfully authenticated with Spotify.\n');
else
    fprintf('[2/5] Spotify keys not set in config.json. Running camera & emotion pipeline.\n');
end

%% 3. Capture Webcam Snapshot
fprintf('[3/5] Capturing frame from your physical webcam...\n');
img = captureRealWebcam();
if isempty(img)
    warning('No physical webcam found. Generating synthetic test face...');
    img = generateSampleData();
end

%% 4. Emotion Detection
[emotion, scores, bbox] = detectEmotion(img);
fprintf('[4/5] Detected Emotion: **%s**\n', upper(emotion));

%% 5. Search Spotify
lang = "english";
genre = "pop";
query = emotionToQuery(emotion, lang, genre);
fprintf('[5/5] Formatted search query: "%s"\n\n', query);

tracks = struct('name', {}, 'artist', {}, 'url', {}, 'preview_url', {});
if token ~= ""
    tracks = searchSpotify(token, query);
    % Display results in table
    fprintf('%-30s | %-20s | %s\n', 'Track Name', 'Artist', 'Preview URL');
    fprintf('%s\n', repmat('-', 1, 80));
    for i = 1:numel(tracks)
        previewStatus = "Available";
        if tracks(i).preview_url == ""
            previewStatus = "N/A (Spotify Web Only)";
        end
        fprintf('%-30s | %-20s | %s\n', ...
            extractBefore(tracks(i).name + "                              ", 31), ...
            extractBefore(tracks(i).artist + "                    ", 21), ...
            previewStatus);
    end
else
    fprintf('[INFO] To fetch live songs, enter your Spotify Client ID & Secret in config.json\n');
end

%% Optional: Play First Available Audio Preview
for i = 1:numel(tracks)
    if tracks(i).preview_url ~= ""
        fprintf('\nStreaming 30s preview of: "%s" by %s\n', tracks(i).name, tracks(i).artist);
        player = AudioPlayerController();
        player.loadTrack(tracks(i).preview_url);
        player.play();
        pause(5); % Sample 5 seconds
        player.pause();
        delete(player);
        break;
    end
end

fprintf('\nPipeline finished successfully.\n');
