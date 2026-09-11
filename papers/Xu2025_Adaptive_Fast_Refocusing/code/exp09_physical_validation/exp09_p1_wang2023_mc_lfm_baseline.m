function results = exp09_p1_wang2023_mc_lfm_baseline()
%EXP09_P1_WANG2023_MC_LFM_BASELINE
% EXP009 / Physical Validation Track / P1
%
% Wang-2023 five-component MC-LFM physical baseline.
%
% Research gate
% -------------
% Before re-validating A4/B3/B3B.1 under physical parameters, verify that
% Wang's paper-reported five azimuth velocities generate five distinct
% residual-LFM components over a reasonable range of unresolved numerical
% quantities (R0 and azimuth-line sample count).
%
% What is paper-grounded?
%   Wang 2023 Table 1:
%     fc=3 GHz, PRF=188 Hz, B=150 MHz, H=3000 m,
%     antenna length=2 m, V_SAR=150 m/s, pulse width=1.5 us.
%   Wang 2023 Table 2:
%     v_a = [5,10,15,20,25] m/s.
%   Wang Eq. (13):
%     each azimuth line is modeled as an MC-LFM signal.
%
% What is NOT paper-grounded?
%   exact R0/incidence angle, exact azimuth-line length N_a,
%   component amplitudes, b_i, initial phases.
%
% Therefore:
%   - R0/H and N_a are sensitivity axes;
%   - amplitudes are equal in P1;
%   - b_i=0 to isolate chirp-rate separation;
%   - unknown initial phases are Monte-Carlo swept;
%   - no noise and no CLEAN are used.
%
% Physical bridge
% ---------------
% The residual azimuth FM rate follows Xu 2025 Eq. (7),(8),(11):
%
%   K_A   = -2(V-v_a)^2/(lambda R0)
%   K_SAR =  2V^2/(lambda R0)
%   K_res = K_SAR^2/(K_A-K_SAR) + K_SAR
%
% This gives a physical chirp-rate axis in Hz/s. P1 deliberately avoids
% forcing a discrete FrFT-order convention before PA4.
%
% Matched response
% ----------------
% A component is synthesized as:
%
%   s_i(t) = A_i exp{j[pi K_i t^2 + 2pi f_i t + phi_i]}
%
% and evaluated with a chirp-rate matched bank. This is used only as a
% convention-light separability diagnostic; Wang states that FrFT at the
% ORO is equivalent to re-matching the LFM component.
%
% Run:
%   results = exp09_p1_wang2023_mc_lfm_baseline;

cfg = config_exp09_p1_wang2023_mc_lfm_baseline();

%% Resolve output path
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_p1_wang2023_mc_lfm_baseline');
else
    out_path = cfg.output_dir;
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

%% Constants
lambda = cfg.c/cfg.fc_hz;
v = cfg.target_velocity_mps(:).';
A = cfg.component_amplitudes(:).';
f0 = cfg.component_center_frequency_hz(:).';

if numel(v)~=5 || numel(A)~=5 || numel(f0)~=5
    error('P1 expects exactly five Wang-2023 components.');
end

rng(cfg.phase_seed,'twister');

%% Scenario sweep
nR = numel(cfg.slant_range_factor);
nN = numel(cfg.azimuth_samples);

rows = cell(nR*nN,18);
row = 0;

scenario_store = struct();

