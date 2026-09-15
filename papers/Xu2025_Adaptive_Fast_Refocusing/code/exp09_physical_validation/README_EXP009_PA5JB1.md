# EXP009 / PA5J-B1 — Selective Neighbor-3 Cost–Reliability Pareto

## Status

Research design frozen for the next experiment after PA5J-B0.

This package is the MATLAB implementation for:

> Can PA5J-A/B0 internal unreliability diagnostics selectively invoke Neighbor-3 and create a better catastrophic-failure / objective-evaluation tradeoff than G0 or Always Neighbor-3?

It does **not** choose a final threshold or deployment operating point.

---

## Upstream artifacts

The code reads four exact artifacts:

1. `pa5ja_indicator_trials_original.csv`
2. `pa5ja_indicator_trials_dense_risk.csv`
3. `pa5i_trials.csv`
4. `pa5i_r1_dense_eta_trials.csv`

The uploaded copies were audited before this package was written:

- PA5I original: 48,000 rows = 9,600 trials × 5 methods.
- PA5I-R1 dense: 7,650 rows = 1,530 trials × 5 methods.
- Both contain `G0_OriginalTop1` and `G1_Neighbor3`.
- Physical identity fields are unique within each method.
- PA5J-A G0 branch error and catastrophic labels match PA5I / PA5I-R1 G0.
- In the supplied upstream data, Neighbor-3 has zero catastrophic failures:
  - Original: G0 55 failures → Neighbor-3 0 failures.
  - Dense-risk: G0 539 failures → Neighbor-3 0 failures.
- No G0-success trial is turned into a Neighbor-3 catastrophic failure in those files.
- Trialwise `n_objective_evals(Neighbor3) >= n_objective_evals(G0)`.

The MATLAB code audits these facts again during the formal run instead of assuming them.

---

## Frozen policy family

Five selective policies are compared.

### G2 — FiveBin

Risk score from `fivebin_peak_fraction`.

Frozen direction:

`low value -> high risk`

No extra objective evaluation.

### G3 — Entropy

Risk score from `local_entropy5`.

Frozen direction:

`high value -> high risk`

No extra objective evaluation.

### G4 — Cost0_MaxRank

Within each primary group:

1. convert FiveBin and Entropy to tie-preserving empirical risk percentiles;
2. use their pointwise maximum.

This is a parameter-free OR-like Cost-0 fusion.

### G5 — RefinedLR

Risk score from `refined_lr_asymmetry`.

Frozen direction:

`high value -> high risk`

Diagnostic cost:

`+2 objective evaluations per trial`

because the score requires the two extra left/right evaluations identified in PA5J-A.

### G6 — All3_MaxRank

Convert all three signals to within-group empirical risk percentiles and use their pointwise maximum.

No learned weight is introduced.

Because this policy uses `refined_lr_asymmetry`, it also pays:

`+2 objective evaluations per trial`.

---

## Primary groups

Ranking is performed independently inside:

- `original_grid × Paper1s`
- `original_grid × BeamDerived`
- `dense_risk × Paper1s`
- `dense_risk × BeamDerived`

This experiment does not perform fixed-threshold transfer across groups.

---

## Frozen fallback budgets

`0, 0.005, 0.01, 0.02, 0.05, 0.10, 0.20, 0.30, 0.50, 0.75, 1.00`

Selection is tie-inclusive.

The code therefore saves both nominal and actual fallback fractions.

No trial ID or row order is allowed to break a cutoff tie.

---

## Final adaptive outcome

For trial `i`:

```text
if triggered:
    final outcome = stored Neighbor-3 outcome
else:
    final outcome = stored G0 outcome
```

Therefore a triggered G0 failure is **not automatically counted as rescued**.

The code separately records:

- rescued G0 failures;
- triggered failures that persist after Neighbor-3;
- induced Neighbor-3 failures;
- G0 failures missed by the gate.

---

## Objective-evaluation cost model

The gate is based on G0 state, so G0 is always paid first.

For Cost-0 policies:

```text
C_i = C_G0,i + trigger_i * (C_N3,i - C_G0,i)
```

For policies using `refined_lr_asymmetry`:

```text
C_i = C_G0,i + 2 + trigger_i * (C_N3,i - C_G0,i)
```

This reuses already-computed G0 work when expanding to Neighbor-3.

It does **not** count the whole Neighbor-3 run on top of an already completed G0 run.

The implementation checks that the stored Neighbor-3 objective-evaluation count is never below the matching G0 count.

The normalized cost is:

```text
(mean adaptive cost - mean G0 cost)
-----------------------------------
(mean Always-N3 cost - mean G0 cost)
```

A Refined-LR policy may therefore end slightly above 1 at full fallback because it pays the extra diagnostic evaluations on every trial.

---

## Main metrics

Primary:

- final catastrophic failure probability;
- mean objective evaluations.

Secondary:

- rescued fraction of G0 failures;
- induced failure rate;
- persistent failure after fallback;
- q95 / q99 / q99.9 final branch error;
- maximum final branch error;
- Wilson 95% interval of final failure probability;
- actual fallback fraction;
- tie inflation.

The key research figure is:

> final catastrophic failure probability vs mean objective evaluations

with G0 and Always Neighbor-3 shown as baseline points.

---

## Run

Place:

- `config_exp09_pa5jb1_selective_n3.m`
- `exp09_pa5jb1_selective_n3_pareto.m`

in:

```text
...\code\exp09_physical_validation\
```

Run:

```matlab
exp09_pa5jb1_selective_n3_pareto
```

Expected output directory:

```text
...\results\exp09_physical_validation\
    exp09_pa5jb1_selective_n3_pareto\
```

---

## Main outputs

- `pa5jb1_canonical_trials.csv`
- `pa5jb1_input_audit.csv`
- `pa5jb1_cost_model_audit.csv`
- `pa5jb1_baselines.csv`
- `pa5jb1_policy_sweep.csv`
- `pa5jb1_tie_audit.csv`
- `pa5jb1_smoke_test.csv`
- `PA5JB1_FORMAL_METRIC_SUMMARY.txt`
- separate primary-group figures under `figures\`

The summary intentionally exports facts only.

It does not automatically announce which research branch is supported.

---

## STOP conditions

Do not reinterpret or silently repair any of the following:

- PA5J-A and PA5I G0 outcomes disagree;
- physical trial identity is not unique;
- a trial cannot be uniquely joined;
- required schema is missing;
- complete-case row count changes;
- Neighbor-3 cost is below G0 cost for any matched trial;
- zero/full-budget behavior fails;
- stored failure labels are inconsistent.

These require research / engineering review before a formal result is accepted.
