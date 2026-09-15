# EXP009 / PA5J-B0

## Failure-Conditional Indicator Complementarity Audit

The authoritative experiment contract is the frozen `PA5JB0_EXPERIMENT_DESIGN.md` supplied by Research Layer. This README documents only the local engineering interface; it does not replace or reinterpret that contract.

## Inputs

The implementation reads the already reconstructed PA5J-A G0 indicator tables:

```text
results/exp09_physical_validation/exp09_pa5ja_indicator_discovery/
  pa5ja_indicator_trials_original.csv
  pa5ja_indicator_trials_dense_risk.csv
```

The formal analysis does not rerun PA5I, PA5I-R1, PA5J-A, or Neighbor-3. It requires the inherited binary `catastrophic_branch_failure` label and the fixed indicator fields `refined_lr_asymmetry`, `fivebin_peak_fraction`, and `local_entropy5`.

## Modes

```matlab
% Read-only input schema, unique-trial, and complete-case audit.
audit = exp09_pa5jb0_complementarity_audit('preflight');

% Formal metric export only after Research Layer authorization.
results = exp09_pa5jb0_complementarity_audit('formal');
```

Preflight creates no output directory. Formal mode writes to:

```text
results/exp09_physical_validation/
  exp09_pa5jb0_failure_conditional_indicator_complementarity/
```

## Stop conditions

The implementation stops without deduplication if required columns are absent, labels are not binary, source/aperture groups are unknown, or either `source + trial_id` or the physical composite trial key is non-unique.

The three risk directions are fixed to `high`, `low`, and `high`, respectively. Ranking is tie-inclusive and never uses trial ID, row order, or randomness to resolve cutoff ties.

## Smoke test

```matlab
test_exp09_pa5jb0_smoke
```

The smoke test checks numerical helpers and frozen direction/budget invariants only. It does not read the physical trial tables, run a sweep, call Neighbor-3, or make a research conclusion.
