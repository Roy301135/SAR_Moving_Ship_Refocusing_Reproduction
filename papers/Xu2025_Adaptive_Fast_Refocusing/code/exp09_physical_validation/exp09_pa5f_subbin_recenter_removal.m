function results = exp09_pa5f_subbin_recenter_removal()
%EXP09_PA5F_SUBBIN_RECENTER_REMOVAL
% EXP009 / PA5F
%
% Sub-Bin Recentered / Fence-Aware Strong Removal
%
% Research questions
% ------------------
% RQ1. If the true fractional-bin offset eta is removed before narrowband
%      deletion, does the PA5E-R1 off-grid strong-leakage floor collapse?
%
% RQ2. Can a fixed 3-point log-power parabolic estimator recover enough of
%      eta from a strong-only focused spectrum to approach the oracle?
%
% RQ3. How much estimator degradation appears when eta is estimated from
%      the actual strong+weak coherent mixture?
%
% RQ4. Does the measured residual strong leakage follow the finite-length
%      Dirichlet leakage model after recentering?
%
% Mathematical chain
% ------------------
% After true strong dechirping and recentering,
%
%   epsilon = eta - eta_hat
%
% and the strong component becomes
%
%   z[n] = exp(j*2*pi*epsilon*n/N).
%
% Its normalized N-point DFT-bin energy is
%
%   p_k(epsilon)
%     = | sin(pi(epsilon-k))
%         / (N sin(pi(epsilon-k)/N)) |^2.
%
% For an actual removal mask M,
%
%   L0^2 = 1 - sum_{k in M} p_k(epsilon).
%
% Together with PA5B-PA5E,
%
%   E0^2 = L0^2/r_A^2 + D0^2
%
% and
%
%   r_min = L0/sqrt(1-D0^2).
%
% Important isolation
% -------------------
% beta_s / chirp-rate is TRUE for every group.
% Noise is OFF.
% Peak semantics are fixed to PlateauAwareTol.
%
% Run:
%   results = exp09_pa5f_subbin_recenter_removal;

cfg = config_exp09_pa5f_subbin_recenter_removal();

validate_config_complete(cfg);
run_startup_self_tests(cfg);

%% Output path
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5f_subbin_recenter_removal');
else
    out_path = cfg.output_dir;
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

%% Physical constants
lambda = cfg.c/cfg.fc_hz;
R0 = cfg.platform_height_m*cfg.slant_range_factor;

beamwidth_rad = ...
    cfg.beamwidth_scale * ...
    lambda/cfg.antenna_length_m;

vw = cfg.weak_velocity_mps;

[~,~,Kw] = residual_fm_rates( ...
    vw,R0,lambda,cfg);

aw = Kw/(cfg.prf_hz^2);

%% Apertures
T_paper = cfg.paper_aperture_time_s;
N_paper = max(32,round(cfg.prf_hz*T_paper));

T_beam = ...
    R0*beamwidth_rad/cfg.platform_velocity_mps;
N_beam = max(32,round(cfg.prf_hz*T_beam));

aperture_names = ["Paper1s","BeamDerived"];
N_list = [N_paper,N_beam];

%% =======================================================================
%  Track A — zero-mismatch floor / mechanism audit
%  Groups G0/G1/G2 use STRONG-ONLY mask selection.
%  =======================================================================
floor_rows = {};
sides = ["LowV","HighV"];
floor_groups = ["G0_Baseline","G1_OracleRecenter","G2_StrongOnlyEstimate"];

for ia = 1:numel(aperture_names)

    mode = aperture_names(ia);
    N = N_list(ia);

    for io = 1:numel(cfg.fractional_bin_offsets)

        eta = cfg.fractional_bin_offsets(io);
        b = eta/N;

        for idv = 1:numel(cfg.delta_velocity_mps)

            dv = cfg.delta_velocity_mps(idv);

            for iside = 1:numel(sides)

                side = sides(iside);

                if side=="LowV"
                    vs = vw-dv;
                else
                    vs = vw+dv;
                end

                [~,~,Ks] = residual_fm_rates( ...
                    vs,R0,lambda,cfg);

                as = Ks/(cfg.prf_hz^2);

                s0 = synth_discrete_lfm( ...
                    N,cfg.A_strong,as,b,0);

                w0 = synth_discrete_lfm( ...
                    N,1,aw,b,0);

                % Strong-only estimator is window-independent.
                eta_hat_g2 = estimate_subbin_offset( ...
                    s0,as,cfg);

                eta_hat_values = [ ...
                    0, ...
                    eta, ...
                    eta_hat_g2];

                for ig = 1:numel(floor_groups)

                    group = floor_groups(ig);
                    eta_hat = eta_hat_values(ig);
                    epsilon = wrap_half_open(eta-eta_hat,N);

                    [s_rec,~] = recenter_signal( ...
                        s0,eta_hat);

                    [w_rec,~] = recenter_signal( ...
                        w0,eta_hat);

                    Ys = matched_lfm_transform( ...
                        s_rec,as);

                    for il = 1:numel( ...
                            cfg.filter_window_length_bins)

                        Lwin = ...
                            cfg.filter_window_length_bins(il);

                        [mask,info] = build_plateau_tol_mask( ...
                            Ys,Lwin,cfg);

                        [sr,wr] = apply_fixed_mask_components( ...
                            s_rec,w_rec,as,mask);

                        L0 = ...
                            norm(sr) / ...
                            max(norm(s_rec), ...
                                cfg.small_norm_floor);

                        D0 = ...
                            norm(wr) / ...
                            max(norm(w_rec), ...
                                cfg.small_norm_floor);

                        L0_dir = ...
                            dirichlet_leakage_from_mask( ...
                                N,epsilon,mask);

                        dir_err = abs(L0-L0_dir);

                        rmin = recoverability_floor( ...
                            L0,D0);

                        floor_rows(end+1,:) = { ... %#ok<AGROW>
                            char(mode),N, ...
                            eta,b,dv,char(side),vs, ...
                            char(group), ...
                            eta_hat, ...
                            eta_hat-eta, ...
                            epsilon, ...
                            Lwin, ...
                            L0,D0,rmin, ...
                            L0_dir,dir_err, ...
                            info.raw_detected_bin_count, ...
                            info.mask_bin_count, ...
                            info.mask_fraction, ...
                            info.tie_tolerance_abs};
                    end
                end
            end
        end
    end
end

floor_table = cell2table(floor_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'fractional_bin_offset_eta', ...
    'center_frequency_cycles_per_sample', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps','group', ...
    'eta_hat_bins','eta_error_bins', ...
    'residual_epsilon_bins','window_bins', ...
    'zero_mismatch_strong_leak_L0', ...
    'zero_mismatch_weak_loss_D0', ...
    'recoverability_floor_rmin', ...
    'dirichlet_predicted_L0', ...
    'dirichlet_abs_error', ...
    'raw_detected_bin_count', ...
    'mask_bin_count','mask_fraction', ...
    'tie_tolerance_abs'});

