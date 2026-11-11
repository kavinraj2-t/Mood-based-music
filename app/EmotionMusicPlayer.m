classdef EmotionMusicPlayer < handle
    % EMOTIONMUSICPLAYER Standalone desktop GUI for Emotion-Based Music Recommendations.
    %
    %   Syntax:
    %       app = EmotionMusicPlayer()
    %
    %   Example:
    %       EmotionMusicPlayer();

    properties (Access = private)
        UIFigure          matlab.ui.Figure
        WebcamAxes        matlab.ui.control.UIAxes
        StatusLabel       matlab.ui.control.Label
        MoodBadge         matlab.ui.control.Label
        StartStopButton   matlab.ui.control.Button
        LanguageDropdown  matlab.ui.control.DropDown
        GenreDropdown     matlab.ui.control.DropDown
        TrackTable        matlab.ui.control.Table
        PlayButton        matlab.ui.control.Button
        OpenSpotifyButton matlab.ui.control.Button
        SeekSlider        matlab.ui.control.Slider
        
        % Backend & State
        Config
        WebcamHandle
        TimerHandle
        AudioController
        SpotifyToken
        CurrentTracks = struct('name', {}, 'artist', {}, 'url', {}, 'preview_url', {})
        LastEmotion = ""
        IsCameraRunning = false
        AutoPlay = true
        ProjectRoot string = ""
    end

    methods
        function obj = EmotionMusicPlayer()
            % Constructor: load config and initialize UI
            obj.ProjectRoot = string(fileparts(fileparts(mfilename('fullpath'))));
            try
                obj.Config = loadConfig();
            catch ME
                errordlg(ME.message, "Configuration Error");
                return;
            end

            obj.AudioController = AudioPlayerController();
            obj.createUI();
            obj.refreshSpotifyToken();
        end
    end

    methods (Access = private)
        function createUI(obj)
            % Main window
            obj.UIFigure = uifigure( ...
                'Name', 'Emotion-Based Music Player', ...
                'Position', [100 100 850 620], ...
                'Color', [0.12 0.12 0.18], ...
                'CloseRequestFcn', @(~,~) obj.onClose());

            mainGrid = uigridlayout(obj.UIFigure, [4, 2]);
            mainGrid.RowHeight = {50, '1x', 180, 50};
            mainGrid.ColumnWidth = {380, '1x'};

            % 1. Header Title
            titleLabel = uilabel(mainGrid, ...
                'Text', '🎶 Emotion-Based Music Player', ...
                'FontColor', [1 1 1], ...
                'FontSize', 22, ...
                'FontWeight', 'bold');
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = [1 2];

            % 2. Video Preview Box
            obj.WebcamAxes = uiaxes(mainGrid);
            obj.WebcamAxes.Layout.Row = 2;
            obj.WebcamAxes.Layout.Column = 1;
            obj.WebcamAxes.Color = [0 0 0];
            obj.WebcamAxes.XTick = [];
            obj.WebcamAxes.YTick = [];
            title(obj.WebcamAxes, "Webcam Feed", 'Color', [0.8 0.8 0.8]);

            % 3. Preference & Control Panel (Right Side)
            prefGrid = uigridlayout(mainGrid, [6, 2]);
            prefGrid.Layout.Row = 2;
            prefGrid.Layout.Column = 2;
            prefGrid.BackgroundColor = [0.18 0.18 0.25];

            uilabel(prefGrid, 'Text', 'Language:', 'FontColor', [1 1 1], 'FontSize', 13);
            obj.LanguageDropdown = uidropdown(prefGrid, ...
                'Items', {'English', 'Hindi', 'Punjabi'}, ...
                'Value', 'English');

            uilabel(prefGrid, 'Text', 'Genre:', 'FontColor', [1 1 1], 'FontSize', 13);
            obj.GenreDropdown = uidropdown(prefGrid, ...
                'Items', {'Pop', 'Rock', 'Classical', 'Lofi'}, ...
                'Value', 'Pop');

            uilabel(prefGrid, 'Text', 'Detected Mood:', 'FontColor', [1 1 1], 'FontSize', 13);
            obj.MoodBadge = uilabel(prefGrid, ...
                'Text', 'Detecting...', ...
                'FontColor', [1 0.84 0], ...
                'FontSize', 16, ...
                'FontWeight', 'bold');

            uilabel(prefGrid, 'Text', 'Auto-Play Music:', 'FontColor', [1 1 1], 'FontSize', 13);
            uicheckbox(prefGrid, ...
                'Text', 'On Mood Change', ...
                'Value', true, ...
                'FontColor', [1 1 1], ...
                'ValueChangedFcn', @(src, ~) obj.onAutoPlayChanged(src.Value));

            obj.StartStopButton = uibutton(prefGrid, ...
                'Text', '▶ Start Camera', ...
                'BackgroundColor', [0.2 0.6 0.2], ...
                'FontColor', [1 1 1], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.toggleCamera());
            obj.StartStopButton.Layout.Column = [1 2];

            % 4. Track Table
            obj.TrackTable = uitable(mainGrid, ...
                'ColumnName', {'Song Title', 'Artist', 'Preview Available'}, ...
                'ColumnWidth', {'auto', 'auto', 120}, ...
                'BackgroundColor', [0.95 0.95 0.95], ...
                'SelectionType', 'row', ...
                'CellSelectionCallback', @(~,e) obj.onTrackSelected(e));
            obj.TrackTable.Layout.Row = 3;
            obj.TrackTable.Layout.Column = [1 2];

            % 5. Bottom Audio Control Bar
            audioGrid = uigridlayout(mainGrid, [1, 5]);
            audioGrid.Layout.Row = 4;
            audioGrid.Layout.Column = [1 2];
            audioGrid.ColumnWidth = {110, 150, '1x', 140, 100};

            obj.PlayButton = uibutton(audioGrid, ...
                'Text', '▶ Play', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.togglePlayback());

            obj.OpenSpotifyButton = uibutton(audioGrid, ...
                'Text', '🌐 Open on Spotify', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.openCurrentOnSpotify());

            obj.SeekSlider = uislider(audioGrid, ...
                'Limits', [0 1], ...
                'Value', 0, ...
                'ValueChangedFcn', @(~,~) obj.onSeek());

            obj.StatusLabel = uilabel(audioGrid, ...
                'Text', 'Ready', ...
                'FontColor', [0.8 0.8 0.8], ...
                'HorizontalAlignment', 'right');
        end

        function refreshSpotifyToken(obj)
            if ~obj.Config.hasValidSpotify
                obj.StatusLabel.Text = "Studio Beat Mode: Multi-Track Drum & Synth Engine";
                obj.AudioController.loadMoodAudio("happy");
                obj.PlayButton.Enable = 'on';
                obj.PlayButton.Text = '▶ Play Beat';
                obj.TrackTable.Data = { ...
                    '🔥 Upbeat Tropical Pop / EDM Beat', '122 BPM • Kick, Snare, Hi-Hats, Chords & Bass', 'Ready to Play'; ...
                    'To stream live Spotify songs', 'Add keys in config.json', 'config.json' ...
                };
                return;
            end
            try
                obj.SpotifyToken = getSpotifyToken( ...
                    obj.Config.spotify.clientId, ...
                    obj.Config.spotify.clientSecret);
                obj.StatusLabel.Text = "Spotify Connected";
            catch ME
                obj.StatusLabel.Text = "Spotify Auth Error";
                warning("Spotify connection failed: %s", ME.message);
            end
        end

        function toggleCamera(obj)
            if ~obj.IsCameraRunning
                obj.IsCameraRunning = true;
                obj.StartStopButton.Text = "⏹ Stop Camera";
                obj.StartStopButton.BackgroundColor = [0.8 0.2 0.2];
                obj.StatusLabel.Text = "Opening Camera Feed...";

                % Remove any previous stop flag
                flagFile = fullfile(obj.ProjectRoot, 'stop_camera.flag');
                if isfile(flagFile)
                    delete(flagFile);
                end

                % Launch continuous background AI camera service with log redirection
                pyService = fullfile(obj.ProjectRoot, 'scripts', 'camera_service.py');
                logFile = fullfile(obj.ProjectRoot, 'camera_log.txt');
                cmd = sprintf('start "" /b python -u "%s" > "%s" 2>&1', pyService, logFile);
                system(cmd);

                % Smooth 12-15 FPS display timer (every 0.08 seconds)
                obj.TimerHandle = timer( ...
                    'ExecutionMode', 'fixedRate', ...
                    'Period', 0.08, ...
                    'TimerFcn', @(~,~) obj.captureAndProcessFrame());
                start(obj.TimerHandle);
            else
                obj.stopCamera();
            end
        end

        function stopCamera(obj)
            if ~isempty(obj.TimerHandle) && isvalid(obj.TimerHandle)
                stop(obj.TimerHandle);
                delete(obj.TimerHandle);
                obj.TimerHandle = [];
            end

            % Signal Python camera service to release hardware
            flagFile = fullfile(obj.ProjectRoot, 'stop_camera.flag');
            fid = fopen(flagFile, 'w');
            if fid ~= -1
                fprintf(fid, 'stop');
                fclose(fid);
            end

            obj.IsCameraRunning = false;
            obj.StartStopButton.Text = "▶ Start Camera";
            obj.StartStopButton.BackgroundColor = [0.2 0.6 0.2];
            obj.StatusLabel.Text = "Camera Stopped";
        end

        function captureAndProcessFrame(obj)
            feedImg = fullfile(obj.ProjectRoot, 'temp_live_feed.jpg');
            infoJson = fullfile(obj.ProjectRoot, 'temp_live_info.json');

            if ~isfile(feedImg)
                obj.StatusLabel.Text = "Initializing Physical Camera Device...";
                return;
            end

            % 1. Render live camera frame smoothly
            try
                frame = imread(feedImg);
                image(obj.WebcamAxes, frame);
                axis(obj.WebcamAxes, 'image');
                obj.WebcamAxes.XTick = [];
                obj.WebcamAxes.YTick = [];
            catch
            end

            % 2. Read Deep Learning Emotion
            if isfile(infoJson)
                try
                    txt = fileread(infoJson);
                    info = jsondecode(txt);
                    if isfield(info, 'ai_ready') && ~info.ai_ready
                        obj.StatusLabel.Text = "Live Camera Active (Loading AI Emotion Engine...)";
                        obj.MoodBadge.Text = "DETECTING...";
                    elseif isfield(info, 'emotion') && info.emotion ~= "" && info.emotion ~= "detecting"
                        emotion = string(info.emotion);
                        obj.MoodBadge.Text = char(upper(emotion));
                        obj.StatusLabel.Text = "Live AI Camera Active";

                        if emotion ~= "no_face" && emotion ~= obj.LastEmotion
                            obj.LastEmotion = emotion;
                            obj.updateRecommendations(emotion);
                        end
                    end
                catch
                end
            end
        end

        function onAutoPlayChanged(obj, val)
            obj.AutoPlay = val;
            if ~val && obj.AudioController.IsPlaying
                obj.AudioController.pause();
                obj.PlayButton.Text = '▶ Play';
            end
        end

        function updateRecommendations(obj, emotion)
            lang = lower(string(obj.LanguageDropdown.Value));
            genre = lower(string(obj.GenreDropdown.Value));

            if isempty(obj.SpotifyToken) || ~obj.Config.hasValidSpotify
                obj.AudioController.loadMoodAudio(emotion);
                eKey = lower(char(emotion));
                switch eKey
                    case 'happy'
                        beatName = "🔥 Upbeat Tropical Pop / EDM Beat";
                        beatSub = "122 BPM • Kick, Snare, Hi-Hats, Chords & Bass";
                    case 'sad'
                        beatName = "🌧️ Melancholic Lo-Fi Ballad";
                        beatSub = "70 BPM • Soft Rhodes Piano, Warm 808 Sub-Bass & Vinyl";
                    case 'surprise'
                        beatName = "⚡ Futuristic Synthwave Beat";
                        beatSub = "128 BPM • 16th Arpeggios & Energetic Dance Drums";
                    case 'angry'
                        beatName = "🎸 Dark Cyberpunk Heavy Beat";
                        beatSub = "132 BPM • Distorted Saw Bass & Driving Percussion";
                    otherwise
                        beatName = "☕ Chillhop Jazz Study Beat";
                        beatSub = "82 BPM • Smooth 7th Chords & Relaxed Groove";
                end

                if obj.AutoPlay
                    obj.AudioController.play();
                    obj.PlayButton.Text = '⏸ Pause';
                    obj.StatusLabel.Text = char("🎵 Playing: " + beatName);
                else
                    obj.PlayButton.Text = '▶ Play Beat';
                    obj.StatusLabel.Text = char("Mood: " + upper(emotion) + " (Click Play to listen)");
                end
                obj.PlayButton.Enable = 'on';
                obj.TrackTable.Data = { ...
                    char(beatName), char(beatSub), 'Playing Now'; ...
                    'To stream live Spotify songs', 'Add keys in config.json', 'config.json' ...
                };
                return;
            end
            
            query = emotionToQuery(emotion, lang, genre);
            
            try
                obj.CurrentTracks = searchSpotify(obj.SpotifyToken, query);
                data = cell(numel(obj.CurrentTracks), 3);
                for i = 1:numel(obj.CurrentTracks)
                    data{i, 1} = char(obj.CurrentTracks(i).name);
                    data{i, 2} = char(obj.CurrentTracks(i).artist);
                    if obj.CurrentTracks(i).preview_url ~= ""
                        data{i, 3} = 'Yes';
                    else
                        data{i, 3} = 'No (Web Only)';
                    end
                end
                obj.TrackTable.Data = data;

                % Auto-play first available Spotify track
                if obj.AutoPlay && numel(obj.CurrentTracks) > 0 && obj.CurrentTracks(1).preview_url ~= ""
                    obj.AudioController.loadTrack(obj.CurrentTracks(1).preview_url);
                    obj.AudioController.play();
                    obj.PlayButton.Enable = 'on';
                    obj.PlayButton.Text = '⏸ Pause';
                    obj.StatusLabel.Text = sprintf("🎵 Auto-playing: %s", obj.CurrentTracks(1).name);
                else
                    obj.StatusLabel.Text = sprintf("Fetched %d songs for %s", numel(obj.CurrentTracks), upper(emotion));
                end
            catch ME
                obj.StatusLabel.Text = "Search Error";
                warning("Track fetch failed: %s", ME.message);
            end
        end

        function onTrackSelected(obj, event)
            if isempty(event.Indices)
                return;
            end
            row = event.Indices(1, 1);
            if ~obj.Config.hasValidSpotify || isempty(obj.CurrentTracks)
                emotion = obj.LastEmotion;
                if emotion == "" || emotion == "no_face", emotion = "happy"; end
                obj.AudioController.loadMoodAudio(emotion);
                obj.PlayButton.Enable = 'on';
                obj.PlayButton.Text = '▶ Play Melody';
                obj.StatusLabel.Text = char("Loaded " + upper(emotion) + " Melody. Click Play!");
                return;
            end
            if row <= numel(obj.CurrentTracks)
                track = obj.CurrentTracks(row);
                obj.OpenSpotifyButton.Enable = 'on';
                
                if track.preview_url ~= ""
                    obj.StatusLabel.Text = "Loading preview...";
                    success = obj.AudioController.loadTrack(track.preview_url);
                    if success
                        obj.PlayButton.Enable = 'on';
                        obj.PlayButton.Text = '▶ Play';
                        obj.StatusLabel.Text = "Preview Ready";
                    else
                        obj.PlayButton.Enable = 'off';
                    end
                else
                    obj.PlayButton.Enable = 'off';
                    obj.StatusLabel.Text = "Preview unavailable (use Web link)";
                end
            end
        end

        function togglePlayback(obj)
            if obj.AudioController.IsPlaying
                obj.AudioController.pause();
                obj.PlayButton.Text = '▶ Play';
            else
                obj.AudioController.play();
                obj.PlayButton.Text = '⏸ Pause';
            end
        end

        function onSeek(obj)
            fraction = obj.SeekSlider.Value;
            obj.AudioController.seek(fraction);
        end

        function openCurrentOnSpotify(obj)
            indices = obj.TrackTable.Selection;
            if ~isempty(indices)
                row = indices(1);
                if row <= numel(obj.CurrentTracks) && obj.CurrentTracks(row).url ~= ""
                    web(obj.CurrentTracks(row).url, '-browser');
                end
            end
        end

        function onClose(obj)
            obj.stopCamera();
            if ~isempty(obj.AudioController)
                delete(obj.AudioController);
            end
            delete(obj.UIFigure);
        end
    end
end
