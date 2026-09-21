# EXP-R-R1B-Full-Frozen-Pool-Occurrence

## Purpose

R1B expands the real-data occurrence audit from the 8 already validated
dominant-component states used in R1A to the **entire ship-line pool frozen
before R0 interpretation**.

For Candidate B this pool is the complete Wang-style:

```text
E(n) > mean(E)
```

set saved as `target_global_all` in the corrected R0 workspace.

## Why R1B does not simply force p=0.78 onto all ship lines

Only the R0 dominant recurrent family was validated near p≈0.78.

R1B therefore reuses the same physically conservative component gate:

```text
corrected Xu Eq.(31) FrAc
-> p=1 guard
-> amplitude-preserving phase permutation
-> line-wise max-statistic 95% threshold
-> real nondegenerate local peak
-> within-line NMS
```

Only accepted component-line pairs become branch-audit states.

The occurrence denominator is therefore:

```text
number of valid real component states
```

not the raw number of image columns.

## Branch audit

For each accepted component state:

```text
p_beta
-> sampled quadratic dechirp
-> G0
-> Neighbor-3
-> evaluation-only full-period continuous global reference
```

Taxonomy:

- SAFE
- G0_FAIL_N3_RESCUE
- N3_COVERAGE_MISS
- PERSISTENT_WITHIN_COVERAGE

Severity flag:

```text
G0_error > 0.10 bin
```

## Frozen parameters

Component screen:

```text
surrogates/line = 32
RNG seed = 20260917
phase-blind point = p=1
nondegenerate guard = |p-1| > 0.06
line-wise surrogate max percentile = 95%
within-line NMS tolerance = 0.04 order
```

Branch search:

```text
local halfwidth = 0.75 bin
local bracket points = 33
Neighbor radius = 1
branch-match tolerance = 0.02 bin
catastrophic threshold = 0.10 bin
global-reference oversample = 1024
```

No parameter may be changed after seeing R1B outcomes.

## Scientific boundary

A SAFE component state means:

> after dechirping by a real component order that passed the frozen R0
> compatibility gate, discrete-first G0 lands on the same continuous global
> branch of the tone objective.

It does **not** mean:

- the ship image is focused;
- motion compensation is complete;
- higher-order / nonlinear phase is absent;
- branch error is the dominant source of visual defocus.

Therefore, if Candidate B is visually severely defocused while R1B remains
all/mostly SAFE, that is a scientifically useful result: it implies that
other defocus mechanisms must be audited separately rather than forcing a
branch failure by retuning the search.

## Run

```matlab
run_exp02_fair_r1b_full_frozen_pool_occurrence
```

## Output folder

```text
research/branch_reliability_sar/results/
  exp02_real_sar_branch_audit/
    fair_csar/
      r1b_full_frozen_pool_occurrence/
```

## Upload for review

Upload only:

1. `EXP02_FAIR_R1B_FEEDBACK.txt`
2. `01_component_state_map.png`
3. `02_branch_occurrence_map.png`
4. `03_occurrence_summary.png`
5. `04_selected_branch_landscapes.png`

Keep CSV/MAT locally.
