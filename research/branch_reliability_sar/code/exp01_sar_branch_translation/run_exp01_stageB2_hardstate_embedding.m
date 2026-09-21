function run_exp01_stageB2_hardstate_embedding()
%RUN_EXP01_STAGEB2_HARDSTATE_EMBEDDING
% EXP01 Stage-B2 — Controlled hard-state physical embedding.
%
% Goal:
%   take ONE frozen EXP010-B BeamDerived DenseRisk case that was already
%   rescued by the frozen Proposed/N3 chain, map its signal-level truth
%   parameters into a physically generated yawing-ship SAR pair, then ask
%   whether G0 failure / N3 rescue appears naturally.
%
% The inverse solver NEVER optimizes G0/N3 branch outcomes.

clc;

%% Paths
this_file=mfilename('fullpath');
this_dir=fileparts(this_file);
code_dir=fileparts(this_dir);
research_root=fileparts(code_dir);
functions_dir=fullfile(research_root,'functions');
addpath(this_dir);
addpath(functions_dir);

cfg=config_exp01_stageB2(research_root);
if ~exist(cfg.results_dir,'dir'), mkdir(cfg.results_dir); end

% Robust resume path: Stage-B2 saves the full MAT bundle before figure /
% feedback generation. If a previous run completed the expensive physical
% solve but stopped only during reporting, reuse that exact frozen result
% instead of solving the scene again. This branch is entered only when the
% MAT exists while one or more reporting artifacts are missing.
resume_mat = fullfile(cfg.results_dir,cfg.stageB2.save_mat_name);
resume_feedback = fullfile(cfg.results_dir,cfg.stageB2.feedback_bundle_name);
resume_fig1 = fullfile(cfg.results_dir,'07_stageB2_physical_embedding.png');
resume_fig2 = fullfile(cfg.results_dir,'08_stageB2_branch_falsification.png');
if exist(resume_mat,'file') && ...
        (~exist(resume_feedback,'file') || ~exist(resume_fig1,'file') || ~exist(resume_fig2,'file'))
    fprintf('============================================================\n');
    fprintf('EXP01 Stage-B2 reporting resume\n');
    fprintf('Reusing saved frozen physical solution; inverse solve will NOT rerun.\n');
    fprintf('============================================================\n\n');

    R = load(resume_mat);
    validate_saved_stageB2_bundle(R);
    validate_branch_audit_schema(R.Sref,'Sref');
    validate_branch_audit_schema(R.PairAudit,'PairAudit');
    validate_branch_audit_schema(R.FullAudit,'FullAudit');

    make_figures(cfg,R.target,R.C,R.fit_s,R.fit_w,R.x_strong,R.x_weak, ...
        R.Sref,R.PairAudit,R.FullAudit);
    write_feedback(cfg,R.target,R.selection_class,R.Sol,R.C,R.fit_s,R.fit_w, ...
        R.beta_s_err_W,R.beta_w_err_W,R.nu_s_frac_err,R.nu_w_frac_err,R.nu_sep, ...
        R.effective_amp_ratio,R.effective_rel_phase,R.context_rel,R.pair_corr, ...
        R.translation_gate,R.Sref,R.PairAudit,R.FullAudit,R.verdict);

    fprintf('Reporting artifacts regenerated from: %s\n',resume_mat);
    fprintf('Verdict: %s\n',R.verdict);
    return;
end

fprintf('============================================================\n');
fprintf('EXP01 Stage-B2 Controlled Hard-State Physical Embedding\n');
fprintf('Branch outcome is NOT part of inverse optimization.\n');
fprintf('Scene family: yaw-only, BeamDerived SAR system.\n');
fprintf('============================================================\n\n');

%% 1) Read frozen EXP010-B results and select exactly one target
if ~exist(cfg.stageB2.exp10b_eval_csv,'file')
    error('EXP01_STAGEB2:MissingUpstreamCSV', ...
        ['Frozen EXP010-B evaluation table not found:\n%s\n' ...
         'Do not regenerate/tune a new stress set. Restore the accepted EXP010-B results first.'], ...
        cfg.stageB2.exp10b_eval_csv);
