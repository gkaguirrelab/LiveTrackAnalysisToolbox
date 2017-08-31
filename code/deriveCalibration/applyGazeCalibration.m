function applyGazeCalibration(pupilFileName,glintFileName,gazeCalParamsFileName,calibratedGazeFileName,varargin)
% applySizeCalibration(pupilFileName,sizeFactorsFileName,calibratedPupilFileName)
%
% this function applies the gaze calibration parameters to the raw pupil
% and glint data.
% 
% All the necessary calibration parameters are stored in the gazeCalParams
% file.
% The calibration strategy is as follows:
% 
% [aXYZW] = calMatrix * [(pX-gX)/Rpc; (pY-gY)/Rpc; (1 - sqrt(((pX-gX)/Rpc)^2 + ((pY-gY)/Rpc)^2)); 1];
% [calGazeX;calGazeY;viewingDistance] =    (aXYZW(1:3)/aXYZW(4))';
% 
% Where:
%   aXYZW = calibrated Gaze Data in homogeneous screen coordinates
%   calMatrix = calibration matrix
%   [pX pY] = center of pupil in pixels
%   [gX gY] = center of glint in pixels
%   Rpc = relative perspective correction (between target and apparent gaze
%       vector)
%   
% Note that the first line applies the calMatrix to the 3-D projection of
% the apparent gaze vector (in pixels) in homogeneous coordinates, while
% the second line converts the calibrated data from homogeneous
% coordinates to 3-D screen coordinates, where the 3rd dimension is the
% distance between the observer and the screen.
% 
% More info about the calibration strategy can be found in the
% calcCalibrationMatrix and calcRpc functions header.
% 
% OUTPUTS: (saved to file)
%   calibratedGaze: struct containing the calibrated pupil width, height
%   and area. The calibrated units are dependent on the size calibration
%   method used.
% 
% 
% INPUTS:
%   pupilFileName: name of the file with the pupil data to be calibrated, 
%       as it results from the pupil pipeline.
%   glintFileName: name of the mat with glint data
%   gazeCalParamsFileName: name of the mat file with the gaze calibration
%       params.
%   calibratedGazeFileName: name of the output file containing the
%       calibrated data
% 
% Optional params:
%   calibratedUnits: units in which the calibrated data is expressed
%       (default [mmOnScreen])
%   whichFitToCalibrate: which of the pupil fit resulting from
%   fitPupilPerimeter to calibrate (default pPosteriorMeanTransparent).
% 
% Optional key/value pairs (display and I/O)
%  'verbosity' - level of verbosity. [none, full]
%
% Options (environment)
%   tbSnapshot - the passed tbSnapshot output that is to be saved along
%      with the data
%   timestamp / username / hostname - these are automatically derived and
%      saved within the p.Results structure.
%
%% Parse vargin for options passed here
p = inputParser; p.KeepUnmatched = true;

% Required
p.addRequired('pupilFileName',@ischar);
p.addRequired('glintFileName',@ischar);
p.addRequired('gazeCalParamsFileName',@ischar);
p.addRequired('calibratedGazeFileName',@ischar);

% Optional analysis parameters
p.addParameter('calibratedUnits','mm', @ischar);
p.addParameter('whichFitToCalibrate','pPosteriorMeanTransparent', @ischar);

% Optional display and I/O parameters
p.addParameter('verbosity','none', @ischar);

% Environment parameters
p.addParameter('tbSnapshot',[],@(x)(isempty(x) | isstruct(x)));
p.addParameter('timestamp',char(datetime('now')),@ischar);
p.addParameter('username',char(java.lang.System.getProperty('user.name')),@ischar);
p.addParameter('hostname',char(java.net.InetAddress.getLocalHost.getHostName),@ischar);

% parse
p.parse(pupilFileName, glintFileName, gazeCalParamsFileName,calibratedGazeFileName, varargin{:})

%% load pupil data
tmpData = load(pupilFileName);
% pull transparent raw pupil data
rawPupilTransparent = tmpData.pupilData.(p.Results.whichFitToCalibrate);
% extract X and Y coordinates of pupil center
pupil.X = rawPupilTransparent(:,1);
pupil.Y = rawPupilTransparent(:,2);

clear tmpData
clear rawPupilTransparent
%% load glint data
tmpData = load(glintFileName);
% extract X and Y coordinates of glint center
glint.X = tmpData.glintData.X;
glint.Y = tmpData.glintData.Y;

clear tmpData
%% load gaze calibration params
tmpData = load(gazeCalParamsFileName);

calMatrix = tmpData.gazeCalibration.calMatrix;
Rpc = tmpData.gazeCalibration.Rpc;

clear tmpData
%% apply calibration to data

% intialize gaze variables
calibratedGaze.X = nan(size(pupil.X));
calibratedGaze.Y = nan(size(pupil.X));
tmp = nan(length(pupil.X),3);

for i = 1:length(pupil.X)
    pX = pupil.X(i);
    pY = pupil.Y(i);
    gX = glint.X(i);
    gY = glint.Y(i);
    % calculate apparent gaze vector in homogeneous coordinates
    aXYZW = calMatrix * [...
        (pX-gX)/Rpc; ...
        (pY-gY)/Rpc; ...
        (1 - sqrt(((pX-gX)/Rpc)^2 + ((pY-gY)/Rpc)^2)); ...
        1];
    % homogeneous divide (convert in 3-d)
    tmp(i,:) = (aXYZW(1:3)/aXYZW(4))';
end

%  pull out the X and Y values
calibratedGaze.X = tmp(:,1);
calibratedGaze.Y = tmp(:,2);

%% save out calibrated gaze and metadata
calibratedGaze.meta = p.Results;

save(calibratedGazeFileName,'calibratedGaze');
