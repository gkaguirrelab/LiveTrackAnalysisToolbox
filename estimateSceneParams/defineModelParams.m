function model = defineModelParams(nScenes, modelIn, cameraTorsion, cameraDepth, corneaTorsion)
% Specification of parameters and functions for estimateSceneGeometry
%
% Syntax:
%  model = defineModelParams(nScenes, modelIn, cameraDepth, penaltyWeight)
%
% Description:
%   This function collects in one place the definition of the parameters of
%   the search that is executed within estimateSceneGeometry. The output of
%   the function is the structure 'model'. This structure contains fields
%   that define the search for:
%
%      'head'     - The effect of head motion upon relative camera position
%      'eye'      - Biometric properties of the model eye
%      'scene'    - Position of the camera in the scene, and the primary
%                   position of the eye, which is defined relative to
%                   camera position
%
%   Each of these parameter specifications also includes an entry for a
%   function handle `idxMap`. This function takes an index in the list of
%   parameters for a particular field (i.e., eye or head) and returns the
%   position of that parameter in the concatenated set of parameters:
%       [head eye scene]
%
%   The function handle 'idxMultiScene' further maps an index value from
%   the concated set [head eye scene] to the concatenated parameter set
%   across all scenes that comprise the search:
%       [head eye scene1 scene2 ... sceneN]
%
%   Additional fields provide the overall bounds and x0 for the search, as
%   well as a field that contains functions used to constrain and guide the
%   search.
%
%   The 'strategy' field specifies values for the following search
%   parameters:
%
%  'errorArgs' -
%       These key-values are passed to the updateError method of the
%       sceneObj.
%  'penaltyWeight' -
%       Vector. Adjustment of camera depth and torsion away from the x0 
%       values is penalized. The effect of the weight (w(1)) is such that
%       an x% change in camera depth produces a [(w(1)*x)^2]% increase in
%       the objective. The w(2) value produces a w(2)*deltaT increase in
%       the objective, where deltaT is the change in camera torsion in
%       degrees. A weight value of zero removes the regularization.
%  'useFixForPrimaryPos' -
%       Logical. The primary position of the eye is specified as part of
%       the eye model, and controls the pseudo-torsion of the eye following
%       Listing's Law. Because eye rotations are defined with respect to
%       the alignment of the optical axis of the camera with the optical
%       axis of the eye, the primary position of the eye in the scene
%       coordinate frame will vary with camera position. The routine is
%       able to search across primary position values for each scene. This
%       flag causes the model to be updated after each stage such that the
%       primary position for the eye in a given scene is set equal to the
%       modeled position of the eye when it is fixating position [0 0] of a
%       fixation array. The use of this flag is justified when the subject
%       is allowed to adjust their head to most comfortably view the center
%       of a fixation array prior to recording, presumably placing the
%       center of fixation at their primary position.
%  'multiSceneNorm' -
%       Scalar. Defines the metric used to combine errors across scenes.
%       Defaults to a value of 1 and thus the L1 norm.
%  'TolMesh' - 
%       Scalar. The precision with which the parameters are adjusted within
%       the BADS search. A value of 1e-2 provides a good trade-off between
%       search time and useful precision in the eye and scene parameters.
%
% Inputs:
%   nScenes               - Scalar. The number of scenes that are to be 
%                           modeled.
%   modelIn               - Structure. A passed structure whose fields are 
%                           used to overwrite the defaults.
%   cameraTorsion         - Scalar. Rotation of the camera with respect to
%                           the azimuthal plane of rotation of the eye, in
%                           degrees. Used to set the scene x0.
%   cameraDepth           - Scalar. The distance of the camera from the 
%                           corneal apex of the eye in mm. Used to set the
%                           scene x0.
%   corneaTorsion         - Scalar. The angle of astigmatism for the cornea
%                           that is used to set the x0 value, perhaps
%                           obtained from keratometry measurement for the
%                           eye to be modeled. This is particularly useful
%                           for angles close to 90 degrees, for which the
%                           model has trouble reaching by search on its
%                           own.
%
% Outputs:
%   model                 - Structure. Specifies the properties for the
%                           search.
%


%% Check that cameraTorsion and cameraDepth params are compatible
if length(cameraTorsion) ~= length(cameraDepth)
    error('The cameraDepth and cameraTorsion variables must be the same size')
end
if length(cameraTorsion) > 1
    if length(cameraDepth) ~= nScenes
    error('cameraDepth and cameraTorsion must either be scalars, or the same length as the number of scenes')
    end
end


