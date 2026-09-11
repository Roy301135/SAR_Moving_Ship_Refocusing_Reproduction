# EXP009 / PA5H-R1
## Mode-Switch and Regret-Tie Audit

PA5H-R1 is a **small audit patch**, not a new method stage.

It addresses the two unresolved issues after PA5H:

1. At \(A_w/A_s=0.5\) and \(0.8\), most states still show near machine-precision
   translation collapse, but a few states produce very large
   \(0.39\sim0.60\) bin jumps.
2. The previous `best window` selector minimized median regret only.
   Because many windows had median regret exactly zero, MATLAB selected the
   first tied entry, usually \(L=1\).

---

# RQ1 — Is the high-contrast collapse anomaly really mode switching?

For every high-contrast physical state, PA5H-R1 repeats the same local
continuous-ML estimator used in PA5G/PA5H across:

```text
eta = [0, 0.125, 0.25, 0.375, 0.5]
```

The experiment records:

- wrapped bias \(\hat\eta-\eta\);
- raw continuous-frequency displacement;
- coarse integer DFT branch;
- exact signal translation error after removing the known true \(\eta\).

The true-\(\eta\) recentering here is **oracle diagnostic only**.

For a collapse-outlier state, PA5H-R1 additionally performs a broad global
objective audit:

\[
J(\delta)
=
\left|
\sum_n
z[n]e^{-j2\pi\delta n/N}
\right|^2.
\]

It extracts the top continuous maxima and asks:

- does the local estimator change peak branch across \(\eta\)?
- does the local estimator sometimes leave the global top-1 branch?
- are the competing peaks nearly degenerate?

The key distinction is:

\[
\boxed{
\text{signal/objective translation invariance}
\neq
\text{local estimator branch invariance}
}
\]

If the oracle-recentered signals collapse numerically while the local peak
branch changes, the PA5H anomaly is an estimator mode-switch phenomenon,
not a failure of the physical translation model.

---

# RQ2 — Correct the best-window tie artifact

The PA5H summary is re-read from:

```text
pa5h_regret_summary.csv
```

The new best-window selection is lexicographic:

1. minimum median regret;
2. among tied windows, minimum p90 regret;
3. among tied windows, minimum mean regret;
4. among tied windows, maximum action agreement;
5. remaining exact tie -> smaller window.

No PA5H trial result is changed.

This only fixes summary selection.

---

# Fixed physical parameters

Inherited from PA5H:

- \(f_c=3\) GHz
- PRF \(=188\) Hz
- \(H=3000\) m
- \(L_a=2\) m
- platform speed \(=150\) m/s
- \(R_0/H=\sqrt{2}\)
- weak velocity \(=15\) m/s
- \(\Delta v=[2.5,5,7.5,10,15,20]\) m/s
- 16 relative phases
- Paper1s / BeamDerived
- the same PA5G/PA5H local continuous ML estimator

Targeted contrast only:

```text
Aw/As = [0.5, 0.8]
```

because those are the only contrasts that produced large PA5H max-collapse
outliers.

---

# Outputs

```text
pa5h_r1_modeswitch_trials.csv
pa5h_r1_modeswitch_state_summary.csv
pa5h_r1_global_peak_audit.csv
pa5h_r1_modeswitch_decision_summary.csv

pa5h_r1_best_window_retie.csv
pa5h_r1_best_window_old_vs_new.csv

pa5h_r1_final_decision_summary.csv
summary.txt
exp09_pa5h_r1_results.mat
```

Figures:

```text
fig01_highcontrast_collapse_distribution.png
fig02_exact_translation_signal_error.png
fig03_collapse_outlier_mechanism.png
fig04_example_branch_switch.png
fig05_retied_p90_regret.png
fig06_old_vs_retied_window.png
```

---

# Expected branches

## Branch A — mode switching confirmed

If:

- oracle-recentered signal mismatch is numerical;
- high-contrast collapse outliers mostly correspond to branch changes or
  local/global peak mismatch;

then:

\[
\boxed{
\text{translation-invariant bias model remains valid}
}
\]

and the high-contrast anomaly becomes:

\[
\boxed{
\text{perturbation regime}
\rightarrow
\text{multi-peak / mode-switch regime}
}
\]

The next actual method experiment should be **PA5I — bias-aware recentering
decision**, not another estimator audit.

## Branch B — mode switching only partially explains the anomaly

Then the outlier states need one more mechanism check before PA5I.

## Branch C — exact signal translation fails

This would mean an implementation/model inconsistency and must be fixed
before moving on.

---

# Run

Place the extracted files in:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\
papers\Xu2025_Adaptive_Fast_Refocusing\
code\exp09_physical_validation
```

Run:

```matlab
results = exp09_pa5h_r1_modeswitch_regret_tie_audit;
```

The script automatically reads PA5H results from:

```text
results\exp09_physical_validation\
exp09_pa5h_bias_regret_audit
```

If your PA5H results are elsewhere, set:

```matlab
cfg.pa5h_results_dir
```

inside the config file.