end

E=readtable(cfg.stageB2.exp10b_eval_csv,'TextType','string');
validate_eval_schema(E);
[target,selection_class]=select_frozen_target(E,cfg);

fprintf('Selected frozen target: trial_id=%d risk_state_id=%d (%s)\n', ...
    target.trial_id,target.risk_state_id,selection_class);
fprintf('  beta_s=%.9g beta_w=%.9g eta=%.4f r=%.3f phase=%.6f\n\n', ...
    target.beta_s_rad,target.beta_w_rad,target.eta_bins, ...
    target.weak_to_strong_ratio,target.relative_phase_rad);

%% 2) Physical inverse solve (parameter mismatch only)
Sol=sar_solve_hardstate_embedding(cfg,target);
C=Sol.candidate;

%% 3) Freeze the solved physical scene and set target amplitude/phase
cfg_embed=cfg;
cfg_embed.motion.yaw_amplitude_rad=C.p.yaw_amplitude_rad;
cfg_embed.motion.yaw_period_s=C.p.yaw_period_s;
cfg_embed.motion.yaw_phase0_rad=C.p.yaw_phase0_rad;
cfg_embed.motion.theta_center_rad=C.theta_center_rad;

sidx=cfg.scatterers.strong_idx;
widx=cfg.scatterers.weak_idx;
cfg_embed.scatterers.body_xy_m(sidx,:)=C.body_xy_m(1,:);
cfg_embed.scatterers.body_xy_m(widx,:)=C.body_xy_m(2,:);

% First evaluate unit-coefficient physical components to compensate the
% physical envelope/phase so that the effective pair matches the frozen
% target r and relative phase without changing its a/nu geometry.
cfg_unit=cfg_embed;
cfg_unit.scatterers.complex_coeff(sidx)=1;
cfg_unit.scatterers.complex_coeff(widx)=1;
tracks_unit=sar_build_ship_tracks(cfg_unit,'moving');
ranges_unit=sar_compute_slant_ranges(cfg_unit,tracks_unit);
Exact_unit=sar_exact_reference_components(cfg_unit,ranges_unit, ...
    cfg.ship_center_x,C.reference_y_m);
xs0=Exact_unit.components(sidx,:);
xw0=Exact_unit.components(widx,:);
fs0=sar_fit_sampled_lfm(xs0);
fw0=sar_fit_sampled_lfm(xw0);

amp_s=mean(abs(xs0));
amp_w=mean(abs(xw0));
weak_coeff_amp=target.weak_to_strong_ratio*amp_s/max(amp_w,eps);
unit_rel_phase=wrap_pi(fw0.phase0_rad-fs0.phase0_rad);
weak_coeff_phase=wrap_pi(target.relative_phase_rad-unit_rel_phase);

cfg_embed.scatterers.amplitude(sidx)=1;
cfg_embed.scatterers.phase_rad(sidx)=0;
cfg_embed.scatterers.amplitude(widx)=weak_coeff_amp;
cfg_embed.scatterers.phase_rad(widx)=weak_coeff_phase;
cfg_embed.scatterers.complex_coeff = cfg_embed.scatterers.amplitude .* ...
    exp(1j*cfg_embed.scatterers.phase_rad);

%% 4) Formal forward realization after freeze
tracks=sar_build_ship_tracks(cfg_embed,'moving');
ranges=sar_compute_slant_ranges(cfg_embed,tracks);
Exact=sar_exact_reference_components(cfg_embed,ranges, ...
    cfg.ship_center_x,C.reference_y_m);

x_strong=Exact.components(sidx,:);
x_weak=Exact.components(widx,:);
x_pair=x_strong+x_weak;
x_full=Exact.full_signal;
x_context=x_full-x_pair;

fit_s=sar_fit_sampled_lfm(x_strong);
fit_w=sar_fit_sampled_lfm(x_weak);

