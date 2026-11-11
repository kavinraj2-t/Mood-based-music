function setupProject()
    % SETUPPROJECT Initializes the Emotion Music Player MATLAB environment.
    %
    %   Syntax:
    %       setupProject()
    %
    %   Example:
    %       setupProject();
    %
    %   Adds src/, app/, scripts/, tests/, and data/ to the MATLAB search path.

    arguments
    end

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(projectRoot, 'src'));
    addpath(fullfile(projectRoot, 'app'));
    addpath(fullfile(projectRoot, 'scripts'));
    addpath(fullfile(projectRoot, 'tests'));
    addpath(fullfile(projectRoot, 'data'));
    savepath();

    fprintf('[setupProject] Emotion Music Player paths successfully added to MATLAB environment.\n');
    fprintf('[setupProject] Root directory: %s\n', projectRoot);
end
