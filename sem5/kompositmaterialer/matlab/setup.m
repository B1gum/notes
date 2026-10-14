%% Composite Materials MATLAB setup
% Adds the course MATLAB subdirectories to the path.

root = fileparts(mfilename('fullpath'));

addpath(root);
addpath(fullfile(root, 'micromechanics'));
addpath(fullfile(root, 'lamina'));
addpath(fullfile(root, 'laminate'));
addpath(fullfile(root, 'failure'));
addpath(fullfile(root, 'plotting'));
addpath(fullfile(root, 'exercises'));

clear root
