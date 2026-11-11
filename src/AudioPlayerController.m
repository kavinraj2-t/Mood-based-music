classdef AudioPlayerController < handle
    % AUDIOPLAYERCONTROLLER Manages streaming, playback, and seek for 30s previews.
    %
    %   Usage Example:
    %       controller = AudioPlayerController();
    %       controller.loadTrack("https://p.scdn.co/mp3-preview/...");
    %       controller.play();
    %       controller.seek(0.5); % 50%
    %       controller.pause();

    properties (Access = private)
        PlayerHandle = []
        SampleRate = 44100
        AudioBuffer = []
        TotalSamples = 0
        TempFilePath = ""
    end

    properties (SetAccess = private)
        IsPlaying = false
        CurrentUrl = ""
    end

    methods
        function obj = AudioPlayerController()
            % Constructor
        end

        function success = loadTrack(obj, previewUrl)
            arguments
                obj (1,1) AudioPlayerController
                previewUrl (1,1) string
            end

            obj.stop();
            success = false;

            if previewUrl == ""
                return;
            end

            try
                % Download preview MP3 to temp location
                obj.TempFilePath = fullfile(tempdir, "temp_preview_" + string(posixtime(datetime('now'))) + ".mp3");
                websave(obj.TempFilePath, previewUrl, weboptions('Timeout', 10));
                
                [y, Fs] = audioread(obj.TempFilePath);
                obj.AudioBuffer = y;
                obj.SampleRate = Fs;
                obj.TotalSamples = size(y, 1);
                obj.CurrentUrl = previewUrl;
                
                obj.PlayerHandle = audioplayer(obj.AudioBuffer, obj.SampleRate);
                success = true;
            catch ME
                warning("AudioPlayerController:LoadError", "Could not load audio preview: %s", ME.message);
            end
        end

        function success = loadMoodAudio(obj, emotion)
            arguments
                obj (1,1) AudioPlayerController
                emotion (1,1) string
            end

            obj.stop();
            cleanEmotion = lower(char(emotion));
            if strcmp(cleanEmotion, 'no_face') || strcmp(cleanEmotion, 'detecting')
                cleanEmotion = 'neutral';
            end

            % 1. Try loading studio-quality multi-track beats from assets/music
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            wavFile = fullfile(projectRoot, 'assets', 'music', [cleanEmotion, '.wav']);
            if isfile(wavFile)
                try
                    [y, Fs] = audioread(wavFile);
                    obj.AudioBuffer = y;
                    obj.SampleRate = Fs;
                    obj.TotalSamples = size(y, 1);
                    obj.PlayerHandle = audioplayer(obj.AudioBuffer, obj.SampleRate);
                    success = true;
                    return;
                catch ME
                    warning("AudioPlayerController:WavLoad", "Failed reading wav: %s", ME.message);
                end
            end

            % 2. Fallback harmonic synthesizer
            Fs = 22050;
            switch cleanEmotion
                case 'happy'
                    notes = [261.63, 329.63, 392.00, 523.25, 440.00, 349.23, 392.00, 523.25];
                    dur = 0.35;
                case 'sad'
                    notes = [220.00, 261.63, 329.63, 196.00, 246.94, 293.66, 164.81, 220.00];
                    dur = 0.70;
                case 'surprise'
                    notes = [329.63, 392.00, 493.88, 587.33, 659.25, 783.99, 987.77];
                    dur = 0.20;
                    repeats = 16;
                case 'angry'
                    notes = [130.81, 138.59, 146.83, 130.81, 164.81, 155.56, 146.83, 130.81];
                    dur = 0.30;
                    repeats = 10;
                otherwise
                    notes = [261.63, 329.63, 392.00, 493.88, 220.00, 261.63, 329.63, 392.00];
                    dur = 0.50;
                    repeats = 6;
            end
            if strcmp(lower(char(emotion)), 'happy')
                repeats = 8;
            elseif strcmp(lower(char(emotion)), 'sad')
                repeats = 4;
            end
            
            t_note = 0:(1/Fs):dur;
            y = [];
            for n = notes
                tone = 0.5 * sin(2*pi*n*t_note) + 0.3 * sin(4*pi*n*t_note) + 0.1 * sin(6*pi*n*t_note);
                env = exp(-2.5 * t_note / dur);
                y = [y, tone .* env];
            end
            y = repmat(y, 1, repeats);
            y = (y' / (max(abs(y)) + 1e-4)) * 0.8;
            
            obj.AudioBuffer = y;
            obj.SampleRate = Fs;
            obj.TotalSamples = size(y, 1);
            obj.PlayerHandle = audioplayer(obj.AudioBuffer, obj.SampleRate);
            success = true;
        end

        function play(obj)
            if ~isempty(obj.PlayerHandle)
                if ~isplaying(obj.PlayerHandle)
                    try
                        resume(obj.PlayerHandle);
                    catch
                        play(obj.PlayerHandle);
                    end
                    if ~isplaying(obj.PlayerHandle)
                        play(obj.PlayerHandle);
                    end
                end
                obj.IsPlaying = true;
            end
        end

        function pause(obj)
            if ~isempty(obj.PlayerHandle)
                pause(obj.PlayerHandle);
                obj.IsPlaying = false;
            end
        end

        function stop(obj)
            if ~isempty(obj.PlayerHandle)
                stop(obj.PlayerHandle);
                obj.IsPlaying = false;
            end
            if obj.TempFilePath ~= "" && isfile(obj.TempFilePath)
                try
                    delete(obj.TempFilePath);
                catch
                end
                obj.TempFilePath = "";
            end
        end

        function seek(obj, fractionalProgress)
            arguments
                obj (1,1) AudioPlayerController
                fractionalProgress (1,1) double {mustBeInRange(fractionalProgress, 0, 1)}
            end

            if isempty(obj.AudioBuffer)
                return;
            end

            startSample = max(1, round(fractionalProgress * obj.TotalSamples));
            wasPlaying = obj.IsPlaying;
            
            stop(obj.PlayerHandle);
            obj.PlayerHandle = audioplayer(obj.AudioBuffer, obj.SampleRate);
            if wasPlaying
                play(obj.PlayerHandle, startSample);
                obj.IsPlaying = true;
            end
        end

        function progress = getProgress(obj)
            if isempty(obj.PlayerHandle) || obj.TotalSamples == 0
                progress = 0;
                return;
            end
            currentSample = get(obj.PlayerHandle, 'CurrentSample');
            progress = min(1.0, currentSample / obj.TotalSamples);
        end

        function delete(obj)
            obj.stop();
        end
    end
end