writetable(floor_table, ...
    fullfile(out_path,'pa5f_floor_trials.csv'));

floor_summary = summarize_floor(floor_table);

writetable(floor_summary, ...
    fullfile(out_path,'pa5f_floor_summary.csv'));

best_floor_summary = summarize_best_floor( ...
    floor_summary);

writetable(best_floor_summary, ...
    fullfile(out_path,'pa5f_best_floor_summary.csv'));

dirichlet_summary = summarize_dirichlet( ...
    floor_table,cfg);

writetable(dirichlet_summary, ...
    fullfile(out_path,'pa5f_dirichlet_validation_summary.csv'));

%% =======================================================================
%  Track B — practical coherent-mixture audit
%  G0/G1/G2/G3 use mixture mask selection.
%  =======================================================================
trial_rows = {};
all_groups = [floor_groups,"G3_PracticalEstimate"];

for ia = 1:numel(aperture_names)

    mode = aperture_names(ia);
    N = N_list(ia);

    for io = 1:numel(cfg.fractional_bin_offsets)

        eta = cfg.fractional_bin_offsets(io);
        b = eta/N;

        for idv = 1:numel(cfg.delta_velocity_mps)

            dv = cfg.delta_velocity_mps(idv);

            for iside = 1:numel(sides)

                side = sides(iside);

                if side=="LowV"
                    vs = vw-dv;
                else
                    vs = vw+dv;
                end

                [~,~,Ks] = residual_fm_rates( ...
                    vs,R0,lambda,cfg);

                as = Ks/(cfg.prf_hz^2);

                s0 = synth_discrete_lfm( ...
                    N,cfg.A_strong,as,b,0);

                w_unit = synth_discrete_lfm( ...
                    N,1,aw,b,0);

                eta_hat_g2 = estimate_subbin_offset( ...
                    s0,as,cfg);

                for ir = 1:numel( ...
                        cfg.weak_to_strong_ratio)

                    rA = ...
                        cfg.weak_to_strong_ratio(ir);

                    for ip = 1:numel( ...
                            cfg.relative_phase_rad)

                        phi = cfg.relative_phase_rad(ip);

                        w_true = ...
                            rA*exp(1j*phi)*w_unit;

                        x = s0+w_true;

                        eta_hat_g3 = ...
                            estimate_subbin_offset( ...
                                x,as,cfg);

                        eta_hat_values = [ ...
                            0, ...
                            eta, ...
                            eta_hat_g2, ...
                            eta_hat_g3];

                        for ig = 1:numel(all_groups)

                            group = all_groups(ig);
                            eta_hat = eta_hat_values(ig);

                            epsilon = ...
                                wrap_half_open( ...
                                    eta-eta_hat,N);

                            [x_rec,~] = ...
                                recenter_signal( ...
                                    x,eta_hat);

                            [s_rec,~] = ...
                                recenter_signal( ...
                                    s0,eta_hat);

                            [w_rec,~] = ...
                                recenter_signal( ...
                                    w_true,eta_hat);

                            Yx = matched_lfm_transform( ...
                                x_rec,as);

                            for il = 1:numel( ...
                                    cfg.filter_window_length_bins)

                                Lwin = ...
                                    cfg.filter_window_length_bins(il);

                                [mask,info] = ...
                                    build_plateau_tol_mask( ...
                                        Yx,Lwin,cfg);

                                r_rec = remove_with_mask( ...
                                    x_rec,as,mask);

                                E = ...
                                    norm(r_rec-w_rec) / ...
                                    max(norm(w_rec), ...
                                        cfg.small_norm_floor);

                                [sr,wr] = ...
                                    apply_fixed_mask_components( ...
                                        s_rec,w_rec,as,mask);

                                Ls = ...
                                    norm(sr) / ...
                                    max(norm(s_rec), ...
                                        cfg.small_norm_floor);

                                Dw = ...
                                    norm(wr) / ...
                                    max(norm(w_rec), ...
                                        cfg.small_norm_floor);

                                Epred = sqrt( ...
                                    (Ls/rA)^2+Dw^2);

                                identity_err = ...
                                    abs(E-Epred);

                                Ldir = ...
                                    dirichlet_leakage_from_mask( ...
                                        N,epsilon,mask);

                                [weak_ok,weak_ratio] = ...
                                    weak_stage_readiness( ...
                                        r_rec,aw, ...
                                        epsilon/N,cfg);

                                trial_rows(end+1,:) = { ... %#ok<AGROW>
                                    char(mode),N, ...
                                    eta,b,dv,char(side),vs, ...
                                    rA,phi,char(group), ...
                                    eta_hat, ...
                                    eta_hat-eta, ...
                                    epsilon,Lwin, ...
                                    E, ...
                                    double(E<= ...
                                        cfg.error_feasible_threshold), ...
                                    double(weak_ok), ...
                                    weak_ratio, ...
                                    Ls,Dw,Epred, ...
                                    identity_err, ...
                                    Ldir,abs(Ls-Ldir), ...
                                    info.raw_detected_bin_count, ...
                                    info.mask_bin_count, ...
                                    info.mask_fraction};
                            end
                        end
                    end
                end
            end
        end
    end
end

trial_table = cell2table(trial_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'fractional_bin_offset_eta', ...
    'center_frequency_cycles_per_sample', ...
    'delta_velocity_mps','strong_velocity_side', ...
    'strong_velocity_mps', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'group','eta_hat_bins','eta_error_bins', ...
    'residual_epsilon_bins','window_bins', ...
    'practical_error_ratio', ...
    'error_feasible_E_le_1', ...
    'weak_stage_success','weak_stage_peak_ratio', ...
    'strong_leak_ratio','weak_projection_loss_ratio', ...
    'predicted_error_ratio','identity_abs_error', ...
    'dirichlet_predicted_strong_leak', ...
    'dirichlet_strong_leak_abs_error', ...
    'raw_detected_bin_count', ...
    'mask_bin_count','mask_fraction'});

writetable(trial_table, ...
    fullfile(out_path,'pa5f_practical_trials.csv'));

practical_summary = summarize_practical( ...
    trial_table);

writetable(practical_summary, ...
    fullfile(out_path,'pa5f_practical_summary.csv'));

best_practical_summary = ...
    summarize_best_practical( ...
        practical_summary);

writetable(best_practical_summary, ...
    fullfile(out_path,'pa5f_best_practical_summary.csv'));

estimator_summary = summarize_estimators( ...
    trial_table);

writetable(estimator_summary, ...
    fullfile(out_path,'pa5f_subbin_estimator_summary.csv'));

identity_summary = summarize_identity( ...
    trial_table,cfg);

writetable(identity_summary, ...
    fullfile(out_path,'pa5f_projection_identity_summary.csv'));

%% Improvement tables
improvement_summary = ...
    summarize_improvement( ...
        best_floor_summary, ...
        best_practical_summary);

writetable(improvement_summary, ...
    fullfile(out_path,'pa5f_improvement_summary.csv'));

