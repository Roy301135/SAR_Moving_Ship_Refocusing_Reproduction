# EXP01 Stage-B5 — Frozen 3-D Scene ERV / IPP Audit

## Purpose

Stage-B5 is the final minimal explanatory audit for the controlled SAR simulation line.

It does **not** search for a new branch-failure case. It only re-analyzes the already accepted Stage-B4 3-D rigid-body motion and asks:

> During the frozen ~1.4 s aperture, how much do the radar-effective rotation vector (ERV) and image projection plane (IPP) actually vary?

## Frozen items

No change is allowed to:

- roll / pitch / yaw amplitude;
- periods or initial phases;
- platform / SAR parameters;
- aperture length;
- scatterer layout;
- target-line selection;
- G0 / Neighbor-3;
- DenseRisk construction;
- Proposed scheduler.

## Important implementation choice

No arbitrary "quasi-stationary = drift < X degrees" threshold is introduced.

The code only reports descriptive geometry metrics and the already accepted Stage-B4 quadratic-fit NRMSE. The scientific interpretation is made after reviewing the output.

Also note that, under the review's definitions,

`n_IPP = normalize(u_LOS x u_CR)`

is theoretically aligned with normalized `omega_eff`. Therefore IPP-normal drift and ERV-direction drift are not treated as independent evidence; their agreement is a numerical consistency check.

## Run

From:

```text
research/branch_reliability_sar/code/exp01_sar_branch_translation/
```

run:

```matlab
run_exp01_stageB5_effective_geometry_audit
```

The script requires the accepted local files:

```text
results/exp01_sar_branch_translation/
├── EXP01_STAGEA_SUMMARY.txt
└── EXP01_STAGEB4_FEEDBACK_BUNDLE.txt
```

## Outputs

```text
results/exp01_sar_branch_translation/
├── EXP01_STAGEB5_FEEDBACK_BUNDLE.txt
├── 13_stageB5_erv_magnitude.png
├── 14_stageB5_angular_drift.png
└── exp01_stageB5_outputs.mat
```

For feedback, upload only the TXT and two PNG figures.
