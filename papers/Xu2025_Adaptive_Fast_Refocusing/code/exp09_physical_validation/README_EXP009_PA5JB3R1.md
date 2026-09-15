# EXP009 / PA5J-B3-R1 — Dense Single-Stage Comparator Audit

## Status

**DESIGN FROZEN**

This is not a new method experiment.

PA5J-B3 showed staged policies below the **sampled** PA5J-B1 envelope at many cost points. However, B1 used only 11 nominal fallback budgets, whereas B3 generated a much denser two-dimensional set of cost points.

PA5J-B3-R1 removes that comparison-resolution confounder.

---

## Research Question

> After enumerating every attainable deterministic tie-inclusive threshold of every frozen B1 single-stage policy, do PA5J-B3 staged policies still create genuinely new cost–reliability Pareto points?

---

## Why this audit is necessary

The old B1 budget grid was:

```text
0
0.005
0.01
0.02
0.05
0.10
0.20
0.30
0.50
0.75
1.00
```

A staged B3 point can naturally land at a cost between two B1 grid points.

Therefore:

```text
B3 better than the sampled B1 envelope
```

does not by itself prove:

```text
B3 better than the underlying single-stage policy family.
```

B3-R1 resolves each single-stage policy down to every deterministic threshold set actually attainable by its stored score.

---

## Frozen B1 policies

No policy definition changes.

- `G2_FiveBin`
- `G3_Entropy`
- `G4_Cost0_MaxRank`
- `G5_RefinedLR`
- `G6_All3_MaxRank`

Risk directions, percentile fusion, and diagnostic costs are exactly inherited from PA5J-B1.

---

## Exact dense comparator

For each:

```text
primary group × B1 policy
```

the code:

1. reconstructs the frozen risk score;
2. finds every distinct score value;
3. uses each value as a tie-inclusive cutoff;
4. evaluates the resulting deterministic trigger set;
5. also adds the no-trigger endpoint.

Therefore each nested trigger set allowed by the frozen score and tie rule is represented.

There is no arbitrary budget grid.

There is no random tie break.

There is no interpolation.

---

## Cost model

Identical to B1.

For Cost-0 policies:

```text
C_i =
    C_G0,i
    + trigger_i * (C_N3,i - C_G0,i)
```

For Refined-LR / All3:

```text
C_i =
    C_G0,i
    + 2
    + trigger_i * (C_N3,i - C_G0,i)
```

---

## Required reconstruction audit

Every original B1 sampled point must appear exactly among the dense endpoints.

The audit requires equality in:

- selected count;
- actual trigger fraction;
- mean objective evaluations;
- final failure count.

Any mismatch is a hard stop.

This proves that B3-R1 expands B1 resolution without changing B1 semantics.

---

## B3 comparison

For each existing B3 staged point at cost:

```text
C_B3
```

find:

```text
min P_F
```

over **all attainable dense B1 points** satisfying:

```text
C_B1 <= C_B3
```

Then:

```text
new_dense_B1_gain =
    best dense-B1 P_F at no greater cost
    - B3 P_F
```

Interpretation:

- `> 0`: B3 strictly beats every attainable deterministic B1 endpoint at no greater cost;
- `= 0`: B3 matches the dense single-stage frontier;
- `< 0`: a dense single-stage threshold is better.

---

## Stronger combined-front criterion

The experiment also constructs the non-dominated front from:

- all dense B1 points;
- all B3 staged points;
- G0;
- Always Neighbor-3.

A B3 point surviving this combined front is a direct staged Pareto contribution under the current fixed policy families.

---

## Main outputs

### `pa5jb3r1_dense_b1_points.csv`

Every attainable single-stage endpoint.

### `pa5jb3r1_dense_b1_front.csv`

Non-dominated dense B1 frontier.

### `pa5jb3r1_b1_reconstruction_audit.csv`

Proof that every old sampled B1 point is reproduced exactly.

### `pa5jb3r1_b3_vs_dense_b1.csv`

