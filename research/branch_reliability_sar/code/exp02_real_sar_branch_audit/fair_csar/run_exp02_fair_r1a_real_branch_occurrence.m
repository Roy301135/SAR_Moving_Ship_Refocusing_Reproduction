%% run_exp02_fair_r1a_real_branch_occurrence.m
% EXP02-FAIR-R1A
% Real Branch-State Occurrence Audit on the already validated FAIR-CSAR
% Candidate-B dominant recurrent component family.
%
% R1A DOES NOT:
%   - reselect the ship;
%   - reselect the crop;
%   - search for a new FrAc component family;
%   - run Proposed / Refined-LR / FiveBin;
%   - change Neighbor-3 radius;
%   - perform inverse focusing;
%   - inspect a second FAIR-CSAR ship.
%
% R1A asks only:
%   Under the frozen G0/N3 search semantics, do the real component states
%   already accepted by R0 naturally contain discrete-first branch failure,
%   and can Neighbor-3 recover the global continuous branch?
%
% Upload after run:
%   EXP02_FAIR_R1A_FEEDBACK.txt
%   01_frequency_and_error_audit.png
%   02_branch_taxonomy_map.png
%   03_selected_objective_landscapes.png
%   04_margin_vs_g0_error.png

clear; clc; close all;

%% 0. Resolve repository paths
this_file = mfilename('fullpath');
fair_code_dir = fileparts(this_file);
exp02_code_dir = fileparts(fair_code_dir);
code_dir = fileparts(exp02_code_dir);
research_dir = fileparts(code_dir);
research_parent = fileparts(research_dir);
repo_root = fileparts(research_parent);

addpath(fair_code_dir);
addpath(genpath(fullfile(research_dir,'functions')));

cfg = config_exp02_fair_r1a(research_dir,repo_root);

if ~exist(cfg.results_dir,'dir')
    mkdir(cfg.results_dir);
end

%% 1. Contract checks
required_files = {cfg.mat_path,cfg.r0_workspace,cfg.component_workspace};

for i = 1:numel(required_files)
    if exist(required_files{i},'file') ~= 2
        error('EXP02_FAIR_R1A:MissingInput', ...
            'Required input/workspace missing: %s',required_files{i});
    end
end

if exist('branch_real_g0_neighbor3_audit','file') ~= 2
    error('EXP02_FAIR_R1A:MissingFunction', ...
        'branch_real_g0_neighbor3_audit.m is not on the MATLAB path.');
end

if exist('branch_refine_from_seed','file') ~= 2 || ...
        exist('branch_tone_objective','file') ~= 2
    error('EXP02_FAIR_R1A:MissingFrozenBranchFunctions', ...
        ['Frozen branch_refine_from_seed.m / branch_tone_objective.m ' ...
         'must remain available in research/branch_reliability_sar/functions.']);
end

%% 2. Load exact accepted R0 state
R = load(cfg.r0_workspace,'cfg','r1','r2','c1','c2','target_global');

C = load(cfg.component_workspace, ...
    'cfg','target_global','matched','matched_order', ...
    'dominant_center','dominant_support','dominant_run', ...
    'dominant_gate_pass','cluster_tolerance');

if ~strcmp(R.cfg.stem,cfg.stem) || ~strcmp(C.cfg.stem,cfg.stem)
    error('EXP02_FAIR_R1A:StemMismatch', ...
        'Saved R0 workspaces do not match the frozen Candidate B.');
end

if ~isequal(R.target_global(:),C.target_global(:))
    error('EXP02_FAIR_R1A:TargetSelectionDrift', ...
        'R0 target line order differs from component-gate workspace.');
end

if ~C.dominant_gate_pass
    error('EXP02_FAIR_R1A:R0GateNotPassed', ...
        'R1A requires the accepted R0 component-consistency gate.');
end

matched = logical(C.matched(:));
source_line_idx = find(matched);
range_columns = C.target_global(matched);
p_beta = C.matched_order(matched);

n_cases = numel(source_line_idx);

if n_cases ~= cfg.expected_matched_lines
    error('EXP02_FAIR_R1A:MatchedCountDrift', ...
        ['Expected exactly %d R0-matched dominant-component lines, ' ...
         'but workspace contains %d. Stop rather than silently changing R1A.'], ...
        cfg.expected_matched_lines,n_cases);
