%% exp01_residual_lfm.m
% Experiment 01: Residual LFM and FrFT refocusing
%
% Purpose
%   1) Build a normalized residual LFM signal.
%   2) Verify that the optimal FrFT order concentrates the LFM energy.
%   3) Verify that maximum peak and minimum entropy identify nearly the same
%      optimal FrFT order.
%
% Paper link:
%   Wang et al., "Fast and Accurate Refocusing for Moving Ships in SAR
%   Imagery Based on FrFT", Remote Sensing, 2023.
%
% Notes
%   - This experiment intentionally uses normalized time-frequency
%     coordinates first. It isolates the FrFT mechanism from physical-unit
%     normalization issues.
%   - The continuous FrFT kernel convention used here is
%
%       K_alpha(t,u) = A_alpha * exp(j*pi*((t^2+u^2)cot(alpha)
%                         - 2tu csc(alpha)))
%
%     Therefore, for x(t)=exp(j*pi*kappa*t^2), the theoretical focusing
%     condition is
%
%       cot(alpha_opt) + kappa = 0.
%
% Authoring style:
%   Self-contained experiment script + shared helper functions.
%
% -------------------------------------------------------------------------

clear;
clc;
close all;

%% 0. Resolve project paths automatically
script_fullpath = mfilename('fullpath');
exp_dir = fileparts(script_fullpath);     % ...\code\exp01_residual_lfm
code_dir = fileparts(exp_dir);            % ...\code
paper_dir = fileparts(code_dir);          % ...\Wang2023_Fast_Accurate_FrFT

functions_dir = fullfile(code_dir, 'functions');
results_dir = fullfile(paper_dir, 'results', 'exp01_residual_lfm');

if ~exist(functions_dir, 'dir')
    error('Functions directory not found: %s', functions_dir);
end

if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

addpath(functions_dir);

fprintf('============================================================\n');
fprintf('EXP01: Residual LFM and FrFT refocusing\n');
fprintf('Experiment folder : %s\n', exp_dir);
fprintf('Functions folder  : %s\n', functions_dir);
fprintf('Results folder    : %s\n', results_dir);
fprintf('============================================================\n\n');

%% 1. Normalized residual LFM parameters
N = 256;               % Number of slow-time samples
T = 8;                 % Normalized observation duration
dt = T / N;

t = ((0:N-1) - N/2) * dt;
u = t;                 % Same normalized grid for FrFT output coordinate

% Residual chirp model:
% x(t) = w(t) * exp(j*pi*kappa*t^2) * exp(j*2*pi*f0*t)
kappa = 1.20;          % Normalized residual chirp rate
f0 = 0.15;             % Normalized center frequency

% Smooth finite-duration aperture window (toolbox-free Hann window)
w = 0.5 - 0.5*cos(2*pi*(0:N-1)/(N-1));

x = w .* exp(1j*pi*kappa*t.^2) .* exp(1j*2*pi*f0*t);
x = x(:).';            % Row vector

% Theoretical optimal FrFT rotation angle:
% cot(alpha_opt) = -kappa
% Choose alpha in (pi/2, pi) for positive kappa.
alpha_theory = atan2(1, -kappa);
p_theory = 2 * alpha_theory / pi;

fprintf('Normalized residual chirp rate kappa = %.6f\n', kappa);
fprintf('Theoretical alpha_opt               = %.6f rad\n', alpha_theory);
fprintf('Theoretical FrFT order p_opt        = %.6f\n\n', p_theory);

%% 2. Plot the residual LFM in slow time
fig1 = figure('Name', 'EXP01 - Residual LFM', 'Color', 'w');

