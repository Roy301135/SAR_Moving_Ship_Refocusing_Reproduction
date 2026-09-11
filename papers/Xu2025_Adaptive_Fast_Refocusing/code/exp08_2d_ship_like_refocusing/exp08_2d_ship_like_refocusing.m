%% exp08_2d_ship_like_refocusing.m
% Xu et al., JSTARS 2025
% "Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images"
%
% EXP08 REVISED:
%   2-D ship-like MC-LFM refocusing with SEQUENTIAL FrAc-CLEAN ORO search.
%
% Why revised:
%   The preliminary EXP08 attempted to select three ORO peaks from ONE FrAc
%   spectrum of the original MC-LFM line. The run showed:
%
%       ComponentRecall      ~ 0.06
%       WeakComponentRecall  = 0
%
%   even for Full search.
%
%   That means the experiment had not actually reproduced the intended
%   multi-component CLEAN mechanism. The strong LFM component dominated the
%   FrAc spectrum and buried the medium/weak components.
%
% Correct mechanism used here:
%
%   residual_0
%      -> FrAc search strongest ORO q1
%      -> FrFT/CLEAN peel component 1
%   residual_1
%      -> FrAc search q2
%      -> FrFT/CLEAN peel component 2
%   residual_2
%      -> FrAc search q3
%      -> FrFT/CLEAN peel component 3
%
% This is the central correction.
%
% Strategy comparison:
%   Full:
%       global FrAc search at EVERY CLEAN stage and every line.
%
%   FixedSmall:
%       dominant q1 tracked with Delta=0.01;
%       q2/q3 searched sequentially in an ORI around q1.
%
%   FixedWide:
%       dominant q1 tracked with Delta=0.08;
%       q2/q3 searched sequentially in the same ORI.
%
%   Adaptive:
%       dominant q1 uses boundary-aware
%           0.01 -> 0.02 -> 0.04 -> 0.08 -> full fallback;
%       q2/q3 searched sequentially in the ORI around the accepted q1.
%
% Important:
%   Delta tracks the DOMINANT ORO center only.
%   ORI resolves the remaining MC-LFM components around that center.
%
% STATUS:
%   Controlled mechanism-level 2-D proof-of-concept.
%
% Shared helpers:
%   Wang2023_Fast_Accurate_FrFT/code/functions/
%       frft_direct.m
%       signal_entropy.m
%
%   Xu2025_Adaptive_Fast_Refocusing/code/functions/
%       compute_frac_energy_map_continuous.m
%       extract_one_lfm_component.m
%
% MATLAB R2021b+ recommended. No toolbox required.

clear; clc; close all;

%% 0. Resolve project paths
this_file = mfilename('fullpath');
exp_code_dir = fileparts(this_file);
xu_code_dir = fileparts(exp_code_dir);
xu_paper_dir = fileparts(xu_code_dir);
papers_dir = fileparts(xu_paper_dir);

xu_functions_dir = fullfile(xu_code_dir,'functions');

wang_functions_dir = fullfile( ...
    papers_dir, ...
    'Wang2023_Fast_Accurate_FrFT', ...
    'code','functions');

result_dir = fullfile( ...
    xu_paper_dir, ...
    'results','exp08_2d_ship_like_refocusing');

if ~exist(result_dir,'dir')
    mkdir(result_dir);
end

addpath(xu_functions_dir);
addpath(wang_functions_dir);

required_functions = { ...
    'frft_direct', ...
    'signal_entropy', ...
    'compute_frac_energy_map_continuous', ...
    'extract_one_lfm_component'};

for ii = 1:numel(required_functions)
    if exist(required_functions{ii},'file') ~= 2
        error('Required function not found: %s.m',required_functions{ii});
    end
end

fprintf('============================================================\n');
fprintf('EXP08 REVISED: 2-D sequential FrAc-CLEAN refocusing\n');
fprintf('Xu paper folder    : %s\n',xu_paper_dir);
fprintf('Results folder     : %s\n',result_dir);
fprintf('============================================================\n\n');

%% 1. Coordinate / scene setup
N = 129;
N_line = 81;
Q = 3;

eta = ((0:N-1) - (N-1)/2);
t_norm = eta / max(abs(eta)) * 4;
u_norm = t_norm;

line_idx = 1:N_line;
x = linspace(-1,1,N_line);

