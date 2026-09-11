# EXP009 / PA5H
## Mixture-Induced Bias Law and Gate-Regret Audit

PA5H is the **final deterministic closure** of the PA5 sequence.

It does **not** introduce another estimator, another interpolation rule, or
another tuned gate threshold.

The two questions are now narrower:

1. Can the coherent-mixture bias isolated in PA5G be explained by a
   first-order perturbation law?
2. How far is the current PA5G evidence gate from the best possible
   per-trial binary decision between “recenter” and “do not recenter”?

If these are sufficiently clean, PA5 ends here and the next stage must
reintroduce realistic error sources.

---

# 1. Background inherited from PA5G

PA5G established:

\[
\boxed{
\text{continuous ML removes the interpolation bias}
}
\]

for strong-only data.

But in a strong+weak coherent mixture:

\[
\hat\eta
=
\eta
+
\delta_{\rm mix},
\]

where the remaining bias is structured rather than random.

The observed bias was nearly translation invariant with respect to the
true common fractional-bin offset \(\eta\).

PA5G also showed that blind recentering is unsafe near \(\eta=0\), while a
BIC + split-aperture consistency gate suppresses most false corrections.

---

# 2. Part A — first-order mixture-bias law

After true strong dechirping and removal of the common true \(\eta\),

\[
g[n]
=
A_s
+
A_w e^{j\phi}
e^{j\pi\Delta a n^2}.
\]

The concentrated continuous-frequency objective is

\[
J(\delta)
=
\left|
\sum_n
g[n]e^{-j2\pi\delta n/N}
\right|^2.
\]

Decompose:

\[
J(\delta)
=
J_s(\delta)
+
J_{\rm cross}(\delta)
+
J_w(\delta).
\]

At the strong-only maximum:

\[
J_s'(0)=0.
\]

For weak contrast, the displaced stationary point satisfies approximately

\[
0
\approx
J_s''(0)\delta_{\rm mix}
+
J_{\rm cross}'(0).
\]

Therefore:

\[
\boxed{
\delta_{\rm pred}
\approx
-
\frac{
J_{\rm cross}'(0)
}{
J_s''(0)
}
}
\]

The derivatives are evaluated numerically from the **known deterministic
strong and weak components**.

This is not a new estimator. It is a mechanism model.

---

# 3. Translation-invariance prediction

Because the true common \(\eta\) multiplies the entire mixture by

\[
e^{j2\pi\eta n/N},
\]

the continuous-frequency objective obeys a translation relation.

Hence for fixed:

- \(A_w/A_s\);
- \(\Delta a\);
- \(\phi\);
- \(N\);

the measured

\[
\delta_{\rm mix}
=
\hat\eta-\eta
\]

should collapse across different true \(\eta\).

PA5H quantifies the spread across:

```text
eta = [0, 0.125, 0.25, 0.375, 0.5]
```

for otherwise identical physical states.

---

# 4. First-order validity range

The perturbation law is expected to be most accurate for lower contrast.

A predefined diagnostic small-contrast regime is:

```text
Aw/As <= 0.3
```

This is **not** used to tune the algorithm.

It is only used when interpreting first-order model validity.

The experiment still runs all:

```text
Aw/As = [0.1, 0.2, 0.3, 0.5, 0.8]
```

---

# 5. Part B — per-trial gate regret

For every physical trial and every deletion-window size, compute:

### Action 0

No recenter:

\[
E_0.
\]

### Action 1

Always recenter using the PA5G continuous mixture estimate:

\[
E_1.
\]

### Gate action

Use the PA5G evidence gate:

\[
E_g.
\]

Then define the binary oracle:

\[
\boxed{
a^*
=
\arg\min\{E_0,E_1\}
}
\]

and oracle error:

\[
E^*
=
\min(E_0,E_1).
\]

Decision regret:

\[
\boxed{
R
=
E_g-E^*
}
\]

with numerical clipping at zero.

---

# 6. Decision-error semantics

### False recenter

The gate chooses recenter but the oracle prefers no recenter.

### Missed recenter

The gate chooses no recenter but the oracle prefers recenter.

### Action agreement

Gate and binary oracle choose the same action.

### Regret

The actual performance penalty of the gate relative to the better of the
two available actions.

This is more informative than trigger rate alone.

---

# 7. Fixed variables

Unchanged from PA5G:

- `fc = 3 GHz`
- `PRF = 188 Hz`
- `H = 3000 m`
- `La = 2 m`
- `V = 150 m/s`
- `R0/H = sqrt(2)`
- weak velocity = `15 m/s`
- `Delta-v = [2.5,5,7.5,10,15,20] m/s`
- `Aw/As = [0.1,0.2,0.3,0.5,0.8]`
- 16 relative phases
- `eta = [0,0.125,0.25,0.375,0.5]`
- `l = [1,3,5,9,17]`
- Paper1s / BeamDerived
- `PlateauAwareTol`
- transform peak gate `0.7`
- true strong chirp rate
- no thermal noise
- no clutter

---

# 8. Outputs

## Bias law

```text
pa5h_bias_trials.csv
pa5h_bias_summary.csv
pa5h_eta_collapse_summary.csv
pa5h_bias_by_phase.csv
pa5h_bias_by_contrast.csv
```

## Gate regret

```text
pa5h_regret_trials.csv
pa5h_regret_summary.csv
pa5h_regret_by_contrast.csv
pa5h_best_window_regret.csv
pa5h_oracle_action_summary.csv
```

## Integrity / decision

```text
pa5h_identity_summary.csv
pa5h_decision_summary.csv
```

---

# 9. Figures

```text
fig01_measured_vs_predicted_bias.png
fig02_bias_R2_vs_contrast.png
fig03_eta_translation_collapse.png
fig04_phase_bias_anatomy.png
fig05_contrast_scaling.png
fig06_gate_regret_vs_eta.png
fig07_action_agreement_vs_eta.png
fig08_false_vs_missed_recenter.png
fig09_gate_vs_binary_oracle.png
```

---

# 10. Desired interpretation branches

## Branch A — deterministic closure achieved

Expected qualitative pattern:

- strong translation collapse across \(\eta\);
- first-order law works well for lower contrasts;
- decision regret is small;
- gate / oracle action agreement is high.

Then:

\[
\boxed{
\text{PA5 ENDS}
}
\]

and the next experiment must add:

- strong-order estimation error;
- noise;
- clutter / realistic perturbations.

## Branch B — bias law works but gate regret is still nontrivial

Then the physics / perturbation model is already useful, but the gate remains
the algorithmic bottleneck.

The next decision should be based on the bias model itself rather than
manual threshold tuning.

## Branch C — first-order law only partially works

If the law fails mainly at high contrast, that is expected and useful:
higher-order terms are needed.

If it fails already at low contrast, the local perturbation derivation or
signal model must be rechecked.

---

# 11. Run

Place all files in:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation
```

Run:

```matlab
results = exp09_pa5h_bias_regret_audit;
```

Outputs:

```text
results\exp09_physical_validation\exp09_pa5h_bias_regret_audit
```
