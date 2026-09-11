%% exp06_boundary_aware_adaptive_tracking.m
% Xu et al., JSTARS 2025
% "Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images"
%
% Experiment 06:
%   Boundary-aware adaptive tracking as an exploratory extension.
%
% Status:
%   This experiment is INSPIRED BY, but goes BEYOND, the Xu 2025 paper.
%
% Why:
%   EXP05 showed that a fixed small tracking window is very efficient in
%   smooth regions but can fail when the line-to-line ORO jump exceeds Delta.
%   Boundary hits appear before/during such failures.
%
% Hypothesis:
%   Use boundary hits as an online trigger:
%       small Delta -> expand only when needed -> full-search fallback
%   This may recover much of the robustness of a wide/fixed search while
%   retaining much of the computational saving of a narrow local search.
%
% Baselines:
%   1) Full independent search
%   2) Fixed-small tracking: Delta = 0.01
%   3) Fixed-wide tracking:  Delta = 0.08
%   4) Adaptive tracking: Delta = 0.01 -> 0.02 -> 0.04 -> 0.08 -> full fallback
%
% Directory:
%   papers/
%     Xu2025_Adaptive_Fast_Refocusing/
%       code/
%         exp06_boundary_aware_adaptive_tracking/
%           exp06_boundary_aware_adaptive_tracking.m
%         functions/
%           compute_frac_energy_map.m
%           track_oro_adjacent_lines.m
%           track_oro_adaptive_window.m
%       results/
%         exp06_boundary_aware_adaptive_tracking/
%
% MATLAB R2021b+ recommended. No toolbox required.

clear; clc; close all;

%% 0. Resolve project paths
this_file = mfilename('fullpath');
exp_code_dir = fileparts(this_file);
code_dir = fileparts(exp_code_dir);
paper_dir = fileparts(code_dir);

functions_dir = fullfile(code_dir, 'functions');
result_dir = fullfile(paper_dir, 'results', ...
    'exp06_boundary_aware_adaptive_tracking');

addpath(functions_dir);

if ~exist(result_dir,'dir')
    mkdir(result_dir);
end

%% 1. Common signal setup
N_az = 128;
N_line = 81;

n = (-(N_az-1)/2 : (N_az-1)/2).';
line_idx = 1:N_line;
x = linspace(-1,1,N_line);

kappa = 0.50;
max_lag = 16;

search_step = 0.0025;
p_full = -0.75 : search_step : -0.30;

p_base = -0.5037 ...
       + 0.045*sin(0.85*pi*x) ...
       + 0.014*x;

amp_base = 0.20 + 0.80*exp(-(x/0.52).^2);

jump_idx = 61;

weak_half_width = 2;
weak_factor = 0.28;

snr_center_db = 15;
noise_power = 1/10^(snr_center_db/10);

background_level_db = -35;

%% 2. Search strategies
delta_small = 0.010;
delta_wide = 0.080;
delta_levels = [0.010, 0.020, 0.040, 0.080];

jump_list = [0.000, 0.010, 0.020, 0.040, 0.060];
n_jump = numel(jump_list);

method_names = {'Full','FixedSmall','FixedWide','Adaptive'};
n_method = numel(method_names);

%% 3. Metrics
rmse = zeros(n_jump,n_method);
mae = zeros(n_jump,n_method);
maxerr = zeros(n_jump,n_method);
evals = zeros(n_jump,n_method);
reduction_pct = zeros(n_jump,n_method);

adaptive_boundary_rate = zeros(n_jump,1);
adaptive_fallback_count = zeros(n_jump,1);
adaptive_mean_delta = zeros(n_jump,1);

example = struct();

full_eval = numel(p_full)*N_line;

fprintf('============================================================\n');
fprintf('EXP06 BOUNDARY-AWARE ADAPTIVE TRACKING\n');
fprintf('Full-search evaluations = %d\n', full_eval);
fprintf('Adaptive Delta levels = ');
fprintf('%.3f ', delta_levels);
fprintf('\n============================================================\n\n');

