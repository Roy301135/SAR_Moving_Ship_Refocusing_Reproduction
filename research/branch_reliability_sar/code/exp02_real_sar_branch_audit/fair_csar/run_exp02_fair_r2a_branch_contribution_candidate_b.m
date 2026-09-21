%% run_exp02_fair_r2a_branch_contribution_candidate_b.m
% EXP02-FAIR-R2A — CORRECTED BRANCH-NATIVE VERSION
%
% Purpose:
%   Measure image-level headroom attributable ONLY to branch selection.
%
% Why this corrected version exists:
%   R1's nu is a dechirped-tone coordinate. The previous R2A attempt mapped
%   that nu into the finite u-grid of frft_direct.m. For p_beta=0.78, the
%   resulting calibrated peak sits close to the u-grid edge; a deliberately
%   remote wrong branch can map outside that finite grid and collapse onto
%   the same boundary sample. That is why TRUE and WRONG closure produced
%   a ratio ~=1 even after changing the metric.
%
% Correct fix:
%   Stay in the SAME matched-LFM / dechirped-tone coordinate used by R1 and
%   by the validated EXP009/EXP010 practical removal operator.
%
% G0 and Global paths are identical except for nu.

clear; clc; close all;

%% 0. Resolve paths
this_file = mfilename('fullpath');
fair_code_dir = fileparts(this_file);
exp02_code_dir = fileparts(fair_code_dir);
code_dir = fileparts(exp02_code_dir);
research_dir = fileparts(code_dir);
research_parent = fileparts(research_dir);
repo_root = fileparts(research_parent);

addpath(fair_code_dir);
addpath(genpath(fullfile(research_dir,'functions')));

cfg = config_exp02_fair_r2a(research_dir,repo_root);

if ~exist(cfg.results_dir,'dir')
    mkdir(cfg.results_dir);
end

required_fns = { ...
    'fair_csar_load_complex_mat', ...
    'refocus_mclfm_branch_native_clean'};

for i = 1:numel(required_fns)
    if exist(required_fns{i},'file') ~= 2
        error('EXP02_FAIR_R2A:MissingFunction', ...
            'Required function not found: %s',required_fns{i});
    end
end

if exist(cfg.r1b_workspace,'file') ~= 2
    error('EXP02_FAIR_R2A:MissingR1B', ...
        'Candidate-B R1B workspace missing: %s',cfg.r1b_workspace);
end

%% 1. Load frozen Candidate-B R1B state
W = load(cfg.r1b_workspace, ...
    'cfg','R','frozen_cols', ...
    'StateLineIndex','StateRangeColumn','StatePbeta', ...
    'StateFracEnergy','StateExcessAboveMaxStat95', ...
    'Audit','T','n_states','n_safe','n_rescue','n_miss','n_persist');

if ~isfield(W,'R') || ~isfield(W.R,'r1') || ~isfield(W.R,'r2') || ...
        ~isfield(W.R,'c1') || ~isfield(W.R,'c2')
    error('EXP02_FAIR_R2A:R1BSchema', ...
        'R1B workspace does not contain frozen Candidate-B crop state.');
end

data_stem = W.cfg.stem;
mat_path = fullfile(cfg.data_root,'SLCMats',[data_stem '.mat']);

if exist(mat_path,'file') ~= 2
    error('EXP02_FAIR_R2A:MissingMAT', ...
        'Candidate-B complex MAT not found: %s',mat_path);
end

[S,mat_info] = fair_csar_load_complex_mat(mat_path);
S = double(S);

r1 = W.R.r1;
r2 = W.R.r2;
c1 = W.R.c1;
c2 = W.R.c2;

G_original = S(r1:r2,c1:c2);

n_states = numel(W.StatePbeta);

if numel(W.Audit) ~= n_states
    error('EXP02_FAIR_R2A:StateCountMismatch', ...
        'R1B state count and Audit struct count differ.');
end

Taxonomy = string(W.T.Taxonomy);
failure_state_mask = Taxonomy ~= "SAFE";

%% 2. Branch-native reconstruction closure
closure = run_reconstruction_closure(cfg);

