%% run_exp02_fair_r1b_full_frozen_pool_occurrence.m
% EXP02-FAIR-R1B
% Full Frozen-Pool Component -> Branch Occurrence Audit
%
% Scientific question:
%   Across the COMPLETE ship-line pool frozen before R0 interpretation
%   (Wang-style E(n)>mean(E) inside Candidate-B crop), how many
%   statistically supported real component states exhibit:
%       SAFE
%       G0_FAIL_N3_RESCUE
%       N3_COVERAGE_MISS
%       PERSISTENT_WITHIN_COVERAGE
%   under the unchanged branch-search semantics?
%
% Important:
%   - Branch auditing is conditional on a line/component passing the same
%     corrected Eq.(31) + phase-permutation max-statistic local-peak gate.
%   - No p=0.78 is imposed on other lines.
%   - Proposed / Refined-LR / FiveBin are NOT run.
%
% Upload after run:
%   EXP02_FAIR_R1B_FEEDBACK.txt
%   01_component_state_map.png
%   02_branch_occurrence_map.png
%   03_occurrence_summary.png
%   04_selected_branch_landscapes.png
%
% Keep CSV/MAT locally.

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
addpath(genpath(fullfile(repo_root,'papers')));

cfg = config_exp02_fair_r1b(research_dir,repo_root);

if ~exist(cfg.results_dir,'dir')
    mkdir(cfg.results_dir);
end

%% 1. Contract checks
required_files = {cfg.mat_path,cfg.r0_workspace};
for i = 1:numel(required_files)
    if exist(required_files{i},'file') ~= 2
        error('EXP02_FAIR_R1B:MissingInput', ...
            'Required input/workspace missing: %s',required_files{i});
    end
end

required_fns = { ...
    'fair_csar_fractional_line_audit', ...
    'fair_csar_load_complex_mat', ...
    'branch_real_g0_neighbor3_audit', ...
    'branch_refine_from_seed', ...
    'branch_tone_objective'};

for i = 1:numel(required_fns)
    if exist(required_fns{i},'file') ~= 2
        error('EXP02_FAIR_R1B:MissingFunction', ...
            'Required function is not on path: %s',required_fns{i});
    end
end

%% 2. Load exact frozen R0 pool
R = load(cfg.r0_workspace, ...
    'cfg','r1','r2','c1','c2', ...
    'target_global_all','p_grid');

if ~strcmp(R.cfg.stem,cfg.stem)
    error('EXP02_FAIR_R1B:StemMismatch', ...
        'Saved R0 workspace does not match frozen Candidate B.');
end

frozen_cols = R.target_global_all(:).';
p_grid = R.p_grid(:).';

n_lines = numel(frozen_cols);
Np = numel(p_grid);

if n_lines < 1
    error('EXP02_FAIR_R1B:EmptyPool','Frozen R0 ship-line pool is empty.');
end

fprintf('============================================================\n');
fprintf('EXP02-FAIR-R1B FULL FROZEN-POOL OCCURRENCE AUDIT\n');
fprintf('Candidate            : %s\n',cfg.stem);
fprintf('Frozen ship lines    : %d\n',n_lines);
fprintf('Surrogates / line    : %d\n',cfg.n_surrogates);
fprintf('p=1 guard            : |p-1| <= %.2f\n',cfg.phase_guard_halfwidth);
fprintf('N3 radius            : %d\n',cfg.stage.neighbor_radius);
fprintf('Proposed scheduler   : NOT RUN\n');
fprintf('============================================================\n\n');

%% 3. Load real complex SLC
[S,mat_info] = fair_csar_load_complex_mat(cfg.mat_path);
S = double(S);

if R.r1 < 1 || R.r2 > size(S,1)
    error('EXP02_FAIR_R1B:CropOutOfBounds', ...
        'Saved R0 row crop is outside current complex MAT.');
end

%% 4. Interface self-test inherited from R1A
run_r1b_interface_self_test(cfg);

%% 5. Frozen component-screening gate over ALL R0 ship lines
guard_mask = abs(p_grid-cfg.phase_blind_order) > ...
    (cfg.phase_guard_halfwidth + 1e-12);

