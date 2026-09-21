function run_exp02_r0c_cross_ship_interface_gate()
%RUN_EXP02_R0C_CROSS_SHIP_INTERFACE_GATE
%
% EXP02-R0C
% Cross-ship processing-object reproducibility gate.
%
% Research question:
%   Does the weak target-line LFM signature observed in R0B repeat across
%   multiple metadata-preselected ships from the same real SLC scene?
%
% This stage DOES NOT:
%   - tune the LFM scanner;
%   - window/crop lines according to the outcome;
%   - run G0 / Neighbor-3 / Proposed;
%   - classify D/G/E/B branch states.
%
% It reuses exactly the R0B dominant-LFM diagnostic and compares natural
% target lines with equal-count lowest-energy background controls.

clc;

%% Paths
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
research_root = fileparts(code_dir);
func_dir = fullfile(research_root,'functions','opensarship');
addpath(this_dir);
addpath(func_dir);

cfg = config_exp02_r0c();

required_funcs = { ...
    'opensarship_read_slc_chip', ...
    'opensarship_find_ship_record', ...
    'opensarship_lfm_coherence_scan'};
for i=1:numel(required_funcs)
    if exist(required_funcs{i},'file') ~= 2
        error('EXP02_R0C:MissingDependency', ...
            'Required R0A/R0B function not found: %s',required_funcs{i});
    end
end

if ~exist(cfg.ship_xml,'file')
    error('EXP02_R0C:MissingShipXML','Missing Ship.xml: %s',cfg.ship_xml);
end
if ~exist(cfg.output_dir,'dir'), mkdir(cfg.output_dir); end

nShips = size(cfg.ship_xy,1);

% IMPORTANT:
% Do not preallocate with repmat(struct(),...), because assigning a populated
% struct into an empty-field struct array triggers:
% "Subscripted assignment between dissimilar structures."
% We instead create the prototype from the first real result, then repmat it.
ship_results = struct([]);
all_rows = [];

fprintf('============================================================\n');
fprintf('EXP02-R0C Cross-Ship Processing-Object Gate\n');
fprintf('Frozen R0B diagnostic | no branch algorithms\n');
fprintf('============================================================\n');

