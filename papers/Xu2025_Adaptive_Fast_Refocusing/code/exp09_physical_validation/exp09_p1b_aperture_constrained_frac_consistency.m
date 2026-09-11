function results = exp09_p1b_aperture_constrained_frac_consistency()
%EXP09_P1B_APERTURE_CONSTRAINED_FRAC_CONSISTENCY
% EXP009 / Physical Validation Track / P1B
%
% Aperture-Constrained FrAc Consistency Audit
%
% Motivation
% ----------
% P1 confirmed the physical velocity -> residual-FM mapping, but showed
% strong dependence of five-component resolvability on observation length.
%
% Wang 2023 states:
%   - each selected ship azimuth line can be modeled as MC-LFM;
%   - FrAc distinguishes LFM components with different modulation rates;
%   - the FrAc energy E_rho(beta) peaks when beta matches a component;
%   - the corresponding FrFT ORO is alpha = beta + pi/2;
%   - the ship swing phase is approximated over an aperture time scale
%     of about one second.
%
% P1B therefore replaces the P1 arbitrary N sweep with two physically
% interpretable aperture prescriptions:
%
%   A) Literature time-scale anchor:
%        T_ap = 1 s, N = round(PRF*T_ap)
%
%   B) First-order beam-derived estimate:
%        beta_az ~= lambda/L_a
%        T_ap ~= R0*beta_az/V
%        N = round(PRF*T_ap)
%
% Exact R0 is still not reported for Wang's five-point experiment, so the
% same controlled R0/H sensitivity set from P1 is retained.
%
% FrAc implementation
% -------------------
% Wang Eq. (13):
%
%   x_i[m] = exp{j2pi(0.5*a_i*m^2 + b_i*m)}
%
% with physical mapping:
%
%   a_i = K_res_i / PRF^2.
%
% From Wang Eq. (20), the FrAc auto-term peak condition is:
%
%   sin(beta) - a_i cos(beta) = 0
%   => tan(beta) = a_i.
%
% For these data beta is ~1e-3 rad, hence cos(beta) is extremely close to
% one. P1B evaluates the following discrete Eq.(17)-consistent statistic:
%
%   R_beta[k] ~= sum_m x[m+k] conj(x[m])
%                    exp{-j2pi*m*k*tan(beta)}
%
%   E(beta) = sum_k |R_beta[k]|^2.
%
% The implementation is accelerated using lag-wise FFT ambiguity spectra.
% This is much closer to Wang's FrAc mechanism than the P1 matched-K proxy,
% while avoiding an unjustified choice of a third-party discrete FrFT
% normalization convention.
%
% No noise. No CLEAN. Equal component amplitude. Unknown phases are swept.
%
% Run:
%   results = exp09_p1b_aperture_constrained_frac_consistency;

cfg = config_exp09_p1b_aperture_constrained_frac_consistency();

%% Output path
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_p1b_aperture_constrained_frac_consistency');
else
    out_path = cfg.output_dir;
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

%% Physical constants
lambda = cfg.c/cfg.fc_hz;
beamwidth_rad = cfg.beamwidth_scale*lambda/cfg.antenna_length_m;

v = cfg.target_velocity_mps(:).';
A = cfg.component_amplitudes(:).';
b = cfg.component_center_frequency_cycles_per_sample(:).';

rng(cfg.phase_seed,'twister');

%% Build scenarios
% Two aperture prescriptions for each unresolved R0/H geometry.
scenario_rows = {};
scenario_store = struct();
sid = 0;