end

if any(~isfinite(p_beta))
    error('EXP02_FAIR_R1A:NonfiniteOrder', ...
        'A matched R0 line contains nonfinite component order.');
end

%% 3. Load real complex SLC
[S,mat_info] = fair_csar_load_complex_mat(cfg.mat_path);
S = double(S);

if R.r1 < 1 || R.r2 > size(S,1)
    error('EXP02_FAIR_R1A:CropOutOfBounds', ...
        'Saved R0 row crop is outside current complex MAT.');
end

%% 4. R1 interface self-test: calibrated p_beta -> dechirp -> branch search
run_r1_interface_self_test(cfg);

%% 5. Audit the 8 frozen real component-line pairs
fprintf('============================================================\n');
fprintf('EXP02-FAIR-R1A REAL BRANCH-STATE OCCURRENCE AUDIT\n');
fprintf('Candidate               : %s\n',cfg.stem);
fprintf('R0 dominant center      : %.4f\n',C.dominant_center);
fprintf('R0 matched real states  : %d\n',n_cases);
fprintf('Branch-match tolerance  : %.4f bin\n', ...
    cfg.stage.branch_match_tolerance_bins);
fprintf('Catastrophic threshold  : %.4f bin\n', ...
    cfg.stage.catastrophic_error_threshold_bins);
fprintf('Global reference        : full-period, eval-only, OS=%d\n', ...
    cfg.stage.global_oversample);
fprintf('Proposed scheduler      : NOT RUN\n');
fprintf('============================================================\n\n');

Audit = struct([]);

for k = 1:n_cases
    col = range_columns(k);
    x = S(R.r1:R.r2,col);
    N = numel(x);

    a_dechirp = pbeta_to_sampled_a(p_beta(k),N,cfg);

    Ak = branch_real_g0_neighbor3_audit( ...
        x,a_dechirp,cfg.stage);

    Ak.source_r0_line_index = source_line_idx(k);
    Ak.range_column = col;
    Ak.p_beta = p_beta(k);

    if k == 1
        Audit = repmat(Ak,n_cases,1);
    else
        Audit(k) = Ak;
    end

    fprintf(['case %d/%d | R0 line=%d | col=%d | p=%.3f | ' ...
        'G0 err=%.5f | N3 err=%.5f | %s\n'], ...
        k,n_cases,source_line_idx(k),col,p_beta(k), ...
        Ak.g0_error_bins,Ak.n3_error_bins,char(Ak.taxonomy));
end

%% 6. Compact result table
Case = (1:n_cases).';
SourceR0Line = source_line_idx(:);
RangeColumn = range_columns(:);
Pbeta = p_beta(:);
% IMPORTANT:
% Audit is preallocated as an n_cases-by-1 struct array. Keep every table
% variable explicitly as an n_cases-by-1 column. Do NOT transpose arrayfun
% outputs here: doing so turns them into 1-by-n_cases rows and MATLAB table()
% rejects the mixed row counts.
ADechirp = reshape(arrayfun(@(s) s.a_dechirp,Audit),[],1);

CoarseTop1Bin = reshape(arrayfun(@(s) s.coarse_top1_bin,Audit),[],1);
GlobalNu = reshape(arrayfun(@(s) s.global_nu_bins,Audit),[],1);
G0Nu = reshape(arrayfun(@(s) s.g0_nu_wrapped,Audit),[],1);
N3Nu = reshape(arrayfun(@(s) s.n3_nu_wrapped,Audit),[],1);

G0ErrorBins = reshape(arrayfun(@(s) s.g0_error_bins,Audit),[],1);
N3ErrorBins = reshape(arrayfun(@(s) s.n3_error_bins,Audit),[],1);

CoarseMargin = reshape(arrayfun(@(s) s.coarse_top1_top2_margin,Audit),[],1);
G0ObjectiveLoss = reshape(arrayfun(@(s) s.g0_objective_loss_vs_global,Audit),[],1);
N3ObjectiveLoss = reshape(arrayfun(@(s) s.n3_objective_loss_vs_global,Audit),[],1);

N3CandidateCoverage = reshape(arrayfun(@(s) s.n3_candidate_coverage,Audit),[],1);
G0Catastrophic = reshape(arrayfun(@(s) s.g0_catastrophic,Audit),[],1);
N3Catastrophic = reshape(arrayfun(@(s) s.n3_catastrophic,Audit),[],1);

