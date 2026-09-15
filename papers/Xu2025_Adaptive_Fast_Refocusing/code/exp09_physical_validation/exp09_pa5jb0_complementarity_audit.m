function results = exp09_pa5jb0_complementarity_audit(mode)
%EXP09_PA5JB0_FAILURE_CONDITIONAL_INDICATOR_COMPLEMENTARITY
% PA5J-B0 is a diagnostic complementarity audit. It does not call
% Neighbor-3, set an operating threshold, or interpret scientific branches.
if nargin<1, mode="formal"; end
mode=string(mode);
if ~ismember(mode,["formal","preflight"]), error('PA5JB0:InvalidMode','Mode must be formal or preflight.'); end
cfg=config_exp09_pa5jb0_complementarity();
[T,audit]=pa5jb0_prepare_cohort(cfg);
if mode=="preflight", results=struct('cfg',cfg,'audit',audit); return; end

this_dir=fileparts(mfilename('fullpath')); paper_root=fileparts(fileparts(this_dir));
if isempty(cfg.output_dir)
    out_path=fullfile(paper_root,'results','exp09_physical_validation',cfg.output_folder_name);
else
    out_path=cfg.output_dir;
end
if ~exist(out_path,'dir')
    mkdir(out_path);
end
writetable(audit.schema,fullfile(out_path,'schema_audit.csv'));
writetable(audit.unique_trial,fullfile(out_path,'unique_trial_audit.csv'));
writetable(audit.cohort,fullfile(out_path,'complete_case_audit.csv'));
writetable(audit.exclusions,fullfile(out_path,'complete_case_exclusion_reasons.csv'));
writetable(audit.cohort(:,{'source','aperture_mode','failures_raw','failure_denominator_raw','prevalence_raw','failures_included','failure_denominator_included','prevalence_included'}),fullfile(out_path,'failure_prevalence_audit.csv'));
manifest=table(["PA5J-A original";"PA5J-A dense risk"],string(audit.schema.path),audit.schema.n_rows, ...
    'VariableNames',{'source_artifact','path','n_rows'});
writetable(manifest,fullfile(out_path,'source_manifest.csv'));

[single,cutoff,pairwise,threeway,commonmiss]=analyse(T,cfg);
writetable(cutoff,fullfile(out_path,'cutoff_tie_audit.csv'));
writetable(single,fullfile(out_path,'pa5jb0_single_indicator_metrics.csv'));
writetable(pairwise,fullfile(out_path,'pa5jb0_pairwise_complementarity.csv'));
writetable(threeway,fullfile(out_path,'pa5jb0_threeway_complementarity.csv'));
writetable(commonmiss,fullfile(out_path,'pa5jb0_common_miss_trials.csv'));
make_figures(single,pairwise,threeway,cfg,out_path);
write_summary(out_path,audit,single,pairwise,threeway);
results=struct('cfg',cfg,'audit',audit,'single',single,'pairwise',pairwise, ...
    'threeway',threeway,'commonmiss',commonmiss);
save(fullfile(out_path,'exp09_pa5jb0_results.mat'),'results','-v7.3');
end