for iR = 1:numel(cfg.slant_range_factor)

    rfac = cfg.slant_range_factor(iR);
    R0 = cfg.platform_height_m*rfac;

    [K_A,K_SAR,K_res] = residual_fm_rates( ...
        v,R0,lambda,cfg);

    a_true = K_res/(cfg.prf_hz^2);
    beta_true = atan(a_true);
    alpha_true = beta_true + pi/2;

    beta_sorted = sort(beta_true);
    min_beta_sep = min(abs(diff(beta_sorted)));

    aperture_modes = ["Paper1s","BeamDerived"];

    for imode = 1:2

        mode = aperture_modes(imode);

        if mode=="Paper1s"
            T_target = cfg.paper_aperture_time_s;
        else
            T_target = R0*beamwidth_rad/cfg.platform_velocity_mps;
        end

        N = max(32,round(cfg.prf_hz*T_target));
        T_actual = (N-1)/cfg.prf_hz;

        max_lag = max(2,min(N-2, ...
            round(cfg.max_lag_fraction*N)));

        beta_grid = build_beta_grid( ...
            beta_true,min_beta_sep,cfg);

        % Single-component FrAc widths
        single_E = nan(numel(beta_grid),5);
        width_3db = nan(1,5);

        for ic = 1:5
            x = synth_discrete_lfm( ...
                N,A(ic),a_true(ic),b(ic),0);

            E = frac_energy_fft( ...
                x,beta_grid,max_lag,cfg);

            single_E(:,ic) = E;
            width_3db(ic) = estimate_3db_width( ...
                beta_grid,E,beta_true(ic));
        end

        median_width = median(width_3db,'omitnan');
        sep_over_width = min_beta_sep/max(median_width,eps);

        % Unknown-phase Monte Carlo
        phase_E_acc = zeros(numel(beta_grid),1);
        all5_hit = false(cfg.num_phase_mc,1);
        phase_loc_rmse = nan(cfg.num_phase_mc,1);

        for imc = 1:cfg.num_phase_mc
            phi = 2*pi*rand(1,5);
            xmix = complex(zeros(1,N));

            for ic = 1:5
                xmix = xmix + synth_discrete_lfm( ...
                    N,A(ic),a_true(ic),b(ic),phi(ic));
            end

            E = frac_energy_fft( ...
                xmix,beta_grid,max_lag,cfg);

            phase_E_acc = phase_E_acc+E;

            [hit,err] = match_true_beta_to_peaks( ...
                beta_grid,E,beta_true, ...
                cfg.peak_match_tolerance_fraction*min_beta_sep, ...
                cfg.min_peak_prominence_fraction);

            all5_hit(imc) = all(hit);

            ev = err(isfinite(err));
            if ~isempty(ev)
                phase_loc_rmse(imc) = sqrt(mean(ev.^2));
            end
        end

        phase_E_avg = phase_E_acc/cfg.num_phase_mc;

        [avg_hit,avg_err] = match_true_beta_to_peaks( ...
            beta_grid,phase_E_avg,beta_true, ...
            cfg.peak_match_tolerance_fraction*min_beta_sep, ...
            cfg.min_peak_prominence_fraction);

        phase_all5_rate = mean(all5_hit);
        avg_all5 = all(avg_hit);

        valid_avg_err = avg_err(isfinite(avg_err));
        if isempty(valid_avg_err)
            avg_max_loc_error = NaN;
        else
            avg_max_loc_error = max(valid_avg_err);
        end

        gate_pass = ...
            avg_all5 && ...
            phase_all5_rate>=cfg.phase_mc_all5_rate_gate;

        sid = sid+1;
        key = sprintf('S%02d',sid);

        scenario_rows(end+1,:) = { ... %#ok<AGROW>
            sid,char(mode),rfac,R0, ...
            T_target,N,T_actual,max_lag, ...
            min_beta_sep,median_width,sep_over_width, ...
            double(avg_all5),phase_all5_rate, ...
            median(phase_loc_rmse,'omitnan'), ...
            avg_max_loc_error,double(gate_pass)};

        scenario_store.(key) = struct( ...
            'mode',mode, ...
            'rfac',rfac, ...
            'R0',R0, ...
            'T_target',T_target, ...
            'N',N, ...
            'T_actual',T_actual, ...
            'max_lag',max_lag, ...
            'K_A',K_A, ...
            'K_SAR',K_SAR, ...
            'K_res',K_res, ...
            'a_true',a_true, ...
            'beta_true',beta_true, ...
            'alpha_true',alpha_true, ...
            'beta_grid',beta_grid, ...
            'single_E',single_E, ...
            'width_3db',width_3db, ...
            'phase_E_avg',phase_E_avg, ...
            'phase_all5_rate',phase_all5_rate, ...
            'avg_all5',avg_all5, ...
            'gate_pass',gate_pass);
    end