Every B3 point with:

- old sampled-B1 gain;
- new dense-B1 gain;
- amount of apparent gain removed by the dense audit;
- relation to the exact deterministic B1 frontier.

### `pa5jb3r1_combined_front.csv`

Non-dominated points from dense B1 + B3 + baselines.

### `pa5jb3r1_smoke_test.csv`

Formal checks.

### `RESULTS_EXP009_PA5JB3R1.txt`

Preferred Research-Layer upload.

It summarizes:

- audit status;
- dense-front sizes;
- how many staged points remain strictly better;
- how many old gains disappear;
- strongest surviving staged gain in each group;
- B3 membership on the combined Pareto front;
- cost-cap comparisons.

---

## Figures

One figure per primary group shows:

- old sampled B1 envelope;
- exact dense B1 frontier;
- all B3 staged points;
- B3 points that survive the combined front;
- G0;
- Always Neighbor-3.

These figures directly show whether the earlier staged advantage survives comparator densification.

---

## Expected result branches

### Branch A — Staged advantage survives strongly

Many B3 points remain strictly below the dense B1 frontier and survive the combined front.

Interpretation:

> staged reliability allocation is a genuine method-level Pareto improvement for the frozen policy family.

### Branch B — Advantage survives but shrinks

Some B3 points remain new Pareto points, but much of the old sampled-grid gain disappears.

Interpretation:

> staging is useful, but the coarse B1 grid had exaggerated its apparent advantage.

### Branch C — Advantage disappears

Dense B1 thresholds match or dominate B3 everywhere.

Interpretation:

> residual complementarity is mechanistically real, but staging does not improve the exact single-stage cost–reliability frontier.

Do not force a staged-method claim.

### Branch D — Advantage survives only in DenseRisk

Interpretation:

> staging is primarily a hard-case robustness mechanism.

### Branch E — Advantage also survives materially in Original

Interpretation:

> staging affects both representative rare-event performance and stress-test robustness.

Original still requires rare-event statistical caution because failure counts are small.

---

## What B3-R1 must not do

- no new gate feature;
- no new staged design;
- no learned fusion;
- no physical sweep;
- no threshold tuning;
- no interpolation added to make either side look better;
- no automatic publication claim.

---

## Run

Place:

```text
config_exp09_pa5jb3r1_dense_b1.m
exp09_pa5jb3r1_dense_b1.m
PARAMETER_PROVENANCE_PA5JB3R1.csv
README_EXP009_PA5JB3R1.md
```

into:

```text
...\code\exp09_physical_validation\
```

Run:

```matlab
exp09_pa5jb3r1_dense_b1
```

Expected result directory:

```text
...\results\exp09_physical_validation\
exp09_pa5jb3r1_dense_b1_audit\
```

For first review, upload only:

1. `RESULTS_EXP009_PA5JB3R1.txt`
2. the four `fig01_dense_audit_*.png` figures

Only upload CSVs if the result exposes a specific question requiring table-level inspection.


## Implementation note

The dense comparator is implemented cumulatively over complete score-tie
classes. It sorts each policy score once and then advances one attainable
tie-inclusive threshold at a time. This avoids rerunning an O(N) full-trial
evaluation for every cutoff.

The Pareto audit also uses an ordered 2-D sweep rather than an O(N^2)
pairwise dominance loop. These are engineering optimizations only; they do
not change the frozen single-stage policy semantics.

The formal smoke tests additionally verify that the dense-audited staged
gain can never exceed the old sampled-B1 gain, because every sampled B1
endpoint must be contained in the dense comparator.


## FIX1 — MATLAB block-structure hotfix

FIX1 corrects two implementation-only block-structure errors in the first
B3-R1 delivery:

1. `build_dense_b1_front()` now closes both nested `for` loops before
   constructing the output table.
2. An accidental duplicate `end` after `pareto_mask()` was removed.

No research design, score definition, cost model, dense-comparator rule,
tie handling, or output metric has changed.
