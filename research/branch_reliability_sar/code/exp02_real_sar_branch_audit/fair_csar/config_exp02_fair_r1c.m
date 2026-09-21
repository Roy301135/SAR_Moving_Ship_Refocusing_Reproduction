function cfg = config_exp02_fair_r1c(research_dir)
%CONFIG_EXP02_FAIR_R1C
% Frozen configuration for EXP02-FAIR-R1C:
% Failure Geometry & Component Validity Audit.
%
% R1C is diagnostic only. It does NOT change any branch-search parameter and
% does NOT run a new refocusing method.
%
% Inputs:
%   The already completed R1B workspace only.
%
% Questions:
%   1) Are the R1B non-SAFE states embedded in recurrent cross-range
%      component families, or are they mostly isolated candidate peaks?
%   2) Why did frozen Neighbor-3 miss every R1B failure?
%   3) Is the correct/global continuous basin's nearest integer seed inside
%      the frozen N3 seed set, and how highly was that seed ranked by the
%      coarse integer DFT?
%
% Scientific boundary:
%   Global continuous winner is still an evaluation reference for the same
%   dechirped tone objective, not physical truth.

cfg = struct();

cfg.experiment_id = "EXP02_FAIR_R1C_FAILURE_GEOMETRY_COMPONENT_VALIDITY";

cfg.r1b_workspace = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r1b_full_frozen_pool_occurrence', ...
    'EXP02_FAIR_R1B_workspace.mat');

cfg.results_dir = fullfile( ...
    research_dir,'results','exp02_real_sar_branch_audit', ...
    'fair_csar','r1c_failure_geometry_component_validity');

%% Frozen cross-line component matching
% Same order tolerance already used in R0/R1B component-family matching.
cfg.component_match_tolerance_order = 0.04;

% Local spatial recurrence is evaluated in a +/-3 range-column neighborhood.
% This is fixed before R1C inspection.
cfg.local_range_halfwidth_columns = 3;

% Engineering credibility flag:
%   >=3 supporting frozen ship lines in the +/-3-column neighborhood
%   AND at least 2 actually consecutive range columns carrying a matched
%   significant component.
cfg.min_local_support_lines = 3;
cfg.min_consecutive_range_run = 2;

%% Plotting
cfg.figure_resolution = 180;
cfg.max_landscape_examples = 4;

end