%% 4. Sweep jump amplitude
for ij = 1:n_jump

    jump_amp = jump_list(ij);

    p_true = p_base;
    p_true(jump_idx:end) = p_true(jump_idx:end) + jump_amp;

    amp = amp_base;
    weak_cells = max(1,jump_idx-weak_half_width) : ...
                 min(N_line,jump_idx+weak_half_width);
    amp(weak_cells) = amp(weak_cells)*weak_factor;

    % Same dataset across all four strategies for this jump amplitude.
    rng(2000+ij,'twister');

    X = 10^(background_level_db/20) * ...
        (randn(N_az,N_line)+1j*randn(N_az,N_line))/sqrt(2);

    for iline = 1:N_line

        alpha_true = p_true(iline)*pi/2;
        a_norm = kappa*tan(alpha_true);

        b_norm = -0.05 + 0.035*sin(1.2*pi*x(iline));

        s = amp(iline) * ...
            exp(1j*pi*a_norm*(n.^2)/N_az + 1j*2*pi*b_norm*n);

        noise = sqrt(noise_power/2) * ...
            (randn(N_az,1)+1j*randn(N_az,1));

        X(:,iline) = X(:,iline) + s + noise;
    end

    line_energy = sum(abs(X).^2,1);
    [~,init_idx] = max(line_energy);

    %% 4.1 Full independent search
    E_full = compute_frac_energy_map(X,p_full,n,kappa,max_lag);
    [~,idx_full] = max(E_full,[],1);
    p_est_full = p_full(idx_full);

    eval_full = full_eval;

    %% 4.2 Fixed-small tracking
    [p_est_small, eval_small] = ...
        track_oro_adjacent_lines( ...
        X,p_full,search_step,delta_small, ...
        n,kappa,max_lag,init_idx);

    %% 4.3 Fixed-wide tracking
    [p_est_wide, eval_wide] = ...
        track_oro_adjacent_lines( ...
        X,p_full,search_step,delta_wide, ...
        n,kappa,max_lag,init_idx);

    %% 4.4 Boundary-aware adaptive tracking
    [p_est_adapt, eval_adapt, boundary_adapt, ...
        delta_used, fallback_full] = ...
        track_oro_adaptive_window( ...
        X,p_full,search_step,delta_levels, ...
        n,kappa,max_lag,init_idx);

    P = [ ...
        p_est_full; ...
        p_est_small; ...
        p_est_wide; ...
        p_est_adapt];

    eval_vec = [eval_full, eval_small, eval_wide, eval_adapt];

    for im = 1:n_method
        err = P(im,:) - p_true;

        rmse(ij,im) = sqrt(mean(err.^2));
        mae(ij,im) = mean(abs(err));
        maxerr(ij,im) = max(abs(err));

        evals(ij,im) = eval_vec(im);
        reduction_pct(ij,im) = 100*(1-eval_vec(im)/full_eval);
    end

    adaptive_boundary_rate(ij) = 100*mean(boundary_adapt);
    adaptive_fallback_count(ij) = sum(fallback_full);

    valid_delta = delta_used(~isnan(delta_used));
    if isempty(valid_delta)
        adaptive_mean_delta(ij) = NaN;
    else
        adaptive_mean_delta(ij) = mean(valid_delta);
    end

    if abs(jump_amp-0.060)<1e-12
        example.p_true = p_true;
        example.p_full = p_est_full;
        example.p_small = p_est_small;
        example.p_wide = p_est_wide;
        example.p_adapt = p_est_adapt;
        example.boundary = boundary_adapt;
        example.delta_used = delta_used;
        example.fallback = fallback_full;
        example.line_energy = line_energy;
        example.init_idx = init_idx;
    end
end

%% 5. Console tables
rows = n_jump*n_method;

JumpAmplitude = zeros(rows,1);
Method = strings(rows,1);
ORO_RMSE = zeros(rows,1);
ORO_MAE = zeros(rows,1);
MaxAbsError = zeros(rows,1);
FrAcEvaluations = zeros(rows,1);
EvaluationReduction_pct = zeros(rows,1);

ir = 0;

for ij = 1:n_jump
    for im = 1:n_method
        ir = ir+1;

        JumpAmplitude(ir) = jump_list(ij);
        Method(ir) = string(method_names{im});

        ORO_RMSE(ir) = rmse(ij,im);
        ORO_MAE(ir) = mae(ij,im);
        MaxAbsError(ir) = maxerr(ij,im);

        FrAcEvaluations(ir) = evals(ij,im);
        EvaluationReduction_pct(ir) = reduction_pct(ij,im);
    end
end

T = table( ...
    JumpAmplitude,Method, ...
    ORO_RMSE,ORO_MAE,MaxAbsError, ...
    FrAcEvaluations,EvaluationReduction_pct);

T_adapt = table( ...
    jump_list.', ...
    adaptive_boundary_rate, ...
    adaptive_fallback_count, ...
    adaptive_mean_delta, ...
    'VariableNames', { ...
    'JumpAmplitude', ...
    'BoundaryHitRate_pct', ...
    'FullFallbackCount', ...
    'MeanAcceptedDelta'});

disp(' ');
disp('================ EXP06 METHOD COMPARISON ================');
disp(T);

disp(' ');
disp('================ EXP06 ADAPTIVE DIAGNOSTICS ================');
disp(T_adapt);

fprintf('\n================ EXP06 INTERPRETATION ================\n');

