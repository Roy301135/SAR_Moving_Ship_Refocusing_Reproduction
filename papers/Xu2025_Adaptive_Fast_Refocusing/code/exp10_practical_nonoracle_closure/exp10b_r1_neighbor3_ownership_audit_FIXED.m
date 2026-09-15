function results = exp10b_r1_neighbor3_ownership_audit()
%EXP10B_R1_NEIGHBOR3_OWNERSHIP_AUDIT
% EXP010-B-R1 — Recovery-Operator Ownership Audit
%
% Trigger:
%   EXP010-B found that the frozen staged policy retained strict positive
%   DenseRisk gains with no induced branch catastrophes, but Always-N3 was
%   no longer branch-safe after fully practical strong-beta estimation.
%
% This audit asks one narrow question:
%
%   WHY does Neighbor-3 lose branch safety in the fully practical chain?
%
% It does NOT change:
%   - Refined-LR / FiveBin definitions;
%   - b1 = 0.20 / b2 = 0.10;
%   - Neighbor-3 candidate count;
%   - removal width;
%   - any Proposed decision.
%
% Audit controls:
%   A) Practical-beta N3 + practical-beta global reference (replay)
%   B) True-beta N3 + true-beta global reference (oracle mechanism control)
%   C) Candidate-coverage geometry for A and B
%
% Main decision:
%   - if true-beta control resolves the practical-N3 failures, the new
%     limitation is owned by upstream beta-hat mismatch / landscape
%     deformation;
%   - if failures persist under true beta and the global basin is outside
%     the N3 candidate union, adjacency coverage is insufficient;
%   - if failures persist under true beta despite candidate coverage, stop
%     and audit implementation / local-refinement transfer before noise.

cfg = config_exp10b_r1_neighbor3_ownership_audit();
validate_cfg(cfg);
ensure_dirs(cfg);
validate_inputs_exist(cfg);

fprintf('\n============================================================\n');
fprintf('EXP010-B-R1 — Neighbor-3 Ownership Audit\n');
fprintf('============================================================\n');
fprintf('This is an evaluation-only deterministic audit.\n');
fprintf('No policy or recovery parameter is retuned.\n\n');

T = readtable(cfg.truth_file,'TextType','string');
O = readtable(cfg.online_file,'TextType','string');
E = readtable(cfg.eval_file,'TextType','string');
validate_input_schemas(T,O,E);

N3 = E(string(E.method)=="Always_Neighbor3",:);
if isempty(N3)
    error('EXP010B_R1:NoAlwaysN3','Always_Neighbor3 rows not found.');
end

selected = build_audit_selection(N3,cfg);
fprintf('Current N3 catastrophic failures to audit: %d\n',sum(selected.is_current_failure));
fprintf('Deterministic success controls: %d\n',sum(~selected.is_current_failure));

A = run_ownership_audit(selected,T,O,N3,cfg);
S = summarize_ownership(A);
Assoc = summarize_beta_error_association(N3);
V = build_verdict(A,S,cfg);

writetable(A,fullfile(cfg.output_dir,'neighbor3_ownership_trials.csv'));
writetable(S,fullfile(cfg.output_dir,'neighbor3_ownership_summary.csv'));
writetable(Assoc,fullfile(cfg.output_dir,'beta_error_failure_association.csv'));
writetable(V,fullfile(cfg.output_dir,'ownership_verdict.csv'));

make_figures(S,Assoc,cfg);
write_feedback_bundle(A,S,Assoc,V,cfg);

save(fullfile(cfg.output_dir,'exp10b_r1_ownership_results.mat'), ...
    'A','S','Assoc','V','cfg');

results = struct();
results.audit_trials = A;
results.summary = S;
results.beta_error_association = Assoc;
results.verdict = V;
results.cfg = cfg;

fprintf('\nR1 verdict: %s\n',string(V.overall_verdict(1)));
fprintf('Outputs: %s\n',cfg.output_dir);
fprintf('Feedback bundle: %s\n\n',fullfile(cfg.output_dir,cfg.feedback_bundle_name));

