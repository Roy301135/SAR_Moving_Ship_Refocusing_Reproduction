# EXP009 / PA5J-B3 — Staged Reliability Gate

## Status

**DESIGN FROZEN**

PA5J-B2 established two facts:

1. `refined_lr_asymmetry` captures a strong low-budget observable failure core;
2. Cost-0 diagnostics retain useful information inside the G5-untriggered residual pool.

It also showed why naive `All3_MaxRank` can underperform at low budgets: complementary Cost-0 ranks displace some high-priority Refined-LR failures before the budget is large enough.

PA5J-B3 converts that mechanism into a staged adaptive-computation policy.

---

## Research Question

> Can sequential reliability allocation create a better final catastrophic-failure / objective-evaluation Pareto front than the complete PA5J-B1 single-stage policy family?

The design is:

```text
G0
↓
Stage 1: Refined-LR ranking
↓
accept Stage-1 high-risk set for Neighbor-3
↓
remaining pool only
↓
Stage 2: Cost-0 reranking
↓
additional Neighbor-3 fallback
```

The key idea is that Cost-0 information is used **after** the high-value Refined-LR core is protected, rather than competing with it symmetrically from the beginning.

---

## Primary groups

The formal run evaluates all four established groups:

- Original / Paper1s
- Original / BeamDerived
- DenseRisk / Paper1s
- DenseRisk / BeamDerived

B2 mechanism evidence came primarily from DenseRisk, while Original remains the representative rare-event evaluation.

---

## Stage-1 budgets

Frozen before the run:

```text
0.005
0.01
0.02
0.05
0.10
0.20
0.30
0.50
```

Stage 1 always uses:

```text
refined_lr_asymmetry
high value -> high risk
```

with tie-inclusive selection.

---

## Stage-2 budgets

Stage-2 budget is defined **inside the Stage-1-untriggered pool**:

```text
0
0.01
0.02
0.05
0.10
0.20
0.30
0.50
1.00
```

Stage-2 selection is also tie-inclusive.

The formal output records:

- conditional Stage-2 actual fraction;
- extra Stage-2 trigger fraction relative to all trials;
- total actual fallback fraction.

No trial ID or row order may break a cutoff tie.

---

## Stage-2 signals

No new indicator is introduced.

Three frozen PA5J-B2 Cost-0 alternatives are tested.

### FiveBin

```text
score = -fivebin_peak_fraction
```

### Entropy

```text
score = local_entropy5
```

### Cost0_MaxRank

Within the complete primary group, convert FiveBin and Entropy to tie-preserving empirical risk percentiles:

```text
Cost0_MaxRank = max(R_fivebin, R_entropy)
```

The score is then used to rerank only the Stage-1-untriggered pool.

No learned weight is introduced.

---

## Neighbor-3 outcome

The formal result always uses the stored B1 canonical trial outcomes:

```text
if Stage1 OR Stage2 trigger:
    final outcome = stored Neighbor-3 outcome
else:
    final outcome = stored G0 outcome
```

A triggered failure is never automatically labeled as rescued.

---

## Cost model

Refined-LR is required for Stage 1, so its diagnostic cost is paid on every trial:

```text
+2 objective evaluations / trial
```

Stage-2 Cost-0 signals add no objective evaluations.

For each trial:

```text
C_adaptive =
    C_G0
    + 2
    + I(Stage1 OR Stage2) * (C_N3 - C_G0)
```

This reuses already-computed G0 work.

---

## Main scientific comparison

PA5J-B3 is not compared only against G5 or G6.

For every staged point, the code finds:

> the lowest final failure probability achieved by **any** PA5J-B1 selective policy at no greater mean objective-evaluation cost.

The B1 comparator includes:

- G2 FiveBin
- G3 Entropy
- G4 Cost0_MaxRank
- G5 RefinedLR
- G6 All3_MaxRank

Define:

```text
gain_vs_best_B1 =
    best B1 failure probability at no-more cost
    - staged failure probability
```

Therefore:

```text
gain > 0
```

means the staged point improves upon the entire available B1 envelope at equal-or-lower cost.

This is a conservative discrete comparison; the code does not interpolate between B1 points.

---

## Primary endpoint

```text
Final catastrophic failure probability
    versus
Mean objective evaluations
```

The main figure shows:

- G0;
- Always Neighbor-3;
- best B1 non-dominated envelope;
- staged FiveBin envelope;
- staged Entropy envelope;
- staged Cost0_MaxRank envelope.

---

## Required reconstruction audits

### B1 reconstruction

For every Stage-1 budget:

