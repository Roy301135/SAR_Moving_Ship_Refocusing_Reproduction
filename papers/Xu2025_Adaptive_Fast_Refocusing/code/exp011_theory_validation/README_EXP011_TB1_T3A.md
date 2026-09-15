# EXP011-A — Theory Bridge 1 T3A

## Purpose

This package performs a retrospective objective-geometry audit for Theory Bridge 1.

It **does not** develop or tune a method and **does not** fit theory to experimental outcomes.

## Placement

Create:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp011_theory_validation
```

Put these files there:

```text
config_exp011_tb1_t3a_geometry_audit.m
exp011_tb1_t3a_geometry_audit.m
EXP011_TB1_T3A_EXPERIMENT_DESIGN.md
TB1_THEORY_FREEZE_v1.0.md
```

Results are written automatically to:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\results\exp011_theory_validation\exp011a_tb1_t3a_geometry_audit\
```

## Required upstream file

```text
results\exp09_physical_validation\exp09_pa5i_r1_gamma_denseeta_tail_audit\pa5i_r1_dense_eta_risk_states.csv
```

No EXP010 result is used.

## Run order

First run the smoke audit:

```matlab
cd E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp011_theory_validation
results = exp011_tb1_t3a_geometry_audit("smoke");
```

Only after the smoke feedback is reviewed, run:

```matlab
results = exp011_tb1_t3a_geometry_audit("formal");
```

## What to send back

Please send:

```text
EXP011_TB1_T3A_FEEDBACK_BUNDLE.txt
exp011a_tb1_t3a_verdict.csv
exp011a_tb1_t3a_regime_summary.csv
exp011a_tb1_t3a_mismatch_taxonomy.csv
```

If the verdict contains `TYPE_I_POTENTIAL_FALSIFICATION`, also send `exp011a_tb1_t3a_trials.csv`.

Do not modify theory parameters before review.

## Interpretation discipline

Zero R1 cases does **not** by itself refute TB1. It may mean the frozen PA5I-R1 parameter family reaches catastrophic behavior mainly through continuous branch competition rather than discrete-first inversion.

High-contrast, half-bin, tie, or branch-topology cases are allowed to depart from the smooth local approximation. Mismatch is scientific output.