% Strong-only global reference is evaluation truth for the physical branch.
Sref=branch_g0_neighbor3_audit(x_strong,fit_s.a,fit_s.nu_bins,cfg.stageB);
nu_ref=Sref.global_nu_bins;
PairAudit=branch_g0_neighbor3_audit(x_pair,fit_s.a,nu_ref,cfg.stageB);
FullAudit=branch_g0_neighbor3_audit(x_full,fit_s.a,nu_ref,cfg.stageB);

% Reporting code consumes the branch-audit schema produced by
% branch_g0_neighbor3_audit(). Validate the contract here so future field
% renames fail immediately with a descriptive message rather than much
% later inside plotting / feedback code.
validate_branch_audit_schema(Sref,'Sref');
validate_branch_audit_schema(PairAudit,'PairAudit');
validate_branch_audit_schema(FullAudit,'FullAudit');

%% 5) Translation diagnostics
beta_s_err_W=abs(fit_s.beta_rad-target.beta_s_rad)/cfg.stageB2.beta_scale_rad;
beta_w_err_W=abs(fit_w.beta_rad-target.beta_w_rad)/cfg.stageB2.beta_scale_rad;
nu_s_frac_err=frac_bin_error(fit_s.nu_bins,target.eta_bins);
nu_w_frac_err=frac_bin_error(fit_w.nu_bins,target.eta_bins);
nu_sep=periodic_bin_distance(fit_s.nu_bins,fit_w.nu_bins,cfg.Na);
context_rel=norm(x_context)/max(norm(x_full),eps);
pair_corr=abs(sum(conj(x_full).*x_pair))/max(norm(x_full)*norm(x_pair),eps);
effective_amp_ratio=mean(abs(x_weak))/max(mean(abs(x_strong)),eps);
effective_rel_phase=wrap_pi(fit_w.phase0_rad-fit_s.phase0_rad);

translation_gate = ...
    beta_s_err_W <= cfg.stageB2.gate_beta_error_over_W && ...
    beta_w_err_W <= cfg.stageB2.gate_beta_error_over_W && ...
    nu_s_frac_err <= cfg.stageB2.gate_fractional_nu_error_bins && ...
    nu_w_frac_err <= cfg.stageB2.gate_fractional_nu_error_bins && ...
    nu_sep <= cfg.stageB2.gate_pair_nu_separation_bins && ...
    fit_s.phase_fit_nrmse <= cfg.stageB2.gate_phase_fit_nrmse && ...
    fit_w.phase_fit_nrmse <= cfg.stageB2.gate_phase_fit_nrmse;

if ~translation_gate
    verdict="PHYSICAL_MAPPING_MISMATCH_STOP";
elseif PairAudit.g0_catastrophic && PairAudit.n3_rescue && ...
        FullAudit.g0_catastrophic && FullAudit.n3_rescue
    verdict="FULL_PHYSICAL_HARDSTATE_REALIZED_PROCEED_STAGEC";
elseif PairAudit.g0_catastrophic && PairAudit.n3_rescue
    verdict="PAIR_HARDSTATE_REALIZED_BUT_CONTEXT_ALTERS_FULL_SCENE";
elseif PairAudit.g0_catastrophic
    verdict="PHYSICAL_G0_FAILURE_NOT_RESCUED_BY_N3";
else
    verdict="MAPPING_PASSED_BUT_NO_PHYSICAL_G0_CATASTROPHE";
end

%% 6) Local outputs
selected_target_table=struct2table(target,'AsArray',true);
physical_solution_table=table( ...
    C.p.x_strong_center_m,C.p.x_weak_center_m,C.p.common_y_offset_m, ...
    C.p.yaw_amplitude_rad*180/pi,C.p.yaw_period_s,C.p.yaw_phase0_rad, ...
    C.body_xy_m(1,1),C.body_xy_m(1,2),C.body_xy_m(2,1),C.body_xy_m(2,2), ...
    'VariableNames',{'x_strong_center_m','x_weak_center_m','common_y_offset_m', ...
    'yaw_amplitude_deg','yaw_period_s','yaw_phase0_rad', ...
    'strong_body_x_m','strong_body_y_m','weak_body_x_m','weak_body_y_m'});