function [Sall,Call,Pall,Wall,Mall]=analyse(T,cfg)
srows={}; crows={}; prows={}; wrows={}; mrows={};
for is=1:numel(cfg.expected_sources)
 for ia=1:numel(cfg.expected_apertures)
  source=cfg.expected_sources(is); aperture=cfg.expected_apertures(ia);
  G=T(string(T.source)==source & string(T.aperture_mode)==aperture,:);
  if isempty(G), error('PA5JB0:MissingPrimaryGroup','Primary group %s × %s is empty.',source,aperture); end
  y=G.catastrophic_branch_failure==1; n=height(G); F=sum(y);
  selections=cell(numel(cfg.indicators),numel(cfg.budgets));
  for ii=1:numel(cfg.indicators)
   indicator=cfg.indicators(ii); direction=cfg.risk_directions(ii); x=G.(indicator);
   if direction=="high", score=x; else, score=-x; end
   for ib=1:numel(cfg.budgets)
    Q=pa5jb0_select_tie_inclusive(score,cfg.budgets(ib)); selections{ii,ib}=Q; tr=Q.trigger;
    crows(end+1,:)={char(source),char(aperture),char(indicator),char(direction),Q.nominal_budget,Q.nominal_n,Q.actual_n,Q.actual_fraction,Q.cutoff_score,Q.cutoff_tie_count,Q.budget_inflation}; %#ok<AGROW>
    [~,clo,chi]=pa5jb0_wilson_ci(sum(tr&y),F,cfg.wilson_z);
    [~,flo,fhi]=pa5jb0_wilson_ci(sum(tr&~y),n-F,cfg.wilson_z);
    [~,plo,phi]=pa5jb0_wilson_ci(sum(tr&y),sum(tr),cfg.wilson_z);
    srows(end+1,:)={char(source),char(aperture),char(indicator),char(direction),Q.nominal_budget,Q.actual_fraction, ...
       sum(tr&y),F,ratio(sum(tr&y),F),clo,chi,sum(tr&~y),n-F,ratio(sum(tr&~y),n-F),flo,fhi,sum(tr&y),sum(tr),ratio(sum(tr&y),sum(tr)),plo,phi}; %#ok<AGROW>
   end
  end
  for iaa=1:numel(cfg.indicators)
   for ibb=1:numel(cfg.indicators)
    if iaa==ibb, continue; end
    for ib=1:numel(cfg.budgets)
     A=selections{iaa,ib}.trigger; B=selections{ibb,ib}.trigger; U=A|B;
     miss=y&~A; rescue=sum(miss&B); den=sum(miss);
     [~,rlo,rhi]=pa5jb0_wilson_ci(rescue,den,cfg.wilson_z);
     union_capture=sum(U&y); union_n=sum(U); union_actual=union_n/n;
     [~,ulo,uhi]=pa5jb0_wilson_ci(union_capture,F,cfg.wilson_z);
     fjden=sum(y&U); inter=sum(y&A&B); [~,jlo,jhi]=pa5jb0_wilson_ci(inter,fjden,cfg.wilson_z);
     SA=pa5jb0_select_tie_inclusive(score_for(G,cfg.indicators(iaa),cfg.risk_directions(iaa)),union_actual);
     SB=pa5jb0_select_tie_inclusive(score_for(G,cfg.indicators(ibb),cfg.risk_directions(ibb)),union_actual);
     matched=max(ratio(sum(SA.trigger&y),F),ratio(sum(SB.trigger&y),F));
     prows(end+1,:)={char(source),char(aperture),char(cfg.indicators(iaa)),char(cfg.indicators(ibb)),cfg.budgets(ib), ...
       rescue,den,ratio(rescue,den),rlo,rhi,union_capture,F,ratio(union_capture,F),ulo,uhi,union_actual, ...
       inter,fjden,ratio(inter,fjden),jlo,jhi,ratio(union_capture,F)-max(ratio(sum(A&y),F),ratio(sum(B&y),F)), ...
       SA.actual_fraction,SB.actual_fraction,ratio(union_capture,F)-matched}; %#ok<AGROW>
    end
   end
  end
  for ib=1:numel(cfg.budgets)
   A=selections{1,ib}.trigger; B=selections{2,ib}.trigger; C=selections{3,ib}.trigger; U=A|B|C;
   cm=y&~A&~B&~C; [~,mlo,mhi]=pa5jb0_wilson_ci(sum(cm),F,cfg.wilson_z); [~,ulo,uhi]=pa5jb0_wilson_ci(sum(U&y),F,cfg.wilson_z);
   wrows(end+1,:)={char(source),char(aperture),cfg.budgets(ib),sum(U)/n,sum(U&y),F,ratio(sum(U&y),F),ulo,uhi,sum(cm),ratio(sum(cm),F),mlo,mhi}; %#ok<AGROW>
   Q=G(cm,:);
   for ir=1:height(Q)
    mrows(end+1,:)={char(source),char(aperture),cfg.budgets(ib),char(Q.source_trial_id(ir)),char(Q.physical_trial_id(ir)),Q.true_eta_bins(ir),Q.weak_to_strong_ratio(ir),Q.Gamma_PA4(ir),Q.relative_phase_rad(ir)}; %#ok<AGROW>
   end
  end
 end
