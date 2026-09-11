%% exp01_eq22_ori_mapping.m
% Xu et al., JSTARS 2025
% "Adaptive Fast Refocusing for Ship Targets With Complex Motion in SAR Images"
%
% Experiment 01:
%   Reproduce the Eq. (22) azimuth-velocity <-> ORO mapping mechanism.
%
% Main questions:
%   1) Does a 20 m/s azimuth-velocity span map into a narrow ORO interval?
%   2) Is the curve consistent with Fig. 6 / Table III at the mechanism level?
%
% Reproducibility limitation:
%   Table I does not report Na (azimuth sample number of the processed slice).
%   Therefore an exact numerical reproduction of Fig. 6 is impossible from
%   the paper alone. Here Na = 1200 is a calibrated working value that
%   approximately matches the Table III ORO scale. It is NOT claimed to be
%   the exact Na used by the authors.

clear; clc; close all;

%% 0. Resolve project paths
this_file = mfilename('fullpath');
exp_code_dir = fileparts(this_file);
code_dir = fileparts(exp_code_dir);
paper_dir = fileparts(code_dir);

functions_dir = fullfile(code_dir, 'functions');
result_dir = fullfile(paper_dir, 'results', 'exp01_eq22_ori_mapping');

addpath(functions_dir);
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

%% 1. Paper parameters (Table I)
c = 3e8;
fc = 3e9;
lambda = c / fc;

PRF = 300;
Vsar = 200;
H = 10e3;
inc_deg = 45;

% Center-geometry approximation
R0 = H / cosd(inc_deg);

% Not reported in Table I; calibrated working value.
Na = 1200;

%% 2. Velocity grid
v = linspace(-180, 180, 4001);

[p_signed, p_raw, p_centered] = ...
    velocity_to_order(v, Vsar, lambda, R0, PRF, Na);

%% 3. Fig. 6-style mapping
fig1 = figure('Name','exp01 Fig6 style mapping','Color','w');

subplot(1,3,1);
% Avoid drawing the artificial modulo-2 connection across v=0.
idx_neg_all = v < 0;
idx_pos_all = v > 0;
plot(p_raw(idx_neg_all), v(idx_neg_all), 'LineWidth', 1.3);
hold on;
plot(p_raw(idx_pos_all), v(idx_pos_all), 'LineWidth', 1.3);
xlabel('Optimal rotation order p (mod 2)');
ylabel('Azimuth velocity v_a (m/s)');
title('(a) v_a = -180 to 180 m/s');
grid on;
xlim([0 2]);
ylim([-180 180]);

subplot(1,3,2);
idx_neg = (v >= -15) & (v <= 0);
plot(p_raw(idx_neg), v(idx_neg), 'LineWidth', 1.3);
xlabel('Optimal rotation order p');
ylabel('Azimuth velocity v_a (m/s)');
title('(b) v_a = -15 to 0 m/s');
grid on;
ylim([-15 0]);

subplot(1,3,3);
idx_pos = (v >= 0) & (v <= 15);
plot(p_raw(idx_pos), v(idx_pos), 'LineWidth', 1.3);
xlabel('Optimal rotation order p');
ylabel('Azimuth velocity v_a (m/s)');
title('(c) v_a = 0 to 15 m/s');
grid on;
ylim([0 15]);

%% 4. Five-target check (Table II / Table III)
v_true = [-10, -5, 0, 5, 10];

[~, ~, p_centered_5] = ...
    velocity_to_order(v_true, Vsar, lambda, R0, PRF, Na);

p_table_paper = [-0.415, -0.457, -0.500, -0.534, -0.583];
v_est_paper = [-11.09, -5.36, 0, 4.96, 9.29];

v_from_paper_oro = centered_order_to_velocity( ...
    p_table_paper, Vsar, lambda, R0, PRF, Na);

T = table( ...
    (1:5).', ...
    v_true.', ...
    p_centered_5.', ...
    p_table_paper.', ...
    (p_centered_5 - p_table_paper).', ...
    v_from_paper_oro.', ...
    v_est_paper.', ...
    'VariableNames', { ...
    'Target', 'TrueVelocity_mps', 'ModelCenteredORO', ...
    'PaperTableIII_ORO', 'ORO_Difference', ...
    'Eq22VelocityFromPaperORO_mps', 'PaperEstimatedVelocity_mps'});

disp(' ');
disp('================ EXP01 TABLE III CHECK ================');
disp(T);

%% 5. Interpretation
p_span_model = max(p_centered_5) - min(p_centered_5);
p_span_paper = max(p_table_paper) - min(p_table_paper);

fprintf('\n================ EXP01 INTERPRETATION ================\n');
fprintf('lambda                 = %.6f m\n', lambda);
fprintf('R0 (center assumption) = %.3f km\n', R0/1e3);
fprintf('Na (working value)     = %d  [not reported in Table I]\n', Na);
fprintf('\n');
fprintf('Velocity span used     = %.2f m/s\n', max(v_true)-min(v_true));
fprintf('Model ORO span         = %.6f\n', p_span_model);
fprintf('Paper Table III span   = %.6f\n', p_span_paper);
fprintf('\n');
fprintf(['Interpretation: a 20 m/s azimuth-velocity span is compressed into\n' ...
         'a narrow ORO span of about 0.17-0.20, supporting the ORI prior.\n']);

%% 6. Continuous centered-ORO visualization
fig2 = figure('Name','exp01 Narrow ORO interval','Color','w');

plot(v, p_centered, 'LineWidth', 1.3);
hold on;
plot(v_true, p_centered_5, 'o', 'MarkerSize', 7, 'LineWidth', 1.2);
plot(v_true, p_table_paper, 'x', 'MarkerSize', 8, 'LineWidth', 1.2);

xlabel('Azimuth velocity v_a (m/s)');
ylabel('Centered ORO');
title('Velocity variation mapped into a narrow ORO interval');
legend('Eq. (22) model', 'Model at five velocities', ...
       'Paper Table III ORO', 'Location','best');
grid on;
xlim([-20 20]);

%% 7. Save outputs
writetable(T, fullfile(result_dir, 'exp01_summary.csv'));

save(fullfile(result_dir, 'exp01_summary.mat'), ...
    'v', 'p_raw', 'p_centered', 'v_true', 'p_centered_5', ...
    'p_table_paper', 'v_est_paper', 'lambda', 'R0', 'PRF', 'Vsar', ...
    'H', 'inc_deg', 'Na', 'p_span_model', 'p_span_paper');

exportgraphics(fig1, fullfile(result_dir, 'fig01_eq22_fig6_style_mapping.png'), ...
    'Resolution', 200);
exportgraphics(fig2, fullfile(result_dir, 'fig02_narrow_oro_interval.png'), ...
    'Resolution', 200);

fprintf('\nOutputs saved to:\n%s\n', result_dir);