w_t = 0.5 - 0.5*cos(2*pi*(0:N-1)/(N-1));

ship_env = exp(-(abs(x)/0.92).^8);
ship_env = ship_env / max(ship_env);

%% 2. True multi-component ORO field
q_dom = -0.280 ...
      + 0.035*sin(0.85*pi*x) ...
      + 0.012*x;

jump_idx = 61;
jump_amp = 0.060;

q_dom(jump_idx:end) = q_dom(jump_idx:end) + jump_amp;

q_offsets = [0.000, -0.080, +0.100];

q_true = zeros(Q,N_line);

for iq = 1:Q
    q_true(iq,:) = q_dom + q_offsets(iq);
end

p_true = q_true + 1;

%% 3. Component amplitudes and focused locations
A = zeros(Q,N_line);

A(1,:) = 1.00 * ship_env .* ...
    (0.88 + 0.12*cos(0.7*pi*x));

A(2,:) = 0.62 * ship_env .* ...
    (0.82 + 0.18*sin(1.1*pi*x + 0.4).^2);

A(3,:) = 0.36 * ship_env .* ...
    (0.72 + 0.28*cos(1.5*pi*x - 0.3).^2);

weak_half_width = 2;
weak_factor = 0.35;

weak_cells = max(1,jump_idx-weak_half_width) : ...
             min(N_line,jump_idx+weak_half_width);

A(:,weak_cells) = A(:,weak_cells) * weak_factor;

freq_shift = zeros(Q,N_line);

freq_shift(1,:) = -0.42 + 0.08*x;
freq_shift(2,:) =  0.02 + 0.05*sin(pi*x);
freq_shift(3,:) = +0.44 - 0.07*x;

%% 4. Generate defocused 2-D MC-LFM data
rng(42,'twister');

X_clean = zeros(N,N_line);
components = zeros(N,N_line,Q);

for iline = 1:N_line
    for iq = 1:Q

        alpha_q = q_true(iq,iline) * pi/2;
        chirp_rate = tan(alpha_q);

        s = A(iq,iline) * w_t .* ...
            exp(1j*pi*chirp_rate*(t_norm.^2) + ...
                1j*2*pi*freq_shift(iq,iline)*t_norm);

        components(:,iline,iq) = s(:);
        X_clean(:,iline) = X_clean(:,iline) + s(:);
    end
end

snr_center_db = 22;

sig_power = mean(abs(X_clean(:)).^2);
noise_power = sig_power / 10^(snr_center_db/10);

noise = sqrt(noise_power/2) * ...
    (randn(size(X_clean)) + 1j*randn(size(X_clean)));

X = X_clean + noise;

line_energy = sum(abs(X).^2,1);
[~,init_idx] = max(line_energy);

%% 5. Search / CLEAN controls
search_step = 0.0025;

q_full = -0.45 : search_step : -0.05;

delta_small = 0.010;
delta_wide = 0.080;
delta_levels = [0.010, 0.020, 0.040, 0.080];

% ORI around dominant q1.
ori_low_offset = -0.100;
ori_high_offset = +0.120;

max_lag = 16;

win_half = 2;
peak_ratio = 0.70;

% Exclude already extracted ORO neighborhoods at later CLEAN stages.
min_stage_sep = 0.025;

% Finite-data matching tolerance: 5 FrAc grid bins.
match_tol = 5 * search_step;

% Active target lines for a second, less background-sensitive recall metric.
active_mask = ship_env >= 0.30;

%% 6. Oracle refocusing with true OROs
Y_oracle = zeros(N,N_line);
R_oracle = zeros(N,N_line);

for iline = 1:N_line

    residual = X(:,iline);
    y_acc = zeros(N,1);

    for iq = 1:Q

        [G_focus,residual] = ...
            extract_one_lfm_component( ...
            residual, ...
            t_norm,u_norm, ...
            p_true(iq,iline), ...
            win_half,peak_ratio);

        y_acc = y_acc + G_focus(:);
    end

    Y_oracle(:,iline) = y_acc;
    R_oracle(:,iline) = residual(:);
end

%% 7. Run strategies
method_names = {'Full','FixedSmall','FixedWide','Adaptive'};
n_method = numel(method_names);

results = cell(1,n_method);