end

%% ========================================================================
function validate_cfg(cfg)
assert(cfg.neighbor_radius==1,'Neighbor-3 candidate count changed.');
assert(abs(cfg.local_search_halfwidth_bins-0.75)<eps,'Local halfwidth changed.');
assert(abs(cfg.branch_match_tolerance_bins-0.02)<eps,'Branch-match tolerance changed.');
assert(abs(cfg.catastrophic_error_threshold_bins-0.10)<eps,'Catastrophic threshold changed.');
assert(abs(cfg.global_search_halfwidth_bins-1.5)<eps,'Global reference halfwidth changed.');
assert(abs(cfg.global_grid_step_bins-1e-3)<eps,'Global reference grid changed.');
end

function ensure_dirs(cfg)
if ~exist(cfg.output_dir,'dir'), mkdir(cfg.output_dir); end
if ~exist(cfg.figure_dir,'dir'), mkdir(cfg.figure_dir); end
end

function validate_inputs_exist(cfg)
files = {cfg.truth_file,cfg.online_file,cfg.eval_file};
for i=1:numel(files)
    if ~exist(files{i},'file')
        error('EXP010B_R1:MissingInput','Required EXP010-B input missing:\n%s',files{i});
    end
end
end

function validate_input_schemas(T,O,E)
reqT = ["validation_set","trial_id","aperture_mode","azimuth_samples", ...
    "true_a_strong","true_a_weak","truth_beta_s_rad","truth_beta_w_rad", ...
    "weak_to_strong_ratio","relative_phase_rad","true_eta_bins"];
reqO = ["validation_set","trial_id","aperture_mode","beta_hat_strong_rad", ...
    "n3_nu_hat_bins"];
reqE = ["validation_set","trial_id","aperture_mode","method", ...
    "eta_hat_bins","branch_error_to_reference_bins", ...
    "catastrophic_branch_failure","strong_beta_abs_error_over_W"];
check_fields(T,reqT,'truth_metadata_all');
check_fields(O,reqO,'practical_online_outputs_all');
check_fields(E,reqE,'evaluation_trials_all');
end

function check_fields(T,req,name)
missing = setdiff(req,string(T.Properties.VariableNames));
if ~isempty(missing)
    error('EXP010B_R1:Schema','%s missing fields: %s',name,strjoin(missing,', '));
end
end

%% ========================================================================
function Sel = build_audit_selection(N3,cfg)
sets = unique(string(N3.validation_set),'stable');
aps = unique(string(N3.aperture_mode),'stable');
rows = {};

for is=1:numel(sets)
    for ia=1:numel(aps)
        M = N3(string(N3.validation_set)==sets(is) & ...
            string(N3.aperture_mode)==aps(ia),:);
        if isempty(M), continue; end

        F = M(logical(M.catastrophic_branch_failure),:);
        for k=1:height(F)
            rows(end+1,:) = {char(sets(is)),char(aps(ia)),F.trial_id(k),true}; %#ok<AGROW>
        end

        Q = M(~logical(M.catastrophic_branch_failure),:);
        nc = min(cfg.n_success_controls_per_group,height(Q));
        if nc>0
            idx = unique(round(linspace(1,height(Q),nc)));
            for k=1:numel(idx)
                rows(end+1,:) = {char(sets(is)),char(aps(ia)),Q.trial_id(idx(k)),false}; %#ok<AGROW>
            end
        end
    end
end

Sel = cell2table(rows,'VariableNames', ...
    {'validation_set','aperture_mode','trial_id','is_current_failure'});
end

%% ========================================================================
function A = run_ownership_audit(Sel,T,O,N3,cfg)
rows = {};

