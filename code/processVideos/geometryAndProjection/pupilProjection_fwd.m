function reconstructedTransparentEllipse = pupilProjection_fwd(pupilAzi, pupilEle, pupilArea, pupilCenter3D, eyeRadius, eyeCenter, projectionModel)
% reconstructedTransparentEllipse = pupilProjection_fwd(pupilAzi, pupilEle, pupilCenter3D)
% 
% Returns the transparent ellipse params of the pupil projection on the
% scene, using the 3D pupil center coordinates and the horiziontal and
% vertical angles of tilt (in degrees) of the pupil center with reference
% to the scene plane.
%
% If the pupil area is available, the transparent param for the ellipse
% area will return the projected ellipse area, otherwise it will be left as
% NaN.
% 
% Note that the linear units must be uniform (eg. all pixels or all mm) for
% both the pupil center and the transparent ellipse parameters (where
% applicable).
% 
% Outputs:
%   reconstructedTransparentEllipse - ellipse in transparent form
% 
% Required inputs:
% pupilAzi - rotation of the pupil in the XY plane in degrees,
%       with the center being the centerOfProjection on the scene.
% pupilEle - elevation of the pupil from the XY plane in degrees,
%       with the center being the centerOfProjection on the scene.
% pupilArea - if not set to nan, the routine will return the ellipse area
% pupilCenter3D - center of the pupil in 3D, where X and Y are parallel to
%	the scene plane and Z is the distance of the center of the pupil from
%	the scene plane.
% projectionModel - string that identifies the projection model to use.
%   Options include "orthogonal" and "perspective"



%% main

% initiate reconstructedTransparentEllipse
reconstructedTransparentEllipse = nan(1,5);

% if we have a non-defined case, just return all nans
if any(isnan([pupilAzi pupilEle]))
return
end

% define ellipse center
switch projectionModel
    case 'orthogonal'
    % under orthogonal hypothesis the ellipse center in 2D is coincident with
    % the ellipse center in the plane of projection.
    reconstructedTransparentEllipse(1) = pupilCenter3D(1);
    reconstructedTransparentEllipse(2) = pupilCenter3D(2);
    case 'pseudoPerspectiveProjection'
        % for the weak perspective correction,we uniformly scale the
        % orthogonal projection according to the scene distance and the eye
        % radius.
        
        % get the perspective projection correction factor 
        relativeDepth = eyeRadius*(1-(cosd(pupilEle)*cosd(pupilAzi)));
        sceneDistance = abs(eyeCenter(3) - eyeRadius);
        perspectiveCorrectionFactor = (sceneDistance/(sceneDistance + relativeDepth));
        
        % apply perspective correction factor to the pupil center
        reconstructedTransparentEllipse(1) = pupilCenter3D(1) * perspectiveCorrectionFactor;
        reconstructedTransparentEllipse(2) = pupilCenter3D(2) * perspectiveCorrectionFactor;
end

% derive transparent parameters
% eccentricity
e = sqrt((sind(pupilEle))^2 - ((sind(pupilAzi))^2 * ((sind(pupilEle))^2 - 1)));
reconstructedTransparentEllipse(4) = e;

theta = nan;
% tilt
if pupilAzi > 0  &&  pupilEle > 0  
    theta = - asin(sind(pupilAzi)/e);
elseif pupilAzi > 0 && pupilEle < 0  
   theta =  asin(sind(pupilAzi)/e);
elseif pupilAzi < 0  &&  pupilEle > 0  
    theta = pi/2 + asin(sind(pupilAzi)/e);
elseif pupilAzi < 0 && pupilEle < 0  
   theta =  pi/2 - asin(sind(pupilAzi)/e);
elseif pupilAzi == 0 && pupilEle == 0
    theta = 0;
elseif pupilAzi ==  0 && pupilEle ~= 0
    theta = 0;
elseif pupilEle == 0 && pupilAzi ~= 0
    theta = pi/2;
else
    % Couldn't constrain the theta
%     warning('could not constrain theta. Dumping out azimuth, elevation, and eccentricity:')
%     pupilAzi
%     pupilEle
%     e
    theta = nan;
end
reconstructedTransparentEllipse(5) = theta;

% area (if pupilRadius available)
if ~isnan(pupilArea)
    switch projectionModel
        case 'orthogonal'
            % under orthogonal hypotesis, the semimajor axis of the ellipse equals the
            % pupil circle radius. If that is known, it can be assigned and used later
            % to determine the ellipse area.
            pupilRadius = sqrt(pupilArea/pi);
            semiMajorAxis = pupilRadius;
        case 'pseudoPerspectiveProjection'
            % apply scaling factor to pupil area
            pupilRadius = sqrt((pupilArea * perspectiveCorrectionFactor)/pi);
            semiMajorAxis = pupilRadius;
    end
    semiMinorAxis = semiMajorAxis*sqrt(1-e^2);
    reconstructedTransparentEllipse(3) = pi*semiMajorAxis*semiMinorAxis;
end

end % function