writetable(selected_target_table,fullfile(cfg.results_dir,'stageB2_selected_target.csv'));
writetable(physical_solution_table,fullfile(cfg.results_dir,'stageB2_physical_solution.csv'));
writetable(Sol.start_summary,fullfile(cfg.results_dir,'stageB2_solver_starts.csv'));

save(fullfile(cfg.results_dir,cfg.stageB2.save_mat_name), ...
    'cfg','cfg_embed','target','selection_class','Sol','C', ...
    'tracks','ranges','Exact','x_strong','x_weak','x_pair','x_full','x_context', ...
    'fit_s','fit_w','Sref','PairAudit','FullAudit','translation_gate','verdict', ...
    'beta_s_err_W','beta_w_err_W','nu_s_frac_err','nu_w_frac_err','nu_sep', ...
    'context_rel','pair_corr','effective_amp_ratio','effective_rel_phase','-v7.3');

%% 7) Compact figures
make_figures(cfg,target,C,fit_s,fit_w,x_strong,x_weak,Sref,PairAudit,FullAudit);

%% 8) Single feedback bundle
write_feedback(cfg,target,selection_class,Sol,C,fit_s,fit_w, ...
    beta_s_err_W,beta_w_err_W,nu_s_frac_err,nu_w_frac_err,nu_sep, ...
    effective_amp_ratio,effective_rel_phase,context_rel,pair_corr, ...
    translation_gate,Sref,PairAudit,FullAudit,verdict);

fprintf('\n================ STAGE-B2 SUMMARY ================\n');
fprintf('Target trial=%d risk_state=%d selection=%s\n', ...
    target.trial_id,target.risk_state_id,selection_class);
fprintf('Mapping: beta err/W strong/weak = %.4f / %.4f\n',beta_s_err_W,beta_w_err_W);
fprintf('Mapping: frac-nu err strong/weak = %.4f / %.4f bins | pair sep=%.4f\n', ...
    nu_s_frac_err,nu_w_frac_err,nu_sep);
fprintf('Pair: G0 err=%.4f N3 err=%.4f rescue=%d\n', ...
    PairAudit.g0_error_bins,PairAudit.n3_error_bins,PairAudit.n3_rescue);
fprintf('Full: G0 err=%.4f N3 err=%.4f rescue=%d\n', ...
    FullAudit.g0_error_bins,FullAudit.n3_error_bins,FullAudit.n3_rescue);
fprintf('Verdict: %s\n',verdict);
fprintf('Feedback: %s\n',fullfile(cfg.results_dir,cfg.stageB2.feedback_bundle_name));
fprintf('==================================================\n');

end

%% ========================================================================
function validate_eval_schema(E)
required=[ ...
    "validation_set","trial_id","aperture_mode","method", ...
    "fallback_trigger","catastrophic_branch_failure", ...
    "weak_waveform_feasible","truth_beta_s_rad","truth_beta_w_rad", ...
    "risk_state_id","truth_weak_to_strong_ratio", ...
    "truth_relative_phase_rad","truth_fractional_bin_offset","truth_Gamma"];
missing=setdiff(required,string(E.Properties.VariableNames));
if ~isempty(missing)
    error('EXP01_STAGEB2:UpstreamSchemaMismatch', ...
        'EXP010-B evaluation table missing fields: %s',strjoin(missing,', '));
end
end

function [T,cls]=select_frozen_target(E,cfg)
idx = string(E.validation_set)==cfg.stageB2.target_validation_set & ...
    string(E.aperture_mode)==cfg.stageB2.target_aperture_mode;
E=E(idx,:);

G=sortrows(E(string(E.method)=="G0_OriginalTop1",:),'trial_id');
Q=sortrows(E(string(E.method)=="Proposed_Frozen_Staged",:),'trial_id');
N=sortrows(E(string(E.method)=="Always_Neighbor3",:),'trial_id');
if isempty(G) || height(G)~=height(Q) || height(G)~=height(N) || ...
        ~isequal(double(G.trial_id),double(Q.trial_id)) || ...
        ~isequal(double(G.trial_id),double(N.trial_id))
    error('EXP01_STAGEB2:MethodAlignment','EXP010-B method rows are not aligned by trial_id.');
end

