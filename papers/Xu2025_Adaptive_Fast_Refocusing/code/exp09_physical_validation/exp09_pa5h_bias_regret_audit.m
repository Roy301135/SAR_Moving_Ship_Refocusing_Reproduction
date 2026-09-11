function results = exp09_pa5h_bias_regret_audit()
%EXP09_PA5H_BIAS_REGRET_AUDIT
% EXP009 / PA5H
%
% Mixture-Induced Bias Law and Gate-Regret Audit
%
% This experiment is the final deterministic closure before noise/clutter.
%
% -------------------------------------------------------------------------
% Part A: first-order continuous-ML bias law
% -------------------------------------------------------------------------
%
% After true strong dechirping and removal of the common true eta:
%
%   g[n] = A_s + A_w exp(j*phi) exp(j*pi*Delta_a*n^2)
%
% The concentrated single-tone objective is
%
%   J(delta)
%     = | sum_n g[n] exp(-j*2*pi*delta*n/N) |^2.
%
% Write
%
%   J(delta)
%     = J_s(delta) + J_cross(delta) + J_w(delta).
%
% At delta=0:
%
%   J_s'(0) = 0.
%
% For weak contrast r = Aw/As, first-order stationarity gives
%
%   0 ~= J_s''(0) * delta_mix + J_cross'(0)
%
% hence
%
%   delta_pred
%     ~= - J_cross'(0) / J_s''(0).
%
% In this implementation J_cross is constructed exactly from the known
% strong and weak components, then differentiated numerically at zero.
% Therefore PA5H tests the mechanism law itself, not a new estimator.
%
% -------------------------------------------------------------------------
% Part B: per-trial gate regret
% -------------------------------------------------------------------------
%
% For every physical trial and every removal window:
%
%   E0 = no recenter
%   E3 = always recenter using continuous mixture estimate
%   E4 = PA5G evidence-gated action
%
% Oracle binary action:
%
%   a* = arg min(E0,E3)
%
% Decision regret:
%
%   R = E4 - min(E0,E3).
%
% Metrics:
%   - false recenter:
%       gate=1 while oracle prefers no recenter;
%   - missed recenter:
%       gate=0 while oracle prefers recenter;
%   - action agreement;
%   - median / p90 / max regret;
%   - best-window and fixed-window summaries.
%
% No new estimator or tuned threshold is introduced.
%
% Run:
%   results = exp09_pa5h_bias_regret_audit;

cfg = config_exp09_pa5h_bias_regret_audit();

validate_config_complete(cfg);
run_startup_self_tests(cfg);

%% Output path
this_dir = fileparts(mfilename('fullpath'));
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_physical_validation', ...
        'exp09_pa5h_bias_regret_audit');
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

sides = ["LowV","HighV"];

%% =======================================================================
% PART A — Bias-law trials
% =======================================================================
bias_rows = {};

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
                delta_a = aw-as;

                s0 = synth_discrete_lfm( ...
                    N,cfg.A_strong,as,b,0);

                w_unit = synth_discrete_lfm( ...
                    N,1,aw,b,0);

                for ir = 1:numel( ...
                        cfg.weak_to_strong_ratio)

                    rA = cfg.weak_to_strong_ratio(ir);

                    for ip = 1:numel( ...
                            cfg.relative_phase_rad)

                        phi = cfg.relative_phase_rad(ip);

                        w = ...
                            rA*exp(1j*phi)*w_unit;

                        x = s0+w;

                        [nu_hat,~] = ...
                            estimate_continuous_ml( ...
                                x,as,cfg);

                        eta_hat = fractional_component( ...
                            nu_hat);

                        delta_meas = ...
                            fractional_error(eta_hat,eta);

                        % Remove common true eta before deriving the local
                        % perturbation law. This makes translation
                        % invariance explicit.
                        [s_eta0,~] = ...
                            recenter_signal(s0,eta);

                        [w_eta0,~] = ...
                            recenter_signal(w,eta);

                        [delta_pred,bdiag] = ...
                            first_order_bias_prediction( ...
                                s_eta0,w_eta0,as,cfg);

                        bias_rows(end+1,:) = { ... %#ok<AGROW>
                            char(mode),N,eta,dv, ...
                            char(side),vs, ...
                            as,aw,delta_a, ...
                            rA,phi, ...
                            eta_hat,delta_meas, ...
                            delta_pred, ...
                            delta_meas-delta_pred, ...
                            bdiag.Jstrong_second, ...
                            bdiag.Jcross_first, ...
                            bdiag.Jweak_first, ...
                            bdiag.Jtotal_first, ...
                            bdiag.prediction_valid};
                    end
                end
            end
        end
    end
end

bias_trials = cell2table(bias_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'true_eta_bins','delta_velocity_mps', ...
    'strong_velocity_side','strong_velocity_mps', ...
    'strong_chirp_rate_discrete', ...
    'weak_chirp_rate_discrete', ...
    'delta_chirp_rate_discrete', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'continuous_mix_eta_hat_bins', ...
    'measured_mix_bias_bins', ...
    'first_order_predicted_bias_bins', ...
    'prediction_error_bins', ...
    'Jstrong_second_derivative', ...
    'Jcross_first_derivative', ...
    'Jweak_first_derivative', ...
    'Jtotal_first_derivative', ...
    'prediction_valid'});

writetable(bias_trials, ...
    fullfile(out_path,'pa5h_bias_trials.csv'));

bias_summary = summarize_bias_law( ...
    bias_trials,cfg);

writetable(bias_summary, ...
    fullfile(out_path,'pa5h_bias_summary.csv'));

collapse_summary = summarize_eta_collapse( ...
    bias_trials,cfg);

writetable(collapse_summary, ...
    fullfile(out_path,'pa5h_eta_collapse_summary.csv'));

phase_summary = summarize_bias_by_phase( ...
    bias_trials);

writetable(phase_summary, ...
    fullfile(out_path,'pa5h_bias_by_phase.csv'));

contrast_summary = summarize_bias_by_contrast( ...
    bias_trials);

writetable(contrast_summary, ...
    fullfile(out_path,'pa5h_bias_by_contrast.csv'));