for i=1:height(Sel)
    if mod(i,25)==0 || i==1 || i==height(Sel)
        fprintf('  ownership audit: %d / %d\n',i,height(Sel));
    end

    vs = string(Sel.validation_set(i));
    ap = string(Sel.aperture_mode(i));
    tid = Sel.trial_id(i);

    tr = unique_row(T,vs,ap,tid,'truth');
    on = unique_row(O,vs,ap,tid,'online');
    st = unique_row(N3,vs,ap,tid,'stored N3 evaluation');

    proc = build_processing_context(ap,tr.azimuth_samples(1),cfg);
    x = synth_from_truth(tr,proc.N);

    a_pr = tan(on.beta_hat_strong_rad(1));
    a_true = tr.true_a_strong(1);

    [Gp,dp] = estimate_neighbor3_with_diag(x,a_pr,cfg);
    Rp = estimate_global_reference(x,a_pr,cfg);
    errp = abs(circular_bin_error(Gp.nu_hat_bins,Rp.nu_hat_bins));
    catp = errp > cfg.catastrophic_error_threshold_bins;

    [Gt,dt] = estimate_neighbor3_with_diag(x,a_true,cfg);
    Rt = estimate_global_reference(x,a_true,cfg);
    errt = abs(circular_bin_error(Gt.nu_hat_bins,Rt.nu_hat_bins));
    catt = errt > cfg.catastrophic_error_threshold_bins;

    rec_nu_mismatch = abs(Gp.nu_hat_bins - st.eta_hat_bins(1));
    rec_err_mismatch = abs(errp - st.branch_error_to_reference_bins(1));

    practical_cover = candidate_union_covers_reference( ...
        dp.seeds,Rp.nu_hat_bins,cfg.local_search_halfwidth_bins);
    true_cover = candidate_union_covers_reference( ...
        dt.seeds,Rt.nu_hat_bins,cfg.local_search_halfwidth_bins);

    practical_min_seed_dist = min(abs(dp.seeds - Rp.nu_hat_bins));
    true_min_seed_dist = min(abs(dt.seeds - Rt.nu_hat_bins));

    beta_err_W = abs(on.beta_hat_strong_rad(1)-tr.truth_beta_s_rad(1))/proc.Wbeta;

    if Sel.is_current_failure(i)
        if ~catt
            ownership = "RESOLVED_BY_TRUE_BETA";
        elseif ~true_cover
            ownership = "PERSISTS_TRUE_BETA_ADJACENCY_COVERAGE";
        else
            ownership = "PERSISTS_TRUE_BETA_WITHIN_COVERAGE";
        end
    else
        if ~catp && ~catt
            ownership = "CONTROL_STABLE";
        elseif ~catp && catt
            ownership = "CONTROL_TRUE_BETA_INDUCED_FAILURE";
        elseif catp
            ownership = "CONTROL_REPLAY_UNEXPECTED_FAILURE";
        else
            ownership = "CONTROL_OTHER";
        end
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(vs),char(ap),tid,Sel.is_current_failure(i), ...
        beta_err_W,on.beta_hat_strong_rad(1),tr.truth_beta_s_rad(1), ...
        st.eta_hat_bins(1),Gp.nu_hat_bins,Rp.nu_hat_bins,errp,catp, ...
        dp.coarse_seed_primary,practical_min_seed_dist,practical_cover, ...
        Gt.nu_hat_bins,Rt.nu_hat_bins,errt,catt, ...
        dt.coarse_seed_primary,true_min_seed_dist,true_cover, ...
        rec_nu_mismatch,rec_err_mismatch,char(ownership)};
end

A = cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','trial_id','is_current_failure', ...
    'practical_beta_error_over_W','practical_beta_hat_rad','truth_beta_s_rad', ...
    'stored_n3_nu_bins','replayed_practical_n3_nu_bins', ...
    'practical_global_reference_nu_bins','practical_branch_error_bins', ...
    'practical_catastrophic','practical_coarse_seed_primary', ...
    'practical_min_reference_to_seed_distance_bins', ...
    'practical_candidate_union_covers_reference', ...
    'truebeta_n3_nu_bins','truebeta_global_reference_nu_bins', ...
    'truebeta_branch_error_bins','truebeta_catastrophic', ...
    'truebeta_coarse_seed_primary','truebeta_min_reference_to_seed_distance_bins', ...
    'truebeta_candidate_union_covers_reference', ...
    'reconstruction_nu_mismatch_bins','reconstruction_branch_error_mismatch_bins', ...
    'ownership_class'});