gcat=aslogical(G.catastrophic_branch_failure);
qcat=aslogical(Q.catastrophic_branch_failure);
ncat=aslogical(N.catastrophic_branch_failure);
qfb=aslogical(Q.fallback_trigger);
gweak=aslogical(G.weak_waveform_feasible);
qweak=aslogical(Q.weak_waveform_feasible);

core=gcat & ~qcat & ~ncat & qfb;
prefer=core & ~gweak & qweak;
if any(prefer)
    j=find(prefer,1,'first');
    cls="BRANCH_AND_WEAK_RESCUE";
elseif any(core)
    j=find(core,1,'first');
    cls="BRANCH_RESCUE_ONLY";
else
    error('EXP01_STAGEB2:NoFrozenTarget', ...
        'No BeamDerived DenseRisk G0-fail -> Proposed/N3-success case exists in accepted EXP010-B results.');
end

T=struct();
T.trial_id=double(G.trial_id(j));
T.risk_state_id=double(G.risk_state_id(j));
T.beta_s_rad=double(G.truth_beta_s_rad(j));
T.beta_w_rad=double(G.truth_beta_w_rad(j));
T.a_s=tan(T.beta_s_rad);
T.a_w=tan(T.beta_w_rad);
T.eta_bins=double(G.truth_fractional_bin_offset(j));
T.weak_to_strong_ratio=double(G.truth_weak_to_strong_ratio(j));
T.relative_phase_rad=double(G.truth_relative_phase_rad(j));
T.Gamma=double(G.truth_Gamma(j));
T.g0_branch_error_bins=double(G.branch_error_to_reference_bins(j));
T.proposed_branch_error_bins=double(Q.branch_error_to_reference_bins(j));
T.n3_branch_error_bins=double(N.branch_error_to_reference_bins(j));
T.g0_weak_waveform_error=double(G.weak_waveform_error_ratio(j));
T.proposed_weak_waveform_error=double(Q.weak_waveform_error_ratio(j));
T.n3_weak_waveform_error=double(N.weak_waveform_error_ratio(j));
end

function x=aslogical(v)
if islogical(v)
    x=v;
elseif isnumeric(v)
    x=v~=0;
else
    s=lower(strtrim(string(v)));
    x=(s=="1" | s=="true" | s=="yes");
end
x=x(:);
end

function make_figures(cfg,T,C,fs,fw,xs,xw,Sref,P,F)
N=numel(xs); m=0:N-1;

