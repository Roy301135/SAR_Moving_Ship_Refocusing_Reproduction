%% exp02_motion_states.m
% EXP02: Motion states -> residual phase order -> LFM/NLFM -> FrFT refocusing
%
% Reproduction target:
%   Wang et al., "Fast and Accurate Refocusing for Moving Ships in SAR
%   Imagery Based on FrFT", Remote Sensing, 2023.
%
% This experiment reproduces the mechanism behind paper Figures 4-7:
%
%   Case A: azimuth velocity      va = 20 m/s
%   Case B: range acceleration   ar = 10 m/s^2
%   Case C: azimuth acceleration aa = 15 m/s^2
%
% Paper-supported SAR parameters:
%   fc   = 3 GHz
%   PRF  = 188 Hz
%   B    = 150 MHz
%   H    = 3000 m
%   La   = 2 m
%   vsar = 150 m/s
%   Tp   = 1.5 us
%
% IMPORTANT REPRODUCTION ASSUMPTIONS
% -------------------------------------------------------------------------
% 1) The paper defines x0 in its geometry, but Table 1 does not provide a
%    numerical x0 for the simulation. Here we explicitly choose
%
%        x0 = 3000 m
%
%    giving a 45-degree-like side-looking geometry (H = x0).
%
% 2) The paper does not state the exact synthetic-aperture duration used in
%    Figure 4-7. Here we estimate it from
%
%        beamwidth ~= lambda / antenna_length
%        T_ap      ~= R0 * beamwidth / vsar
%
%    This is a controlled mechanism reproduction, not a pixel-for-pixel
%    recreation of the published figures.
%
% 3) We generate two related signals:
%
%    (a) A matched-filter azimuth profile:
%        raw moving-target azimuth echo correlated with a stationary-target
%        reference. This visualizes azimuth broadening/asymmetric distortion.
%
%    (b) The motion-induced residual phase factor:
%
%        r(eta) = w(eta) * exp[-j*4*pi/lambda*(R_move-R_static)]
%
%        This isolates the residual phase term corresponding to the
%        mechanism of Eq. (10). STFT and FrFT diagnostics are performed on
%        this residual factor so that the LFM/NLFM boundary is transparent.
%
% Required shared functions from EXP01:
%   frft_direct.m
%   signal_entropy.m
%   simple_stft.m
%
% New helper for EXP02:
%   simulate_motion_case.m
%
% -------------------------------------------------------------------------

clear;
clc;
close all;

%% 0. Resolve project paths
script_fullpath = mfilename('fullpath');
exp_dir = fileparts(script_fullpath);     % ...\code\exp02_motion_states
code_dir = fileparts(exp_dir);            % ...\code
paper_dir = fileparts(code_dir);          % ...\Wang2023_Fast_Accurate_FrFT

functions_dir = fullfile(code_dir, 'functions');
results_dir = fullfile(paper_dir, 'results', 'exp02_motion_states');

if ~exist(functions_dir, 'dir')
    error('Functions directory not found: %s', functions_dir);
end

if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

addpath(functions_dir);

required_functions = {'frft_direct', 'signal_entropy', ...
                      'simple_stft', 'simulate_motion_case'};

for ii = 1:numel(required_functions)
    if exist(required_functions{ii}, 'file') ~= 2
        error('Required function not found: %s.m', required_functions{ii});
    end
end

fprintf('============================================================\n');
fprintf('EXP02: SAR moving-target motion states and FrFT boundary\n');
fprintf('Experiment folder : %s\n', exp_dir);
fprintf('Functions folder  : %s\n', functions_dir);
fprintf('Results folder    : %s\n', results_dir);
fprintf('============================================================\n\n');

%% 1. SAR parameters from the paper
params.c = 299792458;        % speed of light (m/s)
params.fc = 3e9;             % carrier frequency (Hz)
params.lambda = params.c / params.fc;
params.PRF = 188;            % pulse repetition frequency (Hz)
params.B = 150e6;            % bandwidth (Hz)
params.H = 3000;             % platform height (m)
params.Lant = 2;             % antenna length (m)
params.vsar = 150;           % platform velocity (m/s)
params.Tp = 1.5e-6;          % pulse width (s)

