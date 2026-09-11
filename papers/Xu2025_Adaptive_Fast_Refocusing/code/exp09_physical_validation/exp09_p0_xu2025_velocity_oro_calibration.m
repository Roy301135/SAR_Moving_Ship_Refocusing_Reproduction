function results = exp09_p0_xu2025_velocity_oro_calibration()
%EXP09_P0_XU2025_VELOCITY_ORO_CALIBRATION
% EXP009 / Physical Validation Track / P0
%
% Purpose
% -------
% Before re-running the EXP009 mechanism experiments under literature-
% anchored parameters, this P0 gate audits the Xu 2025 velocity <-> ORO
% relationship and resolves the rotation-order convention.
%
% The paper provides:
%   - Table I: radar/platform parameters;
%   - Table II: target azimuth velocities;
%   - Eq. (20)-(22): residual FM / ORO / velocity relationship;
%   - Table III: published OROs and estimated velocities.
%
% However, Table I does not explicitly provide N_a (number of azimuth
% samples), even though Eq. (20)-(22) depends on N_a.
%
% Therefore P0 does NOT pretend that N_a is known. Instead it:
%   1) preserves all published values exactly;
%   2) derives lambda and R0 from the reported radar geometry;
%   3) infers row-wise effective N_a from each non-zero Table III pair;
%   4) computes a robust consensus N_a;
%   5) checks whether Eq. (22) + the stated -0.5 order shift reproduces
%      the published velocity-ORO trend;
%   6) flags any internally inconsistent published row WITHOUT silently
%      correcting it.
%
% This is a calibration / provenance gate, not an innovation experiment.
%
% Run:
%   results = exp09_p0_xu2025_velocity_oro_calibration;
%
% Dependency:
%   config_exp09_p0_xu2025_velocity_oro_calibration.m

cfg = config_exp09_p0_xu2025_velocity_oro_calibration();

%% Output path
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);
code_dir = fileparts(this_dir);
paper_root = fileparts(code_dir);

if isempty(cfg.output_dir)
    out_path = fullfile( ...
        paper_root,'results','exp09_pilot01', ...
        'exp09_p0_xu2025_velocity_oro_calibration');
else
    out_path = cfg.output_dir;
end

if ~exist(out_path,'dir')
    mkdir(out_path);
end

%% Derived geometry
lambda = cfg.c / cfg.fc_hz;

if cfg.use_slant_range_from_height_incidence
    theta = deg2rad(cfg.incidence_angle_deg);
    R0 = cfg.platform_height_m / cos(theta);
else
    error('P0 currently requires slant range derived from height/incidence.');
end

v_target = cfg.target_velocity_mps(:);
p_pub = cfg.published_oro(:);
v_est_pub = cfg.published_estimated_velocity_mps(:);

%% Row-wise implied N_a from the published (ORO, estimated-speed) pairs
N = numel(v_target);
na_row = nan(N,1);

for i = 1:N
    if abs(v_est_pub(i)) < 1e-12
        continue;
    end

    na_row(i) = infer_na_from_velocity_and_reported_oro( ...
        v_est_pub(i),p_pub(i),lambda,R0,cfg);
end

valid_na = na_row(isfinite(na_row) & na_row>0);

if isempty(valid_na)
    error('No valid row-wise N_a could be inferred.');
end

na_consensus = median(valid_na);

rel_dev = abs(na_row-na_consensus)/na_consensus;
row_consistent = rel_dev <= cfg.na_relative_consistency_tol;
row_consistent(~isfinite(rel_dev)) = true; % v=0 row is convention anchor

%% Grid-search N_a using TARGET velocities vs published ORO
na_grid = (cfg.na_search_min:cfg.na_search_step:cfg.na_search_max).';
rmse_grid = nan(size(na_grid));

for k = 1:numel(na_grid)
    p_pred_k = velocity_to_reported_oro( ...
        v_target,na_grid(k),lambda,R0,cfg);

    rmse_grid(k) = sqrt(mean((p_pred_k-p_pub).^2,'omitnan'));
end

[rmse_best_all,ibest] = min(rmse_grid);
na_best_all = na_grid(ibest);

%% Robust-consensus forward prediction
p_pred_consensus = velocity_to_reported_oro( ...
    v_target,na_consensus,lambda,R0,cfg);

oro_error_consensus = p_pred_consensus-p_pub;

%% Inverse check: published ORO -> velocity using consensus N_a
v_from_pub_oro = reported_oro_to_velocity( ...
    p_pub,na_consensus,lambda,R0,cfg);

v_error_vs_target = v_from_pub_oro-v_target;
v_error_vs_published_estimate = v_from_pub_oro-v_est_pub;