end

scenario_table = cell2table(scenario_rows, ...
    'VariableNames',{ ...
    'scenario_id','aperture_mode', ...
    'slant_range_factor','R0_m', ...
    'target_aperture_time_s','azimuth_samples', ...
    'actual_observation_time_s','max_frac_lag', ...
    'min_true_beta_separation_rad', ...
    'median_single_3db_width_rad', ...
    'min_sep_over_median_3db_width', ...
    'phase_averaged_all5_detected', ...
    'phase_mc_all5_detection_rate', ...
    'phase_mc_median_localization_rmse_rad', ...
    'phase_averaged_max_localization_error_rad', ...
    'gate_pass'});

writetable(scenario_table, ...
    fullfile(out_path,'scenario_summary.csv'));

%% Representative geometry rows
[~,iRrep] = min(abs( ...
    cfg.slant_range_factor- ...
    cfg.representative_slant_range_factor));

rfac_rep = cfg.slant_range_factor(iRrep);

mm_rep = abs( ...
    scenario_table.slant_range_factor-rfac_rep)<1e-12;

rep_rows = scenario_table(mm_rep,:);

% Locate representative stored scenarios.
keys = fieldnames(scenario_store);
rep_paper = [];
rep_beam = [];

for ik = 1:numel(keys)
    s = scenario_store.(keys{ik});

    if abs(s.rfac-rfac_rep)<1e-12
        if s.mode=="Paper1s"
            rep_paper = s;
        elseif s.mode=="BeamDerived"
            rep_beam = s;
        end
    end
end

if isempty(rep_paper) || isempty(rep_beam)
    error('Representative P1B scenarios were not found.');
end

%% Component table for representative geometry
component_table = table( ...
    (1:5).', ...
    v(:), ...
    rep_paper.K_A(:), ...
    repmat(rep_paper.K_SAR,5,1), ...
    rep_paper.K_res(:), ...
    rep_paper.a_true(:), ...
    rep_paper.beta_true(:), ...
    rep_paper.alpha_true(:), ...
    'VariableNames',{ ...
    'component','azimuth_velocity_mps', ...
    'K_A_Hz_per_s','K_SAR_Hz_per_s', ...
    'K_residual_Hz_per_s', ...
    'discrete_chirp_rate_a_cycles_per_sample2', ...
    'predicted_FrAc_beta_rad', ...
    'predicted_FrFT_alpha_rad'});

writetable(component_table, ...
    fullfile(out_path,'representative_component_parameters.csv'));

%% Small-angle approximation audit
max_abs_beta = max(abs(component_table.predicted_FrAc_beta_rad));
max_one_minus_cos = max(abs( ...
    1-cos(component_table.predicted_FrAc_beta_rad)));

small_angle_audit = table( ...
    max_abs_beta,max_one_minus_cos, ...
    'VariableNames',{ ...
    'max_abs_beta_rad','max_abs_1_minus_cos_beta'});

writetable(small_angle_audit, ...
    fullfile(out_path,'small_angle_audit.csv'));

%% Gate interpretation
paper_rows = scenario_table( ...
    strcmp(scenario_table.aperture_mode,'Paper1s'),:);

beam_rows = scenario_table( ...
    strcmp(scenario_table.aperture_mode,'BeamDerived'),:);