fprintf('============================================================\n');
fprintf('EXP02-FAIR-R2A BRANCH CONTRIBUTION — CORRECTED\n');
fprintf('Candidate              : B\n');
fprintf('Branch coordinate      : R1 dechirped-tone nu\n');
fprintf('Removal operator       : recenter -> matched-LFM -> 3-bin DC window\n');
fprintf('R1B states             : %d\n',n_states);
fprintf('R1B non-SAFE           : %d\n',sum(failure_state_mask));
fprintf('Closure true capture   : %.9f\n',closure.true_capture_fraction);
fprintf('Closure wrong capture  : %.9f\n',closure.wrong_capture_fraction);
fprintf('Closure                : PASS\n');
fprintf('============================================================\n\n');

%% 3. Build G0 and Global matched-LFM focused images
N = size(G_original,1);
Wcrop = size(G_original,2);

F_g0 = zeros(N,Wcrop);
F_global = zeros(N,Wcrop);

unique_cols = unique(W.StateRangeColumn(:).','stable');
processed_cols_local = unique_cols-c1+1;

LineRangeColumn = unique_cols(:);
LineNumStates = zeros(numel(unique_cols),1);
LineNumFailures = zeros(numel(unique_cols),1);

LineG0ResidualRatio = nan(numel(unique_cols),1);
LineGlobalResidualRatio = nan(numel(unique_cols),1);
LineAbsDifferenceNorm = nan(numel(unique_cols),1);
LineG0CapturedMean = nan(numel(unique_cols),1);
LineGlobalCapturedMean = nan(numel(unique_cols),1);

for il = 1:numel(unique_cols)
    col_global = unique_cols(il);
    col_local = col_global-c1+1;

    sid = find(W.StateRangeColumn==col_global);

    switch cfg.clean.order_rule
        case "descending_frac_energy"
            [~,ord] = sort(W.StateFracEnergy(sid),'descend');
            sid = sid(ord);
        otherwise
            error('EXP02_FAIR_R2A:UnknownOrderRule', ...
                'Unknown component order rule: %s',cfg.clean.order_rule);
    end

    p_beta_set = W.StatePbeta(sid).';

    nu_g0 = arrayfun(@(k) W.Audit(k).g0_nu_wrapped,sid);
    nu_global = arrayfun(@(k) W.Audit(k).global_nu_bins,sid);

    % nu is N-periodic. Use the equivalent Global representative nearest
    % the corresponding G0 value so that a harmless +/-N representation
    % difference cannot contaminate the numerical comparison.
    nu_global = nearest_periodic_rep_vec(nu_global,nu_g0,N);

    x = G_original(:,col_local);

    [f_g0,~,info_g0] = refocus_mclfm_branch_native_clean( ...
        x,p_beta_set,nu_g0, ...
        cfg.clean.removal_window_bins,cfg.tnorm_full_span);

    [f_global,~,info_global] = refocus_mclfm_branch_native_clean( ...
        x,p_beta_set,nu_global, ...
        cfg.clean.removal_window_bins,cfg.tnorm_full_span);

    f_g0 = f_g0(:);
    f_global = f_global(:);

    F_g0(:,col_local) = f_g0;
    F_global(:,col_local) = f_global;

    LineNumStates(il) = numel(sid);
    LineNumFailures(il) = sum(failure_state_mask(sid));

    LineG0ResidualRatio(il) = info_g0.residual_energy_ratio;
    LineGlobalResidualRatio(il) = info_global.residual_energy_ratio;

    LineG0CapturedMean(il) = mean(info_g0.captured_energy_fraction_stage);
    LineGlobalCapturedMean(il) = mean(info_global.captured_energy_fraction_stage);

    LineAbsDifferenceNorm(il) = ...
        norm(abs(f_global)-abs(f_g0))/max(norm(abs(f_g0)),eps);

    fprintf(['line %2d/%2d | col=%d | states=%d | failures=%d | ' ...
        'difference=%.5g\n'], ...
        il,numel(unique_cols),col_global,numel(sid), ...
        LineNumFailures(il),LineAbsDifferenceNorm(il));
end

%% 4. Numerical consistency audit
% IMPORTANT:
% G0 and Global are independently optimized continuous branch estimates.
% A line with max |nu_G0-nu_Global| < 1e-6 is only NEAR-EQUIVALENT, not
% exactly identical. Requiring its reconstructed outputs to agree at 1e-10
% is therefore mathematically inconsistent: a genuine ~1e-7 branch change
% naturally produces a ~1e-7 output change.
%
% We now do two separate checks:
%   A) deterministic operator check: run exactly the SAME branch vector
%      twice and require machine-level agreement;
%   B) near-equivalent G0/Global lines: record their branch and output
%      differences as diagnostics, but do not force exact equality.