%% =======================================================================
% PART B — Per-trial decision regret
% =======================================================================
regret_rows = {};

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

                for ir = 1:numel( ...
                        cfg.weak_to_strong_ratio)

                    rA = cfg.weak_to_strong_ratio(ir);

                    for ip = 1:numel( ...
                            cfg.relative_phase_rad)

                        phi = cfg.relative_phase_rad(ip);

                        w = ...
                            rA*exp(1j*phi)*w_unit;

                        x = s0+w;

                        [nu_hat,~] = ...
                            estimate_continuous_ml( ...
                                x,as,cfg);

                        eta_mix = ...
                            fractional_component(nu_hat);

                        [gate_diag,split_diag] = ...
                            model_evidence_gate( ...
                                x,as,nu_hat,cfg);

                        gate_action = ...
                            double(gate_diag.primary_gate_trigger);

                        for il = 1:numel( ...
                                cfg.filter_window_length_bins)

                            Lwin = ...
                                cfg.filter_window_length_bins(il);

                            % Action 0: no recenter
                            M0 = evaluate_action( ...
                                x,s0,w,as,aw, ...
                                eta,0,Lwin,cfg);

                            % Action 1: always recenter using mixture ML
                            M1 = evaluate_action( ...
                                x,s0,w,as,aw, ...
                                eta,eta_mix,Lwin,cfg);

                            % Gate action
                            if gate_action==1
                                Mg = M1;
                            else
                                Mg = M0;
                            end

                            % Per-trial oracle action
                            dE = M1.E-M0.E;

                            if abs(dE)<=cfg.action_tie_tolerance
                                oracle_action = 0;
                                oracle_tie = 1;
                            elseif M1.E<M0.E
                                oracle_action = 1;
                                oracle_tie = 0;
                            else
                                oracle_action = 0;
                                oracle_tie = 0;
                            end

                            Eoracle = min(M0.E,M1.E);
                            regret = max(0,Mg.E-Eoracle);

                            false_recenter = ...
                                double(gate_action==1 && ...
                                oracle_action==0 && ...
                                oracle_tie==0);

                            missed_recenter = ...
                                double(gate_action==0 && ...
                                oracle_action==1 && ...
                                oracle_tie==0);

                            action_agree = ...
                                double(gate_action==oracle_action || ...
                                oracle_tie==1);

                            regret_rows(end+1,:) = { ... %#ok<AGROW>
                                char(mode),N,eta,dv, ...
                                char(side),vs,rA,phi,Lwin, ...
                                eta_mix, ...
                                fractional_error(eta_mix,eta), ...
                                gate_action, ...
                                gate_diag.delta_bic, ...
                                split_diag.split_inconsistency_bins, ...
                                M0.E,M1.E,Mg.E,Eoracle, ...
                                M0.weak_success, ...
                                M1.weak_success, ...
                                Mg.weak_success, ...
                                oracle_action,oracle_tie, ...
                                false_recenter, ...
                                missed_recenter, ...
                                action_agree, ...
                                regret, ...
                                M0.Ls,M1.Ls,Mg.Ls, ...
                                M0.Dw,M1.Dw,Mg.Dw};
                        end
                    end
                end
            end
        end
    end
end

regret_trials = cell2table(regret_rows, ...
    'VariableNames',{ ...
    'aperture_mode','azimuth_samples', ...
    'true_eta_bins','delta_velocity_mps', ...
    'strong_velocity_side','strong_velocity_mps', ...
    'weak_to_strong_ratio','relative_phase_rad', ...
    'window_bins','eta_mix_hat_bins', ...
    'eta_mix_error_bins', ...
    'gate_action_recenter', ...
    'delta_bic','split_inconsistency_bins', ...
    'E_no_recenter','E_always_recenter', ...
    'E_gate','E_binary_oracle', ...
    'weak_success_no_recenter', ...
    'weak_success_always_recenter', ...
    'weak_success_gate', ...
    'oracle_action_recenter','oracle_action_tie', ...
    'false_recenter','missed_recenter', ...
    'action_agreement','decision_regret', ...
    'strong_leak_no_recenter', ...
    'strong_leak_always_recenter', ...
    'strong_leak_gate', ...
    'weak_loss_no_recenter', ...
    'weak_loss_always_recenter', ...
    'weak_loss_gate'});

writetable(regret_trials, ...
    fullfile(out_path,'pa5h_regret_trials.csv'));

regret_summary = summarize_regret( ...
    regret_trials);

writetable(regret_summary, ...
    fullfile(out_path,'pa5h_regret_summary.csv'));

regret_by_contrast = ...
    summarize_regret_by_contrast( ...
        regret_trials);

writetable(regret_by_contrast, ...
    fullfile(out_path,'pa5h_regret_by_contrast.csv'));

best_window_regret = ...
    summarize_best_window_regret( ...
        regret_summary);

writetable(best_window_regret, ...
    fullfile(out_path,'pa5h_best_window_regret.csv'));

oracle_action_summary = ...
    summarize_oracle_actions(regret_trials);

writetable(oracle_action_summary, ...
    fullfile(out_path,'pa5h_oracle_action_summary.csv'));

%% Numerical identity audit
identity_summary = ...
    summarize_action_identity( ...
        regret_trials,cfg);

writetable(identity_summary, ...
    fullfile(out_path,'pa5h_identity_summary.csv'));

%% Final deterministic decision
decision_summary = ...
    build_decision_summary( ...
        bias_summary,collapse_summary, ...
        best_window_regret, ...
        identity_summary,cfg);

writetable(decision_summary, ...
    fullfile(out_path,'pa5h_decision_summary.csv'));

%% Text summary
write_summary( ...
    out_path,cfg,lambda,R0, ...
    bias_summary,collapse_summary, ...
    best_window_regret, ...
    oracle_action_summary, ...
    identity_summary,decision_summary);

%% Figures
make_figures( ...
    out_path,cfg, ...
    bias_trials,bias_summary, ...
    collapse_summary,phase_summary, ...
    contrast_summary, ...
    regret_summary, ...
    best_window_regret, ...
    oracle_action_summary);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.R0 = R0;
results.bias_trials = bias_trials;
results.bias_summary = bias_summary;
results.collapse_summary = collapse_summary;
results.phase_summary = phase_summary;
results.contrast_summary = contrast_summary;
results.regret_trials = regret_trials;
results.regret_summary = regret_summary;
results.regret_by_contrast = regret_by_contrast;
results.best_window_regret = best_window_regret;
results.oracle_action_summary = oracle_action_summary;
results.identity_summary = identity_summary;
results.decision_summary = decision_summary;

save(fullfile(out_path,'exp09_pa5h_results.mat'), ...
    'results','-v7.3');

fprintf('\n============================================================\n');
fprintf(' EXP009 PA5H / Mixture Bias Law + Gate Regret Audit\n');
fprintf('============================================================\n');
disp(bias_summary);
disp(collapse_summary);
disp(best_window_regret);
disp(oracle_action_summary);
disp(decision_summary);
fprintf('============================================================\n');
fprintf('Saved to:\n%s\n\n',out_path);

end

%% ========================================================================
function validate_config_complete(cfg)

required = { ...
    'c','fc_hz','prf_hz','bandwidth_hz', ...
    'platform_height_m','antenna_length_m', ...
    'platform_velocity_mps','pulse_width_s', ...
    'slant_range_factor','paper_aperture_time_s', ...
    'beamwidth_scale','weak_velocity_mps', ...
    'delta_velocity_mps','A_strong', ...
    'weak_to_strong_ratio','num_relative_phases', ...
    'relative_phase_rad','fractional_bin_offsets', ...
    'filter_window_length_bins','peak_semantics', ...
    'frac_domain_peak_gate','tie_eps_multiplier', ...
    'ml_search_halfwidth_bins','ml_bracket_points', ...
    'ml_tolx_bins','ml_max_fun_evals', ...
    'bic_k_integer','bic_k_continuous', ...
    'bic_eps_multiplier','split_min_samples', ...
    'bias_derivative_step_bins', ...
    'first_order_small_contrast_max', ...
    'weak_stage_peak_gate', ...
    'weak_stage_center_tolerance_bins', ...
    'error_feasible_threshold','small_norm_floor', ...
    'action_tie_tolerance','identity_gate', ...
    'eta_translation_collapse_gate_bins', ...
    'figure_visible','output_dir'};

