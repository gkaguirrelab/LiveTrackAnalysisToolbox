function [outputRay, thetas, imageCoords, intersectionCoords] = rayTraceCenteredSphericalSurfaces(coordsInitial, thetaInitial, opticalSystemIn, figureFlag)
% Returns the position and angle of a resultant ray WRT optical axis
%
% Syntax:
%   [thetaOut, imagePositionCurrent] = rayTraceCenteredSphericalSurfaces(thetaInitial, nInitial, opticalSystem)

% Description:
%   This routine implements the 2D generalized ray tracing equations of:
%
%       Elagha, Hassan A. "Generalized formulas for ray-tracing and
%       longitudinal spherical aberration." JOSA A 34.3 (2017): 335-343.
%
%   The equations assume a set of spherical surfaces, with each spherical
%   surface having its center of curvature positioned on the optical axis.
%   The initial state of the ray is specified by its two-dimensional
%   coordinates and by the angle (theta) that it makes with the optical
%   axis. By convention, the optical axis is termed "z", and the orthogonal
%   axis is termed "height". Positive values of z are to the right. A theta
%   of zero indicates a ray that is parallel to the optical axis. Positive
%   values of theta correspond to the ray diverging to a position above the
%   optical axis. Each spherical surface is specified by a center of
%   curvature and a radius. The center of curvature must lie on the optical
%   axis; positive values place the center to the right of the origin of
%   the ray. A positive radius presents the ray with a convex surface; a
%   negative radius presents the ray with a concave surface. The output of
%   the routine is the position and angle at which the ray (or its reverse
%   projection) intersects the optical axis.
%
%   The routine is able to take symbolic variables for some or all of the
%   input components. When the input contains a symbolic variable:
%     - plotting is disabled
%     - intersectionCoords are not calculated and instead returned as empty
%     - checks for incidence angles above the critical angle or rays that
%       miss an optical surface are not conducted
%
% Inputs:
%   coordsInitial         - a 2x1 matrix, with the values corresponding to
%                           the z-position and height of the initial
%                           position of the ray.
%   thetaInitial          - A scalar in radians. A value of zero is aligned
%                           with the optical axis. Values between 0 and pi
%                           direct the ray to diverge "upwards" away from
%                           the axis.
%   opticalSystemIn       - An mx3 matrix, where m is the number of
%                           surfaces in the model, including the initial
%                           position of the ray. Each row contains the
%                           values [center, radius, refractiveIndex] that
%                           define a spherical lens. The first row
%                           corresponds to the initial conditions of the
%                           ray. Thus, the refractive index value given in
%                           the first row species the index of the medium
%                           in which the raw arises. The center and radius
%                           values for the first row are ignored.
%   figureFlag            - Logical or structure. If logical, the true or
%                           false value controls whether the default style
%                           plot is created. If empty, it will be set to
%                           false. More control of the plot can be obtained
%                           by passing a structure with individual elements
%                           set to true or false.
%
% Outputs:
%   outputRay             - a 2x2 matrix that contains a unit vector which
%                           describes the location and vector direction of
%                           a ray that is the virtual image for this system
%                           for the input. The first columns contains the z
%                           positions and the second column the h(eight)
%                           position. The first row contains the
%                           coordinates of a point on the optic axis and
%                           the second row contains a point on a ray
%                           arising from the first point that has unit
%                           length. This vector passes through the point in
%                           space and has the same theta as the ray which
%                           emerges from the final surface for the input
%                           ray.
%   thetas                - A scalar in radians
%   imageCoords           - An mx2 matrix which provides at each surface
%                           the point at which the resultant ray (or its
%                           virtual extension) intersects the optical axis.
%                           The second column of this matrix will contain
%                           only zeros.
%   intersectionCoords    - An mx2 matrix which procides at each surface
%                           the point at which the ray intersects the
%                           surface. This matrix is only defined when
%                           non-symbolic inputs are provided. This is
%                           because there are two possible points of
%                           intersection of a ray with the circular lens,
%                           and this routine cannot resolve this ambiguity
%                           analytically.
%
% Examples:
%   Examples 2-5 require the modelEyeParametersFunction from the
%   transparentTrack toolbox.
%
%   Ex.1 - Elagha 2017
%       The paper provides a numerical example in section C which is
%       implemented here as an example. Compare the returned theta values
%       with those given on page 340, section C.
%{
    clear coords
    clear theta
    coords = [0 0];
    theta = deg2rad(17.309724);
    figureFlag=true;
    opticalSystem=[nan nan 1; 22 10 1.2; 9 -8 1; 34 12 1.5; 20 -10 1.0];
    [outputRay, thetas, imageCoords] = rayTraceCenteredSphericalSurfaces(coords, theta, opticalSystem, figureFlag);
    for ii=1:length(thetas)
        fprintf('theta%d: %f \n',ii-1,rad2deg(thetas(ii)));
    end
    fprintf('Elegha gives a final image distance of 17.768432. we obtain:\n')
    fprintf('i5 - c5 = K4 = %f \n',imageCoords(end,1)-opticalSystem(5,1));
%}
%
%   Ex.2 - Pupil through cornea
%       A model of the passage of a point on the pupil perimeter through
%       the cornea (units in mm).
%{
    clear coords
    clear theta
    eye = modelEyeParameters();
    pupilRadius = 2;
    theta = deg2rad(-45);
    coords = [eye.pupilCenter(1) pupilRadius];
    opticalSystem = [nan nan eye.aqueousRefractiveIndex; ...
                     eye.corneaBackSurfaceCenter(1) -eye.corneaBackSurfaceRadius eye.corneaRefractiveIndex; ...
                     eye.corneaFrontSurfaceCenter(1) -eye.corneaFrontSurfaceRadius 1.0];
    figureFlag=true;
    outputRay = rayTraceCenteredSphericalSurfaces(coords, theta, opticalSystem, figureFlag)
%}
%
%   Ex.3 - Pupil through cornea, multiple points and rays
%{
    clear coords
    clear theta
    eye = modelEyeParameters();
    pupilRadius = 2;
    opticalSystem = [nan nan eye.aqueousRefractiveIndex; ...
                     eye.corneaBackSurfaceCenter(1) -eye.corneaBackSurfaceRadius eye.corneaRefractiveIndex; ...
                     eye.corneaFrontSurfaceCenter(1) -eye.corneaFrontSurfaceRadius 1.0];
    figure;
    clear figureFlag
    figureFlag.show = true;
    figureFlag.new = false;
    figureFlag.surfaces = true;
    figureFlag.imageLines = true;
    figureFlag.rayLines = true;
    figureFlag.textLabels = false;
    for theta = -35:70:35
        for pupilRadius = -2:4:2
            rayTraceCenteredSphericalSurfaces([eye.pupilCenter(1) pupilRadius], theta, opticalSystem, figureFlag);
        end
    end
%}
%
%   Ex.4 - Pupil through cornea, symbolic variables
%       Compare the final values for thetas of the rays through the system
%       to the values for thetas returned by Ex.2
%{
    clear coords
    clear theta
    eye = modelEyeParameters();
    syms theta
    syms pupilPointHeight
    coords = [eye.pupilCenter(1) pupilPointHeight];
    opticalSystem = [nan nan eye.aqueousRefractiveIndex; ...
                     eye.corneaBackSurfaceCenter(1) -eye.corneaBackSurfaceRadius eye.corneaRefractiveIndex; ...
                     eye.corneaFrontSurfaceCenter(1) -eye.corneaFrontSurfaceRadius 1.0];
    outputRay = rayTraceCenteredSphericalSurfaces(coords, theta, opticalSystem);
    symvar(outputRay)
    theta = deg2rad(-45);
    pupilPointHeight = 2;
    double(subs(outputRay))
%}
%
%   Ex.5 - Pupil through cornea, symbolic variables, create function
%       Demonstrates the creation of a function handle to allow rapid
%       evaluation of many values for the symbolic expression. The function
%       unitRayFromPupilFunc returns a unitRay for a given pupil height and 
%       theta. The function is then called for the pupil heights and thetas
%       that might reflect the position of a point on the pupil perimeter
%       in the x and y dimensions, creating a zxRay and a zyRay. The zyRay 
%       is then adjusted to share the same Z dimension point of origin.
%{
    clear coords
    clear theta
    eye = modelEyeParameters();
    syms theta
    syms pupilPointHeight
    coords = [eye.pupilCenter(1) pupilPointHeight];
    opticalSystem = [nan nan eye.aqueousRefractiveIndex; ...
                     eye.corneaBackSurfaceCenter(1) -eye.corneaBackSurfaceRadius eye.corneaRefractiveIndex; ...
                     eye.corneaFrontSurfaceCenter(1) -eye.corneaFrontSurfaceRadius 1.0];
    outputRay = rayTraceCenteredSphericalSurfaces(coords, theta, opticalSystem);
    symvar(outputRay)
    unitRayFromPupilFunc = matlabFunction(outputRay);
    zxRay=unitRayFromPupilFunc(2,pi/4)
    zyRay=unitRayFromPupilFunc(1.7,pi/8)
    slope =zyRay(2,2)/(zyRay(2,1)-zyRay(1,1));
    zOffset=zxRay(1,1)-zyRay(1,1);
    zyRay(:,1)=zyRay(:,1)+zOffset;
    zyRay(:,2)=zyRay(:,2)+(zOffset*slope)
%}


