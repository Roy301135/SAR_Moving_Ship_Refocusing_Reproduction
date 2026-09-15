function results = exp10b_r1_recover_outputs()
%EXP10B_R1_RECOVER_OUTPUTS
% Recovery helper for the specific end-of-run feedback-bundle serialization
% error in EXP010-B-R1.
%
% Use this AFTER the ownership audit reached 246/246 and then failed at
% write_feedback_bundle because writetable() was given a numeric file ID.
% The expensive audit does NOT need to be rerun: the four CSV summaries and
% figures were already written before the failed bundle step.
%
% This helper:
%   1) reads the already-saved CSV outputs;
%   2) rebuilds EXP010B_R1_FEEDBACK_BUNDLE.txt correctly;
%   3) rebuilds exp10b_r1_ownership_results.mat;
%   4) returns the recovered results struct.

cfg = config_exp10b_r1_neighbor3_ownership_audit();

trial_file   = fullfile(cfg.output_dir,'neighbor3_ownership_trials.csv');
summary_file = fullfile(cfg.output_dir,'neighbor3_ownership_summary.csv');
assoc_file   = fullfile(cfg.output_dir,'beta_error_failure_association.csv');
verdict_file = fullfile(cfg.output_dir,'ownership_verdict.csv');

required = {trial_file,summary_file,assoc_file,verdict_file};
for i = 1:numel(required)
    if ~isfile(required{i})
        error('EXP010B_R1_RECOVER:MissingOutput', ...
            'Expected saved output is missing: %s\nDo not use recovery; rerun the main audit instead.', required{i});
    end
end

A = readtable(trial_file,'TextType','string');
S = readtable(summary_file,'TextType','string');
Assoc = readtable(assoc_file,'TextType','string');
V = readtable(verdict_file,'TextType','string');

write_feedback_bundle_recovered(A,S,Assoc,V,cfg);

save(fullfile(cfg.output_dir,'exp10b_r1_ownership_results.mat'), ...
    'A','S','Assoc','V','cfg');

results = struct();
results.audit_trials = A;
results.summary = S;
results.beta_error_association = Assoc;
results.verdict = V;
results.cfg = cfg;

fprintf('\nEXP010-B-R1 recovery complete.\n');
fprintf('No ownership audit was rerun.\n');
fprintf('Feedback bundle: %s\n', fullfile(cfg.output_dir,cfg.feedback_bundle_name));
fprintf('MAT result: %s\n\n', fullfile(cfg.output_dir,'exp10b_r1_ownership_results.mat'));
end

function write_feedback_bundle_recovered(A,S,B,V,cfg)
path = fullfile(cfg.output_dir,cfg.feedback_bundle_name);
fid = fopen(path,'w');
if fid < 0
    error('Could not open feedback bundle: %s',path);
end
cleanup = onCleanup(@() fclose(fid));

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
classes = unique(string(A.ownership_class),'stable');
for i = 1:numel(classes)
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
% writetable() requires a filename, not an already-open numeric file ID.
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