%% Literature table
T = table( ...
    (1:N).', ...
    v_target, ...
    p_pub, ...
    v_est_pub, ...
    na_row, ...
    rel_dev, ...
    row_consistent, ...
    p_pred_consensus, ...
    oro_error_consensus, ...
    v_from_pub_oro, ...
    v_error_vs_target, ...
    v_error_vs_published_estimate, ...
    'VariableNames',{ ...
    'point_index', ...
    'target_velocity_mps', ...
    'published_oro', ...
    'published_estimated_velocity_mps', ...
    'implied_Na_from_published_pair', ...
    'implied_Na_relative_deviation', ...
    'row_consistent_with_consensus_Na', ...
    'predicted_oro_from_target_velocity', ...
    'oro_prediction_error', ...
    'velocity_from_published_oro', ...
    'velocity_error_vs_target', ...
    'velocity_error_vs_published_estimate'});

writetable(T,fullfile(out_path,'xu2025_tableIII_consistency_audit.csv'));

%% Gate metrics
median_abs_oro_error = median(abs(oro_error_consensus),'omitnan');
max_abs_oro_error = max(abs(oro_error_consensus),[],'omitnan');

nonzero_mask = abs(v_est_pub)>1e-12;
num_consistent_nonzero = sum(row_consistent(nonzero_mask));
num_nonzero = sum(nonzero_mask);

if median_abs_oro_error <= cfg.oro_gate_abs_tol
    if num_consistent_nonzero == num_nonzero
        gate_status = "PASS";
    elseif num_consistent_nonzero >= num_nonzero-1
        gate_status = "PASS_WITH_PUBLICATION_INCONSISTENCY";
    else
        gate_status = "REVIEW_REQUIRED";
    end
else
    gate_status = "FAIL";
end

S = table( ...
    lambda, ...
    R0, ...
    na_consensus, ...
    na_best_all, ...
    rmse_best_all, ...
    median_abs_oro_error, ...
    max_abs_oro_error, ...
    num_consistent_nonzero, ...
    num_nonzero, ...
    gate_status, ...
    'VariableNames',{ ...
    'lambda_m', ...
    'derived_R0_m', ...
    'robust_consensus_Na', ...
    'best_grid_Na_all_rows', ...
    'best_grid_oro_rmse', ...
    'consensus_median_abs_oro_error', ...
    'consensus_max_abs_oro_error', ...
    'consistent_nonzero_rows', ...
    'nonzero_rows', ...
    'gate_status'});

writetable(S,fullfile(out_path,'p0_gate_summary.csv'));

%% N_a search trace
Tna = table(na_grid,rmse_grid, ...
    'VariableNames',{'Na','oro_rmse'});
writetable(Tna,fullfile(out_path,'na_grid_search.csv'));

%% Console
fprintf('\n============================================================\n');
fprintf(' EXP009 P0 / Xu 2025 Velocity-ORO Calibration\n');
fprintf('============================================================\n');
fprintf('lambda                  : %.9f m\n',lambda);
fprintf('derived R0              : %.3f m\n',R0);
fprintf('robust consensus N_a    : %.3f\n',na_consensus);
fprintf('best all-row grid N_a   : %d\n',na_best_all);
fprintf('best all-row ORO RMSE   : %.6g\n',rmse_best_all);
fprintf('median |ORO error|      : %.6g\n',median_abs_oro_error);
fprintf('max |ORO error|         : %.6g\n',max_abs_oro_error);
fprintf('consistent nonzero rows : %d / %d\n', ...
    num_consistent_nonzero,num_nonzero);
fprintf('P0 gate                 : %s\n',gate_status);
fprintf('============================================================\n\n');

disp(T);
disp(S);

%% Summary text
fid = fopen(fullfile(out_path,'summary.txt'),'w');

fprintf(fid,'EXP009 P0 / Xu 2025 Velocity-ORO Calibration\n');
fprintf(fid,'===========================================\n\n');

fprintf(fid,'Paper-grounded inputs\n');
fprintf(fid,'---------------------\n');
fprintf(fid,'fc = %.6g Hz\n',cfg.fc_hz);
fprintf(fid,'B = %.6g Hz\n',cfg.bandwidth_hz);
fprintf(fid,'PRF = %.6g Hz\n',cfg.prf_hz);
fprintf(fid,'V_SAR = %.6g m/s\n',cfg.platform_velocity_mps);
fprintf(fid,'pulse width = %.6g s\n',cfg.pulse_width_s);
fprintf(fid,'incidence angle = %.6g deg\n',cfg.incidence_angle_deg);
fprintf(fid,'platform height = %.6g m\n',cfg.platform_height_m);
fprintf(fid,'target velocities = %s m/s\n',mat2str(cfg.target_velocity_mps));
fprintf(fid,'published ORO = %s\n',mat2str(cfg.published_oro));
fprintf(fid,'published estimated speeds = %s m/s\n\n', ...
    mat2str(cfg.published_estimated_velocity_mps));