end

function R = unique_row(T,vs,ap,tid,label)
idx = string(T.validation_set)==vs & string(T.aperture_mode)==ap & T.trial_id==tid;
R = T(idx,:);
if height(R)~=1
    error('EXP010B_R1:Key','Expected 1 %s row for %s/%s/trial %g, found %d.', ...
        label,vs,ap,tid,height(R));
end
end

%% ========================================================================
function S = summarize_ownership(A)
sets=unique(string(A.validation_set),'stable');
aps=unique(string(A.aperture_mode),'stable');
rows={};

for is=1:numel(sets)
    for ia=1:numel(aps)
        M=A(string(A.validation_set)==sets(is) & string(A.aperture_mode)==aps(ia),:);
        if isempty(M), continue; end
        F=M(M.is_current_failure,:);
        C=M(~M.is_current_failure,:);

        rows(end+1,:)={ ... %#ok<AGROW>
            char(sets(is)),char(aps(ia)),height(F),height(C), ...
            sum(string(F.ownership_class)=="RESOLVED_BY_TRUE_BETA"), ...
            sum(F.truebeta_catastrophic), ...
            sum(~F.practical_candidate_union_covers_reference), ...
            sum(~F.truebeta_candidate_union_covers_reference), ...
            sum(string(F.ownership_class)=="PERSISTS_TRUE_BETA_WITHIN_COVERAGE"), ...
            median(F.practical_beta_error_over_W,'omitnan'), ...
            max(F.reconstruction_nu_mismatch_bins,[],'omitnan'), ...
            max(F.reconstruction_branch_error_mismatch_bins,[],'omitnan'), ...
            sum(string(C.ownership_class)=="CONTROL_TRUE_BETA_INDUCED_FAILURE")};
    end
end

S=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','n_current_n3_failures','n_success_controls', ...
    'n_failures_resolved_by_true_beta','n_failures_persistent_under_true_beta', ...
    'n_practical_candidate_coverage_miss','n_truebeta_candidate_coverage_miss', ...
    'n_truebeta_persistent_within_coverage','median_beta_error_over_W_among_failures', ...
    'max_reconstruction_nu_mismatch_bins','max_reconstruction_branch_error_mismatch_bins', ...
    'n_control_truebeta_induced_failures'});
end

%% ========================================================================
function B = summarize_beta_error_association(N3)
sets=unique(string(N3.validation_set),'stable');
aps=unique(string(N3.aperture_mode),'stable');
rows={};
for is=1:numel(sets)
    for ia=1:numel(aps)
        M=N3(string(N3.validation_set)==sets(is) & string(N3.aperture_mode)==aps(ia),:);
        if isempty(M), continue; end
        y=logical(M.catastrophic_branch_failure);
        x=double(M.strong_beta_abs_error_over_W);
        if any(y) && any(~y)
            auc=rank_auc(x,y); % high beta error -> N3 failure
        else
            auc=NaN;
        end
        rows(end+1,:)={ ... %#ok<AGROW>
            char(sets(is)),char(aps(ia)),height(M),sum(y),mean(y), ...
            median(x(y),'omitnan'),median(x(~y),'omitnan'),auc};
    end
end
B=cell2table(rows,'VariableNames',{ ...
    'validation_set','aperture_mode','n_trials','n_n3_failures','n3_failure_rate', ...
    'median_beta_error_over_W_failures','median_beta_error_over_W_successes', ...
    'beta_error_directional_AUC_for_n3_failure'});
end