%% Head
% These parameters adjust the effect of head motion over time upon relative
% camera position. When properly constructed, the head motion vectors start
% off by being roughly in terms of the relative position of the camera with
% respect to the eye of the subject. These search parameters find
% adjustments to the rotation of the coordinate frame of the measurement of
% head motion to the coordinate frame of the camera. The first parameter
% also adjusts the temporal offset (in units of measurement frames) between
% the head motion vectors and the eye recording measurements.
model.head.x0 = [0, 0, 0, 0];
model.head.bounds = [30, 30, 30, 30];
model.head.paramLabels = {'timeShift','azi','ele','torsion'};
model.head.units = {'frames','deg','deg','deg'};
model.head.nParams = length(model.head.paramLabels);
model.head.setLabels = {'phaseAndRotation','all'};
model.head.setIdx = {1:4,1:4};
model.head.idxMap = @(idx) idx;
model.head.idxMultiScene = @(idx) idx;


%% Eye
% These parameters adjust biometric properties of the model eye. The
% default parameters correspond to a cornea with the default kvals, and
% default rotation centers of the eye. The bounds on the first two k-vals
% reflect 2 SDs around the values obtained in the TOME population. The
% commonDepth parameter allows for adjustment of camera depth of all scenes
% in common. It is placed in the eye parameter set for convenience.
model.eye.x0 = [14.104, 44.2410, 45.6302, corneaTorsion, 2.5000, 0, 1, 1, 0];
model.eye.bounds = [5, 5, 5, 180, 5, 2.5, 0.25, 0.25, 30];
model.eye.paramLabels = {'corneaAxialRadius','K1','K2','torsion','tilt','tip','joint','diff','commonDepth'};
model.eye.units = {'mm','diopters','diopters','deg','deg','deg','proportion','proportion','mm'};
model.eye.nParams = length(model.eye.paramLabels);
model.eye.setLabels = {'corneaAxialRadius','k1k2','kvals','rotationCenterScalers','commonDepth','all'};
model.eye.setIdx = {1, 2:3, 2:6, 7:8, 9, 1:9};
model.eye.idxMap = @(idx) model.head.nParams+idx;
model.eye.idxMultiScene = @(idx) idx;


%% Scene
% These parameters adjust the position of the camera within a scene, which
% also adjusts the primary position of the eye. The cameraDepth parameter
% is the most important to get right, and is specified by a passed
% variable.
model.scene.x0 = @(cameraTorsion, cameraDepth) [0 0 cameraTorsion 0 0 cameraDepth];
model.scene.bounds = [10 10 10 20 20 20];
model.scene.paramLabels = {'pp_azi','pp_ele','torsion','horiz','vert','depth'};
model.scene.units = {'deg','deg','deg','mm','mm','mm'};
model.scene.nParams = length(model.scene.paramLabels);
model.scene.nScenes = nScenes;
model.scene.setLabels = {'primaryPosition','cameraPosition', 'translation', 'moveInPlane', 'depth','all'};
model.scene.setIdx = {1:2, 3:6, 4:6, 3:5, 6, 1:6};
model.scene.idxMap =  @(idx) model.head.nParams+model.eye.nParams+idx;
% An anonymous function that expands the input index vector [a, b, ...]
% into a vector given k eye+head, s sceneParams, and n scenes:
%	[ e+a+(s*0), e+b+(s*0), e+a+(s*1), e+b+(s*1), ... e+a+(s*(n-1)), e+b+(s*(n-1)) ]
% This is used to map a given choice of scene parameters to a multi-scene
% search.
model.scene.idxMultiScene = @(idx) repmat((0:model.scene.nScenes-1)*model.scene.nParams,1,length(idx)) + ...
    cell2mat(arrayfun(@(x) repmat(x,1,model.scene.nScenes),idx,'UniformOutput',false));


%% Strategy
% Arrange the sets into search stages for different search strategy

% gazeCal -- Used to derive multiple biometric and scene parameters from
% one or more gazeCal acquisitions.
model.strategy.gazeCal.stages = { ...
    {'eye.rotationCenterScalers','eye.corneaAxialRadius','eye.commonDepth','scene.cameraPosition'},...
    {'eye.corneaAxialRadius','eye.kvals','eye.commonDepth','scene.cameraPosition'},...
    {'scene.primaryPosition','scene.cameraPosition'} };
model.strategy.gazeCal.errorArgs = { ...
    {'cameraTransBounds',[0;0;0],'errorReg',[1 1 10 0 0]}
    {'cameraTransBounds',[0;0;0],'errorReg',[1 1 10 0 0]}
    {'cameraTransBounds',[5;5;0],'errorReg',[1 1 10 0 1]} };