fprintf(fid,'Derived / inferred quantities\n');
fprintf(fid,'-----------------------------\n');
fprintf(fid,'lambda = %.9f m\n',lambda);
fprintf(fid,'R0 = H/cos(theta_inc) = %.6f m\n',R0);
fprintf(fid,'rotation-order convention: p_reported = 2*alpha/pi - 0.5\n');
fprintf(fid,['N_a is NOT listed in Xu Table I; this P0 treats it as an ' ...
    'effective calibration quantity.\n\n']);

fprintf(fid,'Row-wise implied N_a\n');
fprintf(fid,'--------------------\n');

for i = 1:height(T)
    fprintf(fid,[ ...
        'P%d: targetV=%+.3f, publishedORO=%+.6f, publishedEstV=%+.3f, ' ...
        'impliedNa=%g, relDev=%g, consistent=%d\n'], ...
        T.point_index(i), ...
        T.target_velocity_mps(i), ...
        T.published_oro(i), ...
        T.published_estimated_velocity_mps(i), ...
        T.implied_Na_from_published_pair(i), ...
        T.implied_Na_relative_deviation(i), ...
        T.row_consistent_with_consensus_Na(i));
end

fprintf(fid,'\nGate metrics\n');
fprintf(fid,'------------\n');
fprintf(fid,'robust consensus N_a = %.6f\n',na_consensus);
fprintf(fid,'best all-row grid N_a = %d\n',na_best_all);
fprintf(fid,'best all-row RMSE = %.9g\n',rmse_best_all);
fprintf(fid,'median absolute ORO error = %.9g\n',median_abs_oro_error);
fprintf(fid,'maximum absolute ORO error = %.9g\n',max_abs_oro_error);
fprintf(fid,'consistent nonzero rows = %d / %d\n', ...
    num_consistent_nonzero,num_nonzero);
fprintf(fid,'gate status = %s\n\n',gate_status);

fprintf(fid,'Interpretation discipline\n');
fprintf(fid,'-------------------------\n');
fprintf(fid,['1) Do NOT silently replace any Xu Table III value even if a row ' ...
    'appears internally inconsistent.\n']);
fprintf(fid,['2) The purpose of P0 is to verify convention and scale, not to ' ...
    'claim an exact parameter-free reproduction because N_a is omitted.\n']);
fprintf(fid,['3) If P0 passes or passes with one publication inconsistency, ' ...
    'proceed to P1 Wang-2023 five-component MC-LFM baseline.\n']);
fprintf(fid,['4) If P0 fails, stop the physical validation track and revisit ' ...
    'the Eq. (22) convention / R0 definition / N_a interpretation.\n']);

fclose(fid);

%% Figures
make_figures( ...
    out_path,cfg,v_target,p_pub,p_pred_consensus, ...
    na_row,na_consensus,row_consistent,na_grid,rmse_grid);

%% Save
results = struct();
results.cfg = cfg;
results.lambda = lambda;
results.R0 = R0;
results.audit_table = T;
results.gate_summary = S;
results.na_grid = na_grid;
results.rmse_grid = rmse_grid;

save(fullfile(out_path,'exp09_p0_results.mat'),'results','-v7.3');

fprintf('Saved P0 outputs to:\n%s\n\n',out_path);

end

%% ========================================================================
function p_reported = velocity_to_reported_oro(v,Na,lambda,R0,cfg)
% Invert Xu Eq. (22) to obtain alpha and then reported rotation order.
%
% Xu Eq. (22), as used here:
%
% v_a = V * ( 1 - sqrt( 1 + 2V^2 /
%       (lambda*R0*(PRF^2/Na)*cot(alpha) - 2V^2) ) )
%
% Solve analytically for cot(alpha), then use the local principal branch
% alpha around zero. The paper states an overall 0.5 order shift.

v = double(v(:));

V = cfg.platform_velocity_mps;
PRF = cfg.prf_hz;

p_reported = nan(size(v));

for i = 1:numel(v)

    if abs(v(i)) < 1e-12
        p_raw = 0;
        p_reported(i) = p_raw + cfg.reported_order_shift;
        continue;
    end

    s = 1 - v(i)/V;
    z = s^2 - 1;

    if abs(z) < eps
        p_raw = 0;
        p_reported(i) = p_raw + cfg.reported_order_shift;
        continue;
    end

    D = 2*V^2 / z;

    cot_alpha = ...
        (D + 2*V^2) * Na / ...
        (lambda*R0*PRF^2);

    % Local branch around alpha=0.
    alpha = atan(1/cot_alpha);

    p_raw = 2*alpha/pi;
    p_reported(i) = p_raw + cfg.reported_order_shift;
end

end

%% ========================================================================
function v = reported_oro_to_velocity(p_reported,Na,lambda,R0,cfg)
% Direct Xu Eq. (22) evaluation.