%% ========================================================================
function V = build_verdict(A,S,cfg)
max_nu=max(A.reconstruction_nu_mismatch_bins,[],'omitnan');
max_be=max(A.reconstruction_branch_error_mismatch_bins,[],'omitnan');
reconstruction_pass = max_nu<=cfg.reconstruction_tolerance_bins && ...
    max_be<=cfg.branch_error_reconstruction_tolerance;

F=A(A.is_current_failure,:);
nfail=height(F);
resolved=sum(string(F.ownership_class)=="RESOLVED_BY_TRUE_BETA");
persist=sum(F.truebeta_catastrophic);
true_coverage_miss=sum(~F.truebeta_candidate_union_covers_reference);
within=sum(string(F.ownership_class)=="PERSISTS_TRUE_BETA_WITHIN_COVERAGE");
control_induced=sum(string(A.ownership_class)=="CONTROL_TRUE_BETA_INDUCED_FAILURE");

if ~reconstruction_pass
    verdict="FAIL_RECONSTRUCTION_AUDIT";
elseif nfail==0
    verdict="NO_PRACTICAL_N3_FAILURES_TO_AUDIT";
elseif persist==0 && control_induced==0
    verdict="UPSTREAM_BETA_MISMATCH_OWNS_N3_LIMITATION";
elseif persist>0 && within==0 && true_coverage_miss==persist
    verdict="N3_ADJACENCY_LIMIT_PERSISTS_UNDER_TRUE_BETA";
elseif persist>0 && within>0
    verdict="LOCAL_REFINEMENT_OR_TRANSFER_AUDIT_REQUIRED";
else
    verdict="MIXED_OWNERSHIP_REVIEW_REQUIRED";
end

V=table(verdict,reconstruction_pass,nfail,resolved,persist,true_coverage_miss,within, ...
    control_induced,max_nu,max_be, ...
    'VariableNames',{ ...
    'overall_verdict','reconstruction_pass','n_current_n3_failures', ...
    'n_resolved_by_true_beta','n_persistent_under_true_beta', ...
    'n_truebeta_candidate_coverage_miss','n_truebeta_persistent_within_coverage', ...
    'n_control_truebeta_induced_failures','max_reconstruction_nu_mismatch_bins', ...
    'max_reconstruction_branch_error_mismatch_bins'});
end

%% ========================================================================
function proc = build_processing_context(mode,N,cfg)
if mode=="Paper1s"
    Wbeta=cfg.pa4_beta_width_paper_rad;
elseif mode=="BeamDerived"
    Wbeta=cfg.pa4_beta_width_beam_rad;
else
    error('Unknown aperture: %s',mode);
end
proc=struct('N',N,'Wbeta',Wbeta);
end

function x = synth_from_truth(tr,N)
b=tr.true_eta_bins(1)/N;
s=synth_discrete_lfm(N,1,tr.true_a_strong(1),b,0);
w=synth_discrete_lfm(N,tr.weak_to_strong_ratio(1),tr.true_a_weak(1),b,tr.relative_phase_rad(1));
x=s+w;
end

function [G,D] = estimate_neighbor3_with_diag(x,a,cfg)
z=dechirp_signal(x,a);
N=numel(z); m=0:N-1;
Y=fftshift(fft(z));
[~,i0]=max(abs(Y));
dc=floor(N/2)+1;
k0=i0-dc;
seeds=(k0-cfg.neighbor_radius):(k0+cfg.neighbor_radius);
nu_best=NaN; Jbest=-Inf; total=0;
for s=seeds
    [nu,J,neval]=refine_from_seed(z,m,N,s,cfg);
    total=total+neval;
    if J>Jbest
        Jbest=J; nu_best=nu;
    end
end
G=struct('nu_hat_bins',nu_best,'objective_at_hat',Jbest, ...
    'n_objective_evals',total,'coarse_seed_primary',k0);
D=struct('coarse_seed_primary',k0,'seeds',seeds);
end