fprintf('Running Full sequential search...\n');
results{1} = run_strategy( ...
    'full', ...
    X,t_norm,u_norm, ...
    q_true,q_dom,init_idx, ...
    q_full,search_step, ...
    delta_small,delta_wide,delta_levels, ...
    ori_low_offset,ori_high_offset, ...
    max_lag,win_half,peak_ratio, ...
    min_stage_sep,match_tol);

fprintf('Running FixedSmall sequential search...\n');
results{2} = run_strategy( ...
    'fixedsmall', ...
    X,t_norm,u_norm, ...
    q_true,q_dom,init_idx, ...
    q_full,search_step, ...
    delta_small,delta_wide,delta_levels, ...
    ori_low_offset,ori_high_offset, ...
    max_lag,win_half,peak_ratio, ...
    min_stage_sep,match_tol);

fprintf('Running FixedWide sequential search...\n');
results{3} = run_strategy( ...
    'fixedwide', ...
    X,t_norm,u_norm, ...
    q_true,q_dom,init_idx, ...
    q_full,search_step, ...
    delta_small,delta_wide,delta_levels, ...
    ori_low_offset,ori_high_offset, ...
    max_lag,win_half,peak_ratio, ...
    min_stage_sep,match_tol);

fprintf('Running Adaptive sequential search...\n');
results{4} = run_strategy( ...
    'adaptive', ...
    X,t_norm,u_norm, ...
    q_true,q_dom,init_idx, ...
    q_full,search_step, ...
    delta_small,delta_wide,delta_levels, ...
    ori_low_offset,ori_high_offset, ...
    max_lag,win_half,peak_ratio, ...
    min_stage_sep,match_tol);

%% 8. Metrics
oracle_entropy = image_entropy_energy(Y_oracle);
oracle_residual_ratio = ...
    sum(abs(R_oracle(:)).^2) / max(sum(abs(X(:)).^2),eps);

FrAcEvaluations = zeros(n_method,1);
EvaluationReduction_pct = zeros(n_method,1);

DominantORO_RMSE = zeros(n_method,1);

ComponentRecall = zeros(n_method,1);
ActiveComponentRecall = zeros(n_method,1);

WeakComponentRecall = zeros(n_method,1);
ActiveWeakComponentRecall = zeros(n_method,1);

ImageEntropy = zeros(n_method,1);
ResidualEnergyRatio = zeros(n_method,1);
ImageSimilarityToOracle = zeros(n_method,1);

BoundaryHitRate_pct = zeros(n_method,1);
FullFallbackCount = zeros(n_method,1);

full_eval = results{1}.eval_count;

for im = 1:n_method

    rr = results{im};

    FrAcEvaluations(im) = rr.eval_count;

    EvaluationReduction_pct(im) = ...
        100*(1 - rr.eval_count/full_eval);

    DominantORO_RMSE(im) = ...
        sqrt(mean((rr.q_est(1,:) - q_dom).^2));

    ComponentRecall(im) = mean(rr.component_recall(:));

    ActiveComponentRecall(im) = ...
        mean(rr.component_recall(:,active_mask),'all');

    WeakComponentRecall(im) = ...
        mean(rr.component_recall(3,:));

    ActiveWeakComponentRecall(im) = ...
        mean(rr.component_recall(3,active_mask));

    ImageEntropy(im) = image_entropy_energy(rr.Y);

    ResidualEnergyRatio(im) = ...
        sum(abs(rr.R(:)).^2) / max(sum(abs(X(:)).^2),eps);

    ImageSimilarityToOracle(im) = ...
        magnitude_image_similarity(rr.Y,Y_oracle);

    BoundaryHitRate_pct(im) = ...
        100*mean(rr.boundary_hit);

    FullFallbackCount(im) = ...
        sum(rr.fallback_full);
end

T_summary = table( ...
    string(method_names(:)), ...
    FrAcEvaluations, ...
    EvaluationReduction_pct, ...
    DominantORO_RMSE, ...
    ComponentRecall, ...
    ActiveComponentRecall, ...
    WeakComponentRecall, ...
    ActiveWeakComponentRecall, ...
    ImageEntropy, ...
    ResidualEnergyRatio, ...
    ImageSimilarityToOracle, ...
    BoundaryHitRate_pct, ...
    FullFallbackCount, ...
    'VariableNames',{ ...
    'Method', ...
    'FrAcEvaluations', ...
    'EvaluationReduction_pct', ...
    'DominantORO_RMSE', ...
    'ComponentRecall', ...
    'ActiveComponentRecall', ...
    'WeakComponentRecall', ...
    'ActiveWeakComponentRecall', ...
    'ImageEntropy', ...
    'ResidualEnergyRatio', ...
    'ImageSimilarityToOracle', ...
    'BoundaryHitRate_pct', ...
    'FullFallbackCount'});