paper_pass_fraction = mean(paper_rows.gate_pass);
beam_pass_fraction = mean(beam_rows.gate_pass);

rep_paper_pass = logical(rep_rows.gate_pass( ...
    strcmp(rep_rows.aperture_mode,'Paper1s')));

rep_beam_pass = logical(rep_rows.gate_pass( ...
    strcmp(rep_rows.aperture_mode,'BeamDerived')));

if rep_paper_pass && paper_pass_fraction>=2/3
    gate_status = "CONSISTENT_AT_1S_SCALE";
elseif rep_beam_pass && beam_pass_fraction>=2/3
    gate_status = "CONSISTENT_AT_BEAM_DERIVED_SCALE";
elseif any(logical(scenario_table.gate_pass))
    gate_status = "PARTIALLY_CONSISTENT";
else
    gate_status = "UNRESOLVED_WITH_REPORTED_PARAMETERS";
end

gate_summary = table( ...
    gate_status, ...
    paper_pass_fraction,beam_pass_fraction, ...
    double(rep_paper_pass),double(rep_beam_pass), ...
    rep_paper.N,rep_paper.T_actual, ...
    rep_beam.N,rep_beam.T_actual, ...
    max_abs_beta,max_one_minus_cos, ...
    'VariableNames',{ ...
    'gate_status', ...
    'paper1s_pass_fraction','beamderived_pass_fraction', ...
    'representative_paper1s_pass', ...
    'representative_beamderived_pass', ...
    'representative_paper1s_N', ...
    'representative_paper1s_actual_time_s', ...
    'representative_beamderived_N', ...
    'representative_beamderived_actual_time_s', ...
    'max_abs_beta_rad', ...
    'max_abs_1_minus_cos_beta'});

writetable(gate_summary, ...
    fullfile(out_path,'p1b_gate_summary.csv'));

%% Save text summary
write_summary( ...
    out_path,cfg,lambda,beamwidth_rad, ...
    scenario_table,component_table, ...
    small_angle_audit,gate_summary, ...
    rep_paper,rep_beam);

%% Figures
make_figures( ...
    out_path,cfg,scenario_table,scenario_store, ...
    component_table,rep_paper,rep_beam);

%% Save results
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.beamwidth_rad = beamwidth_rad;
results.scenario_table = scenario_table;
results.component_table = component_table;
results.small_angle_audit = small_angle_audit;
results.gate_summary = gate_summary;
results.rep_paper = rep_paper;
results.rep_beam = rep_beam;

save(fullfile(out_path,'exp09_p1b_results.mat'), ...
    'results','-v7.3');

%% Console
fprintf('\n============================================================\n');
fprintf(' EXP009 P1B / Aperture-Constrained FrAc Consistency\n');
fprintf('============================================================\n');
fprintf('Gate                         : %s\n',gate_status);
fprintf('Paper-1s pass fraction       : %.3f\n',paper_pass_fraction);
fprintf('Beam-derived pass fraction   : %.3f\n',beam_pass_fraction);
fprintf('Representative paper N / T   : %d / %.3f s\n', ...
    rep_paper.N,rep_paper.T_actual);
fprintf('Representative beam N / T    : %d / %.3f s\n', ...
    rep_beam.N,rep_beam.T_actual);
fprintf('max |beta|                    : %.6g rad\n',max_abs_beta);
fprintf('max |1-cos(beta)|             : %.6g\n',max_one_minus_cos);
fprintf('============================================================\n\n');

disp(scenario_table);
disp(gate_summary);

fprintf('Saved P1B outputs to:\n%s\n\n',out_path);

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
function beta_grid = build_beta_grid(beta_true,min_sep,cfg)

lo = min(beta_true)- ...
    cfg.beta_grid_margin_separations*min_sep;
hi = max(beta_true)+ ...
    cfg.beta_grid_margin_separations*min_sep;

step = min_sep/cfg.beta_grid_oversample;

