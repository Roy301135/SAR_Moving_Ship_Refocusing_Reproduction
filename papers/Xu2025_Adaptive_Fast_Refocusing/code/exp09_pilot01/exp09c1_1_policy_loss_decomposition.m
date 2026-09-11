function results = exp09c1_1_policy_loss_decomposition()
%EXP09C1_1_POLICY_LOSS_DECOMPOSITION
% EXP009 / Pilot-01 / Experiment C1.1
%
% Policy Loss Decomposition
%
% -------------------------------------------------------------------------
% Motivation
% -------------------------------------------------------------------------
% C1 showed:
%
%   Cheap recall                ~ 0.718
%   Oracle union recall         ~ 0.950
%   Practical matched-cost      ~ 0.820
%
% Therefore the remaining gap is large.
%
% C1.1 asks:
%
%   Is the gap mainly caused by:
%
%   A) allocation error:
%      the gate does not trigger on rescuable trials;
%
%   or
%
%   B) branch-selection error:
%      the gate triggers correctly, but the prominence selector chooses
%      the wrong branch?
%
% No new signal-level MC is required. C1.1 reads the already generated
% branch-level trial table from C1.
%
% -------------------------------------------------------------------------
% Definitions
% -------------------------------------------------------------------------
% Beneficial fallback:
%   cheap fails AND fallback succeeds
%
% Harmful fallback:
%   cheap succeeds AND fallback fails
%
% Practical trigger:
%   low cheap-branch prominence
%
% Three selectors are evaluated UNDER THE SAME practical trigger:
%
%   1) Always-fallback:
%      if triggered, always use fallback output.
%
%   2) Prominence-selector:
%      if triggered, use fallback only when fallback prominence is higher.
%      This reproduces the current C1 practical logic.
%
%   3) Oracle-selector:
%      if triggered, use whichever branch is correct.
%      This is not practical; it is the maximum recall achievable with the
%      SAME trigger set and therefore isolates allocation quality.
%
% Gap decomposition:
%
%   R_oracle - R_current
%
% = [R_oracle - R_trigger_ceiling]     allocation loss
% + [R_trigger_ceiling - R_current]    selector loss
%
% where R_trigger_ceiling is practical trigger + oracle branch selector.
%
% Run:
%   results = exp09c1_1_policy_loss_decomposition;

cfg = config_exp09c1_1();

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.c1_result_dir)
    c1_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09c1_adaptive_budget');
else
    c1_dir = cfg.c1_result_dir;
end

if isempty(cfg.output_dir)
    out_dir = fullfile(paper_root,'results','exp09_pilot01', ...
        'exp09c1_1_policy_loss_decomposition');
else
    out_dir = cfg.output_dir;
end

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

branch_file = fullfile(c1_dir,'c1_branch_trials.csv');
curve_file = fullfile(c1_dir,'policy_curve_prominence.csv');

if ~exist(branch_file,'file')
    error('C1 branch trial file not found: %s',branch_file);
end

if ~exist(curve_file,'file')
    error('C1 prominence policy curve not found: %s',curve_file);
end

T = readtable(branch_file);
C = readtable(curve_file);

required_T = { ...
    'cell_id','trial_id', ...
    'cheap_success','fallback_success', ...
    'cheap_prominence','fallback_prominence'};

assert_table_vars(T,required_T,'c1_branch_trials.csv');

required_C = {'threshold','fallback_rate','policy_recall'};
assert_table_vars(C,required_C,'policy_curve_prominence.csv');

fprintf('\n============================================================\n');
fprintf(' EXP009-C1.1 / Policy Loss Decomposition\n');
fprintf('============================================================\n');
fprintf('C1 input: %s\n',c1_dir);
fprintf('Output:   %s\n\n',out_dir);

%% Core labels
cheap = logical(T.cheap_success);
fb = logical(T.fallback_success);

beneficial = ~cheap & fb;
harmful = cheap & ~fb;

oracle_union = cheap | fb;

