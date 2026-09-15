# EXP009 / PA5J-B3-R2 — Shared-Policy Cross-Aperture Robustness Audit

## Status

**DESIGN FROZEN**

PA5J-B3-R1 showed that staged reliability allocation retains genuine but localized Pareto improvements after exhaustive deterministic single-stage threshold enumeration.

The next unresolved issue is robustness:

> Are those gains obtained only by choosing a different staged configuration for each aperture, or does the same staged rule work across Paper1s and BeamDerived?

PA5J-B3-R2 answers that question without introducing any new policy.

---

## Shared-policy definition

A shared staged configuration is the exact tuple:

```text
(Stage-2 signal, Stage-1 nominal budget, Stage-2 conditional budget)
```

The tuple must be identical for:

- DenseRisk / Paper1s
- DenseRisk / BeamDerived

No aperture-specific tuning is permitted inside the primary robustness metric.

---

## Primary evidence domain

Primary:

```text
dense_risk
```

Apertures:

```text
Paper1s
BeamDerived
```

For each shared configuration, PA5J-B3-R1 has already computed:

```text
new_dense_b1_gain
```

where a positive value means the B3 staged point has lower catastrophic-failure probability than **every attainable deterministic single-stage B1 point at no greater mean objective cost**.

---

## Robust gain

For one shared configuration:

```text
g_P = dense Paper1s new_dense_b1_gain
g_B = dense BeamDerived new_dense_b1_gain
```

Define:

```text
robust_min_gain = min(g_P, g_B)
```

Therefore:

```text
robust_min_gain > 0
```

means:

> the SAME staged configuration strictly beats each aperture's own exhaustive deterministic B1 frontier.

This is the primary B3-R2 criterion.

---

## Saved-failure count

The code also converts probability gain back into paired integer failure-count improvement:

```text
saved failures =
    dense-B1 comparator failure count
    - B3 staged failure count
```

This prevents a very small probability difference from being discussed without its underlying discrete count.

---

## Relative gain

For descriptive use:

```text
relative gain =
    absolute probability gain
    / dense-B1 comparator failure probability
```

This is reported only when the comparator failure probability is non-zero.

The primary criterion remains the absolute cross-aperture gain.

---

## Worst-case compute

For every shared configuration, record:

```text
max(normalized cost in Paper1s,
    normalized cost in BeamDerived)
```

A secondary robust candidate front is formed by:

- minimizing worst-aperture normalized cost;
- maximizing `robust_min_gain`.

This front is descriptive and does not select a deployment operating point.

---

## Stage-2 signals

No new score is introduced.

Frozen B3 choices:

- `FiveBin`
- `Entropy`
- `Cost0_MaxRank`

The experiment asks whether any of these can support one common staged configuration across both apertures.

---

## Original-grid role

Original-grid performance is **not used** to construct, rank, or define `robust_min_gain`.

After a configuration is identified as DenseRisk robust, the same tuple is inspected on:

- Original / Paper1s
- Original / BeamDerived

using the already completed B3-R1 dense-B1 audit.

This is only a rare-event consistency check.

The code reports whether a DenseRisk-robust shared configuration is:

- non-inferior on both Original apertures;
- strictly better on both Original apertures;
- mixed.

Because Original has only 38 / 17 G0 failures, these results must remain statistically modest.

---

## Cross-aperture concordance

The experiment computes Spearman rank correlation between:

```text
Dense Paper1s gain
```

and:

```text
Dense BeamDerived gain
```

for:

- all shared configurations;
- each Stage-2 signal separately.

This answers whether configurations that help one aperture tend to help the other, beyond the existence of a few lucky overlapping points.

---

## Required reconstruction audit

`pa5jb3r1_b3_vs_dense_b1.csv` is joined back to the original B3 staged sweep using:

```text
source
aperture_mode
stage2_signal
stage1_nominal_budget
stage2_conditional_nominal_budget
```

For every row, the following must match:

- B3 mean objective evaluations;
- B3 final failure probability;
- total actual fallback fraction.