beta_grid = (lo:step:hi).';

end

%% ========================================================================
function x = synth_discrete_lfm(N,A,a,b,phi)
% Wang Eq. (13)-compatible discrete LFM:
%
%   exp{j2pi(0.5*a*m^2 + b*m)}.

m = 0:N-1;

x = A.*exp(1j*2*pi*( ...
    0.5*a*m.^2 + b*m) + 1j*phi);

x = x(:).';

end

%% ========================================================================
function E = frac_energy_fft(x,beta_grid,max_lag,cfg)
%FRAC_ENERGY_FFT
% Discrete Eq.(17)-consistent FrAc energy statistic.
%
% For integer lag k:
%
%   z_k[m] = x[m+k] conj(x[m])
%
% Its DFT in m is the ambiguity spectrum versus normalized frequency nu.
% Wang's auto-term condition is:
%
%   tan(beta) = a_i
%
% so for lag k the coherent frequency is:
%
%   nu = k*tan(beta).
%
% We interpolate |Z_k(nu)|^2 and integrate it over k:
%
%   E(beta) = sum_k |R_beta[k]|^2.
%
% This avoids a hidden discrete-FrFT normalization convention.

x = x(:).';
N = numel(x);

beta_grid = beta_grid(:);
tan_beta = tan(beta_grid);

nfft_min = max(2048, ...
    2^nextpow2(cfg.frac_fft_oversample*N));

nfft = nfft_min;

% Frequency axis in cycles/sample, fftshift convention.
if mod(nfft,2)==0
    f = (-nfft/2:nfft/2-1).'/nfft;
else
    f = (-(nfft-1)/2:(nfft-1)/2).'/nfft;
end

E = zeros(numel(beta_grid),1);

for k = 1:max_lag

    z = x(1+k:end).*conj(x(1:end-k));

    Z = fftshift(fft(z,nfft));
    P = abs(Z(:)).^2;

    nu_target = k*tan_beta;

    pk = interp1( ...
        f,P,nu_target,'linear',0);

    % Normalize lag energy by number of valid products so that long lags
    % do not disappear solely because fewer samples overlap.
    overlap = numel(z);
    E = E + pk/max(overlap^2,1);
end

mx = max(E);

if mx>0
    E = E/mx;
end

end

%% ========================================================================
function w = estimate_3db_width(beta_grid,E,beta_true)

beta_grid = beta_grid(:);
E = E(:);

[~,i0] = min(abs(beta_grid-beta_true));

halfwin = max(3,round(0.15*numel(beta_grid)));
i1 = max(1,i0-halfwin);
i2 = min(numel(beta_grid),i0+halfwin);

[~,iloc] = max(E(i1:i2));
ip = i1+iloc-1;

level = E(ip)/2;

il = ip;
while il>1 && E(il)>=level
    il = il-1;
end

ir = ip;
while ir<numel(E) && E(ir)>=level
    ir = ir+1;
end

if il==1 || ir==numel(E)
    w = NaN;
else
    w = beta_grid(ir)-beta_grid(il);
end

end

%% ========================================================================
function [hit,err] = match_true_beta_to_peaks( ...
    beta_grid,E,beta_true,tol,min_prom_frac)

beta_grid = beta_grid(:);
E = E(:);
beta_true = beta_true(:);

idx = local_maxima_indices(E);

if isempty(idx)
    [~,idx] = max(E);
end

% Crude local prominence relative to global dynamic range.
emin = min(E);
erange = max(E)-emin;

keep = true(size(idx));

if erange>0
    for j = 1:numel(idx)
        ii = idx(j);
        left_min = min(E(1:ii));
        right_min = min(E(ii:end));
        prom = E(ii)-max(left_min,right_min);

        if prom < min_prom_frac*erange
            keep(j) = false;
        end
    end
end

idx = idx(keep);

if isempty(idx)
    [~,idx] = max(E);