near_equal_branch_lines = false(numel(unique_cols),1);
near_equal_branch_max_delta = nan(numel(unique_cols),1);
near_equal_reconstruction_error = nan(numel(unique_cols),1);

for il = 1:numel(unique_cols)
    col_global = unique_cols(il);
    col_local = col_global-c1+1;

    sid = find(W.StateRangeColumn==col_global);

    nu_g0 = arrayfun(@(k) W.Audit(k).g0_nu_wrapped,sid);
    nu_global = arrayfun(@(k) W.Audit(k).global_nu_bins,sid);
    nu_global = nearest_periodic_rep_vec(nu_global,nu_g0,N);

    dnu = circular_bin_distance_vec(nu_g0,nu_global,N);
    near_equal_branch_max_delta(il) = max(dnu);

    if near_equal_branch_max_delta(il) < 1e-6
        near_equal_branch_lines(il) = true;

        near_equal_reconstruction_error(il) = ...
            norm(F_global(:,col_local)-F_g0(:,col_local))/ ...
            max(norm(F_g0(:,col_local)),eps);
    end
end

vals = near_equal_reconstruction_error(near_equal_branch_lines);
vals = vals(isfinite(vals));

if isempty(vals)
    max_near_equal_reconstruction_error = NaN;
else
    max_near_equal_reconstruction_error = max(vals);
end

dvals = near_equal_branch_max_delta(near_equal_branch_lines);
dvals = dvals(isfinite(dvals));

if isempty(dvals)
    max_near_equal_branch_delta = NaN;
else
    max_near_equal_branch_delta = max(dvals);
end

% Exact-repeat determinism test on the first processed real line.
test_col_global = unique_cols(1);
test_col_local = test_col_global-c1+1;
test_sid = find(W.StateRangeColumn==test_col_global);

switch cfg.clean.order_rule
    case "descending_frac_energy"
        [~,ord_test] = sort(W.StateFracEnergy(test_sid),'descend');
        test_sid = test_sid(ord_test);
    otherwise
        error('EXP02_FAIR_R2A:UnknownOrderRule', ...
            'Unknown component order rule: %s',cfg.clean.order_rule);
end

test_p = W.StatePbeta(test_sid).';
test_nu = arrayfun(@(k) W.Audit(k).g0_nu_wrapped,test_sid);
test_x = G_original(:,test_col_local);

[f_test_1,~,~] = refocus_mclfm_branch_native_clean( ...
    test_x,test_p,test_nu, ...
    cfg.clean.removal_window_bins,cfg.tnorm_full_span);

[f_test_2,~,~] = refocus_mclfm_branch_native_clean( ...
    test_x,test_p,test_nu, ...
    cfg.clean.removal_window_bins,cfg.tnorm_full_span);

operator_repeat_error = ...
    norm(f_test_2(:)-f_test_1(:))/max(norm(f_test_1(:)),eps);

if operator_repeat_error > 1e-12
    error('EXP02_FAIR_R2A:OperatorDeterminismFailed', ...
        ['Exact repeated use of the SAME branch vector changed output ' ...
         '(relative error %.3e).'],operator_repeat_error);
end

fprintf(['Numerical consistency PASS | repeat error=%.3e | ' ...
    'near-equal max dnu=%.3e bin | near-equal max output diff=%.3e\n\n'], ...
    operator_repeat_error,max_near_equal_branch_delta, ...
    max_near_equal_reconstruction_error);

%% 5. Primary G0-vs-Global metrics
% IMPORTANT: These metrics are computed on the SAME matched-LFM focused
% coordinate. Original SLC is visualization context only and is NOT mixed
% into the causal metric comparison.

I_g0 = F_g0(:,processed_cols_local);
I_global = F_global(:,processed_cols_local);

M_g0 = image_metrics(I_g0,cfg.metrics.azimuth_energy_fraction);
M_global = image_metrics(I_global,cfg.metrics.azimuth_energy_fraction);

%% 6. Branch-sensitive objective weight / headroom from frozen R1B
Jglobal = reshape(arrayfun(@(s) s.global_objective,W.Audit),[],1);
Jg0 = reshape(arrayfun(@(s) s.G0.objective_at_hat,W.Audit),[],1);