model.strategy.gazeCal.penaltyWeight = [1 1]; % [depth torsion]
model.strategy.gazeCal.useFixForPrimaryPos = false;
model.strategy.gazeCal.multiSceneNorm = 1;
model.strategy.gazeCal.TolMesh = 1e-2;


% sceneSync -- Used to map a known set of eye biometric parameters and a
% pretty good initial set of scene parameters to an acquisition that has an
% associated measurement of head movement over time. The penalty weights
% discourage large changes in camera depth or torsion.
model.strategy.sceneSync.stages = { ...
    {'scene.cameraPosition', 'head.phaseAndRotation' } };
model.strategy.sceneSync.errorArgs = { ...
    {'cameraTransBounds',[5;5;0],'errorReg',[1 1 0 0 1]} };
model.strategy.sceneSync.penaltyWeight = [100 1]; % [depth torsion]
model.strategy.sceneSync.useFixForPrimaryPos = false;
model.strategy.sceneSync.multiSceneNorm = 1;
model.strategy.sceneSync.TolMesh = 1e-2;


% default -- Do not perform a search, and just save out the default
% sceneGeometry implied by the x0 settings
model.strategy.default.stages = { {} };
model.strategy.default.errorArgs = { ...
    {'cameraTransBounds',[5;5;0],'errorReg',[1 1 0 0 1]} };
model.strategy.default.penaltyWeight = [100 1]; % [depth torsion]
model.strategy.default.useFixForPrimaryPos = false;
model.strategy.default.multiSceneNorm = 1;
model.strategy.default.TolMesh = 1e-2;


% synthFix -- Similar to gazeCal, but the source frames were acquired
% during a lengthy fMRI scan. Therefore, we want to handle head translation
% during this time.
model.strategy.synthFix.stages = { ...
    {'eye.rotationCenterScalers','eye.corneaAxialRadius','eye.commonDepth','scene.cameraPosition'},...
    {'eye.corneaAxialRadius','eye.kvals','eye.commonDepth','scene.cameraPosition'},...
    {'scene.primaryPosition','scene.cameraPosition','head.phaseAndRotation'} };
model.strategy.synthFix.errorArgs = { ...
    {'cameraTransBounds',[0;0;0],'errorReg',[1 1 10 0 0]}
    {'cameraTransBounds',[0;0;0],'errorReg',[1 1 10 0 0]}
    {'cameraTransBounds',[5;5;0],'errorReg',[1 1 10 0 1]} };
model.strategy.synthFix.penaltyWeight = [1 1]; % [depth torsion]
model.strategy.synthFix.useFixForPrimaryPos = false;
model.strategy.synthFix.multiSceneNorm = 1;
model.strategy.synthFix.TolMesh = 1e-2;


% validateEye -- Used in the assessment of the cross-validated accuracy of
% the gaze calibration procedure for the Aguirre 2020 Moving Eye paper
model.strategy.validate.stages = { ...
    {'scene.moveInPlane'},...
     };
model.strategy.validate.errorArgs = { ...
    {'cameraTransBounds',[5;5;0],'errorReg',[1 1 0 0 1]} };
model.strategy.validate.penaltyWeight = [100 0]; % [depth torsion]
model.strategy.validate.useFixForPrimaryPos = false;
model.strategy.validate.multiSceneNorm = 1;
model.strategy.validate.TolMesh = 1e-2;


% simulateBio -- Used in a test of the accuracy of recovered biometry for
% the Aguirre 2020 Moving Eye paper
model.strategy.simulateBio.stages = { ...
    {'scene.moveInPlane','eye.k1k2','eye.rotationCenterScalers'},...
     };
model.strategy.simulateBio.errorArgs = { ...
    {'cameraTransBounds',[0;0;0],'errorReg',[1 1 10 0 0]} };
model.strategy.simulateBio.penaltyWeight = [1 1]; % [depth torsion]
model.strategy.simulateBio.useFixForPrimaryPos = false;
model.strategy.simulateBio.multiSceneNorm = 1;
model.strategy.simulateBio.TolMesh = 1e-2;



%% Substitute passed model inputs for defaults
% The passed modelIn structure can over-write all model parameters defined
% up to this point. Function definitions can not be replaced by this
% approach.
if ~isempty(modelIn)
    model = mergestruct(model, modelIn);
end


%% Assemble full x0 and bounds

% The head and eye parameters are shared by all scenes, and each scene gets
% its own set of scene parameters, yielding this many total parameters in
% the optimization.
model.nParams = model.head.nParams + model.eye.nParams + model.scene.nParams * model.scene.nScenes;

