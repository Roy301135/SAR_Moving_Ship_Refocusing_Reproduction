function run_exp01_stageB_interface_audit()
%RUN_EXP01_STAGEB_INTERFACE_AUDIT
% EXP01 Stage-B — SAR physical signal -> frozen branch-domain interface.
%
% Research question:
%   Does the accepted Stage-A physical SAR scene naturally generate a
%   same-range-cell sampled MC-LFM mixture whose branch geometry is
%   compatible with the frozen EXP009/010 G0 / Neighbor-3 semantics?
%
% This stage DOES NOT run the Proposed staged scheduler and DOES NOT tune
% the scene. It is an interface / falsification gate only.

clc;

%% Resolve repository-local paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
research_root = fileparts(code_dir);
functions_dir = fullfile(research_root,'functions');
addpath(this_dir);
addpath(functions_dir);

cfg = config_exp01_stageB(research_root);
if ~exist(cfg.results_dir,'dir'), mkdir(cfg.results_dir); end

fprintf('============================================================\n');
fprintf('EXP01 SAR Branch Translation - Stage B\n');
fprintf('Physical SAR -> sampled MC-LFM -> branch-interface audit\n');
fprintf('Proposed scheduler: NOT RUN\n');
fprintf('Scene retuning: FORBIDDEN\n');
fprintf('============================================================\n\n');

%% 1. Load the accepted Stage-A physical realization
if ~exist(cfg.stageB.stageA_mat,'file')
    error('EXP01_STAGEB:MissingStageA', ...
        ['Stage-A MAT not found:\n%s\nRun and accept Stage-A first.'], ...
        cfg.stageB.stageA_mat);
end
S = load(cfg.stageB.stageA_mat, ...
    'cfg','tracks_static','tracks_moving','ranges_static','ranges_moving','echo_moving');

% Guard against accidental configuration drift.
if S.cfg.Na ~= cfg.Na || abs(S.cfg.fc-cfg.fc)>1 || ...
        abs(S.cfg.bandwidth-cfg.bandwidth)>1 || abs(S.cfg.prf-cfg.prf)>1e-12
    error('EXP01_STAGEB:StageAConfigDrift', ...
        'Current config_exp01 no longer matches the accepted Stage-A MAT.');
end

center_idx = (cfg.Na+1)/2;
strong_idx = cfg.scatterers.strong_idx;
weak_idx = cfg.scatterers.weak_idx;

% Canonical reference: x=scene center, y=the designated pair common
% aperture-center ground-range coordinate.
x_ref_m = cfg.stageB.reference_x_m;
y_ref_m = mean(S.tracks_static.y([strong_idx,weak_idx],center_idx));

%% 2. Extract the physical same-range-cell residual history
Grid = sar_extract_reference_history_from_grid( ...
    cfg,S.echo_moving,x_ref_m,y_ref_m);
Exact = sar_exact_reference_components( ...
    cfg,S.ranges_moving,x_ref_m,y_ref_m);

x_full = Exact.full_signal;
x_grid = Grid.signal;
x_strong = Exact.components(strong_idx,:);
x_weak = Exact.components(weak_idx,:);
x_pair = x_strong + x_weak;
x_context = x_full - x_pair;

% Data-grid discretization diagnostic.
grid_rel_error = norm(x_grid-x_full) / max(norm(x_full),eps);
grid_corr = abs(sum(conj(x_full).*x_grid)) / ...
    max(norm(x_full)*norm(x_grid),eps);

% Pair ownership / context contamination diagnostic.
context_rel_norm = norm(x_context) / max(norm(x_full),eps);
pair_corr_full = abs(sum(conj(x_full).*x_pair)) / ...
    max(norm(x_full)*norm(x_pair),eps);

%% 3. Map exact physical components to frozen sampled LFM parameters
fit_s = sar_fit_sampled_lfm(x_strong);
fit_w = sar_fit_sampled_lfm(x_weak);

beta_sep = abs(fit_s.beta_rad-fit_w.beta_rad);
Gamma_beam = beta_sep / cfg.stageB.pa4_beta_width_beam_rad;
nu_sep = circular_bin_distance_local(fit_s.nu_bins,fit_w.nu_bins,cfg.Na);

