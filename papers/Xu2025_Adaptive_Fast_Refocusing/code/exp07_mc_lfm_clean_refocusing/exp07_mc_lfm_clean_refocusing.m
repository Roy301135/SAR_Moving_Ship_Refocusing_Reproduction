%% exp07_mc_lfm_clean_refocusing.m
% Xu et al., JSTARS 2025
% "Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images"
%
% EXP07 (REVISED):
%   ORO estimation/completeness -> MC-LFM FrFT/CLEAN refocusing quality.
%
% Why revised:
%   The preliminary EXP07 mixed Xu-2025 sequential CLEAN with an additional
%   0.7 inter-component stopping rule from Wang-2023. With component
%   amplitudes [1.00, 0.55, 0.28], that caused the loop to terminate after
%   the first component, so the intended multi-component test was not
%   actually being performed.
%
% Xu 2025 Sec. IV-C states that all LFM components can be sequentially
% refocused and accumulated after the ORO set is obtained. This revision
% therefore processes ALL supplied OROs.
%
% Main questions:
%   1) Does ORO bias degrade final refocusing concentration / entropy?
%   2) Does missing the weak ORO leave a measurable weak residual?
%   3) Does an Adaptive-like small ORO error stay close to the correct-set
%      refocusing quality, while a FixedSmall-like large tracking error does
%      not?
%
% Existing helpers reused:
%   papers/Wang2023_Fast_Accurate_FrFT/code/functions/frft_direct.m
%   papers/Wang2023_Fast_Accurate_FrFT/code/functions/signal_entropy.m
%
% Revised Xu helper:
%   code/functions/refocus_mc_lfm_clean.m
%
% MATLAB R2021b+ recommended. No toolbox required.

clear; clc; close all;

%% 0. Resolve project paths
this_file = mfilename('fullpath');
exp_code_dir = fileparts(this_file);
xu_code_dir = fileparts(exp_code_dir);
xu_paper_dir = fileparts(xu_code_dir);
papers_dir = fileparts(xu_paper_dir);

xu_functions_dir = fullfile(xu_code_dir, 'functions');

wang_functions_dir = fullfile( ...
    papers_dir, ...
    'Wang2023_Fast_Accurate_FrFT', ...
    'code', 'functions');

result_dir = fullfile( ...
    xu_paper_dir, ...
    'results', 'exp07_mc_lfm_clean_refocusing');

if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

addpath(xu_functions_dir);
addpath(wang_functions_dir);

required_functions = { ...
    'frft_direct', ...
    'signal_entropy', ...
    'refocus_mc_lfm_clean'};

for ii = 1:numel(required_functions)
    if exist(required_functions{ii}, 'file') ~= 2
        error('Required function not found: %s.m', required_functions{ii});
    end
end

fprintf('============================================================\n');
fprintf('EXP07 REVISED: ORO -> MC-LFM sequential refocusing quality\n');
fprintf('Xu paper folder     : %s\n', xu_paper_dir);
fprintf('Wang functions dir  : %s\n', wang_functions_dir);
fprintf('Results folder      : %s\n', result_dir);
fprintf('============================================================\n\n');

%% 1. Normalized FrFT coordinates: preserve prior project convention
N = 129;

eta_dummy = ((0:N-1) - (N-1)/2);
t_norm = eta_dummy / max(abs(eta_dummy)) * 4;
u_norm = t_norm;

w = 0.5 - 0.5*cos(2*pi*(0:N-1)/(N-1));

%% 2. Three-component MC-LFM line
% Keep a genuinely weak third component so the omission test is meaningful.
p_design = [0.72, 0.64, 0.82];
amp = [1.00, 0.55, 0.28];
freq_shift = [-0.45, 0.05, 0.52];

Q = numel(p_design);

components = zeros(Q, N);

for iq = 1:Q
    alpha = p_design(iq) * pi/2;

    % Concentration condition: cot(alpha) + DeltaK = 0.
    deltaK_norm = -cot(alpha);

    components(iq,:) = ...
        amp(iq) * w .* ...
        exp(1j*pi*deltaK_norm*(t_norm.^2) + ...
            1j*2*pi*freq_shift(iq)*t_norm);