%% Check the input
% If a value was not passed for figureFlag, set to false.
if nargin==3
    figureFlag.show = false;
    figureFlag.new = false;
    figureFlag.surfaces = false;
    figureFlag.imageLines = false;
    figureFlag.rayLines = false;
    figureFlag.textLabels = false;
end

if nargin==4
    if islogical(figureFlag)
        if figureFlag
            clear figureFlag
            figureFlag.show = true;
            figureFlag.new = true;
            figureFlag.surfaces = true;
            figureFlag.imageLines = true;
            figureFlag.rayLines = true;
            figureFlag.textLabels = true;
        else
            clear figureFlag
            figureFlag.show = false;
            figureFlag.new = false;
            figureFlag.surfaces = false;
            figureFlag.imageLines = false;
            figureFlag.rayLines = false;
            figureFlag.textLabels = false;
        end
    end
end

% check if there are symbolic variables in the input
if ~isempty(symvar(coordsInitial)) || ~isempty(symvar(thetaInitial)) || ~isempty(symvar(opticalSystemIn(:)'))
    symbolicFlag = true;
    figureFlag.show = false;
else
    symbolicFlag = false;
end

%% Initialize variables and plotting
nSurfaces = size(opticalSystemIn,1);

% Set the values for at the first surface (initial position of ray)
if symbolicFlag
    syms unity
    aVals(1) = unity;
    intersectionCoords=[];
else
    aVals(1) = 1;
    intersectionCoords(1,:)=coordsInitial;
end
thetas(1)=thetaInitial;
relativeIndices(1) = 1;
imageCoords(1,:)=[coordsInitial(1)-(coordsInitial(2)/tan(thetaInitial)) 0];

% Build the local optical system. This is mostly copying over the passed
% opticalSystemIn, but we replace the center and radius of the first
% surface with the point of intersection of the initial ray with the
% optical axis, and set the radius to zero. This re-assembly of the matrix
% is also needed so that it can hold symbolic values if some were passed
% for coordsInitial or thetaInitial.
opticalSystem(1,1)=imageCoords(1,1);
opticalSystem(1,2)=0;
opticalSystem(1,3)=opticalSystemIn(1,3);
opticalSystem(2:nSurfaces,:)=opticalSystemIn(2:nSurfaces,:);

% Initialize the figure
if figureFlag.show
    if figureFlag.new
        figure
    end
    hold on
    refline(0,0)
    axis equal
end


%% Peform the ray trace
for ii = 2:nSurfaces
    % The distance between the center of curvature of the current lens
    % surface and the center of curvature of the prior lens surface
    d = opticalSystem(ii,1)-opticalSystem(ii-1,1);
    % The relative refractive index of the prior medium to the medium of
    % the surface that the ray is now impacting
    relativeIndices(ii)=opticalSystem(ii-1,3)/opticalSystem(ii,3);
    % implements equation 54 of Eleghan
    aVals(ii) = ...
        (1/opticalSystem(ii,2))*(relativeIndices(ii-1).*aVals(ii-1).*opticalSystem(ii-1,2)+d.*sin(thetas(ii-1)));
    % check if the incidence angle is above the critical angle for the
    % relative refractive index at the surface interface, but only if we
    % are not working with symbolic variables
    if ~symbolicFlag
        if abs((aVals(ii)*relativeIndices(ii))) > 1
            warning('Angle of incidence for surface %d greater than critical angle',ii);
            break
        end
    end
    % Find the angle of the ray after it enters the current surface
    thisTheta = thetas(ii-1) - asin(aVals(ii)) + asin(aVals(ii).*relativeIndices(ii));
    if symbolicFlag && ii==2
        clear thetas
        thetas(ii) = thisTheta;
        thetas(1) = thetaInitial;
    else
        thetas(ii) = thisTheta;
    end
    % Find the coordinates at which the ray, after making contact with the
    % current surface, would contact (or originate from) the optical axis
    thisImageCoord = [opticalSystem(ii,1) + ...
        1./(-(1/relativeIndices(ii)).*(1/(aVals(ii).*opticalSystem(ii,2))).*sin(thetas(ii))) 0];
    if symbolicFlag && ii==2
        clear imageCoords
        imageCoords(ii,:)=thisImageCoord;
        imageCoords(1,:)=coordsInitial;
    else
        imageCoords(ii,:)=thisImageCoord;
    end
    % If we are not working with symbolic variables, find the coordinate of
    % at which the ray intersects the current surface
    if ~symbolicFlag
        if ii==2
            slope = tan(thetas(ii-1));
        else
            slope = intersectionCoords(ii-1,2)/(intersectionCoords(ii-1,1)-imageCoords(ii-1,1));
        end
        intercept = (0-imageCoords(ii-1))*slope;
        [xout,yout] = linecirc(slope,intercept,opticalSystem(ii,1),0,abs(opticalSystem(ii,2)));
        % This next bit of logic figures out which of the two coordinates of
        % intersection of the ray with a sphere correspond to the one we want
        % for the lens
        if length(xout)==2
            whichIdx = 1.5+0.5*((sign(opticalSystem(ii,1))*sign(opticalSystem(ii,2))));
            intersectionCoords(ii,:)=[xout(whichIdx) yout(whichIdx)];
        else
            % If it returns only one coordinate the ray either was tangential
            % to the surface or missed entirely. We therefore exit the ray
            % tracing
            warning('The ray is either tangential to or misses surface %d \n',ii);
            break
        end
    end
    % Update the plot
    if figureFlag.show
        % add this lens surface
        if figureFlag.surfaces
            plotLensArc(opticalSystem(ii,:))
        end
        % plot the line for the virtual image
        if figureFlag.imageLines
            plot([imageCoords(ii-1,1) intersectionCoords(ii-1,1)],[imageCoords(ii-1,2) intersectionCoords(ii-1,2)],'--b');
        end
        % plot the line for the path of the ray
        if figureFlag.rayLines
            plot([intersectionCoords(ii-1,1) intersectionCoords(ii,1)],[intersectionCoords(ii-1,2) intersectionCoords(ii,2)],'-r');
        end
    end
end


%% Finish and clean up
% Assemble an output which is the unit vector for the final ray
slope = tan(thetas(ii)+pi);
norm = sqrt(slope^2+1);
outputRay = [imageCoords(ii,:); [imageCoords(ii,1)+(1/norm) imageCoords(ii,2)+(slope/norm)]];

% Complete the plot
if figureFlag.show
    % Plot the final virtual image
    if figureFlag.imageLines
        plot([imageCoords(ii,1) intersectionCoords(ii,1)],[imageCoords(ii,2) intersectionCoords(ii,2)],'-b');
    end
    % Plot the output unit ray vector
    if figureFlag.rayLines
        plot([outputRay(1,1) outputRay(2,1)],[outputRay(1,2) outputRay(2,2)],'-g');
    end
    % Replot the refline
    refline(0,0)
    % Add some labels
    if figureFlag.textLabels
        plot(opticalSystem(:,1),zeros(nSurfaces,1),'+k');
        text(opticalSystem(:,1),zeros(nSurfaces,1)-(diff(ylim)/50),strseq('c',[1:1:nSurfaces]),'HorizontalAlignment','center')
        plot(imageCoords(:,1),zeros(nSurfaces,1),'*r');
        text(imageCoords(:,1),zeros(nSurfaces,1)-(diff(ylim)/50),strseq('i',[1:1:nSurfaces]),'HorizontalAlignment','center')
    end
    hold off
end

end % function


%% LOCAL FUNCTIONS
function plotLensArc(opticalSystem)
%
ang=pi/2:0.01:3*pi/2;
xp=opticalSystem(2)*cos(ang);
yp=opticalSystem(2)*sin(ang);
plot(opticalSystem(1)+xp,yp,'-k');
end