disp(' ');
disp('================ EXP08 REVISED SUMMARY ================');
disp(T_summary);

fprintf('\n================ EXP08 ORACLE REFERENCE ================\n');
fprintf('Oracle image entropy      = %.6f\n',oracle_entropy);
fprintf('Oracle residual ratio     = %.6f\n',oracle_residual_ratio);
fprintf('Strongest initialization  = line %d of %d\n',init_idx,N_line);
fprintf('Abrupt ORO jump           = %.3f at line %d\n',jump_amp,jump_idx);
fprintf('Active target lines       = %d / %d\n',sum(active_mask),N_line);
fprintf('Component match tolerance = %.4f\n',match_tol);
fprintf('\n');

for im = 1:n_method
    fprintf(['%-10s | Eval=%5d | EvalRed=%6.2f%% | DomRMSE=%8.5f | ' ...
             'Recall=%6.3f | ActiveRecall=%6.3f | Weak=%6.3f | ' ...
             'ActiveWeak=%6.3f | Resid=%7.4f | ImgSim=%6.3f\n'], ...
        method_names{im}, ...
        round(FrAcEvaluations(im)), ...
        EvaluationReduction_pct(im), ...
        DominantORO_RMSE(im), ...
        ComponentRecall(im), ...
        ActiveComponentRecall(im), ...
        WeakComponentRecall(im), ...
        ActiveWeakComponentRecall(im), ...
        ResidualEnergyRatio(im), ...
        ImageSimilarityToOracle(im));
end

fprintf('\n');
fprintf(['Interpretation target:\n' ...
    '  This revised experiment first verifies that sequential FrAc-CLEAN\n' ...
    '  actually recovers medium/weak OROs. Only after Full achieves\n' ...
    '  meaningful multi-component recall should the FixedSmall/Wide/\n' ...
    '  Adaptive quality-cost comparison be interpreted scientifically.\n']);

%% 9. Figure 1: input vs oracle
fig1 = figure('Name','exp08 Input vs oracle','Color','w');

tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
imagesc(line_idx,t_norm, ...
    20*log10(abs(X)/(max(abs(X(:)))+eps)+1e-6));
axis xy;
xlabel('Neighboring spatial / range cell');
ylabel('Normalized azimuth coordinate');
title('Synthetic defocused ship-like MC-LFM image');
colorbar;
caxis([-45 0]);

nexttile;
imagesc(line_idx,u_norm, ...
    20*log10(abs(Y_oracle)/(max(abs(Y_oracle(:)))+eps)+1e-6));
axis xy;
xlabel('Neighboring spatial / range cell');
ylabel('Fractional coordinate');
title('Oracle refocusing using true ORO sets');
colorbar;
caxis([-45 0]);

%% 10. Figure 2: strategy refocused images
fig2 = figure('Name','exp08 Strategy images','Color','w');

tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

for im = 1:n_method
    nexttile;

    Ytmp = results{im}.Y;

    imagesc(line_idx,u_norm, ...
        20*log10(abs(Ytmp)/(max(abs(Ytmp(:)))+eps)+1e-6));

    axis xy;
    xlabel('Neighboring spatial / range cell');
    ylabel('Fractional coordinate');
    title(method_names{im});
    colorbar;
    caxis([-45 0]);
end

%% 11. Figure 3: sequential ORO estimates for Full
fig3 = figure('Name','exp08 Full sequential ORO estimates','Color','w');

hold on;

for iq = 1:Q
    plot(line_idx,q_true(iq,:), ...
        'LineWidth',1.5);

    plot(line_idx,results{1}.q_est(iq,:), ...
        '--','LineWidth',1.0);
end

xline(jump_idx,'--','Jump','LineWidth',1.0);

xlabel('Neighboring spatial / range cell');
ylabel('FrAc order q');
title('Full sequential FrAc-CLEAN: true vs estimated OROs');