missing = required(~isfield(cfg,required));

if ~isempty(missing)
    error('EXP009:PA5H:MissingConfigField', ...
        'Missing config field(s): %s', ...
        strjoin(missing,', '));
end

end

%% ========================================================================
function run_startup_self_tests(cfg)
% Test continuous estimator translation invariance and first-order bias law
% in a small-contrast deterministic synthetic case.

N = 188;
aS = 0.0017;
aW = 0.0022;
rA = 0.1;
phi = 0.7;

biases = zeros(size(cfg.fractional_bin_offsets));

for i = 1:numel(cfg.fractional_bin_offsets)

    eta = cfg.fractional_bin_offsets(i);

    s = synth_discrete_lfm( ...
        N,1,aS,eta/N,0);

    w = synth_discrete_lfm( ...
        N,rA,aW,eta/N,phi);

    x = s+w;

    [nu,~] = estimate_continuous_ml( ...
        x,aS,cfg);

    eta_hat = fractional_component(nu);

    biases(i) = ...
        fractional_error(eta_hat,eta);
end

if max(biases)-min(biases) > ...
        cfg.eta_translation_collapse_gate_bins

    error('EXP009:PA5H:TranslationSelfTestFailed', ...
        ['Mixture bias failed translation-invariance self-test. ' ...
         'Spread=%g bins.'], ...
        max(biases)-min(biases));
end

% First-order law must at least have the correct sign and finite value.
eta = 0.25;

s = synth_discrete_lfm( ...
    N,1,aS,eta/N,0);

w = synth_discrete_lfm( ...
    N,rA,aW,eta/N,phi);

[s0,~] = recenter_signal(s,eta);
[w0,~] = recenter_signal(w,eta);

[dp,diag] = first_order_bias_prediction( ...
    s0,w0,aS,cfg);

x = s+w;

[nu,~] = estimate_continuous_ml( ...
    x,aS,cfg);

dm = fractional_error( ...
    fractional_component(nu),eta);

if ~diag.prediction_valid || ...
        ~isfinite(dp) || ...
        sign(dp)~=sign(dm)

    error('EXP009:PA5H:BiasLawSelfTestFailed', ...
        ['First-order bias-law self-test failed. ' ...
         'Measured=%g, predicted=%g.'],dm,dp);
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
function z = dechirp_signal(x,a)

x = x(:).';

N = numel(x);
m = 0:N-1;

z = x.*exp(-1j*pi*a*m.^2);

end

%% ========================================================================
function Y = matched_lfm_transform(x,a)

z = dechirp_signal(x,a);

Y = fftshift(fft(z))/sqrt(numel(z));

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
function [nu_hat,diag] = estimate_continuous_ml(x,a,cfg)

z = dechirp_signal(x,a);

N = numel(z);
m = 0:N-1;

Y = fftshift(fft(z));
[~,i0] = max(abs(Y));

dc = floor(N/2)+1;
k0 = i0-dc;

[nu_hat,Jhat] = ...
    refine_continuous_frequency( ...
        z,m,N,k0,cfg);

Jint = ...
    tone_objective(z,m,N,round(nu_hat));

diag = struct();
diag.coarse_integer_bin = k0;
diag.objective_at_hat = Jhat;
diag.objective_at_integer = Jint;
diag.objective_gain_vs_integer = ...
    (Jhat-Jint)/max(Jhat,cfg.small_norm_floor);

end

%% ========================================================================
function [nu_hat,Jhat] = ...
    refine_continuous_frequency(z,m,N,center,cfg)

z = z(:).';
m = m(:).';

lb = center-cfg.ml_search_halfwidth_bins;
ub = center+cfg.ml_search_halfwidth_bins;

grid = linspace( ...
    lb,ub,cfg.ml_bracket_points);

J = zeros(size(grid));

for i = 1:numel(grid)
    J(i) = tone_objective( ...
        z,m,N,grid(i));
end

[~,ib] = max(J);

i1 = max(1,ib-1);
i2 = min(numel(grid),ib+1);

local_lb = grid(i1);
local_ub = grid(i2);

if local_ub<=local_lb
    nu_hat = grid(ib);
    Jhat = J(ib);
    return;
end

opts = optimset( ...
    'Display','off', ...
    'TolX',cfg.ml_tolx_bins, ...
    'MaxFunEvals',cfg.ml_max_fun_evals);

obj = @(nu) -tone_objective( ...
    z,m,N,nu);

[nu_hat,fval] = ...
    fminbnd(obj,local_lb,local_ub,opts);

Jhat = -fval;

end

%% ========================================================================
function J = tone_objective(z,m,N,nu)

v = exp(-1j*2*pi*nu*m/N);

q = sum(z.*v);

J = abs(q).^2;

end

%% ========================================================================
function [delta_pred,diag] = ...
    first_order_bias_prediction(s,w,aS,cfg)
% First-order perturbation:
%
%   delta ~= - Jcross'(0) / Jstrong''(0)
%
% Strong and weak components are assumed to have had the common true eta
% removed before entering this function.

zs = dechirp_signal(s,aS);
zw = dechirp_signal(w,aS);

N = numel(zs);
m = 0:N-1;

h = cfg.bias_derivative_step_bins;

% Component objectives
Js = @(d) abs(sum(zs .* exp(-1j*2*pi*d*m/N))).^2;
Jw = @(d) abs(sum(zw .* exp(-1j*2*pi*d*m/N))).^2;

% Cross term in |S+W|^2:
%   2 Re{ S(d) conj(W(d)) }.
Jc = @(d) cross_objective(zs,zw,m,N,d);

Jt = @(d) Js(d)+Jc(d)+Jw(d);

Js_p = Js(h);
Js_0 = Js(0);
Js_m = Js(-h);

Jc_p = Jc(h);
Jc_m = Jc(-h);

Jw_p = Jw(h);
Jw_m = Jw(-h);

Jt_p = Jt(h);
Jt_m = Jt(-h);

Js_second = ...
    (Js_p-2*Js_0+Js_m)/(h^2);

Jc_first = ...
    (Jc_p-Jc_m)/(2*h);

Jw_first = ...
    (Jw_p-Jw_m)/(2*h);

Jt_first = ...
    (Jt_p-Jt_m)/(2*h);

valid = ...
    isfinite(Js_second) && ...
    abs(Js_second)> ...
    cfg.small_norm_floor;

if valid
    delta_pred = -Jc_first/Js_second;
else
    delta_pred = NaN;
end