for iR = 1:nR
    rfac = cfg.slant_range_factor(iR);
    R0 = cfg.platform_height_m*rfac;

    [K_A,K_SAR,K_res] = residual_fm_rates(v,R0,lambda,cfg);

    K_sorted = sort(K_res);
    dK = diff(K_sorted);
    min_sep = min(abs(dK));

    for iN = 1:nN
        N = cfg.azimuth_samples(iN);
        t = centered_slow_time(N,cfg.prf_hz);
        Tspan = max(t)-min(t);

        % A useful scale for quadratic-phase discrimination.
        nominal_k_resolution = 1/max(Tspan^2,eps);
        sep_ratio_nominal = min_sep/nominal_k_resolution;

        Kgrid = build_k_grid(K_res,min_sep,cfg);

        % Single-component responses and 3-dB widths
        single_score = nan(numel(Kgrid),5);
        width_3db = nan(1,5);

        for ic = 1:5
            x = synth_component( ...
                t,A(ic),K_res(ic),f0(ic),0);

            s = chirp_rate_score(x,t,Kgrid);
            single_score(:,ic) = s;

            width_3db(ic) = estimate_3db_width(Kgrid,s,K_res(ic));
        end

        med_width = median(width_3db,'omitnan');
        sep_over_width = min_sep/max(med_width,eps);

        % Phase-averaged combined matched response
        avg_score = zeros(numel(Kgrid),1);
        all5_hits = false(cfg.num_phase_mc,1);
        loc_err = nan(cfg.num_phase_mc,5);

        for imc = 1:cfg.num_phase_mc
            phi = 2*pi*rand(1,5);
            xmix = complex(zeros(size(t)));

            for ic = 1:5
                xmix = xmix + synth_component( ...
                    t,A(ic),K_res(ic),f0(ic),phi(ic));
            end

            s = chirp_rate_score(xmix,t,Kgrid);
            avg_score = avg_score+s;

            [hit,err] = match_true_components_to_local_peaks( ...
                Kgrid,s,K_res, ...
                cfg.peak_match_tolerance_fraction*min_sep);

            all5_hits(imc) = all(hit);
            loc_err(imc,:) = err;
        end

        avg_score = avg_score/cfg.num_phase_mc;
        [avg_hit,avg_err] = match_true_components_to_local_peaks( ...
            Kgrid,avg_score,K_res, ...
            cfg.peak_match_tolerance_fraction*min_sep);

        phase_all5_rate = mean(all5_hits);
        phase_med_loc_error = median(loc_err(:),'omitnan');

        avg_all5 = all(avg_hit);
        avg_max_loc_error = max(avg_err,[],'omitnan');

        gate_pass = ...
            avg_all5 && ...
            sep_over_width >= cfg.min_sep_over_3db_width_gate && ...
            phase_all5_rate >= cfg.phase_mc_all5_rate_gate;

        row = row+1;

        rows(row,:) = { ...
            rfac,R0,N,Tspan, ...
            min_sep,nominal_k_resolution,sep_ratio_nominal, ...
            width_3db(1),width_3db(2),width_3db(3), ...
            width_3db(4),width_3db(5), ...
            med_width,sep_over_width, ...
            double(avg_all5),avg_max_loc_error, ...
            phase_all5_rate,double(gate_pass)};

        key = sprintf('R%d_N%d',iR,iN);
        scenario_store.(key) = struct( ...
            'R0',R0, ...
            'rfac',rfac, ...
            'N',N, ...
            't',t, ...
            'K_A',K_A, ...
            'K_SAR',K_SAR, ...
            'K_res',K_res, ...
            'Kgrid',Kgrid, ...
            'single_score',single_score, ...
            'avg_score',avg_score, ...
            'width_3db',width_3db, ...
            'phase_all5_rate',phase_all5_rate, ...
            'gate_pass',gate_pass);
    end
end

scenario_table = cell2table(rows, ...
    'VariableNames',{ ...
    'slant_range_factor','R0_m','azimuth_samples','time_span_s', ...
    'min_true_K_separation_Hz_per_s', ...
    'nominal_K_resolution_Hz_per_s', ...
    'min_sep_over_nominal_resolution', ...
    'width3db_P1','width3db_P2','width3db_P3', ...
    'width3db_P4','width3db_P5', ...
    'median_3db_width_Hz_per_s', ...
    'min_sep_over_median_3db_width', ...
    'phase_averaged_all5_detected', ...
    'phase_averaged_max_localization_error', ...
    'phase_mc_all5_detection_rate', ...
    'gate_pass'});

writetable(scenario_table, ...
    fullfile(out_path,'scenario_summary.csv'));

%% Representative scenario
[~,iRrep] = min(abs( ...
    cfg.slant_range_factor-cfg.representative_slant_range_factor));
[~,iNrep] = min(abs( ...
    cfg.azimuth_samples-cfg.representative_azimuth_samples));

