%% run_exp02_fair_r0_positive_control.m
% EXP02-FAIR-R0-POSCTRL
% Positive control for the FAIR-CSAR fractional-domain diagnostic.
%
% Purpose:
%   Before interpreting the real FAIR-CSAR Candidate B as being outside the
%   Wang/Xu MC-LFM regime, verify that the exact same R0 diagnostic can
%   recover known fractional-order structure from synthetic LFM / MC-LFM
%   signals generated with the project's validated FrFT convention.
%
% IMPORTANT:
%   - This does NOT touch the real-data branch pipeline.
%   - No G0 / Neighbor-3 / Proposed.
%   - No tuning from FAIR-CSAR outcomes.
%   - The p-grid comes directly from the frozen FAIR-R0 config.
%   - The corrected diagnostic uses Xu Eq.(31) TOTAL FrAc energy; the
%     legacy zero-lag exclusion argument is retained only for API compatibility
%     and is intentionally ignored by fair_csar_fractional_line_audit.m.

clear; clc; close all;

%% 0. Resolve repository paths
this_file = mfilename('fullpath');
fair_code_dir = fileparts(this_file);
exp02_code_dir = fileparts(fair_code_dir);
code_dir = fileparts(exp02_code_dir);
research_dir = fileparts(code_dir);
research_parent = fileparts(research_dir);
repo_root = fileparts(research_parent);

addpath(genpath(fullfile(research_dir,'functions')));
addpath(genpath(fullfile(repo_root,'papers')));

if exist('frft_direct','file') ~= 2
    error('Validated frft_direct.m is not available on the MATLAB path.');
end

cfg = config_exp02_fair_r0();

result_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r0_positive_control');

if ~exist(result_dir,'dir')
    mkdir(result_dir);
end

fprintf('============================================================\n');
fprintf('EXP02-FAIR-R0 POSITIVE CONTROL\n');
fprintf('Same diagnostic / same p-grid as real FAIR-R0\n');
fprintf('============================================================\n\n');

%% 1. Synthetic coordinates: match real Candidate-B audited line length
% Real frozen crop length was 310 azimuth samples.
N = 310;

eta = (0:N-1) - (N-1)/2;
t_norm = eta / max(abs(eta)) * 4;

% Preserve the finite-support convention already used in the validated
% Xu/Wang reproduction line.
w = 0.5 - 0.5*cos(2*pi*(0:N-1)/(N-1));

%% 2. Known LFM components
% These are the same design-order family used in the validated Xu EXP07
% reproduction line.
p_oro = [0.72, 0.64, 0.82];
amp = [1.00, 0.55, 0.28];
freq_shift = [-0.45, 0.05, 0.52];

Q = numel(p_oro);
components = zeros(Q,N);

for iq = 1:Q
    alpha = p_oro(iq) * pi/2;

    % Project convention:
    % concentration condition cot(alpha) + DeltaK = 0.
    deltaK_norm = -cot(alpha);

    components(iq,:) = ...
        amp(iq) * w .* ...
        exp(1j*pi*deltaK_norm*(t_norm.^2) + ...
            1j*2*pi*freq_shift(iq)*t_norm);
end

% For the Eq.(26)-style FrAc parameter beta:
%   alpha_ORO = beta + pi/2
% therefore, in order units:
%   p_beta = p_ORO - 1 (modulo 2 for line orientation).
p_beta_expected = mod(p_oro - 1, 2);

%% 3. Fixed noise realization
rng(42,'twister');
snr_db = 24;

single_clean = components(1,:);
single_noisy = add_fixed_awgn(single_clean,snr_db);

mc_clean = sum(components,1);
mc_noisy = add_fixed_awgn(mc_clean,snr_db);

%% 4. Run EXACT SAME FAIR-R0 diagnostic
single = fair_csar_fractional_line_audit( ...
    single_noisy,cfg.p_grid,cfg.frac_exclude_zero_lags);

mc = fair_csar_fractional_line_audit( ...
    mc_noisy,cfg.p_grid,cfg.frac_exclude_zero_lags);

% Also audit each isolated component to verify parameter mapping.
% IMPORTANT:
%   Do NOT preallocate with repmat(struct(),...) because assigning a
%   populated struct into a no-field struct array causes MATLAB's
%   "subscripted assignment between dissimilar structures" error.
isolated = struct([]);

for iq = 1:Q
    xi = add_fixed_awgn(components(iq,:),snr_db);

    ai = fair_csar_fractional_line_audit( ...
        xi,cfg.p_grid,cfg.frac_exclude_zero_lags);

    if iq == 1
        isolated = repmat(ai,1,Q);
    else
        isolated(iq) = ai;
    end
end

%% 5. Expected-order errors
single_expected = p_beta_expected(1);
single_error = circular_order_distance(single.best_frac_order,single_expected);

isolated_best = zeros(1,Q);
isolated_err = zeros(1,Q);

for iq = 1:Q
    isolated_best(iq) = isolated(iq).best_frac_order;
    isolated_err(iq) = circular_order_distance( ...
        isolated_best(iq),p_beta_expected(iq));
end

% Top local peaks for combined MC-LFM.
[top_p,top_score] = top_local_peaks( ...
    cfg.p_grid,mc.frac_score,6);

%% 6. Figure 1: isolated/single calibration
fig1 = figure('Color','w','Name','FAIR R0 positive control - isolated LFM');
tiledlayout(Q,1,'Padding','compact','TileSpacing','compact');

