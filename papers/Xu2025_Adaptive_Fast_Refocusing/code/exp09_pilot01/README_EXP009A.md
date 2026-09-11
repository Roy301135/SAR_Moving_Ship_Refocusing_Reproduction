# EXP009-A / Pilot-01 — Oracle Ladder

## 1. Purpose

This is the first controlled mechanism experiment for EXP009.

It asks only:

> **Where does weak-component failure first enter the sequential MC-LFM chain?**

The experiment intentionally disables spatial tracking and does **not** yet attempt to build a new adaptive method.

---

## 2. Why the code is self-contained

The exact function signatures of the existing Wang/Xu project FrFT/FrAc utilities are not part of this code package.

Therefore EXP009-A uses a self-contained **matched-chirp concentration search**:

`candidate q -> dechirp -> FFT -> maximum spectral concentration`

This is a controlled FrFT/FrAc-like mechanism proxy. It is used to validate the Oracle Ladder before integrating the exact project FrAc backend.

Do **not** describe this file as a reproduction of Xu 2025 AFRA.

---

## 3. Ladder definition

### L0 — Oracle-Exact

- true strong component;
- exact strong subtraction;
- full weak-q search.

Measures intrinsic weak-component detectability at the selected SNR.

### L1 — Q-Error-Only

- estimate strong q from the noisy mixture;
- keep strong amplitude / center frequency / phase oracle-known;
- reconstruct the strong component with only q replaced by q_hat;
- subtract and perform a full weak-q search.

Difference from L0 isolates the effect of strong-q estimation error.

### L2 — Practical-CLEAN-Full

- estimate strong q;
- dechirp at q_hat;
- FFT;
- notch the strongest spectral bin and neighboring bins;
- IFFT and rechirp;
- perform a full weak-q search.

Difference from L1 measures the practical extraction / residual-contamination penalty.

### L3 — Practical-CLEAN-Local-Valid

- uses exactly the same L2 residual;
- weak q is searched only in a narrow interval around a **valid synthetic prior**.

EXP009-A deliberately sets local prior bias to zero. Therefore L3 is **not** yet a tracking-stress experiment. It tests whether a correct local prior can reduce candidate evaluations without losing weak recovery.

---

## 4. Default controlled case

- N = 512
- Monte Carlo = 100
- mixture-referenced SNR = 3 dB
- q_strong = 1.420
- q_weak = 1.470
- A_weak / A_strong = 0.40
- full q interval = [1.340, 1.540]
- q step = 0.001
- success threshold = |q_hat_weak - q_weak| <= 0.003
- practical CLEAN notch halfwidth = 1 FFT bin
- local halfwidth = 0.015
- local prior bias = 0

Every ladder level uses the **same noise realization within each Monte-Carlo trial**.

---

## 5. Recommended placement

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09a_oracle_ladder.m
    │       └── config_exp09a.m
    └── results/
        └── exp09_pilot01/
            └── exp09a_oracle_ladder/
```

Place the two `.m` files in the same `exp09_pilot01` directory.

---

## 6. Run

In MATLAB:

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09a_oracle_ladder;
```

---

## 7. Outputs

The code automatically generates:

```text
results/exp09_pilot01/exp09a_oracle_ladder/
├── trial_metrics.csv
├── summary.csv
├── cost_summary.csv
├── summary.txt
├── exp09a_results.mat
├── fig01_recovery_rates.png
├── fig02_weak_q_error.png
├── fig03_residual_correlations.png
└── fig04_example_concentration_curves.png
```

### Important columns in `trial_metrics.csv`

- strong q estimate and error;
- weak q estimate for L0-L3;
- success/failure for L0-L3;
- L2 residual-energy ratio;
- `corr(r2,strong)`;
- `corr(r2,weak)`;
- L2 peak / second-peak ratio;
- L2 peak prominence;
- L2 peak curvature;
- L3 distance to local-search boundary.

These quantities are preserved for the later reliability-predictability experiment.

---

## 8. Reasonable expected result

The experiment is a mechanism test, so exact numbers are **not** success criteria.

With the default configuration, a numerical sanity check of the same model suggests the following approximate behavior:

| Level | Expected weak recovery |
|---|---:|
| L0 Oracle-Exact | about 0.85–0.95 |
| L1 Q-Error-Only | close to L0, roughly 0.80–0.95 |
| L2 Practical-CLEAN-Full | roughly 0.55–0.75 |
| L3 Practical-CLEAN-Local-Valid | usually close to L2, sometimes slightly better |

The expected qualitative interpretation is more important:

1. **L0 high**  
   The weak component is intrinsically recoverable in this controlled case.

2. **L1 ≈ L0**  
   Dominant-q estimation is not the principal bottleneck.

3. **L2 < L1**  
   Practical extraction/filtering creates a measurable weak-component penalty.

4. **L3 ≈ L2 with fewer q candidates**  
   A valid local prior can reduce search cost without necessarily degrading weak recovery.

The full q search contains 201 q candidates.  
The default local weak search contains about 31 candidates.

Therefore:

- L2 q-candidate evaluations per trial ≈ 201 + 201 = 402
- L3 q-candidate evaluations per trial ≈ 201 + 31 = 232

This corresponds to roughly a **42% reduction** in q-candidate evaluations for the strong+weak sequential search, while using the same practical residual.

---

## 9. Results that would require investigation

### Case A — L0 is already very low

If L0 recovery is below roughly 0.6:

> The chosen weak component is intrinsically too difficult.

Do not interpret L2 failure as CLEAN error. Increase weak amplitude, SNR, or q separation first.

### Case B — L1 is much worse than L0

Then strong-q estimation error is already a dominant source.

The next experiment should focus on q-estimation robustness before residual reliability.

### Case C — L2 is much worse than L1

This is the most relevant outcome for Line B.

Inspect:

- `corr(r2,strong)`
- `corr(r2,weak)`
- L2 peak ratio
- L2 peak prominence
- weak-q success/failure

The next question becomes whether L2 failure is predictable from residual observables.

### Case D — L3 is better than L2

This is **not** an error.

A valid local prior can act as a regularizer by excluding distant spurious peaks.

Later experiments must separately vary prior bias / local-window width to distinguish:

- useful search regularization;
- harmful search truncation.

### Case E — L3 is much worse than L2 even with zero prior bias

Check the local halfwidth and success threshold. In the default configuration, the true weak q is deliberately inside the local interval.

---

## 10. What not to do yet

Do not yet:

- add abrupt spatial ORO jumps;
- build an adaptive-confidence score;
- train a neural network;
- add many component numbers;
- scan a large multidimensional grid;
- claim novelty.

First run EXP009-A and inspect whether the four levels isolate a stable mechanism.

---

## 11. Decision after EXP009-A

The most valuable first result is:

```text
L0 high
L1 close to L0
L2 clearly lower
```

If this occurs and L2 failures also show systematically different residual signatures, EXP009 can proceed toward:

`residual reliability -> failure prediction -> selective computation allocation`

If not, the next step should be changed according to the observed failure source rather than forcing the confidence-aware hypothesis.
