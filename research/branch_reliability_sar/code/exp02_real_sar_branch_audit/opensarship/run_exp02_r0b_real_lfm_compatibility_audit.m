function run_exp02_r0b_real_lfm_compatibility_audit()
%RUN_EXP02_R0B_REAL_LFM_COMPATIBILITY_AUDIT
% EXP02-R0B — Real complex-line dominant-LFM compatibility audit.

clc;

this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
research_root = fileparts(code_dir);
func_dir = fullfile(research_root,'functions','opensarship');
addpath(this_dir);
addpath(func_dir);

cfg = config_exp02_r0b();
if ~exist(cfg.r0a_mat,'file')
    error('EXP02_R0B:MissingR0A','Missing R0A MAT: %s',cfg.r0a_mat);
end
if ~exist(cfg.output_dir,'dir'), mkdir(cfg.output_dir); end

A = load(cfg.r0a_mat);
required = {'S','selected_idx','line_energy','diag'};
for i=1:numel(required)
    if ~isfield(A,required{i})
        error('EXP02_R0B:R0ASchema','R0A MAT missing field: %s',required{i});
    end
end

S = A.S;
target_idx = A.selected_idx(:).';
line_energy = double(A.line_energy(:).');

if string(A.diag.primary_pol) ~= "VV"
    error('EXP02_R0B:PrimaryPolDrift','R0A primary polarization was not VV.');
end

X = S.VV;
N = size(X,1);
Nr = size(X,2);

is_target = false(1,Nr);
is_target(target_idx) = true;
candidate_bg = find(~is_target);
[~,ord] = sort(line_energy(candidate_bg),'ascend');
nT = numel(target_idx);
if numel(candidate_bg) < nT
    error('EXP02_R0B:BackgroundPool','Not enough non-target background columns.');
end
background_idx = candidate_bg(ord(1:nT));

all_idx = [target_idx background_idx];
group = [repmat("TARGET",1,nT) repmat("BACKGROUND",1,nT)];

metrics = repmat(struct( ...
    'range_col',0,'group',"",'line_energy',0,'best_coherence',0, ...
    'tone_coherence',0,'chirp_gain_db',0,'best_beta',0,'best_nu_bins',0, ...
    'beta_boundary_hit',false),1,numel(all_idx));

scan_cache = cell(1,numel(all_idx));

fprintf('============================================================\n');
fprintf('EXP02-R0B Real LFM Compatibility Audit\n');
fprintf('N=%d | target=%d | background=%d\n',N,nT,nT);
fprintf('No branch algorithms are run.\n');
fprintf('============================================================\n');

for k=1:numel(all_idx)
    n = all_idx(k);
    R = opensarship_lfm_coherence_scan(X(:,n),cfg.n_beta,cfg.nfft);
    scan_cache{k} = R;

    metrics(k).range_col = n;
    metrics(k).group = group(k);
    metrics(k).line_energy = line_energy(n);
    metrics(k).best_coherence = R.best_coherence;
    metrics(k).tone_coherence = R.tone_coherence;
    metrics(k).chirp_gain_db = R.chirp_gain_db;
    metrics(k).best_beta = R.best_beta;
    metrics(k).best_nu_bins = R.best_nu_bins;
    metrics(k).beta_boundary_hit = R.beta_boundary_hit;

    fprintf('%02d/%02d | %-10s n=%3d | C=%.4f | gain=%+.2f dB | beta=%+.5g | nu=%+.3f | edge=%d\n', ...
        k,numel(all_idx),group(k),n,R.best_coherence,R.chirp_gain_db, ...
        R.best_beta,R.best_nu_bins,R.beta_boundary_hit);
end

T = struct2table(metrics);
writetable(T,fullfile(cfg.output_dir,cfg.csv_name));

isT = T.group=="TARGET";
isB = T.group=="BACKGROUND";

summary = struct();
summary.target_n = sum(isT);
summary.background_n = sum(isB);
summary.target_coh_median = median(T.best_coherence(isT));
summary.target_coh_q25 = prctile(T.best_coherence(isT),25);
summary.target_coh_q75 = prctile(T.best_coherence(isT),75);
summary.background_coh_median = median(T.best_coherence(isB));
summary.background_coh_q25 = prctile(T.best_coherence(isB),25);
summary.background_coh_q75 = prctile(T.best_coherence(isB),75);
summary.target_gain_median_db = median(T.chirp_gain_db(isT));
summary.target_gain_q25_db = prctile(T.chirp_gain_db(isT),25);
summary.target_gain_q75_db = prctile(T.chirp_gain_db(isT),75);
summary.background_gain_median_db = median(T.chirp_gain_db(isB));
summary.background_gain_q25_db = prctile(T.chirp_gain_db(isB),25);
summary.background_gain_q75_db = prctile(T.chirp_gain_db(isB),75);
summary.target_beta_edge_hits = sum(T.beta_boundary_hit(isT));
summary.background_beta_edge_hits = sum(T.beta_boundary_hit(isB));

target_energy = line_energy(target_idx);
[~,eo] = sort(target_energy,'descend');
strong_idx = target_idx(eo(1));
weak_idx = target_idx(eo(end));
med_rank = round((numel(eo)+1)/2);
median_idx = target_idx(eo(med_rank));
rep_idx = [strong_idx median_idx weak_idx];
rep_labels = ["strongest selected energy","median selected energy","weakest selected energy"];

fig1 = figure('Color','w','Name','EXP02-R0B LFM compatibility overview');
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

nexttile;
scatter(T.range_col(isB),T.best_coherence(isB),32,'x'); hold on;
scatter(T.range_col(isT),T.best_coherence(isT),42,'filled');
grid on;
xlabel('Range-column index n');
ylabel('dominant LFM coherence');
title('Real SLC dominant single-LFM projection coherence');
legend('lowest-energy background control','natural target lines','Location','best');

nexttile;
scatter(T.range_col(isB),T.chirp_gain_db(isB),32,'x'); hold on;
scatter(T.range_col(isT),T.chirp_gain_db(isT),42,'filled');
yline(0,'k:');
grid on;
xlabel('Range-column index n');
ylabel('chirp gain over \beta=0 (dB)');
title('Benefit of nonzero chirp rate over tone-only model');
legend('background control','natural target lines','Location','best');

exportgraphics(fig1,fullfile(cfg.output_dir,cfg.fig1_name),'Resolution',180);

fig2 = figure('Color','w','Name','EXP02-R0B representative beta profiles');
tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

rep_metrics = repmat(struct(),1,3);
for r=1:3
    n = rep_idx(r);
    k = find(all_idx==n & group=="TARGET",1);
    R = scan_cache{k};

    nexttile;
    plot(R.beta_grid,R.beta_profile,'LineWidth',1.4); hold on;
    xline(0,'k:');
    xline(R.best_beta,'r--');
    grid on;
    xlabel('\beta (cycles/sample^2, discrete LFM convention)');
    ylabel('max_\nu coherence');
    title(sprintf('%s | n=%d | C=%.3f | gain=%+.2f dB | \\beta=%+.4g', ...
        rep_labels(r),n,R.best_coherence,R.chirp_gain_db,R.best_beta));

    rep_metrics(r).range_col = n;
    rep_metrics(r).label = rep_labels(r);
    rep_metrics(r).coherence = R.best_coherence;
    rep_metrics(r).tone_coherence = R.tone_coherence;
    rep_metrics(r).gain_db = R.chirp_gain_db;
    rep_metrics(r).best_beta = R.best_beta;
    rep_metrics(r).best_nu_bins = R.best_nu_bins;
    rep_metrics(r).beta_boundary_hit = R.beta_boundary_hit;
end

exportgraphics(fig2,fullfile(cfg.output_dir,cfg.fig2_name),'Resolution',180);

save(fullfile(cfg.output_dir,cfg.mat_name), ...
    'cfg','T','summary','rep_idx','rep_labels','rep_metrics', ...
    'target_idx','background_idx');

fb = fullfile(cfg.output_dir,cfg.feedback_name);
fid = fopen(fb,'w');
if fid<0, error('Cannot open feedback bundle.'); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-R0B / REAL COMPLEX-LINE DOMINANT LFM COMPATIBILITY AUDIT\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'G0: NOT RUN\n');
fprintf(fid,'Neighbor-3: NOT RUN\n');
fprintf(fid,'Proposed: NOT RUN\n');
fprintf(fid,'Branch taxonomy: NOT RUN\n\n');