legend( ...
    'True q1','Full q1', ...
    'True q2','Full q2', ...
    'True q3','Full q3', ...
    'Location','best');

grid on;

%% 12. Figure 4: dominant ORO tracking
fig4 = figure('Name','exp08 Dominant tracking','Color','w');

plot(line_idx,q_dom,'LineWidth',1.6);
hold on;

for im = 1:n_method
    plot(line_idx,results{im}.q_est(1,:), ...
        'LineWidth',1.0);
end

xline(jump_idx,'--','Jump','LineWidth',1.0);

xlabel('Neighboring spatial / range cell');
ylabel('Dominant FrAc order q');
title('Dominant ORO tracking across the target');

legend(['True',method_names],'Location','best');
grid on;

%% 13. Figure 5: recovered component count
fig5 = figure('Name','exp08 Component count','Color','w');

hold on;

for im = 1:n_method
    count_line = sum(results{im}.component_recall,1);

    plot(line_idx,count_line,'o-', ...
        'LineWidth',1.0,'MarkerSize',3);
end

xline(jump_idx,'--','Jump','LineWidth',1.0);

xlabel('Neighboring spatial / range cell');
ylabel('Recovered true ORO components (0-3)');
title('Sequential MC-LFM component completeness by line');

legend(method_names,'Location','best');
ylim([-0.1,3.2]);
grid on;

%% 14. Figure 6: weak-component recovery
fig6 = figure('Name','exp08 Weak component recovery','Color','w');

hold on;

for im = 1:n_method
    stairs(line_idx,results{im}.component_recall(3,:), ...
        'LineWidth',1.2);
end

xline(jump_idx,'--','Jump','LineWidth',1.0);

xlabel('Neighboring spatial / range cell');
ylabel('Weak component recovered (0/1)');
title('Weak ORO recovery after sequential CLEAN');

legend(method_names,'Location','best');
ylim([-0.1,1.1]);
grid on;

%% 15. Figure 7: residual quality-cost
fig7 = figure('Name','exp08 Residual quality-cost','Color','w');

scatter(FrAcEvaluations,ResidualEnergyRatio,90,'o','LineWidth',1.3);
hold on;

for im = 1:n_method
    text(FrAcEvaluations(im),ResidualEnergyRatio(im), ...
        ['  ' method_names{im}]);
end

yline(oracle_residual_ratio,'--','Oracle residual','LineWidth',1.0);

xlabel('Sequential FrAc candidate-order evaluations');
ylabel('Residual / original energy ratio');
title('2-D sequential refocusing quality-cost plane');
grid on;

%% 16. Figure 8: image similarity quality-cost
fig8 = figure('Name','exp08 Similarity quality-cost','Color','w');

scatter(FrAcEvaluations,ImageSimilarityToOracle,90,'o','LineWidth',1.3);
hold on;

for im = 1:n_method
    text(FrAcEvaluations(im),ImageSimilarityToOracle(im), ...
        ['  ' method_names{im}]);
end

xlabel('Sequential FrAc candidate-order evaluations');
ylabel('Magnitude-image similarity to oracle');
title('2-D image fidelity vs sequential-search cost');
grid on;

%% 17. Figure 9: recall summary
fig9 = figure('Name','exp08 Recall summary','Color','w');

bar([ActiveComponentRecall,ActiveWeakComponentRecall]);

set(gca,'XTick',1:n_method,'XTickLabel',method_names);

ylabel('Recall on active ship lines');
title('Sequential ORO recovery: all vs weak component');

legend('All components','Weak component','Location','best');
ylim([0 1.05]);
grid on;

%% 18. Figure 10: image entropy
fig10 = figure('Name','exp08 Image entropy','Color','w');

bar(ImageEntropy);

set(gca,'XTick',1:n_method,'XTickLabel',method_names);

yline(oracle_entropy,'--','Oracle','LineWidth',1.0);

ylabel('2-D image entropy');
title('Image entropy (secondary metric)');
grid on;

%% 19. Save
writetable(T_summary, ...
    fullfile(result_dir,'exp08_summary.csv'));