failure_objective_weight = ...
    sum(Jglobal(failure_state_mask))/max(sum(Jglobal),eps);

weighted_branch_objective_headroom = ...
    sum(max(Jglobal-Jg0,0))/max(sum(Jglobal),eps);

failure_only_weighted_headroom = ...
    sum(max(Jglobal(failure_state_mask)-Jg0(failure_state_mask),0))/ ...
    max(sum(Jglobal(failure_state_mask)),eps);

%% 7. Difference localization
D = abs(F_global)-abs(F_g0);

failure_cols_global = unique(W.StateRangeColumn(failure_state_mask));
failure_cols_local = failure_cols_global-c1+1;
failure_cols_local = failure_cols_local( ...
    failure_cols_local>=1 & failure_cols_local<=Wcrop);

all_change = sum(abs(D(:)));

if all_change > 0
    failure_column_change_fraction = ...
        sum(abs(D(:,failure_cols_local)),'all')/all_change;
else
    failure_column_change_fraction = 0;
end

%% 8. Tables
MetricName = [ ...
    "Entropy"; ...
    "Azimuth_W80"; ...
    "PeakConcentration"];

FrozenG0 = [ ...
    M_g0.entropy; ...
    M_g0.azimuth_w80; ...
    M_g0.peak_concentration];

GlobalBranch = [ ...
    M_global.entropy; ...
    M_global.azimuth_w80; ...
    M_global.peak_concentration];

GlobalMinusG0 = GlobalBranch-FrozenG0;
RelativeChangeVsG0 = GlobalMinusG0./max(abs(FrozenG0),eps);

Tmetric = table( ...
    MetricName,FrozenG0,GlobalBranch, ...
    GlobalMinusG0,RelativeChangeVsG0);

writetable(Tmetric, ...
    fullfile(cfg.results_dir,'EXP02_FAIR_R2A_metrics.csv'));

Tline = table( ...
    LineRangeColumn,LineNumStates,LineNumFailures, ...
    LineG0ResidualRatio,LineGlobalResidualRatio, ...
    LineG0CapturedMean,LineGlobalCapturedMean, ...
    LineAbsDifferenceNorm,near_equal_branch_lines, ...
    near_equal_branch_max_delta,near_equal_reconstruction_error);

writetable(Tline, ...
    fullfile(cfg.results_dir,'EXP02_FAIR_R2A_line_metrics.csv'));

%% 9. Figure 1 — closure
fig1 = figure('Color','w','Name','R2A branch-native closure');
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

nexttile;
plot(abs(closure.focus_true),'LineWidth',1.1);
xlabel('Matched-LFM azimuth bin');
ylabel('|Y_{focus}|');
title(sprintf('True branch | capture=%.4f', ...
    closure.true_capture_fraction));
grid on;

nexttile;
plot(abs(closure.focus_wrong),'LineWidth',1.1);
xlabel('Matched-LFM azimuth bin');
ylabel('|Y_{focus}|');
title(sprintf('Wrong branch | capture=%.4g', ...
    closure.wrong_capture_fraction));
grid on;

nexttile;
bar([closure.true_capture_fraction closure.wrong_capture_fraction]);
xticks(1:2);
xticklabels({'true','wrong'});
ylabel('Captured fraction');
title(sprintf('true/wrong = %.1f',closure.capture_ratio));
grid on;

exportgraphics(fig1, ...
    fullfile(cfg.results_dir,'01_reconstruction_closure.png'), ...
    'Resolution',cfg.figure_resolution);

%% 10. Figure 2 — original context + two comparable focused outputs
fig2 = figure('Color','w','Name','R2A original context and focused outputs');
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

nexttile;
imagesc(log1p(abs(G_original)));
axis image;
xlabel('Range column');
ylabel('Original SLC azimuth row');
title('Original SLC (context only)');

nexttile;
imagesc(log1p(abs(F_g0)));
axis image;
xlabel('Range column');
ylabel('Matched-LFM azimuth bin');
title(sprintf('Frozen G0 | H=%.3f',M_g0.entropy));

nexttile;
imagesc(log1p(abs(F_global)));
axis image;
xlabel('Range column');
ylabel('Matched-LFM azimuth bin');
title(sprintf('Global branch | H=%.3f',M_global.entropy));

colormap gray;

