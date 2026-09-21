# EXP-R-R1C-Failure-Geometry-Component-Validity

## Purpose

R1B found real non-SAFE branch states, but every failure was a frozen
Neighbor-3 coverage miss.

R1C does **not** enlarge Neighbor-3 or introduce a new recovery method.

It asks two diagnostic questions:

1. Are the R1B failure states embedded in recurrent cross-range FrAc
   component families, or are they mostly isolated significant peaks?
2. Why is the evaluation-only global branch outside Neighbor-3 coverage?

## Inputs

R1C reads only:

```text
results/exp02_real_sar_branch_audit/fair_csar/
  r1b_full_frozen_pool_occurrence/
    EXP02_FAIR_R1B_workspace.mat
```

It does not rerun the 62×32 phase-surrogate screen.

## Component recurrence

For each R1B failure state `(column, p_beta)`:

- search every frozen R1B ship line for an already accepted component
  within `|Δp| <= 0.04`;
- compute total cross-line support;
- compute local support inside `column ± 3`;
- compute the longest run across **actually consecutive range columns**.

Frozen engineering credibility flag:

```text
local support >= 3 lines
AND
consecutive range-column run >= 2
```

This strengthens component validity but does not prove unique scatterer identity.

## Failure search geometry

For every failure state, R1C computes:

- nearest integer bin to the full-period continuous global winner;
- off-grid distance of that winner;
- coarse DFT rank of the nearest global-basin integer seed;
- coarse score ratio of that seed to coarse Top-1;
- circular integer-bin distance from G0 Top-1 seed to the global-basin seed;
- whether that global-basin seed lies in `{k0-1,k0,k0+1}`;
- consistency between that geometric coverage and actual N3 candidate coverage.

No quantity above is used to change the algorithm.

## Integrity rule

If the global-basin nearest integer seed lies in frozen N3 but actual N3
candidate coverage is false, stop scientific interpretation and audit the
implementation/search geometry first.

## Interpretation

A likely clean outcome is:

```text
failure component is locally recurrent
+
global-basin integer seed is far from k0
+
global-basin integer seed is outside N3 seed set
```

That supports:

> credible real remote-basin branch failure exists, but it lies outside the
> local Neighbor-3 coverage regime.

This is an applicability-boundary result, not a reason to enlarge Neighbor-3
inside R1C.

## Run

```matlab
run_exp02_fair_r1c_failure_geometry_component_validity
```

## Result folder

```text
research/branch_reliability_sar/results/
  exp02_real_sar_branch_audit/
    fair_csar/
      r1c_failure_geometry_component_validity/
```

## Upload for review

Upload only:

1. `EXP02_FAIR_R1C_FEEDBACK.txt`
2. `01_failure_recurrence_overlay.png`
3. `02_failure_search_geometry.png`
4. `03_failure_recurrence_summary.png`
5. `04_selected_failure_landscapes.png`

Keep CSV/MAT locally.