% Assemble the concatenated x0 parameters. This behavior differs depending
% upon the form of the field model.scene.x0

% If model.scene.x0 is a cell array, then we have been given a different
% set of x0 parameters for each scene.
if iscell(model.scene.x0)
    model.x0 = [model.head.x0, model.eye.x0, cell2mat(model.scene.x0)];
end

% If model.scene.x0 is function handle, then we will use the passed values
% of cameraDepth and cameraTorsion to assemble the x0.
if isa(model.scene.x0,'function_handle')
    % If we were given single values for cameraDepth and Torsion, use these
    % for all scenes
    if isscalar(cameraTorsion)
        model.x0 = [model.head.x0, model.eye.x0, repmat(model.scene.x0(cameraTorsion, cameraDepth), 1, nScenes)];
    else
        % We have vectors for cameraDepth and torsion. Use a different
        % value for each scene
        model.x0 = [model.head.x0, model.eye.x0];
        for ss = 1:nScenes
            model.x0 = [model.x0, model.scene.x0(cameraTorsion(ss), cameraDepth(ss))];
        end
    end
else
    % It must be a numeric vector, so we have been given a single vector of
    % scene parameter values that we will use for all scenes.
    model.x0 = [model.head.x0, model.eye.x0, repmat(model.scene.x0, 1, nScenes)];
end

% And the bounds
if iscell(model.scene.x0)
    model.bounds = [model.head.bounds, model.eye.bounds, cell2mat(model.scene.bounds)];
else
    model.bounds = [model.head.bounds, model.eye.bounds, repmat(model.scene.bounds, 1, nScenes)];
end


%% Functions

% Return the indices for a given field (head, eye, scene) and param label
model.func.fieldSetIdx = @(field,setLabel) model.(field).idxMap(model.(field).setIdx{strcmp(model.(field).setLabels,setLabel)});
model.func.fieldParamIdx = @(field,paramLabel) model.(field).idxMap(find(strcmp(model.(field).paramLabels,paramLabel)));

% subX  returns the indices for the full set of parameters for each scene
model.func.sceneParamStart = @(sceneIdx) (sceneIdx-1)*model.scene.nParams+model.head.nParams+model.eye.nParams+1;
model.func.subX = @(x,sceneIdx) x([1:(model.head.nParams+model.eye.nParams),model.func.sceneParamStart(sceneIdx):model.func.sceneParamStart(sceneIdx)+model.scene.nParams-1]);

% Penalty is a regularization that penalizes changes in depth and torsion
% from the x0 values. For depth changes, we wish to penalize the total
% change in depth across all scenes. We do not penalize a net zero change
% in depth across the scenes (i.e., the camera is free to move a bit closer
% or father 
cameraDepthTransSet = model.scene.idxMultiScene(model.func.fieldParamIdx('scene','depth'));
commonDepthIdx =model.eye.idxMap(find(strcmp(model.eye.paramLabels,'commonDepth')));
cameraTorsionTransSet = model.scene.idxMultiScene(model.func.fieldParamIdx('scene','torsion'));
model.func.penalty = @(x,x0,w) (1 + ...
    w(1) * abs( x(commonDepthIdx) + mean(x(cameraDepthTransSet) - x0(cameraDepthTransSet)) ) ./ mean(x0(cameraDepthTransSet))  + ...
    w(2) * norm( (x(cameraTorsionTransSet) - x0(cameraTorsionTransSet)) ) ...
    )^2;

% A non-linear constraint for the BADS search that requires first value of
% the corneal curvature (K1) to be less than the second value (K2). Note
% that NONBCON takes a matrix input, which is why we perform this
% calculation over the first dimension. The function returns a non-zero
% value when the constraint is violated (i.e., when K1>K2).
model.func.nonbcon = @(x) x(:,model.func.fieldParamIdx('eye','K1')) > x(:,model.func.fieldParamIdx('eye','K2'));



end




%% LOCAL FUNCTIONS

function into = mergestruct(into, from)
% MERGESTRUCT merge all the fields of scalar structure from into scalar
% structure into
validateattributes(from, {'struct'}, {'scalar'});
validateattributes(into, {'struct'}, {'scalar'});
fns = fieldnames(from);
for fn = fns.'
    if isstruct(from.(fn{1})) && isfield(into, fn{1})
        % nested structure where the field already exist, merge again
        into.(fn{1}) = mergestruct(into.(fn{1}), from.(fn{1}));
    else
        % non structure field, or nested structure field that does not
        % already exist, simply copy
        into.(fn{1}) = from.(fn{1});
    end
end
end
