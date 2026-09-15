# EXP010-C Noise Protocol Freeze v1.0

> Status: **FROZEN FOR IMPLEMENTATION**
>
> Purpose: validate the frozen practical non-oracle chain under additive complex Gaussian noise without redesigning the method.
>
> Deterministic predecessor: EXP010-B / EXP010-B-R1 closed. Neighbor-3 residual failures were attributed to upstream practical strong-parameter mismatch rather than adjacency coverage.

---

## 1. Experimental layer

EXP010-C is a **post-detection, target-dominated local azimuth-line signal-level robustness experiment**.

It does **not** model the complete maritime SAR scene and does **not** claim that sea clutter is Gaussian white noise.

Primary noisy signal model:

\[
x[n]=s_s[n]+s_w[n]+w[n].
\]

where:

- \(s_s[n]\): strong ship LFM component;
- \(s_w[n]\): weak ship LFM component;
- \(w[n]\): additive circular complex Gaussian noise.

Sea clutter / local maritime background is reserved for later SAR-level validation.

---

## 2. Noise model — FROZEN

\[
w[n]\sim\mathcal{CN}(0,\sigma_n^2)
\]

with

\[
E|w[n]|^2=\sigma_n^2,
\]

and

\[
\operatorname{Var}(\Re w)
=
\operatorname{Var}(\Im w)
=
\frac{\sigma_n^2}{2}.
\]

MATLAB implementation semantics:

```matlab
w = sqrt(sigma_n2/2) .* ...
    (randn(size(x_clean)) + 1j*randn(size(x_clean)));
```

Noise is injected after the clean MC-LFM mixture is constructed and before any estimator, reliability diagnostic, branch recovery, removal, or weak recovery.

---

## 3. SNR definitions — FROZEN

### 3.1 Primary controlled SNR

Strong-component-referenced per-sample input SNR:

\[
P_s=\frac{1}{N}\sum_n |s_s[n]|^2
\]

\[
\boxed{
\mathrm{SNR}_s
=
10\log_{10}\frac{P_s}{\sigma_n^2}
}
\]

Thus

\[
\sigma_n^2
=
\frac{P_s}{10^{\mathrm{SNR}_s/10}}.
\]

### 3.2 Weak effective SNR

If

\[
r=A_w/A_s,
\]

and strong/weak components share the same sample support/envelope,

\[
\boxed{
\mathrm{SNR}_w
=
\mathrm{SNR}_s+20\log_{10}r
}
\]

Weak SNR is **derived**, not independently controlled.

### 3.3 Mixture SNR

\[
\mathrm{SNR}_{mix}
=
10\log_{10}
\frac{N^{-1}\|s_s+s_w\|^2}{\sigma_n^2}.
\]

Mixture SNR is **reported only** and never used to set noise variance.

No mixture-SNR-controlled secondary experiment will be added.

---

## 4. SNR grid — FROZEN

\[
\boxed{
\mathrm{SNR}_s\in
\{-10,-5,0,5,10,15,20\}\ \mathrm{dB}
}
\]

Interpretation:

- -10 dB: severe low-SNR stress;
- -5 dB: low-SNR;
- 0 dB: transition;
- 5 dB: moderate;
- 10 dB: good;
- 15 dB: high;
- 20 dB: near-clean bridge to deterministic closure.

The grid must not be changed after observing EXP010-C outcomes.

---

## 5. Validation-set allocation — FROZEN

### 5.1 Primary noise-validation set

**DenseRisk**

- Paper1s: 1122 frozen physical states;
- BeamDerived: 408 frozen physical states;
- all 7 SNR levels;
- **10 independent noise realizations per physical state per SNR**.

Total physical-noise cases:

\[
(1122+408)\times7\times10
=
\boxed{107100}.
\]

DenseRisk is primary because EXP010-C aims to identify the reliability / breakdown boundary of the frozen chain in failure-rich regimes.

### 5.2 Broad-regime sanity anchor

**OriginalGrid**

- 4800 physical states per aperture;
- SNR anchors:
  \[
  \boxed{\{-10,0,10,20\}\ \mathrm{dB}}
  \]
- **5 independent noise realizations per physical state per anchor SNR**.

Total physical-noise cases:

\[
9600\times4\times5
=
\boxed{192000}.
\]

Purpose: check that noise robustness conclusions from DenseRisk do not conceal broad-regime induced harm. This is not a second tuning set.

### 5.3 Total planned physical-noise cases

\[
107100+192000
=
\boxed{299100}.
\]

---

## 6. Monte-Carlo / confidence audit

The chosen MC counts are based on the total number of frozen physical states contributing to each SNR-level estimate, not on a convention such as “100 MC because another paper used 100”.

### DenseRisk

With 10 realizations/state:

- Paper1s: \(n=11220\) Bernoulli outcomes per SNR;
- BeamDerived: \(n=4080\) outcomes per SNR.