end
Sall=cell2table(srows,'VariableNames',{'source','aperture_mode','indicator','risk_direction','nominal_budget','actual_trigger_fraction','capture_numerator','capture_denominator','failure_capture','capture_wilson_lo','capture_wilson_hi','false_trigger_numerator','false_trigger_denominator','false_trigger_rate','false_trigger_wilson_lo','false_trigger_wilson_hi','precision_numerator','precision_denominator','precision','precision_wilson_lo','precision_wilson_hi'});
Call=cell2table(crows,'VariableNames',{'source','aperture_mode','indicator','risk_direction','nominal_budget','nominal_trigger_n','actual_trigger_n','actual_trigger_fraction','cutoff_score','cutoff_tie_count','tie_induced_budget_inflation'});
Pall=cell2table(prows,'VariableNames',{'source','aperture_mode','indicator_A','indicator_B','nominal_budget','conditional_rescue_numerator','conditional_rescue_denominator','conditional_rescue','conditional_rescue_wilson_lo','conditional_rescue_wilson_hi','union_capture_numerator','union_capture_denominator','union_capture','union_capture_wilson_lo','union_capture_wilson_hi','union_actual_trigger_fraction','failure_jaccard_numerator','failure_jaccard_denominator','failure_jaccard','failure_jaccard_wilson_lo','failure_jaccard_wilson_hi','diagnostic_union_gain','matched_actual_fraction_A','matched_actual_fraction_B','budget_matched_complementarity_gain'});
Wall=cell2table(wrows,'VariableNames',{'source','aperture_mode','nominal_budget','threeway_actual_trigger_fraction','threeway_capture_numerator','threeway_capture_denominator','threeway_capture','threeway_capture_wilson_lo','threeway_capture_wilson_hi','common_miss_count','common_miss_fraction','common_miss_wilson_lo','common_miss_wilson_hi'});
Mall=cell2table(mrows,'VariableNames',{'source','aperture_mode','nominal_budget','source_trial_id','physical_trial_id','true_eta_bins','weak_to_strong_ratio','Gamma_PA4','relative_phase_rad'});
end
function x=score_for(G,indicator,direction)
x=G.(indicator); if direction=="low", x=-x; end
end
function r=ratio(k,n), if n==0, r=NaN; else, r=k/n; end, end
function make_figures(S,P,W,cfg,out)
fig=figure('Visible',cfg.figure_visible); hold on
for i=1:numel(cfg.indicators)
 M=S(string(S.indicator)==cfg.indicators(i),:); plot(M.actual_trigger_fraction,M.failure_capture,'.-','DisplayName',cfg.indicators(i));
end
xlabel('Actual trigger fraction'); ylabel('Failure capture'); legend('Interpreter','none','Location','best'); grid on; exportgraphics(fig,fullfile(out,'fig01_single_capture_vs_actual_trigger.png'),'Resolution',180); close(fig);
fig=figure('Visible',cfg.figure_visible); plot(P.union_actual_trigger_fraction,P.conditional_rescue,'.'); xlabel('Actual union trigger fraction'); ylabel('Conditional rescue'); grid on; exportgraphics(fig,fullfile(out,'fig02_pairwise_conditional_rescue_vs_actual_trigger.png'),'Resolution',180); close(fig);
fig=figure('Visible',cfg.figure_visible); plot(P.union_actual_trigger_fraction,P.budget_matched_complementarity_gain,'.'); xlabel('Actual union trigger fraction'); ylabel('Budget-matched gain'); grid on; exportgraphics(fig,fullfile(out,'fig03_pairwise_budget_matched_gain.png'),'Resolution',180); close(fig);
fig=figure('Visible',cfg.figure_visible); plot(W.threeway_actual_trigger_fraction,W.common_miss_fraction,'.'); xlabel('Actual three-way union trigger fraction'); ylabel('Three-way common-miss fraction'); grid on; exportgraphics(fig,fullfile(out,'fig04_threeway_common_miss_vs_actual_union_trigger.png'),'Resolution',180); close(fig);
end
function write_summary(out,audit,S,P,W)
fid=fopen(fullfile(out,'summary.txt'),'w'); fprintf(fid,'PA5J-B0 formal metric export; no automatic research-branch interpretation.\n'); fprintf(fid,'Raw trials: %d; complete cases: %d\n',audit.raw_trials,audit.complete_trials); fprintf(fid,'Single rows: %d; pairwise rows: %d; three-way rows: %d\n',height(S),height(P),height(W)); fclose(fid);
end