save(fullfile(result_dir,'exp08_summary.mat'), ...
    'X','Y_oracle','R_oracle', ...
    'q_true','p_true','q_dom', ...
    'q_offsets','A','freq_shift', ...
    'jump_idx','jump_amp','init_idx', ...
    'active_mask','method_names','results', ...
    'FrAcEvaluations','EvaluationReduction_pct', ...
    'DominantORO_RMSE', ...
    'ComponentRecall','ActiveComponentRecall', ...
    'WeakComponentRecall','ActiveWeakComponentRecall', ...
    'ImageEntropy','ResidualEnergyRatio', ...
    'ImageSimilarityToOracle', ...
    'BoundaryHitRate_pct','FullFallbackCount', ...
    'oracle_entropy','oracle_residual_ratio', ...
    'q_full','search_step', ...
    'delta_small','delta_wide','delta_levels', ...
    'ori_low_offset','ori_high_offset', ...
    'win_half','peak_ratio','max_lag', ...
    'min_stage_sep','match_tol');

exportgraphics(fig1, ...
    fullfile(result_dir,'fig01_defocused_vs_oracle.png'), ...
    'Resolution',200);

exportgraphics(fig2, ...
    fullfile(result_dir,'fig02_refocused_strategy_images.png'), ...
    'Resolution',200);

exportgraphics(fig3, ...
    fullfile(result_dir,'fig03_full_sequential_oro_estimates.png'), ...
    'Resolution',200);

exportgraphics(fig4, ...
    fullfile(result_dir,'fig04_dominant_oro_tracking.png'), ...
    'Resolution',200);

exportgraphics(fig5, ...
    fullfile(result_dir,'fig05_component_recall_by_line.png'), ...
    'Resolution',200);

exportgraphics(fig6, ...
    fullfile(result_dir,'fig06_weak_component_recovery.png'), ...
    'Resolution',200);

exportgraphics(fig7, ...
    fullfile(result_dir,'fig07_residual_quality_cost.png'), ...
    'Resolution',200);

exportgraphics(fig8, ...
    fullfile(result_dir,'fig08_similarity_quality_cost.png'), ...
    'Resolution',200);

exportgraphics(fig9, ...
    fullfile(result_dir,'fig09_component_recall_summary.png'), ...
    'Resolution',200);

exportgraphics(fig10, ...
    fullfile(result_dir,'fig10_image_entropy.png'), ...
    'Resolution',200);

fprintf('\nOutputs saved to:\n%s\n',result_dir);

%% ========================================================================
% Local functions
% ========================================================================

function out = run_strategy( ...
    mode, ...
    X,t_norm,u_norm, ...
    q_true,q_dom_true,init_idx, ...
    q_full,search_step, ...
    delta_small,delta_wide,delta_levels, ...
    ori_low_offset,ori_high_offset, ...
    max_lag,win_half,peak_ratio, ...
    min_stage_sep,match_tol)

[N,N_line] = size(X);
Q = size(q_true,1);

out = struct();

out.Y = zeros(N,N_line);
out.R = zeros(N,N_line);

out.q_est = nan(Q,N_line);
out.component_recall = false(Q,N_line);

out.boundary_hit = false(1,N_line);
out.fallback_full = false(1,N_line);
out.delta_used = nan(1,N_line);

out.eval_count = 0;

if strcmpi(mode,'full')

    for iline = 1:N_line

        residual = X(:,iline);
        y_acc = zeros(N,1);

        q_prev = [];

        for istage = 1:Q

            [q_hat,add_eval] = ...
                search_residual_on_grid( ...
                residual,q_full,t_norm,max_lag, ...
                q_prev,min_stage_sep);

            out.eval_count = out.eval_count + add_eval;
            out.q_est(istage,iline) = q_hat;

            [G_focus,residual] = ...
                extract_one_lfm_component( ...
                residual,t_norm,u_norm,q_hat+1, ...
                win_half,peak_ratio);

            y_acc = y_acc + G_focus(:);

            q_prev(end+1) = q_hat; %#ok<AGROW>
        end

        out.Y(:,iline) = y_acc;
        out.R(:,iline) = residual;

        out.component_recall(:,iline) = ...
            match_true_components( ...
            out.q_est(:,iline).', ...
            q_true(:,iline).', ...
            match_tol);
    end

    return;
end

% ---------- Initialization line: sequential FULL CLEAN ----------
residual = X(:,init_idx);
y_acc = zeros(N,1);
q_prev = [];

