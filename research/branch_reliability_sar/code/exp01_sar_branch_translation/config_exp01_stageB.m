function cfg = config_exp01_stageB(research_root)
%CONFIG_EXP01_STAGEB Configuration for EXP01 Stage-B interface audit.
%
% Stage-B purpose:
%   physical SAR echo -> canonical reference range-cell history
%   -> sampled MC-LFM parameterization used by EXP009/010
%   -> inherited G0 / Neighbor-3 branch-geometry audit.
%
% IMPORTANT:
%   - Stage-A physical scene is NOT changed here.
%   - Proposed scheduler is NOT run here.
%   - True strong a/beta is used only as an oracle mechanism control to
%     isolate the branch-interface geometry before practical beta search.

if nargin < 1 || isempty(research_root)
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    code_dir = fileparts(this_dir);
    research_root = fileparts(code_dir);
end

cfg = config_exp01(research_root);

%% Stage-A dependency: reuse the exact accepted physical realization
cfg.stageB.stageA_mat = fullfile(cfg.results_dir, 'exp01_stageA_outputs.mat');

%% Canonical physical extraction reference
% Use the scene-center azimuth reference x=0. This is fixed independently
% of the branch outcome and must NOT be moved to manufacture an off-grid
% hard case.
cfg.stageB.reference_x_m = cfg.ship_center_x;

% Ground-range reference is the aperture-center common range coordinate of
% the designated strong/weak pair. It is resolved from the Stage-A tracks.
cfg.stageB.reference_y_rule = 'mean designated-pair static y at eta=0';

%% Exact-forward / sampled-data bridge
% Primary mechanism audit uses the ideal forward model evaluated at the
% canonical reference range history, avoiding range-grid interpolation as a
% hidden source of branch geometry. The signal extracted from the stored
% range grid is retained as a discretization diagnostic only.
cfg.stageB.primary_signal = 'exact_forward_full_scene';

%% Sampled LFM / branch semantics inherited from EXP009/010
cfg.stageB.local_search_halfwidth_bins = 0.75;
cfg.stageB.local_bracket_points = 33;
cfg.stageB.local_tolx_bins = 1e-11;
cfg.stageB.local_max_fun_evals = 200;
cfg.stageB.neighbor_radius = 1;

% Evaluation-only branch criteria inherited from EXP010-B.
cfg.stageB.branch_match_tolerance_bins = 0.02;
cfg.stageB.catastrophic_error_threshold_bins = 0.10;

% Evaluation-only global reference. We use the same conceptual role as the
% old GlobalReference, but scan the full DFT period because this physical
% scene was not constructed from the old eta-in-[0,0.5] stress family.
cfg.stageB.global_oversample = 32;
cfg.stageB.global_tolx_bins = 1e-12;
cfg.stageB.global_max_fun_evals = 300;

% PA4 BeamDerived width is carried only as a scale/context diagnostic.
% It is NOT used to tune the scene or make any online decision.
cfg.stageB.pa4_beta_width_beam_rad = 8.60e-5;

%% Figure / feedback settings
cfg.stageB.figure_visible = 'on';
cfg.stageB.feedback_bundle_name = 'EXP01_STAGEB_FEEDBACK_BUNDLE.txt';
cfg.stageB.save_mat_name = 'exp01_stageB_outputs.mat';
cfg.stageB.branch_plot_halfwidth_bins = 4.0;
cfg.stageB.branch_plot_step_bins = 0.002;

end
