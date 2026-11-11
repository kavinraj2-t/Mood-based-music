function frame = captureRealWebcam()
    % CAPTUREREALWEBCAM Captures a real live frame from the physical camera.
    % Seamlessly tries MATLAB webcam() first, or uses Python OpenCV grabber.
    %
    %   Syntax:
    %       frame = captureRealWebcam()
    %
    %   Outputs:
    %       frame - RGB image matrix (uint8) or empty if no camera detected.

    arguments
    end

    persistent camObj;
    persistent hasCheckedMatlabCam;
    frame = [];

    % 1. Try native MATLAB USB webcam package if available
    if isempty(hasCheckedMatlabCam)
        hasCheckedMatlabCam = (exist('webcamlist', 'file') == 2 || exist('webcamlist', 'builtin') == 5);
    end

    if hasCheckedMatlabCam
        try
            if isempty(camObj)
                cams = webcamlist;
                if ~isempty(cams)
                    camObj = webcam(1);
                end
            end
            if ~isempty(camObj)
                frame = snapshot(camObj);
                return;
            end
        catch
            hasCheckedMatlabCam = false;
        end
    end

    % 2. Seamless Real Hardware Camera Grabber via OpenCV
    projectDir = fileparts(fileparts(mfilename('fullpath')));
    pyScript = fullfile(projectDir, 'scripts', 'snapshot_cam.py');
    tempFile = fullfile(tempdir, 'matlab_live_cam.jpg');

    cmd = sprintf('python "%s" "%s"', pyScript, tempFile);
    [status, ~] = system(cmd);

    if status == 0 && isfile(tempFile)
        try
            frame = imread(tempFile);
        catch
            frame = [];
        end
    end
end