diag = struct();
diag.Jstrong_second = Js_second;
diag.Jcross_first = Jc_first;
diag.Jweak_first = Jw_first;
diag.Jtotal_first = Jt_first;
diag.prediction_valid = double(valid);

end

%% ========================================================================
function Jc = cross_objective(zs,zw,m,N,d)

ph = exp(-1j*2*pi*d*m/N);

S = sum(zs.*ph);
W = sum(zw.*ph);

Jc = 2*real(S*conj(W));

end

%% ========================================================================
function [gate,split] = ...
    model_evidence_gate(x,a,nu_hat,cfg)

z = dechirp_signal(x,a);

N = numel(z);
m = 0:N-1;

nu_int = round(nu_hat);

[rss0,~] = tone_fit_rss( ...
    z,m,N,nu_int);

[rss1,~] = tone_fit_rss( ...
    z,m,N,nu_hat);

energy = real(sum(abs(z).^2));

rss_floor = ...
    cfg.bic_eps_multiplier * ...
    N * eps(max(energy,1));

rss0b = max(rss0,rss_floor);
rss1b = max(rss1,rss_floor);

bic0 = ...
    N*log(rss0b/N) + ...
    cfg.bic_k_integer*log(N);

bic1 = ...
    N*log(rss1b/N) + ...
    cfg.bic_k_continuous*log(N);

delta_bic = bic0-bic1;

split = split_aperture_diagnostic( ...
    z,m,N,nu_hat,cfg);

frac = fractional_component(nu_hat);

gate = struct();
gate.nu_integer_bins = nu_int;
gate.rss_integer = rss0;
gate.rss_continuous = rss1;
gate.bic_integer = bic0;
gate.bic_continuous = bic1;
gate.delta_bic = delta_bic;
gate.bic_prefers_continuous = delta_bic>0;
gate.shift_exceeds_split = ...
    abs(frac)>split.split_inconsistency_bins;
gate.primary_gate_trigger = ...
    gate.bic_prefers_continuous && ...
    gate.shift_exceeds_split;

% Mirror split fields into gate as a defensive interface contract.
gate.nu_left_bins = split.nu_left_bins;
gate.nu_right_bins = split.nu_right_bins;
gate.split_inconsistency_bins = ...
    split.split_inconsistency_bins;

end

%% ========================================================================
function [rss,c_hat] = ...
    tone_fit_rss(z,m,N,nu)

z = z(:).';
m = m(:).';

avec = exp(1j*2*pi*nu*m/N);

den = sum(abs(avec).^2);

c_hat = ...
    sum(conj(avec).*z) / ...
    max(den,eps);

e = z-c_hat*avec;

rss = real(sum(abs(e).^2));

end

%% ========================================================================
function S = ...
    split_aperture_diagnostic( ...
        z,m,N,nu_full,cfg)

n = numel(z);

if n<cfg.split_min_samples
    S = struct();
    S.nu_left_bins = NaN;
    S.nu_right_bins = NaN;
    S.split_inconsistency_bins = Inf;
    return;
end

nL = floor(n/2);

idxL = 1:nL;
idxR = (nL+1):n;

[nuL,~] = ...
    refine_continuous_frequency( ...
        z(idxL),m(idxL),N, ...
        nu_full,cfg);

[nuR,~] = ...
    refine_continuous_frequency( ...
        z(idxR),m(idxR),N, ...
        nu_full,cfg);

S = struct();
S.nu_left_bins = nuL;
S.nu_right_bins = nuR;
S.split_inconsistency_bins = ...
    abs(fractional_error(nuL,nuR));

end

%% ========================================================================
function f = fractional_component(nu)

f = nu-round(nu);

end

%% ========================================================================
function e = fractional_error(a,b)

e = mod((a-b)+0.5,1)-0.5;

end

%% ========================================================================
function [xr,phase] = recenter_signal(x,eta_used)

x = x(:).';

N = numel(x);
m = 0:N-1;

phase = ...
    exp(-1j*2*pi*eta_used*m/N);

xr = x.*phase;

end

%% ========================================================================
function M = evaluate_action( ...
    x,s,w,aS,aW,eta_true,eta_used,Lwin,cfg)

[xr,~] = recenter_signal(x,eta_used);
[sr0,~] = recenter_signal(s,eta_used);
[wr0,~] = recenter_signal(w,eta_used);

Yx = matched_lfm_transform(xr,aS);

[mask,~] = ...
    build_plateau_tol_mask( ...
        Yx,Lwin,cfg);

residual = remove_with_mask( ...
    xr,aS,mask);

E = ...
    norm(residual-wr0) / ...
    max(norm(wr0),cfg.small_norm_floor);

[sleak,wloss] = ...
    apply_fixed_mask_components( ...
        sr0,wr0,aS,mask);

Ls = ...
    norm(sleak) / ...
    max(norm(sr0),cfg.small_norm_floor);

Dw = ...
    norm(wloss) / ...
    max(norm(wr0),cfg.small_norm_floor);

bweak_after = ...
    (eta_true-eta_used)/numel(x);

[weak_ok,weak_ratio] = ...
    weak_stage_readiness( ...
        residual,aW, ...
        bweak_after,cfg);

M = struct();
M.E = E;
M.Ls = Ls;
M.Dw = Dw;
M.weak_success = double(weak_ok);
M.weak_peak_ratio = weak_ratio;

end

%% ========================================================================
function [mask,info] = ...
    build_plateau_tol_mask(Y,Lwin,cfg)

amp = abs(Y(:).');
N = numel(amp);

amax = max(amp);
gate = cfg.frac_domain_peak_gate*amax;

tol = ...
    cfg.tie_eps_multiplier * ...
    N * eps(max(amax,1));

centers = ...
    plateau_aware_tol( ...
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
function pk = ...
    plateau_aware_tol(amp,gate,tol)

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

    ge_left = amp(i)>=amp(i-1)-tol;
    ge_right = amp(i)>=amp(i+1)-tol;

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

ext = ...
    inverse_matched_lfm_transform( ...
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
function S = summarize_bias_law(T,cfg)

modes = unique(string(T.aperture_mode),'stable');
ratios = unique(T.weak_to_strong_ratio).';

rows = {};

for im = 1:numel(modes)

    for ir = 1:numel(ratios)

        M = T( ...
            string(T.aperture_mode)==modes(im) & ...
            abs(T.weak_to_strong_ratio-ratios(ir))<1e-12,:);

        valid = M.prediction_valid==1 & ...
            isfinite(M.first_order_predicted_bias_bins);

        Mv = M(valid,:);

        if isempty(Mv)
            rmse = NaN;
            mae = NaN;
            corrv = NaN;
            slope = NaN;
            r2 = NaN;
        else
            err = ...
                Mv.measured_mix_bias_bins - ...
                Mv.first_order_predicted_bias_bins;

            rmse = sqrt(mean(err.^2));
            mae = median(abs(err));

            x = Mv.first_order_predicted_bias_bins;
            y = Mv.measured_mix_bias_bins;

            corrv = safe_corr(x,y);
            [slope,~,r2] = linear_fit_no_intercept(x,y);
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),ratios(ir),height(Mv), ...
            rmse,mae,corrv,slope,r2, ...
            double(ratios(ir)<= ...
                cfg.first_order_small_contrast_max)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','weak_to_strong_ratio','n_valid', ...
    'prediction_rmse_bins', ...
    'prediction_median_abs_error_bins', ...
    'prediction_correlation', ...
    'measured_vs_predicted_slope', ...
    'measured_vs_predicted_R2', ...
    'small_contrast_regime'});