% Explicit assumption because the paper does not provide a numerical x0
% in the simulation parameter table.
params.x0 = 3000;            % cross-track ground coordinate (m)

params.R0 = hypot(params.H, params.x0);

% Controlled estimate of the synthetic aperture duration.
params.az_beamwidth = params.lambda / params.Lant;
params.Tap_est = params.R0 * params.az_beamwidth / params.vsar;

N = round(params.Tap_est * params.PRF);

% Use an odd number of samples so eta = 0 is exactly sampled.
if mod(N, 2) == 0
    N = N + 1;
end

% Keep enough samples for a stable STFT.
N = max(N, 129);

eta = ((0:N-1) - (N-1)/2) / params.PRF;
params.N = N;
params.eta = eta;

% Toolbox-free Hann aperture.
params.window = 0.5 - 0.5*cos(2*pi*(0:N-1)/(N-1));

fprintf('Paper SAR parameters:\n');
fprintf('  fc             = %.3f GHz\n', params.fc/1e9);
fprintf('  lambda         = %.6f m\n', params.lambda);
fprintf('  PRF            = %.3f Hz\n', params.PRF);
fprintf('  H              = %.1f m\n', params.H);
fprintf('  vsar           = %.1f m/s\n', params.vsar);
fprintf('  antenna length = %.2f m\n', params.Lant);
fprintf('\nControlled reproduction assumptions:\n');
fprintf('  x0             = %.1f m\n', params.x0);
fprintf('  R0             = %.3f m\n', params.R0);
fprintf('  estimated Tap  = %.6f s\n', params.Tap_est);
fprintf('  N              = %d azimuth samples\n\n', N);

%% 2. Three motion states from Section 4.1
motions(1) = struct( ...
    'short_name', 'Azimuth velocity', ...
    'label', 'v_a = 20 m/s', ...
    'vr', 0, ...
    'ar', 0, ...
    'va', 20, ...
    'aa', 0);

motions(2) = struct( ...
    'short_name', 'Range acceleration', ...
    'label', 'a_r = 10 m/s^2', ...
    'vr', 0, ...
    'ar', 10, ...
    'va', 0, ...
    'aa', 0);

motions(3) = struct( ...
    'short_name', 'Azimuth acceleration', ...
    'label', 'a_a = 15 m/s^2', ...
    'vr', 0, ...
    'ar', 0, ...
    'va', 0, ...
    'aa', 15);

n_cases = numel(motions);

%% 3. Generate exact range histories and mismatch signals
% IMPORTANT:
% Do not preallocate with repmat(struct(), ...). That creates a struct array
% with no fields, and MATLAB does not allow assigning a struct with fields
% into it ("Subscripted assignment between dissimilar structures").
%
% Initialize the first element from the actual function output so that the
% struct field layout is established correctly, then preallocate the rest
% using that template.

fprintf('Generating exact moving-target range histories...\n');

results(1) = simulate_motion_case(params, motions(1));
results = repmat(results(1), 1, n_cases);

for ic = 2:n_cases
    results(ic) = simulate_motion_case(params, motions(ic));
end

fprintf('Range-history generation completed.\n\n');

%% 4. Quantify instantaneous-frequency linearity
% For an LFM, instantaneous frequency should be approximately linear in eta.
% The R^2 value of a linear fit gives a useful diagnostic:
%
%   R^2 ~= 1   -> strong LFM behavior
%   R^2 << 1   -> clear nonlinear-FM behavior