exportgraphics(fig2, ...
    fullfile(cfg.results_dir,'02_original_g0_global.png'), ...
    'Resolution',cfg.figure_resolution);

%% 11. Figure 3 — difference
fig3 = figure('Color','w','Name','R2A G0 Global difference');

imagesc(D);
axis image;
xlabel('Range column within crop');
ylabel('Matched-LFM azimuth bin');
title(sprintf('|Global|-|G0| | failure-column fraction=%.3f', ...
    failure_column_change_fraction));
colorbar;
hold on;

for k = 1:numel(failure_cols_local)
    xline(failure_cols_local(k),'--','LineWidth',0.8);
end

hold off;

exportgraphics(fig3, ...
    fullfile(cfg.results_dir,'03_g0_vs_global_difference.png'), ...
    'Resolution',cfg.figure_resolution);

%% 12. Figure 4 — primary causal metrics
fig4 = figure('Color','w','Name','R2A G0 Global metric comparison');
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');

nexttile;
bar([M_g0.entropy M_global.entropy]);
xticks(1:2);
xticklabels({'G0','Global'});
ylabel('Entropy');
title('Matched-LFM image entropy');
grid on;

nexttile;
bar([M_g0.azimuth_w80 M_global.azimuth_w80]);
xticks(1:2);
xticklabels({'G0','Global'});
ylabel('Bins');
title('Azimuth 80% energy width');
grid on;

nexttile;
bar([M_g0.peak_concentration M_global.peak_concentration]);
xticks(1:2);
xticklabels({'G0','Global'});
ylabel('max |I|^2 / sum |I|^2');
title('Peak concentration');
grid on;

exportgraphics(fig4, ...
    fullfile(cfg.results_dir,'04_metric_comparison.png'), ...
    'Resolution',cfg.figure_resolution);

%% 13. Figure 5 — spatial line change
fig5 = figure('Color','w','Name','R2A branch contribution by range line');

yyaxis left;
stem(LineRangeColumn,LineAbsDifferenceNorm,'filled');
ylabel('|| |Global|-|G0| || / || |G0| ||');

yyaxis right;
stem(LineRangeColumn,LineNumFailures);
ylabel('Non-SAFE states on line');

xlabel('Range column');
title('Spatial localization of branch-substitution effect');
grid on;

exportgraphics(fig5, ...
    fullfile(cfg.results_dir,'05_failure_column_profile.png'), ...
    'Resolution',cfg.figure_resolution);

%% 14. Save workspace
save(fullfile(cfg.results_dir,'EXP02_FAIR_R2A_workspace.mat'), ...
    'cfg','W','mat_info', ...
    'G_original','F_g0','F_global','D', ...
    'closure','M_g0','M_global', ...
    'Tmetric','Tline', ...
    'failure_objective_weight', ...
    'weighted_branch_objective_headroom', ...
    'failure_only_weighted_headroom', ...
    'failure_column_change_fraction', ...
    'operator_repeat_error', ...
    'max_near_equal_branch_delta', ...
    'max_near_equal_reconstruction_error');

%% 15. Feedback
txt_path = fullfile(cfg.results_dir,'EXP02_FAIR_R2A_FEEDBACK.txt');
fid = fopen(txt_path,'w');

if fid < 0
    error('EXP02_FAIR_R2A:FeedbackOpenFailed', ...
        'Cannot write feedback bundle.');
end

cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-R2A BRANCH CONTRIBUTION TO IMAGE DEFOCUS\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'candidate=B\n');
fprintf(fid,'R2A_version=corrected_branch_native\n');
fprintf(fid,'FrFT_u_mapping_used=0\n');
fprintf(fid,'Branch_parameters_retuned=0\n');
fprintf(fid,'Component_set_changed_between_G0_Global=0\n');
fprintf(fid,'p_beta_changed_between_G0_Global=0\n');
fprintf(fid,'Only_branch_nu_substituted=1\n\n');

fprintf(fid,'[OPERATOR]\n');
fprintf(fid,'operator=recenter -> matched-LFM dechirp -> FFT -> centered finite window -> inverse -> undo recenter -> sequential subtraction\n');
fprintf(fid,'provenance=EXP009_EXP010_practical_recenter_notch_remove\n');
fprintf(fid,'removal_window_bins=%d\n',cfg.clean.removal_window_bins);
fprintf(fid,'component_order_rule=%s\n\n',cfg.clean.order_rule);