```text
Stage-2 budget = 0
```

must reproduce B1 `G5_RefinedLR` exactly in:

- selected count;
- actual fallback fraction;
- final failure count;
- mean objective evaluations.

Any mismatch causes a hard stop.

### B2 reconstruction

For DenseRisk at the B2 overlapping anchors:

Stage-1 budgets:

```text
0.10, 0.20, 0.30, 0.50
```

and Stage-2 budgets:

```text
0.05, 0.10, 0.20, 0.30
```

the Stage-2 screening must reproduce B2 in:

- selected count;
- conditional actual screen fraction;
- residual failures selected.

Any mismatch causes a hard stop.

---

## Main outputs

### `pa5jb3_staged_sweep.csv`

Complete two-stage grid with:

- Stage-1 and Stage-2 nominal / actual budgets;
- tie information;
- total fallback fraction;
- final failure probability;
- Wilson CI;
- Stage-1 rescue;
- Stage-2 incremental rescue;
- induced / persistent failure;
- objective-evaluation cost;
- branch-error tails;
- cost-matched gain versus the B1 envelope.

### `pa5jb3_pareto_front.csv`

Non-dominated points from:

- G0 / Always N3;
- all B1 policies;
- all B3 staged policies.

### `pa5jb3_b1_reconstruction_audit.csv`

Exact Stage-1 reconstruction of B1 G5.

### `pa5jb3_b2_reconstruction_audit.csv`

Exact residual-screen reconstruction of B2.

### `pa5jb3_smoke_test.csv`

Formal software and metric checks.

### `RESULTS_EXP009_PA5JB3.txt`

This is the preferred file to upload back to the web Research Layer.

It contains:

- input / audit status;
- frozen design;
- baselines;
- the formal Pareto-front table;
- best staged result under several pre-registered normalized-cost caps;
- number and magnitude of staged improvements over the complete B1 envelope;
- Stage-2 signal comparison;
- induced / persistent-failure safety counts.

It does **not** automatically select an operating point or research conclusion.

---

## Figures

### Main Pareto figures

One figure per primary group:

```text
Best B1 envelope
vs
Staged FiveBin
vs
Staged Entropy
vs
Staged Cost0_MaxRank
```

plus G0 and Always N3.

### DenseRisk budget maps

For Paper1s and BeamDerived, heatmaps show final failure probability over:

```text
Stage-1 budget × Stage-2 conditional budget
```

for all three Stage-2 signal definitions.

---

## Expected result branches

### Branch A — Staged gate creates new Pareto points

At least one staged family has:

```text
gain_vs_best_B1 > 0
```

over a meaningful cost range.

Interpretation:

> B2's sequential-information hypothesis converts into actual algorithmic value.

### Branch B — Staged policy only matches B1

Residual information is real, but sequential allocation does not improve the overall cost–reliability frontier.

Interpretation:

> B2 is mechanistically interesting but not yet a method contribution.

### Branch C — One Stage-2 signal is robust across both apertures

A fixed Cost-0 residual signal consistently supplies most staged Pareto points.

Interpretation:

> a simple two-stage adaptive policy becomes plausible.

### Branch D — Best Stage-2 signal changes by aperture

Staging helps, but no single residual score is robust.

Interpretation:

> do not tune aperture-specific rules yet; investigate a more invariant residual confidence representation.

### Branch E — Staged gain appears only in DenseRisk

Stress-test benefit exists but representative rare-event benefit is weak.

Interpretation:

> method value may be robustness-oriented rather than average-case.

---

## What PA5J-B3 must not do

- no learned fusion;
- no new indicator mining;
- no truth physics;
- no post-hoc weight tuning;
- no final operating point;
- no DenseRisk prevalence interpreted as real-world failure probability;
- no interpolation invented to make a Pareto gain;
- no automatic method claim inside MATLAB.

---

## Run

Place these files in:

```text
...\code\exp09_physical_validation\
```

Files:

```text
config_exp09_pa5jb3_staged_gate.m
exp09_pa5jb3_staged_gate.m
PARAMETER_PROVENANCE_PA5JB3.csv
README_EXP009_PA5JB3.md
```

Run:

```matlab
exp09_pa5jb3_staged_gate
```

Expected output:

```text
...\results\exp09_physical_validation\
exp09_pa5jb3_staged_gate\
```

For the first Research-Layer review, normally upload only:

1. `RESULTS_EXP009_PA5JB3.txt`
2. the four `fig01_pareto_*.png` figures
3. the two dense-risk budget-map figures

Upload CSVs only if the first review exposes a question that needs trial/table-level inspection.