function G = estimate_global_reference(x,a,cfg)
z=dechirp_signal(x,a);
N=numel(z); m=0:N-1;
d=-cfg.global_search_halfwidth_bins:cfg.global_grid_step_bins:cfg.global_search_halfwidth_bins;
J=zeros(size(d));
for i=1:numel(d), J(i)=tone_objective(z,m,N,d(i)); end
[~,ig]=max(J);
i1=max(1,ig-1); i2=min(numel(d),ig+1);
lb=d(i1); ub=d(i2);
count=0;
opts=optimset('Display','off','TolX',cfg.global_tolx_bins,'MaxFunEvals',cfg.global_max_fun_evals);
if ub<=lb
    nu=d(ig); Jhat=J(ig);
else
    [nu,fval]=fminbnd(@wrapped_obj,lb,ub,opts);
    Jhat=-fval;
end
G=struct('nu_hat_bins',nu,'objective_at_hat',Jhat,'n_objective_evals',numel(d)+count);
    function y=wrapped_obj(q)
        count=count+1;
        y=-tone_objective(z,m,N,q);
    end
end

function [nu_hat,Jhat,neval] = refine_from_seed(z,m,N,seed,cfg)
lb=seed-cfg.local_search_halfwidth_bins;
ub=seed+cfg.local_search_halfwidth_bins;
grid=linspace(lb,ub,cfg.local_bracket_points);
J=zeros(size(grid));
for i=1:numel(grid), J(i)=tone_objective(z,m,N,grid(i)); end
neval=numel(grid);
[~,ib]=max(J);
i1=max(1,ib-1); i2=min(numel(grid),ib+1);
local_lb=grid(i1); local_ub=grid(i2);
if local_ub<=local_lb
    nu_hat=grid(ib); Jhat=J(ib); return;
end
count=0;
opts=optimset('Display','off','TolX',cfg.local_tolx_bins,'MaxFunEvals',cfg.local_max_fun_evals);
[nu_hat,fval]=fminbnd(@wrapped_obj,local_lb,local_ub,opts);
Jhat=-fval; neval=neval+count;
    function y=wrapped_obj(q)
        count=count+1;
        y=-tone_objective(z,m,N,q);
    end
end

function tf = candidate_union_covers_reference(seeds,nu_ref,halfwidth)
tf = any(abs(seeds-nu_ref)<=halfwidth+1e-12);
end

function J = tone_objective(z,m,N,nu)
q=sum(z.*exp(-1j*2*pi*nu*m/N));
J=abs(q).^2;
end

function z=dechirp_signal(x,a)
x=x(:).'; N=numel(x); m=0:N-1;
z=x.*exp(-1j*pi*a*m.^2);
end

function x=synth_discrete_lfm(N,A,a,b,phi)
m=0:N-1;
x=A.*exp(1j*2*pi*(0.5*a*m.^2+b*m)+1j*phi);
x=x(:).';
end

function e=circular_bin_error(a,b)
% Inherited verbatim from PA5I / EXP010-B evaluation semantics.
e=mod((a-b)+0.5,1)-0.5;
end

function auc=rank_auc(score,y)
score=score(:); y=logical(y(:));
ok=isfinite(score);
score=score(ok); y=y(ok);
pos=score(y); neg=score(~y);
if isempty(pos) || isempty(neg), auc=NaN; return; end
% Exact pairwise AUC with 0.5 credit for ties; sample sizes are modest.
auc=(sum(pos'>neg,'all') + 0.5*sum(pos'==neg,'all'))/(numel(pos)*numel(neg));
end

%% ========================================================================
function make_figures(S,B,cfg)
% Figure 1 — current N3 failure ownership under true-beta control.
f=figure('Visible',cfg.figure_visible,'Position',[100 100 1100 650]);
labels=strcat(string(S.validation_set)," | ",string(S.aperture_mode));
Y=[S.n_failures_resolved_by_true_beta, S.n_failures_persistent_under_true_beta];
bar(Y,'stacked');
set(gca,'XTick',1:height(S),'XTickLabel',labels,'XTickLabelRotation',18);
ylabel('Current Always-N3 catastrophic failures');
title('EXP010-B-R1: ownership of practical Neighbor-3 failures');
legend({'Resolved by true-beta control','Persistent under true beta'},'Interpreter','none','Location','best');
grid on;
exportgraphics(f,fullfile(cfg.figure_dir,'fig01_neighbor3_failure_ownership.png'),'Resolution',180);
close(f);