end

[~,ord] = sort(E(idx),'descend');
idx = idx(ord);

peak_beta = beta_grid(idx);
used = false(size(peak_beta));

hit = false(numel(beta_true),1);
err = nan(numel(beta_true),1);

[bt,sort_idx] = sort(beta_true);

for ii = 1:numel(bt)
    d = abs(peak_beta-bt(ii));
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
    out_path,cfg,lambda,beamwidth_rad, ...
    scenario_table,component_table, ...
    small_angle_audit,gate_summary, ...
    rep_paper,rep_beam)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 P1B / Aperture-Constrained FrAc Consistency\n');
fprintf(fid,'=================================================\n\n');

fprintf(fid,'Paper-grounded Wang 2023 inputs\n');
fprintf(fid,'-------------------------------\n');
fprintf(fid,'fc = %.9g Hz\n',cfg.fc_hz);
fprintf(fid,'PRF = %.9g Hz\n',cfg.prf_hz);
fprintf(fid,'B = %.9g Hz\n',cfg.bandwidth_hz);
fprintf(fid,'H = %.9g m\n',cfg.platform_height_m);
fprintf(fid,'L_a = %.9g m\n',cfg.antenna_length_m);
fprintf(fid,'V_SAR = %.9g m/s\n',cfg.platform_velocity_mps);
fprintf(fid,'pulse width = %.9g s\n',cfg.pulse_width_s);
fprintf(fid,'v_a = %s m/s\n\n', ...
    mat2str(cfg.target_velocity_mps));

fprintf(fid,'Literature / engineering anchors\n');
fprintf(fid,'--------------------------------\n');
fprintf(fid,'lambda = %.9g m\n',lambda);
fprintf(fid,'Wang time-scale anchor = %.6f s\n', ...
    cfg.paper_aperture_time_s);
fprintf(fid,'first-order beamwidth lambda/L_a = %.9g rad\n', ...
    beamwidth_rad);
fprintf(fid,['beam-derived T_ap = R0*(lambda/L_a)/V ' ...
    '(derived estimate, not a Wang table value).\n\n']);

fprintf(fid,'FrAc mechanism\n');
fprintf(fid,'--------------\n');
fprintf(fid,['Wang Eq.(20) auto-term condition: ' ...
    'tan(beta)=a_i.\n']);
fprintf(fid,['a_i = K_res/PRF^2 from the physical residual-FM ' ...
    'mapping.\n']);
fprintf(fid,['Discrete statistic uses lag-wise ambiguity FFTs and ' ...
    'E(beta)=sum_k |R_beta[k]|^2.\n']);
fprintf(fid,['No noise. No CLEAN. Equal amplitudes. b_i=0. ' ...
    'Unknown phases are Monte-Carlo swept.\n\n']);

fprintf(fid,'Small-angle audit\n');
fprintf(fid,'-----------------\n');
fprintf(fid,'max |beta| = %.9g rad\n', ...
    small_angle_audit.max_abs_beta_rad(1));
fprintf(fid,'max |1-cos(beta)| = %.9g\n\n', ...
    small_angle_audit.max_abs_1_minus_cos_beta(1));

fprintf(fid,'Representative component parameters\n');
fprintf(fid,'-----------------------------------\n');

for i = 1:height(component_table)
    fprintf(fid,[ ...
        'P%d: v=%+.3f m/s Kres=%+.9g Hz/s ' ...
        'a=%+.9g beta=%+.9g rad alpha=%+.9g rad\n'], ...
        component_table.component(i), ...
        component_table.azimuth_velocity_mps(i), ...
        component_table.K_residual_Hz_per_s(i), ...
        component_table.discrete_chirp_rate_a_cycles_per_sample2(i), ...
        component_table.predicted_FrAc_beta_rad(i), ...
        component_table.predicted_FrFT_alpha_rad(i));
end