for istage = 1:Q

    [q_hat,add_eval] = ...
        search_residual_on_grid( ...
        residual,q_full,t_norm,max_lag, ...
        q_prev,min_stage_sep);

    out.eval_count = out.eval_count + add_eval;
    out.q_est(istage,init_idx) = q_hat;

    [G_focus,residual] = ...
        extract_one_lfm_component( ...
        residual,t_norm,u_norm,q_hat+1, ...
        win_half,peak_ratio);

    y_acc = y_acc + G_focus(:);

    q_prev(end+1) = q_hat; %#ok<AGROW>
end

out.Y(:,init_idx) = y_acc;
out.R(:,init_idx) = residual;

out.component_recall(:,init_idx) = ...
    match_true_components( ...
    out.q_est(:,init_idx).', ...
    q_true(:,init_idx).', ...
    match_tol);

% ---------- Propagate right ----------
for iline = (init_idx+1):N_line

    prev_center = out.q_est(1,iline-1);

    [q1,add_eval,hit_any,used_delta,did_fallback] = ...
        track_dominant_stage( ...
        mode,X(:,iline),prev_center, ...
        q_full,search_step, ...
        delta_small,delta_wide,delta_levels, ...
        t_norm,max_lag);

    out.eval_count = out.eval_count + add_eval;

    out.q_est(1,iline) = q1;
    out.boundary_hit(iline) = hit_any;
    out.delta_used(iline) = used_delta;
    out.fallback_full(iline) = did_fallback;

    [out,add_eval_rest] = ...
        sequential_rest_of_line( ...
        out,iline,X(:,iline),q1, ...
        q_true(:,iline).', ...
        q_full,search_step, ...
        ori_low_offset,ori_high_offset, ...
        t_norm,u_norm,max_lag, ...
        win_half,peak_ratio, ...
        min_stage_sep,match_tol);

    out.eval_count = out.eval_count + add_eval_rest;
end

% ---------- Propagate left ----------
for iline = (init_idx-1):-1:1

    prev_center = out.q_est(1,iline+1);

    [q1,add_eval,hit_any,used_delta,did_fallback] = ...
        track_dominant_stage( ...
        mode,X(:,iline),prev_center, ...
        q_full,search_step, ...
        delta_small,delta_wide,delta_levels, ...
        t_norm,max_lag);

    out.eval_count = out.eval_count + add_eval;

    out.q_est(1,iline) = q1;
    out.boundary_hit(iline) = hit_any;
    out.delta_used(iline) = used_delta;
    out.fallback_full(iline) = did_fallback;

    [out,add_eval_rest] = ...
        sequential_rest_of_line( ...
        out,iline,X(:,iline),q1, ...
        q_true(:,iline).', ...
        q_full,search_step, ...
        ori_low_offset,ori_high_offset, ...
        t_norm,u_norm,max_lag, ...
        win_half,peak_ratio, ...
        min_stage_sep,match_tol);

    out.eval_count = out.eval_count + add_eval_rest;
end

end

function [out,eval_count] = ...
    sequential_rest_of_line( ...
    out,iline,xline_sig,q1, ...
    q_true_line, ...
    q_full,search_step, ...
    ori_low_offset,ori_high_offset, ...
    t_norm,u_norm,max_lag, ...
    win_half,peak_ratio, ...
    min_stage_sep,match_tol)

Q = size(out.q_est,1);
N = numel(xline_sig);

y_acc = zeros(N,1);

% Stage 1: q1 already estimated by the tracking search.
[G_focus,residual] = ...
    extract_one_lfm_component( ...
    xline_sig,t_norm,u_norm,q1+1, ...
    win_half,peak_ratio);

y_acc = y_acc + G_focus(:);

q_prev = q1;

q_ori = make_ori_grid( ...
    q1, ...
    ori_low_offset,ori_high_offset, ...
    search_step, ...
    q_full(1),q_full(end));

eval_count = 0;

for istage = 2:Q

    [q_hat,add_eval] = ...
        search_residual_on_grid( ...
        residual,q_ori,t_norm,max_lag, ...
        q_prev,min_stage_sep);

    eval_count = eval_count + add_eval;

    out.q_est(istage,iline) = q_hat;

    [G_focus,residual] = ...
        extract_one_lfm_component( ...
        residual,t_norm,u_norm,q_hat+1, ...
        win_half,peak_ratio);

    y_acc = y_acc + G_focus(:);

    q_prev(end+1) = q_hat; %#ok<AGROW>