end

%% ========================================================================
function S = summarize_eta_collapse(T,cfg)

modes = unique(string(T.aperture_mode),'stable');
ratios = unique(T.weak_to_strong_ratio).';

rows = {};

for im = 1:numel(modes)

    for ir = 1:numel(ratios)

        M = T( ...
            string(T.aperture_mode)==modes(im) & ...
            abs(T.weak_to_strong_ratio-ratios(ir))<1e-12,:);

        % For each fixed physical state except eta, quantify spread over eta.
        dvvals = unique(M.delta_velocity_mps).';
        sidevals = unique(string(M.strong_velocity_side),'stable');
        phivals = unique(M.relative_phase_rad).';

        spreads = [];

        for idv = 1:numel(dvvals)
            for isd = 1:numel(sidevals)
                for ip = 1:numel(phivals)

                    Q = M( ...
                        abs(M.delta_velocity_mps-dvvals(idv))<1e-12 & ...
                        string(M.strong_velocity_side)==sidevals(isd) & ...
                        abs(M.relative_phase_rad-phivals(ip))<1e-12,:);

                    if height(Q)>=2
                        spreads(end+1,1) = ... %#ok<AGROW>
                            max(Q.measured_mix_bias_bins) - ...
                            min(Q.measured_mix_bias_bins);
                    end
                end
            end
        end

        if isempty(spreads)
            medspread = NaN;
            maxspread = NaN;
        else
            medspread = median(abs(spreads));
            maxspread = max(abs(spreads));
        end

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),ratios(ir), ...
            numel(spreads), ...
            medspread,maxspread, ...
            double(maxspread<= ...
                cfg.eta_translation_collapse_gate_bins)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','weak_to_strong_ratio', ...
    'n_physical_state_groups', ...
    'median_eta_collapse_spread_bins', ...
    'maximum_eta_collapse_spread_bins', ...
    'strict_translation_collapse_pass'});

end

%% ========================================================================
function S = summarize_bias_by_phase(T)

modes = unique(string(T.aperture_mode),'stable');
phases = unique(T.relative_phase_rad).';

rows = {};

for im = 1:numel(modes)

    for ip = 1:numel(phases)

        M = T( ...
            string(T.aperture_mode)==modes(im) & ...
            abs(T.relative_phase_rad-phases(ip))<1e-12,:);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),phases(ip),height(M), ...
            median(M.measured_mix_bias_bins), ...
            median(M.first_order_predicted_bias_bins), ...
            median(abs(M.prediction_error_bins))};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','relative_phase_rad','n', ...
    'median_measured_bias_bins', ...
    'median_predicted_bias_bins', ...
    'median_abs_prediction_error_bins'});

end

%% ========================================================================
function S = summarize_bias_by_contrast(T)

modes = unique(string(T.aperture_mode),'stable');
ratios = unique(T.weak_to_strong_ratio).';

rows = {};

for im = 1:numel(modes)

    for ir = 1:numel(ratios)

        M = T( ...
            string(T.aperture_mode)==modes(im) & ...
            abs(T.weak_to_strong_ratio-ratios(ir))<1e-12,:);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),ratios(ir),height(M), ...
            median(abs(M.measured_mix_bias_bins)), ...
            local_percentile( ...
                abs(M.measured_mix_bias_bins),90), ...
            median(abs(M.first_order_predicted_bias_bins)), ...
            median(abs(M.prediction_error_bins))};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','weak_to_strong_ratio','n', ...
    'median_abs_measured_bias_bins', ...
    'p90_abs_measured_bias_bins', ...
    'median_abs_predicted_bias_bins', ...
    'median_abs_prediction_error_bins'});

end

%% ========================================================================
function S = summarize_regret(T)

modes = unique(string(T.aperture_mode),'stable');
etas = unique(T.true_eta_bins).';
wins = unique(T.window_bins).';

rows = {};

for im = 1:numel(modes)

    for ie = 1:numel(etas)

        for iw = 1:numel(wins)

            M = T( ...
                string(T.aperture_mode)==modes(im) & ...
                abs(T.true_eta_bins-etas(ie))<1e-12 & ...
                T.window_bins==wins(iw),:);

            nontie = M.oracle_action_tie==0;

            rows(end+1,:) = { ... %#ok<AGROW>
                char(modes(im)),etas(ie),wins(iw), ...
                height(M), ...
                mean(M.gate_action_recenter), ...
                mean(M.oracle_action_recenter), ...
                mean(M.action_agreement), ...
                mean(M.false_recenter(nontie)), ...
                mean(M.missed_recenter(nontie)), ...
                median(M.decision_regret), ...
                local_percentile(M.decision_regret,90), ...
                max(M.decision_regret), ...
                mean(M.decision_regret), ...
                median(M.E_no_recenter), ...
                median(M.E_always_recenter), ...
                median(M.E_gate), ...
                median(M.E_binary_oracle)};
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','true_eta_bins','window_bins','n', ...
    'gate_recenter_rate','oracle_recenter_rate', ...
    'action_agreement_rate', ...
    'false_recenter_rate','missed_recenter_rate', ...
    'median_decision_regret','p90_decision_regret', ...
    'maximum_decision_regret','mean_decision_regret', ...
    'median_E_no_recenter','median_E_always_recenter', ...
    'median_E_gate','median_E_binary_oracle'});

end

%% ========================================================================
function S = summarize_regret_by_contrast(T)

modes = unique(string(T.aperture_mode),'stable');
etas = unique(T.true_eta_bins).';
ratios = unique(T.weak_to_strong_ratio).';

rows = {};

for im = 1:numel(modes)

    for ie = 1:numel(etas)

        for ir = 1:numel(ratios)

            M = T( ...
                string(T.aperture_mode)==modes(im) & ...
                abs(T.true_eta_bins-etas(ie))<1e-12 & ...
                abs(T.weak_to_strong_ratio-ratios(ir))<1e-12,:);

            nontie = M.oracle_action_tie==0;

            rows(end+1,:) = { ... %#ok<AGROW>
                char(modes(im)),etas(ie),ratios(ir), ...
                height(M), ...
                mean(M.action_agreement), ...
                mean(M.false_recenter(nontie)), ...
                mean(M.missed_recenter(nontie)), ...
                median(M.decision_regret), ...
                local_percentile(M.decision_regret,90), ...
                mean(M.gate_action_recenter), ...
                mean(M.oracle_action_recenter)};
        end
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','true_eta_bins', ...
    'weak_to_strong_ratio','n', ...
    'action_agreement_rate', ...
    'false_recenter_rate','missed_recenter_rate', ...
    'median_decision_regret','p90_decision_regret', ...
    'gate_recenter_rate','oracle_recenter_rate'});

