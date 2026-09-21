function fit = sar_fit_sampled_lfm(x)
%SAR_FIT_SAMPLED_LFM Weighted quadratic-phase fit in frozen EXP009/010 form.
%
% Frozen sampled convention:
%   x[m] = A[m] exp(j 2pi (0.5*a*m^2 + (nu/N)*m) + j phi),
%   m = 0,...,N-1.
%
% Hence:
%   phase = pi*a*m^2 + 2pi*(nu/N)*m + phi,
%   beta  = atan(a).
%
% The amplitude is allowed to vary slowly due to the physical range
% response. Magnitude^2 weighting prevents low-energy samples from
% dominating the phase fit. No truth from another component enters.

x = x(:).';
N = numel(x);
m = 0:N-1;
mag = abs(x);

if max(mag) <= 0
    error('sar_fit_sampled_lfm:ZeroSignal','Input signal has zero magnitude.');
end

valid = mag > max(mag)*1e-8;
if nnz(valid) < 8
    error('sar_fit_sampled_lfm:TooFewSamples', ...
        'Too few non-negligible samples for quadratic phase fit.');
end

mv = m(valid).';
phase = unwrap(angle(x(valid))).';
w = (mag(valid).'/max(mag(valid))).^2;

A = [mv.^2, mv, ones(size(mv))];
Aw = A .* sqrt(w);
yw = phase .* sqrt(w);
coef = Aw \ yw;
phase_fit = A * coef;
residual = phase - phase_fit;

phase_mean = sum(w.*phase)/sum(w);
centered = phase - phase_mean;
den = sum(w.*centered.^2);
if den <= eps
    nrmse = NaN;
    r2 = NaN;
else
    mse_num = sum(w.*residual.^2);
    nrmse = sqrt(mse_num/den);
    r2 = 1 - mse_num/den;
end

a = coef(1)/pi;
nu_bins = coef(2)*N/(2*pi);
beta = atan(a);

fit.N = N;
fit.a = a;
fit.beta_rad = beta;
fit.nu_bins = nu_bins;
fit.phase0_rad = coef(3);
fit.phase_fit_nrmse = nrmse;
fit.phase_fit_r2 = r2;
fit.max_abs_phase_residual_rad = max(abs(residual));
fit.amplitude_mean = mean(mag);
fit.amplitude_cv = std(mag)/max(mean(mag),eps);
fit.min_to_max_amplitude_ratio = min(mag)/max(mag);
fit.valid_sample_count = nnz(valid);
fit.m = m;
fit.valid_mask = valid;
fit.unwrapped_phase_valid = phase;
fit.phase_fit_valid = phase_fit;

end