keyrep = sprintf('R%d_N%d',iRrep,iNrep);
rep = scenario_store.(keyrep);

component_table = table( ...
    (1:5).', ...
    v(:), ...
    rep.K_A(:), ...
    repmat(rep.K_SAR,5,1), ...
    rep.K_res(:), ...
    'VariableNames',{ ...
    'component','azimuth_velocity_mps', ...
    'K_A_Hz_per_s','K_SAR_Hz_per_s', ...
    'K_residual_Hz_per_s'});

writetable(component_table, ...
    fullfile(out_path,'representative_component_parameters.csv'));

%% Global gate
all_scenarios_pass = all(logical(scenario_table.gate_pass));
pass_fraction = mean(scenario_table.gate_pass);

% More conservative status:
% PASS = every tested nuisance setting passes.
% PASS_WITH_SENSITIVITY = representative scenario passes but some nuisance
% settings do not.
rep_row = scenario_table( ...
    abs(scenario_table.slant_range_factor- ...
        cfg.slant_range_factor(iRrep))<1e-12 & ...
    scenario_table.azimuth_samples== ...
        cfg.azimuth_samples(iNrep),:);

if all_scenarios_pass
    gate_status = "PASS";
elseif logical(rep_row.gate_pass)
    gate_status = "PASS_WITH_SENSITIVITY";
else
    gate_status = "FAIL";
end

gate_summary = table( ...
    gate_status, ...
    pass_fraction, ...
    rep.R0, ...
    rep.N, ...
    rep.phase_all5_rate, ...
    min(abs(diff(sort(rep.K_res)))), ...
    median(rep.width_3db,'omitnan'), ...
    'VariableNames',{ ...
    'gate_status','scenario_pass_fraction', ...
    'representative_R0_m','representative_azimuth_samples', ...
    'representative_phase_mc_all5_detection_rate', ...
    'representative_min_K_separation', ...
    'representative_median_3db_width'});

writetable(gate_summary, ...
    fullfile(out_path,'p1_gate_summary.csv'));

%% Text summary
write_summary( ...
    out_path,cfg,lambda,scenario_table,component_table, ...
    gate_summary,rep);

%% Figures
make_figures( ...
    out_path,cfg,v,scenario_table,scenario_store, ...
    rep,iRrep,iNrep);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.scenario_table = scenario_table;
results.component_table = component_table;
results.gate_summary = gate_summary;
results.representative = rep;

save(fullfile(out_path,'exp09_p1_results.mat'), ...
    'results','-v7.3');

%% Console
fprintf('\n============================================================\n');
fprintf(' EXP009 P1 / Wang 2023 MC-LFM Physical Baseline\n');
fprintf('============================================================\n');
fprintf('Gate                    : %s\n',gate_status);
fprintf('Scenario pass fraction  : %.3f\n',pass_fraction);
fprintf('Representative R0       : %.3f m\n',rep.R0);
fprintf('Representative N        : %d\n',rep.N);
fprintf('Representative all-5 MC : %.3f\n',rep.phase_all5_rate);
fprintf('K_res [Hz/s]             : %s\n', ...
    mat2str(rep.K_res,6));
fprintf('============================================================\n\n');

disp(component_table);
disp(gate_summary);

fprintf('Saved P1 outputs to:\n%s\n\n',out_path);

end

%% ========================================================================
function [K_A,K_SAR,K_res] = residual_fm_rates(v,R0,lambda,cfg)
% Xu 2025 Eq. (7),(8),(11), with range acceleration neglected.

V = cfg.platform_velocity_mps;

K_A = -2*(V-v).^2/(lambda*R0);
K_SAR = 2*V^2/(lambda*R0);
K_res = K_SAR.^2./(K_A-K_SAR) + K_SAR;

end

%% ========================================================================
function t = centered_slow_time(N,PRF)

n = 0:N-1;
t = (n-(N-1)/2)/PRF;
t = t(:).';

end

%% ========================================================================
function Kgrid = build_k_grid(Ktrue,min_sep,cfg)