end

%% ========================================================================
function B = summarize_best_window_regret(S)

modes = unique(string(S.aperture_mode),'stable');
etas = unique(S.true_eta_bins).';

rows = {};

for im = 1:numel(modes)

    for ie = 1:numel(etas)

        M = S( ...
            string(S.aperture_mode)==modes(im) & ...
            abs(S.true_eta_bins-etas(ie))<1e-12,:);

        [bestReg,ib] = min( ...
            M.median_decision_regret);

        [bestAgree,ia] = max( ...
            M.action_agreement_rate);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),etas(ie), ...
            M.window_bins(ib),bestReg, ...
            M.p90_decision_regret(ib), ...
            M.mean_decision_regret(ib), ...
            M.false_recenter_rate(ib), ...
            M.missed_recenter_rate(ib), ...
            M.action_agreement_rate(ib), ...
            M.median_E_gate(ib), ...
            M.median_E_binary_oracle(ib), ...
            M.window_bins(ia),bestAgree};
    end
end

B = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','true_eta_bins', ...
    'min_regret_window_bins', ...
    'minimum_median_decision_regret', ...
    'p90_regret_at_min_regret_window', ...
    'mean_regret_at_min_regret_window', ...
    'false_recenter_at_min_regret_window', ...
    'missed_recenter_at_min_regret_window', ...
    'action_agreement_at_min_regret_window', ...
    'median_E_gate_at_min_regret_window', ...
    'median_E_oracle_at_min_regret_window', ...
    'max_agreement_window_bins', ...
    'maximum_action_agreement_rate'});

end

%% ========================================================================
function S = summarize_oracle_actions(T)

modes = unique(string(T.aperture_mode),'stable');
etas = unique(T.true_eta_bins).';

rows = {};

for im = 1:numel(modes)

    for ie = 1:numel(etas)

        M = T( ...
            string(T.aperture_mode)==modes(im) & ...
            abs(T.true_eta_bins-etas(ie))<1e-12,:);

        rows(end+1,:) = { ... %#ok<AGROW>
            char(modes(im)),etas(ie),height(M), ...
            mean(M.oracle_action_recenter), ...
            mean(M.gate_action_recenter), ...
            mean(M.action_agreement), ...
            mean(M.false_recenter), ...
            mean(M.missed_recenter), ...
            median(M.decision_regret), ...
            local_percentile(M.decision_regret,90)};
    end
end

S = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode','true_eta_bins','n', ...
    'oracle_recenter_rate','gate_recenter_rate', ...
    'action_agreement_rate', ...
    'false_recenter_rate','missed_recenter_rate', ...
    'median_decision_regret','p90_decision_regret'});

end

%% ========================================================================
function I = summarize_action_identity(T,cfg)
% Check consistency:
%   E_gate must exactly equal E0 when gate=0
%   E_gate must exactly equal E1 when gate=1

err = zeros(height(T),1);

for i = 1:height(T)

    if T.gate_action_recenter(i)==1
        err(i) = abs( ...
            T.E_gate(i)- ...
            T.E_always_recenter(i));
    else
        err(i) = abs( ...
            T.E_gate(i)- ...
            T.E_no_recenter(i));
    end
end

I = table( ...
    median(err),max(err), ...
    double(max(err)<=cfg.identity_gate), ...
    'VariableNames',{ ...
    'median_gate_action_identity_error', ...
    'maximum_gate_action_identity_error', ...
    'identity_gate_pass'});

end

%% ========================================================================
function D = build_decision_summary( ...
    BS,CS,BW,IS,cfg)

modes = unique(string(BS.aperture_mode),'stable');

rows = {};

for im = 1:numel(modes)

    mode = modes(im);

    B = BS(string(BS.aperture_mode)==mode,:);
    C = CS(string(CS.aperture_mode)==mode,:);
    W = BW(string(BW.aperture_mode)==mode,:);

    small = B( ...
        B.small_contrast_regime==1,:);

    if isempty(small)
        small_r2 = NaN;
        small_slope = NaN;
    else
        small_r2 = median( ...
            small.measured_vs_predicted_R2, ...
            'omitnan');
        small_slope = median( ...
            small.measured_vs_predicted_slope, ...
            'omitnan');
    end

    collapse_max = max( ...
        C.maximum_eta_collapse_spread_bins);

    identity_pass = ...
        IS.identity_gate_pass(1)==1;

    med_reg = median( ...
        W.minimum_median_decision_regret);

    p90_reg = median( ...
        W.p90_regret_at_min_regret_window);

    med_agree = median( ...
        W.action_agreement_at_min_regret_window);

    if ~identity_pass

        branch = "IMPLEMENTATION_IDENTITY_REVIEW";

    elseif collapse_max > ...
            cfg.eta_translation_collapse_gate_bins

        branch = "TRANSLATION_INVARIANCE_MODEL_REVIEW";

    elseif small_r2>=0.8 && ...
            abs(small_slope-1)<=0.3 && ...
            med_agree>=0.8 && ...
            p90_reg<=0.1

        branch = ...
            "DETERMINISTIC_CLOSURE_ACHIEVED_READY_FOR_REALISTIC_ERRORS";

    elseif small_r2>=0.8 && ...
            abs(small_slope-1)<=0.3

        branch = ...
            "BIAS_LAW_VALIDATED_GATE_REGRET_REMAINS_NONTRIVIAL";

    else

        branch = ...
            "FIRST_ORDER_BIAS_LAW_ONLY_PARTIALLY_VALID";
    end

    rows(end+1,:) = { ... %#ok<AGROW>
        char(mode),identity_pass, ...
        small_r2,small_slope, ...
        collapse_max, ...
        med_reg,p90_reg,med_agree, ...
        char(branch)};
end

D = cell2table(rows, ...
    'VariableNames',{ ...
    'aperture_mode', ...
    'implementation_identity_pass', ...
    'small_contrast_median_bias_R2', ...
    'small_contrast_median_bias_slope', ...
    'maximum_eta_collapse_spread_bins', ...
    'median_bestwindow_decision_regret', ...
    'median_p90_bestwindow_regret', ...
    'median_bestwindow_action_agreement', ...
    'decision_branch'});

end

%% ========================================================================
function [slope,intercept,r2] = ...
    linear_fit_no_intercept(x,y)

x = x(:);
y = y(:);

den = sum(x.^2);

if den<=eps
    slope = NaN;
    intercept = 0;
    r2 = NaN;
    return;
end

slope = sum(x.*y)/den;
intercept = 0;

yhat = slope*x;

ssres = sum((y-yhat).^2);
sstot = sum((y-mean(y)).^2);

if sstot<=eps
    r2 = double(ssres<=eps);
else
    r2 = 1-ssres/sstot;