cheap_recall = mean(cheap);
oracle_recall = mean(oracle_union);

oracle_trigger_rate = mean(beneficial);

%% Choose matched-cost practical threshold
switch cfg.operating_point
    case 'oracle_rate'
        [~,iop] = min(abs(C.fallback_rate-oracle_trigger_rate));
    otherwise
        error('Unknown operating point mode.');
end

thr = C.threshold(iop);

trigger = T.cheap_prominence <= thr;
trigger_rate = mean(trigger);

%% Selector 1: always use fallback when triggered
pol_always = cheap;
pol_always(trigger) = fb(trigger);

recall_always = mean(pol_always);

%% Selector 2: current C1 prominence selector
use_fb_prom = trigger & ...
    (T.fallback_prominence > T.cheap_prominence);

pol_prom = cheap;
pol_prom(use_fb_prom) = fb(use_fb_prom);

recall_prom = mean(pol_prom);

%% Selector 3: oracle selector under SAME practical trigger
% If triggered, success is achieved whenever either branch succeeds.
pol_oracle_selector = cheap;

idx = find(trigger);
pol_oracle_selector(idx) = cheap(idx) | fb(idx);

recall_trigger_ceiling = mean(pol_oracle_selector);

%% Oracle trigger + different selectors
oracle_trigger = beneficial;

% If oracle trigger fires, always fallback is already optimal because by
% definition these are exactly cheap-fail/fallback-success trials.
pol_oracle_trigger_always = cheap;
pol_oracle_trigger_always(oracle_trigger) = fb(oracle_trigger);

recall_oracle_trigger_always = mean(pol_oracle_trigger_always);

% What if we had the perfect trigger but still used prominence selector?
oracle_trigger_prom_use = oracle_trigger & ...
    (T.fallback_prominence > T.cheap_prominence);

pol_oracle_trigger_prom = cheap;
pol_oracle_trigger_prom(oracle_trigger_prom_use) = ...
    fb(oracle_trigger_prom_use);

recall_oracle_trigger_prom = mean(pol_oracle_trigger_prom);

%% Decompose current Practical-vs-Oracle gap
total_gap = oracle_recall-recall_prom;

allocation_loss = oracle_recall-recall_trigger_ceiling;
selector_loss = recall_trigger_ceiling-recall_prom;

if total_gap > 0
    allocation_loss_fraction = allocation_loss/total_gap;
    selector_loss_fraction = selector_loss/total_gap;
else
    allocation_loss_fraction = NaN;
    selector_loss_fraction = NaN;
end

%% Targeting statistics
beneficial_total = sum(beneficial);

beneficial_triggered = sum(beneficial & trigger);

if beneficial_total > 0
    allocation_capture = beneficial_triggered/beneficial_total;
else
    allocation_capture = NaN;
end

trigger_total = sum(trigger);

if trigger_total > 0
    trigger_precision_for_benefit = ...
        beneficial_triggered/trigger_total;
else
    trigger_precision_for_benefit = NaN;
end

wasted_trigger_fraction = 1-trigger_precision_for_benefit;

harmful_triggered = sum(harmful & trigger);

if trigger_total > 0
    harmful_trigger_fraction = harmful_triggered/trigger_total;
else
    harmful_trigger_fraction = NaN;
end

%% Selector-specific diagnostics on correctly targeted beneficial trials
targeted_beneficial = beneficial & trigger;

n_targeted_beneficial = sum(targeted_beneficial);

selector_accepts_fallback_on_targeted_benefit = ...
    sum(use_fb_prom & targeted_beneficial);

if n_targeted_beneficial > 0
    selector_rescue_capture = ...
        selector_accepts_fallback_on_targeted_benefit / ...
        n_targeted_beneficial;
else
    selector_rescue_capture = NaN;
end

selector_missed_rescues = ...
    sum(targeted_beneficial & ~use_fb_prom);

selector_harm_events = ...
    sum(harmful & trigger & use_fb_prom);

%% Does always-fallback beat prominence selector?
always_minus_prom = recall_always-recall_prom;