p_reported = double(p_reported(:));

V = cfg.platform_velocity_mps;
PRF = cfg.prf_hz;

v = nan(size(p_reported));

for i = 1:numel(p_reported)

    p_raw = p_reported(i)-cfg.reported_order_shift;
    alpha = p_raw*pi/2;

    if abs(alpha) < 1e-12
        v(i) = 0;
        continue;
    end

    cot_alpha = 1/tan(alpha);

    den = ...
        lambda*R0*(PRF^2/Na)*cot_alpha - ...
        2*V^2;

    radicand = 1 + 2*V^2/den;

    if radicand < 0
        v(i) = NaN;
        continue;
    end

    v(i) = V*(1-sqrt(radicand));
end

end

%% ========================================================================
function Na = infer_na_from_velocity_and_reported_oro( ...
    v,p_reported,lambda,R0,cfg)
% Rearrange Xu Eq. (22) to infer the effective N_a required by one
% published (velocity, ORO) pair.

V = cfg.platform_velocity_mps;
PRF = cfg.prf_hz;

p_raw = p_reported-cfg.reported_order_shift;
alpha = p_raw*pi/2;

if abs(alpha)<1e-12 || abs(v)<1e-12
    Na = NaN;
    return;
end

s = 1-v/V;
z = s^2-1;

if abs(z)<eps
    Na = NaN;
    return;
end

D = 2*V^2/z;
cot_alpha = 1/tan(alpha);

den = D + 2*V^2;

if abs(den)<eps
    Na = NaN;
    return;
end

Na = ...
    lambda*R0*PRF^2*cot_alpha / den;

end

%% ========================================================================
function make_figures( ...
    out_path,cfg,v_target,p_pub,p_pred, ...
    na_row,na_consensus,row_consistent,na_grid,rmse_grid)

%% Fig 1: published vs Eq.22 curve
v_dense = linspace(min(v_target),max(v_target),401).';
p_dense = velocity_to_reported_oro( ...
    v_dense,na_consensus,cfg.c/cfg.fc_hz, ...
    cfg.platform_height_m/cosd(cfg.incidence_angle_deg),cfg);

fig = figure('Visible',cfg.figure_visible);
plot(v_dense,p_dense,'LineWidth',1.4);
hold on;
plot(v_target,p_pub,'o','LineWidth',1.2,'MarkerSize',7);
xlabel('Azimuth velocity v_a (m/s)');
ylabel('Reported ORO');
title('EXP009 P0 — Xu 2025 Velocity–ORO Calibration');
legend({'Eq. (22) with robust consensus N_a','Xu Table III'}, ...
    'Location','best');
grid on;
exportgraphics(fig, ...
    fullfile(out_path,'fig01_velocity_oro_calibration.png'), ...
    'Resolution',180);
close(fig);

%% Fig 2: predicted vs published
fig = figure('Visible',cfg.figure_visible);
plot(p_pub,p_pred,'o','LineWidth',1.2,'MarkerSize',7);
hold on;

lo = min([p_pub;p_pred])-0.02;
hi = max([p_pub;p_pred])+0.02;
plot([lo hi],[lo hi],'--','LineWidth',1.0);

xlabel('Xu published ORO');
ylabel('Eq. (22) predicted ORO');
title('EXP009 P0 — Published vs Predicted ORO');
axis equal;
xlim([lo hi]);
ylim([lo hi]);
grid on;
exportgraphics(fig, ...
    fullfile(out_path,'fig02_published_vs_predicted_oro.png'), ...
    'Resolution',180);
close(fig);

%% Fig 3: row-wise implied N_a
fig = figure('Visible',cfg.figure_visible);
x = 1:numel(na_row);
bar(x,na_row);
hold on;
yline(na_consensus,'--','Consensus N_a');

for i = 1:numel(na_row)
    if isfinite(na_row(i)) && ~row_consistent(i)
        plot(i,na_row(i),'x','MarkerSize',12,'LineWidth',2);
    end
end

xticks(x);
xticklabels({'P1','P2','P3','P4','P5'});
ylabel('Row-wise implied N_a');
title('EXP009 P0 — Xu Table III Internal Consistency');
grid on;
exportgraphics(fig, ...
    fullfile(out_path,'fig03_rowwise_implied_Na.png'), ...
    'Resolution',180);
close(fig);

%% Fig 4: N_a grid search
fig = figure('Visible',cfg.figure_visible);
plot(na_grid,rmse_grid,'LineWidth',1.2);
hold on;
xline(na_consensus,'--');
xlabel('Candidate N_a');
ylabel('ORO RMSE vs Xu Table III');
title('EXP009 P0 — Effective N_a Grid Search');
grid on;
exportgraphics(fig, ...
    fullfile(out_path,'fig04_Na_grid_search.png'), ...
    'Resolution',180);
close(fig);

end