end

%% 3. Empirical ORO calibration with the validated project FrFT convention
p_coarse = 0.10 : 0.01 : 1.90;
fine_half = 0.02;
fine_step = 0.001;

p_cal = zeros(1,Q);
entropy_curves = zeros(numel(p_coarse), Q);

for iq = 1:Q

    xq = components(iq,:);

    Hc = zeros(size(p_coarse));

    for ip = 1:numel(p_coarse)
        Xp = frft_direct(xq, t_norm, p_coarse(ip), u_norm);
        Hc(ip) = signal_entropy(Xp);
    end

    entropy_curves(:,iq) = Hc(:);

    [~,idx0] = min(Hc);
    p0 = p_coarse(idx0);

    p_fine = max(0.02,p0-fine_half) : fine_step : min(1.98,p0+fine_half);
    Hf = zeros(size(p_fine));

    for ip = 1:numel(p_fine)
        Xp = frft_direct(xq, t_norm, p_fine(ip), u_norm);
        Hf(ip) = signal_entropy(Xp);
    end

    [~,idxf] = min(Hf);
    p_cal(iq) = p_fine(idxf);
end

T_cal = table( ...
    (1:Q).', ...
    amp.', ...
    p_design.', ...
    p_cal.', ...
    (p_cal-p_design).', ...
    'VariableNames', { ...
    'Component','Amplitude','DesignedORO', ...
    'CalibratedORO','CalibrationError'});

disp(' ');
disp('================ EXP07 ORO CALIBRATION ================');
disp(T_cal);

%% 4. Noisy MC-LFM signal
rng(42,'twister');

x_clean = sum(components,1);

snr_db = 24;

sig_power = mean(abs(x_clean).^2);
noise_power = sig_power / 10^(snr_db/10);

noise = sqrt(noise_power/2) * ...
    (randn(1,N)+1j*randn(1,N));

x_mc = x_clean + noise;

%% 5. Controlled extraction parameters
% Xu 2025 does not report exact discrete bandpass-window width.
win_half = 2;

% Retained only as a controlled peak-selection parameter.
peak_ratio = 0.70;

%% 6. Correct complete ORO set
[y_correct, residual_correct, info_correct] = ...
    refocus_mc_lfm_clean( ...
    x_mc, t_norm, u_norm, p_cal, ...
    win_half, peak_ratio);

%% 7. ORO-bias sweep
bias_list = [0, 0.0025, 0.005, 0.010, 0.020, ...
             0.030, 0.040, 0.050, 0.060];

n_bias = numel(bias_list);

entropy_bias = zeros(1,n_bias);
concentration_bias = zeros(1,n_bias);
residual_ratio_bias = zeros(1,n_bias);
orders_used_bias = zeros(1,n_bias);

for ib = 1:n_bias

    p_use = p_cal + bias_list(ib);

    [y_tmp, ~, info_tmp] = ...
        refocus_mc_lfm_clean( ...
        x_mc, t_norm, u_norm, p_use, ...
        win_half, peak_ratio);

    entropy_bias(ib) = signal_entropy(y_tmp);

    power_tmp = abs(y_tmp).^2;
    concentration_bias(ib) = ...
        max(power_tmp) / max(sum(power_tmp),eps);

    residual_ratio_bias(ib) = info_tmp.residual_energy_ratio;
    orders_used_bias(ib) = info_tmp.n_order_used;
end

T_bias = table( ...
    bias_list.', ...
    entropy_bias.', ...
    concentration_bias.', ...
    residual_ratio_bias.', ...
    orders_used_bias.', ...
    'VariableNames', { ...
    'CommonOROBias', ...
    'RefocusedEntropy', ...
    'PeakConcentration', ...
    'ResidualEnergyRatio', ...
    'OrdersUsed'});

%% 8. Component-completeness tests
% Complete set.
[y_complete, residual_complete, info_complete] = ...
    refocus_mc_lfm_clean( ...
    x_mc, t_norm, u_norm, p_cal, ...
    win_half, peak_ratio);