end

end

%% ========================================================================
function c = safe_corr(x,y)

x = x(:);
y = y(:);

if numel(x)<2 || std(x)<=eps || std(y)<=eps
    c = NaN;
    return;
end

C = corrcoef(x,y);

c = C(1,2);

end

%% ========================================================================
function q = local_percentile(x,p)

x = sort(x(:));
x = x(isfinite(x));

if isempty(x)
    q = NaN;
    return;
end

if numel(x)==1
    q = x;
    return;
end

r = 1 + (p/100)*(numel(x)-1);

i1 = floor(r);
i2 = ceil(r);

if i1==i2
    q = x(i1);
else
    w = r-i1;
    q = (1-w)*x(i1)+w*x(i2);
end

end

%% ========================================================================
function write_summary( ...
    out_path,cfg,lambda,R0, ...
    BS,CS,BW,OA,IS,D)

fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 PA5H / Mixture Bias Law + Gate Regret Audit\n');
fprintf(fid,'=================================================\n\n');

fprintf(fid,'Purpose\n');
fprintf(fid,'-------\n');
fprintf(fid,['Final deterministic closure before realistic error sources.\n']);
fprintf(fid,['A) validate first-order mixture-induced continuous-ML bias law.\n']);
fprintf(fid,['B) quantify evidence-gate decision regret vs a per-trial ' ...
    'binary oracle.\n\n']);

fprintf(fid,'Physical setup\n');
fprintf(fid,'--------------\n');
fprintf(fid,'lambda=%g m, R0=%g m, PRF=%g Hz\n', ...
    lambda,R0,cfg.prf_hz);
fprintf(fid,'eta=%s bins\n', ...
    mat2str(cfg.fractional_bin_offsets));
fprintf(fid,'Aw/As=%s\n', ...
    mat2str(cfg.weak_to_strong_ratio));
fprintf(fid,'windows=%s bins\n\n', ...
    mat2str(cfg.filter_window_length_bins));

fprintf(fid,'Bias-law summary\n');
fprintf(fid,'----------------\n');
for i=1:height(BS)
    fprintf(fid,[ ...
        '%s r=%g RMSE=%g slope=%g R2=%g small=%d\n'], ...
        BS.aperture_mode{i}, ...
        BS.weak_to_strong_ratio(i), ...
        BS.prediction_rmse_bins(i), ...
        BS.measured_vs_predicted_slope(i), ...
        BS.measured_vs_predicted_R2(i), ...
        BS.small_contrast_regime(i));
end

fprintf(fid,'\nEta-collapse summary\n');
fprintf(fid,'--------------------\n');
for i=1:height(CS)
    fprintf(fid,[ ...
        '%s r=%g medSpread=%g maxSpread=%g strictPass=%d\n'], ...
        CS.aperture_mode{i}, ...
        CS.weak_to_strong_ratio(i), ...
        CS.median_eta_collapse_spread_bins(i), ...
        CS.maximum_eta_collapse_spread_bins(i), ...
        CS.strict_translation_collapse_pass(i));
end

fprintf(fid,'\nBest-window regret\n');
fprintf(fid,'------------------\n');
for i=1:height(BW)
    fprintf(fid,[ ...
        '%s eta=%g L=%d medR=%g p90R=%g agree=%g ' ...
        'false=%g miss=%g\n'], ...
        BW.aperture_mode{i}, ...
        BW.true_eta_bins(i), ...
        BW.min_regret_window_bins(i), ...
        BW.minimum_median_decision_regret(i), ...
        BW.p90_regret_at_min_regret_window(i), ...
        BW.action_agreement_at_min_regret_window(i), ...
        BW.false_recenter_at_min_regret_window(i), ...
        BW.missed_recenter_at_min_regret_window(i));
end

fprintf(fid,'\nOracle-action summary\n');
fprintf(fid,'---------------------\n');
for i=1:height(OA)
    fprintf(fid,[ ...
        '%s eta=%g oracleRec=%g gateRec=%g agree=%g ' ...
        'medR=%g p90R=%g\n'], ...
        OA.aperture_mode{i}, ...
        OA.true_eta_bins(i), ...
        OA.oracle_recenter_rate(i), ...
        OA.gate_recenter_rate(i), ...
        OA.action_agreement_rate(i), ...
        OA.median_decision_regret(i), ...
        OA.p90_decision_regret(i));
end

fprintf(fid,'\nIdentity\n');
fprintf(fid,'--------\n');
fprintf(fid,'max gate-action identity err=%g pass=%d\n', ...
    IS.maximum_gate_action_identity_error(1), ...
    IS.identity_gate_pass(1));

fprintf(fid,'\nDecision\n');
fprintf(fid,'--------\n');
for i=1:height(D)
    fprintf(fid,'%s -> %s\n', ...
        D.aperture_mode{i}, ...
        D.decision_branch{i});
end

fprintf(fid,'\nInterpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) PA5H adds no new estimator.\n']);
fprintf(fid,['2) The first-order law is tested against the SAME continuous ML ' ...
    'bias measured in PA5G-style mixtures.\n']);
fprintf(fid,['3) Gate regret is evaluated per trial; it is not a group-median ' ...
    'surrogate.\n']);
fprintf(fid,['4) No gate threshold is tuned in PA5H.\n']);
fprintf(fid,['5) If deterministic closure is adequate, PA5H ends PA5 and the ' ...
    'next stage must add realistic error sources rather than continue ' ...
    'micro-tuning the gate.\n']);

fclose(fid);

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,BT,BS,CS,PS,CTS,RS,BW,OA)

%% Fig 1 — measured vs predicted first-order bias
fig = figure('Visible',cfg.figure_visible);
hold on;

modes = ["Paper1s","BeamDerived"];
h = gobjects(numel(modes)+1,1);

for im = 1:numel(modes)

    M = BT( ...
        string(BT.aperture_mode)==modes(im) & ...
        BT.weak_to_strong_ratio<= ...
            cfg.first_order_small_contrast_max,:);

    h(im) = scatter( ...
        M.first_order_predicted_bias_bins, ...
        M.measured_mix_bias_bins, ...
        22,'filled');
end

lims = local_symmetric_limits( ...
    [BT.first_order_predicted_bias_bins; ...
     BT.measured_mix_bias_bins]);

h(end) = plot(lims,lims,'k--','LineWidth',1.2);

xlabel('First-order predicted \delta_{mix} (bins)');
ylabel('Measured continuous-ML bias (bins)');
title('EXP009 PA5H — First-Order Mixture-Bias Law');
legend(h,[cellstr(modes(:));{'y=x'}], ...
    'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig01_measured_vs_predicted_bias.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2 — prediction R2 vs contrast
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(modes),1);

for im = 1:numel(modes)

    M = BS(string(BS.aperture_mode)==modes(im),:);
    [~,o] = sort(M.weak_to_strong_ratio);
    M = M(o,:);

    h(im) = plot( ...
        M.weak_to_strong_ratio, ...
        M.measured_vs_predicted_R2, ...
        'o-','LineWidth',1.3);