%% 4. Define the evaluation-only strong branch reference
% Use the global continuous optimum of the oracle strong-only component at
% its fitted physical a_s. This avoids using the polynomial-fit nu directly
% as the branch label.
strong_ref_audit = branch_g0_neighbor3_audit( ...
    x_strong,fit_s.a,fit_s.nu_bins,cfg.stageB);
nu_strong_ref = strong_ref_audit.global_nu_bins;

%% 5. Test whether the same physical signal naturally creates branch risk
full_audit = branch_g0_neighbor3_audit( ...
    x_full,fit_s.a,nu_strong_ref,cfg.stageB);
pair_audit = branch_g0_neighbor3_audit( ...
    x_pair,fit_s.a,nu_strong_ref,cfg.stageB);
grid_audit = branch_g0_neighbor3_audit( ...
    x_grid,fit_s.a,nu_strong_ref,cfg.stageB);

%% 6. Compact tables retained locally
component_table = table( ...
    [strong_idx;weak_idx], ["strong";"weak"], ...
    [fit_s.a;fit_w.a], [fit_s.beta_rad;fit_w.beta_rad], ...
    [fit_s.nu_bins;fit_w.nu_bins], ...
    [fit_s.phase_fit_nrmse;fit_w.phase_fit_nrmse], ...
    [fit_s.phase_fit_r2;fit_w.phase_fit_r2], ...
    [fit_s.max_abs_phase_residual_rad;fit_w.max_abs_phase_residual_rad], ...
    [fit_s.amplitude_cv;fit_w.amplitude_cv], ...
    [fit_s.min_to_max_amplitude_ratio;fit_w.min_to_max_amplitude_ratio], ...
    'VariableNames',{'scatterer_idx','role','a_discrete','beta_rad', ...
    'nu_bins','phase_fit_nrmse','phase_fit_r2', ...
    'max_abs_phase_residual_rad','amplitude_cv','min_to_max_amplitude_ratio'});

branch_table = make_branch_table(full_audit,pair_audit,grid_audit);
writetable(component_table,fullfile(cfg.results_dir,'stageB_component_mapping.csv'));
writetable(branch_table,fullfile(cfg.results_dir,'stageB_branch_audit.csv'));

%% 7. Verdict semantics — no scene retuning inside Stage-B
if full_audit.g0_catastrophic && full_audit.n3_rescue
    branch_verdict = "NATURAL_G0_FAILURE_WITH_N3_RESCUE";
elseif full_audit.g0_catastrophic
    branch_verdict = "NATURAL_G0_FAILURE_NOT_RESCUED_BY_N3";
else
    branch_verdict = "NO_NATURAL_G0_CATASTROPHE_IN_FROZEN_SCENE";
end

%% 8. Save MAT
save(fullfile(cfg.results_dir,cfg.stageB.save_mat_name), ...
    'cfg','x_ref_m','y_ref_m','Grid','Exact', ...
    'x_full','x_grid','x_strong','x_weak','x_pair','x_context', ...
    'fit_s','fit_w','nu_strong_ref', ...
    'strong_ref_audit','full_audit','pair_audit','grid_audit', ...
    'component_table','branch_table','branch_verdict', ...
    'grid_rel_error','grid_corr','context_rel_norm','pair_corr_full','Gamma_beam', ...
    '-v7.3');

%% 9. Figures
make_stageB_figures(cfg,x_full,x_grid,x_strong,x_weak,fit_s,fit_w, ...
    nu_strong_ref,full_audit,pair_audit,strong_ref_audit);

%% 10. Single feedback bundle
write_feedback_bundle(cfg,x_ref_m,y_ref_m,grid_rel_error,grid_corr, ...
    context_rel_norm,pair_corr_full,fit_s,fit_w,beta_sep,Gamma_beam,nu_sep, ...
    nu_strong_ref,strong_ref_audit,full_audit,pair_audit,grid_audit, ...
    component_table,branch_table,branch_verdict);