fprintf(fid,'\nRepresentative aperture prescriptions\n');
fprintf(fid,'------------------------------------\n');
fprintf(fid,[ ...
    'Paper1s: R0/H=%.4f N=%d Tactual=%.6f s ' ...
    'phaseAll5=%.4f gate=%d\n'], ...
    rep_paper.rfac,rep_paper.N,rep_paper.T_actual, ...
    rep_paper.phase_all5_rate,rep_paper.gate_pass);

fprintf(fid,[ ...
    'BeamDerived: R0/H=%.4f N=%d Tactual=%.6f s ' ...
    'phaseAll5=%.4f gate=%d\n\n'], ...
    rep_beam.rfac,rep_beam.N,rep_beam.T_actual, ...
    rep_beam.phase_all5_rate,rep_beam.gate_pass);

fprintf(fid,'Gate summary\n');
fprintf(fid,'------------\n');
fprintf(fid,'status = %s\n',gate_summary.gate_status(1));
fprintf(fid,'Paper1s pass fraction = %.6f\n', ...
    gate_summary.paper1s_pass_fraction(1));
fprintf(fid,'BeamDerived pass fraction = %.6f\n\n', ...
    gate_summary.beamderived_pass_fraction(1));

fprintf(fid,'Scenario table\n');
fprintf(fid,'--------------\n');

for i = 1:height(scenario_table)
    fprintf(fid,[ ...
        '%s R0/H=%.4f N=%d T=%.4f minBetaSep=%g ' ...
        'width=%g sep/width=%g avgAll5=%d phaseAll5=%.4f gate=%d\n'], ...
        scenario_table.aperture_mode{i}, ...
        scenario_table.slant_range_factor(i), ...
        scenario_table.azimuth_samples(i), ...
        scenario_table.actual_observation_time_s(i), ...
        scenario_table.min_true_beta_separation_rad(i), ...
        scenario_table.median_single_3db_width_rad(i), ...
        scenario_table.min_sep_over_median_3db_width(i), ...
        scenario_table.phase_averaged_all5_detected(i), ...
        scenario_table.phase_mc_all5_detection_rate(i), ...
        scenario_table.gate_pass(i));
end

fprintf(fid,'\nInterpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) 1 s is a literature time-scale anchor, not proof that ' ...
    'Wang five-point Fig.8 used exactly N=188.\n']);
fprintf(fid,['2) Beam-derived aperture time is an engineering estimate, not ' ...
    'a Wang-reported parameter.\n']);
fprintf(fid,['3) If FrAc resolves the components at plausible aperture scales, ' ...
    'P1 matched-K was overly conservative and PA4 can use FrAc beta.\n']);
fprintf(fid,['4) If FrAc does not resolve them, report that Wang public ' ...
    'parameters are insufficient for unique Fig.8 reproduction; do not ' ...
    'increase N merely to force five peaks.\n']);