for iq = 1:Q
    nexttile;
    plot(cfg.p_grid,isolated(iq).frac_score,'LineWidth',1.2);
    hold on;
    xline(p_beta_expected(iq),'--', ...
        sprintf('expected %.2f',p_beta_expected(iq)), ...
        'LineWidth',0.9);
    xline(isolated_best(iq),':', ...
        sprintf('observed %.2f',isolated_best(iq)), ...
        'LineWidth',0.9);
    hold off;
    xlabel('FrAc angle/order parameter \beta (order units)');
    ylabel('Normalized Eq.(31) FrAc energy');
    title(sprintf('Isolated LFM %d | ORO=%.2f | error=%.3f', ...
        iq,p_oro(iq),isolated_err(iq)));
    grid on;
end

exportgraphics(fig1, ...
    fullfile(result_dir,'01_isolated_lfm_positive_control.png'), ...
    'Resolution',cfg.figure_resolution);

%% 7. Figure 2: combined MC-LFM
fig2 = figure('Color','w','Name','FAIR R0 positive control - MC-LFM');
plot(cfg.p_grid,mc.frac_score,'LineWidth',1.3);
hold on;

for iq = 1:Q
    xline(p_beta_expected(iq),'--', ...
        sprintf('\\beta_%d=%.2f',iq,p_beta_expected(iq)), ...
        'LineWidth',0.8);
end

hold off;
xlabel('FrAc angle/order parameter \beta (order units)');
ylabel('Normalized Eq.(31) FrAc energy');
title('Known 3-component MC-LFM under the exact FAIR-R0 diagnostic');
grid on;

exportgraphics(fig2, ...
    fullfile(result_dir,'02_mc_lfm_positive_control.png'), ...
    'Resolution',cfg.figure_resolution);

%% 8. Feedback bundle
txt_path = fullfile(result_dir,'EXP02_FAIR_R0_POSCTRL_FEEDBACK.txt');
fid = fopen(txt_path,'w');

if fid < 0
    error('Cannot open feedback bundle for writing.');
end

cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-R0 POSITIVE CONTROL\n');
fprintf(fid,'==============================================\n');
fprintf(fid,'Purpose: validate the exact FAIR-R0 diagnostic on known LFM/MC-LFM signals\n');
fprintf(fid,'Real FAIR-CSAR data used: NO\n');
fprintf(fid,'G0/N3/Proposed used: NO\n\n');

fprintf(fid,'[FROZEN SETTINGS]\n');
fprintf(fid,'N=%d\n',N);
fprintf(fid,'snr_db=%.3f\n',snr_db);
fprintf(fid,'p_grid_min=%.6f\n',min(cfg.p_grid));
fprintf(fid,'p_grid_max=%.6f\n',max(cfg.p_grid));
fprintf(fid,'p_grid_step=%.6f\n',cfg.p_grid(2)-cfg.p_grid(1));
fprintf(fid,'frac_metric=Eq31_total_energy_normalized\n');
fprintf(fid,'zero_lag_exclusion_used=0\n\n');

fprintf(fid,'[DESIGNED COMPONENTS]\n');

for iq = 1:Q
    fprintf(fid,['component_%d: ORO=%.6f expected_beta=%.6f ' ...
        'observed_best_beta=%.6f circular_error=%.6f ' ...
        'peak=%.9g prominence=%.9g\n'], ...
        iq,p_oro(iq),p_beta_expected(iq),isolated_best(iq), ...
        isolated_err(iq),isolated(iq).frac_peak, ...
        isolated(iq).frac_peak_to_median);
end

fprintf(fid,'\n[SINGLE-LFM CHECK]\n');
fprintf(fid,'expected_beta=%.6f\n',single_expected);
fprintf(fid,'observed_best_beta=%.6f\n',single.best_frac_order);
fprintf(fid,'circular_error=%.6f\n',single_error);
fprintf(fid,'frac_peak=%.9g\n',single.frac_peak);
fprintf(fid,'frac_peak_to_median=%.9g\n\n',single.frac_peak_to_median);

fprintf(fid,'[COMBINED MC-LFM TOP LOCAL PEAKS]\n');

for k = 1:numel(top_p)
    fprintf(fid,'rank_%d: beta=%.6f score=%.9g\n', ...
        k,top_p(k),top_score(k));
end

fprintf(fid,'\n[INTERPRETATION]\n');
fprintf(fid,['If isolated known LFM components peak near their analytically ' ...
    'expected beta orders, the FAIR-R0 diagnostic has a valid positive ' ...
    'control for order selectivity.\n']);
fprintf(fid,['If this positive control fails, do not interpret Candidate B as ' ...
    'evidence against the MC-LFM model; repair the diagnostic first.\n']);

fprintf('\nPositive control complete.\n');
fprintf('Feedback: %s\n',txt_path);

%% Local helpers
function y = add_fixed_awgn(x,snr_db)

sig_power = mean(abs(x).^2);
noise_power = sig_power / 10^(snr_db/10);

noise = sqrt(noise_power/2) * ...
    (randn(size(x)) + 1j*randn(size(x)));

y = x + noise;

end

function d = circular_order_distance(a,b)
% FrAc line orientation is pi-periodic -> order period 2.

raw = abs(a-b);
d = min(raw,2-raw);

end

function [p_out,s_out] = top_local_peaks(p,y,K)

y = y(:).';
N = numel(y);

is_peak = false(1,N);

if N == 1
    is_peak(1) = true;
else
    is_peak(1) = y(1) >= y(2);
    is_peak(N) = y(N) >= y(N-1);

    for i = 2:N-1
        is_peak(i) = ...
            (y(i) >= y(i-1)) && ...
            (y(i) >= y(i+1));
    end
end

idx = find(is_peak);

[~,ord] = sort(y(idx),'descend');
idx = idx(ord);

K = min(K,numel(idx));
idx = idx(1:K);

p_out = p(idx);
s_out = y(idx);

end
