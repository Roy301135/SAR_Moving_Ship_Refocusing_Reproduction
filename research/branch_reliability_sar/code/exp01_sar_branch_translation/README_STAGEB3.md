# EXP01 Stage-B3 — Canonical Full Target-Line Natural Mechanism Audit

## Purpose

This stage does **not** add a new algorithm and does **not** retune the SAR scene.
It asks one question only:

> Does the already accepted canonical yawing-ship SAR scene naturally contain the discrete-first branch failure mechanism targeted by Neighbor-3?

## Inputs

Requires the accepted Stage-A output:

```text
research/branch_reliability_sar/results/exp01_sar_branch_translation/
    exp01_stageA_outputs.mat
```

and the Stage-B functions already installed in:

```text
research/branch_reliability_sar/functions/
```

including the corrected `branch_g0_neighbor3_audit.m`.

## Run

From:

```text
research/branch_reliability_sar/code/exp01_sar_branch_translation/
```

run:

```matlab
run_exp01_stageB3_natural_line_audit
```

## Frozen target-line selection

Range-line energy is computed from the accepted moving BP SLC:

```text
E(n) = sum_m |g(m,n)|^2
```

and all lines satisfying:

```text
E(n) > mean(E)
```

are audited. No truth label, branch outcome, DenseRisk state, yaw parameter, phase, or amplitude ratio enters this selection.

## Mechanism taxonomy

- `E`: easy / stable — G0 is not catastrophic relative to the dominant strong physical component.
- `B`: continuous-bias — the mixture continuous optimum moves, but remains in the same nearest-integer branch.
- `D`: discrete-first — the mixture continuous global optimum remains matched to strong truth, but coarse Top-1 changes and G0 becomes catastrophic.
- `G`: global-winner/branch change — the mixture continuous optimum moves to a different nearest-integer branch.
- `U`: unresolved guard — stop rather than force an interpretation.

A catastrophic error alone is **not** sufficient to label a line as branch failure.

## Outputs

```text
stageB3_natural_line_audit.csv
exp01_stageB3_outputs.mat
EXP01_STAGEB3_FEEDBACK_BUNDLE.txt
09_stageB3_line_taxonomy.png
10_stageB3_representative_landscape.png
```

For ChatGPT audit, upload only the TXT and the two PNG files unless specifically asked for CSV/MAT.

## Stop rule

- Any `U`: stop and audit classification/interface.
- At least one `D` with Neighbor-3 rescue: proceed directly to Stage-C frozen Proposed image-level integration.
- `D` exists but no N3 rescue: stop; do not widen N3 or retune the scene.
- No `D`: close this canonical yaw-only scene for the selective-N3 SAR claim; do not manufacture a hard case.
