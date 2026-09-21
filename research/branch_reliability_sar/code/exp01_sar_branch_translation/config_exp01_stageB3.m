function cfg = config_exp01_stageB3(research_root)
%CONFIG_EXP01_STAGEB3 EXP01 Stage-B3 natural target-line mechanism audit.
%
% Purpose:
%   Use the ACCEPTED canonical Stage-A SAR scene without any physical
%   retuning. Select ship target range lines by the same energy-above-mean
%   principle used by Wang 2023, then classify the naturally generated
%   search geometry relative to the dominant physical scatterer on each
%   line.
%
% This stage does NOT run the frozen Proposed scheduler. Its only decision
% is whether a natural discrete-first / Neighbor-3-rescuable line exists.

if nargin < 1 || isempty(research_root)
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    code_dir = fileparts(this_dir);
    research_root = fileparts(code_dir);
end

cfg = config_exp01_stageB(research_root);

%% Accepted Stage-A dependency
cfg.stageB3.stageA_mat = fullfile(cfg.results_dir,'exp01_stageA_outputs.mat');

%% Target-line selection: frozen, observable, no truth tuning
% For moving BP SLC image I(y,x), define range-line energy
%   E(y) = sum_x |I(y,x)|^2
% and select lines with E(y) > mean_y E(y).
% This follows the line-energy selection principle of Wang 2023.
cfg.stageB3.line_selection_rule = 'moving BP line energy > mean line energy';
cfg.stageB3.reference_x_m = cfg.ship_center_x;

%% Mechanism taxonomy thresholds inherited from frozen EXP009/010
cfg.stageB3.branch_match_tolerance_bins = cfg.stageB.branch_match_tolerance_bins;
cfg.stageB3.catastrophic_error_threshold_bins = cfg.stageB.catastrophic_error_threshold_bins;

% Primary classes:
%   E = easy/stable: G0 is not catastrophic relative to strong truth.
%   B = continuous-bias: mixture global optimum moves significantly but
%       remains in the same nearest-integer branch as the strong reference.
%   D = discrete-first: mixture global optimum remains matched to the strong
%       reference, but the coarse Top-1 branch differs and G0 is catastrophic.
%   G = global-winner/branch change: mixture global optimum changes nearest
%       integer branch relative to the strong reference.
%   U = unresolved guard: inconsistent geometry that should not be forced
%       into one of the four scientific classes.
cfg.stageB3.primary_classes = ["E","B","D","G"];

%% Numerical / reporting
cfg.stageB3.figure_visible = 'on';
cfg.stageB3.feedback_bundle_name = 'EXP01_STAGEB3_FEEDBACK_BUNDLE.txt';
cfg.stageB3.save_mat_name = 'exp01_stageB3_outputs.mat';
cfg.stageB3.csv_name = 'stageB3_natural_line_audit.csv';
cfg.stageB3.max_feedback_rows = 12;
cfg.stageB3.landscape_halfwidth_bins = 4.0;
cfg.stageB3.landscape_step_bins = 0.002;

end