for s = 1:nShips
    cx = cfg.ship_xy(s,1);
    cy = cfg.ship_xy(s,2);

    pattern = fullfile(cfg.patch_dir,sprintf('*_x%d_y%d.tif',cx,cy));
    hits = dir(pattern);
    if isempty(hits)
        error('EXP02_R0C:ChipMissing', ...
            ['No Patch file found for x=%d y=%d.\n' ...
             'Extract this chip from Scene 1 ZIP into %s first.'], ...
             cx,cy,cfg.patch_dir);
    end
    if numel(hits) ~= 1
        error('EXP02_R0C:ChipNonUnique', ...
            'Expected exactly one chip for x=%d y=%d, found %d.', ...
            cx,cy,numel(hits));
    end

    chip_path = fullfile(hits(1).folder,hits(1).name);
    S = opensarship_read_slc_chip(chip_path);
    ship = opensarship_find_ship_record(cfg.ship_xml,cx,cy);

    X = S.VV;
    N = size(X,1);
    Nr = size(X,2);

    line_energy = sum(abs(double(X)).^2,1);
    selected = line_energy > mean(line_energy);
    target_idx = find(selected);
    nT = numel(target_idx);

    if nT < 3
        error('EXP02_R0C:TooFewTargetLines', ...
            'Only %d natural target lines for %s.',nT,hits(1).name);
    end

    is_target = false(1,Nr);
    is_target(target_idx)=true;
    bg_pool = find(~is_target);
    [~,ord] = sort(line_energy(bg_pool),'ascend');
    if numel(bg_pool) < nT
        error('EXP02_R0C:BackgroundPool','Not enough background lines.');
    end
    background_idx = bg_pool(ord(1:nT));

    idx_all = [target_idx background_idx];
    grp_all = [repmat("TARGET",1,nT) repmat("BACKGROUND",1,nT)];

    C = zeros(1,numel(idx_all));
    G = zeros(1,numel(idx_all));
    B = zeros(1,numel(idx_all));
    NU = zeros(1,numel(idx_all));
    EDGE = false(1,numel(idx_all));

    fprintf('\nShip %d/%d: %s | N=%d | selected=%d/%d\n', ...
        s,nShips,hits(1).name,N,nT,Nr);

    for k=1:numel(idx_all)
        n = idx_all(k);
        R = opensarship_lfm_coherence_scan(X(:,n),cfg.n_beta,cfg.nfft);
        C(k) = R.best_coherence;
        G(k) = R.chirp_gain_db;
        B(k) = R.best_beta;
        NU(k)= R.best_nu_bins;
        EDGE(k)=R.beta_boundary_hit;
    end

    isT = grp_all=="TARGET";
    isBG = grp_all=="BACKGROUND";

    sr = struct();
    sr.ship_id = s;
    sr.filename = string(hits(1).name);
    sr.center_x = cx;
    sr.center_y = cy;
    sr.N_azimuth = N;
    sr.N_range = Nr;
    sr.n_target_lines = nT;
    sr.target_indices = target_idx;
    sr.background_indices = background_idx;

    sr.manual_length_m = getfield_default(ship.SAR,'Manual_Length',NaN); %#ok<GFLD>
    sr.incidence_deg = getfield_default(ship.SAR,'Incidence',NaN); %#ok<GFLD>
    sr.AIS_Sog_raw = getfield_default(ship.AIS,'Sog',NaN); %#ok<GFLD>
    sr.AIS_Rot_raw = getfield_default(ship.AIS,'Rot',NaN); %#ok<GFLD>
    sr.AIS_length_m = getfield_default(ship.AIS,'Length',NaN); %#ok<GFLD>
    sr.length_error_rate = getfield_default(ship.Match,'Length_error_rate',NaN); %#ok<GFLD>

    sr.target_coh_median = median(C(isT));
    sr.background_coh_median = median(C(isBG));
    sr.target_to_background_coh_ratio = ...
        sr.target_coh_median / max(sr.background_coh_median,eps);

    sr.target_gain_median_db = median(G(isT));
    sr.background_gain_median_db = median(G(isBG));
    sr.target_minus_background_gain_db = ...
        sr.target_gain_median_db - sr.background_gain_median_db;

    sr.target_beta_edge_hits = sum(EDGE(isT));
    sr.background_beta_edge_hits = sum(EDGE(isBG));

    % Heuristic random-search context only. It is NOT a threshold.
    sr.extreme_value_floor_heuristic = log(cfg.n_beta * N) / N;

    % Prototype-based struct-array preallocation.
    if s == 1
        ship_results = repmat(sr,1,nShips);
    else
        ship_results(s) = sr;
    end

    % Long-form CSV rows
    ship_id_col = repmat(s,numel(idx_all),1);
    file_col = repmat(string(hits(1).name),numel(idx_all),1);
    range_col = idx_all(:);
    group_col = grp_all(:);
    coh_col = C(:);
    gain_col = G(:);
    beta_col = B(:);
    nu_col = NU(:);
    edge_col = EDGE(:);

    rows = table(ship_id_col,file_col,range_col,group_col, ...
        coh_col,gain_col,beta_col,nu_col,edge_col, ...
        'VariableNames',{'ship_id','filename','range_col','group', ...
        'best_coherence','chirp_gain_db','best_beta','best_nu_bins', ...
        'beta_boundary_hit'});

    if isempty(all_rows)
        all_rows = rows;
    else
        all_rows = [all_rows; rows]; %#ok<AGROW>
    end

    fprintf('  target C median      = %.6f\n',sr.target_coh_median);
    fprintf('  background C median  = %.6f\n',sr.background_coh_median);
    fprintf('  C ratio T/B          = %.4f\n',sr.target_to_background_coh_ratio);
    fprintf('  target gain median   = %+.3f dB\n',sr.target_gain_median_db);
    fprintf('  background gain med. = %+.3f dB\n',sr.background_gain_median_db);
end

writetable(all_rows,fullfile(cfg.output_dir,cfg.csv_name));

%% Figures
fig1=figure('Color','w','Name','R0C cross-ship coherence');
tiledlayout(nShips,1,'Padding','compact','TileSpacing','compact');
for s=1:nShips
    nexttile;
    rows = all_rows(all_rows.ship_id==s,:);
    isT = rows.group=="TARGET";
    isB = rows.group=="BACKGROUND";
    scatter(rows.range_col(isB),rows.best_coherence(isB),28,'x'); hold on;
    scatter(rows.range_col(isT),rows.best_coherence(isT),38,'filled');
    yline(ship_results(s).extreme_value_floor_heuristic,'k:', ...
        'extreme-value heuristic');
    grid on;
    xlabel('range-column n');
    ylabel('dominant LFM coherence');
    title(sprintf('Ship %d | %s | T/B median ratio=%.3f', ...
        s,ship_results(s).filename,ship_results(s).target_to_background_coh_ratio), ...
        'Interpreter','none');
    legend('background control','target lines','Location','best');
end
exportgraphics(fig1,fullfile(cfg.output_dir,cfg.fig1_name),'Resolution',180);