end

xlabel('A_w/A_s');
ylabel('R^2: measured vs first-order predicted bias');
title('EXP009 PA5H — First-Order Law Validity vs Contrast');
legend(h,cellstr(modes(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig02_bias_R2_vs_contrast.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3 — eta translation-collapse
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(modes),1);

for im = 1:numel(modes)

    M = CS(string(CS.aperture_mode)==modes(im),:);
    [~,o] = sort(M.weak_to_strong_ratio);
    M = M(o,:);

    h(im) = plot( ...
        M.weak_to_strong_ratio, ...
        M.maximum_eta_collapse_spread_bins, ...
        'o-','LineWidth',1.3);
end

xlabel('A_w/A_s');
ylabel('Max bias spread across true \eta (bins)');
title('EXP009 PA5H — Translation-Invariant Bias Collapse');
legend(h,cellstr(modes(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig03_eta_translation_collapse.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4 — phase anatomy
fig = figure('Visible',cfg.figure_visible);
hold on;

M = PS(string(PS.aperture_mode)=="BeamDerived",:);
[~,o] = sort(M.relative_phase_rad);
M = M(o,:);

h = gobjects(2,1);
h(1) = plot( ...
    M.relative_phase_rad, ...
    M.median_measured_bias_bins, ...
    'o-','LineWidth',1.3);

h(2) = plot( ...
    M.relative_phase_rad, ...
    M.median_predicted_bias_bins, ...
    's--','LineWidth',1.3);

xlabel('Relative phase \phi (rad)');
ylabel('Median bias (bins)');
title('EXP009 PA5H — Phase Structure of Mixture Bias');
legend(h,{'Measured','First-order predicted'}, ...
    'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig04_phase_bias_anatomy.png'), ...
    'Resolution',180);
close(fig);

%% Fig 5 — contrast scaling
fig = figure('Visible',cfg.figure_visible);
hold on;

M = CTS(string(CTS.aperture_mode)=="BeamDerived",:);
[~,o] = sort(M.weak_to_strong_ratio);
M = M(o,:);

h = gobjects(2,1);
h(1) = plot( ...
    M.weak_to_strong_ratio, ...
    M.median_abs_measured_bias_bins, ...
    'o-','LineWidth',1.3);

h(2) = plot( ...
    M.weak_to_strong_ratio, ...
    M.median_abs_predicted_bias_bins, ...
    's--','LineWidth',1.3);

xlabel('A_w/A_s');
ylabel('Median |\delta_{mix}| (bins)');
title('EXP009 PA5H — Contrast Scaling of Mixture Bias');
legend(h,{'Measured','First-order predicted'}, ...
    'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig05_contrast_scaling.png'), ...
    'Resolution',180);
close(fig);

%% Fig 6 — best-window gate regret vs eta
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(modes),1);

for im = 1:numel(modes)

    M = BW(string(BW.aperture_mode)==modes(im),:);
    [~,o] = sort(M.true_eta_bins);
    M = M(o,:);

    h(im) = plot( ...
        M.true_eta_bins, ...
        M.p90_regret_at_min_regret_window, ...
        'o-','LineWidth',1.3);
end

xlabel('True fractional-bin offset |\eta|');
ylabel('90th-percentile decision regret');
title('EXP009 PA5H — Gate Regret vs Fence Offset');
legend(h,cellstr(modes(:)),'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig06_gate_regret_vs_eta.png'), ...
    'Resolution',180);
close(fig);

%% Fig 7 — action agreement vs eta
fig = figure('Visible',cfg.figure_visible);
hold on;

h = gobjects(numel(modes),1);

for im = 1:numel(modes)

    M = OA(string(OA.aperture_mode)==modes(im),:);
    [~,o] = sort(M.true_eta_bins);
    M = M(o,:);

    h(im) = plot( ...
        M.true_eta_bins, ...
        M.action_agreement_rate, ...
        'o-','LineWidth',1.3);
end

xlabel('True fractional-bin offset |\eta|');
ylabel('Gate / oracle action agreement rate');
title('EXP009 PA5H — Decision Agreement with Binary Oracle');
legend(h,cellstr(modes(:)),'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig07_action_agreement_vs_eta.png'), ...
    'Resolution',180);
close(fig);

%% Fig 8 — false vs missed recenter
fig = figure('Visible',cfg.figure_visible);
hold on;

M = OA(string(OA.aperture_mode)=="BeamDerived",:);
[~,o] = sort(M.true_eta_bins);
M = M(o,:);

h = gobjects(2,1);

h(1) = plot( ...
    M.true_eta_bins, ...
    M.false_recenter_rate, ...
    'o-','LineWidth',1.3);

h(2) = plot( ...
    M.true_eta_bins, ...
    M.missed_recenter_rate, ...
    's-','LineWidth',1.3);

xlabel('True fractional-bin offset |\eta|');
ylabel('Decision error rate');
title('EXP009 PA5H — False vs Missed Recentering');
legend(h,{'False recenter','Missed recenter'}, ...
    'Location','best');
ylim([0 1]);
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig08_false_vs_missed_recenter.png'), ...
    'Resolution',180);
close(fig);

%% Fig 9 — gate error vs binary oracle error
fig = figure('Visible',cfg.figure_visible);
hold on;

M = RS( ...
    string(RS.aperture_mode)=="BeamDerived",:);

etas = unique(M.true_eta_bins).';
h = gobjects(numel(etas),1);

for ie = 1:numel(etas)

    Q = M( ...
        abs(M.true_eta_bins-etas(ie))<1e-12,:);

    [~,o] = sort(Q.window_bins);
    Q = Q(o,:);

    h(ie) = plot( ...
        Q.median_E_binary_oracle, ...
        Q.median_E_gate, ...
        'o-','LineWidth',1.1);
end

lims = local_joint_limits( ...
    [M.median_E_binary_oracle; ...
     M.median_E_gate]);

plot(lims,lims,'k--','LineWidth',1.0);

xlabel('Median binary-oracle error');
ylabel('Median gate error');
title('EXP009 PA5H — Gate Distance from Binary Oracle');
legend(h,compose('\\eta=%.3g',etas), ...
    'Location','best');
grid on;

exportgraphics(fig, ...
    fullfile(out_path,'fig09_gate_vs_binary_oracle.png'), ...
    'Resolution',180);
close(fig);

end

%% ========================================================================
function lims = local_symmetric_limits(x)

x = x(isfinite(x));

if isempty(x)
    lims = [-1 1];
    return;
end

m = max(abs(x));

if m<=0
    m = 1;
end

lims = 1.05*[-m m];

end

%% ========================================================================
function lims = local_joint_limits(x)

x = x(isfinite(x));

if isempty(x)
    lims = [0 1];
    return;
end

mn = min(x);
mx = max(x);

if mx<=mn
    mx = mn+1;
end

pad = 0.05*(mx-mn);

lims = [mn-pad,mx+pad];

end