% Deliberately omit the weak third ORO.
[y_omit_weak, residual_omit_weak, info_omit_weak] = ...
    refocus_mc_lfm_clean( ...
    x_mc, t_norm, u_norm, p_cal(1:2), ...
    win_half, peak_ratio);

% Process only the strongest ORO.
[y_only_strong, residual_only_strong, info_only_strong] = ...
    refocus_mc_lfm_clean( ...
    x_mc, t_norm, u_norm, p_cal(1), ...
    win_half, peak_ratio);

%% 9. Weak-component residual correlation
weak_component = components(3,:);

weak_corr_complete = normalized_complex_correlation( ...
    residual_complete, weak_component);

weak_corr_omit = normalized_complex_correlation( ...
    residual_omit_weak, weak_component);

weak_corr_only_strong = normalized_complex_correlation( ...
    residual_only_strong, weak_component);

%% 10. EXP06-inspired strategy comparison
fixedsmall_bias = 0.050;
adaptive_bias = 0.001;

[y_fixedsmall, residual_fixedsmall, info_fixedsmall] = ...
    refocus_mc_lfm_clean( ...
    x_mc, t_norm, u_norm, p_cal + fixedsmall_bias, ...
    win_half, peak_ratio);

[y_adaptive, residual_adaptive, info_adaptive] = ...
    refocus_mc_lfm_clean( ...
    x_mc, t_norm, u_norm, p_cal + adaptive_bias, ...
    win_half, peak_ratio);

strategy_names = [ ...
    "OriginalMC-LFM"; ...
    "CorrectOROSet"; ...
    "FixedSmallLike"; ...
    "AdaptiveLike"; ...
    "WeakOROOmitted"; ...
    "OnlyStrongORO"];

Y = { ...
    x_mc, ...
    y_correct, ...
    y_fixedsmall, ...
    y_adaptive, ...
    y_omit_weak, ...
    y_only_strong};

R = { ...
    [], ...
    residual_correct, ...
    residual_fixedsmall, ...
    residual_adaptive, ...
    residual_omit_weak, ...
    residual_only_strong};

I = { ...
    [], ...
    info_correct, ...
    info_fixedsmall, ...
    info_adaptive, ...
    info_omit_weak, ...
    info_only_strong};

n_strategy = numel(strategy_names);

entropy_strategy = zeros(n_strategy,1);
concentration_strategy = zeros(n_strategy,1);
residual_ratio_strategy = nan(n_strategy,1);
orders_used_strategy = nan(n_strategy,1);
weak_corr_strategy = nan(n_strategy,1);

for is = 1:n_strategy

    ys = Y{is};

    entropy_strategy(is) = signal_entropy(ys);

    ps = abs(ys).^2;
    concentration_strategy(is) = ...
        max(ps) / max(sum(ps),eps);

    if is > 1
        residual_ratio_strategy(is) = I{is}.residual_energy_ratio;
        orders_used_strategy(is) = I{is}.n_order_used;

        weak_corr_strategy(is) = ...
            normalized_complex_correlation(R{is}, weak_component);
    end
end

T_strategy = table( ...
    strategy_names, ...
    entropy_strategy, ...
    concentration_strategy, ...
    residual_ratio_strategy, ...
    orders_used_strategy, ...
    weak_corr_strategy, ...
    'VariableNames', { ...
    'Strategy', ...
    'Entropy', ...
    'PeakConcentration', ...
    'ResidualEnergyRatio', ...
    'OrdersUsed', ...
    'WeakResidualCorrelation'});

disp(' ');
disp('================ EXP07 BIAS SWEEP ================');
disp(T_bias);

disp(' ');
disp('================ EXP07 STRATEGY COMPARISON ================');
disp(T_strategy);

fprintf('\n================ EXP07 REVISED INTERPRETATION ================\n');
fprintf('SNR                      = %.1f dB\n', snr_db);
fprintf('Peak threshold           = %.2f * current FrFT max\n', peak_ratio);
fprintf('Window half width        = %d samples\n', win_half);
fprintf('Calibrated ORO set       = ');
fprintf('%.4f ', p_cal);
fprintf('\n\n');

