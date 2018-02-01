# transparentTrack
Code to analyze pupil size and gaze location in IR videos of the eye.

These MATLAB routines are designed to operate upon monocular, infra-red videos of the eye and extract the elliptical boundary of the pupil in the image plane. Absolute pupil size and gaze position are estimated without the need for explicit calibration.

Notably, this software is computationally intensive and is designed to be run off-line upon videos collected during an experimental session. A particular design goal is to provide an accurate fit to the pupil boundary even when it is partially obscured by the eyelid. This circumstance is encountered when the pupil is large, as is seen in data collected under low-light conditions or in people with retinal disease.

The central computation is to fit an ellipse to the pupil boundary in each image frame. This fitting operation is performed iteratively, aided by ever more informed constraints upon the parameters that define the ellipse. The ellipse equation is cast in "transparent" form, with parameters that define x center, y center, area, eccentricity (non-linear aspect ratio), and theta (angle of tilt). Expressing the parameters of the ellipse in this way allows us to place boundaries and non-linear constraints upon the values.

The parameters of the ellipse are constrained by a projection model of the appearance of the pupil on the image plane. A perspective projection of an anatomically accurate eye is calculated, accounting for the refractive properties of the cornea and any lens distortion in the camera. The parameters of this model are informed by normal variation in eye biometrics from the literature, subject spherical refraction and optionally measured axial length, by empirical calibration of the IR camera, and by estimation of the geometry of the scene performed by the routine.

At a high level of description, the fitting approach involves:
- **Intensity segmentation to extract the boundary of the pupil**. A preliminary circle fit via the Hough transform and an adaptive size window. In principle, another algorithm (e.g., the Starburst) could be substituted here.
- **Initial ellipse fit with minimal parameter constraints**. During this initial stage, the pupil boundary is refined through the application of "cuts" of different angles and extent. The minimum cut that provides an acceptable ellipse fit is retained. This step addresses obscuration of the pupil border by the eyelid or by non-uniform IR illumination of the pupil.
- **Estimation of scene geometry**. Assuming an underlying physical model for the data (circular pupil on a spherical eye behind a refractive cornea), an estimate is made of the extrinsic translation vector for the forward, perspective projection model that best accounts for the observed ellipses on the image plane. This step is informed by an empirical measurement of the camera intrinsics and lens distortion parameters (https://www.mathworks.com/help/vision/ug/single-camera-calibrator-app.html). 
- **Repeat ellipse fit with scene geometry constraints**. Given the scene geometry, the perimeter of the pupil on the image plane is re-fit in terms of explicit values for the rotation of the eye and the radius of the pupil in millimeters.
- **Smooth pupil radius**. Pupil radius is expected to change relatively slowly. This physiologic property motivates temporal smoothing of pupil radius using an empirical Bayes approach. A non-causal, empirical prior is constructed for each time point using the (exponentially weighted) pupil radius observed in adjacent time points. The posterior is calculated and the pupil perimeter in the image is refit using this value as a constraint upon the radius.

There are many parameters that control the behavior of the routines. While the default settings work well for some videos (including those that are part of the sandbox demo included in this repository), other parameter settings may be needed for videos with different qualities.

The MATLAB parpool may be used to speed the analysis on multi-core systems.

To install and configure transparentTrack, first install toolboxToolbox (tBtB), which provides for declarative dependency management for Matlab (https://github.com/ToolboxHub/ToolboxToolbox). Once tBtB is installed, transparentTrack (and all its dependencies) will be installed and readied for use with the command `tbUse('transparentTrack')`. One of these dependencies is the quadfit toolbox (https://www.mathworks.com/matlabcentral/fileexchange/45356-fitting-quadratic-curves-and-surfaces).