%% Console
fprintf('\n================ STAGE-B SUMMARY ================\n');
fprintf('Reference x/y = %.6f / %.6f m\n',x_ref_m,y_ref_m);
fprintf('Strong beta / nu = %.9g rad / %.6f bins\n',fit_s.beta_rad,fit_s.nu_bins);
fprintf('Weak   beta / nu = %.9g rad / %.6f bins\n',fit_w.beta_rad,fit_w.nu_bins);
fprintf('|Delta beta| / Wbeta(BeamDerived) = %.6f\n',Gamma_beam);
fprintf('Strong branch reference nu = %.6f bins\n',nu_strong_ref);
fprintf('FULL: k0=%d G0=%.6f N3=%.6f | err G0/N3=%.6f/%.6f | rescue=%d\n', ...
    full_audit.coarse_top1_bin,full_audit.G0.nu_hat_bins, ...
    full_audit.N3.nu_hat_bins,full_audit.g0_error_bins, ...
    full_audit.n3_error_bins,full_audit.n3_rescue);
fprintf('Verdict: %s\n',branch_verdict);
fprintf('Feedback: %s\n',fullfile(cfg.results_dir,cfg.stageB.feedback_bundle_name));
fprintf('=================================================\n');

end

%% ========================================================================
function T = make_branch_table(F,P,G)
labels = ["full_exact";"pair_exact";"grid_extracted"];
A = {F;P;G};
n = numel(A);
k0=zeros(n,1); g0=zeros(n,1); n3=zeros(n,1); glob=zeros(n,1);
eg0=zeros(n,1); en3=zeros(n,1); eglob=zeros(n,1);
gcat=false(n,1); ncat=false(n,1); rescue=false(n,1);
for i=1:n
    a=A{i};
    k0(i)=a.coarse_top1_bin;
    g0(i)=a.G0.nu_hat_bins;
    n3(i)=a.N3.nu_hat_bins;
    glob(i)=a.global_nu_bins;
    eg0(i)=a.g0_error_bins;
    en3(i)=a.n3_error_bins;
    eglob(i)=a.global_error_bins;
    gcat(i)=a.g0_catastrophic;
    ncat(i)=a.n3_catastrophic;
    rescue(i)=a.n3_rescue;
end
T=table(labels,k0,g0,n3,glob,eg0,en3,eglob,gcat,ncat,rescue, ...
    'VariableNames',{'signal','coarse_top1_bin','g0_nu_bins','n3_nu_bins', ...
    'global_nu_bins','g0_error_bins','n3_error_bins','global_error_bins', ...
    'g0_catastrophic','n3_catastrophic','n3_rescue'});
end

%% ========================================================================
function make_stageB_figures(cfg,x_full,x_grid,xs,xw,fit_s,fit_w, ...
    nu_ref,F,P,Sref)

N=numel(x_full); m=0:N-1;

