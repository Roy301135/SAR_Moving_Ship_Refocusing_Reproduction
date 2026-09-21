# EXP01 — SAR-Level Translation of Branch Error and Reliability-Aware Recovery

## Current implementation status: Stage A only

This folder currently implements the **SAR physical foundation** for EXP01:

`ship scatterers -> yaw motion -> exact slant-range histories -> ideal range-compressed complex data -> stationary-reference BP -> static/moving SAR images`

It intentionally does **not** yet connect the frozen G0 / Proposed / Always-N3 / Oracle chain.

### Why Stage A is isolated

Before testing the branch-reliability claim at image level, the project first checks that:

1. a stationary version of the same scene is correctly focused by the common imager;
2. complex target motion naturally produces spatially varying SAR defocus through the physical range history, rather than through artificial image blur;
3. the designated strong/weak scatterers remain compatible with the short-aperture local quadratic-phase / MC-LFM approximation that underlies EXP009–EXP011.

No new algorithmic claim is introduced here.

## Run

From MATLAB, either enter this folder and run:

```matlab
run_exp01_sar_branch_translation
```

or add this folder to the MATLAB path and call the same function.

The script automatically locates:

- `../../functions/`
- `../../results/exp01_sar_branch_translation/`

relative to `research/branch_reliability_sar/`.

## Expected outputs

All outputs are written to:

```text
research/branch_reliability_sar/results/exp01_sar_branch_translation/
```

including:

- `01_scene_geometry.png`
- `02_range_compressed_echo.png`
- `03_static_vs_moving_bp.png`
- `04_model_consistency.png`
- `model_consistency_audit.csv`
- `EXP01_STAGEA_SUMMARY.txt`
- `exp01_stageA_outputs.mat`

## Review gate

Do not attach the frozen branch-processing chain until Stage A is audited.

Return at minimum:

- `03_static_vs_moving_bp.png`
- `04_model_consistency.png`
- `EXP01_STAGEA_SUMMARY.txt`

The next step remains inside **the same EXP01**, rather than creating multiple small experiments.
