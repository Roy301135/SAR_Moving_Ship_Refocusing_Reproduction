# Experiment Index
## branch_reliability_sar

本文件用于快速定位当前 `research/branch_reliability_sar/` 中的代码、文档和结果目录。

---

# 1. EXP01 — Controlled SAR Branch Translation

代码：

```text
code/exp01_sar_branch_translation/
```

## Stage A

```text
config_exp01.m
run_exp01_sar_branch_translation.m
```

结果：

```text
results/exp01_sar_branch_translation/
01_scene_geometry.png
02_range_compressed_echo.png
03_static_vs_moving_bp.png
04_model_consistency.png
EXP01_STAGEA_SUMMARY.txt
exp01_stageA_outputs.mat
model_consistency_audit.csv
```

---

## Stage B — Physical Interface

```text
config_exp01_stageB.m
run_exp01_stageB_interface_audit.m
```

文档：

```text
docs/EXP01_STAGEB_INTERFACE_AUDIT.md
```

主要结果：

```text
05_stageB_physical_interface.png
06_stageB_branch_landscape.png
EXP01_STAGEB_FEEDBACK_BUNDLE.txt
exp01_stageB_outputs.mat
stageB_branch_audit.csv
stageB_component_mapping.csv
```

---

## Stage B2 — Hard-State Embedding

```text
config_exp01_stageB2.m
run_exp01_stageB2_hardstate_embedding.m
```

文档：

```text
docs/EXP01_STAGEB2_HARDSTATE_EMBEDDING.md
```

主要结果：

```text
07_stageB2_physical_embedding.png
08_stageB2_branch_falsification.png
EXP01_STAGEB2_FEEDBACK_BUNDLE.txt
exp01_stageB2_outputs.mat
```

---

## Stage B3 — Natural Line Audit

```text
config_exp01_stageB3.m
run_exp01_stageB3_natural_line_audit.m
```

文档：

```text
docs/EXP01_STAGEB3_NATURAL_LINE_AUDIT.md
```

---

## Stage B4 — 3-D Swing Audit

```text
config_exp01_stageB4.m
run_exp01_stageB4_3d_swing_audit.m
```

文档：

```text
docs/EXP01_STAGEB4_3D_SWING_AUDIT.md
```

---

## Stage B5 — ERV / IPP Audit

```text
config_exp01_stageB5.m
run_exp01_stageB5_effective_geometry_audit.m
```

文档：

```text
docs/EXP01_STAGEB5_ERV_IPP_AUDIT.md
```

当前状态：

```text
EXP01 controlled SAR branch question CLOSED
```

---

# 2. EXP02 — OpenSARShip

代码：

```text
code/exp02_real_sar_branch_audit/opensarship/
```

## R0A — Complex Interface

```text
config_exp02_r0.m
run_exp02_r0a_complex_interface_gate.m
```

结果：

```text
results/exp02_real_sar_branch_audit/opensarship/r0a_interface_gate/
```

---

## R0B — Real LFM Compatibility

```text
config_exp02_r0b.m
run_exp02_r0b_real_lfm_compatibility_audit.m
```

结果：

```text
results/exp02_real_sar_branch_audit/opensarship/r0b_lfm_compatibility/
```

---

## R0C — Cross-Ship Gate

```text
config_exp02_r0c.m
run_exp02_r0c_cross_ship_interface_gate.m
```

结果：

```text
results/exp02_real_sar_branch_audit/opensarship/r0c_cross_ship_interface_gate/
```

当前状态：

```text
OpenSARShip complex-SLC applicability validated
Direct branch-mechanism validation STOPPED
```

---

# 3. EXP02 — FAIR-CSAR

代码：

```text
code/exp02_real_sar_branch_audit/fair_csar/
```

---

## R0 Positive Control

```text
run_exp02_fair_r0_positive_control.m
```

结果：

```text
results/.../fair_csar/r0_positive_control/
```

---

## R0 MC-LFM Compatibility

```text
config_exp02_fair_r0.m
run_exp02_fair_r0.m
```

结果：