fprintf(fid,'[RESEARCH QUESTION]\n');
fprintf(fid,['Do natural fixed-range azimuth lines from the real OpenSARShip SLC ' ...
    'show coherent support for the same local discrete-LFM family?\n\n']);

fprintf(fid,'[SIGNAL DEFINITION]\n');
fprintf(fid,'primary_pol=VV\n');
fprintf(fid,'row=azimuth_y\n');
fprintf(fid,'column=range_x\n');
fprintf(fid,'processing_object=g(:,n)=S(:,n)\n');
fprintf(fid,'N=%d\n',N);
fprintf(fid,'beta_search=[-1/N,+1/N]\n');
fprintf(fid,'n_beta=%d\n',cfg.n_beta);
fprintf(fid,'nfft=%d\n',cfg.nfft);
fprintf(fid,['coherence=max|<x,s(beta,nu)>|^2/(N*||x||^2); ' ...
    'diagnostic dominant single-LFM projection fraction, not a reliability feature.\n\n']);

fprintf(fid,'[POOLS]\n');
fprintf(fid,'target_rule=R0A energy_gt_mean\n');
fprintf(fid,'target_n=%d\n',summary.target_n);
fprintf(fid,'background_rule=lowest_energy_equal_count\n');
fprintf(fid,'background_n=%d\n',summary.background_n);
fprintf(fid,'target_indices='); fprintf(fid,'%d ',target_idx); fprintf(fid,'\n');
fprintf(fid,'background_indices='); fprintf(fid,'%d ',background_idx); fprintf(fid,'\n\n');