fprintf('Correct-set orders used  = %d\n', info_correct.n_order_used);
fprintf('Weak-omitted orders used = %d\n', info_omit_weak.n_order_used);
fprintf('Only-strong orders used  = %d\n', info_only_strong.n_order_used);
fprintf('\n');

fprintf('Weak residual correlation:\n');
fprintf('  Complete ORO set       = %.6f\n', weak_corr_complete);
fprintf('  Weak ORO omitted       = %.6f\n', weak_corr_omit);
fprintf('  Only strong ORO        = %.6f\n', weak_corr_only_strong);
fprintf('\n');

fprintf(['Interpretation target:\n' ...
    '  (1) OrdersUsed should now stay fixed at three during the bias sweep.\n' ...
    '  (2) This removes the previous control-flow confound where bias=0.04\n' ...
    '      unexpectedly processed an extra component.\n' ...
    '  (3) Weak-ORO omission should now leave more residual energy and/or\n' ...
    '      stronger correlation with the original weak component.\n' ...
    '  (4) Adaptive-like quality should remain near CorrectOROSet, whereas\n' ...
    '      FixedSmall-like quality should degrade under large ORO bias.\n']);

%% 11. Figure 1: calibration curves
fig1 = figure('Name','exp07 Revised ORO calibration','Color','w');

hold on;

for iq = 1:Q
    plot(p_coarse, entropy_curves(:,iq), 'LineWidth',1.2);
    xline(p_cal(iq), '--', sprintf('P%d=%.3f',iq,p_cal(iq)), ...
        'LineWidth',0.8);
end

xlabel('FrFT rotation order p');
ylabel('Signal entropy');
title('Isolated LFM component ORO calibration');
legend('Component 1','Component 2','Component 3','Location','best');
grid on;

%% 12. Figure 2: isolated focusing
fig2 = figure('Name','exp07 Revised isolated focusing','Color','w');

tiledlayout(1,Q,'Padding','compact','TileSpacing','compact');

for iq = 1:Q
    nexttile;

    Xp = frft_direct(components(iq,:), t_norm, p_cal(iq), u_norm);
    mag = abs(Xp);
    mag = mag / max(mag);

    plot(u_norm, mag, 'LineWidth',1.2);

    xlabel('Fractional coordinate u');
    ylabel('Normalized magnitude');
    title(sprintf('Component %d, p=%.3f',iq,p_cal(iq)));
    grid on;
end

%% 13. Figure 3: complete vs omission
fig3 = figure('Name','exp07 Revised completeness comparison','Color','w');

tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

Y_comp = {y_complete, y_omit_weak, y_only_strong};
labels_comp = {'Complete ORO set','Weak ORO omitted','Only strongest ORO'};

for is = 1:3
    nexttile;

    yy = abs(Y_comp{is});
    yy = yy / max(yy);

    plot(u_norm, yy, 'LineWidth',1.2);

    xlabel('Fractional coordinate');
    ylabel('Normalized magnitude');
    title(labels_comp{is});
    grid on;
end

%% 14. Figure 4: entropy vs ORO bias
fig4 = figure('Name','exp07 Revised entropy vs bias','Color','w');

plot(bias_list, entropy_bias, 'o-', 'LineWidth',1.2);

xlabel('Common ORO bias');
ylabel('Refocused signal entropy');
title('ORO estimation error -> refocusing entropy');
grid on;

%% 15. Figure 5: concentration vs ORO bias
fig5 = figure('Name','exp07 Revised concentration vs bias','Color','w');

plot(bias_list, concentration_bias, 'o-', 'LineWidth',1.2);

xlabel('Common ORO bias');
ylabel('Peak concentration');
title('ORO estimation error -> FrFT concentration');
grid on;

%% 16. Figure 6: residual energy vs ORO bias
fig6 = figure('Name','exp07 Revised residual energy vs bias','Color','w');