%% Decision
decision_summary = ...
    build_decision_summary( ...
        best_floor_summary, ...
        best_practical_summary, ...
        estimator_summary, ...
        dirichlet_summary, ...
        identity_summary,cfg);

writetable(decision_summary, ...
    fullfile(out_path,'pa5f_decision_summary.csv'));

%% Text summary
write_summary( ...
    out_path,cfg,lambda,R0, ...
    floor_summary,best_floor_summary, ...
    estimator_summary, ...
    best_practical_summary, ...
    dirichlet_summary, ...
    identity_summary, ...
    decision_summary);

%% Figures
make_figures( ...
    out_path,cfg, ...
    floor_summary,best_floor_summary, ...
    practical_summary,best_practical_summary, ...
    estimator_summary,trial_table, ...
    floor_table);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.R0 = R0;
results.floor_table = floor_table;
results.floor_summary = floor_summary;
results.best_floor_summary = best_floor_summary;
results.dirichlet_summary = dirichlet_summary;
results.trial_table = trial_table;
results.practical_summary = practical_summary;
results.best_practical_summary = best_practical_summary;
results.estimator_summary = estimator_summary;
results.identity_summary = identity_summary;
results.improvement_summary = improvement_summary;
results.decision_summary = decision_summary;

save(fullfile(out_path,'exp09_pa5f_results.mat'), ...
    'results','-v7.3');

fprintf('\n============================================================\n');
fprintf(' EXP009 PA5F / Sub-Bin Recentered Fence-Aware Removal\n');
fprintf('============================================================\n');
disp(dirichlet_summary);
disp(estimator_summary);
disp(best_floor_summary);
disp(best_practical_summary);
disp(decision_summary);
fprintf('============================================================\n');
fprintf('Saved to:\n%s\n\n',out_path);

end

%% ========================================================================
function validate_config_complete(cfg)

required = { ...
    'c', ...
    'fc_hz', ...
    'prf_hz', ...
    'bandwidth_hz', ...
    'platform_height_m', ...
    'antenna_length_m', ...
    'platform_velocity_mps', ...
    'pulse_width_s', ...
    'slant_range_factor', ...
    'paper_aperture_time_s', ...
    'beamwidth_scale', ...
    'weak_velocity_mps', ...
    'delta_velocity_mps', ...
    'A_strong', ...
    'weak_to_strong_ratio', ...
    'num_relative_phases', ...
    'relative_phase_rad', ...
    'fractional_bin_offsets', ...
    'filter_window_length_bins', ...
    'peak_semantics', ...
    'frac_domain_peak_gate', ...
    'tie_eps_multiplier', ...
    'subbin_estimator', ...
    'subbin_delta_clip', ...
    'log_power_floor', ...
    'weak_stage_peak_gate', ...
    'weak_stage_center_tolerance_bins', ...
    'error_feasible_threshold', ...
    'small_norm_floor', ...
    'dirichlet_identity_gate', ...
    'oracle_leakage_gate', ...
    'estimator_good_rmse_bins', ...
    'practical_halfbin_improvement_ratio_gate', ...
    'figure_visible', ...
    'output_dir'};

missing = required(~isfield(cfg,required));

if ~isempty(missing)
    error('EXP009:PA5F:MissingConfigField', ...
        'Missing config field(s): %s', ...
        strjoin(missing,', '));
end

end

%% ========================================================================
function run_startup_self_tests(cfg)
% Three deterministic guards:
%   A) exact half-bin sub-bin estimator must be close to 0.5;
%   B) oracle recentering must collapse a half-bin tone to one DFT bin;
%   C) analytic Dirichlet energy must match direct FFT energy.

%% A) estimator self-test
N = 188;
eta = 0.5;
b = eta/N;
a = 0.0123;

x = synth_discrete_lfm(N,1,a,b,0);

ehat = estimate_subbin_offset(x,a,cfg);

if abs(ehat-eta)>1e-10
    error('EXP009:PA5F:SubbinSelfTestFailed', ...
        ['Half-bin estimator self-test failed. ' ...
         'Expected 0.5, got %.16g.'],ehat);
end

%% B) oracle recentering self-test
[xr,~] = recenter_signal(x,eta);
Y = matched_lfm_transform(xr,a);

[mask,~] = build_plateau_tol_mask( ...
    Y,1,cfg);

leak = dirichlet_leakage_from_mask( ...
    N,0,mask);

if leak>cfg.oracle_leakage_gate
    error('EXP009:PA5F:OracleRecenterSelfTestFailed', ...
        ['Oracle half-bin recentering did not collapse ' ...
         'to a single-bin removal. Leakage=%g.'],leak);
end

%% C) Dirichlet / FFT distribution self-test
eps0 = 0.271828;
m = 0:N-1;

z = exp(1j*2*pi*eps0*m/N);

Yz = fftshift(fft(z))/sqrt(N);
p_fft = abs(Yz).^2 / sum(abs(Yz).^2);

p_dir = dirichlet_bin_energy(N,eps0);

err = max(abs(p_fft(:)-p_dir(:)));

if err>cfg.dirichlet_identity_gate
    error('EXP009:PA5F:DirichletSelfTestFailed', ...
        ['Dirichlet/FFT energy self-test failed. ' ...
         'max abs error=%g.'],err);
end

end

%% ========================================================================
function [K_A,K_SAR,K_res] = ...
    residual_fm_rates(v,R0,lambda,cfg)

V = cfg.platform_velocity_mps;

K_A = -2*(V-v).^2/(lambda*R0);
K_SAR = 2*V^2/(lambda*R0);
K_res = K_SAR.^2./(K_A-K_SAR)+K_SAR;

end

%% ========================================================================
function x = synth_discrete_lfm(N,A,a,b,phi)

m = 0:N-1;

x = A.*exp(1j*2*pi*( ...
    0.5*a*m.^2+b*m)+1j*phi);

x = x(:).';

end

%% ========================================================================
function Y = matched_lfm_transform(x,a)

x = x(:).';

N = numel(x);
m = 0:N-1;

z = x.*exp(-1j*pi*a*m.^2);

Y = fftshift(fft(z))/sqrt(N);

end

%% ========================================================================
function x = inverse_matched_lfm_transform(Y,a)

Y = Y(:).';

N = numel(Y);
m = 0:N-1;

z = ifft(ifftshift(Y))*sqrt(N);

x = z.*exp(1j*pi*a*m.^2);

end

%% ========================================================================
function eta_hat = estimate_subbin_offset(x,a,cfg)
% 3-point log-power parabolic interpolation around the dominant DFT bin.
%
% Output:
%   absolute focused-bin coordinate relative to DC.
%
% Standard interpolation:
%
%   delta = 0.5*(L_- - L_+) / (L_- - 2L_0 + L_+)
%
% where L = log(power).

if ~strcmpi(cfg.subbin_estimator, ...
        'LogPowerParabolic3')
    error('Unknown sub-bin estimator: %s', ...
        cfg.subbin_estimator);
end

Y = matched_lfm_transform(x,a);
P = abs(Y).^2;