%% Threshold sweep decomposition
nC = height(C);

threshold = C.threshold;
fallback_rate = nan(nC,1);

allocation_capture_curve = nan(nC,1);
trigger_precision_curve = nan(nC,1);

recall_always_curve = nan(nC,1);
recall_prom_curve = nan(nC,1);
recall_trigger_ceiling_curve = nan(nC,1);

allocation_loss_curve = nan(nC,1);
selector_loss_curve = nan(nC,1);
total_gap_curve = nan(nC,1);

selector_rescue_capture_curve = nan(nC,1);
harmful_trigger_fraction_curve = nan(nC,1);

for i = 1:nC
    tr = T.cheap_prominence <= threshold(i);

    fallback_rate(i) = mean(tr);

    ntr = sum(tr);
    nb = sum(beneficial & tr);

    if beneficial_total>0
        allocation_capture_curve(i) = nb/beneficial_total;
    end

    if ntr>0
        trigger_precision_curve(i) = nb/ntr;
        harmful_trigger_fraction_curve(i) = ...
            sum(harmful & tr)/ntr;
    end

    % Always fallback
    p1 = cheap;
    p1(tr) = fb(tr);
    recall_always_curve(i) = mean(p1);

    % Prominence selector
    usep = tr & ...
        (T.fallback_prominence > T.cheap_prominence);

    p2 = cheap;
    p2(usep) = fb(usep);
    recall_prom_curve(i) = mean(p2);

    % Oracle selector under same trigger
    p3 = cheap;
    ii = find(tr);
    p3(ii) = cheap(ii) | fb(ii);
    recall_trigger_ceiling_curve(i) = mean(p3);

    allocation_loss_curve(i) = ...
        oracle_recall-recall_trigger_ceiling_curve(i);

    selector_loss_curve(i) = ...
        recall_trigger_ceiling_curve(i)-recall_prom_curve(i);

    total_gap_curve(i) = ...
        oracle_recall-recall_prom_curve(i);

    tb = beneficial & tr;

    if any(tb)
        selector_rescue_capture_curve(i) = ...
            mean(usep(tb));
    end
end

decomposition_curve = table( ...
    threshold,fallback_rate, ...
    allocation_capture_curve,trigger_precision_curve, ...
    recall_always_curve,recall_prom_curve, ...
    recall_trigger_ceiling_curve, ...
    allocation_loss_curve,selector_loss_curve,total_gap_curve, ...
    selector_rescue_capture_curve,harmful_trigger_fraction_curve, ...
    'VariableNames',{ ...
    'threshold','fallback_rate', ...
    'beneficial_allocation_capture','benefit_precision_among_triggers', ...
    'recall_always_fallback','recall_prominence_selector', ...
    'recall_oracle_selector_same_trigger', ...
    'allocation_loss','selector_loss','total_oracle_gap', ...
    'selector_rescue_capture_on_targeted_benefit', ...
    'harmful_fraction_among_triggers'});

writetable(decomposition_curve, ...
    fullfile(out_dir,'policy_loss_decomposition_curve.csv'));

%% Matched-cost summary
metric = [ ...
    "Cheap recall"; ...
    "Oracle union recall"; ...
    "Practical trigger + always fallback"; ...
    "Practical trigger + prominence selector"; ...
    "Practical trigger + oracle selector"; ...
    "Oracle trigger + always fallback"; ...
    "Oracle trigger + prominence selector"];

value = [ ...
    cheap_recall; ...
    oracle_recall; ...
    recall_always; ...
    recall_prom; ...
    recall_trigger_ceiling; ...
    recall_oracle_trigger_always; ...
    recall_oracle_trigger_prom];

matched_policy_summary = table(metric,value);

writetable(matched_policy_summary, ...
    fullfile(out_dir,'matched_policy_summary.csv'));

