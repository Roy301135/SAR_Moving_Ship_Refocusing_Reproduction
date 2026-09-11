# EXP009-A3 / Pilot-01 — Operator-Induced Peak-Shift Test

## 1. Why A3 exists

EXP009-A2 showed:

- C0 Exact subtraction: high weak recovery;
- C1 Practical CLEAN with true q_strong: much lower recovery;
- C2 Practical CLEAN with estimated q_strong: almost identical to C1.

So q_strong estimation error is not the main cause in the current controlled case.

A2 also showed:

- strong-template projection drops strongly as CLEAN width grows;
- weak-template projection remains high;
- weak-q bias remains systematically negative.

This means that the weak component is not obviously being deleted, yet the q estimator is still shifted.

A3 therefore asks:

> Is the peak shift caused by direct filtering of the weak component, or by the *filtered strong residual* that remains after CLEAN?

---

## 2. Key conceptual improvement over A2

A2 used correlation with the original strong template.

But after notch filtering, the remaining strong residual can be severely reshaped.

Therefore:

```text
low corr(residual, original strong)
```

does **not** imply:

```text
little strong-residual energy remains
```

A3 measures the filtered strong residual directly because the synthetic ground truth is known.

The two important quantities are:

```text
||O{s_strong}||^2 / ||s_strong||^2
```

and

```text
||O{s_strong}||^2 / ||s_weak||^2
```

The second quantity is particularly important: even a small fraction of the original strong energy can still be a substantial fraction of the weak-component energy.

---

## 3. Fixed linear operator

A3 defines a fixed operator O_h:

```text
dechirp at true q_strong
-> FFT
-> notch a fixed strong FFT bin
-> IFFT
-> rechirp
```

The notch center is determined once from the noiseless strong-only signal.

Because the mask is fixed, O_h is linear. This allows the exact decomposition:

```text
O_h{s_strong + s_weak + n}
=
O_h{s_strong}
+
O_h{s_weak + n}
```

This is the main reason A3 can isolate the source of the peak shift.

---

## 4. Noiseless branches

### P0 — Weak only

```text
s_weak
```

Reference.

### P1 — Filtered weak only

```text
O_h{s_weak}
```

Tests whether the notch operator alone moves the weak q peak.

### P2 — Weak + filtered strong residual

```text
s_weak + O_h{s_strong}
```

Tests whether the filtered strong residual alone can shift the weak q peak.

### P3 — Combined fixed operator

```text
O_h{s_weak} + O_h{s_strong}
```

Equivalent to applying the fixed operator to the noiseless mixture.

---

## 5. Monte-Carlo branches

### D0 — Baseline

```text
s_weak + noise
```

### D1 — Operator only

```text
O_h{s_weak + noise}
```

If D1 ~= D0, the notch operator itself is not the dominant source.

### D2 — Strong residual only

```text
s_weak + noise + O_h{s_strong}
```

If D2 becomes biased/fails while D1 does not, the filtered strong residual is the main cause.

### D3 — Combined fixed operator

```text
O_h{s_weak + noise} + O_h{s_strong}
```

### D4 — Practical adaptive-notch CLEAN

This is the same practical CLEAN idea used in A2, with true q_strong, where the strongest FFT bin is selected from the mixture.

If D4 ~= D3, adaptive notch-center selection is not the main cause and the fixed-operator decomposition is a faithful explanation of the A2 mechanism.

---

## 6. Width sweep

A3 repeats D0-D3 for:

```text
h = 0, 1, 2, 3, 5
```

and records:

- weak recovery;
- signed q bias;
- RMSE / MAE;
- filtered strong residual energy;
- filtered strong residual energy relative to weak energy;
- weak energy removed by the operator.

---

## 7. Strongest expected outcome

The most informative result would be:

```text
D0 ~= D1
D2 ~= D3 ~= D4
D2 clearly worse than D0/D1
```

Then the interpretation is:

```text
direct filtering of weak/noise is not the main cause
        ↓
filtered strong residual is still large enough relative to the weak signal
        ↓
weak concentration landscape is perturbed
        ↓
weak q peak shifts
```

This would also explain why A2's strong-template correlation could be small while weak recovery was still degraded: the filtered strong residual no longer looks like the original strong template.

---

## 8. Another possible outcome

If:

```text
D1 already shifts strongly
```

then the notch operator directly reshapes the weak component / noise.

If:

```text
D3 differs strongly from D2
```

then direct weak filtering and strong residual interact nontrivially.

If:

```text
D4 differs strongly from D3
```

then adaptive notch-center selection contributes additional error.

---

## 9. Recommended placement

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09a3_peak_shift.m
    │       └── config_exp09a3.m
    └── results/
        └── exp09_pilot01/
            └── exp09a3_peak_shift/
```

---

## 10. Run

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09a3_peak_shift;
```

---

## 11. Outputs

```text
noiseless_branch_results.csv
operator_energy_results.csv
default_mc_trials.csv
default_mc_summary.csv
width_sweep_trials.csv
width_sweep_summary.csv
summary.txt
exp09a3_results.mat

fig01_noiseless_q_bias.png
fig02_operator_energy.png
fig03_default_mc_recovery.png
fig04_default_mc_bias.png
fig05_width_vs_recovery.png
fig06_width_vs_bias.png
fig07_residual_energy_vs_bias.png
fig08_example_concentration_curves.png
```

---

## 12. Do not over-claim yet

Even if A3 supports the filtered-strong-residual hypothesis, the result is still:

> mechanism-level evidence in the current controlled MC-LFM model.

The next step would be to test whether the mechanism is stable across amplitude ratio, q separation and SNR before calling it a general failure mechanism.
