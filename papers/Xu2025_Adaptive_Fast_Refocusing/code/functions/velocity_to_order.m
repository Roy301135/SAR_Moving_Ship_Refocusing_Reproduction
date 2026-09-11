function [p_signed, p_raw, p_centered] = velocity_to_order(v, Vsar, lambda, R0, PRF, Na)
%VELOCITY_TO_ORDER Invert Eq. (22) of Xu et al. (JSTARS, 2025).
%
% Inputs:
%   v       - azimuth velocity [m/s]
%   Vsar    - SAR platform velocity [m/s]
%   lambda  - wavelength [m]
%   R0      - reference slant range [m]
%   PRF     - pulse repetition frequency [Hz]
%   Na      - number of azimuth samples in the processed slice
%
% Outputs:
%   p_signed   - signed FrFT order around zero
%   p_raw      - modulo-2 FrFT order in [0, 2)
%   p_centered - centered order used for comparison with Table III
%
% Notes:
%   alpha = p*pi/2.
%   The centered representation is used only to place the Table III orders
%   on a continuous branch around -0.5.

p_signed = zeros(size(v));

nonzero = abs(v) > 1e-12;
vv = v(nonzero);

q = 1 - vv ./ Vsar;
D = 2 * Vsar^2 ./ (q.^2 - 1);

cot_alpha = (D + 2 * Vsar^2) .* Na ./ ...
            (lambda * R0 * PRF^2);

alpha = atan(1 ./ cot_alpha);

p_signed(nonzero) = 2 * alpha / pi;
p_raw = mod(p_signed, 2);
p_centered = p_signed - 0.5;

end
