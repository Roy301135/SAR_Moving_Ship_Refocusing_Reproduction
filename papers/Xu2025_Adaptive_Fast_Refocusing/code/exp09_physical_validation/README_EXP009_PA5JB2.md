# EXP009 / PA5J-B2 — Residual-Failure / Policy-Crossover Anatomy


## FIX1 note

This package includes one engineering-only MATLAB hotfix:

- `unique_state_values()` returns scalar states inside a cell array.
- The physical-anatomy loop now uses `states{iu}` rather than `states(iu)`.
- `state_mask()` and `state_to_string()` also defensively unwrap scalar cells.

This does **not** change the frozen PA5J-B2 research design, budgets, risk
directions, metrics, or interpretation protocol.


## Status

**DESIGN FROZEN**

PA5J-B1 has already established that selective Neighbor-3 can produce genuine cost–reliability Pareto improvements. PA5J-B2 does not add another recovery method. It explains the structure behind the observed policy crossover.

---

## Research Questions

### RQ1 — Residual Cost-0 information

After `G5_RefinedLR` removes the most obvious catastrophic failures, do:

- `fivebin_peak_fraction`
- `local_entropy5`
- `Cost0_MaxRank`

still distinguish the remaining failures inside the G5-untriggered pool?

### RQ2 — Residual physical anatomy

Which physical states concentrate in the G5 residual failure tail?

Particular attention is paid to:

- relative phase;
- `Gamma_PA4`;
- fractional-bin offset `eta`;
- weak/strong contrast;
- velocity separation;
- strong-velocity side.

These variables are **post-hoc interpretation metadata only**. They must never enter a gate score.

### RQ3 — Why does naive All3 fusion cross over?

At the same nominal fallback budget, compare:

- failures caught by G5 but displaced out of G6;
- failures missed by G5 but promoted into G6;
- promoted/demoted non-failures.

This directly tests whether the low-budget weakness of `All3_MaxRank` comes from rank displacement rather than absence of complementary information.

---

## Primary scope

B2 is intentionally focused on `dense_risk`.

Reason:

- the B1 G5 plateau and G5/G6 policy crossover are visible there;
- Original-grid catastrophic failures are too sparse for detailed mechanism stratification;
- Original remains the representative reliability reference from B1.

This is a pre-specified mechanism study, not a new estimate of real-world failure prevalence.

Primary aperture groups:

- `Paper1s`
- `BeamDerived`

---

## G5 anchor budgets

Frozen before running B2:

```text
0.10
0.20
0.30
0.50
```

Interpretation:

- `0.10 / 0.20 / 0.30`: primary low-to-mid budget anchors;
- `0.50`: one pre-registered late-budget reference to inspect the onset of Cost-0 complementarity.

No anchor is a deployment operating point.

---

## Residual second-stage audit

Inside the trials **not triggered by G5**, Cost-0 signals are evaluated at:

```text
0.05
0.10
0.20
0.30
```

of the remaining pool.

This is an information audit only.

It does not create or claim a new hierarchical method.

Metrics:

- AUC within the G5-untriggered pool;
- conditional residual-failure capture;
- precision;
- actual extra trigger fraction;
- Wilson confidence intervals.

---

## Frozen score definitions

Higher score always means higher risk.

### FiveBin

```text
score = -fivebin_peak_fraction
```

### Entropy

```text
score = local_entropy5
```

### RefinedLR

```text
score = refined_lr_asymmetry
```

### Cost0_MaxRank

Within each aperture group, convert FiveBin and Entropy to tie-preserving empirical risk percentiles:

```text
Cost0_MaxRank = max(R_fivebin, R_entropy)
```

### All3_MaxRank

```text
All3_MaxRank = max(R_fivebin, R_entropy, R_refinedLR)
```

No learned weight or post-hoc tuning is introduced.

---

## Residual definition

For G5 budget `b`:

```text
G5 captured failure = G0 failure AND G5 trigger
G5 residual failure = G0 failure AND NOT G5 trigger
```

This definition is independent of the Neighbor-3 outcome.

PA5J-B1 already established the recovery behavior; B2 studies the **gate-observability structure**.

---

## B1 reconstruction audit

PA5J-B2 independently reconstructs G5 and G6 trigger sets.

For every aperture and anchor budget it must exactly match B1:

- selected count;
- actual trigger fraction;
- missed G0 failure count.

Any mismatch causes a hard stop.