fprintf(fid,['5) P1B is still a consistency audit. Do not introduce noise, ' ...
    'CLEAN, learned models, or adaptive search here.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,scenario_table,scenario_store, ...
    component_table,rep_paper,rep_beam)

%% Fig 1 — aperture constraints
fig = figure('Visible',cfg.figure_visible);

rfac = cfg.slant_range_factor(:);
paperT = cfg.paper_aperture_time_s*ones(size(rfac));
beamT = nan(size(rfac));

lambda = cfg.c/cfg.fc_hz;
beamwidth = cfg.beamwidth_scale*lambda/cfg.antenna_length_m;

for i = 1:numel(rfac)
    R0 = cfg.platform_height_m*rfac(i);
    beamT(i) = R0*beamwidth/cfg.platform_velocity_mps;
end

plot(rfac,paperT,'o-','LineWidth',1.2);
hold on;
plot(rfac,beamT,'s-','LineWidth',1.2);

xlabel('R_0 / H');
ylabel('Aperture time (s)');
title('EXP009 P1B — Literature and Beam-Derived Aperture Scales');
legend({'Wang ~1 s time-scale anchor','Beam-derived estimate'}, ...
    'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_aperture_constraints.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — representative 1-s FrAc curve
fig = figure('Visible',cfg.figure_visible);

plot(rep_paper.beta_grid,rep_paper.phase_E_avg, ...
    'LineWidth',1.3);
hold on;

for ic = 1:5
    xline(rep_paper.beta_true(ic),':');
end

xlabel('FrAc rotation angle \beta (rad)');
ylabel('Normalized E_\rho(\beta)');
title(sprintf( ...
    'EXP009 P1B — FrAc Consistency at ~1 s (R_0/H=%.3g, N=%d)', ...
    rep_paper.rfac,rep_paper.N));
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_representative_paper1s_frac.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — representative beam-derived FrAc curve
fig = figure('Visible',cfg.figure_visible);

plot(rep_beam.beta_grid,rep_beam.phase_E_avg, ...
    'LineWidth',1.3);
hold on;

for ic = 1:5
    xline(rep_beam.beta_true(ic),':');
end

xlabel('FrAc rotation angle \beta (rad)');
ylabel('Normalized E_\rho(\beta)');
title(sprintf( ...
    ['EXP009 P1B — FrAc Consistency at Beam-Derived Aperture ' ...
     '(R_0/H=%.3g, N=%d)'], ...
    rep_beam.rfac,rep_beam.N));
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_representative_beam_frac.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — phase MC all-five detection rate
modes = {'Paper1s','BeamDerived'};
Z = nan(numel(cfg.slant_range_factor),2);

for iR = 1:numel(cfg.slant_range_factor)
    for im = 1:2
        mm = ...
            abs(scenario_table.slant_range_factor- ...
                cfg.slant_range_factor(iR))<1e-12 & ...
            strcmp(scenario_table.aperture_mode,modes{im});

        Z(iR,im) = ...
            scenario_table.phase_mc_all5_detection_rate(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
imagesc(1:2,cfg.slant_range_factor,Z,[0 1]);
set(gca,'YDir','normal');
xticks(1:2);
xticklabels({'Paper ~1 s','Beam-derived'});
ylabel('R_0 / H');
colorbar;
title('EXP009 P1B — Five-Component FrAc Detection Rate');
exportgraphics(fig, ...
    fullfile(out_path,'fig04_phase_mc_detection_rate.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5 — separability ratio
Z = nan(numel(cfg.slant_range_factor),2);

for iR = 1:numel(cfg.slant_range_factor)
    for im = 1:2
        mm = ...
            abs(scenario_table.slant_range_factor- ...
                cfg.slant_range_factor(iR))<1e-12 & ...
            strcmp(scenario_table.aperture_mode,modes{im});

        Z(iR,im) = ...
            scenario_table.min_sep_over_median_3db_width(mm);
    end
end

fig = figure('Visible',cfg.figure_visible);
imagesc(1:2,cfg.slant_range_factor,Z);
set(gca,'YDir','normal');
xticks(1:2);
xticklabels({'Paper ~1 s','Beam-derived'});
ylabel('R_0 / H');
colorbar;
title('EXP009 P1B — FrAc Separation / Single-Component 3-dB Width');
exportgraphics(fig, ...
    fullfile(out_path,'fig05_frac_separability_ratio.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6 — physical K -> beta mapping
fig = figure('Visible',cfg.figure_visible);
plot( ...
    component_table.azimuth_velocity_mps, ...
    component_table.predicted_FrAc_beta_rad, ...
    'o-','LineWidth',1.2);

xlabel('Azimuth velocity v_a (m/s)');
ylabel('Predicted FrAc \beta (rad)');
title('EXP009 P1B — Physical Velocity to FrAc-Angle Mapping');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig06_velocity_to_frac_beta.png'), ...
    'Resolution',180);
close(fig);

end
