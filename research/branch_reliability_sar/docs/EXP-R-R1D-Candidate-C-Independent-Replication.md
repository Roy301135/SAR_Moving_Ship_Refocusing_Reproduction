# EXP-R-R1D-Candidate-C-Independent-Replication

## Purpose

Candidate C is the second pre-registered FAIR-CSAR real target.

This experiment is an **independent replication** of the pipeline already
frozen on Candidate B.

Nothing is tuned using Candidate-C outcomes.

## Frozen pipeline

```text
complex SLC interface sanity
-> official target polygon + fixed 32 px margin
-> Wang E(n)>mean(E) ship-line pool
-> corrected Xu Eq.(31) FrAc
-> p=1 guard
-> amplitude-preserving phase permutation
-> line-wise max-statistic 95% gate
-> significant nondegenerate local components
-> G0 / Neighbor-3 / continuous global reference
-> failure recurrence + remote-basin geometry
```

## Candidate

```text
GF3_KAS_SL_028368_E139.7_N35.5_20211229_L1A_HH_L10000000001_00000_04491
```

Expected data folder:

```text
data/fair_csar/pilot_candidate_C/
├─ SLCMats/
├─ PNGImages/
├─ METAXmls/
└─ Annotations/
```

The current script uses MAT/PNG/XML. Annotation is retained for provenance.

## Frozen component parameters

```text
p grid = same Candidate-B corrected R0 grid
surrogates/line = 32
RNG seed = 20260917
phase-blind point = p=1
guard = |p-1| > 0.06
line-wise surrogate max percentile = 95%
within-line NMS = 0.04 order
```

## Frozen branch parameters

```text
local halfwidth = 0.75 bin
local bracket points = 33
Neighbor radius = 1
branch match = 0.02 bin
catastrophic threshold = 0.10 bin
global reference oversample = 1024
```

## Frozen failure-recurrence parameters

```text
component order match tolerance = 0.04
local range neighborhood = +/-3 columns
credible local support >= 3 lines
credible consecutive range run >= 2
```

## Interpretation

The main replication questions are:

1. Does Candidate C also contain natural real branch failures?
2. Are they again remote-basin N3 coverage misses?
3. Does Candidate C contain any natural `G0_FAIL_N3_RESCUE` state under the
   unchanged Neighbor-3 definition?
4. Are failure states locally recurrent component families or isolated peaks?

No result in this experiment is allowed to enlarge Neighbor-3 or retune the
component gate.

## Run

```matlab
run_exp02_fair_r1d_candidate_c_replication
```

## Results

```text
research/branch_reliability_sar/results/
  exp02_real_sar_branch_audit/
    fair_csar/
      r1d_candidate_c_independent_replication/
```

## Upload for review

Upload only:

1. `EXP02_FAIR_R1D_FEEDBACK.txt`
2. `01_candidate_c_interface_crop.png`
3. `02_candidate_c_component_states.png`
4. `03_candidate_c_branch_occurrence.png`
5. `04_candidate_c_failure_geometry.png`
6. `05_candidate_c_selected_failure_landscapes.png`

Keep MAT/CSV locally.
