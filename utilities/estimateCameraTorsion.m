function cameraTorsionStruct = estimateCameraTorsion(grayVideoName, varargin)
% Estimate camera torsion by reference to the medial and lateral canthus
%
% Syntax:
%  cameraTorsionStruct = estimateCameraTorsion(grayVideoName)
%
% Description:
%   The cameraTorsion parameter of sceneGeometry describes the rotation of
%   the camera with respect to the azimuthal plane for rotation of the eye.
%   We can estimate the camera torsion by reference to medial and lateral
%   canthii of the eye. In most people there is a positive "canthal angle",
%   meaning that the medial canthus is slightly lower on the face than the
%   lateral canthus. This angle varies with age (due to sagging of the soft
%   tissues of the lateral canthus), but in young people the principle
%   source of biometric variation is ethnicity. Faces with "asian" features
%   have a larger, positive canthal angle in comparison to faces with
%   "caucasian" or "black" features.
%
%   This routine presents a frame from a gray video along with an ROI line.
%   Adjust the line so that the ends terminate in the medial and lateral
%   canthii. Press return. The variable cameraTorsionStruct will report the
%   predicted camera torsion, with fields giving the values for the left or
%   right eye, and for different ethnicities.
%
% Inputs:
%	grayVideoName         - Full path to the video in which to track the
%
% Optional key/value pairs (flow control)
%  'startFrame'           - First frame from which to start the analysis.
%

%% parse input and define variables

p = inputParser; p.KeepUnmatched = true;

% Required
p.addRequired('grayVideoName',@isstr);

% Optional flow control params
p.addParameter('startFrame',1,@isnumeric);

% parse
p.parse(grayVideoName, varargin{:})


% If the grayVideoName is empty, provide a file picker GUI
if isempty(grayVideoName)
    [fileName, path] = uigetfile({'*.mp4;*.mov;*avi'});
    if isempty(fileName)
        returne
    end
    grayVideoName = [path, fileName];
else
    grayVideoName = p.Results.grayVideoName;
end

% Prepare the video object
videoInObj = videoIOWrapper(grayVideoName,'ioAction','read');

% Grab the image dimensions
width = videoInObj.Width;
height = videoInObj.Height;

% read the video desired frame into memory, adjust gamma
thisFrame = read(videoInObj,p.Results.startFrame);

% close the video object
clear videoInObj

% create a figure for display
figureHandle=figure();

% Show the image
imageHandle = imshow(thisFrame,'Border', 'tight', 'InitialMagnification', 200);

roi = images.roi.Line(gca,'Position',[round(width*0.8), round(height*0.25);round(width*0.25),round(height*0.25)]);

% Enter a while loop
notDoneFlag = true;

% Wait until the user is done (presses return or hits 'q')
while notDoneFlag
    
    % Wait for operator input
    waitforbuttonpress
    keyChoiceValue = double(get(gcf,'CurrentCharacter'));
    if ~isempty(keyChoiceValue)
        switch keyChoiceValue
            case {13,27}
                notDoneFlag = false;
        end
    end
end

% The roi position is given as Xpos, Ypos, width, height. [Xpos, Ypos] of
% [0, 0] is the upper left of the displayed image.
x = round(roi.Position);

% Calculate the canthal angle (plus any camera torsion) for a presumed
% right eye. A positive canthal angle corresponds to the medial canthus
% being lower than the lateral canthus.
canthalAngle = rad2deg(atan2(x(1,2)-x(2,2),x(1,1)-x(2,1)));

% Subtract the expected canthalAngle to obtain the residual camera torsion.
% The expected value can vary by ethnicity:
%
%   Rhee, Seung Chul, Kyoung-Sik Woo, and Bongsik Kwon. "Biometric study of
%   eyelid shape and dimensions of different races with references to
%   beauty." Aesthetic plastic surgery 36.5 (2012): 1236-1245.
%
% We round to the nearest whole degree, as the uncertainty in the
% estimation is at least this large.
cameraTorsionStruct.grayVideoName = grayVideoName;
cameraTorsionStruct.rightEyeAsian = round(-(9.77 - canthalAngle));
cameraTorsionStruct.rightEyeCaucasian = round(-(4.12 - canthalAngle));
cameraTorsionStruct.rightEyeBlack = round(-(5.39 - canthalAngle));
cameraTorsionStruct.leftEyeAsian = round(-(canthalAngle - 9.77));
cameraTorsionStruct.leftEyeCaucasian = round(-(canthalAngle - 4.12));
cameraTorsionStruct.leftEyeBlack = round(-(canthalAngle - 5.39));

% Clean up
close(figureHandle)

% Estimate the camera depth
sceneGeometry = createSceneGeometry();
d = sqrt(diff(x(:,1)).^2+diff(x(:,2)).^2);
myObj = @(depth) abs(d - canthalDistance(sceneGeometry, depth));
depth = fminsearch(myObj,120);
cameraTorsionStruct.depth = depth;


end % main function

function d = canthalDistance(sceneGeometry, depth)

sceneGeometry.cameraPosition.translation(3)= depth;

[~, ~, imagePoints, ~, ~, ~, pointLabels] = projectModelEye([0 0 0 1], sceneGeometry, 'fullEyeModelFlag', true);
canthalPoints = find(contains(pointLabels,'Canthus'));
d = sqrt( ...
    (imagePoints(canthalPoints(1),1) - imagePoints(canthalPoints(2),1)).^2 + ...
    (imagePoints(canthalPoints(1),2) - imagePoints(canthalPoints(2),2)).^2  ...
    );

end