%% Loss summary
name = [ ...
    "Practical trigger rate"; ...
    "Oracle minimal trigger rate"; ...
    "Beneficial allocation capture"; ...
    "Benefit precision among practical triggers"; ...
    "Wasted trigger fraction"; ...
    "Harmful fraction among practical triggers"; ...
    "Selector rescue capture on targeted beneficial trials"; ...
    "Selector missed rescues"; ...
    "Selector harm events"; ...
    "Total Oracle-Practical gap"; ...
    "Allocation loss"; ...
    "Selector loss"; ...
    "Allocation loss fraction"; ...
    "Selector loss fraction"; ...
    "Always-fallback minus prominence-selector recall"];

stat = [ ...
    trigger_rate; ...
    oracle_trigger_rate; ...
    allocation_capture; ...
    trigger_precision_for_benefit; ...
    wasted_trigger_fraction; ...
    harmful_trigger_fraction; ...
    selector_rescue_capture; ...
    selector_missed_rescues; ...
    selector_harm_events; ...
    total_gap; ...
    allocation_loss; ...
    selector_loss; ...
    allocation_loss_fraction; ...
    selector_loss_fraction; ...
    always_minus_prom];

loss_summary = table(name,stat);

writetable(loss_summary, ...
    fullfile(out_dir,'loss_summary.csv'));

%% Console
fprintf('================ C1.1 MATCHED COST ==================\n');
fprintf('Practical threshold                = %.8f\n',thr);
fprintf('Practical trigger rate             = %.3f\n',trigger_rate);
fprintf('Oracle minimal trigger rate        = %.3f\n', ...
    oracle_trigger_rate);

fprintf('\nCheap recall                       = %.3f\n', ...
    cheap_recall);
fprintf('Oracle union recall                = %.3f\n', ...
    oracle_recall);

fprintf('\nPractical trigger + always fallback= %.3f\n', ...
    recall_always);
fprintf('Practical trigger + prominence sel = %.3f\n', ...
    recall_prom);
fprintf('Practical trigger + oracle selector= %.3f\n', ...
    recall_trigger_ceiling);

fprintf('\nOracle trigger + always fallback   = %.3f\n', ...
    recall_oracle_trigger_always);
fprintf('Oracle trigger + prominence sel    = %.3f\n', ...
    recall_oracle_trigger_prom);

fprintf('\n================ C1.1 GAP DECOMPOSITION =============\n');
fprintf('Total Oracle-Practical gap         = %.4f\n',total_gap);
fprintf('Allocation loss                    = %.4f (%.1f%%)\n', ...
    allocation_loss,100*allocation_loss_fraction);
fprintf('Selector loss                      = %.4f (%.1f%%)\n', ...
    selector_loss,100*selector_loss_fraction);

fprintf('\nBeneficial allocation capture      = %.3f\n', ...
    allocation_capture);
fprintf('Benefit precision among triggers   = %.3f\n', ...
    trigger_precision_for_benefit);
fprintf('Wasted trigger fraction            = %.3f\n', ...
    wasted_trigger_fraction);
fprintf('Selector rescue capture            = %.3f\n', ...
    selector_rescue_capture);
fprintf('Always-fallback minus prom selector= %+0.4f\n', ...
    always_minus_prom);
fprintf('=====================================================\n');

%% Text summary
fid = fopen(fullfile(out_dir,'summary.txt'),'w');

fprintf(fid,'EXP009-C1.1 Policy Loss Decomposition\n');
fprintf(fid,'====================================\n\n');

fprintf(fid,'Matched-cost operating point\n');
fprintf(fid,'----------------------------\n');
fprintf(fid,'Prominence threshold: %.8f\n',thr);
fprintf(fid,'Practical trigger rate: %.6f\n',trigger_rate);
fprintf(fid,'Oracle minimal trigger rate: %.6f\n\n', ...
    oracle_trigger_rate);

fprintf(fid,'Recall under different selectors\n');
fprintf(fid,'--------------------------------\n');
fprintf(fid,'Cheap: %.6f\n',cheap_recall);
fprintf(fid,'Oracle union: %.6f\n',oracle_recall);
fprintf(fid,'Practical trigger + always fallback: %.6f\n', ...
    recall_always);