for ic = 1:n_cases

    mask = params.window > 0.20;

    phase_res = unwrap(angle(results(ic).residual_signal));
    f_inst = gradient(phase_res, eta) / (2*pi);

    fit_coeff = polyfit(eta(mask), f_inst(mask), 1);
    f_fit = polyval(fit_coeff, eta(mask));

    ss_res = sum((f_inst(mask) - f_fit).^2);
    ss_tot = sum((f_inst(mask) - mean(f_inst(mask))).^2);

    if ss_tot > eps
        R2 = 1 - ss_res/ss_tot;
    else
        R2 = 1;
    end

    % Fourth-order polynomial fit of residual phase for diagnostics:
    % coeff(1)*eta^4 + coeff(2)*eta^3 + ... + coeff(5)
    phase_poly4 = polyfit(eta(mask), phase_res(mask), 4);

    results(ic).phase_residual = phase_res;
    results(ic).f_inst = f_inst;
    results(ic).f_linear_fit_coeff = fit_coeff;
    results(ic).f_linear_R2 = R2;
    results(ic).phase_poly4 = phase_poly4;
end

%% 5. Theoretical second-order residual Doppler-rate contribution
%
% From the paper's quadratic model:
%
%   Ka_static = -2*vsar^2 / (lambda*R0)
%
%   Ka_move   = 2[-ar*x0 - (vsar-va)^2] / (lambda*R0)
%
% Therefore the residual quadratic chirp rate after removing the stationary
% reference is
%
%   K_res = Ka_move - Ka_static
%
% For the azimuth-acceleration case, this second-order prediction is not
% sufficient because aa enters higher-order phase terms.

Ka_static = -2 * params.vsar^2 / (params.lambda * params.R0);

% Normalized FrFT coordinate used below:
% t_norm ranges from -4 to 4.
t_norm = eta / max(abs(eta)) * 4;
u_norm = t_norm;

% eta = eta_scale * t_norm
eta_scale = max(abs(eta)) / 4;

for ic = 1:n_cases

    ar = motions(ic).ar;
    va = motions(ic).va;

    Ka_move_second = ...
        2 * (-ar*params.x0 - (params.vsar-va)^2) / ...
        (params.lambda * params.R0);

    K_res_second = Ka_move_second - Ka_static;

    % If residual phase is approximately
    %
    %   pi*K_res*eta^2
    %
    % then in normalized t:
    %
    %   pi*kappa_norm*t_norm^2
    %   kappa_norm = K_res * eta_scale^2
    kappa_norm_theory = K_res_second * eta_scale^2;

    alpha_second = atan2(1, -kappa_norm_theory);
    p_second = 2 * alpha_second / pi;

    results(ic).Ka_static = Ka_static;
    results(ic).Ka_move_second = Ka_move_second;
    results(ic).K_res_second = K_res_second;
    results(ic).kappa_norm_theory = kappa_norm_theory;
    results(ic).p_second_order_theory = p_second;
end

%% 6. STFT for the three residual signals
win_len = min(64, floor(N/2));

% Force even win_len for a clean center definition.
if mod(win_len, 2) ~= 0
    win_len = win_len - 1;
end

hop = 4;
nfft = 256;

for ic = 1:n_cases

    [Sstft, f_stft, t_stft] = simple_stft( ...
        results(ic).residual_signal, ...
        1/params.PRF, ...
        win_len, hop, nfft);

    Pstft = abs(Sstft).^2;
    Pstft_dB = 10*log10(Pstft / max(Pstft(:)) + eps);

    results(ic).Sstft = Sstft;
    results(ic).f_stft = f_stft;
    results(ic).t_stft = t_stft;
    results(ic).Pstft_dB = Pstft_dB;
end

%% 7. FrFT order search for each motion state
%
% We scan almost the entire non-singular interval 0 < p < 2.
% Case B can have an optimal order close to zero, so a wide interval is
% necessary.
%
% Coarse search is used for the 2D FrFT-order map, followed by a local fine
% search for the entropy minimum.

p_coarse = 0.05 : 0.02 : 1.95;
fine_half_width = 0.03;
fine_step = 0.001;

fprintf('Starting FrFT scans...\n');