N = numel(P);
[~,i0] = max(P);

im = mod(i0-2,N)+1;
ip = mod(i0,N)+1;

Lm = log(max(P(im), ...
    cfg.log_power_floor*max(P)));

L0 = log(max(P(i0), ...
    cfg.log_power_floor*max(P)));

Lp = log(max(P(ip), ...
    cfg.log_power_floor*max(P)));

den = Lm-2*L0+Lp;

if abs(den)<=100*eps(max(abs([Lm,L0,Lp])))
    delta = 0;
else
    delta = 0.5*(Lm-Lp)/den;
end

delta = min(max( ...
    delta,-cfg.subbin_delta_clip), ...
    cfg.subbin_delta_clip);

dc = floor(N/2)+1;
k0 = i0-dc;

eta_hat = k0+delta;

% Map the frequency coordinate to the principal N-bin interval.
eta_hat = wrap_half_open(eta_hat,N);

end

%% ========================================================================
function [xr,phase] = recenter_signal(x,eta_hat)
% Shift the common focused center frequency by -eta_hat/N cycles/sample.

x = x(:).';
N = numel(x);
m = 0:N-1;

phase = exp(-1j*2*pi*eta_hat*m/N);

xr = x.*phase;

end

%% ========================================================================
function v = wrap_half_open(v,N)
% Wrap bin coordinate to [-N/2, N/2).

v = mod(v+N/2,N)-N/2;

end

%% ========================================================================
function [mask,info] = ...
    build_plateau_tol_mask( ...
        Y,Lwin,cfg)

amp = abs(Y(:).');
N = numel(amp);

amax = max(amp);
gate = cfg.frac_domain_peak_gate*amax;

tol = ...
    cfg.tie_eps_multiplier * ...
    N * eps(max(amax,1));

centers = plateau_aware_tol( ...
    amp,gate,tol);

half = floor((Lwin-1)/2);

mask = false(1,N);

for k = 1:numel(centers)

    i1 = max(1,centers(k)-half);
    i2 = min(N,centers(k)+half);

    mask(i1:i2) = true;
end

info = struct();
info.raw_indices = centers;
info.raw_detected_bin_count = numel(centers);
info.mask_bin_count = nnz(mask);
info.mask_fraction = mean(mask);
info.tie_tolerance_abs = tol;

end

%% ========================================================================
function pk = plateau_aware_tol( ...
    amp,gate,tol)

amp = amp(:).';
N = numel(amp);

pk = [];

if N==1
    pk = 1;
    return;
end

if amp(1)>=amp(2)-tol && ...
        amp(1)>=gate-tol
    pk(end+1) = 1; %#ok<AGROW>
end

for i = 2:N-1

    ge_left = ...
        amp(i)>=amp(i-1)-tol;

    ge_right = ...
        amp(i)>=amp(i+1)-tol;

    strict_somewhere = ...
        amp(i)>amp(i-1)+tol || ...
        amp(i)>amp(i+1)+tol;

    if ge_left && ge_right && ...
            strict_somewhere && ...
            amp(i)>=gate-tol

        pk(end+1) = i; %#ok<AGROW>
    end
end

if amp(N)>=amp(N-1)-tol && ...
        amp(N)>=gate-tol
    pk(end+1) = N; %#ok<AGROW>
end

pk = unique(pk);

if isempty(pk)

    [~,imax] = max(amp);

    pk = find( ...
        abs(amp-amp(imax))<=tol & ...
        amp>=gate-tol);
end

end

%% ========================================================================
function r = remove_with_mask(x,a,mask)

Y = matched_lfm_transform(x,a);

Yext = zeros(size(Y));
Yext(mask) = Y(mask);

ext = inverse_matched_lfm_transform( ...
    Yext,a);

r = x-ext;

end

%% ========================================================================
function [sr,wr] = ...
    apply_fixed_mask_components( ...
        s,w,a,mask)

Ys = matched_lfm_transform(s,a);
Yw = matched_lfm_transform(w,a);

Ysq = zeros(size(Ys));
Ysq(mask) = Ys(mask);

Ywq = zeros(size(Yw));
Ywq(mask) = Yw(mask);

Qs = inverse_matched_lfm_transform( ...
    Ysq,a);

Qw = inverse_matched_lfm_transform( ...
    Ywq,a);

sr = s-Qs;
wr = Qw;

end

%% ========================================================================
function p = dirichlet_bin_energy(N,epsilon)
% Exact normalized DFT-bin energy of
%
%   exp(j*2*pi*epsilon*n/N), n=0,...,N-1
%
% in fftshift ordering.

if mod(N,2)==0
    k = (-N/2):(N/2-1);
else
    k = -floor(N/2):floor(N/2);
end

x = epsilon-k;

num = sin(pi*x);
den = N*sin(pi*x/N);

ratio = zeros(size(x));

near = abs(den)<=100*eps;

ratio(~near) = ...
    num(~near)./den(~near);

% Limiting magnitude is 1 when x is a multiple of N.
% In the principal interval this relevant singularity is x=0.
ratio(near) = 1;

p = abs(ratio).^2;
p = p(:).';

% Only suppress roundoff; do not change the analytic model.
p = p/max(sum(p),eps);

end

%% ========================================================================
function L = dirichlet_leakage_from_mask( ...
    N,epsilon,mask)

p = dirichlet_bin_energy(N,epsilon);

captured = sum(p(logical(mask)));

L = sqrt(max(0,1-captured));

end

%% ========================================================================
function rmin = recoverability_floor(L0,D0)

if D0>=1-1e-12

    if L0<=1e-12
        rmin = 0;
    else
        rmin = Inf;
    end

else

    rmin = ...
        L0/sqrt(max(1-D0^2,eps));
end

end

%% ========================================================================
function [ok,ratio] = ...
    weak_stage_readiness( ...
        residual,aweak,bweak,cfg)

Y = matched_lfm_transform( ...
    residual,aweak);

amp = abs(Y);
N = numel(amp);

eta = bweak*N;
dc = floor(N/2)+1;

idx_expected = round(dc+eta);
idx_expected = mod(idx_expected-1,N)+1;

cand = [];

for d = -cfg.weak_stage_center_tolerance_bins: ...
        cfg.weak_stage_center_tolerance_bins

    cand(end+1) = ...
        mod(idx_expected-1+d,N)+1; %#ok<AGROW>
end

local_peak = max(amp(cand));
global_peak = max(amp);

ratio = ...
    local_peak / ...
    max(global_peak,cfg.small_norm_floor);

ok = ratio>=cfg.weak_stage_peak_gate;

end

%% ========================================================================
function S = summarize_floor(T)

modes = unique(string(T.aperture_mode),'stable');
etas = unique(T.fractional_bin_offset_eta).';
groups = unique(string(T.group),'stable');
wins = unique(T.window_bins).';

rows = {};

for im = 1:numel(modes)

    for io = 1:numel(etas)

        for ig = 1:numel(groups)

            for iw = 1:numel(wins)

                M = T( ...
                    string(T.aperture_mode)==modes(im) & ...
                    abs(T.fractional_bin_offset_eta-etas(io))<1e-12 & ...
                    string(T.group)==groups(ig) & ...
                    T.window_bins==wins(iw),:);

                r = M.recoverability_floor_rmin;
                rf = r(isfinite(r));

                if isempty(rf)
                    medr = Inf;
                    minr = Inf;
                    maxr = Inf;
                else
                    medr = median(rf);
                    minr = min(rf);
                    maxr = max(rf);
                end

                rows(end+1,:) = { ... %#ok<AGROW>
                    char(modes(im)),etas(io), ...
                    char(groups(ig)),wins(iw), ...
                    median(M.eta_hat_bins), ...
                    median(abs(M.eta_error_bins)), ...
                    median(abs(M.residual_epsilon_bins)), ...
                    median(M.zero_mismatch_strong_leak_L0), ...
                    median(M.zero_mismatch_weak_loss_D0), ...
                    medr,minr,maxr, ...
                    median(M.dirichlet_predicted_L0), ...
                    max(M.dirichlet_abs_error)};
            end
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset_eta', ...
    'group','window_bins', ...
    'median_eta_hat_bins', ...
    'median_abs_eta_error_bins', ...
    'median_abs_residual_epsilon_bins', ...
    'median_zero_mismatch_strong_leak_L0', ...
    'median_zero_mismatch_weak_loss_D0', ...
    'median_recoverability_floor_rmin', ...
    'minimum_recoverability_floor_rmin', ...
    'maximum_recoverability_floor_rmin', ...
    'median_dirichlet_predicted_L0', ...
    'maximum_dirichlet_abs_error'});

