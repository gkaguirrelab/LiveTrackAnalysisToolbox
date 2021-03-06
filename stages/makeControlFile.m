function makeControlFile(controlFileName, perimeterFileName, glintFileName, varargin)
% Create a control file of instructions for refinement of pupil perimeters
%
% Syntax:
%  makeControlFile(controlFileName, perimeterFileName, glintFileName)
%
% Description:
%   Creates and saves a "control file", which is a text (csv) file that
%   instructs subsequent routines as to how a perimeter may be cleaned up
%   to remove blinks, eyelid intrusions, or force a particular set of
%   ellipse parameters.
%
%   The following processing steps are undertaken:
%     - Blink detection. Frames that lack a glint entirely, or in which the
%       glint is at a non-plausible location when compared to the average
%       glint location, are marked as blinks. Frames that are adjacent to
%       blinks may also be excluded.
%     - Glint patching. In case the glint is sitting right on the pupil
%       boundary, the pupil perimeter might be distorted. This step will
%       remove perimeter points close to the glint location.
% 	  - Pupil cutting. A more time-consuming step examines if removing a
%       portion of the perimeter of the pupil boundary produces an
%       improvement in an initial ellipse fit.
%
% Notes:
%   Parallel pool - Controlled by the key/value pair 'useParallel'. The
%   routine should gracefully fall-back on serial processing if the
%   parallel pool is unavailable. Each worker requires ~8 GB of memory to
%   operate. It is important to keep total RAM usage below the physical
%   memory limit to prevent swapping and a dramatic slow down in
%   processing. To use the parallel pool with TbTb, provide the identity of
%   the repo name in the 'tbtbRepoName', which is then used to configure
%   the workers.
%
% Inputs:
%	controlFileName       - Full path (including csv extension) to the
%                           control file
%   perimeterFileName     - Full path to the perimeter file
%   glintFileName         - Full path to the glint file
%
% Optional key/value pairs (display and I/O):
%  'verbose'              - Logical. Default false.
%
% Optional key/value pairs (flow control)
%  'nFrames'              - Analyze fewer than the total number of frames.
%  'useParallel'          - If set to true, use the Matlab parallel pool
%  'nWorkers'             - Specify the number of workers in the parallel
%                           pool. If undefined the default number will be
%                           used.
%  'tbtbProjectName'      - The workers in the parallel pool are configured
%                           by issuing a tbUseProject command for the
%                           project specified here.
%  'overwriteControlFile' - By default, the routine will not overwrite an
%                           existing control file. This behavior is
%                           motivated by the possibility that a human has
%                           edited the control file to improve analysis,
%                           and we do not want to overwrite this by
%                           accident.
%
% Optional key/value pairs (environment)
%  'tbSnapshot'           - This should contain the output of the
%                           tbDeploymentSnapshot performed upon the result
%                           of the tbUse command. This documents the state
%                           of the system at the time of analysis.
%  'timestamp'            - AUTOMATIC; The current time and date
%  'username'             - AUTOMATIC; The user
%  'hostname'             - AUTOMATIC; The host
%
% Optional key/value pairs (Blink detection)
%  'extendBlinkWindow'    - A two element vector that defines the number of
%                           additional frames flagged as a blink before and
%                           after a continuous block of blink frames
%
% Optional key/value pairs (Glint patching)
%  'glintZoneRadius'      - The radius (in pixel) of the circular zone in
%                           which the glint is allowed to be on the frame.
%                           Any candiate glint beyond this radius will be
%                           disregarded.
%  'glintZoneCenter'      - [X Y] location of the glint zone center. If not
%                           specified, the glint zone center will be the
%                           median value of the candidate glint locations
%                           throughout the run.
%  'glintPatchRadius'     - The radius of the glint patch
%
% Optional key/value pairs (Pupil cutting)
%  'ellipseTransparentLB/UB' - Define the hard upper and lower boundaries
%                           for the ellipse fit, in units of pixels of the
%                           video. The default values selected here
%                           represent the physical and mathematical limits,
%                           as the constraint for the fit will be provided
%                           by the scene geometry. A mild constraint (0.75)
%                           is placed upon the eccentricity, corresponding
%                           to an aspect ration of 3:2.
%  'cutErrorThreshold'    - If the ellipse fit RMSE is larger than this,
%                           perform a search over pupil cuts
%  'candidateThetas'      - A CxN matrix that provides N theta values to be
%                           evaluated for each of C cuts. A grid search of
%                           candidate cuts are examined, with the cut
%                           defined by a theta and a radius. This parameter
%                           provides a vector of theta values that are to
%                           be searched. Theta values range from 0 (image
%                           vertical down), to pi/2 (image horizontal
%                           right), to pi (image vertical up), to 3pi/2
%                           (image horizontal left). The default value is
%                           pi/2:pi/16:pi, corresponding to a search of 9
%                           angles ranging from horizontal right to
%                           vertical up. We restrict the search to these
%                           theta angles as we typically observe intrusion
%                           on to the pupil boundary either by the upper
%                           eyelid or by a non-uniform "shadow" of IR
%                           illumination arising from the horizontal right
%                           side of the image. If more than one row of
%                           theta values are offered, then multiple cuts
%                           will be attempted. The candidate theta values
%                           for each cut can be overlapping or separated.
%  'radiusDivisions'      - Controls how many divisions between the
%                           geometric center of the pupil perimeter and the
%                           outer edge are to be examined with a pupil cut.
%                           A larger number results in a longer search of
%                           finer sizes of cuts.
%  'minRadiusProportion'  - This defines the stopping point for the amount
%                           of the pupil that can be cut. When set to zero
%                           (the default) the largest cut that will be
%                           considered is one that passes through the
%                           center of the pupil perimeter. A positive value
%                           (e.g., 0.5) limits the maximum cut to that
%                           proportion of the radius. A negative proportion
%                           would allow a cut to remove more than half of
%                           the total pupil radius.
%
% Outputs:
%   The routine does not return any variables, but does output a file.
%
%   Format of controlFile - Each line of the control file contains an
%       "instruction" of the form:
%       FRAME NUMBER, INSTRUCTION TYPE, INSTRUCTION PARAMS (variable #)
%
%	where:
%       FRAME NUMBER: frame on which to apply the instruction
%       INSTRUCTION TYPE: what to do on the frame
%       INSTRUCTION PARAMS: variable number of params necessary to execute
%           the instruction.
%
%   This routine generates instructions of the type "blink", "cut", "glint
%   patch", and "error". Additional legal instructions are "ellipse", with
%   the parameters of a forced ellipse, and "%", which marks a non-executed
%   comment
%


%% Parse input and define variables
p = inputParser; p.KeepUnmatched = true; p.PartialMatching = false;

% required input
p.addRequired('controlFileName',@isstr);
p.addRequired('perimeterFileName',@isstr);
p.addRequired('glintFileName',@isstr);

% Optional display and I/O params
p.addParameter('verbose',false,@islogical);
p.addParameter('displayMode',false,@islogical);

% Optional flow control params
p.addParameter('nFrames',Inf,@isnumeric);
p.addParameter('startFrame',1,@isnumeric);
p.addParameter('useParallel',false,@islogical);
p.addParameter('nWorkers',[],@(x)(isempty(x) | isnumeric(x)));
p.addParameter('tbtbRepoName','transparentTrack',@ischar);
p.addParameter('overwriteControlFile',false,@islogical);

% Optional environment parameters
p.addParameter('tbSnapshot',[],@(x)(isempty(x) | isstruct(x)));
p.addParameter('timestamp',char(datetime('now')),@ischar);
p.addParameter('username',char(java.lang.System.getProperty('user.name')),@ischar);
p.addParameter('hostname',char(java.net.InetAddress.getLocalHost.getHostName),@ischar);

% Optional analysis params -- Blink detection
p.addParameter('extendBlinkWindow', [5,10], @isnumeric);

% Optional analysis params -- Glint patching
p.addParameter('glintZoneRadius', 80, @isnumeric);
p.addParameter('glintZoneCenter', [], @isnumeric);
p.addParameter('glintPatchRadius', 20, @isnumeric);

% Optional analysis params -- Pupil Cutting
p.addParameter('ellipseTransparentLB',[0, 0, 800, 0, 0],@(x)(isempty(x) | isnumeric(x)));
p.addParameter('ellipseTransparentUB',[640,480,20000,1, pi],@(x)(isempty(x) | isnumeric(x)));
p.addParameter('cutErrorThreshold', 1, @isnumeric);
p.addParameter('candidateThetas',pi/2:pi/16:pi,@(x)(iscell(x) | isnumeric(x)));
p.addParameter('radiusDivisions',5,@isnumeric);
p.addParameter('minRadiusProportion',0,@isnumeric);

% parse
p.parse(controlFileName, perimeterFileName, glintFileName, varargin{:})


%% Check that this control file does not exist
if ~p.Results.displayMode
    % We decline to over-write an existing control file, as it may contain
    % instructions lovingly crafted by a human
    if exist(controlFileName, 'file') == 2 && ~(p.Results.overwriteControlFile)
        warning('makeControlFile:overwrittingControlFile',['The control file ' controlFileName ' exists already and cannot be over-written. Exiting.']);
        return
    end
    
    % If we decided to overwrite an existing control file, we remove the
    % previous one to start fresh and avoid that new instructions are appended
    % after old ones.
    if exist(controlFileName, 'file') == 2 && (p.Results.overwriteControlFile)
        warning(['Deleting old version of ' controlFileName ]);
        delete (controlFileName)
    end
end


%% Set up the parallel pool
if p.Results.useParallel
    nWorkers = startParpool( p.Results.nWorkers, p.Results.verbose );
else
    nWorkers=0;
end


%% Load the pupil perimeter data.
% It will be a structure variable "perimeter", with the fields .data and .meta
dataLoad=load(perimeterFileName);
perimeter=dataLoad.perimeter;
clear dataLoad
if p.Results.nFrames == Inf
    nFrames=size(perimeter.data,1);
else
    nFrames = p.Results.nFrames;
end


%% Perform blink detection
dataLoad = load(glintFileName);
glintData = dataLoad.glintData;
if size (glintData.X,2) == 2
    glintsMainDirection = dataLoad.glintData.meta.glintsMainDirection;
end
clear dataLoad

% locate all nans
blinkFrames = find(isnan(glintData.X(:,1)));

switch size (glintData.X,2)
    case 1
        % locate candidate glints outside the user defined glint zone
        % define center of glint zone
        if isempty(p.Results.glintZoneCenter)
            glintZoneCenter = [nanmedian(glintData.X) nanmedian(glintData.Y)];
        else
            glintZoneCenter = p.Results.glintZoneCenter;
        end
        
        % get distance of each glint from the glintZone center
        glintDistance = sqrt((glintData.X - glintZoneCenter(1)).^2 +(glintData.Y - glintZoneCenter(2)).^2);
        
        tooFarGlints = find(glintDistance>p.Results.glintZoneRadius);
        
        blinkFrames = sort([blinkFrames; tooFarGlints]);
    case 2
        % find glintZone center
        if isempty(p.Results.glintZoneCenter)
            glintZoneCenter = [median(nanmedian(glintData.X)) median(nanmedian(glintData.Y))];
        else
            glintZoneCenter = p.Results.glintZoneCenter;
        end
        
        % find mean location of each glint vector
        meanGlintVector = [mean(glintData.X,2) mean(glintData.Y,2)];
        
        % get distance of each glint from the glintZone center
        glintDistance = sqrt((meanGlintVector(:,1) - glintZoneCenter(1)).^2 +(meanGlintVector(:,2) - glintZoneCenter(2)).^2);
        
        tooFarGlints = find(glintDistance>p.Results.glintZoneRadius);
        
        blinkFrames = sort([blinkFrames; tooFarGlints]);
end


% extend the frames identified as blinks to before and after blocks of
% blink frames
if ~isempty(blinkFrames)
    tmp=diff(blinkFrames);
    blinkBoundaryIdx=find(tmp~=1);
    if ~isempty(blinkBoundaryIdx) && p.Results.extendBlinkWindow(1)>0
        padBlinksBefore=[];
        for pp=1:p.Results.extendBlinkWindow(1)
            candidateBlinkFrames=blinkFrames(blinkBoundaryIdx+1)-pp;
            inBoundFrames=logical((candidateBlinkFrames>=1) .* (candidateBlinkFrames<=nFrames));
            if ~isempty(inBoundFrames)
                padBlinksBefore=[padBlinksBefore;candidateBlinkFrames(inBoundFrames)];
            end
        end
        blinkFrames=unique(sort([blinkFrames;padBlinksBefore]));
    end
    if ~isempty(blinkBoundaryIdx) && p.Results.extendBlinkWindow(2)>0
        padBlinksAfter=[];
        for pp=1:p.Results.extendBlinkWindow(2)
            candidateBlinkFrames=blinkFrames(blinkBoundaryIdx)+pp;
            inBoundFrames=logical((candidateBlinkFrames>=1) .* (candidateBlinkFrames<=nFrames));
            if ~isempty(inBoundFrames)
                padBlinksAfter=[padBlinksAfter;candidateBlinkFrames(inBoundFrames)];
            end
        end
        blinkFrames=unique(sort([blinkFrames;padBlinksAfter]));
    end
end


%% Apply glint patch and guess pupil cuts

% Intialize some variables
glintPatchX = nan(nFrames,1);
glintPatchY = nan(nFrames,1);
glintPatchRadius = nan(nFrames,1);
nCuts = size(p.Results.candidateThetas,1);
frameRadii=nan(nFrames,nCuts);
frameThetas=nan(nFrames,nCuts);
frameErrors=nan(nFrames,1);

% alert the user
if p.Results.verbose
    tic
    fprintf(['Guessing pupil cuts. Started ' char(datetime('now')) '\n']);
    fprintf('| 0                      50                   100%% |\n');
    fprintf('.\n');
end

% get glintData ready for the parfor. This includes transposing the
% variables
switch size (glintData.X,2)
    case 1
        glintData_X = glintData.X';
        glintData_Y = glintData.Y';
    case 2
        glintData_X = meanGlintVector(:,1)';
        glintData_Y = meanGlintVector(:,2)';
end

% Recast perimeter.data into a sliced cell array to reduce par for
% broadcast overhead
startFrame = p.Results.startFrame;
frameCellArray = perimeter.data(startFrame:startFrame+nFrames-1);
frameSize = perimeter.size;
clear perimeter

% Loop through the video frames
parfor (ii = startFrame:startFrame+nFrames-1, nWorkers)
%for ii = startFrame:startFrame+nFrames-1

    % Update progress
    if p.Results.verbose && mod(ii,round(nFrames/50))==0
        fprintf('\b.\n');
    end
    
    % get the data frame
    thisFrame = uint8(zeros(frameSize));
    thisFrame(sub2ind(frameSize,frameCellArray{ii-startFrame+1}.Yp,frameCellArray{ii-startFrame+1}.Xp))=255;
    
    % make glint patch
    if ~isnan(glintData_X(ii))
        glintPatch = ones(size(thisFrame));
        glintPatch = insertShape(glintPatch,'FilledCircle',[glintData_X(ii) glintData_Y(ii) p.Results.glintPatchRadius],'Color','black');
        glintPatch = im2bw(glintPatch);
        
        % apply glint patch
        thisFramePatched = immultiply(thisFrame,glintPatch);
        
        % check if glint patch had an effect. If so, save out glintPatch
        % instruction for this frame
        if ~isempty(find(thisFrame - thisFramePatched))
            glintPatchX(ii) = glintData_X(ii);
            glintPatchY(ii) = glintData_Y(ii);
            glintPatchRadius(ii) = p.Results.glintPatchRadius;
            
            % also, use the patched frame to search for the cut
            thisFrame = thisFramePatched;
        end
    end
    
    % index perimeter points
    [Yp, Xp] = ind2sub(size(thisFrame),find(thisFrame));
    
    % define these so that the parfor loop is not concerned that the values
    % will not carry from one loop to the next
    smallestFittingError = NaN;
    theseRadii = nan(1,nCuts);
    theseThetas = nan(1,nCuts);
    
    % proceed if the frame is not empty
    if ~isempty(Xp)
        
        % The try - catch allows processing to proceed if an attempt to
        % fit the ellipse fails
        try
            % fit an ellipse to the full perimeter
            [~, originalFittingError] = constrainedEllipseFit(Xp, Yp, ...
                p.Results.ellipseTransparentLB, ...
                p.Results.ellipseTransparentUB, ...
                []);
            
            % if the fitting error is above the threshold, search over cuts
            if originalFittingError > p.Results.cutErrorThreshold
                smallestFittingError = originalFittingError;
                stillSearching = true;
            else
                stillSearching = false;
            end
            
            % Determine some properties of the search over cut radii
            maxRadius=round(max([max(Xp)-min(Xp),max(Yp)-min(Yp)])/2);
            stepReducer = max([1,floor(maxRadius/p.Results.radiusDivisions)]);
            minRadius = maxRadius * p.Results.minRadiusProportion;
            
            % Keep count of the number of cuts we have tried
            cutIdx = 1;
            
            % Make a copy of the frame that we will cut as we go
            cutFrame = thisFrame;
            
            % Keep searching over the number of allowed cuts until we have
            % a fit of acceptable quality, or we run out of cuts
            while stillSearching && cutIdx <= nCuts
                
                % Get the candidateThetas for this cut
                if iscell(p.Results.candidateThetas)
                    thisCutThetas = p.Results.candidateThetas{cutIdx};
                else
                    thisCutThetas = p.Results.candidateThetas(cutIdx,:);
                end
                
                % We start with a cut radius that is one division below the
                % maximum radius in the pupil boundary
                candidateRadius = maxRadius - stepReducer;
                
                % Keep searching until we have a fit of accetable quality, or
                % if the candidate radius drops below the minimum radius
                while stillSearching && candidateRadius > minRadius
                    
                    [gridSearchRadii,gridSearchThetas] = ndgrid(candidateRadius,thisCutThetas);
                    myCutOptim = @(params) calcErrorForACut(cutFrame, params(1), params(2), p.Results.ellipseTransparentLB, p.Results.ellipseTransparentUB);
                    gridSearchResults=arrayfun(@(k1,k2) myCutOptim([k1,k2]),gridSearchRadii,gridSearchThetas);
                    
                    % Store the best cut from this search
                    bestFitOnThisSearch=min(min(min(gridSearchResults)));
                    
                    % Update the best search
                    if bestFitOnThisSearch < smallestFittingError
                        smallestFittingError=bestFitOnThisSearch;
                        [~,col] = find(gridSearchResults==bestFitOnThisSearch);
                        theseRadii(cutIdx)=candidateRadius;
                        theseThetas(cutIdx)=thisCutThetas(col(1));
                    end
                    
                    % Are we done searching over radii? If not, shrink the
                    % candidate radius
                    if bestFitOnThisSearch < p.Results.cutErrorThreshold
                        stillSearching = false;
                    else
                        candidateRadius=candidateRadius - stepReducer;
                    end
                    
                end % search over radii
                
                % Update the cutFrame with the result of this cut
                if ~isnan(theseRadii(cutIdx))
                    cutFrame = applyPupilCut (cutFrame, theseRadii(cutIdx), theseThetas(cutIdx));
                end
                
                % Iterate the cut index
                cutIdx = cutIdx+1;
                
            end % search over cuts
            
            frameRadii(ii,:)=theseRadii;
            frameThetas(ii,:)=theseThetas;
            
        catch
            % If there is a fitting error, tag this frame error and
            % continue with the parfor loop
            frameErrors(ii)=1;

            
            continue
        end % try-catch
        
    end % not an empty frame
    
end % parloop over frames


% report completion of preliminary control file generation
if p.Results.verbose
    toc
    fprintf('\n');
end


%% Write out control file instructions
if ~p.Results.displayMode
    
    fid = fopen(controlFileName,'a');
    
    % Blinks
    if ~isempty(blinkFrames)
        for bb = 1 : length(blinkFrames)
            instruction = [num2str(blinkFrames(bb)) ',' 'blink'];
            fprintf(fid,'%s\n',instruction);
            clear instruction
        end
    end
    
    % Glint patches
    glintPatchFrames=find(~isnan(glintPatchX));
    if ~isempty(glintPatchFrames)
        for kk = 1 : length(glintPatchFrames)
            frameIdx=glintPatchFrames(kk);
            instruction = [num2str(frameIdx) ',' 'glintPatch' ',' num2str(glintPatchX(frameIdx)) ',' num2str(glintPatchY(frameIdx)) ',' num2str(glintPatchRadius(frameIdx))];
            fprintf(fid,'%s\n',instruction);
            clear instruction
        end
    end
    
    % Cuts
    cutFrames=find(any(~isnan(frameThetas),2));
    if ~isempty(cutFrames)
        for kk = 1 : length(cutFrames)
            frameIdx=cutFrames(kk);
            for jj = 1 : nCuts
                if ~isnan(frameRadii(frameIdx,jj))
                    instruction = [num2str(frameIdx) ',' 'cut' ',' num2str(frameRadii(frameIdx,jj)) ',' num2str(frameThetas(frameIdx,jj))];
                    fprintf(fid,'%s\n',instruction);
                end
            end
            clear instruction
        end
    end
    
    % Fit errors
    errorFrameIdx=find(~isnan(frameErrors));
    if ~isempty(errorFrameIdx)
        for kk = 1 : length(errorFrameIdx)
            frameIdx=errorFrameIdx(kk);
            instruction = [num2str(frameIdx) ',' 'error' ];
            fprintf(fid,'%s\n',instruction);
            clear instruction
        end
    end
    
    % Extract field data
    fields = repmat(fieldnames(p.Results), numel(p.Results), 1);
    values = struct2cell(p.Results);
    
    % Convert all numerical values to strings
    numericIdx = cellfun(@isnumeric, values);
    values(numericIdx) = cellfun(@mat2str, values(numericIdx), 'UniformOutput', 0);
    
    % Convert all logical values to strings
    logicalText = {'false','true'};
    logicalIdx = cellfun(@islogical, values);
    values(logicalIdx) = cellfun(@(x) logicalText{double(x)+1}, values(logicalIdx), 'UniformOutput', 0);
    
    % Replace any remaining cells or structures with an explanation
    cellIdx = cellfun(@iscell, values);
    values(cellIdx) = cellfun(@(x) '== cell value not reported here ==', values(cellIdx), 'UniformOutput', 0);
    
    structIdx = cellfun(@isstruct, values);
    values(structIdx) = cellfun(@(x) '== struct value not reported here ==', values(structIdx), 'UniformOutput', 0);
    
    % Combine field names and values in the same array
    paramsCellArray = {fields{:}; values{:}};
    
    % Mark off this section
    instruction = ['%' ',' '%' ',' '**** start analysis parameters ****'];
    fprintf(fid,'%s\n',instruction);
    clear instruction
    
    % Loop through the columns and save each as a row in the filed
    for kk = 1:size(paramsCellArray,2)
        instruction = ['%' ',' '%' ',' paramsCellArray{1,kk} ',' paramsCellArray{2,kk}];
        fprintf(fid,'%s\n',instruction);
        clear instruction
    end
    instruction = ['%' ',' '%' ',' '**** end analysis parameters ****'];
    fprintf(fid,'%s\n',instruction);
    clear instruction
    
    % finish and close the file
    instruction = ['%' ',' '%' ',' 'end of automatic instructions'];
    fprintf(fid,'%s\n',instruction);
    fclose(fid);
end

end % function


%% LOCAL FUNCTIONS

function [distanceError] = calcErrorForACut(theFrame, radiusThresh, theta, lb, ub)
[binPcut] = applyPupilCut (theFrame, radiusThresh, theta);
[Yp, Xp] = ind2sub(size(binPcut),find(binPcut));
[~, distanceError] = constrainedEllipseFit(Xp, Yp, lb, ub, []);
end
