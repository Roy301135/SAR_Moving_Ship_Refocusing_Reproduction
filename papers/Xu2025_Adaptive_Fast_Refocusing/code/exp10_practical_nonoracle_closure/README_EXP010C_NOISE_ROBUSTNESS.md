# EXP010-C — Frozen-Policy Additive-Noise Robustness

## 1. Purpose

This package implements the frozen EXP010-C noise protocol after deterministic closure of EXP010-B / B-R1.

Scientific question:

> As additive complex Gaussian noise degrades the practical strong-parameter estimate, where does the already-frozen reliability-gated sequential refocusing chain lose validity?

Primary causal chain:

```text
strong-referenced input SNR
→ practical strong-beta error
→ branch-recovery validity
→ weak-component recovery
```

This is **not** a sea-clutter simulation.

---

## 2. Files

- `config_exp10c_noise_robustness.m`
- `exp10c_noise_robustness.m`
- `EXP010C_NOISE_PROTOCOL_FREEZE_v1.0.md`
- `EXP010C_IMPLEMENTATION_NOTES.md`

Recommended placement:

```text
...\Xu2025_Adaptive_Fast_Refocusing\
    code\
        exp10_practical_nonoracle_closure\
            config_exp10c_noise_robustness.m
            exp10c_noise_robustness.m
            EXP010C_NOISE_PROTOCOL_FREEZE_v1.0.md
            EXP010C_IMPLEMENTATION_NOTES.md
```

The existing EXP010-A/B files remain untouched.

---

## 3. Run modes

### A. Required first run: implementation smoke

```matlab
cd('E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp10_practical_nonoracle_closure');

results = exp10c_noise_robustness("smoke");
```

Smoke mode is **engineering-only**:

- 12 frozen physical states / aperture;
- SNR = `[-10, 0, 20] dB`;
- MC = 1;
- same estimator, scheduler, N3, removal, evaluation semantics as formal mode.

Do **not** interpret smoke results scientifically.

Its purpose is to verify:

1. vectorized beta-search equivalence;
2. complex-AWGN injection / fixed seed ledger;
3. no-SNR-leak scheduler;
4. checkpoint / resume logic;
5. output tables / feedback bundle;
6. local runtime per noise case.

### B. Primary formal noise validation

After smoke is audited:

```matlab
results = exp10c_noise_robustness("dense_formal");
```

Formal DenseRisk protocol:

```text
SNR_s = {-10,-5,0,5,10,15,20} dB
MC = 10 / physical state / SNR
Paper1s physical states = 1122
BeamDerived physical states = 408
```

### C. Broad-regime sanity anchor

After DenseRisk:

```matlab
results = exp10c_noise_robustness("original_anchor");
```

Protocol:

```text
SNR_s = {-10,0,10,20} dB
MC = 5 / physical state / SNR
OriginalGrid = 4800 states / aperture
```

### D. `all_formal`

Supported, but not recommended after running `dense_formal` separately because it uses a separate checkpoint tree and would recompute DenseRisk.

---

## 4. Critical scheduler semantics

The frozen policy is a batch/fixed-compute scheduler.

For each:

```text
validation set × aperture
```

all tested SNR levels and Monte-Carlo realizations form **one heterogeneous processing pool**.

The scheduler sees only:

```text
refined_lr_asymmetry
fivebin_peak_fraction
```

and never receives:

```text
true SNR
true eta
Gamma
contrast
relative phase
risk-state label
future N3 outcome
```

Therefore EXP010-C does **not** perform a separate top-20% / top-10% ranking at each true SNR.

Per-SNR fallback fractions are evaluation outputs only.

---

## 5. Noise definition

For each clean strong component:

```math
P_s = mean(abs(s_strong).^2)
```

the expected complex-noise variance is

```math
sigma_n^2 = P_s / 10^(SNR_s/10).
```

Noise generation:

```matlab
noise = sqrt(sigma_n2/2) .* ...
    (randn(stream,1,N) + 1j*randn(stream,1,N));
```

Thus

```math
w[n] ~ CN(0, sigma_n^2),
```

with real and imaginary variances `sigma_n^2/2`.

Weak SNR is derived, not independently controlled.

Mixture SNR is reported, not used to set noise power.

---

## 6. Checkpoint / resume

EXP010-C is much heavier than EXP010-B.

The code therefore has two passes:

```text
PASS 1
noisy observation
→ practical beta
→ G0
→ Refined-LR / FiveBin

GLOBAL FROZEN SCHEDULER
→ top-20% Stage 1
→ residual top-10% Stage 2

PASS 2
regenerate exact same observation from seed
→ N3 / proposed decision
→ removal
→ weak recovery
→ truth-only evaluation
```

Checkpoint blocks are stored under:

```text
...\results\exp10_practical_nonoracle_closure\
    exp10c_noise_robustness\<run_mode>\checkpoints\
```

If MATLAB stops, rerunning the same command resumes completed blocks.

Do not change the config while reusing checkpoints. Signature mismatches deliberately raise an error.

---

## 7. Engineering acceleration

The frozen FrAc-style beta score is unchanged mathematically.

The scalar beta estimator from EXP010-B is retained for startup verification. Formal processing uses a vectorized batch implementation of the same:

```text
lag product
→ zero-padded FFT
→ same linear interpolation
→ same score accumulation
→ same beta-grid argmax
```

Before any experiment, the program compares batched and inherited scalar outputs. If they disagree beyond tolerance, the run stops.

This is an engineering acceleration only, not a method modification.

---

## 8. Main outputs

Top-level output directory:

```text
...\results\exp10_practical_nonoracle_closure\
    exp10c_noise_robustness\<run_mode>\
```

Important compact outputs:

```text
EXP010C_FEEDBACK_BUNDLE_<run_mode>.txt
method_summary_by_snr_all.csv
paired_outcomes_by_snr_all.csv
stage_allocation_by_snr_all.csv
risk_direction_by_snr_all.csv
upstream_errors_by_snr_all.csv
noise_validity_summary_all.csv
oracle_firewall_audit_all.csv
run_inventory.csv
overall_status.csv
```

Figures:

```text
fig01_branch_failure_vs_snr.png
fig02_upstream_beta_error_vs_snr.png
fig03_weak_feasible_vs_snr.png
fig04_fallback_cost_vs_snr.png
fig05_risk_auc_vs_snr.png
```

Case-level CSVs remain inside each job folder for traceability.

---

## 9. What to send back

After the smoke run, normally upload only:

```text
EXP010C_FEEDBACK_BUNDLE_smoke.txt
```

No scientific interpretation is made from smoke results.

After `dense_formal`, upload:

```text
EXP010C_FEEDBACK_BUNDLE_dense_formal.txt
fig01_branch_failure_vs_snr.png
fig02_upstream_beta_error_vs_snr.png
fig05_risk_auc_vs_snr.png
```

The raw CSV/MAT/checkpoint files stay local unless a code audit becomes necessary.

---

## 10. Frozen no-retuning rule

Noise results must not be used to change:

- Refined-LR definition or risk direction;
- FiveBin definition or risk direction;
- `b1=0.20`;
- `b2=0.10`;
- Neighbor-3 radius;
- removal window = 3 bins;
- SNR-specific or aperture-specific policy.

If performance degrades at low SNR, report a validity boundary.

Do not expand to Neighbor-5.