fprintf(fid,'Practical trigger + prominence selector: %.6f\n', ...
    recall_prom);
fprintf(fid,'Practical trigger + oracle selector: %.6f\n', ...
    recall_trigger_ceiling);
fprintf(fid,'Oracle trigger + always fallback: %.6f\n', ...
    recall_oracle_trigger_always);
fprintf(fid,'Oracle trigger + prominence selector: %.6f\n\n', ...
    recall_oracle_trigger_prom);

fprintf(fid,'Gap decomposition\n');
fprintf(fid,'-----------------\n');
fprintf(fid,'Total Oracle-Practical gap: %.6f\n',total_gap);
fprintf(fid,'Allocation loss: %.6f\n',allocation_loss);
fprintf(fid,'Selector loss: %.6f\n',selector_loss);
fprintf(fid,'Allocation loss fraction: %.6f\n', ...
    allocation_loss_fraction);
fprintf(fid,'Selector loss fraction: %.6f\n\n', ...
    selector_loss_fraction);

fprintf(fid,'Targeting diagnostics\n');
fprintf(fid,'---------------------\n');
fprintf(fid,'Beneficial allocation capture: %.6f\n', ...
    allocation_capture);
fprintf(fid,'Benefit precision among practical triggers: %.6f\n', ...
    trigger_precision_for_benefit);
fprintf(fid,'Wasted trigger fraction: %.6f\n', ...
    wasted_trigger_fraction);
fprintf(fid,'Harmful fraction among triggers: %.6f\n', ...
    harmful_trigger_fraction);
fprintf(fid,'Selector rescue capture on targeted beneficial: %.6f\n', ...
    selector_rescue_capture);
fprintf(fid,'Selector missed rescues: %d\n',selector_missed_rescues);
fprintf(fid,'Selector harm events: %d\n',selector_harm_events);
fprintf(fid,'Always-fallback minus prominence-selector recall: %+0.6f\n', ...
    always_minus_prom);

fclose(fid);

%% Figures
make_figures( ...
    out_dir,cfg,decomposition_curve, ...
    cheap_recall,oracle_recall, ...
    recall_always,recall_prom,recall_trigger_ceiling, ...
    trigger_rate,oracle_trigger_rate, ...
    allocation_loss,selector_loss,total_gap, ...
    allocation_capture,trigger_precision_for_benefit, ...
    selector_rescue_capture);

%% Save
results = struct();

results.cfg = cfg;
results.threshold = thr;

results.matched_policy_summary = matched_policy_summary;
results.loss_summary = loss_summary;
results.decomposition_curve = decomposition_curve;

results.cheap_recall = cheap_recall;
results.oracle_recall = oracle_recall;
results.recall_always = recall_always;
results.recall_prom = recall_prom;
results.recall_trigger_ceiling = recall_trigger_ceiling;

results.allocation_loss = allocation_loss;
results.selector_loss = selector_loss;
results.total_gap = total_gap;

save(fullfile(out_dir,'exp09c1_1_results.mat'), ...
    'results','-v7.3');

fprintf('\nSaved EXP009-C1.1 outputs to:\n%s\n\n',out_dir);

end

%% ========================================================================
function assert_table_vars(tbl,names,filename)
vars = tbl.Properties.VariableNames;

for i = 1:numel(names)
    if ~ismember(names{i},vars)
        error('Missing variable "%s" in %s.', ...
            names{i},filename);
    end
end
end

%% ========================================================================
function make_figures( ...
    out_dir,cfg,D, ...
    cheap_recall,oracle_recall, ...
    recall_always,recall_prom,recall_trigger_ceiling, ...
    trigger_rate,oracle_trigger_rate, ...
    allocation_loss,selector_loss,total_gap, ...
    allocation_capture,trigger_precision,selector_capture)

%% Fig 1: Same-trigger selector comparison
fig = figure('Visible',cfg.figure_visible);