tiledlayout(2,1, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(t, abs(x), 'LineWidth', 1.2);
grid on;
xlabel('Normalized slow time t');
ylabel('|x(t)|');
title('Residual LFM amplitude');

nexttile;
plot(t, unwrap(angle(x)), 'LineWidth', 1.2);
grid on;
xlabel('Normalized slow time t');
ylabel('Unwrapped phase (rad)');
title('Residual LFM quadratic phase');

exportgraphics(fig1, fullfile(results_dir, 'fig01_residual_lfm_time_domain.png'), ...
    'Resolution', 180);

%% 3. STFT: verify linear instantaneous-frequency ridge
win_len = 64;
hop = 4;
nfft = 256;

[Sstft, f_stft, t_stft] = simple_stft(x, dt, win_len, hop, nfft);

Pstft = abs(Sstft).^2;
Pstft_dB = 10*log10(Pstft / max(Pstft(:)) + eps);

fig2 = figure('Name', 'EXP01 - STFT', 'Color', 'w');
imagesc(t_stft, f_stft, Pstft_dB);
axis xy;
xlabel('Normalized slow time t');
ylabel('Normalized frequency');
title('STFT of residual LFM');
cb = colorbar;
ylabel(cb, 'Normalized power (dB)');
clim([-40 0]);

exportgraphics(fig2, fullfile(results_dir, 'fig02_residual_lfm_stft.png'), ...
    'Resolution', 180);

%% 4. Coarse FrFT-order scan
% Avoid p near 0 or 2 because the direct continuous-kernel expression
% becomes singular as sin(alpha) -> 0.
p_coarse = 1.20 : 0.01 : 1.90;

entropy_coarse = zeros(size(p_coarse));
peak_coarse = zeros(size(p_coarse));
frft_map = zeros(N, numel(p_coarse));

fprintf('Running coarse FrFT scan (%d orders)...\n', numel(p_coarse));

for ii = 1:numel(p_coarse)
    p = p_coarse(ii);

    Xp = frft_direct(x, t, p, u);

    power_p = abs(Xp).^2;
    frft_map(:, ii) = power_p(:);

    entropy_coarse(ii) = signal_entropy(Xp);
    peak_coarse(ii) = max(power_p);
end

[~, idx_entropy_coarse] = min(entropy_coarse);
p_entropy_coarse = p_coarse(idx_entropy_coarse);

[~, idx_peak_coarse] = max(peak_coarse);
p_peak_coarse = p_coarse(idx_peak_coarse);

fprintf('Coarse minimum-entropy order = %.6f\n', p_entropy_coarse);
fprintf('Coarse maximum-peak order    = %.6f\n\n', p_peak_coarse);

%% 5. Fine FrFT-order scan around the coarse minimum
fine_half_width = 0.02;
fine_step = 0.001;

p_fine_left = max(1.01, p_entropy_coarse - fine_half_width);
p_fine_right = min(1.99, p_entropy_coarse + fine_half_width);
p_fine = p_fine_left : fine_step : p_fine_right;

entropy_fine = zeros(size(p_fine));
peak_fine = zeros(size(p_fine));

fprintf('Running fine FrFT scan (%d orders)...\n', numel(p_fine));

for ii = 1:numel(p_fine)
    p = p_fine(ii);

    Xp = frft_direct(x, t, p, u);
    power_p = abs(Xp).^2;

    entropy_fine(ii) = signal_entropy(Xp);
    peak_fine(ii) = max(power_p);
end

[entropy_min, idx_entropy_fine] = min(entropy_fine);
p_entropy_opt = p_fine(idx_entropy_fine);

[peak_max, idx_peak_fine] = max(peak_fine);
p_peak_opt = p_fine(idx_peak_fine);

fprintf('Fine minimum-entropy order = %.6f\n', p_entropy_opt);
fprintf('Fine maximum-peak order    = %.6f\n', p_peak_opt);
fprintf('Theoretical order          = %.6f\n', p_theory);
fprintf('|p_entropy - p_theory|     = %.6e\n', abs(p_entropy_opt - p_theory));
fprintf('|p_peak    - p_theory|     = %.6e\n\n', abs(p_peak_opt - p_theory));

%% 6. Visualize the FrFT-domain energy distribution
frft_map_norm = frft_map ./ (max(frft_map(:)) + eps);
frft_map_dB = 10*log10(frft_map_norm + eps);

fig3 = figure('Name', 'EXP01 - FrFT Order Plane', 'Color', 'w');
imagesc(p_coarse, u, frft_map_dB);
axis xy;
xlabel('FrFT order p');
ylabel('Fractional-frequency coordinate u');
title('FrFT-domain energy distribution versus rotation order');
cb = colorbar;
ylabel(cb, 'Normalized power (dB)');
clim([-35 0]);
hold on;
xline(p_theory, '--', 'Theoretical p_{opt}', 'LineWidth', 1.2);
xline(p_entropy_opt, ':', 'Estimated p_{opt}', 'LineWidth', 1.2);
hold off;

exportgraphics(fig3, fullfile(results_dir, 'fig03_frft_order_plane.png'), ...
    'Resolution', 180);

%% 7. Peak-order and entropy-order curves
peak_norm = peak_coarse / max(peak_coarse);

entropy_min_c = min(entropy_coarse);
entropy_max_c = max(entropy_coarse);
entropy_norm = (entropy_coarse - entropy_min_c) / ...
    (entropy_max_c - entropy_min_c + eps);

fig4 = figure('Name', 'EXP01 - Peak and Entropy', 'Color', 'w');
plot(p_coarse, peak_norm, 'LineWidth', 1.5);
hold on;
plot(p_coarse, entropy_norm, 'LineWidth', 1.5);
xline(p_theory, '--', 'Theoretical p_{opt}', 'LineWidth', 1.2);
xline(p_entropy_opt, ':', 'Estimated p_{opt}', 'LineWidth', 1.2);
grid on;
xlabel('FrFT order p');
ylabel('Normalized metric');
title('Peak maximum and entropy minimum versus FrFT order');
legend('Normalized peak', 'Normalized entropy', ...
    'Theoretical p_{opt}', 'Estimated p_{opt}', ...
    'Location', 'best');
hold off;

exportgraphics(fig4, fullfile(results_dir, 'fig04_peak_entropy_vs_order.png'), ...
    'Resolution', 180);

%% 8. Compare a wrong FrFT order with the optimal order
p_wrong = p_entropy_opt - 0.15;

X_wrong = frft_direct(x, t, p_wrong, u);
X_opt = frft_direct(x, t, p_entropy_opt, u);

power_wrong = abs(X_wrong).^2;
power_opt = abs(X_opt).^2;

concentration_wrong = max(power_wrong) / sum(power_wrong);
concentration_opt = max(power_opt) / sum(power_opt);

entropy_wrong = signal_entropy(X_wrong);
entropy_opt = signal_entropy(X_opt);

fig5 = figure('Name', 'EXP01 - Refocusing Comparison', 'Color', 'w');

tiledlayout(2,1, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(u, abs(X_wrong), 'LineWidth', 1.2);
grid on;
xlabel('Fractional-frequency coordinate u');
ylabel('|X_p(u)|');
title(sprintf('Non-optimal FrFT: p = %.4f', p_wrong));

nexttile;
plot(u, abs(X_opt), 'LineWidth', 1.2);
grid on;
xlabel('Fractional-frequency coordinate u');
ylabel('|X_p(u)|');
title(sprintf('Optimal FrFT refocusing: p = %.4f', p_entropy_opt));

exportgraphics(fig5, fullfile(results_dir, 'fig05_wrong_vs_optimal_frft.png'), ...
    'Resolution', 180);

%% 9. Save numerical summary
summary = struct();

summary.N = N;
summary.T = T;
summary.dt = dt;
summary.kappa = kappa;
summary.f0 = f0;

summary.alpha_theory = alpha_theory;
summary.p_theory = p_theory;

summary.p_entropy_coarse = p_entropy_coarse;
summary.p_peak_coarse = p_peak_coarse;

summary.p_entropy_opt = p_entropy_opt;
summary.p_peak_opt = p_peak_opt;

summary.error_entropy_vs_theory = abs(p_entropy_opt - p_theory);
summary.error_peak_vs_theory = abs(p_peak_opt - p_theory);

summary.entropy_wrong = entropy_wrong;
summary.entropy_opt = entropy_opt;

summary.concentration_wrong = concentration_wrong;
summary.concentration_opt = concentration_opt;

summary.coarse_order_count = numel(p_coarse);
summary.fine_order_count = numel(p_fine);

save(fullfile(results_dir, 'exp01_summary.mat'), ...
    'summary', ...
    't', 'u', 'x', ...
    'p_coarse', 'entropy_coarse', 'peak_coarse', 'frft_map', ...
    'p_fine', 'entropy_fine', 'peak_fine', ...
    'X_wrong', 'X_opt');

%% 10. Console summary
fprintf('================ EXP01 SUMMARY ================\n');
fprintf('Theoretical optimal order          : %.6f\n', p_theory);
fprintf('Estimated order (minimum entropy)  : %.6f\n', p_entropy_opt);
fprintf('Estimated order (maximum peak)     : %.6f\n', p_peak_opt);
fprintf('Entropy at wrong order             : %.6f\n', entropy_wrong);
fprintf('Entropy at optimal order           : %.6f\n', entropy_opt);
fprintf('Peak-energy concentration (wrong)  : %.6f\n', concentration_wrong);
fprintf('Peak-energy concentration (optimal): %.6f\n', concentration_opt);
fprintf('Saved results to:\n%s\n', results_dir);
fprintf('================================================\n');

if entropy_opt >= entropy_wrong
    warning(['Unexpected result: optimal-order entropy is not smaller than ' ...
             'wrong-order entropy. Check the FrFT implementation or sampling.']);
end

if concentration_opt <= concentration_wrong
    warning(['Unexpected result: optimal-order peak concentration is not larger ' ...
             'than wrong-order concentration.']);
end