lo = min(Ktrue)-cfg.k_grid_margin_separations*min_sep;
hi = max(Ktrue)+cfg.k_grid_margin_separations*min_sep;

step = min_sep/cfg.k_grid_oversample;
Kgrid = (lo:step:hi).';

end

%% ========================================================================
function x = synth_component(t,A,K,f0,phi)

x = A.*exp(1j*(pi*K*t.^2 + 2*pi*f0*t + phi));
x = x(:).';

end

%% ========================================================================
function score = chirp_rate_score(x,t,Kgrid)
% Convention-light matched chirp-rate response.
%
% The center-frequency term is zero in P1; the bank tests only K.

x = x(:).';
t = t(:).';
Kgrid = Kgrid(:);

D = exp(-1j*pi*(Kgrid*(t.^2)));
y = D*x.';
score = abs(y).^2;
score = score/max(max(score),eps);

end

%% ========================================================================
function w = estimate_3db_width(Kgrid,score,Ktrue)

Kgrid = Kgrid(:);
score = score(:);

[~,i0] = min(abs(Kgrid-Ktrue));

% Find local maximum close to the true K.
halfwin = max(2,round(0.1*numel(Kgrid)));
i1 = max(1,i0-halfwin);
i2 = min(numel(Kgrid),i0+halfwin);

[~,iloc] = max(score(i1:i2));
ip = i1+iloc-1;

level = score(ip)/2;

il = ip;
while il>1 && score(il)>=level
    il = il-1;
end

ir = ip;
while ir<numel(score) && score(ir)>=level
    ir = ir+1;
end

if il==1 || ir==numel(score)
    w = NaN;
else
    w = Kgrid(ir)-Kgrid(il);
end

end

%% ========================================================================
function [hit,err] = match_true_components_to_local_peaks( ...
    Kgrid,score,Ktrue,tol)

Kgrid = Kgrid(:);
score = score(:);
Ktrue = Ktrue(:);

pk_idx = local_maxima_indices(score);

% If there are too few local maxima, include the global maximum so the
% diagnostic still returns a defined result.
if isempty(pk_idx)
    [~,pk_idx] = max(score);
end

% Sort peaks by score descending; greedy unique matching to true K.
[~,ord] = sort(score(pk_idx),'descend');
pk_idx = pk_idx(ord);
pk_K = Kgrid(pk_idx);

hit = false(numel(Ktrue),1);
err = nan(numel(Ktrue),1);
used = false(numel(pk_K),1);

% Match true components in ascending K order to avoid label crossing.
[Ks,sort_idx] = sort(Ktrue);

for ii = 1:numel(Ks)
    d = abs(pk_K-Ks(ii));
    d(used) = inf;

    [dm,j] = min(d);

    orig = sort_idx(ii);

    if isfinite(dm) && dm<=tol
        hit(orig) = true;
        err(orig) = dm;
        used(j) = true;
    end
end

end

%% ========================================================================
function idx = local_maxima_indices(y)

y = y(:);

if numel(y)<3
    [~,idx] = max(y);
    return;
end

idx = find( ...
    y(2:end-1)>y(1:end-2) & ...
    y(2:end-1)>=y(3:end)) + 1;

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,lambda,scenario_table,component_table, ...
    gate_summary,rep)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 P1 / Wang 2023 MC-LFM Physical Baseline\n');
fprintf(fid,'==============================================\n\n');

fprintf(fid,'Paper-grounded inputs (Wang 2023 Table 1/2)\n');
fprintf(fid,'--------------------------------------------\n');
fprintf(fid,'fc = %.9g Hz\n',cfg.fc_hz);
fprintf(fid,'PRF = %.9g Hz\n',cfg.prf_hz);
fprintf(fid,'B = %.9g Hz\n',cfg.bandwidth_hz);
fprintf(fid,'platform height = %.9g m\n',cfg.platform_height_m);
fprintf(fid,'antenna length = %.9g m\n',cfg.antenna_length_m);
fprintf(fid,'V_SAR = %.9g m/s\n',cfg.platform_velocity_mps);
fprintf(fid,'pulse width = %.9g s\n',cfg.pulse_width_s);
fprintf(fid,'target azimuth velocities = %s m/s\n\n', ...
    mat2str(cfg.target_velocity_mps));