% Figure 2 — beta-error association with practical N3 failure.
f=figure('Visible',cfg.figure_visible,'Position',[100 100 1100 650]);
Y=[B.median_beta_error_over_W_successes, B.median_beta_error_over_W_failures];
bar(Y);
set(gca,'XTick',1:height(B),'XTickLabel',strcat(string(B.validation_set)," | ",string(B.aperture_mode)), ...
    'XTickLabelRotation',18);
ylabel('Median |beta-hat - beta_s| / W_beta');
title('Upstream beta error versus practical Neighbor-3 failure');
legend({'N3 success','N3 failure'},'Interpreter','none','Location','best');
grid on;
exportgraphics(f,fullfile(cfg.figure_dir,'fig02_beta_error_failure_association.png'),'Resolution',180);
close(f);
end

%% ========================================================================
function write_feedback_bundle(A,S,B,V,cfg)
path=fullfile(cfg.output_dir,cfg.feedback_bundle_name);
fid=fopen(path,'w');
if fid<0, error('Could not open feedback bundle: %s',path); end
cleanup=onCleanup(@() fclose(fid));

fprintf(fid,'EXP010-B-R1 / NEIGHBOR-3 OWNERSHIP AUDIT\n');
fprintf(fid,'=========================================\n');
fprintf(fid,'Noise/clutter: OFF\n');
fprintf(fid,'Method redesign: NONE\n');
fprintf(fid,'Frozen Neighbor-3: radius=1, local halfwidth=0.75 bin\n');
fprintf(fid,'Audit control: replace practical beta-hat with true beta ONLY in evaluation-control branch\n\n');

fprintf(fid,'[VERDICT]\n');
append_table_tsv(fid,V);
fprintf(fid,'\n[OWNERSHIP SUMMARY]\n');
append_table_tsv(fid,S);
fprintf(fid,'\n[BETA-ERROR / N3-FAILURE ASSOCIATION]\n');
append_table_tsv(fid,B);

fprintf(fid,'\n[OWNERSHIP CLASS COUNTS]\n');
classes=unique(string(A.ownership_class),'stable');
for i=1:numel(classes)
    fprintf(fid,'%s\t%d\n',classes(i),sum(string(A.ownership_class)==classes(i)));
end

fprintf(fid,'\n[INTERPRETATION RULES]\n');
fprintf(fid,'1) This audit does not modify the frozen Proposed policy.\n');
fprintf(fid,'2) True beta is an oracle mechanism control only; it is forbidden in Proposed.\n');
fprintf(fid,'3) If practical N3 failures disappear under true beta, report an upstream-beta-conditioned validity boundary; do not expand to Neighbor-5.\n');
fprintf(fid,'4) If failures persist under true beta because the global basin lies outside all N3 local intervals, report an adjacency-coverage limitation.\n');
fprintf(fid,'5) If failures persist under true beta despite candidate coverage, STOP before noise and audit local-refinement / implementation transfer.\n');
fprintf(fid,'6) Only after ownership is resolved may the project proceed to SNR/noise-definition audit.\n');
end

function append_table_tsv(fid,T)
%APPEND_TABLE_TSV Serialize a MATLAB table as TSV into an already-open file.
% writetable() does not accept a numeric file identifier, so use a
% temporary text file and append its exact contents to the bundle.

tmp = [tempname, '.txt'];
cleanup = onCleanup(@() delete_if_exists(tmp));
writetable(T,tmp,'Delimiter','\t','FileType','text');
txt = fileread(tmp);
fprintf(fid,'%s',txt);
end

function delete_if_exists(path)
if isfile(path)
    delete(path);
end
end