end

%% ========================================================================
function B = summarize_best_floor(S)

modes = unique(string(S.aperture_mode),'stable');
etas = unique(S.fractional_bin_offset_eta).';
groups = unique(string(S.group),'stable');

rows = {};

for im = 1:numel(modes)

    for io = 1:numel(etas)

        for ig = 1:numel(groups)

            M = S( ...
                string(S.aperture_mode)==modes(im) & ...
                abs(S.fractional_bin_offset_eta-etas(io))<1e-12 & ...
                string(S.group)==groups(ig),:);

            vals = M.median_recoverability_floor_rmin;

            [bestv,ib] = min(vals);

            rows(end+1,:) = { ... %#ok<AGROW>
                char(modes(im)),etas(io), ...
                char(groups(ig)), ...
                M.window_bins(ib),bestv, ...
                M.median_zero_mismatch_strong_leak_L0(ib), ...
                M.median_zero_mismatch_weak_loss_D0(ib), ...
                M.median_abs_eta_error_bins(ib), ...
                M.median_abs_residual_epsilon_bins(ib)};
        end
    end
end

B = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset_eta', ...
    'group','best_window_bins', ...
    'best_median_rmin', ...
    'best_median_L0', ...
    'best_median_D0', ...
    'median_abs_eta_error_bins', ...
    'median_abs_residual_epsilon_bins'});

end

%% ========================================================================
function D = summarize_dirichlet(T,cfg)

groups = unique(string(T.group),'stable');

rows = {};

for ig = 1:numel(groups)

    M = T(string(T.group)==groups(ig),:);

    rows(end+1,:) = { ... %#ok<AGROW>
        char(groups(ig)),height(M), ...
        median(M.dirichlet_abs_error), ...
        max(M.dirichlet_abs_error), ...
        double(max(M.dirichlet_abs_error)<= ...
            cfg.dirichlet_identity_gate)};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'group','n', ...
    'median_abs_L0_model_error', ...
    'maximum_abs_L0_model_error', ...
    'dirichlet_gate_pass'});

end

%% ========================================================================
function S = summarize_practical(T)

modes = unique(string(T.aperture_mode),'stable');
etas = unique(T.fractional_bin_offset_eta).';
groups = unique(string(T.group),'stable');
wins = unique(T.window_bins).';

rows = {};

for im = 1:numel(modes)

    for io = 1:numel(etas)

        for ig = 1:numel(groups)

            for iw = 1:numel(wins)

                M = T( ...
                    string(T.aperture_mode)==modes(im) & ...
                    abs(T.fractional_bin_offset_eta-etas(io))<1e-12 & ...
                    string(T.group)==groups(ig) & ...
                    T.window_bins==wins(iw),:);

                rows(end+1,:) = { ... %#ok<AGROW>
                    char(modes(im)),etas(io), ...
                    char(groups(ig)),wins(iw), ...
                    height(M), ...
                    median(M.practical_error_ratio), ...
                    prctile(M.practical_error_ratio,90), ...
                    mean(M.error_feasible_E_le_1), ...
                    mean(M.weak_stage_success), ...
                    median(M.strong_leak_ratio), ...
                    median(M.weak_projection_loss_ratio), ...
                    median(abs(M.eta_error_bins)), ...
                    prctile(abs(M.eta_error_bins),90), ...
                    median(abs(M.residual_epsilon_bins))};
            end
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset_eta', ...
    'group','window_bins','n', ...
    'median_practical_error_ratio', ...
    'p90_practical_error_ratio', ...
    'E_le_1_trial_fraction', ...
    'weak_stage_success_rate', ...
    'median_strong_leak_ratio', ...
    'median_weak_projection_loss_ratio', ...
    'median_abs_eta_error_bins', ...
    'p90_abs_eta_error_bins', ...
    'median_abs_residual_epsilon_bins'});

end

%% ========================================================================
function B = summarize_best_practical(S)

modes = unique(string(S.aperture_mode),'stable');
etas = unique(S.fractional_bin_offset_eta).';
groups = unique(string(S.group),'stable');

rows = {};

for im = 1:numel(modes)

    for io = 1:numel(etas)

        for ig = 1:numel(groups)

            M = S( ...
                string(S.aperture_mode)==modes(im) & ...
                abs(S.fractional_bin_offset_eta-etas(io))<1e-12 & ...
                string(S.group)==groups(ig),:);

            [bestE,ib] = min( ...
                M.median_practical_error_ratio);

            [bestFeas,ifz] = max( ...
                M.E_le_1_trial_fraction);

            [bestSucc,is] = max( ...
                M.weak_stage_success_rate);

            rows(end+1,:) = { ... %#ok<AGROW>
                char(modes(im)),etas(io), ...
                char(groups(ig)), ...
                M.window_bins(ib),bestE, ...
                M.p90_practical_error_ratio(ib), ...
                M.E_le_1_trial_fraction(ib), ...
                M.weak_stage_success_rate(ib), ...
                M.median_strong_leak_ratio(ib), ...
                M.median_weak_projection_loss_ratio(ib), ...
                M.median_abs_eta_error_bins(ib), ...
                M.window_bins(ifz),bestFeas, ...
                M.window_bins(is),bestSucc};
        end
    end
end

B = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset_eta', ...
    'group', ...
    'min_error_window_bins', ...
    'minimum_median_error', ...
    'p90_error_at_min_error_window', ...
    'feasible_fraction_at_min_error_window', ...
    'success_at_min_error_window', ...
    'median_strong_leak_at_min_error_window', ...
    'median_weak_loss_at_min_error_window', ...
    'median_abs_eta_error_bins', ...
    'max_feasible_window_bins', ...
    'maximum_E_le_1_trial_fraction', ...
    'max_success_window_bins', ...
    'maximum_weak_stage_success_rate'});

end

%% ========================================================================
function S = summarize_estimators(T)

modes = unique(string(T.aperture_mode),'stable');
etas = unique(T.fractional_bin_offset_eta).';
groups = ["G2_StrongOnlyEstimate","G3_PracticalEstimate"];

rows = {};

for im = 1:numel(modes)

    for io = 1:numel(etas)

        for ig = 1:numel(groups)

            % eta estimates repeat over windows, so keep only L=1 rows.
            M = T( ...
                string(T.aperture_mode)==modes(im) & ...
                abs(T.fractional_bin_offset_eta-etas(io))<1e-12 & ...
                string(T.group)==groups(ig) & ...
                T.window_bins==1,:);

            e = M.eta_error_bins;

            rows(end+1,:) = { ... %#ok<AGROW>
                char(modes(im)),etas(io), ...
                char(groups(ig)), ...
                numel(e), ...
                mean(e), ...
                sqrt(mean(e.^2)), ...
                median(abs(e)), ...
                prctile(abs(e),90), ...
                max(abs(e))};
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset_eta', ...
    'group','n', ...
    'mean_eta_error_bins', ...
    'rmse_eta_error_bins', ...
    'median_abs_eta_error_bins', ...
    'p90_abs_eta_error_bins', ...
    'maximum_abs_eta_error_bins'});

end

%% ========================================================================
function I = summarize_identity(T,cfg)

groups = unique(string(T.group),'stable');

rows = {};

for ig = 1:numel(groups)

    M = T(string(T.group)==groups(ig),:);

    rows(end+1,:) = { ... %#ok<AGROW>
        char(groups(ig)),height(M), ...
        median(M.identity_abs_error), ...
        max(M.identity_abs_error), ...
        double(max(M.identity_abs_error)<= ...
            cfg.dirichlet_identity_gate)};
end

I = cell2table(rows, ...
    'VariableNames',{ ...
    'group','n', ...
    'median_identity_abs_error', ...
    'maximum_identity_abs_error', ...
    'identity_gate_pass'});

end

%% ========================================================================
function S = summarize_improvement(BF,BP)

modes = unique(string(BF.aperture_mode),'stable');
etas = unique(BF.fractional_bin_offset_eta).';

rows = {};

for im = 1:numel(modes)

    for io = 1:numel(etas)

        mode = modes(im);
        eta = etas(io);

        f0 = pick_best_floor(BF,mode,eta,"G0_Baseline");
        f1 = pick_best_floor(BF,mode,eta,"G1_OracleRecenter");
        f2 = pick_best_floor(BF,mode,eta,"G2_StrongOnlyEstimate");

        p0 = pick_best_error(BP,mode,eta,"G0_Baseline");
        p1 = pick_best_error(BP,mode,eta,"G1_OracleRecenter");
        p2 = pick_best_error(BP,mode,eta,"G2_StrongOnlyEstimate");
        p3 = pick_best_error(BP,mode,eta,"G3_PracticalEstimate");

        rows(end+1,:) = { ... %#ok<AGROW>
            char(mode),eta, ...
            f0,f1,f2, ...
            safe_ratio(f1,f0), ...
            safe_ratio(f2,f0), ...
            p0,p1,p2,p3, ...
            safe_ratio(p1,p0), ...
            safe_ratio(p2,p0), ...
            safe_ratio(p3,p0)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','fractional_bin_offset_eta', ...
    'baseline_best_rmin', ...
    'oracle_best_rmin', ...
    'strongOnlyEstimate_best_rmin', ...
    'oracle_to_baseline_rmin_ratio', ...
    'strongOnlyEstimate_to_baseline_rmin_ratio', ...
    'baseline_min_median_error', ...
    'oracle_min_median_error', ...
    'strongOnlyEstimate_min_median_error', ...
    'practicalEstimate_min_median_error', ...
    'oracle_to_baseline_error_ratio', ...
    'strongOnlyEstimate_to_baseline_error_ratio', ...
    'practicalEstimate_to_baseline_error_ratio'});

end

%% ========================================================================
function v = pick_best_floor(B,mode,eta,group)

M = B( ...
    string(B.aperture_mode)==mode & ...
    abs(B.fractional_bin_offset_eta-eta)<1e-12 & ...
    string(B.group)==group,:);

v = M.best_median_rmin(1);

end

%% ========================================================================
function v = pick_best_error(B,mode,eta,group)

M = B( ...
    string(B.aperture_mode)==mode & ...
    abs(B.fractional_bin_offset_eta-eta)<1e-12 & ...
    string(B.group)==group,:);

v = M.minimum_median_error(1);

end

%% ========================================================================
function r = safe_ratio(a,b)

if ~isfinite(a) || ~isfinite(b)
    r = NaN;
elseif abs(b)<=1e-14
    r = double(abs(a)<=1e-14);
else
    r = a/b;
end

end

%% ========================================================================
function D = build_decision_summary( ...
    BF,BP,ES,DS,IS,cfg)

modes = unique(string(BF.aperture_mode),'stable');

rows = {};

