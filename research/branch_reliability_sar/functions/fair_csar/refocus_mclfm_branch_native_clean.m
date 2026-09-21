function [focus_profile,residual,info] = ...
    refocus_mclfm_branch_native_clean( ...
    x,p_beta_set,nu_set,removal_window_bins,tnorm_full_span)
%REFOCUS_MCLFM_BRANCH_NATIVE_CLEAN
% Branch-native sequential MC-LFM extraction/refocusing for R2A.
%
% This helper is deliberately tied to the SAME coordinate in which R1
% defined G0 and the evaluation-only continuous global branch.
%
% For each component:
%
%   a = tan(pi*p_beta/2) * (tnorm_full_span/(N-1))^2
%
%   recenter:
%       x_r[m] = residual[m] * exp(-j*2*pi*nu*m/N)
%
%   matched-LFM transform:
%       z[m] = x_r[m] * exp(-j*pi*a*m^2)
%       Y    = fftshift(fft(z))/sqrt(N)
%
%   Since the selected branch has been recentered, the selected component
%   should lie at DC. Extract the same frozen 3-bin finite window used by
%   the EXP009/EXP010 practical removal chain.
%
%   Invert the extracted component, undo recentering, subtract it from the
%   residual, and continue sequentially.
%
% focus_profile is accumulated on the ORIGINAL dechirped-tone FFT-bin axis:
% each extracted branch-centered component is transformed back after undoing
% recentering, so different nu estimates appear at their own azimuth-bin
% locations. This produces one common focused-profile coordinate for all
% component orders.
%
% No FrFT-domain u-coordinate mapping is used here.

was_column = iscolumn(x);

x0 = double(x(:).');
residual = x0;

p_beta_set = double(p_beta_set(:).');
nu_set = double(nu_set(:).');

N = numel(x0);
m = 0:N-1;
Q = numel(p_beta_set);

if numel(nu_set) ~= Q
    error('refocus_mclfm_branch_native_clean:SizeMismatch', ...
        'p_beta_set and nu_set must have identical lengths.');
end

if removal_window_bins < 1 || mod(removal_window_bins,2) ~= 1
    error('refocus_mclfm_branch_native_clean:WindowContract', ...
        'removal_window_bins must be a positive odd integer.');
end

% fftshift DC index.
dc = floor(N/2)+1;
half = floor((removal_window_bins-1)/2);

mask = false(1,N);
mask(max(1,dc-half):min(N,dc+half)) = true;

focus_profile = zeros(1,N);

captured_energy_fraction_stage = zeros(1,Q);
residual_energy_ratio_after_stage = zeros(1,Q);
a_sample_set = zeros(1,Q);
dc_peak_ratio_stage = zeros(1,Q);
component_output_energy = zeros(1,Q);

for ii = 1:Q
    p_beta = p_beta_set(ii);
    nu = nu_set(ii);

    scale = tnorm_full_span/(N-1);
    a = tan(pi*p_beta/2)*scale^2;
    a_sample_set(ii) = a;

    Ein_stage = sum(abs(residual).^2);

    % Same recenter operation as EXP009/EXP010.
    phase = exp(-1j*2*pi*nu*m/N);
    xr = residual .* phase;

    % Same matched-LFM transform as EXP009/EXP010.
    z = xr .* exp(-1j*pi*a*m.^2);
    Y = fftshift(fft(z))/sqrt(N);

    % Frozen branch-local finite extraction around DC.
    Yext = zeros(1,N);
    Yext(mask) = Y(mask);

    captured_energy_fraction_stage(ii) = ...
        sum(abs(Yext).^2)/max(sum(abs(Y).^2),eps);

    dc_peak_ratio_stage(ii) = ...
        abs(Y(dc))/max(max(abs(Y)),eps);

    % Return extracted branch to recentered signal domain.
    zext_centered = ifft(ifftshift(Yext))*sqrt(N);
    xext_centered = zext_centered .* exp(1j*pi*a*m.^2);

    % Undo recentering to obtain extracted component in original signal
    % coordinates, then subtract sequentially.
    xext = xext_centered .* conj(phase);
    residual = residual-xext;

    % Build the common matched-filter / focused azimuth profile.
    % Remove the chirp from the extracted component but keep its original
    % linear frequency nu.
    zext_original = xext .* exp(-1j*pi*a*m.^2);
    Yout = fftshift(fft(zext_original))/sqrt(N);

    focus_profile = focus_profile+Yout;
    component_output_energy(ii) = sum(abs(Yout).^2);

    residual_energy_ratio_after_stage(ii) = ...
        sum(abs(residual).^2)/max(sum(abs(x0).^2),eps);
end

info = struct();
info.n_components = Q;
info.p_beta_set = p_beta_set;
info.nu_set = nu_set;
info.a_sample_set = a_sample_set;
info.removal_window_bins = removal_window_bins;
info.dc_index = dc;
info.captured_energy_fraction_stage = captured_energy_fraction_stage;
info.dc_peak_ratio_stage = dc_peak_ratio_stage;
info.component_output_energy = component_output_energy;
info.residual_energy_ratio_after_stage = residual_energy_ratio_after_stage;
info.residual_energy_ratio = ...
    sum(abs(residual).^2)/max(sum(abs(x0).^2),eps);

if was_column
    focus_profile = focus_profile.';
    residual = residual.';
end

end