fprintf(fid,'[TARGET DOMINANT-LFM COHERENCE]\n');
fprintf(fid,'median=%.15g\n',summary.target_coh_median);
fprintf(fid,'q25=%.15g\n',summary.target_coh_q25);
fprintf(fid,'q75=%.15g\n',summary.target_coh_q75);
fprintf(fid,'beta_boundary_hits=%d/%d\n\n', ...
    summary.target_beta_edge_hits,summary.target_n);

fprintf(fid,'[BACKGROUND DOMINANT-LFM COHERENCE]\n');
fprintf(fid,'median=%.15g\n',summary.background_coh_median);
fprintf(fid,'q25=%.15g\n',summary.background_coh_q25);
fprintf(fid,'q75=%.15g\n',summary.background_coh_q75);
fprintf(fid,'beta_boundary_hits=%d/%d\n\n', ...
    summary.background_beta_edge_hits,summary.background_n);

fprintf(fid,'[CHIRP GAIN OVER BETA=0]\n');
fprintf(fid,'target_median_dB=%.15g\n',summary.target_gain_median_db);
fprintf(fid,'target_q25_dB=%.15g\n',summary.target_gain_q25_db);
fprintf(fid,'target_q75_dB=%.15g\n',summary.target_gain_q75_db);
fprintf(fid,'background_median_dB=%.15g\n',summary.background_gain_median_db);
fprintf(fid,'background_q25_dB=%.15g\n',summary.background_gain_q25_db);
fprintf(fid,'background_q75_dB=%.15g\n\n',summary.background_gain_q75_db);

fprintf(fid,'[REPRESENTATIVE TARGET LINES — ENERGY-BASED, NOT OUTCOME-BASED]\n');
for r=1:3
    M=rep_metrics(r);
    fprintf(fid,['%s | n=%d | C=%.15g | toneC=%.15g | gain_dB=%.15g | ' ...
        'beta=%.15g | nu_bins=%.15g | beta_edge=%d\n'], ...
        M.label,M.range_col,M.coherence,M.tone_coherence,M.gain_db, ...
        M.best_beta,M.best_nu_bins,M.beta_boundary_hit);
end

fprintf(fid,'\n[INTERPRETATION]\n');
fprintf(fid,'automatic_model_validity_label=NOT_ASSIGNED\n');
fprintf(fid,['Reason: real ship lines are multi-component; low dominant single-LFM ' ...
    'projection fraction does not by itself falsify an MC-LFM model.\n']);
fprintf(fid,['Primary audit questions: (1) are target-line optima numerically interior, ' ...
    '(2) is nonzero-beta gain reproducible across natural target lines, and ' ...
    '(3) are target results distinguishable from lowest-energy background controls?\n\n']);

fprintf(fid,'[STOP RULE]\n');
fprintf(fid,['If target lines show no coherent nonzero-beta structure beyond controls, ' ...
    'do not proceed to branch-state occurrence on this chip.\n']);
fprintf(fid,['If target lines show stable interior chirp-like structure, proceed to EXP02-R1 ' ...
    'using frozen branch-search semantics; do not tune R0B to manufacture validity.\n\n']);

fprintf(fid,'[UPLOAD REQUEST]\n');
fprintf(fid,'Return only: %s, %s, %s.\n', ...
    cfg.feedback_name,cfg.fig1_name,cfg.fig2_name);

fprintf('\nEXP02-R0B completed.\n');
fprintf('Feedback: %s\n',fb);
end
