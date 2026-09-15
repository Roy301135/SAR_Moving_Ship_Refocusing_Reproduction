# EXP010-C Implementation Notes

## Status

**IMPLEMENTED — AWAITING SMOKE AUDIT**

EXP010-B deterministic experiments are closed. EXP010-C implements the frozen additive-noise validation protocol without changing the scientific method.

## Why a smoke run still exists

The smoke run is not another research experiment and does not reopen parameter design.

EXP010-C introduces three engineering changes relative to EXP010-B:

1. seeded complex-noise generation;
2. heterogeneous-SNR global rank scheduling;
3. checkpointed two-pass execution with a vectorized equivalent beta-search backend.

Therefore a small implementation smoke is required before the formal ~10^5-scale runs.

## Oracle / SNR firewall

The online path is split explicitly:

```text
X noisy
→ extract_online_features_exp10c(X, case_id, proc, cfg)
→ apply_frozen_scheduler_exp10c(O, cfg)
→ run_online_downstream_exp10c(X, O, proc, cfg)
```

No function above receives:

```text
truth table
SNR labels
Gamma
contrast
relative phase
risk-state identity
```

Truth and SNR metadata enter only in `evaluate_noise_chunk`.

The output `online_features_and_scheduler.csv` is audited for forbidden field names.

## Natural-batch interpretation under noise

A separate scheduler per SNR would leak the simulation's true SNR stratum into resource allocation and would violate the pre-existing policy freeze.

EXP010-C therefore ranks all cases jointly within each known processing configuration:

```text
DenseRisk × Paper1s
DenseRisk × BeamDerived
OriginalGrid × Paper1s
OriginalGrid × BeamDerived
```

The SNR composition is heterogeneous and hidden from the scheduler.

This makes per-SNR fallback rate an **observed allocation outcome**, not a prescribed budget.

## Runtime strategy

Formal noise validation is much heavier than EXP010-B.

Run sequence:

```text
smoke
→ audit implementation + seconds/case
→ dense_formal
→ audit primary noise boundary
→ original_anchor
```

Do not launch `all_formal` before auditing the smoke runtime.

Checkpoint files permit exact restart with the same seed ledger.

## Scientific outputs to prioritize

The three central noise results are:

1. `strong_beta_error / W_beta` versus SNR;
2. branch catastrophe / paired rescue-harm versus SNR;
3. weak waveform feasibility versus SNR.

Supporting diagnostics:

- Stage-1 / Stage-2 directional AUC;
- fallback fraction;
- normalized branch cost;
- persistent N3 failures.

The intended causal interpretation is:

```text
noise
→ upstream strong-beta degradation
→ conditional Neighbor-3 validity degradation
→ branch reliability
→ weak recovery
```

Do not interpret AWGN as maritime clutter.
