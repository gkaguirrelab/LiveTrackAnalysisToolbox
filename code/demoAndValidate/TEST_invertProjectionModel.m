%% UNIT TEST OF FORWARD AND INVERSE PUPIL PROJECTION MODELS

tolerance = 1e-6;

eyeCenter = [320 240 1500];
eyeRadius = 150;

projectionModels = {'pseudoPerspective' 'orthogonal' };

for models = 1:length(projectionModels)
    fprintf(['testing ' projectionModels{models} ' model \n']);
    for pupilAzimuth = -15:15:15
        for pupilElevation = -15:15:15
            reconstructedTransparentEllipse = pupilProjection_fwd(pupilAzimuth, pupilElevation, nan, eyeCenter, eyeRadius, projectionModels{models});
            [reconstructedPupilAzi, reconstructedPupilEle, ~] = pupilProjection_inv(reconstructedTransparentEllipse, eyeCenter, eyeRadius, projectionModels{models});
            if abs(reconstructedPupilAzi-pupilAzimuth) > tolerance || abs(reconstructedPupilEle-pupilElevation) > tolerance
                error('Failed inversion check for azimuth %d, elevation %d',pupilAzimuth,pupilElevation);
        end
    end
end