for ic = 1:n_cases

    fprintf('  Case %d/%d: %s\n', ic, n_cases, motions(ic).short_name);

    x = results(ic).residual_signal;

    entropy_coarse = zeros(size(p_coarse));
    peak_coarse = zeros(size(p_coarse));
    frft_map = zeros(N, numel(p_coarse));

    for ip = 1:numel(p_coarse)

        Xp = frft_direct(x, t_norm, p_coarse(ip), u_norm);
        power_p = abs(Xp).^2;

        frft_map(:, ip) = power_p(:);
        entropy_coarse(ip) = signal_entropy(Xp);
        peak_coarse(ip) = max(power_p);
    end

    [~, idx_min] = min(entropy_coarse);
    p0 = p_coarse(idx_min);

    p_left = max(0.02, p0 - fine_half_width);
    p_right = min(1.98, p0 + fine_half_width);
    p_fine = p_left : fine_step : p_right;

    entropy_fine = zeros(size(p_fine));
    peak_fine = zeros(size(p_fine));

    for ip = 1:numel(p_fine)

        Xp = frft_direct(x, t_norm, p_fine(ip), u_norm);
        power_p = abs(Xp).^2;

        entropy_fine(ip) = signal_entropy(Xp);
        peak_fine(ip) = max(power_p);
    end

    [entropy_opt, idx_entropy] = min(entropy_fine);
    p_opt_entropy = p_fine(idx_entropy);

    [~, idx_peak] = max(peak_fine);
    p_opt_peak = p_fine(idx_peak);

    X_opt = frft_direct(x, t_norm, p_opt_entropy, u_norm);

    power_opt = abs(X_opt).^2;
    concentration_opt = max(power_opt) / sum(power_opt);

    results(ic).p_coarse = p_coarse;
    results(ic).entropy_coarse = entropy_coarse;
    results(ic).peak_coarse = peak_coarse;
    results(ic).frft_map = frft_map;

    results(ic).p_fine = p_fine;
    results(ic).entropy_fine = entropy_fine;
    results(ic).peak_fine = peak_fine;

    results(ic).p_opt_entropy = p_opt_entropy;
    results(ic).p_opt_peak = p_opt_peak;
    results(ic).entropy_opt = entropy_opt;
    results(ic).X_opt = X_opt;
    results(ic).concentration_opt = concentration_opt;
end

fprintf('FrFT scans completed.\n\n');

%% 8. Figure 1: matched-filter azimuth profiles (paper Figure 4 mechanism)
fig1 = figure('Name', 'EXP02 - Azimuth profiles', 'Color', 'w');

tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

for ic = 1:n_cases

    nexttile;

    profile_move = abs(results(ic).az_profile);
    profile_static = abs(results(ic).az_profile_static);

    profile_move = profile_move / max(profile_move);
    profile_static = profile_static / max(profile_static);

    plot(results(ic).lags, profile_move, 'LineWidth', 1.4);
    hold on;
    plot(results(ic).lags, profile_static, '--', 'LineWidth', 1.0);
    hold off;

    grid on;
    xlabel('Azimuth lag (s)');
    ylabel('Normalized magnitude');
    title(sprintf('%s\n%s', motions(ic).short_name, motions(ic).label));
    legend('Moving target', 'Static reference', 'Location', 'best');

    xlim([-0.40, 0.40]);
end

sgtitle('Matched-filter azimuth profiles for different motion states');

exportgraphics(fig1, ...
    fullfile(results_dir, 'fig01_azimuth_profiles_motion_states.png'), ...
    'Resolution', 180);

%% 9. Figure 2: STFT time-frequency distributions (paper Figure 5 mechanism)
fig2 = figure('Name', 'EXP02 - STFT motion states', 'Color', 'w');

tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

for ic = 1:n_cases

    nexttile;

    imagesc( ...
        results(ic).t_stft, ...
        results(ic).f_stft, ...
        results(ic).Pstft_dB);

    axis xy;
    xlabel('Azimuth slow time \eta (s)');
    ylabel('Frequency (Hz)');
    title(sprintf('%s\nR^2_{linear}=%.4f', ...
        motions(ic).short_name, ...
        results(ic).f_linear_R2));

    clim([-35 0]);