This prevents B2 from silently changing:

- tie handling;
- risk direction;
- percentile fusion;
- budget semantics.

---

## Main outputs

### `pa5jb2_residual_summary.csv`

For each aperture × G5 anchor:

- total G0 failures;
- G5 captured failures;
- G5 residual failures;
- residual fraction;
- Wilson interval;
- residual prevalence inside the untriggered candidate pool.

### `pa5jb2_residual_cost0_screen.csv`

For each residual pool:

- Cost-0 AUC;
- second-stage nominal/actual screen budget;
- conditional residual capture;
- precision;
- confidence intervals.

### `pa5jb2_policy_displacement.csv`

Direct G6-vs-G5 set anatomy:

- G5-caught / G6-lost failures;
- G5-missed / G6-gained failures;
- net failure-capture difference;
- promoted/demoted non-failures.

### `pa5jb2_physical_anatomy.csv`

Denominator-aware post-hoc anatomy for:

- phase;
- Gamma;
- eta;
- contrast;
- delta-v;
- strong side.

For each state it reports both raw counts and residual enrichment.

### `pa5jb2_trial_membership.csv`

Trial-level membership for later Research-Layer inspection.

### `pa5jb2_reconstruction_audit.csv`

Exact audit against B1.

### `pa5jb2_smoke_test.csv`

Formal software/metric checks.

---

## Figures

The package generates:

1. G5 residual fraction versus trigger fraction;
2. Cost-0 AUC inside the G5-untriggered pool;
3. G6-vs-G5 failure rank displacement;
4. phase–eta and phase–Gamma residual-probability heatmaps at G5 budgets 0.20 and 0.30.

The heatmaps plot:

```text
P(G5 residual | G0 failure, physical state)
```

rather than raw residual counts, so grid composition is not silently confused with mechanism.

---

## Expected Result Branches

### Branch A — Residual Cost-0 information disappears

Residual-pool AUC approaches 0.5 and second-stage capture is near budget chance level.

Interpretation:

> B1's apparent late Cost-0 benefit was mainly due to global budget expansion rather than a distinct residual signature.

### Branch B — Cost-0 remains informative after G5

Residual-pool AUC remains above chance and Cost-0 produces failure enrichment within the G5-untriggered pool.

Interpretation:

> the residual tail carries an observable signature different from local refined asymmetry.

This would justify a later, separate hierarchical-policy experiment.

### Branch C — Low-budget G6 dilution is caused by rank displacement

At low budgets:

```text
G5-caught / G6-lost failures
>
G5-missed / G6-gained failures
```

while the balance approaches or reverses later.

Interpretation:

> complementary information exists, but max-rank fusion spends scarce early budget on the wrong risk layer.

### Branch D — Residuals are concentrated in phase / Gamma, not only eta

Residual enrichment appears in coherent-phase / resolution states across a broad eta range.

Interpretation:

> the tail cannot be reduced to the earlier half-bin fence effect alone.

### Branch E — Residuals collapse to eta alone

Residual probability is primarily controlled by a narrow eta region regardless of phase / Gamma.

Interpretation:

> the apparent global-ambiguity story must be reconsidered in favor of a remaining finite-grid mechanism.

---

## What B2 must not do

- no new indicator search;
- no learned classifier;
- no hand-tuned fusion weights;
- no final threshold;
- no new Neighbor-3 run;
- no use of truth physics for ranking;
- no claim that dense-risk prevalence is real system prevalence;
- no automatic declaration of a research branch inside MATLAB.

---

## Run

Place the following files in the physical-validation code directory:

```text
config_exp09_pa5jb2_residual_anatomy.m
exp09_pa5jb2_residual_anatomy.m
PARAMETER_PROVENANCE_PA5JB2.csv
README_EXP009_PA5JB2.md
```

Run:

```matlab
exp09_pa5jb2_residual_anatomy
```

Expected result directory:

```text
results\exp09_physical_validation\
exp09_pa5jb2_residual_anatomy\
```

Bring back:

- `PA5JB2_FORMAL_METRIC_SUMMARY.txt`
- `pa5jb2_residual_summary.csv`
- `pa5jb2_residual_cost0_screen.csv`
- `pa5jb2_policy_displacement.csv`
- `pa5jb2_physical_anatomy.csv`
- `pa5jb2_reconstruction_audit.csv`
- `pa5jb2_smoke_test.csv`
- all generated figures

for Research-Layer interpretation.
