function n = returnRefractiveIndex( material, spectralDomain )
% Returns the refractice index for a specified material and spectral domain
%
% Syntax:
%  n = returnRefractiveIndex( material, spectralDomain )
%
% Description:
%   The optical model requires the refractive index of several biological
%   and optical materials. The index of refraction varies by wavelength of
%   light. This routine returns the index for a specified material for a
%   specified imaging domain (visual or near infrared).
%
%   Unless otherwise specified, refractive index in the visible (VIS)
%   domain is at 589.29 nm (the sodium spectral line), while the index in
%   the near-infrared (NIR) domain is at 950 nm, which is the center
%   frequency of light emitted by the LED of many active IR cameras.
%
% Inputs:
%   material              - String.
%   spectralDomain        - String. Valid values are {'VIS','NIR'}.
%
% Outputs:
%   n                     - The requested index of refraction.
%

%% input parser
p = inputParser;

% Optional
p.addRequired('material',@ischar);
p.addRequired('spectralDomain',@ischar);

% parse
p.parse(material,spectralDomain)

% Look up the indices of refraction ns = [VIS, NIR] for the specified
% material
switch material
    case 'vacuum'
        ns = [1.000 1.000];
    case 'air'
        ns = [1.000 1.000];
    case 'water'
        % https://en.wikipedia.org/wiki/Optical_properties_of_water_and_ice
        ns = [1.333 1.347];
    case 'vitreous'
        % Sardar, Dhiraj K., et al. "Optical properties of ocular tissues
        % in the near infrared region." Lasers in medical science 22.1
        % (2007): 46-52.
        ns = [1.357 1.345];
    case 'aqueous'
        % Sardar, Dhiraj K., et al. "Optical properties of ocular tissues
        % in the near infrared region." Lasers in medical science 22.1
        % (2007): 46-52.
        ns = [1.348 1.337];
    case 'cornea'
        % I cannot find a measurement of the index of refraction of the
        % cornea in NIR. Amazing. Using the visible value.
        ns = [1.376 1.376];
    case 'hydrogel'
        % Childs, Andre, et al. "Fabricating customized hydrogel contact
        % lens." Scientific reports 6 (2016): 34905.
        ns = [1.430 1.420];
    case 'optorez'
        % Nikolov, Ivan D., and Christo D. Ivanov. "Optical plastic
        % refractive measurements in the visible and the near-infrared
        % regions." Applied Optics 39.13 (2000): 2067-2070.
        % Measured at 594 and 890 nm
        ns = [1.5089 1.5004];
    case 'cr-39'
        % Traynor, Nathan BJ, et al. "CR-39 (PADC) Reflection and
        % Transmission of Light in the Ultraviolet-Near-Infrared (UV-NIR)
        % Range." Applied spectroscopy (2017): 0003702817745071.
        % NIR value estimated from Figure 5b.
        ns = [1.51 1.50];
    case 'polycarbonate'
        % Nikolov, Ivan D., and Christo D. Ivanov. "Optical plastic
        % refractive index measurements for NIR region." 18th Congress of
        % the International Commission for Optics. Vol. 3749. International
        % Society for Optics and Photonics, 1999.
        ns = [1.5852 1.5614];
    otherwise
        error(['I do not know the index of refraction for ' material]);
end

% Now, select which index to return based upon the spectral domain.
switch spectralDomain
    case {'VIS','vis','Vis','visible'}
        n = ns(1);
    case {'NIR','nir','Nir','near infrared','near infra-red'}
        n = ns(2);
    otherwise
        error(['I do not have values for the spectral domain of ' spectralDomain]);
end

end