Approximate 95% Wilson half-widths:

| Group | n/SNR | p=0.01 | p=0.03 | p=0.08 | p=0.15 | worst p=0.50 |
|---|---:|---:|---:|---:|---:|---:|
| DenseRisk / Paper1s | 11220 | 0.0018 | 0.0032 | 0.0050 | 0.0066 | 0.0093 |
| DenseRisk / BeamDerived | 4080 | 0.0031 | 0.0052 | 0.0083 | 0.0110 | 0.0153 |

Thus even the smaller BeamDerived set has a worst-case half-width of about ±1.53 percentage points at p=0.5, and substantially tighter intervals in the rare-event regime.

### OriginalGrid anchor

With 5 realizations/state:

- \(n=24000\) outcomes per aperture per anchor SNR;
- worst-case Wilson half-width at p=0.5 is about ±0.63 percentage points.

This is sufficient for a broad-regime non-inferiority / induced-harm sanity check.

---

## 7. Randomness and pairing — FROZEN

For each tuple

```text
physical_state_id × SNR_level × MC_realization
```

generate exactly one complex-noise realization.

The same noisy observation must be reused for:

- G0_OriginalTop1;
- Proposed_Frozen_Staged;
- Always_Neighbor3.

The method name must never enter the RNG seed.

Maintain an explicit seed ledger containing at least:

```text
validation_set
aperture_mode
physical_state_id
snr_db
mc_index
seed
```

---

## 8. Frozen method under noise

No retuning is permitted.

```text
Cheap G0
→ Refined-LR, high=risky, b1=0.20
→ N3 for Stage-1 trigger
→ remaining pool
→ FiveBin, low=risky, b2=0.10 conditional
→ N3 for Stage-2 trigger
→ otherwise keep G0
```

Removal remains:

```text
recenter
→ PlateauAwareTol
→ 0.70 peak gate
→ 3-bin notch
→ inverse
→ undo recenter
```

Neighbor-3 remains radius 1 with the inherited local refinement semantics.

---

## 9. Mandatory outputs

At each validation-set / aperture / SNR combination report:

1. branch-catastrophe numerator / denominator / probability;
2. 95% Wilson CI;
3. weak waveform feasible numerator / denominator / probability;
4. median / p90 / p99 strong-beta error over \(W_\beta\);
5. median / p90 / p99 eta error;
6. fallback fraction;
7. mean branch objective evaluations;
8. normalized branch cost;
9. Stage-1 / Stage-2 trigger and rescue counts;
10. Refined-LR directional AUC;
11. residual FiveBin directional AUC when both classes exist;
12. paired outcomes:
    - G0 fail → Proposed success;
    - G0 success → Proposed fail;
    - Proposed fail → N3 success;
    - persistent after N3;
13. paired exact / McNemar-style p-value where applicable;
14. derived weak SNR and observed mixture SNR summaries.

---

## 10. Primary causal reading of EXP010-C

The main noise-validation chain is:

\[
\boxed{
\mathrm{SNR}_s
\rightarrow
|\hat\beta_s-\beta_s|
\rightarrow
\text{branch-recovery validity}
\rightarrow
\text{weak recovery}
}
\]

EXP010-C is not merely a “failure-rate-vs-SNR” plot.

The deterministic result from EXP010-B-R1 establishes that upstream strong-parameter error is a validity boundary for Neighbor-3; EXP010-C tests how additive noise moves the system toward or across that boundary.

---

## 11. Stop / falsification rules

Do **not** modify the method if low SNR causes:

- Refined-LR / FiveBin directional degradation;
- increased fallback;
- Neighbor-3 persistent failure;
- weak-recovery collapse.

Instead report a validity range / reliability boundary.

The frozen method may be reopened only if the closure evidence directly invalidates Claim 2 and the limitation cannot be honestly scoped.

---

## 12. Scope boundary: sea clutter

EXP010-C does not claim to simulate sea clutter.

A later SAR-level validation may use:

\[
x_{SLC}
=
s_{ship}
+
c_{local\ sea}
+
w_{thermal}
\]

with a clutter/SCR model appropriate to the actual SAR processing level and local maritime background.

AWGN and sea clutter must remain explicitly separated in the manuscript.

---

# Final freeze status

```text
Noise layer                  FROZEN
Complex AWGN                 FROZEN
Injection point              FROZEN
Strong-referenced SNR        FROZEN
Weak-SNR derivation          FROZEN
Mixture-SNR reporting only   FROZEN
SNR grid                     FROZEN
DenseRisk MC = 10            FROZEN
Original anchor MC = 5       FROZEN
CRN + seed ledger            FROZEN
Wilson CI + paired outcomes  FROZEN
Sea clutter / SCR            OUT OF EXP010-C
```

**EXP010-C is ready for implementation.**