TaxonomyCell = arrayfun(@(s) char(s.taxonomy),Audit,'UniformOutput',false);
Taxonomy = reshape(string(TaxonomyCell),[],1);

table_vars = { ...
    Case,SourceR0Line,RangeColumn,Pbeta,ADechirp, ...
    CoarseTop1Bin,GlobalNu,G0Nu,N3Nu, ...
    G0ErrorBins,N3ErrorBins,CoarseMargin, ...
    G0ObjectiveLoss,N3ObjectiveLoss,N3CandidateCoverage, ...
    G0Catastrophic,N3Catastrophic,Taxonomy};

table_heights = cellfun(@(v) size(v,1),table_vars);
if any(table_heights ~= n_cases)
    error('EXP02_FAIR_R1A:TableShapeMismatch', ...
        'Internal table column heights are inconsistent: %s', ...
        mat2str(table_heights));
end

T = table( ...
    Case,SourceR0Line,RangeColumn,Pbeta,ADechirp, ...
    CoarseTop1Bin,GlobalNu,G0Nu,N3Nu, ...
    G0ErrorBins,N3ErrorBins,CoarseMargin, ...
    G0ObjectiveLoss,N3ObjectiveLoss,N3CandidateCoverage, ...
    G0Catastrophic,N3Catastrophic,Taxonomy);

writetable(T,fullfile(cfg.results_dir,'EXP02_FAIR_R1A_line_metrics.csv'));

%% 7. Summary / frozen stop rule
is_safe = Taxonomy=="SAFE";
is_rescue = Taxonomy=="G0_FAIL_N3_RESCUE";
is_miss = Taxonomy=="N3_COVERAGE_MISS";
is_persist = Taxonomy=="PERSISTENT_WITHIN_COVERAGE";

n_safe = sum(is_safe);
n_rescue = sum(is_rescue);
n_miss = sum(is_miss);
n_persist = sum(is_persist);
n_g0_fail = n_cases-n_safe;
n_g0_cat = sum(G0Catastrophic);
n_n3_cat = sum(N3Catastrophic);

if n_rescue > 0
    stop_decision = "R1A_NATURAL_RESCUE_OBSERVED__PROCEED_R1B";
elseif n_g0_fail > 0
    stop_decision = "R1A_BRANCH_FAILURE_WITHOUT_RESCUE__PROCEED_R1B_NO_RETUNE";
else
    stop_decision = "R1A_ALL_SAFE__PROCEED_R1B_EXPANSION_NO_RETUNE";
end

%% 8. Figure 1: frequencies and errors
fig1 = figure('Color','w','Name','FAIR R1A frequency/error audit');
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

nexttile;
plot(RangeColumn,GlobalNu,'o-','LineWidth',1.1,'DisplayName','global reference');
hold on;
plot(RangeColumn,G0Nu,'s--','LineWidth',1.0,'DisplayName','G0');
plot(RangeColumn,N3Nu,'d-.','LineWidth',1.0,'DisplayName','Neighbor-3');
hold off;
xlabel('Range column');
ylabel('\nu (DFT bins)');
title('Real branch estimates on frozen R0 component states');
legend('Location','best');
grid on;

nexttile;
plot(RangeColumn,G0ErrorBins,'o-','LineWidth',1.1,'DisplayName','G0 error');
hold on;
plot(RangeColumn,N3ErrorBins,'s--','LineWidth',1.0,'DisplayName','N3 error');
yline(cfg.stage.branch_match_tolerance_bins,':','branch match tolerance');
yline(cfg.stage.catastrophic_error_threshold_bins,'--','catastrophic threshold');
hold off;
xlabel('Range column');
ylabel('Circular error to global reference (bins)');
title('Occurrence severity under frozen search semantics');
legend('Location','best');
grid on;

exportgraphics(fig1, ...
    fullfile(cfg.results_dir,'01_frequency_and_error_audit.png'), ...
    'Resolution',cfg.figure_resolution);

%% 9. Figure 2: taxonomy spatial map
fig2 = figure('Color','w','Name','FAIR R1A branch taxonomy');

tax_order = [ ...
    "SAFE", ...
    "G0_FAIL_N3_RESCUE", ...
    "N3_COVERAGE_MISS", ...
    "PERSISTENT_WITHIN_COVERAGE"];