end

cb = colorbar;
ylabel(cb, 'Normalized power (dB)');

sgtitle('STFT of motion-induced residual signals');

exportgraphics(fig2, ...
    fullfile(results_dir, 'fig02_stft_motion_states.png'), ...
    'Resolution', 180);

%% 10. Figure 3: FrFT order-energy maps (paper Figure 6 mechanism)
fig3 = figure('Name', 'EXP02 - FrFT order maps', 'Color', 'w');

tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

for ic = 1:n_cases

    nexttile;

    map = results(ic).frft_map;
    map = map / (max(map(:)) + eps);
    map_dB = 10*log10(map + eps);

    imagesc(p_coarse, u_norm, map_dB);
    axis xy;
    xlabel('FrFT order p');
    ylabel('Fractional coordinate u');
    title(sprintf('%s\np_{opt}=%.3f', ...
        motions(ic).short_name, ...
        results(ic).p_opt_entropy));

    clim([-35 0]);

    hold on;
    xline(results(ic).p_opt_entropy, ':', 'p_{opt}', ...
        'LineWidth', 1.1);
    hold off;
end

cb = colorbar;
ylabel(cb, 'Normalized power (dB)');

sgtitle('FrFT-domain energy distribution versus rotation order');

exportgraphics(fig3, ...
    fullfile(results_dir, 'fig03_frft_order_maps.png'), ...
    'Resolution', 180);

%% 11. Figure 4: FrFT outputs at each optimal order (paper Figure 7 mechanism)
fig4 = figure('Name', 'EXP02 - Optimal FrFT outputs', 'Color', 'w');

tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

for ic = 1:n_cases

    nexttile;

    amp = abs(results(ic).X_opt);
    amp = amp / max(amp);

    plot(u_norm, amp, 'LineWidth', 1.3);
    grid on;
    xlabel('Fractional coordinate u');
    ylabel('Normalized magnitude');

    title(sprintf('%s\np=%.3f, C=%.3f', ...
        motions(ic).short_name, ...
        results(ic).p_opt_entropy, ...
        results(ic).concentration_opt));

    xlim([min(u_norm), max(u_norm)]);
end

sgtitle('Signals after FrFT at their minimum-entropy orders');

exportgraphics(fig4, ...
    fullfile(results_dir, 'fig04_optimal_frft_outputs.png'), ...
    'Resolution', 180);

%% 12. Figure 5: instantaneous-frequency linearity (our diagnostic extension)
fig5 = figure('Name', 'EXP02 - Instantaneous frequency diagnostics', ...
    'Color', 'w');

tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

for ic = 1:n_cases

    nexttile;

    mask = params.window > 0.20;

    plot(eta(mask), results(ic).f_inst(mask), 'LineWidth', 1.3);
    hold on;

    f_fit = polyval(results(ic).f_linear_fit_coeff, eta(mask));
    plot(eta(mask), f_fit, '--', 'LineWidth', 1.2);

    hold off;
    grid on;

    xlabel('Azimuth slow time \eta (s)');
    ylabel('Instantaneous frequency (Hz)');
    title(sprintf('%s\nlinear-fit R^2 = %.6f', ...
        motions(ic).short_name, ...
        results(ic).f_linear_R2));

    legend('Measured', 'Linear fit', 'Location', 'best');
end

sgtitle('LFM/NLFM diagnostic from instantaneous frequency');

exportgraphics(fig5, ...
    fullfile(results_dir, 'fig05_instantaneous_frequency_linearity.png'), ...
    'Resolution', 180);