fprintf(fid,'[CLOSURE]\n');
fprintf(fid,'p_beta=%.9g\n',cfg.closure.p_beta);
fprintf(fid,'nu_true=%.9g\n',cfg.closure.nu_true);
fprintf(fid,'nu_wrong=%.9g\n', ...
    cfg.closure.nu_true+cfg.closure.nu_wrong_offset);
fprintf(fid,'true_capture_fraction=%.12g\n',closure.true_capture_fraction);
fprintf(fid,'wrong_capture_fraction=%.12g\n',closure.wrong_capture_fraction);
fprintf(fid,'true_to_wrong_capture_ratio=%.12g\n',closure.capture_ratio);
fprintf(fid,'closure_PASS=1\n\n');

fprintf(fid,'[FROZEN R1B INPUT]\n');
fprintf(fid,'stem=%s\n',data_stem);
fprintf(fid,'crop_rows=%d:%d\n',r1,r2);
fprintf(fid,'crop_columns=%d:%d\n',c1,c2);
fprintf(fid,'valid_component_states=%d\n',n_states);
fprintf(fid,'nonSAFE_component_states=%d\n',sum(failure_state_mask));
fprintf(fid,'processed_range_lines=%d\n\n',numel(unique_cols));

fprintf(fid,'[PRIMARY G0 VS GLOBAL METRICS]\n');
fprintf(fid,'G0_entropy=%.12g\n',M_g0.entropy);
fprintf(fid,'Global_entropy=%.12g\n',M_global.entropy);
fprintf(fid,'Global_minus_G0_entropy=%.12g\n', ...
    M_global.entropy-M_g0.entropy);
fprintf(fid,'Global_vs_G0_entropy_relative=%.12g\n\n', ...
    (M_global.entropy-M_g0.entropy)/max(abs(M_g0.entropy),eps));

fprintf(fid,'G0_azimuth_W80=%d\n',M_g0.azimuth_w80);
fprintf(fid,'Global_azimuth_W80=%d\n',M_global.azimuth_w80);
fprintf(fid,'Global_minus_G0_W80=%d\n\n', ...
    M_global.azimuth_w80-M_g0.azimuth_w80);

fprintf(fid,'G0_peak_concentration=%.12g\n',M_g0.peak_concentration);
fprintf(fid,'Global_peak_concentration=%.12g\n', ...
    M_global.peak_concentration);
fprintf(fid,'Global_minus_G0_peak_concentration=%.12g\n\n', ...
    M_global.peak_concentration-M_g0.peak_concentration);

fprintf(fid,'[BRANCH-SENSITIVE OBJECTIVE WEIGHT]\n');
fprintf(fid,'failure_global_objective_weight=%.12g\n', ...
    failure_objective_weight);
fprintf(fid,'weighted_branch_objective_headroom=%.12g\n', ...
    weighted_branch_objective_headroom);
fprintf(fid,'failure_only_weighted_headroom=%.12g\n\n', ...
    failure_only_weighted_headroom);

fprintf(fid,'[SPATIAL LOCALIZATION]\n');
fprintf(fid,'failure_range_columns=%s\n',mat2str(failure_cols_global));
fprintf(fid,'failure_column_change_fraction=%.12g\n', ...
    failure_column_change_fraction);
fprintf(fid,'operator_repeat_error=%.12g\n',operator_repeat_error);
fprintf(fid,'max_near_equal_branch_delta_bins=%.12g\n', ...
    max_near_equal_branch_delta);
fprintf(fid,'max_near_equal_reconstruction_error=%.12g\n\n', ...
    max_near_equal_reconstruction_error);

fprintf(fid,'[INTERPRETATION BOUNDARY]\n');
fprintf(fid,['G0 and Global outputs are compared in the SAME branch-native ' ...
    'matched-LFM focused coordinate. Original SLC is visualization context ' ...
    'only and is not mixed into the primary causal metrics.\n']);
fprintf(fid,['Global nu is the evaluation-only continuous winner of the same R1 ' ...
    'tone objective; it is not physical motion truth.\n']);