tax_y = zeros(n_cases,1);
for k = 1:n_cases
    tax_y(k) = find(tax_order==Taxonomy(k),1);
end

scatter(RangeColumn,tax_y,65,'filled');
hold on;

for k = 1:n_cases
    text(RangeColumn(k),tax_y(k)+0.08,sprintf('p=%.2f',Pbeta(k)), ...
        'HorizontalAlignment','center','FontSize',8);
end

hold off;
yticks(1:numel(tax_order));
yticklabels(tax_order);
ylim([0.5 numel(tax_order)+0.5]);
xlabel('Range column');
ylabel('Branch-state taxonomy');
title(sprintf('R1A real occurrence | S=%d R=%d M=%d P=%d', ...
    n_safe,n_rescue,n_miss,n_persist));
grid on;

exportgraphics(fig2, ...
    fullfile(cfg.results_dir,'02_branch_taxonomy_map.png'), ...
    'Resolution',cfg.figure_resolution);

%% 10. Figure 3: selected objective landscapes
priority = [find(is_rescue); find(is_miss); find(is_persist)];

if isempty(priority)
    [~,ord_err] = sort(G0ErrorBins,'descend');
    priority = ord_err(:);
else
    remaining = setdiff((1:n_cases).',priority,'stable');
    [~,ord_rem] = sort(G0ErrorBins(remaining),'descend');
    priority = [priority; remaining(ord_rem)];
end

n_show = min(cfg.max_landscape_examples,numel(priority));
show_idx = priority(1:n_show);

fig3 = figure('Color','w','Name','FAIR R1A selected objective landscapes');
tiledlayout(n_show,1,'Padding','compact','TileSpacing','compact');

for ii = 1:n_show
    k = show_idx(ii);
    A = Audit(k);

    ref = A.global_nu_bins;
    g0p = nearest_periodic_rep(A.g0_nu_wrapped,ref,A.N);
    n3p = nearest_periodic_rep(A.n3_nu_wrapped,ref,A.N);
    candp = arrayfun(@(q) nearest_periodic_rep(q,ref,A.N), ...
        A.N3_candidate_nu_wrapped);

    anchors = [ref,g0p,n3p,candp(:).'];
    qmin = min(anchors)-1.0;
    qmax = max(anchors)+1.0;
    q = linspace(qmin,qmax,2001);

    J = zeros(size(q));
    for iq = 1:numel(q)
        J(iq) = branch_tone_objective(A.dechirped_signal,q(iq));
    end
    J = J/max(J);

    nexttile;
    plot(q,J,'LineWidth',1.1);
    hold on;
    xline(ref,':','global');
    xline(g0p,'--','G0');
    xline(n3p,'-.','N3');
    hold off;

    xlabel('\nu (DFT bins; unwrapped around global reference)');
    ylabel('Normalized J');
    title(sprintf('col=%d | p=%.2f | %s | G0 err=%.4f', ...
        RangeColumn(k),Pbeta(k),Taxonomy(k),G0ErrorBins(k)));
    grid on;
end

exportgraphics(fig3, ...
    fullfile(cfg.results_dir,'03_selected_objective_landscapes.png'), ...
    'Resolution',cfg.figure_resolution);

%% 11. Figure 4: coarse margin vs G0 displacement
fig4 = figure('Color','w','Name','FAIR R1A coarse margin versus G0 error');

scatter(CoarseMargin,G0ErrorBins,70,'filled');
hold on;
yline(cfg.stage.branch_match_tolerance_bins,':','branch match tolerance');
yline(cfg.stage.catastrophic_error_threshold_bins,'--','catastrophic threshold');

for k = 1:n_cases
    text(CoarseMargin(k),G0ErrorBins(k),sprintf('  c%d',RangeColumn(k)), ...
        'FontSize',8);
end

hold off;
xlabel('(J_{(1)}-J_{(2)}) / J_{(1)}');
ylabel('G0 circular error to global reference (bins)');
title('Coarse ranking margin versus real G0 branch displacement');
grid on;

exportgraphics(fig4, ...
    fullfile(cfg.results_dir,'04_margin_vs_g0_error.png'), ...
    'Resolution',cfg.figure_resolution);

%% 12. Save workspace
save(fullfile(cfg.results_dir,'EXP02_FAIR_R1A_workspace.mat'), ...
    'cfg','R','C','Audit','T', ...
    'n_safe','n_rescue','n_miss','n_persist', ...
    'n_g0_fail','n_g0_cat','n_n3_cat','stop_decision');

%% 13. Feedback bundle
txt_path = fullfile(cfg.results_dir,'EXP02_FAIR_R1A_FEEDBACK.txt');
fid = fopen(txt_path,'w');

if fid < 0
    error('EXP02_FAIR_R1A:FeedbackOpenFailed', ...
        'Cannot open feedback bundle for writing.');
end

cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-R1A REAL BRANCH-STATE OCCURRENCE AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Proposed=NOT_RUN\n');
fprintf(fid,'RefinedLR=NOT_RUN\n');
fprintf(fid,'FiveBin=NOT_RUN\n');
fprintf(fid,'Second_FAIR_ship=NOT_USED\n');
fprintf(fid,'Inverse_focus=NOT_RUN\n\n');

fprintf(fid,'[FROZEN INPUT]\n');
fprintf(fid,'stem=%s\n',cfg.stem);
fprintf(fid,'crop_rows=%d:%d\n',R.r1,R.r2);
fprintf(fid,'crop_columns=%d:%d\n',R.c1,R.c2);
fprintf(fid,'R0_dominant_center=%.9g\n',C.dominant_center);
fprintf(fid,'R0_dominant_support=%d\n',C.dominant_support);
fprintf(fid,'R0_dominant_run=%d\n',C.dominant_run);
fprintf(fid,'R1A_matched_states=%d\n',n_cases);
fprintf(fid,'range_columns=%s\n',mat2str(RangeColumn.'));
fprintf(fid,'matched_p_beta=%s\n\n',mat2str(Pbeta.',4));

fprintf(fid,'[FROZEN BRANCH SEMANTICS]\n');
fprintf(fid,'local_search_halfwidth_bins=%.9g\n', ...
    cfg.stage.local_search_halfwidth_bins);
fprintf(fid,'local_bracket_points=%d\n',cfg.stage.local_bracket_points);
fprintf(fid,'neighbor_radius=%d\n',cfg.stage.neighbor_radius);
fprintf(fid,'branch_match_tolerance_bins=%.9g\n', ...
    cfg.stage.branch_match_tolerance_bins);
fprintf(fid,'catastrophic_error_threshold_bins=%.9g\n', ...
    cfg.stage.catastrophic_error_threshold_bins);
fprintf(fid,'global_reference=full_period_continuous_same_objective_eval_only\n');
fprintf(fid,'global_oversample=%d\n\n',cfg.stage.global_oversample);

fprintf(fid,'[P_BETA TO DECHIRP MAPPING]\n');
fprintf(fid,'t_norm_span=%g\n',cfg.tnorm_full_span);
fprintf(fid,['a_sample = tan(pi*p_beta/2) * ' ...
    '(tnorm_full_span/(N-1))^2\n\n']);

fprintf(fid,'[R1A COUNTS]\n');
fprintf(fid,'SAFE=%d/%d\n',n_safe,n_cases);
fprintf(fid,'G0_FAIL_N3_RESCUE=%d/%d\n',n_rescue,n_cases);
fprintf(fid,'N3_COVERAGE_MISS=%d/%d\n',n_miss,n_cases);
fprintf(fid,'PERSISTENT_WITHIN_COVERAGE=%d/%d\n',n_persist,n_cases);
fprintf(fid,'G0_fail_total=%d/%d\n',n_g0_fail,n_cases);
fprintf(fid,'G0_catastrophic=%d/%d\n',n_g0_cat,n_cases);
fprintf(fid,'N3_catastrophic=%d/%d\n',n_n3_cat,n_cases);
fprintf(fid,'stop_decision=%s\n\n',stop_decision);

fprintf(fid,'[PER-STATE AUDIT]\n');
fprintf(fid,['case\tR0line\tcol\tp_beta\ta_dechirp\tcoarse_k0\t' ...
    'global_nu\tG0_nu\tN3_nu\tG0_err\tN3_err\tcoarse_margin\t' ...
    'G0_obj_loss\tN3_obj_loss\tN3_coverage\tG0_cat\tN3_cat\ttaxonomy\n']);

for k = 1:n_cases
    fprintf(fid,['%d\t%d\t%d\t%.6f\t%.12g\t%d\t%.9g\t%.9g\t%.9g\t' ...
        '%.9g\t%.9g\t%.9g\t%.9g\t%.9g\t%d\t%d\t%d\t%s\n'], ...
        Case(k),SourceR0Line(k),RangeColumn(k),Pbeta(k),ADechirp(k), ...
        CoarseTop1Bin(k),GlobalNu(k),G0Nu(k),N3Nu(k), ...
        G0ErrorBins(k),N3ErrorBins(k),CoarseMargin(k), ...
        G0ObjectiveLoss(k),N3ObjectiveLoss(k),N3CandidateCoverage(k), ...
        G0Catastrophic(k),N3Catastrophic(k),Taxonomy(k));
end

fprintf(fid,'\n[INTERPRETATION BOUNDARY]\n');
fprintf(fid,['The global continuous winner is an evaluation reference for the ' ...
    'same dechirped tone objective; it is NOT physical ground truth for the ' ...
    'ship motion or scattering component.\n']);
fprintf(fid,['R1A is conditional on the already accepted R0 component order. ' ...
    'It audits discrete-first branch occurrence under that frozen dechirp ' ...
    'state and does not estimate a hidden true beta.\n']);
fprintf(fid,['No R1A outcome is allowed to retune the coarse grid, local window, ' ...
    'Neighbor-3 radius, match tolerance, or catastrophic threshold.\n']);

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,'1) EXP02_FAIR_R1A_FEEDBACK.txt\n');
fprintf(fid,'2) 01_frequency_and_error_audit.png\n');
fprintf(fid,'3) 02_branch_taxonomy_map.png\n');
fprintf(fid,'4) 03_selected_objective_landscapes.png\n');
fprintf(fid,'5) 04_margin_vs_g0_error.png\n');

fprintf('\n============================================================\n');
fprintf('R1A complete.\n');
fprintf('SAFE=%d | RESCUE=%d | MISS=%d | PERSIST=%d\n', ...
    n_safe,n_rescue,n_miss,n_persist);
fprintf('G0 catastrophic=%d/%d\n',n_g0_cat,n_cases);
fprintf('Stop decision: %s\n',stop_decision);
fprintf('Feedback: %s\n',txt_path);
fprintf('============================================================\n');

%% ========================================================================
function a = pbeta_to_sampled_a(p_beta,N,cfg)

scale = cfg.tnorm_full_span/(N-1);
a = tan(pi*p_beta/2) * scale^2;

end

%% ========================================================================
function run_r1_interface_self_test(cfg)
% Verify the R0 p_beta convention, sampled quadratic mapping, and branch
% code agree before touching the real R1A states.

N = 310;
m = 0:N-1;

p_test = 0.78;
nu_true = 4.37;

a = pbeta_to_sampled_a(p_test,N,cfg);

x = exp(1j*pi*a*m.^2 + 1j*2*pi*nu_true*m/N);

A = branch_real_g0_neighbor3_audit(x,a,cfg.stage);

d_global = circular_bin_distance_local(A.global_nu_bins,nu_true,N);
d_g0 = circular_bin_distance_local(A.g0_nu_wrapped,nu_true,N);
d_n3 = circular_bin_distance_local(A.n3_nu_wrapped,nu_true,N);

if d_global > 1e-6 || ...
        d_g0 > cfg.stage.branch_match_tolerance_bins || ...
        d_n3 > cfg.stage.branch_match_tolerance_bins
    error('EXP02_FAIR_R1A:InterfaceSelfTestFailed', ...
        ['R1 p_beta->dechirp interface self-test failed. ' ...
         'global=%.3g, G0=%.3g, N3=%.3g bin.'], ...
        d_global,d_g0,d_n3);
end

fprintf('R1 interface self-test PASS: global=%.3g, G0=%.3g, N3=%.3g bin\n\n', ...
    d_global,d_g0,d_n3);

end

%% ========================================================================
function d = circular_bin_distance_local(a,b,N)

d = abs(mod((a-b)+N/2,N)-N/2);

end

%% ========================================================================
function q = nearest_periodic_rep(q,ref,N)
% Return the N-periodic representative of q nearest to ref.

delta = mod((q-ref)+N/2,N)-N/2;
q = ref + delta;

end