%% 13. Numerical summary table
case_name = strings(n_cases, 1);
Kres_second = zeros(n_cases, 1);
p_theory_second = zeros(n_cases, 1);
p_entropy = zeros(n_cases, 1);
p_peak = zeros(n_cases, 1);
linear_R2 = zeros(n_cases, 1);
frft_concentration = zeros(n_cases, 1);
phase_eta2 = zeros(n_cases, 1);
phase_eta3 = zeros(n_cases, 1);
phase_eta4 = zeros(n_cases, 1);

for ic = 1:n_cases

    case_name(ic) = string(motions(ic).short_name);

    Kres_second(ic) = results(ic).K_res_second;
    p_theory_second(ic) = results(ic).p_second_order_theory;

    p_entropy(ic) = results(ic).p_opt_entropy;
    p_peak(ic) = results(ic).p_opt_peak;

    linear_R2(ic) = results(ic).f_linear_R2;
    frft_concentration(ic) = results(ic).concentration_opt;

    % polyfit degree 4:
    % c4 eta^4 + c3 eta^3 + c2 eta^2 + c1 eta + c0
    phase_eta4(ic) = results(ic).phase_poly4(1);
    phase_eta3(ic) = results(ic).phase_poly4(2);
    phase_eta2(ic) = results(ic).phase_poly4(3);
end

summary_table = table( ...
    case_name, ...
    Kres_second, ...
    p_theory_second, ...
    p_entropy, ...
    p_peak, ...
    linear_R2, ...
    frft_concentration, ...
    phase_eta2, ...
    phase_eta3, ...
    phase_eta4, ...
    'VariableNames', { ...
    'MotionState', ...
    'SecondOrderKres_HzPerS', ...
    'SecondOrderTheoryOrder', ...
    'EntropyOptimalOrder', ...
    'PeakOptimalOrder', ...
    'InstantFreqLinearR2', ...
    'OptimalFrFTConcentration', ...
    'PhaseCoeffEta2', ...
    'PhaseCoeffEta3', ...
    'PhaseCoeffEta4'});

disp(' ');
disp('================ EXP02 SUMMARY TABLE ================');
disp(summary_table);

%% 14. Explicit pass/fail mechanism checks
fprintf('\n================ EXP02 MECHANISM CHECKS ================\n');

fprintf('Case A - azimuth velocity:\n');
fprintf('  instantaneous-frequency R^2 = %.8f\n', results(1).f_linear_R2);
fprintf('  entropy optimal order       = %.6f\n', results(1).p_opt_entropy);
fprintf('  2nd-order theoretical order = %.6f\n', ...
    results(1).p_second_order_theory);

fprintf('\nCase B - range acceleration:\n');
fprintf('  instantaneous-frequency R^2 = %.8f\n', results(2).f_linear_R2);
fprintf('  entropy optimal order       = %.6f\n', results(2).p_opt_entropy);
fprintf('  2nd-order theoretical order = %.6f\n', ...
    results(2).p_second_order_theory);

fprintf('\nCase C - azimuth acceleration:\n');
fprintf('  instantaneous-frequency R^2 = %.8f\n', results(3).f_linear_R2);
fprintf('  entropy optimal order       = %.6f\n', results(3).p_opt_entropy);
fprintf('  NOTE: second-order order is not sufficient for this case because\n');
fprintf('        azimuth acceleration introduces higher-order phase.\n');

fprintf('\nExpected qualitative result:\n');
fprintf('  Case A: R^2 ~ 1, clear FrFT concentration, good refocusing.\n');
fprintf('  Case B: R^2 ~ 1, clear FrFT concentration, good refocusing.\n');
fprintf('  Case C: R^2 much smaller, curved TF ridge, diffuse FrFT result.\n');
fprintf('==========================================================\n');

%% 15. Save all results
save(fullfile(results_dir, 'exp02_summary.mat'), ...
    'params', 'motions', 'results', ...
    'summary_table', ...
    'eta', 't_norm', 'u_norm');

writetable(summary_table, ...
    fullfile(results_dir, 'exp02_summary.csv'));

fprintf('\nSaved all figures and numerical results to:\n%s\n', results_dir);