for im = 1:numel(modes)

    mode = modes(im);

    identity_pass = all(IS.identity_gate_pass==1);
    dir_pass = all(DS.dirichlet_gate_pass==1);

    % Half-bin mechanism
    b0 = BF( ...
        string(BF.aperture_mode)==mode & ...
        abs(BF.fractional_bin_offset_eta-0.5)<1e-12 & ...
        string(BF.group)=="G0_Baseline",:);

    b1 = BF( ...
        string(BF.aperture_mode)==mode & ...
        abs(BF.fractional_bin_offset_eta-0.5)<1e-12 & ...
        string(BF.group)=="G1_OracleRecenter",:);

    oracle_floor_collapsed = ...
        b1.best_median_L0<=cfg.oracle_leakage_gate && ...
        b1.best_median_rmin<=cfg.oracle_leakage_gate;

    % Strong-only estimator accuracy across nonzero eta
    E2 = ES( ...
        string(ES.aperture_mode)==mode & ...
        string(ES.group)=="G2_StrongOnlyEstimate" & ...
        ES.fractional_bin_offset_eta>0,:);

    e2_rmse = median(E2.rmse_eta_error_bins);

    % Practical half-bin improvement
    p0 = BP( ...
        string(BP.aperture_mode)==mode & ...
        abs(BP.fractional_bin_offset_eta-0.5)<1e-12 & ...
        string(BP.group)=="G0_Baseline",:);

    p3 = BP( ...
        string(BP.aperture_mode)==mode & ...
        abs(BP.fractional_bin_offset_eta-0.5)<1e-12 & ...
        string(BP.group)=="G3_PracticalEstimate",:);

    practical_ratio = ...
        safe_ratio( ...
            p3.minimum_median_error, ...
            p0.minimum_median_error);

    practical_improves = ...
        practical_ratio <= ...
        cfg.practical_halfbin_improvement_ratio_gate;

    if ~identity_pass || ~dir_pass

        branch = "IMPLEMENTATION_OR_ANALYTIC_MODEL_REVIEW";

    elseif ~oracle_floor_collapsed

        branch = "RECENTERING_MECHANISM_HYPOTHESIS_REJECTED";

    elseif e2_rmse<=cfg.estimator_good_rmse_bins && ...
            practical_improves

        branch = ...
            "MECHANISM_VALIDATED_AND_PRACTICAL_RECENTERING_PROMISING";

    elseif e2_rmse<=cfg.estimator_good_rmse_bins && ...
            ~practical_improves

        branch = ...
            "ORACLE_AND_STRONG_ONLY_WORK_BUT_MIXTURE_ESTIMATION_IS_BOTTLENECK";

    else

        branch = ...
            "ORACLE_WORKS_BUT_SUBBIN_ESTIMATION_IS_BOTTLENECK";
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode), ...
        double(identity_pass), ...
        double(dir_pass), ...
        b0.best_median_rmin, ...
        b1.best_median_rmin, ...
        double(oracle_floor_collapsed), ...
        e2_rmse, ...
        practical_ratio, ...
        double(practical_improves), ...
        char(branch)};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode', ...
    'projection_identity_all_pass', ...
    'dirichlet_model_all_pass', ...
    'halfbin_baseline_best_rmin', ...
    'halfbin_oracle_best_rmin', ...
    'halfbin_oracle_floor_collapsed', ...
    'median_nonzeroEta_G2_rmse_bins', ...
    'halfbin_G3_to_G0_minError_ratio', ...
    'halfbin_practical_improves', ...
    'decision_branch'});

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,lambda,R0, ...
    F,BF,ES,BP,DS,IS,D)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5F / Sub-Bin Recentered Fence-Aware Strong Removal\n');
fprintf(fid,'==========================================================\n\n');

fprintf(fid,'Mechanism\n');
fprintf(fid,'---------\n');
fprintf(fid,['eta -> eta_hat -> epsilon -> Dirichlet leakage ' ...
    '-> L0 -> r_min\n\n']);

fprintf(fid,'Physical setup\n');
fprintf(fid,'--------------\n');
fprintf(fid,'lambda=%g m, R0=%g m, PRF=%g Hz\n', ...
    lambda,R0,cfg.prf_hz);
fprintf(fid,'eta=%s bins\n', ...
    mat2str(cfg.fractional_bin_offsets));
fprintf(fid,'windows=%s bins\n', ...
    mat2str(cfg.filter_window_length_bins));
fprintf(fid,'sub-bin estimator=%s\n', ...
    cfg.subbin_estimator);
fprintf(fid,'peak semantics=%s\n\n', ...
    cfg.peak_semantics);

fprintf(fid,'Dirichlet validation\n');
fprintf(fid,'--------------------\n');
for i=1:height(DS)
    fprintf(fid,'%s max |Lmeas-Lmodel|=%g pass=%d\n', ...
        DS.group{i}, ...
        DS.maximum_abs_L0_model_error(i), ...
        DS.dirichlet_gate_pass(i));
end

fprintf(fid,'\nProjection identity\n');
fprintf(fid,'-------------------\n');
for i=1:height(IS)
    fprintf(fid,'%s max identity err=%g pass=%d\n', ...
        IS.group{i}, ...
        IS.maximum_identity_abs_error(i), ...
        IS.identity_gate_pass(i));
end

fprintf(fid,'\nSub-bin estimator summary\n');
fprintf(fid,'-------------------------\n');
for i=1:height(ES)
    fprintf(fid,[ ...
        '%s %s eta=%g RMSE=%g medAbs=%g p90Abs=%g maxAbs=%g\n'], ...
        ES.aperture_mode{i},ES.group{i}, ...
        ES.fractional_bin_offset_eta(i), ...
        ES.rmse_eta_error_bins(i), ...
        ES.median_abs_eta_error_bins(i), ...
        ES.p90_abs_eta_error_bins(i), ...
        ES.maximum_abs_eta_error_bins(i));
end

fprintf(fid,'\nBest floor summary\n');
fprintf(fid,'------------------\n');
for i=1:height(BF)
    fprintf(fid,[ ...
        '%s eta=%g %s L=%d rmin=%g L0=%g D0=%g ' ...
        '|etaErr|=%g\n'], ...
        BF.aperture_mode{i}, ...
        BF.fractional_bin_offset_eta(i), ...
        BF.group{i},BF.best_window_bins(i), ...
        BF.best_median_rmin(i), ...
        BF.best_median_L0(i), ...
        BF.best_median_D0(i), ...
        BF.median_abs_eta_error_bins(i));
end

fprintf(fid,'\nBest practical summary\n');
fprintf(fid,'----------------------\n');
for i=1:height(BP)
    fprintf(fid,[ ...
        '%s eta=%g %s L=%d minMedE=%g feasible=%g success=%g ' ...
        '|etaErr|=%g\n'], ...
        BP.aperture_mode{i}, ...
        BP.fractional_bin_offset_eta(i), ...
        BP.group{i}, ...
        BP.min_error_window_bins(i), ...
        BP.minimum_median_error(i), ...
        BP.feasible_fraction_at_min_error_window(i), ...
        BP.success_at_min_error_window(i), ...
        BP.median_abs_eta_error_bins(i));
end

fprintf(fid,'\nDecision\n');
fprintf(fid,'--------\n');
for i=1:height(D)
    fprintf(fid,'%s -> %s\n', ...
        D.aperture_mode{i}, ...
        D.decision_branch{i});
end

fprintf(fid,'\nInterpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,[ ...
    '1) beta_s is true in PA5F; only sub-bin recentering is tested.\n']);
fprintf(fid,[ ...
    '2) G1 is a mechanism oracle, not a practical algorithm.\n']);
fprintf(fid,[ ...
    '3) G2 isolates estimator bias without weak contamination.\n']);
fprintf(fid,[ ...
    '4) G3 is the deterministic practical mixture estimator.\n']);
fprintf(fid,[ ...
    '5) The analytic strong-leakage model is evaluated using the ACTUAL ' ...
    'binary removal mask from each trial.\n']);
fprintf(fid,[ ...
    '6) Best-over-window summaries are diagnostics; fixed-window tables ' ...
    'remain available for fair operator-by-operator comparison.\n']);