fprintf(fid,'Derived\n');
fprintf(fid,'-------\n');
fprintf(fid,'lambda = %.9g m\n',lambda);
fprintf(fid,['Residual FM rates use Xu 2025 Eq. (7),(8),(11), ' ...
    'with range acceleration neglected.\n\n']);

fprintf(fid,'Not reported by Wang for the one-line experiment\n');
fprintf(fid,'------------------------------------------------\n');
fprintf(fid,'Exact closest slant range R0 / incidence angle: NOT REPORTED.\n');
fprintf(fid,'Exact azimuth-line sample count N_a: NOT REPORTED.\n');
fprintf(fid,'Exact component amplitudes: NOT REPORTED.\n');
fprintf(fid,'Exact b_i center frequencies: NOT REPORTED.\n');
fprintf(fid,'Exact initial phases: NOT REPORTED.\n\n');

fprintf(fid,'Controlled sensitivity settings\n');
fprintf(fid,'-------------------------------\n');
fprintf(fid,'R0/H factors = %s\n',mat2str(cfg.slant_range_factor));
fprintf(fid,'Azimuth sample counts = %s\n',mat2str(cfg.azimuth_samples));
fprintf(fid,'Component amplitudes = equal, unit amplitude.\n');
fprintf(fid,'Component center frequencies b_i = 0 for chirp-rate isolation.\n');
fprintf(fid,'Initial phase MC = %d trials.\n',cfg.num_phase_mc);
fprintf(fid,'No noise. No CLEAN.\n\n');

fprintf(fid,'Representative scenario\n');
fprintf(fid,'-----------------------\n');
fprintf(fid,'R0/H = %.6f\n',rep.rfac);
fprintf(fid,'R0 = %.6f m\n',rep.R0);
fprintf(fid,'N = %d\n',rep.N);
fprintf(fid,'K_SAR = %.9g Hz/s\n',rep.K_SAR);
fprintf(fid,'K_A = %s Hz/s\n',mat2str(rep.K_A,8));
fprintf(fid,'K_res = %s Hz/s\n',mat2str(rep.K_res,8));
fprintf(fid,'3-dB widths = %s Hz/s\n',mat2str(rep.width_3db,8));
fprintf(fid,'phase-MC all-five detection rate = %.6f\n\n', ...
    rep.phase_all5_rate);

fprintf(fid,'Gate\n');
fprintf(fid,'----\n');
fprintf(fid,'status = %s\n',gate_summary.gate_status(1));
fprintf(fid,'scenario pass fraction = %.6f\n\n', ...
    gate_summary.scenario_pass_fraction(1));

fprintf(fid,'Interpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) P1 establishes physically anchored residual-chirp separation, ' ...
    'not exact reproduction of Wang Fig. 8.\n']);
fprintf(fid,['2) R0 and N_a are nuisance/sensitivity axes because Wang does not ' ...
    'report them for the five-point one-line experiment.\n']);
fprintf(fid,['3) Do not label sqrt(2)*H or N=512 as Wang-paper parameters.\n']);
fprintf(fid,['4) The matched-chirp bank is a convention-light proxy for the ' ...
    'FrFT energy-concentration principle; PA4 will handle the physical ' ...
    'perturbation mechanism, not P1.\n']);
fprintf(fid,['5) If P1 passes, proceed to PA4 Physical Perturbation / Mirror ' ...
    'Validation. Do not add noise or CLEAN here.\n\n']);

fprintf(fid,'Scenario table\n');
fprintf(fid,'--------------\n');

for i = 1:height(scenario_table)
    fprintf(fid,[ ...
        'R0/H=%.4f N=%d minSep=%g width=%g sep/width=%g ' ...
        'avgAll5=%d phaseAll5=%.4f gate=%d\n'], ...
        scenario_table.slant_range_factor(i), ...
        scenario_table.azimuth_samples(i), ...
        scenario_table.min_true_K_separation_Hz_per_s(i), ...
        scenario_table.median_3db_width_Hz_per_s(i), ...
        scenario_table.min_sep_over_median_3db_width(i), ...
        scenario_table.phase_averaged_all5_detected(i), ...
        scenario_table.phase_mc_all5_detection_rate(i), ...
        scenario_table.gate_pass(i));
