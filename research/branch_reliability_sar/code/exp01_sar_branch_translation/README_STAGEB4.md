# EXP01 Stage-B4 — Literature-Anchored Full 3-D Swing Natural Branch Audit

## Purpose

Stage-B4 is the **final controlled-simulation mechanism check** before the project either:

1. proceeds to frozen Proposed SAR image-level integration, or
2. closes the controlled rigid-body simulation line for the selective-N3 claim.

It asks only:

> Can one frozen, literature-anchored roll + pitch + yaw rigid-body SAR scene naturally enter the discrete-first / Neighbor-3-rescuable branch-vulnerable regime discovered in EXP009/010?

## Frozen motion

The simulation uses the Wang 2023 3-D swing parameters already cited in the project:

- roll double amplitude 17.2 deg, period 12.2 s;
- pitch double amplitude 3.4 deg, period 6.7 s;
- yaw double amplitude 38 deg, period 14.2 s;
- initial phase = 0.5*pi.

Consistent with Stage-A, reported double amplitudes are treated as peak-to-peak, giving sinusoid amplitudes 8.6 / 1.7 / 19 deg.

The rigid-body rotation matrix follows Xu 2025 Eq. (14), equivalent to:

`Rot = Rx(theta_x) * Ry(theta_y) * Rz(theta_z)`

## What is NOT changed

- SAR system / aperture;
- sparse scatterer skeleton and reflectivities;
- target-line energy selection;
- E/B/D/G/U taxonomy;
- branch-match and catastrophic thresholds;
- G0 / Neighbor-3 semantics;
- noise/clutter remain off;
- Proposed is not run;
- no motion sweep or scene retuning.

## Run

From:

`research/branch_reliability_sar/code/exp01_sar_branch_translation/`

run:

```matlab
run_exp01_stageB4_3d_swing_audit
```

## Return to ChatGPT

Upload only:

- `EXP01_STAGEB4_FEEDBACK_BUNDLE.txt`
- `11_stageB4_3d_scene_and_taxonomy.png`
- `12_stageB4_representative_landscape.png`

Keep CSV/MAT locally unless an anomaly needs a deeper audit.

## Stop rule

- D + Neighbor-3 rescue -> audit the D-line LFM fit, briefly discuss signal-space hard-state physical realizability, then proceed to Stage-C.
- D but no rescue -> stop; do not widen N3.
- no D -> close controlled rigid-body simulation for this branch claim; do not add more simulated motion families simply to manufacture a failure.