Any mismatch is a hard stop.

---

## Main outputs

### `pa5jb3r2_shared_configs.csv`

One row per shared tuple, including:

- Paper1s / BeamDerived dense gain;
- `robust_min_gain`;
- relative gains;
- saved-failure counts;
- per-aperture cost;
- worst normalized cost;
- DenseRisk strict/noninferior classification;
- Original-grid consistency gains and classification;
- robust-front membership.

### `pa5jb3r2_signal_summary.csv`

Per Stage-2 signal:

- number of shared configs;
- number strict-positive in both apertures;
- number noninferior in both;
- maximum worst-aperture gain;
- maximum minimum saved-failure count;
- robust-front count;
- how many DenseRisk-robust configurations remain noninferior / strict on Original.

### `pa5jb3r2_cross_aperture_correlation.csv`

Gain concordance across apertures.

### `pa5jb3r2_input_join_audit.csv`

Exact B3-R1 ↔ B3 reconstruction audit.

### `pa5jb3r2_smoke_test.csv`

Formal metric checks.

### `RESULTS_EXP009_PA5JB3R2.txt`

Preferred Research-Layer upload.

---

## Figures

### Fig 1 — Dense gain scatter

```text
x = Paper1s dense gain
y = BeamDerived dense gain
```

The upper-right quadrant is the shared strict-positive region.

### Fig 2 — Robust-gain maps

For each Stage-2 signal:

```text
robust_min_gain(b1,b2)
```

This shows whether cross-aperture robustness occupies a coherent region or only isolated points.

### Fig 3 — Robust gain vs worst-case compute

Tests whether meaningful shared gain requires excessive compute.

### Fig 4 — Original consistency

Only DenseRisk strict-positive shared configurations are shown.

Original is not used to select them.

---

## Expected result branches

### Branch A — Clear shared robust region

Many configurations have:

```text
robust_min_gain > 0
```

and form a coherent region over nearby budgets.

Interpretation:

> staged reliability allocation has cross-aperture robustness within the current stress-test domain.

### Branch B — Only isolated shared-positive points

A few tuples work in both apertures, but neighboring configurations do not.

Interpretation:

> method value exists but the current budget parameterization is fragile; do not lock a deployment rule.

### Branch C — No strict shared configuration

The best configuration for one aperture hurts the other.

Interpretation:

> staged architecture is mechanism-valid but not yet aperture-invariant.

Do not choose separate aperture-specific thresholds as the final method without a stronger conditioning variable.

### Branch D — Shared DenseRisk gains exist and Original remains noninferior

Interpretation:

> strongest current evidence for a common staged policy family.

### Branch E — DenseRisk shared gains cost Original performance

Interpretation:

> robustness gain is stress-specific; further method design or an independent confidence representation is required.

---

## What B3-R2 must not do

- no new Stage-2 feature;
- no new budget values;
- no aperture-specific tuning inside the primary criterion;
- no use of Original for selecting the robust configuration;
- no physical truth variable;
- no final deployment threshold;
- no claim of held-out generalization.

This is an in-grid cross-aperture robustness audit.

---

## Run

Place:

```text
config_exp09_pa5jb3r2_shared_policy.m
exp09_pa5jb3r2_shared_policy.m
PARAMETER_PROVENANCE_PA5JB3R2.csv
README_EXP009_PA5JB3R2.md
```

into:

```text
...\code\exp09_physical_validation\
```

Run:

```matlab
exp09_pa5jb3r2_shared_policy
```

Expected output:

```text
...\results\exp09_physical_validation\
exp09_pa5jb3r2_shared_policy\
```

For the first Research-Layer review, upload:

1. `RESULTS_EXP009_PA5JB3R2.txt`
2. `fig01_dense_gain_scatter.png`
3. `fig02_robust_gain_maps.png`
4. `fig03_robust_gain_vs_cost.png`
5. `fig04_original_consistency.png`

CSV files are only needed if a specific table-level question remains.