fprintf(fid,[ ...
    '7) Noise and beta_s estimation error remain OFF until the deterministic ' ...
    'recentered method is validated.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,F,BF,P,BP,ES,T,FT)

groups = ["G0_Baseline","G1_OracleRecenter", ...
          "G2_StrongOnlyEstimate","G3_PracticalEstimate"];

floor_groups = groups(1:3);
modes = ["Paper1s","BeamDerived"];

%% Fig 1 — best floor vs fence offset
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(floor_groups),1);

for ig = 1:numel(floor_groups)

    M = BF( ...
        string(BF.aperture_mode)=="BeamDerived" & ...
        string(BF.group)==floor_groups(ig),:);

    [~,o] = sort(M.fractional_bin_offset_eta);
    M = M(o,:);

    h(ig) = plot( ...
        M.fractional_bin_offset_eta, ...
        M.best_median_rmin, ...
        'o-','LineWidth',1.3);
end

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Best median r_{min} over l');
title('EXP009 PA5F — Recentered Recoverability Floor');
legend(h,cellstr(floor_groups(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_best_floor_vs_fence_offset.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — best strong leakage vs fence offset
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(floor_groups),1);

for ig = 1:numel(floor_groups)

    M = BF( ...
        string(BF.aperture_mode)=="BeamDerived" & ...
        string(BF.group)==floor_groups(ig),:);

    [~,o] = sort(M.fractional_bin_offset_eta);
    M = M(o,:);

    h(ig) = plot( ...
        M.fractional_bin_offset_eta, ...
        M.best_median_L0, ...
        'o-','LineWidth',1.3);
end

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Strong leakage L_0 at best-r_{min} window');
title('EXP009 PA5F — Strong-Leakage Suppression by Recentering');
legend(h,cellstr(floor_groups(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_best_L0_vs_fence_offset.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — sub-bin estimator RMSE
fig = figure('Visible',cfg.figure_visible);
hold on;

est_groups = ["G2_StrongOnlyEstimate","G3_PracticalEstimate"];
h = gobjects(numel(est_groups),1);

for ig = 1:numel(est_groups)

    M = ES( ...
        string(ES.aperture_mode)=="BeamDerived" & ...
        string(ES.group)==est_groups(ig),:);

    [~,o] = sort(M.fractional_bin_offset_eta);
    M = M(o,:);

    h(ig) = plot( ...
        M.fractional_bin_offset_eta, ...
        M.rmse_eta_error_bins, ...
        'o-','LineWidth',1.3);
end

xlabel('True fractional-bin offset |\eta|');
ylabel('Sub-bin estimator RMSE (bins)');
title('EXP009 PA5F — Sub-Bin Estimation Accuracy');
legend(h,cellstr(est_groups(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_subbin_estimator_rmse.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — best practical error vs fence offset
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(groups),1);

for ig = 1:numel(groups)

    M = BP( ...
        string(BP.aperture_mode)=="BeamDerived" & ...
        string(BP.group)==groups(ig),:);

    [~,o] = sort(M.fractional_bin_offset_eta);
    M = M(o,:);

    h(ig) = plot( ...
        M.fractional_bin_offset_eta, ...
        M.minimum_median_error, ...
        'o-','LineWidth',1.3);
end

yline(1,':');

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Minimum median ||r-w||/||w|| over l');
title('EXP009 PA5F — Practical Error After Sub-Bin Recentering');
legend(h,cellstr(groups(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig04_best_practical_error_vs_fence.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5 — feasible fraction vs fence offset
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(groups),1);

for ig = 1:numel(groups)

    M = BP( ...
        string(BP.aperture_mode)=="BeamDerived" & ...
        string(BP.group)==groups(ig),:);

    [~,o] = sort(M.fractional_bin_offset_eta);
    M = M(o,:);

    h(ig) = plot( ...
        M.fractional_bin_offset_eta, ...
        M.maximum_E_le_1_trial_fraction, ...
        'o-','LineWidth',1.3);
end

xlabel('Focused fractional-bin offset |\eta|');
ylabel('Maximum E\leq1 trial fraction over l');
title('EXP009 PA5F — Practical Feasible Fraction');
legend(h,cellstr(groups(:)),'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig05_feasible_fraction_vs_fence.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6 — measured vs Dirichlet-predicted strong leakage
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(floor_groups)+1,1);

for ig = 1:numel(floor_groups)

    M = FT(string(FT.group)==floor_groups(ig),:);

    h(ig) = scatter( ...
        M.zero_mismatch_strong_leak_L0, ...
        M.dirichlet_predicted_L0, ...
        24,'filled');
end

mx = max([ ...
    FT.zero_mismatch_strong_leak_L0; ...
    FT.dirichlet_predicted_L0]);

h(end) = plot([0 mx],[0 mx],'k--','LineWidth',1.2);

xlabel('Measured L_0');
ylabel('Dirichlet-predicted L_0');
title('EXP009 PA5F — Finite-Length Leakage Model Validation');

labels = [ ...
    cellstr(floor_groups(:)); ...
    {'y=x'}];

legend(h,labels,'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig06_dirichlet_model_validation.png'), ...
    'Resolution',180);
close(fig);

%% Fig 7 — half-bin floor vs window
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(floor_groups),1);

for ig = 1:numel(floor_groups)

    M = F( ...
        string(F.aperture_mode)=="BeamDerived" & ...
        abs(F.fractional_bin_offset_eta-0.5)<1e-12 & ...
        string(F.group)==floor_groups(ig),:);

    [~,o] = sort(M.window_bins);
    M = M(o,:);

    h(ig) = plot( ...
        M.window_bins, ...
        M.median_recoverability_floor_rmin, ...
        'o-','LineWidth',1.3);
end

xlabel('Window length l (bins)');
ylabel('Median zero-mismatch r_{min}');
title('EXP009 PA5F — Half-Bin Floor vs Window');
legend(h,cellstr(floor_groups(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig07_halfbin_floor_vs_window.png'), ...
    'Resolution',180);
close(fig);

%% Fig 8 — practical eta-estimation error vs contrast at half-bin
fig = figure('Visible',cfg.figure_visible);
hold on;

rvals = unique(T.weak_to_strong_ratio).';
mederr = nan(size(rvals));
p90err = nan(size(rvals));

for i = 1:numel(rvals)

    M = T( ...
        string(T.aperture_mode)=="BeamDerived" & ...
        abs(T.fractional_bin_offset_eta-0.5)<1e-12 & ...
        string(T.group)=="G3_PracticalEstimate" & ...
        abs(T.weak_to_strong_ratio-rvals(i))<1e-12 & ...
        T.window_bins==1,:);

    e = abs(M.eta_error_bins);

    mederr(i) = median(e);
    p90err(i) = prctile(e,90);
end

h = gobjects(2,1);
h(1) = plot(rvals,mederr,'o-','LineWidth',1.3);
h(2) = plot(rvals,p90err,'s--','LineWidth',1.3);

xlabel('A_w/A_s');
ylabel('|\hat{\eta}-\eta| (bins)');
title('EXP009 PA5F — Mixture Sub-Bin Estimation vs Contrast');
legend(h,{'Median','90th percentile'},'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig08_practical_eta_error_vs_contrast.png'), ...
    'Resolution',180);
close(fig);

end