```text
results/.../fair_csar/r0_mclfm_compatibility/
```

---

## R0 Phase-Sensitivity Gate

```text
run_exp02_fair_r0_phase_sensitivity_gate.m
```

结果：

```text
results/.../fair_csar/r0_phase_sensitivity_gate/
```

---

## R0 Component-Consistency Gate

```text
run_exp02_fair_r0_component_consistency_gate.m
```

结果：

```text
results/.../fair_csar/r0_component_consistency_gate/
```

---

## R1A — Real Branch Occurrence

```text
config_exp02_fair_r1a.m
run_exp02_fair_r1a_real_branch_occurrence.m
```

结果：

```text
results/.../fair_csar/r1a_real_branch_occurrence/
```

---

## R1B — Full Frozen Pool Occurrence

```text
config_exp02_fair_r1b.m
run_exp02_fair_r1b_full_frozen_pool_occurrence.m
```

文档：

```text
docs/EXP-R-R1B-Full-Frozen-Pool-Occurrence.md
```

结果：

```text
results/.../fair_csar/r1b_full_frozen_pool_occurrence/
```

---

## R1C — Failure Geometry / Component Validity

```text
config_exp02_fair_r1c.m
run_exp02_fair_r1c_failure_geometry_component_validity.m
```

文档：

```text
docs/EXP-R-R1C-Failure-Geometry-Component-Validity.md
```

结果：

```text
results/.../fair_csar/r1c_failure_geometry_component_validity/
```

---

## R1D — Candidate-C Independent Replication

```text
config_exp02_fair_r1d_candidate_c.m
run_exp02_fair_r1d_candidate_c_replication.m
```

文档：

```text
docs/EXP-R-R1D-Candidate-C-Independent-Replication.md
```

结果：

```text
results/.../fair_csar/r1d_candidate_c_independent_replication/
```

---

## R2A — Branch Contribution

```text
config_exp02_fair_r2a.m
run_exp02_fair_r2a_branch_contribution_candidate_b.m
```

有效 helper：

```text
functions/fair_csar/refocus_mclfm_branch_native_clean.m
```

文档：

```text
docs/EXP-R-R2A-Branch-Contribution-to-Image-Defocus.md
```

结果：

```text
results/.../fair_csar/r2a_branch_contribution_candidate_b/
```

---

## GAP01 — Real-vs-Synthetic Gap Audit

```text
config_exp02_fair_gap01.m
run_exp02_fair_gap01_real_vs_synthetic.m
```

文档：

```text
docs/EXP-R-GAP01-Real-vs-Synthetic-Gap-Audit.md
```

结果：

```text
results/.../fair_csar/gap01_real_vs_synthetic/
```

---

# 4. Shared Functions

根目录：

```text
functions/
```

主要 branch helpers：

```text
branch_g0_neighbor3_audit.m
branch_refine_from_seed.m
branch_tone_objective.m
```

Controlled SAR helpers：

```text
sar_backprojection_static_reference.m
sar_build_ship_tracks.m
sar_build_ship_tracks_3d.m
sar_compute_slant_ranges.m
sar_effective_observation_geometry.m
sar_fit_sampled_lfm.m
...
```

FAIR-CSAR：

```text
functions/fair_csar/
```

主要：

```text
branch_real_g0_neighbor3_audit.m
fair_csar_fractional_line_audit.m
fair_csar_load_complex_mat.m
fair_csar_png_orientation_corr.m
fair_csar_read_metadata_xml.m
refocus_mclfm_branch_native_clean.m
```

Deprecated：

```text
refocus_mc_lfm_clean_branch_locked.m
```

不要用于后续实验。

OpenSARShip：

```text
functions/opensarship/
```

---

# 5. 当前建议的 Git 跟踪层级

优先跟踪：

```text
README.md
code/
functions/
docs/
```

结果目录暂时只在本地保留完整版本：

```text
results/
```

后续若需要公开阶段结果，建议只精选：

```text
results/summary/
results/figures/
```

而不是提交全部 MAT / CSV / PNG。