f=figure('Name','EXP01 Stage-B2 Mapping','Color','w', ...
    'Visible',cfg.stageB2.figure_visible,'Position',[80 80 1250 780]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

nexttile;
plot([T.beta_s_rad,T.beta_w_rad],'o-','LineWidth',1.4); hold on;
plot([fs.beta_rad,fw.beta_rad],'x--','LineWidth',1.4);
set(gca,'XTick',[1 2],'XTickLabel',{'strong','weak'}); grid on;
ylabel('\beta (rad)'); title('Frozen target versus physical embedding');
legend('EXP010-B target','SAR physical','Location','best');

nexttile;
bar([frac_coord(T.eta_bins),frac_coord(T.eta_bins); ...
    frac_coord(fs.nu_bins),frac_coord(fw.nu_bins)]');
set(gca,'XTick',[1 2],'XTickLabel',{'strong','weak'}); grid on;
ylabel('fractional DFT-bin coordinate');
legend('target','physical','Location','best'); title('Fractional branch alignment');

nexttile;
plot(m,abs(xs)/max(abs(xs)),'LineWidth',1.1); hold on;
plot(m,abs(xw)/max(abs(xs)),'LineWidth',1.1); grid on;
xlabel('sample m'); ylabel('relative magnitude');
title('Physically generated hard-state pair'); legend('strong','weak','Location','best');

nexttile;
axis off;
text(0,0.95,sprintf('P4/P7 center x = %.3f / %.3f m', ...
    C.p.x_strong_center_m,C.p.x_weak_center_m),'FontName','Consolas');
text(0,0.78,sprintf('common y offset = %.3f m',C.p.common_y_offset_m),'FontName','Consolas');
text(0,0.61,sprintf('yaw amp = %.3f deg',C.p.yaw_amplitude_rad*180/pi),'FontName','Consolas');
text(0,0.44,sprintf('yaw period = %.3f s',C.p.yaw_period_s),'FontName','Consolas');
text(0,0.27,sprintf('yaw phase0 = %.3f rad',C.p.yaw_phase0_rad),'FontName','Consolas');
text(0,0.10,sprintf('fit NRMSE S/W = %.4g / %.4g',fs.phase_fit_nrmse,fw.phase_fit_nrmse),'FontName','Consolas');

exportgraphics(f,fullfile(cfg.results_dir,'07_stageB2_physical_embedding.png'),'Resolution',180);

% Branch landscape
f2=figure('Name','EXP01 Stage-B2 Branch Falsification','Color','w', ...
    'Visible',cfg.stageB2.figure_visible,'Position',[80 80 1250 720]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

q=(-4:0.002:4)+Sref.global_nu_bins;
nexttile;
Js=zeros(size(q)); Jp=zeros(size(q));
for i=1:numel(q)
    Js(i)=branch_tone_objective(xs.*exp(-1j*pi*fs.a*(0:N-1).^2),q(i));
    Jp(i)=branch_tone_objective((xs+xw).*exp(-1j*pi*fs.a*(0:N-1).^2),q(i));
end
plot(q,Js/max(Js),'LineWidth',1.2); hold on;
plot(q,Jp/max(Jp),'--','LineWidth',1.2); xline(Sref.global_nu_bins,':');
grid on; xlabel('\nu (DFT bins)'); ylabel('normalized objective');
title('Strong-only versus physical pair objective'); legend('strong','pair','strong reference','Location','best');

nexttile;
stem(P.coarse_bins,P.coarse_objective/max(P.coarse_objective),'filled'); hold on;
xline(Sref.global_nu_bins,':'); xline(P.G0.nu_hat_bins,'--'); xline(P.N3.nu_hat_bins,'-.');
grid on; xlabel('integer DFT bin'); ylabel('normalized coarse objective');
title(sprintf('Physical pair: G0 err=%.4f | N3 err=%.4f | rescue=%d | full rescue=%d', ...
    P.g0_error_bins,P.n3_error_bins,P.n3_rescue,F.n3_rescue));
legend('coarse','strong ref','G0','N3','Location','best');
exportgraphics(f2,fullfile(cfg.results_dir,'08_stageB2_branch_falsification.png'),'Resolution',180);
end

function write_feedback(cfg,T,cls,Sol,C,fs,fw,ebs,ebw,ens,enw,nsep, ...
    ar,pr,context_rel,pair_corr,gate,Sref,P,F,verdict)
path=fullfile(cfg.results_dir,cfg.stageB2.feedback_bundle_name);
fid=fopen(path,'w');
if fid<0, error('EXP01_STAGEB2:FeedbackOpen','Cannot open feedback file: %s',path); end
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP01 / STAGE-B2 CONTROLLED HARD-STATE PHYSICAL EMBEDDING\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'Inverse objective contains branch outcome: NO\n');
fprintf(fid,'New algorithm / policy tuning: NONE\n');
fprintf(fid,'Noise / clutter: OFF\n\n');

fprintf(fid,'[FROZEN TARGET SELECTION]\n');
fprintf(fid,'selection_class=%s\n',cls);
fprintf(fid,'trial_id=%d\n',T.trial_id);
fprintf(fid,'risk_state_id=%d\n',T.risk_state_id);
fprintf(fid,'target_beta_s_rad=%.15g\n',T.beta_s_rad);
fprintf(fid,'target_beta_w_rad=%.15g\n',T.beta_w_rad);
fprintf(fid,'target_eta_bins=%.15g\n',T.eta_bins);
fprintf(fid,'target_weak_to_strong_ratio=%.15g\n',T.weak_to_strong_ratio);
fprintf(fid,'target_relative_phase_rad=%.15g\n',T.relative_phase_rad);
fprintf(fid,'target_Gamma=%.15g\n',T.Gamma);
fprintf(fid,'stored_G0_branch_error_bins=%.15g\n',T.g0_branch_error_bins);
fprintf(fid,'stored_Proposed_branch_error_bins=%.15g\n',T.proposed_branch_error_bins);
fprintf(fid,'stored_N3_branch_error_bins=%.15g\n\n',T.n3_branch_error_bins);

fprintf(fid,'[SOLVED PHYSICAL STATE]\n');
fprintf(fid,'solver_objective=%.15g\n',Sol.best_objective);
fprintf(fid,'x_strong_center_m=%.15g\n',C.p.x_strong_center_m);
fprintf(fid,'x_weak_center_m=%.15g\n',C.p.x_weak_center_m);
fprintf(fid,'common_y_offset_m=%.15g\n',C.p.common_y_offset_m);
fprintf(fid,'yaw_amplitude_deg=%.15g\n',C.p.yaw_amplitude_rad*180/pi);
fprintf(fid,'yaw_period_s=%.15g\n',C.p.yaw_period_s);
fprintf(fid,'yaw_phase0_rad=%.15g\n',C.p.yaw_phase0_rad);
fprintf(fid,'strong_body_xy_m=%.15g\t%.15g\n',C.body_xy_m(1,1),C.body_xy_m(1,2));
fprintf(fid,'weak_body_xy_m=%.15g\t%.15g\n\n',C.body_xy_m(2,1),C.body_xy_m(2,2));

fprintf(fid,'[PHYSICAL-TO-SIGNAL TRANSLATION]\n');
fprintf(fid,'physical_beta_s_rad=%.15g\n',fs.beta_rad);
fprintf(fid,'physical_beta_w_rad=%.15g\n',fw.beta_rad);
fprintf(fid,'beta_error_over_W_strong=%.15g\n',ebs);
fprintf(fid,'beta_error_over_W_weak=%.15g\n',ebw);
fprintf(fid,'physical_nu_s_bins=%.15g\n',fs.nu_bins);
fprintf(fid,'physical_nu_w_bins=%.15g\n',fw.nu_bins);
fprintf(fid,'fractional_nu_error_strong_bins=%.15g\n',ens);
fprintf(fid,'fractional_nu_error_weak_bins=%.15g\n',enw);
fprintf(fid,'pair_absolute_nu_separation_bins=%.15g\n',nsep);
fprintf(fid,'phase_fit_nrmse_strong=%.15g\n',fs.phase_fit_nrmse);
fprintf(fid,'phase_fit_nrmse_weak=%.15g\n',fw.phase_fit_nrmse);
fprintf(fid,'effective_weak_to_strong_ratio=%.15g\n',ar);
fprintf(fid,'effective_relative_phase_rad=%.15g\n',pr);
fprintf(fid,'context_relative_L2_norm=%.15g\n',context_rel);
fprintf(fid,'pair_complex_correlation_with_full=%.15g\n',pair_corr);
fprintf(fid,'translation_gate=%d\n\n',gate);

fprintf(fid,'[BRANCH FALSIFICATION AFTER SCENE FREEZE]\n');
fprintf(fid,'strong_reference_nu_bins=%.15g\n',Sref.global_nu_bins);
fprintf(fid,'PAIR_coarse_top1_bin=%d\n',P.coarse_top1_bin);
fprintf(fid,'PAIR_G0_nu_bins=%.15g\n',P.G0.nu_hat_bins);
fprintf(fid,'PAIR_N3_nu_bins=%.15g\n',P.N3.nu_hat_bins);
fprintf(fid,'PAIR_G0_error_bins=%.15g\n',P.g0_error_bins);
fprintf(fid,'PAIR_N3_error_bins=%.15g\n',P.n3_error_bins);
fprintf(fid,'PAIR_G0_catastrophic=%d\n',P.g0_catastrophic);
fprintf(fid,'PAIR_N3_rescue=%d\n',P.n3_rescue);
fprintf(fid,'FULL_G0_error_bins=%.15g\n',F.g0_error_bins);
fprintf(fid,'FULL_N3_error_bins=%.15g\n',F.n3_error_bins);
fprintf(fid,'FULL_G0_catastrophic=%d\n',F.g0_catastrophic);
fprintf(fid,'FULL_N3_rescue=%d\n\n',F.n3_rescue);

fprintf(fid,'[PAIR COARSE TOP-5]\n');
for i=1:numel(P.coarse_top_bins)
    fprintf(fid,'rank%d\tbin=%d\tnorm_score=%.15g\n', ...
        i,P.coarse_top_bins(i),P.coarse_top_scores_normalized(i));
end

fprintf(fid,'\n[VERDICT]\n');
fprintf(fid,'stageB2_verdict=%s\n\n',verdict);

fprintf(fid,'[STOP / NEXT RULE]\n');
fprintf(fid,'1) If translation_gate=0: STOP. Do not run Proposed; the frozen DenseRisk state was not faithfully embedded.\n');
fprintf(fid,'2) If mapping passes but physical G0 catastrophe is absent: report non-realization under this pre-registered yaw-only family; do not try a second target in this stage.\n');
fprintf(fid,'3) If G0 catastrophe occurs but N3 does not rescue: STOP and compare physical landscape with the frozen DenseRisk geometry.\n');
fprintf(fid,'4) Only FULL_PHYSICAL_HARDSTATE_REALIZED_PROCEED_STAGEC authorizes frozen Proposed image-level integration.\n');
fprintf(fid,'5) No yaw/position/phase retuning is allowed after this formal run.\n\n');

fprintf(fid,'[UPLOAD REQUEST]\n');
fprintf(fid,'Return only: EXP01_STAGEB2_FEEDBACK_BUNDLE.txt, 07_stageB2_physical_embedding.png, 08_stageB2_branch_falsification.png.\n');
fprintf(fid,'Keep CSV/MAT locally unless an anomaly requires them.\n');
end

function validate_branch_audit_schema(A,label)
%VALIDATE_BRANCH_AUDIT_SCHEMA Guard the producer-consumer contract.
required = { ...
    'coarse_bins','coarse_objective','coarse_top1_bin', ...
    'coarse_top_bins','coarse_top_scores_normalized', ...
    'G0','N3','global_nu_bins','g0_error_bins','n3_error_bins', ...
    'g0_catastrophic','n3_catastrophic','n3_rescue'};
missing = required(~isfield(A,required));
if ~isempty(missing)
    error('EXP01_STAGEB2:BranchAuditSchemaMismatch', ...
        '%s is missing branch-audit field(s): %s',label,strjoin(missing,', '));
end
if ~isstruct(A.G0) || ~isfield(A.G0,'nu_hat_bins') || ...
        ~isstruct(A.N3) || ~isfield(A.N3,'nu_hat_bins')
    error('EXP01_STAGEB2:BranchAuditNestedSchemaMismatch', ...
        '%s.G0 / %s.N3 must contain nu_hat_bins.',label,label);
end
end

function validate_saved_stageB2_bundle(R)
%VALIDATE_SAVED_STAGEB2_BUNDLE Ensure reporting-resume inputs are complete.
required = { ...
    'target','selection_class','Sol','C','fit_s','fit_w', ...
    'x_strong','x_weak','Sref','PairAudit','FullAudit', ...
    'beta_s_err_W','beta_w_err_W','nu_s_frac_err','nu_w_frac_err','nu_sep', ...
    'effective_amp_ratio','effective_rel_phase','context_rel','pair_corr', ...
    'translation_gate','verdict'};
missing = required(~isfield(R,required));
if ~isempty(missing)
    error('EXP01_STAGEB2:ResumeBundleIncomplete', ...
        'Saved Stage-B2 MAT is missing field(s): %s',strjoin(missing,', '));
end
end

function y=wrap_pi(x)
y=mod(x+pi,2*pi)-pi;
end
function e=frac_bin_error(a,b)
e=abs(mod((a-b)+0.5,1)-0.5);
end
function d=periodic_bin_distance(a,b,N)
d=abs(mod((a-b)+N/2,N)-N/2);
end
function f=frac_coord(x)
f=mod(x+0.5,1)-0.5;
end