vals = [ ...
    cheap_recall, ...
    recall_always, ...
    recall_prom, ...
    recall_trigger_ceiling, ...
    oracle_recall];

bar(vals);
ylim([0 1]);

xticks(1:5);
xticklabels({ ...
    'Cheap', ...
    'Always fallback', ...
    'Prominence selector', ...
    'Oracle selector', ...
    'Oracle union'});
xtickangle(25);

ylabel('Weak recovery rate');
title('C1.1 Same-Trigger Branch-Selection Comparison');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig01_same_trigger_selector_comparison.png'), ...
    'Resolution',180);

close(fig);

%% Fig 2: Gap decomposition
fig = figure('Visible',cfg.figure_visible);

bar([allocation_loss selector_loss],'stacked');
hold on;
yline(total_gap,'--','Total gap');

xticks(1);
xticklabels({'Oracle - current practical'});
ylabel('Recall gap');

title('C1.1 Oracle-Practical Gap Decomposition');

legend('Allocation loss','Selector loss','Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig02_gap_decomposition.png'), ...
    'Resolution',180);

close(fig);

%% Fig 3: Recall vs trigger rate under three selectors
fig = figure('Visible',cfg.figure_visible);

plot(D.fallback_rate,D.recall_always_fallback, ...
    'LineWidth',1.3);
hold on;

plot(D.fallback_rate,D.recall_prominence_selector, ...
    'LineWidth',1.3);

plot(D.fallback_rate,D.recall_oracle_selector_same_trigger, ...
    'LineWidth',1.3);

scatter(trigger_rate,recall_prom,75,'filled');
scatter(oracle_trigger_rate,oracle_recall,85,'filled');

xlabel('Practical trigger rate');
ylabel('Weak recovery rate');

title('C1.1 Selector Effect Across Budget');

legend('Always fallback','Prominence selector', ...
    'Oracle selector same trigger','Matched practical','Oracle union', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig03_selector_recall_vs_budget.png'), ...
    'Resolution',180);

close(fig);

%% Fig 4: Allocation quality vs budget
fig = figure('Visible',cfg.figure_visible);

plot(D.fallback_rate,D.beneficial_allocation_capture, ...
    'LineWidth',1.3);
hold on;

plot(D.fallback_rate,D.benefit_precision_among_triggers, ...
    'LineWidth',1.3);

xlabel('Trigger / fallback budget');
ylabel('Rate');

title('C1.1 Allocation Quality vs Budget');

legend('Capture of all rescuable trials', ...
    'Benefit precision among triggers', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig04_allocation_quality_vs_budget.png'), ...
    'Resolution',180);

close(fig);

%% Fig 5: Selector quality
fig = figure('Visible',cfg.figure_visible);

plot(D.fallback_rate, ...
    D.selector_rescue_capture_on_targeted_benefit, ...
    'LineWidth',1.3);
hold on;

plot(D.fallback_rate, ...
    D.harmful_fraction_among_triggers, ...
    'LineWidth',1.3);

xlabel('Trigger / fallback budget');
ylabel('Rate');

title('C1.1 Branch-Selector Quality');

legend('Rescue capture on targeted beneficial trials', ...
    'Harmful fraction among triggers', ...
    'Location','best');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig05_selector_quality.png'), ...
    'Resolution',180);

close(fig);

%% Fig 6: Matched-cost targeting summary
fig = figure('Visible',cfg.figure_visible);

vals = [ ...
    allocation_capture, ...
    trigger_precision, ...
    selector_capture];

bar(vals);
ylim([0 1]);

xticks(1:3);
xticklabels({ ...
    'Rescuable capture', ...
    'Benefit precision', ...
    'Selector rescue capture'});
xtickangle(20);

ylabel('Rate');
title('C1.1 Matched-Cost Targeting Diagnostics');

grid on;

exportgraphics(fig, ...
    fullfile(out_dir,'fig06_matched_targeting_diagnostics.png'), ...
    'Resolution',180);

close(fig);

end