for ij = 1:n_jump
    fprintf('Jump = %.3f\n',jump_list(ij));

    for im = 1:n_method
        fprintf(['  %-10s | RMSE=%8.5f | MaxErr=%8.5f | ' ...
                 'Eval=%5d | EvalRed=%6.2f%%\n'], ...
            method_names{im}, ...
            rmse(ij,im), ...
            maxerr(ij,im), ...
            round(evals(ij,im)), ...
            reduction_pct(ij,im));
    end

    fprintf(['  Adaptive diagnostics: boundary=%5.2f%%, ' ...
             'fallback=%d, mean Delta=%.4f\n\n'], ...
        adaptive_boundary_rate(ij), ...
        adaptive_fallback_count(ij), ...
        adaptive_mean_delta(ij));
end

%% 6. Figure 1: RMSE vs jump amplitude
fig1 = figure('Name','exp06 RMSE comparison','Color','w');

hold on;
for im = 1:n_method
    plot(jump_list,rmse(:,im),'o-','LineWidth',1.2);
end

xlabel('Abrupt ORO jump amplitude');
ylabel('ORO RMSE');
title('Robustness comparison under abrupt ORO changes');
legend(method_names,'Location','best');
grid on;

%% 7. Figure 2: evaluation count vs jump amplitude
fig2 = figure('Name','exp06 Evaluation comparison','Color','w');

hold on;
for im = 1:n_method
    plot(jump_list,evals(:,im),'o-','LineWidth',1.2);
end

xlabel('Abrupt ORO jump amplitude');
ylabel('FrAc candidate-order evaluations');
title('Computational cost under abrupt ORO changes');
legend(method_names,'Location','best');
grid on;

%% 8. Figure 3: quality-cost plane at largest jump
fig3 = figure('Name','exp06 Quality-cost largest jump','Color','w');

ij = n_jump;

scatter(evals(ij,:),rmse(ij,:),85,'o','LineWidth',1.2);
hold on;

for im = 1:n_method
    text(evals(ij,im),rmse(ij,im), ...
        ['  ' method_names{im}]);
end

xlabel('FrAc candidate-order evaluations');
ylabel('ORO RMSE');
title(sprintf('Quality-cost plane at ORO jump = %.3f',jump_list(ij)));
grid on;

%% 9. Figure 4: challenging tracking example
fig4 = figure('Name','exp06 Challenging example','Color','w');

plot(line_idx,example.p_true,'LineWidth',1.5);
hold on;
plot(line_idx,example.p_small,'--','LineWidth',1.0);
plot(line_idx,example.p_wide,'-.','LineWidth',1.0);
plot(line_idx,example.p_adapt,':','LineWidth',1.5);

xline(jump_idx,'--','Jump','LineWidth',1.0);

xlabel('Neighboring spatial / range cell');
ylabel('Dominant ORO');
title(sprintf('Tracking at jump = %.3f',jump_list(end)));

legend('True','FixedSmall','FixedWide','Adaptive','Location','best');
grid on;

%% 10. Figure 5: adaptive Delta usage for challenging case
fig5 = figure('Name','exp06 Adaptive Delta usage','Color','w');

stairs(line_idx,example.delta_used,'LineWidth',1.2);
hold on;

fallback_idx = find(example.fallback);
if ~isempty(fallback_idx)
    plot(fallback_idx, ...
        max(delta_levels)*ones(size(fallback_idx)), ...
        'x','MarkerSize',7,'LineWidth',1.2);
end

xline(jump_idx,'--','Jump','LineWidth',1.0);

xlabel('Neighboring spatial / range cell');
ylabel('Accepted local half width \Delta');
title('Adaptive search-window usage on challenging case');

grid on;

%% 11. Save outputs
writetable(T, ...
    fullfile(result_dir,'exp06_method_comparison.csv'));

writetable(T_adapt, ...
    fullfile(result_dir,'exp06_adaptive_diagnostics.csv'));

save(fullfile(result_dir,'exp06_summary.mat'), ...
    'jump_list','method_names', ...
    'rmse','mae','maxerr','evals','reduction_pct', ...
    'adaptive_boundary_rate','adaptive_fallback_count', ...
    'adaptive_mean_delta', ...
    'delta_small','delta_wide','delta_levels', ...
    'search_step','p_full','full_eval', ...
    'jump_idx','weak_factor','snr_center_db', ...
    'example');

exportgraphics(fig1, ...
    fullfile(result_dir,'fig01_rmse_vs_jump.png'), ...
    'Resolution',200);

exportgraphics(fig2, ...
    fullfile(result_dir,'fig02_evaluations_vs_jump.png'), ...
    'Resolution',200);

exportgraphics(fig3, ...
    fullfile(result_dir,'fig03_quality_cost_largest_jump.png'), ...
    'Resolution',200);

exportgraphics(fig4, ...
    fullfile(result_dir,'fig04_challenging_tracking_example.png'), ...
    'Resolution',200);

exportgraphics(fig5, ...
    fullfile(result_dir,'fig05_adaptive_delta_usage.png'), ...
    'Resolution',200);

fprintf('\nOutputs saved to:\n%s\n',result_dir);