% Figure 05 — physical interface and component phase model
f=figure('Name','EXP01 Stage-B Physical Interface','Color','w', ...
    'Visible',cfg.stageB.figure_visible,'Position',[100 100 1200 760]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

nexttile;
plot(m,abs(x_full)/max(abs(x_full)),'LineWidth',1.2); hold on;
plot(m,abs(x_grid)/max(abs(x_grid)),'--','LineWidth',1.0);
plot(m,abs(xs)/max(abs(x_full)),':','LineWidth',1.1);
plot(m,abs(xw)/max(abs(x_full)),':','LineWidth',1.1);
grid on; xlabel('sample m'); ylabel('normalized magnitude');
title('Canonical same-range-cell history');
legend('exact full','from stored range grid','strong P4','weak P7','Location','best');

nexttile;
plot(m,unwrap(angle(xs)),'LineWidth',1.0); hold on;
phi_s = pi*fit_s.a*m.^2 + 2*pi*(fit_s.nu_bins/N)*m + fit_s.phase0_rad;
plot(m,phi_s,'--','LineWidth',1.2);
grid on; xlabel('sample m'); ylabel('phase (rad)');
title(sprintf('Strong P4 sampled-LFM fit: NRMSE=%.4g, R^2=%.6f', ...
    fit_s.phase_fit_nrmse,fit_s.phase_fit_r2));
legend('exact physical component','sampled-LFM fit','Location','best');

nexttile;
plot(m,unwrap(angle(xw)),'LineWidth',1.0); hold on;
phi_w = pi*fit_w.a*m.^2 + 2*pi*(fit_w.nu_bins/N)*m + fit_w.phase0_rad;
plot(m,phi_w,'--','LineWidth',1.2);
grid on; xlabel('sample m'); ylabel('phase (rad)');
title(sprintf('Weak P7 sampled-LFM fit: NRMSE=%.4g, R^2=%.6f', ...
    fit_w.phase_fit_nrmse,fit_w.phase_fit_r2));
legend('exact physical component','sampled-LFM fit','Location','best');

nexttile;
plot(m,real(x_full),'LineWidth',0.9); hold on;
plot(m,real(xs+xw),'--','LineWidth',1.0);
grid on; xlabel('sample m'); ylabel('real part');
title('Full scene versus designated P4/P7 pair');
legend('full exact','P4+P7 pair','Location','best');

exportgraphics(f,fullfile(cfg.results_dir,'05_stageB_physical_interface.png'),'Resolution',180);

% Figure 06 — branch geometry around the physical strong branch
q = (nu_ref-cfg.stageB.branch_plot_halfwidth_bins): ...
    cfg.stageB.branch_plot_step_bins: ...
    (nu_ref+cfg.stageB.branch_plot_halfwidth_bins);
JF = branch_tone_objective(F.dechirped_signal,q);
JP = branch_tone_objective(P.dechirped_signal,q);
JS = branch_tone_objective(Sref.dechirped_signal,q);
JF=JF/max(JF); JP=JP/max(JP); JS=JS/max(JS);

f=figure('Name','EXP01 Stage-B Branch Landscape','Color','w', ...
    'Visible',cfg.stageB.figure_visible,'Position',[100 100 1200 720]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

nexttile;
plot(q,JS,'LineWidth',1.2); hold on;
plot(q,JP,'--','LineWidth',1.2);
plot(q,JF,'-.','LineWidth',1.2);
xline(nu_ref,':','Strong reference','LabelVerticalAlignment','bottom');
xline(F.G0.nu_hat_bins,'--','G0');
xline(F.N3.nu_hat_bins,'-.','N3');
grid on; xlabel('\nu (DFT bins)'); ylabel('normalized objective');
title('Continuous branch objective at oracle strong a_s');
legend('strong-only','P4+P7 pair','full scene','Location','best');

nexttile;
stem(F.coarse_bins,F.coarse_objective/max(F.coarse_objective),'filled','MarkerSize',3); hold on;
xline(F.coarse_top1_bin,'--','coarse Top-1');
xline(nu_ref,':','strong reference');
xlim([nu_ref-cfg.stageB.branch_plot_halfwidth_bins, ...
      nu_ref+cfg.stageB.branch_plot_halfwidth_bins]);
ylim([0 1.05]); grid on;
xlabel('integer DFT bin'); ylabel('normalized coarse objective');
title(sprintf('Full-scene coarse landscape | G0 error=%.4f bin | N3 error=%.4f bin', ...
    F.g0_error_bins,F.n3_error_bins));

exportgraphics(f,fullfile(cfg.results_dir,'06_stageB_branch_landscape.png'),'Resolution',180);
end

%% ========================================================================
function write_feedback_bundle(cfg,xref,yref,griderr,gridcorr,ctxnorm,paircorr, ...
    fs,fw,dbeta,Gamma,nusep,nuref,Sref,F,P,G,CT,BT,verdict)

path=fullfile(cfg.results_dir,cfg.stageB.feedback_bundle_name);
fid=fopen(path,'w');
if fid<0, error('Could not open feedback bundle: %s',path); end
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP01 / STAGE-B SAR-TO-BRANCH INTERFACE AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Purpose: test whether the frozen Stage-A physical scene maps into the sampled MC-LFM / branch geometry used by EXP009/010.\n');
fprintf(fid,'Proposed scheduler: NOT RUN\n');
fprintf(fid,'Scene retuning: NONE\n');
fprintf(fid,'Noise/clutter: OFF\n\n');

fprintf(fid,'[REFERENCE RANGE CELL]\n');
fprintf(fid,'N=%d\n',cfg.Na);
fprintf(fid,'reference_x_m=%.12g\n',xref);
fprintf(fid,'reference_y_m=%.12g\n',yref);
fprintf(fid,'primary_signal=%s\n\n',cfg.stageB.primary_signal);

fprintf(fid,'[FORWARD-DATA CONSISTENCY]\n');
fprintf(fid,'grid_extraction_relative_L2_error_vs_exact=%.12g\n',griderr);
fprintf(fid,'grid_extraction_complex_correlation_vs_exact=%.12g\n',gridcorr);
fprintf(fid,'context_relative_L2_norm=%.12g\n',ctxnorm);
fprintf(fid,'pair_complex_correlation_with_full=%.12g\n\n',paircorr);

fprintf(fid,'[SAMPLED MC-LFM PARAMETER MAPPING]\n');
fprintf(fid,'Strong_a_discrete=%.12g\n',fs.a);
fprintf(fid,'Strong_beta_rad=%.12g\n',fs.beta_rad);
fprintf(fid,'Strong_nu_fit_bins=%.12g\n',fs.nu_bins);
fprintf(fid,'Strong_phase_fit_nrmse=%.12g\n',fs.phase_fit_nrmse);
fprintf(fid,'Strong_phase_fit_r2=%.12g\n',fs.phase_fit_r2);
fprintf(fid,'Strong_max_abs_phase_residual_rad=%.12g\n',fs.max_abs_phase_residual_rad);
fprintf(fid,'Strong_amplitude_cv=%.12g\n',fs.amplitude_cv);
fprintf(fid,'Strong_min_to_max_amplitude=%.12g\n',fs.min_to_max_amplitude_ratio);
fprintf(fid,'Weak_a_discrete=%.12g\n',fw.a);
fprintf(fid,'Weak_beta_rad=%.12g\n',fw.beta_rad);
fprintf(fid,'Weak_nu_fit_bins=%.12g\n',fw.nu_bins);
fprintf(fid,'Weak_phase_fit_nrmse=%.12g\n',fw.phase_fit_nrmse);
fprintf(fid,'Weak_phase_fit_r2=%.12g\n',fw.phase_fit_r2);
fprintf(fid,'Weak_max_abs_phase_residual_rad=%.12g\n',fw.max_abs_phase_residual_rad);
fprintf(fid,'Weak_amplitude_cv=%.12g\n',fw.amplitude_cv);
fprintf(fid,'Weak_min_to_max_amplitude=%.12g\n',fw.min_to_max_amplitude_ratio);
fprintf(fid,'abs_delta_beta_rad=%.12g\n',dbeta);
fprintf(fid,'Gamma_vs_PA4_BeamDerived_width=%.12g\n',Gamma);
fprintf(fid,'circular_nu_separation_bins=%.12g\n',nusep);
fprintf(fid,'strong_global_reference_nu_bins=%.12g\n\n',nuref);

fprintf(fid,'[COMPONENT TABLE]\n');
write_table_tsv(fid,CT);

fprintf(fid,'\n[BRANCH AUDIT TABLE]\n');
write_table_tsv(fid,BT);

fprintf(fid,'\n[FULL-SCENE COARSE TOP-5]\n');
for i=1:numel(F.coarse_top_bins)
    fprintf(fid,'rank%d\tbin=%.12g\tnorm_score=%.12g\n', ...
        i,F.coarse_top_bins(i),F.coarse_top_scores_normalized(i));
end

fprintf(fid,'\n[PAIR CONTROL COARSE TOP-5]\n');
for i=1:numel(P.coarse_top_bins)
    fprintf(fid,'rank%d\tbin=%.12g\tnorm_score=%.12g\n', ...
        i,P.coarse_top_bins(i),P.coarse_top_scores_normalized(i));
end

fprintf(fid,'\n[STRONG-ONLY REFERENCE]\n');
fprintf(fid,'coarse_top1_bin=%.12g\n',Sref.coarse_top1_bin);
fprintf(fid,'g0_nu_bins=%.12g\n',Sref.G0.nu_hat_bins);
fprintf(fid,'n3_nu_bins=%.12g\n',Sref.N3.nu_hat_bins);
fprintf(fid,'global_nu_bins=%.12g\n',Sref.global_nu_bins);

fprintf(fid,'\n[VERDICT]\n');
fprintf(fid,'branch_verdict=%s\n',verdict);

fprintf(fid,'\n[STOP / NEXT RULE]\n');
fprintf(fid,'1) This stage uses true strong a only as an oracle mechanism control; it is NOT a practical Proposed path.\n');
fprintf(fid,'2) If sampled physical strong/weak components are not MC-LFM-like, STOP before Proposed and audit the representation bridge.\n');
fprintf(fid,'3) If FULL exact signal shows G0 catastrophe and Neighbor-3 rescue, proceed to Stage-C frozen Proposed integration without scene retuning.\n');
fprintf(fid,'4) If G0 succeeds, do NOT tune yaw, scatterer coordinates, amplitude ratio, phase, or reference x to manufacture failure. Audit why the canonical physical state lies outside the previously frozen branch-vulnerable regime before any controlled hard-state embedding.\n');
fprintf(fid,'5) Grid-extracted signal is a discretization diagnostic. Differences between it and exact-forward signal must not be mislabeled as branch physics.\n');

fprintf(fid,'\n[UPLOAD REQUEST]\n');
fprintf(fid,'Return only: EXP01_STAGEB_FEEDBACK_BUNDLE.txt, 05_stageB_physical_interface.png, 06_stageB_branch_landscape.png. Keep CSV/MAT locally unless a specific anomaly requires them.\n');
end


%% ========================================================================
function write_table_tsv(fid,T)
%WRITE_TABLE_TSV Write a MATLAB table to an already-open text stream.
%
% writetable() requires a filename/path in MATLAB releases where file-ID
% targets are unsupported.  The EXP01 feedback bundle is intentionally a
% single open text file, so this helper serializes tables directly through
% fprintf and avoids version-dependent writetable(fid,...) behavior.
%
% Supported column types used by this experiment:
%   numeric, logical, string, char, categorical, cellstr/cell scalars.
% Missing string/categorical values are emitted as <missing>; NaN/Inf keep
% their normal textual representation.  Tabs/newlines inside text fields
% are sanitized to preserve the TSV structure.

if ~(isscalar(fid) && isnumeric(fid) && fid >= 0)
    error('EXP01_STAGEB:InvalidFileID','write_table_tsv received an invalid file ID.');
end
if ~istable(T)
    error('EXP01_STAGEB:ExpectedTable','write_table_tsv expects a MATLAB table.');
end

names = T.Properties.VariableNames;
for j = 1:numel(names)
    if j > 1, fprintf(fid,'\t'); end
    fprintf(fid,'%s',sanitize_text(names{j}));
end
fprintf(fid,'\n');

for i = 1:height(T)
    for j = 1:width(T)
        if j > 1, fprintf(fid,'\t'); end
        value = T{i,j};
        fprintf(fid,'%s',table_scalar_to_text(value));
    end
    fprintf(fid,'\n');
end
end

%% ========================================================================
function s = table_scalar_to_text(v)
% Convert one table element into a stable scalar text representation.

% Curly indexing on some table variable types can still return a 1x1 cell.
if iscell(v)
    if isempty(v)
        s = '';
        return;
    elseif isscalar(v)
        v = v{1};
    else
        s = sanitize_text(strjoin(string(v(:).'),','));
        return;
    end
end

if isstring(v)
    if isempty(v)
        s = '';
    elseif ismissing(v(1))
        s = '<missing>';
    else
        s = sanitize_text(char(v(1)));
    end
elseif ischar(v)
    s = sanitize_text(v);
elseif iscategorical(v)
    if isundefined(v(1))
        s = '<missing>';
    else
        s = sanitize_text(char(string(v(1))));
    end
elseif islogical(v)
    if isempty(v), s=''; else, s = sprintf('%d',v(1)); end
elseif isnumeric(v)
    if isempty(v)
        s = '';
    elseif ~isscalar(v)
        s = sanitize_text(strjoin(compose('%.15g',v(:).'),','));
    else
        s = sprintf('%.15g',v);
    end
elseif isdatetime(v) || isduration(v)
    s = sanitize_text(char(string(v(1))));
else
    % Defensive fallback for any future scalar table type.
    try
        s = sanitize_text(char(string(v(1))));
    catch
        s = '<unsupported>';
    end
end
end

%% ========================================================================
function s = sanitize_text(s)
% Keep feedback-bundle rows valid TSV records.
if isstring(s), s=char(s); end
s = strrep(s,sprintf('\t'),' ');
s = strrep(s,sprintf('\r'),' ');
s = strrep(s,sprintf('\n'),' ');
end

%% ========================================================================
function d = circular_bin_distance_local(a,b,N)
d = abs(mod((a-b)+N/2,N)-N/2);
end
