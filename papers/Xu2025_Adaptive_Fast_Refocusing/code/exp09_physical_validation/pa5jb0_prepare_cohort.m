function [T,audit] = pa5jb0_prepare_cohort(cfg)
%PA5JB0_PREPARE_COHORT Read PA5J-A outputs and enforce B0 STOP conditions.
this_dir=fileparts(mfilename('fullpath')); paper_root=fileparts(fileparts(this_dir));
input_dir=fullfile(paper_root,'results','exp09_physical_validation',cfg.pa5ja_folder_name);
paths=[string(fullfile(input_dir,cfg.original_trials_name));string(fullfile(input_dir,cfg.dense_trials_name))];
required=[cfg.identity_fields,"trial_id","catastrophic_branch_failure", ...
    "branch_error_to_global_bins",cfg.indicators,"Gamma_PA4"];
parts=cell(2,1); rows=cell(2,4);
for i=1:2
    if ~exist(paths(i),'file'), error('PA5JB0:MissingInput','Missing input: %s',paths(i)); end
    X=readtable(paths(i),'TextType','string');
    missing=required(~ismember(required,string(X.Properties.VariableNames)));
    if ~isempty(missing), error('PA5JB0:SchemaMismatch','%s missing: %s',paths(i),strjoin(missing,', ')); end
    if any(string(X.source)~=cfg.expected_sources(i))
        error('PA5JB0:SourceMismatch','%s must contain only source=%s.',paths(i),cfg.expected_sources(i));
    end
    parts{i}=X; rows(i,:)={char(cfg.expected_sources(i)),char(paths(i)),height(X),true};
end
Traw=vertcat(parts{:}); label=Traw.catastrophic_branch_failure;
if any(~ismember(string(Traw.aperture_mode),cfg.expected_apertures))
    error('PA5JB0:UnknownAperture','Unknown aperture group.');
end
if any(~isfinite(label) | ~(label==0 | label==1))
    error('PA5JB0:InvalidFailureLabel','Inherited catastrophic label must be binary and nonmissing.');
end
source_id=string(Traw.source)+"|"+string(Traw.trial_id);
physical_id=make_physical_id(Traw,cfg.identity_fields);
assert_unique(source_id,'source + trial_id'); assert_unique(physical_id,'source + physical identity');
if numel(unique(source_id))~=numel(unique(physical_id))
    error('PA5JB0:IdentityDisagreement','Source and physical identity cardinalities differ.');
end
valid_group=ismember(string(Traw.source),cfg.expected_sources) & ismember(string(Traw.aperture_mode),cfg.expected_apertures);
finite_features=true(height(Traw),1);
for i=1:numel(cfg.indicators), finite_features=finite_features & isfinite(Traw.(cfg.indicators(i))); end
valid_label=isfinite(label) & (label==0 | label==1); included=valid_group & finite_features & valid_label;
reason=strings(height(Traw),1); reason(~valid_group)="invalid_group";
for i=1:numel(cfg.indicators)
    bad=~isfinite(Traw.(cfg.indicators(i))); reason(bad & reason=="")="nonfinite_"+cfg.indicators(i);
end
reason(~valid_label & reason=="")="invalid_failure_label"; reason(included)="included";
Traw.source_trial_id=source_id; Traw.physical_trial_id=physical_id;
Traw.complete_case_included=included; Traw.exclusion_reason=reason; T=Traw(included,:);
[cohort,exclusions]=complete_case_audit(Traw,cfg);
audit=struct('input_dir',input_dir, ...
    'schema',cell2table(rows,'VariableNames',{'source','path','n_rows','schema_pass'}), ...
    'unique_trial',table(["source_trial_id";"physical_trial_id"],[height(Traw);height(Traw)], ...
      [numel(unique(source_id));numel(unique(physical_id))], ...
      'VariableNames',{'identity','n_rows','n_unique'}), ...
    'cohort',cohort,'exclusions',exclusions,'raw_trials',height(Traw),'complete_trials',height(T));
end

function id=make_physical_id(T,fields)
id=strings(height(T),1);
for i=1:numel(fields)
    x=T.(fields(i)); if isstring(x) || iscellstr(x), token=string(x); else, token=compose('%.17g',x); end
    id=id+"|"+token;
end
end
function assert_unique(id,name)
[~,~,g]=unique(id);
if any(accumarray(g,1)>1)
    error('PA5JB0:DuplicateTrialIdentity','STOP: duplicate %s; automatic deduplication is forbidden.',name);
end
end
function [A,E]=complete_case_audit(T,cfg)
rows={}; erows=cell(0,4);
for s=1:numel(cfg.expected_sources)
 for a=1:numel(cfg.expected_apertures)
    M=T(string(T.source)==cfg.expected_sources(s) & string(T.aperture_mode)==cfg.expected_apertures(a),:);
    I=M.complete_case_included; n0=height(M); n1=sum(I); f0=sum(M.catastrophic_branch_failure); f1=sum(M.catastrophic_branch_failure(I));
    rows(end+1,:)={char(cfg.expected_sources(s)),char(cfg.expected_apertures(a)),n0,n1,n0-n1,f0,n0,f0/max(n0,1),f1,n1,f1/max(n1,1)}; %#ok<AGROW>
    reasons=unique(M.exclusion_reason(~I));
    for ir=1:numel(reasons)
        erows(end+1,:)={char(cfg.expected_sources(s)),char(cfg.expected_apertures(a)),char(reasons(ir)),sum(M.exclusion_reason==reasons(ir))}; %#ok<AGROW>
    end
 end
end
A=cell2table(rows,'VariableNames',{'source','aperture_mode','n_raw','n_included','n_excluded','failures_raw','failure_denominator_raw','prevalence_raw','failures_included','failure_denominator_included','prevalence_included'});
E=cell2table(erows,'VariableNames',{'source','aperture_mode','exclusion_reason','n_excluded'});
end