fprintf(fid,['R2A measures conditional branch-selection headroom under the ' ...
    'current accepted p_beta/component model. It does not measure the total ' ...
    'recoverable ship defocus.\n']);

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,'1) EXP02_FAIR_R2A_FEEDBACK.txt\n');
fprintf(fid,'2) 01_reconstruction_closure.png\n');
fprintf(fid,'3) 02_original_g0_global.png\n');
fprintf(fid,'4) 03_g0_vs_global_difference.png\n');
fprintf(fid,'5) 04_metric_comparison.png\n');
fprintf(fid,'6) 05_failure_column_profile.png\n');

fprintf('\n============================================================\n');
fprintf('R2A complete.\n');
fprintf('Entropy G0 %.6f | Global %.6f\n',M_g0.entropy,M_global.entropy);
fprintf('W80    G0 %d | Global %d\n',M_g0.azimuth_w80,M_global.azimuth_w80);
fprintf('Peak C G0 %.6g | Global %.6g\n', ...
    M_g0.peak_concentration,M_global.peak_concentration);
fprintf('Failure-column change fraction %.6f\n', ...
    failure_column_change_fraction);
fprintf('Feedback: %s\n',txt_path);
fprintf('============================================================\n');

%% ========================================================================
function closure = run_reconstruction_closure(cfg)

N = cfg.closure.N;
m = 0:N-1;

p_beta = cfg.closure.p_beta;
nu_true = cfg.closure.nu_true;
nu_wrong = nu_true+cfg.closure.nu_wrong_offset;

scale = cfg.tnorm_full_span/(N-1);
a = tan(pi*p_beta/2)*scale^2;

x = exp(1j*pi*a*m.^2 + 1j*2*pi*nu_true*m/N);

[f_true,r_true,info_true] = refocus_mclfm_branch_native_clean( ...
    x,p_beta,nu_true, ...
    cfg.clean.removal_window_bins,cfg.tnorm_full_span);

[f_wrong,r_wrong,info_wrong] = refocus_mclfm_branch_native_clean( ...
    x,p_beta,nu_wrong, ...
    cfg.clean.removal_window_bins,cfg.tnorm_full_span);

true_capture = info_true.captured_energy_fraction_stage(1);
wrong_capture = info_wrong.captured_energy_fraction_stage(1);

if true_capture < cfg.closure.min_true_capture_fraction
    error('EXP02_FAIR_R2A:ClosureTrueCaptureFailed', ...
        'Correct branch captured only %.6f < %.6f.', ...
        true_capture,cfg.closure.min_true_capture_fraction);
end

if wrong_capture > cfg.closure.max_wrong_capture_fraction
    error('EXP02_FAIR_R2A:ClosureWrongCaptureFailed', ...
        'Wrong branch captured %.6f > %.6f.', ...
        wrong_capture,cfg.closure.max_wrong_capture_fraction);
end

closure = struct();
closure.x = x;
closure.focus_true = f_true;
closure.focus_wrong = f_wrong;
closure.residual_true = r_true;
closure.residual_wrong = r_wrong;
closure.info_true = info_true;
closure.info_wrong = info_wrong;
closure.true_capture_fraction = true_capture;
closure.wrong_capture_fraction = wrong_capture;
closure.capture_ratio = true_capture/max(wrong_capture,eps);

end

%% ========================================================================
function M = image_metrics(I,energy_fraction)

P = abs(I).^2;
S = sum(P(:));

prob = P/max(S,eps);
nz = prob>0;
H = -sum(prob(nz).*log(prob(nz)));

az = sum(P,2);
W = shortest_energy_interval_width(az,energy_fraction);

C = max(P(:))/max(S,eps);

M = struct();
M.entropy = H;
M.azimuth_w80 = W;
M.peak_concentration = C;

end

%% ========================================================================
function width = shortest_energy_interval_width(profile,fraction)

p = double(profile(:));
total = sum(p);

if total <= eps
    width = numel(p);
    return;
end

target = fraction*total;
N = numel(p);
best = N;

for i = 1:N
    s = 0;
    for j = i:N
        s = s+p(j);
        if s >= target
            best = min(best,j-i+1);
            break;
        end
    end
end

width = best;

end

%% ========================================================================
function q = nearest_periodic_rep_vec(q,ref,N)
% Return the N-periodic representative of each q nearest to ref.

q = q(:).';
ref = ref(:).';

delta = mod((q-ref)+N/2,N)-N/2;
q = ref+delta;

end

%% ========================================================================
function d = circular_bin_distance_vec(a,b,N)

a = a(:);
b = b(:);
d = abs(mod((a-b)+N/2,N)-N/2);

end
