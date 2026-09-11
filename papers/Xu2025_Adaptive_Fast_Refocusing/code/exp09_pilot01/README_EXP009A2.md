# EXP009-A2 / Pilot-01 — CLEAN Mechanism Dissection

## 1. Why A2 is needed

EXP009-A showed, after applying a numerical tolerance to the recovery boundary:

- L0 Oracle Exact: ~0.96 weak recovery
- L1 q-error-only: ~0.93
- L2 Practical CLEAN Full: ~0.75
- L3 Practical CLEAN Local: ~0.75

The large penalty appears at the practical extraction / CLEAN stage.

Moreover, the existing normalized residual correlations do not clearly support the simple hypothesis:

`more strong leakage -> more weak failure`

Therefore A2 asks a narrower question:

> Does the CLEAN operator itself damage or reshape the weak component, and how does that effect depend on CLEAN extraction strength?

---

## 2. Part I — C0/C1/C2

### C0 Exact subtraction

`x - true strong component`

This is the intrinsic reference.

### C1 Practical CLEAN + true strong q

Use the true q_strong but still perform the practical dechirp/FFT/notch/IFFT/rechirp CLEAN operation.

So:

`C1 - C0 = operator/filtering penalty`

If C1 is already much worse than C0, the CLEAN operator itself is responsible even when strong q is perfect.

### C2 Practical CLEAN + estimated strong q

Use q_hat_strong estimated from the noisy mixture.

So:

`C2 - C1 = additional q-estimation/CLEAN interaction`

---

## 3. Part II — CLEAN-width sweep

Default halfwidths:

```text
h = 0, 1, 2, 3, 5 FFT bins
```

For every width, both branches are evaluated:

- TrueQ CLEAN
- EstimatedQ CLEAN

The same 100 noise realizations are reused everywhere.

---

## 4. Key new metrics

### 4.1 Normalized residual correlation

For residual `r` and a template `s`:

```text
corr(r,s) = |<r,s>| / (||r|| ||s||)
```

This answers:

> What fraction of the *direction/shape* of the residual resembles this template?

It is bounded between 0 and 1.

But it is normalized by the total residual norm. Therefore it is not a direct measure of how much absolute strong or weak amplitude remains.

### 4.2 Template retention

A2 adds:

```text
eta_s = |<r,s_strong>|^2 / ||s_strong||^4
eta_w = |<r,s_weak>|^2   / ||s_weak||^4
```

If:

```text
r = a*s + content orthogonal to s
```

then approximately:

```text
eta = |a|^2
```

Therefore:

- eta_s small -> strong template is strongly suppressed
- eta_w close to 1 -> weak template is well preserved
- eta_w decreases -> CLEAN is damaging/removing weak-template energy

This is the main mechanism metric for A2.

---

## 5. What A2 is looking for

The most interesting pattern would be:

```text
notch width increases
    -> eta_s decreases     (strong suppression improves)
    -> eta_w also decreases (weak component is damaged)
    -> weak-q bias grows
    -> weak recovery first improves or then degrades
```

That would reveal a:

`strong suppression <-> weak preservation`

trade-off.

Another possible result is:

```text
C0 high
C1 much lower
C2 only slightly lower than C1
```

This would mean the CLEAN/filter operator itself, not q estimation, is the main failure source.

If instead:

```text
C0 ~= C1
C2 much lower
```

then q-estimation error interacting with CLEAN is the main issue.

---

## 6. Recommended placement

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09a2_clean_mechanism.m
    │       └── config_exp09a2.m
    └── results/
        └── exp09_pilot01/
            └── exp09a2_clean_mechanism/
```

---

## 7. Run

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09a2_clean_mechanism;
```

---

## 8. Outputs

```text
default_ladder_trials.csv
default_ladder_summary.csv
width_sweep_trials.csv
width_sweep_summary.csv
summary.txt
exp09a2_results.mat

fig01_default_recovery.png
fig02_signed_q_bias.png
fig03_width_vs_recovery.png
fig04_eta_tradeoff.png
fig05_width_vs_q_bias.png
fig06_eta_scatter.png
fig07_example_concentration_curves.png
```

---

## 9. Interpretation rules

Do not judge A2 only by recall.

The important joint reading is:

1. C0 vs C1 vs C2 recovery
2. signed weak-q bias
3. eta_s
4. eta_w
5. width-response curve

### Candidate mechanism A

`eta_s remains high when failure occurs`

Strong leakage remains plausible.

### Candidate mechanism B

`eta_s decreases while eta_w also decreases`

Aggressive strong suppression is damaging the weak component.

### Candidate mechanism C

`eta_w stays high but q bias changes strongly`

The weak component may remain energetic but its concentration landscape is being reshaped/shifted.

---

## 10. What not to do yet

Do not yet:

- scan amplitude ratio / SNR / q separation;
- train AI/ML models;
- build adaptive CLEAN;
- claim a suppression-preservation trade-off before the width sweep supports it.

A2 is still mechanism dissection.