end

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,v,scenario_table,scenario_store,rep,iRrep,iNrep)

%% Fig 1: residual FM vs velocity across R0/H sensitivity
fig = figure('Visible',cfg.figure_visible);
hold on;

for iR = 1:numel(cfg.slant_range_factor)
    key = sprintf('R%d_N%d',iR,iNrep);
    s = scenario_store.(key);

    plot(v,s.K_res,'o-','LineWidth',1.2);
end

xlabel('Azimuth velocity v_a (m/s)');
ylabel('Residual FM rate K_{res} (Hz/s)');
title('EXP009 P1 — Wang-2023 Velocity to Residual-FM Mapping');
legend(arrayfun(@(x)sprintf('R_0/H=%.3g',x), ...
    cfg.slant_range_factor,'UniformOutput',false), ...
    'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_velocity_to_residual_FM.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2: representative phase-averaged matched response
fig = figure('Visible',cfg.figure_visible);
plot(rep.Kgrid,rep.avg_score,'LineWidth',1.3);
hold on;

for ic = 1:5
    xline(rep.K_res(ic),':');
end

xlabel('Matched chirp rate K (Hz/s)');
ylabel('Normalized matched-response energy');
title(sprintf( ...
    'EXP009 P1 — Representative 5-Component Response (R_0/H=%.3g, N=%d)', ...
    rep.rfac,rep.N));
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_representative_five_component_response.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3: isolated single-component responses
fig = figure('Visible',cfg.figure_visible);
hold on;

for ic = 1:5
    plot(rep.Kgrid,rep.single_score(:,ic),'LineWidth',1.1);
end

xlabel('Matched chirp rate K (Hz/s)');
ylabel('Normalized single-component response');
title('EXP009 P1 — Isolated Wang-2023 Components');
legend({'P1','P2','P3','P4','P5'},'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_single_component_responses.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4: separability ratio map
Z = nan(numel(cfg.slant_range_factor),numel(cfg.azimuth_samples));

for iR = 1:numel(cfg.slant_range_factor)
    for iN = 1:numel(cfg.azimuth_samples)
        mm = ...
            abs(scenario_table.slant_range_factor- ...
                cfg.slant_range_factor(iR))<1e-12 & ...
            scenario_table.azimuth_samples==cfg.azimuth_samples(iN);

        Z(iR,iN) = ...
            scenario_table.min_sep_over_median_3db_width(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
imagesc(cfg.azimuth_samples,cfg.slant_range_factor,Z);
set(gca,'YDir','normal');
colorbar;
xlabel('Azimuth samples N');
ylabel('R_0 / H');
title('EXP009 P1 — Min Separation / Median 3-dB Width');

exportgraphics(fig, ...
    fullfile(out_path,'fig04_separability_ratio_map.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5: phase-MC all-five detection rate
Z = nan(numel(cfg.slant_range_factor),numel(cfg.azimuth_samples));

for iR = 1:numel(cfg.slant_range_factor)
    for iN = 1:numel(cfg.azimuth_samples)
        mm = ...
            abs(scenario_table.slant_range_factor- ...
                cfg.slant_range_factor(iR))<1e-12 & ...
            scenario_table.azimuth_samples==cfg.azimuth_samples(iN);

        Z(iR,iN) = ...
            scenario_table.phase_mc_all5_detection_rate(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
imagesc(cfg.azimuth_samples,cfg.slant_range_factor,Z,[0 1]);
set(gca,'YDir','normal');
colorbar;
xlabel('Azimuth samples N');
ylabel('R_0 / H');
title('EXP009 P1 — Five-Component Detection Rate Across Unknown Phases');

exportgraphics(fig, ...
    fullfile(out_path,'fig05_phase_mc_detection_rate.png'), ...
    'Resolution',180);
close(fig);

end