if ~any(guard_mask)
    error('EXP02_FAIR_R1B:EmptyNondegenerateGrid', ...
        'Nondegenerate order grid is empty.');
end

rng(cfg.phase_rng_seed,'twister');

line_threshold = nan(n_lines,1);
line_n_components = zeros(n_lines,1);
line_peak_orders = cell(n_lines,1);
line_peak_values = cell(n_lines,1);
line_peak_excess = cell(n_lines,1);

% State arrays are dynamic because each line can support 0..K components.
StateLineIndex = [];
StateRangeColumn = [];
StatePbeta = [];
StateFracEnergy = [];
StateExcessAboveMaxStat95 = [];

for il = 1:n_lines
    col = frozen_cols(il);
    x = S(R.r1:R.r2,col);

    real_audit = fair_csar_fractional_line_audit( ...
        x,p_grid,R.cfg.frac_exclude_zero_lags);

    real_curve = real_audit.frac_energy;

    amp = abs(x(:).');
    ph = angle(x(:).');

    surrogate_max_nondeg = zeros(cfg.n_surrogates,1);

    for is = 1:cfg.n_surrogates
        perm = randperm(numel(ph));
        xs = amp .* exp(1j*ph(perm));

        as = fair_csar_fractional_line_audit( ...
            xs,p_grid,R.cfg.frac_exclude_zero_lags);

        surrogate_max_nondeg(is) = max(as.frac_energy(guard_mask));
    end

    q95 = vector_percentile(surrogate_max_nondeg, ...
        cfg.surrogate_max_percentile);

    line_threshold(il) = q95;

    % Strict local maxima; endpoints excluded.
    is_local = false(1,Np);
    for ip = 2:(Np-1)
        is_local(ip) = ...
            (real_curve(ip) > real_curve(ip-1)) && ...
            (real_curve(ip) >= real_curve(ip+1));
    end

    candidate_idx = find( ...
        is_local & guard_mask & (real_curve > q95));

    keep_idx = nms_peak_indices( ...
        candidate_idx,real_curve,p_grid,cfg.within_line_nms_tolerance);

    line_n_components(il) = numel(keep_idx);
    line_peak_orders{il} = p_grid(keep_idx);
    line_peak_values{il} = real_curve(keep_idx);
    line_peak_excess{il} = real_curve(keep_idx)-q95;

    for jj = 1:numel(keep_idx)
        ip = keep_idx(jj);

        StateLineIndex(end+1,1) = il; %#ok<AGROW>
        StateRangeColumn(end+1,1) = col; %#ok<AGROW>
        StatePbeta(end+1,1) = p_grid(ip); %#ok<AGROW>
        StateFracEnergy(end+1,1) = real_curve(ip); %#ok<AGROW>
        StateExcessAboveMaxStat95(end+1,1) = real_curve(ip)-q95; %#ok<AGROW>
    end

    fprintf('component screen %2d/%2d | col=%d | accepted=%d | p=%s\n', ...
        il,n_lines,col,numel(keep_idx),mat2str(p_grid(keep_idx),3));
end

n_states = numel(StatePbeta);
n_lines_with_state = sum(line_n_components>0);
n_lines_without_state = n_lines-n_lines_with_state;

fprintf('\nAccepted real component states: %d across %d/%d ship lines\n\n', ...
    n_states,n_lines_with_state,n_lines);

if n_states < 1
    stop_decision = "R1B_NO_VALID_COMPONENT_STATES__DO_NOT_BRANCH_AUDIT";
    write_empty_feedback_and_stop(cfg,R,n_lines,line_n_components,stop_decision);
    return;
end

%% 6. Branch occurrence audit on every accepted component state
Audit = struct([]);

for is = 1:n_states
    il = StateLineIndex(is);
    col = StateRangeColumn(is);
    p_beta = StatePbeta(is);

    x = S(R.r1:R.r2,col);
    N = numel(x);

    a_dechirp = pbeta_to_sampled_a(p_beta,N,cfg);

    A = branch_real_g0_neighbor3_audit( ...
        x,a_dechirp,cfg.stage);

    A.state_id = is;
    A.source_pool_line_index = il;
    A.range_column = col;
    A.p_beta = p_beta;
    A.frac_energy = StateFracEnergy(is);
    A.frac_excess_above_maxstat95 = StateExcessAboveMaxStat95(is);

    if is == 1
        Audit = repmat(A,n_states,1);
    else
        Audit(is) = A;
    end

    fprintf(['branch state %3d/%3d | line=%d col=%d p=%.3f | ' ...
        'G0=%.5g N3=%.5g | %s\n'], ...
        is,n_states,il,col,p_beta,A.g0_error_bins,A.n3_error_bins, ...
        char(A.taxonomy));
end

%% 7. Compact state table
StateID = (1:n_states).';
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

T = table( ...
    StateID,StateLineIndex,StateRangeColumn,StatePbeta, ...
    StateFracEnergy,StateExcessAboveMaxStat95,ADechirp, ...
    CoarseTop1Bin,GlobalNu,G0Nu,N3Nu, ...
    G0ErrorBins,N3ErrorBins,CoarseMargin, ...
    G0ObjectiveLoss,N3ObjectiveLoss,N3CandidateCoverage, ...
    G0Catastrophic,N3Catastrophic,Taxonomy);

writetable(T,fullfile(cfg.results_dir,'EXP02_FAIR_R1B_state_metrics.csv'));

%% 8. Occurrence summary
is_safe = Taxonomy=="SAFE";
is_rescue = Taxonomy=="G0_FAIL_N3_RESCUE";
is_miss = Taxonomy=="N3_COVERAGE_MISS";
is_persist = Taxonomy=="PERSISTENT_WITHIN_COVERAGE";

n_safe = sum(is_safe);
n_rescue = sum(is_rescue);
n_miss = sum(is_miss);
n_persist = sum(is_persist);

n_g0_fail = n_states-n_safe;
n_g0_cat = sum(G0Catastrophic);
n_n3_cat = sum(N3Catastrophic);

g0_fail_rate = n_g0_fail/n_states;

if n_g0_fail > 0
    n3_rescue_given_fail = n_rescue/n_g0_fail;
else
    n3_rescue_given_fail = NaN;
end

if n_rescue > 0
    stop_decision = "R1B_NATURAL_RESCUE_OBSERVED__CANDIDATE_B_OCCURRENCE_CONFIRMED";
elseif n_g0_fail > 0
    stop_decision = "R1B_BRANCH_FAILURE_OBSERVED_WITHOUT_N3_RESCUE__NO_RETUNE";
else
    stop_decision = "R1B_ALL_VALID_COMPONENT_STATES_SAFE__MOVE_TO_SECOND_PREREGISTERED_FAIR_CANDIDATE";
end

%% 9. Figure 1: accepted component state map
fig1 = figure('Color','w','Name','FAIR R1B component state map');

scatter(StateRangeColumn,StatePbeta, ...
    45+400*normalize01(StateExcessAboveMaxStat95), ...
    StateFracEnergy,'filled');

xlabel('Range column');
ylabel('Accepted nondegenerate FrAc order p_\beta');
title(sprintf('FWER-guarded real component states | %d states on %d/%d ship lines', ...
    n_states,n_lines_with_state,n_lines));
grid on;
colorbar;

exportgraphics(fig1, ...
    fullfile(cfg.results_dir,'01_component_state_map.png'), ...
    'Resolution',cfg.figure_resolution);

%% 10. Figure 2: branch occurrence map
fig2 = figure('Color','w','Name','FAIR R1B branch occurrence map');

tax_order = [ ...
    "SAFE", ...
    "G0_FAIL_N3_RESCUE", ...
    "N3_COVERAGE_MISS", ...
    "PERSISTENT_WITHIN_COVERAGE"];

tax_y = zeros(n_states,1);
for k = 1:n_states
    tax_y(k) = find(tax_order==Taxonomy(k),1);
end

scatter(StateRangeColumn,tax_y,50,StatePbeta,'filled');
yticks(1:numel(tax_order));
yticklabels(tax_order);
ylim([0.5 numel(tax_order)+0.5]);
xlabel('Range column');
ylabel('Branch-state taxonomy');
title(sprintf('R1B occurrence | S=%d R=%d M=%d P=%d', ...
    n_safe,n_rescue,n_miss,n_persist));
grid on;
cb = colorbar;
ylabel(cb,'p_\beta');

exportgraphics(fig2, ...
    fullfile(cfg.results_dir,'02_branch_occurrence_map.png'), ...
    'Resolution',cfg.figure_resolution);

%% 11. Figure 3: occurrence summary
fig3 = figure('Color','w','Name','FAIR R1B occurrence summary');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
bar([n_safe n_rescue n_miss n_persist]);
xticks(1:4);
xticklabels({'SAFE','RESCUE','MISS','PERSIST'});
ylabel('Component states');
title(sprintf('Branch taxonomy | total=%d',n_states));
grid on;

nexttile;
scatter(CoarseMargin,G0ErrorBins,55,StatePbeta,'filled');
hold on;
yline(cfg.stage.branch_match_tolerance_bins,':','branch match');
yline(cfg.stage.catastrophic_error_threshold_bins,'--','catastrophic');
hold off;
xlabel('(J_{(1)}-J_{(2)}) / J_{(1)}');
ylabel('G0 error to global reference (bins)');
title('Coarse margin versus branch displacement');
grid on;
cb = colorbar;
ylabel(cb,'p_\beta');

exportgraphics(fig3, ...
    fullfile(cfg.results_dir,'03_occurrence_summary.png'), ...
    'Resolution',cfg.figure_resolution);

%% 12. Figure 4: selected branch landscapes
priority = [find(is_rescue); find(is_miss); find(is_persist)];

if isempty(priority)
    [~,ord] = sort(G0ErrorBins,'descend');
    priority = ord(:);
else
    rem = setdiff((1:n_states).',priority,'stable');
    [~,ord] = sort(G0ErrorBins(rem),'descend');
    priority = [priority; rem(ord)];
end

n_show = min(cfg.max_landscape_examples,numel(priority));
show_idx = priority(1:n_show);

fig4 = figure('Color','w','Name','FAIR R1B selected branch landscapes');
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

    xlabel('\nu (DFT bins; unwrapped around global)');
    ylabel('Normalized J');
    title(sprintf('state=%d | col=%d | p=%.2f | %s | G0 err=%.4g', ...
        k,StateRangeColumn(k),StatePbeta(k),Taxonomy(k),G0ErrorBins(k)));
    grid on;
end

exportgraphics(fig4, ...
    fullfile(cfg.results_dir,'04_selected_branch_landscapes.png'), ...
    'Resolution',cfg.figure_resolution);

%% 13. Save workspace
save(fullfile(cfg.results_dir,'EXP02_FAIR_R1B_workspace.mat'), ...
    'cfg','R','mat_info', ...
    'frozen_cols','p_grid','line_threshold','line_n_components', ...
    'line_peak_orders','line_peak_values','line_peak_excess', ...
    'StateLineIndex','StateRangeColumn','StatePbeta', ...
    'StateFracEnergy','StateExcessAboveMaxStat95', ...
    'Audit','T', ...
    'n_lines','n_lines_with_state','n_lines_without_state','n_states', ...
    'n_safe','n_rescue','n_miss','n_persist', ...
    'n_g0_fail','n_g0_cat','n_n3_cat', ...
    'g0_fail_rate','n3_rescue_given_fail','stop_decision');

%% 14. Feedback bundle
txt_path = fullfile(cfg.results_dir,'EXP02_FAIR_R1B_FEEDBACK.txt');
fid = fopen(txt_path,'w');

if fid < 0
    error('EXP02_FAIR_R1B:FeedbackOpenFailed', ...
        'Cannot open feedback bundle.');
end

cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-R1B FULL FROZEN-POOL OCCURRENCE AUDIT\n');
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
fprintf(fid,'frozen_Wang_selected_ship_lines=%d\n',n_lines);
fprintf(fid,'frozen_range_columns=%s\n\n',mat2str(frozen_cols));

fprintf(fid,'[COMPONENT SCREEN]\n');
fprintf(fid,'phase_rng_seed=%d\n',cfg.phase_rng_seed);
fprintf(fid,'surrogates_per_line=%d\n',cfg.n_surrogates);
fprintf(fid,'phase_blind_order=%.6f\n',cfg.phase_blind_order);
fprintf(fid,'phase_guard_halfwidth=%.6f\n',cfg.phase_guard_halfwidth);
fprintf(fid,'linewise_surrogate_max_percentile=%.1f\n', ...
    cfg.surrogate_max_percentile);
fprintf(fid,'within_line_nms_tolerance=%.6f\n', ...
    cfg.within_line_nms_tolerance);
fprintf(fid,'ship_lines_with_at_least_one_valid_component=%d/%d\n', ...
    n_lines_with_state,n_lines);
fprintf(fid,'ship_lines_without_valid_component=%d/%d\n', ...
    n_lines_without_state,n_lines);
fprintf(fid,'total_valid_component_states=%d\n\n',n_states);

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

fprintf(fid,'[OCCURRENCE COUNTS]\n');
fprintf(fid,'SAFE=%d/%d\n',n_safe,n_states);
fprintf(fid,'G0_FAIL_N3_RESCUE=%d/%d\n',n_rescue,n_states);
fprintf(fid,'N3_COVERAGE_MISS=%d/%d\n',n_miss,n_states);
fprintf(fid,'PERSISTENT_WITHIN_COVERAGE=%d/%d\n',n_persist,n_states);
fprintf(fid,'G0_fail_total=%d/%d\n',n_g0_fail,n_states);
fprintf(fid,'G0_fail_rate=%.12g\n',g0_fail_rate);

if isnan(n3_rescue_given_fail)
    fprintf(fid,'N3_rescue_given_G0_fail=NaN_no_G0_failures\n');
else
    fprintf(fid,'N3_rescue_given_G0_fail=%.12g\n',n3_rescue_given_fail);
end

fprintf(fid,'G0_catastrophic=%d/%d\n',n_g0_cat,n_states);
fprintf(fid,'N3_catastrophic=%d/%d\n',n_n3_cat,n_states);
fprintf(fid,'stop_decision=%s\n\n',stop_decision);

fprintf(fid,'[LINE-LEVEL COMPONENT COUNTS]\n');
for il = 1:n_lines
    fprintf(fid,'line_%02d col=%d n_components=%d orders=%s maxstat95=%.9g\n', ...
        il,frozen_cols(il),line_n_components(il), ...
        mat2str(line_peak_orders{il},3),line_threshold(il));
end

fprintf(fid,'\n[NON-SAFE STATE DETAILS]\n');
idx_bad = find(~is_safe);

if isempty(idx_bad)
    fprintf(fid,'NONE\n');
else
    for jj = 1:numel(idx_bad)
        k = idx_bad(jj);
        fprintf(fid,['state=%d line=%d col=%d p=%.6f taxonomy=%s ' ...
            'G0_err=%.9g N3_err=%.9g margin=%.9g coverage=%d ' ...
            'G0_cat=%d N3_cat=%d\n'], ...
            k,StateLineIndex(k),StateRangeColumn(k),StatePbeta(k), ...
            Taxonomy(k),G0ErrorBins(k),N3ErrorBins(k),CoarseMargin(k), ...
            N3CandidateCoverage(k),G0Catastrophic(k),N3Catastrophic(k));
    end
end

fprintf(fid,'\n[INTERPRETATION BOUNDARY]\n');
fprintf(fid,['The occurrence denominator is the number of real component-line ' ...
    'states that pass the frozen phase-sensitive max-statistic local-peak ' ...
    'gate, not the raw number of image columns.\n']);
fprintf(fid,['A SAFE state means the frozen discrete-first G0 path lands on the ' ...
    'same continuous global branch for the dechirped tone objective. It ' ...
    'does NOT mean the original SAR target is focused or that other motion ' ...
    'model errors are absent.\n']);
fprintf(fid,['If all valid component states remain SAFE, Candidate B should be ' ...
    'treated as evidence that severe visual defocus and real MC-LFM-like ' ...
    'phase structure can coexist without natural branch failure under the ' ...
    'frozen search semantics. Do not retune branch parameters to force a ' ...
    'failure; move to the next pre-registered real target and separately ' ...
    'investigate non-branch defocus mechanisms.\n']);

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,'1) EXP02_FAIR_R1B_FEEDBACK.txt\n');
fprintf(fid,'2) 01_component_state_map.png\n');
fprintf(fid,'3) 02_branch_occurrence_map.png\n');
fprintf(fid,'4) 03_occurrence_summary.png\n');
fprintf(fid,'5) 04_selected_branch_landscapes.png\n');

fprintf('\n============================================================\n');
fprintf('R1B complete.\n');
fprintf('Valid component states=%d on %d/%d ship lines\n', ...
    n_states,n_lines_with_state,n_lines);
fprintf('SAFE=%d | RESCUE=%d | MISS=%d | PERSIST=%d\n', ...
    n_safe,n_rescue,n_miss,n_persist);
fprintf('Stop decision: %s\n',stop_decision);
fprintf('Feedback: %s\n',txt_path);
fprintf('============================================================\n');

%% ========================================================================
function a = pbeta_to_sampled_a(p_beta,N,cfg)
scale = cfg.tnorm_full_span/(N-1);
a = tan(pi*p_beta/2) * scale^2;
end

%% ========================================================================
function run_r1b_interface_self_test(cfg)
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
    error('EXP02_FAIR_R1B:InterfaceSelfTestFailed', ...
        ['p_beta->dechirp interface self-test failed. ' ...
         'global=%.3g G0=%.3g N3=%.3g bin.'], ...
        d_global,d_g0,d_n3);
end

fprintf('R1B interface self-test PASS: global=%.3g G0=%.3g N3=%.3g bin\n\n', ...
    d_global,d_g0,d_n3);
end

%% ========================================================================
function keep_idx = nms_peak_indices(candidate_idx,y,p_grid,tol)
if isempty(candidate_idx)
    keep_idx = candidate_idx;
    return;
end

[~,ord] = sort(y(candidate_idx),'descend');
candidate_idx = candidate_idx(ord);

keep_idx = [];

for i = 1:numel(candidate_idx)
    ii = candidate_idx(i);

    if isempty(keep_idx) || ...
            all(abs(p_grid(ii)-p_grid(keep_idx)) > tol + 1e-12)
        keep_idx(end+1) = ii; %#ok<AGROW>
    end
end

[~,ord2] = sort(p_grid(keep_idx));
keep_idx = keep_idx(ord2);
end

%% ========================================================================
function v = vector_percentile(x,p)
x = sort(x(:));
n = numel(x);

if n == 0
    v = NaN;
    return;
elseif n == 1
    v = x(1);
    return;
end

pos = 1 + (n-1)*p/100;
lo = floor(pos);
hi = ceil(pos);

if lo == hi
    v = x(lo);
else
    w = pos-lo;
    v = (1-w)*x(lo) + w*x(hi);
end
end

%% ========================================================================
function y = normalize01(x)
x = x(:);
xmin = min(x);
xmax = max(x);

if xmax <= xmin
    y = ones(size(x))*0.5;
else
    y = (x-xmin)/(xmax-xmin);
end
end

%% ========================================================================
function d = circular_bin_distance_local(a,b,N)
d = abs(mod((a-b)+N/2,N)-N/2);
end

%% ========================================================================
function q = nearest_periodic_rep(q,ref,N)
delta = mod((q-ref)+N/2,N)-N/2;
q = ref + delta;
end

%% ========================================================================
function write_empty_feedback_and_stop(cfg,R,n_lines,line_n_components,stop_decision)
txt_path = fullfile(cfg.results_dir,'EXP02_FAIR_R1B_FEEDBACK.txt');
fid = fopen(txt_path,'w');

if fid < 0
    error('Cannot write empty R1B feedback bundle.');
end

cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-FAIR-R1B FULL FROZEN-POOL OCCURRENCE AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'frozen_ship_lines=%d\n',n_lines);
fprintf(fid,'lines_with_valid_components=%d\n',sum(line_n_components>0));
fprintf(fid,'total_valid_component_states=0\n');
fprintf(fid,'branch_audit_not_run=1\n');
fprintf(fid,'stop_decision=%s\n',stop_decision);
end