end

out.Y(:,iline) = y_acc;
out.R(:,iline) = residual;

out.component_recall(:,iline) = ...
    match_true_components( ...
    out.q_est(:,iline).', ...
    q_true_line, ...
    match_tol);

end

function [q_hat,eval_count] = ...
    search_residual_on_grid( ...
    residual,q_grid,t_norm,max_lag, ...
    q_exclude,min_stage_sep)

E = compute_frac_energy_map_continuous( ...
    residual,q_grid,t_norm,max_lag);

score = E(:,1);

% Prevent a partly removed old component from being selected again.
if ~isempty(q_exclude)

    for kk = 1:numel(q_exclude)
        mask = abs(q_grid - q_exclude(kk)) < min_stage_sep;
        score(mask) = -inf;
    end
end

[best,imax] = max(score);

if ~isfinite(best)
    error('All q candidates were excluded.');
end

q_hat = q_grid(imax);
eval_count = numel(q_grid);

end

function [q1,eval_count,hit_any,used_delta,did_fallback] = ...
    track_dominant_stage( ...
    mode,xline_sig,prev_center, ...
    q_full,search_step, ...
    delta_small,delta_wide,delta_levels, ...
    t_norm,max_lag)

eval_count = 0;
hit_any = false;
used_delta = NaN;
did_fallback = false;

switch lower(mode)

    case 'fixedsmall'
        levels = delta_small;

    case 'fixedwide'
        levels = delta_wide;

    case 'adaptive'
        levels = delta_levels;

    otherwise
        error('Unknown mode: %s',mode);
end

for id = 1:numel(levels)

    delta = levels(id);

    q_local = make_local_grid( ...
        prev_center,delta,search_step, ...
        q_full(1),q_full(end));

    E = compute_frac_energy_map_continuous( ...
        xline_sig,q_local,t_norm,max_lag);

    eval_count = eval_count + numel(q_local);

    [~,imax] = max(E(:,1));
    q_candidate = q_local(imax);

    is_boundary = ...
        (imax == 1) || ...
        (imax == numel(q_local));

    if ~is_boundary
        q1 = q_candidate;
        used_delta = delta;
        return;
    end

    hit_any = true;

    if ~strcmpi(mode,'adaptive')
        q1 = q_candidate;
        used_delta = delta;
        return;
    end
end

% Adaptive full-search fallback.
E = compute_frac_energy_map_continuous( ...
    xline_sig,q_full,t_norm,max_lag);

eval_count = eval_count + numel(q_full);

[~,imax] = max(E(:,1));

q1 = q_full(imax);
did_fallback = true;
used_delta = NaN;

end

function q_local = make_local_grid(center,delta,step,full_low,full_high)

low = max(center-delta,full_low);
high = min(center+delta,full_high);

low = ceil(low/step)*step;
high = floor(high/step)*step;

if high < low
    q_local = center;
else
    q_local = low:step:high;
end

end

function q_ori = make_ori_grid( ...
    center,low_offset,high_offset,step,full_low,full_high)

low = max(center+low_offset,full_low);
high = min(center+high_offset,full_high);

low = ceil(low/step)*step;
high = floor(high/step)*step;

q_ori = low:step:high;

end

function recall = match_true_components(q_est,q_true,tol)

q_est = q_est(:).';
q_true = q_true(:).';

Q = numel(q_true);
recall = false(Q,1);

used = false(size(q_est));

for iq = 1:Q

    dist = abs(q_est - q_true(iq));
    dist(used) = inf;

    [dmin,idx] = min(dist);

    if dmin <= tol
        recall(iq) = true;
        used(idx) = true;
    end
end

end

function H = image_entropy_energy(Y)

P = abs(Y).^2;
S = sum(P(:));

if S <= eps
    H = NaN;
    return;
end

p = P(:)/S;
p = p(p > 0);

H = -sum(p.*log(p));

end

function s = magnitude_image_similarity(A,B)

a = abs(A(:));
b = abs(B(:));

den = sqrt(sum(a.^2)*sum(b.^2));

if den <= eps
    s = 0;
else
    s = sum(a.*b)/den;
end

end