fig2=figure('Color','w','Name','R0C cross-ship chirp gain');
tiledlayout(nShips,1,'Padding','compact','TileSpacing','compact');
for s=1:nShips
    nexttile;
    rows = all_rows(all_rows.ship_id==s,:);
    isT = rows.group=="TARGET";
    isB = rows.group=="BACKGROUND";
    scatter(rows.range_col(isB),rows.chirp_gain_db(isB),28,'x'); hold on;
    scatter(rows.range_col(isT),rows.chirp_gain_db(isT),38,'filled');
    yline(0,'k:');
    grid on;
    xlabel('range-column n');
    ylabel('chirp gain over \beta=0 (dB)');
    title(sprintf('Ship %d | target-background median gain = %+.3f dB', ...
        s,ship_results(s).target_minus_background_gain_db));
    legend('background control','target lines','Location','best');
end
exportgraphics(fig2,fullfile(cfg.output_dir,cfg.fig2_name),'Resolution',180);

save(fullfile(cfg.output_dir,cfg.mat_name), ...
    'cfg','ship_results','all_rows');

%% Feedback
fb = fullfile(cfg.output_dir,cfg.feedback_name);
fid=fopen(fb,'w');
if fid<0, error('Cannot open feedback bundle.'); end
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'EXP02-R0C / CROSS-SHIP PROCESSING-OBJECT REPRODUCIBILITY GATE\n');
fprintf(fid,'============================================================\n');
fprintf(fid,'G0: NOT RUN\n');
fprintf(fid,'Neighbor-3: NOT RUN\n');
fprintf(fid,'Proposed: NOT RUN\n');
fprintf(fid,'Branch taxonomy: NOT RUN\n');
fprintf(fid,'R0B scanner semantics: FROZEN\n\n');

fprintf(fid,'[QUESTION]\n');
fprintf(fid,['Does the weak target-line LFM signature observed in R0B repeat across ' ...
    'three metadata-preselected ships from the same real SLC scene?\n\n']);

fprintf(fid,'[PRESELECTION]\n');
fprintf(fid,['Ships were fixed using metadata/support criteria before R0C outcomes. ' ...
    'No ship was selected by LFM/branch result.\n']);
for s=1:nShips
    R=ship_results(s);
    fprintf(fid,['ship%d=%s | x=%d y=%d | size=%dx%d | manual_length_m=%.15g | ' ...
        'AIS_Sog_raw=%.15g | length_error_rate=%.15g\n'], ...
        s,R.filename,R.center_x,R.center_y,R.N_azimuth,R.N_range, ...
        R.manual_length_m,R.AIS_Sog_raw,R.length_error_rate);
end

fprintf(fid,'\n[PER-SHIP RESULTS]\n');
for s=1:nShips
    R=ship_results(s);
    fprintf(fid,'--- ship %d ---\n',s);
    fprintf(fid,'filename=%s\n',R.filename);
    fprintf(fid,'N_azimuth=%d\n',R.N_azimuth);
    fprintf(fid,'N_range=%d\n',R.N_range);
    fprintf(fid,'n_target_lines=%d\n',R.n_target_lines);
    fprintf(fid,'target_coh_median=%.15g\n',R.target_coh_median);
    fprintf(fid,'background_coh_median=%.15g\n',R.background_coh_median);
    fprintf(fid,'target_to_background_coh_ratio=%.15g\n', ...
        R.target_to_background_coh_ratio);
    fprintf(fid,'target_gain_median_dB=%.15g\n',R.target_gain_median_db);
    fprintf(fid,'background_gain_median_dB=%.15g\n',R.background_gain_median_db);
    fprintf(fid,'target_minus_background_gain_dB=%.15g\n', ...
        R.target_minus_background_gain_db);
    fprintf(fid,'target_beta_edge_hits=%d/%d\n', ...
        R.target_beta_edge_hits,R.n_target_lines);
    fprintf(fid,'background_beta_edge_hits=%d/%d\n', ...
        R.background_beta_edge_hits,R.n_target_lines);
    fprintf(fid,'extreme_value_floor_heuristic=%.15g\n\n', ...
        R.extreme_value_floor_heuristic);
end

fprintf(fid,'[INTERPRETATION RULE]\n');
fprintf(fid,'automatic_dataset_suitability_label=NOT_ASSIGNED\n');
fprintf(fid,['If the R0B pattern repeats across all three ships (target coherence/gain ' ...
    'not stronger than controls), stop treating OpenSARShip as a direct ' ...
    'validation source for the frozen MC-LFM branch mechanism.\n']);
fprintf(fid,['If one or more ships show a reproducibly stronger target-specific LFM ' ...
    'signature, do NOT jump to R1; first perform a source-aligned MC-LFM/FrAc ' ...
    'audit on that preselected ship.\n\n']);

fprintf(fid,'[UPLOAD REQUEST]\n');
fprintf(fid,'Return only: %s, %s, %s.\n', ...
    cfg.feedback_name,cfg.fig1_name,cfg.fig2_name);

fprintf('\nEXP02-R0C completed.\n');
fprintf('Feedback: %s\n',fb);

end

function v=getfield_default(s,name,default)
if isfield(s,name)
    v=s.(name);
else
    v=default;
end
end