plot(bias_list, residual_ratio_bias, 'o-', 'LineWidth',1.2);

xlabel('Common ORO bias');
ylabel('Residual / original energy ratio');
title('ORO estimation error -> residual MC-LFM energy');
grid on;

%% 17. Figure 7: strategy entropy
fig7 = figure('Name','exp07 Revised strategy entropy','Color','w');

bar(entropy_strategy);

set(gca,'XTick',1:n_strategy, ...
    'XTickLabel',strategy_names);

xtickangle(20);
ylabel('Entropy');
title('ORO quality/completeness -> refocusing entropy');
grid on;

%% 18. Figure 8: strategy residual energy
fig8 = figure('Name','exp07 Revised strategy residual','Color','w');

bar(residual_ratio_strategy(2:end));

set(gca,'XTick',1:(n_strategy-1), ...
    'XTickLabel',strategy_names(2:end));

xtickangle(20);
ylabel('Residual / original energy ratio');
title('ORO quality/completeness -> residual energy');
grid on;

%% 19. Figure 9: weak-component residual correlation
fig9 = figure('Name','exp07 Weak residual correlation','Color','w');

bar([weak_corr_complete, weak_corr_omit, weak_corr_only_strong]);

set(gca,'XTick',1:3, ...
    'XTickLabel',{'Complete','Weak omitted','Only strong'});

ylabel('Normalized correlation with weak component');
title('Does weak-ORO omission leave the weak LFM component behind?');
grid on;

%% 20. Save outputs
writetable(T_cal, ...
    fullfile(result_dir,'exp07_oro_calibration.csv'));

writetable(T_bias, ...
    fullfile(result_dir,'exp07_bias_sweep.csv'));

writetable(T_strategy, ...
    fullfile(result_dir,'exp07_strategy_summary.csv'));

save(fullfile(result_dir,'exp07_summary.mat'), ...
    'p_design','p_cal','amp','freq_shift', ...
    'components','x_mc','snr_db', ...
    'bias_list','entropy_bias','concentration_bias', ...
    'residual_ratio_bias','orders_used_bias', ...
    'fixedsmall_bias','adaptive_bias', ...
    'entropy_strategy','concentration_strategy', ...
    'residual_ratio_strategy','orders_used_strategy', ...
    'weak_corr_strategy', ...
    'weak_corr_complete','weak_corr_omit', ...
    'weak_corr_only_strong', ...
    'peak_ratio','win_half','N','t_norm','u_norm');

exportgraphics(fig1, ...
    fullfile(result_dir,'fig01_oro_calibration.png'), ...
    'Resolution',200);

exportgraphics(fig2, ...
    fullfile(result_dir,'fig02_isolated_component_focusing.png'), ...
    'Resolution',200);

exportgraphics(fig3, ...
    fullfile(result_dir,'fig03_component_completeness.png'), ...
    'Resolution',200);

exportgraphics(fig4, ...
    fullfile(result_dir,'fig04_entropy_vs_oro_bias.png'), ...
    'Resolution',200);

exportgraphics(fig5, ...
    fullfile(result_dir,'fig05_concentration_vs_oro_bias.png'), ...
    'Resolution',200);

exportgraphics(fig6, ...
    fullfile(result_dir,'fig06_residual_energy_vs_oro_bias.png'), ...
    'Resolution',200);

exportgraphics(fig7, ...
    fullfile(result_dir,'fig07_strategy_entropy_comparison.png'), ...
    'Resolution',200);

exportgraphics(fig8, ...
    fullfile(result_dir,'fig08_strategy_residual_energy.png'), ...
    'Resolution',200);

exportgraphics(fig9, ...
    fullfile(result_dir,'fig09_weak_residual_correlation.png'), ...
    'Resolution',200);

fprintf('\nOutputs saved to:\n%s\n',result_dir);

%% Local function
function c = normalized_complex_correlation(x, y)

x = x(:);
y = y(:);

den = sqrt(sum(abs(x).^2) * sum(abs(y).^2));

if den <= eps
    c = 0;
else
    c = abs(sum(conj(y).*x)) / den;
end

end
