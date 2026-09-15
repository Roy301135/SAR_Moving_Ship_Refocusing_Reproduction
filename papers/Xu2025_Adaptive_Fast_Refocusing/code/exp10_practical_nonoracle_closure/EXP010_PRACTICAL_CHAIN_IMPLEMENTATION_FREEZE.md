# EXP009 Practical-Chain Implementation Freeze

**Status:** frozen for the first noiseless non-oracle integration smoke test  
**Code folder:** `code/exp09_practical_nonoracle_closure`  
**Result folder:** `results/exp09_practical_nonoracle_closure`

## 1. Why this freeze exists

PA5J-B3-R2 has already frozen the reliability architecture:

`G0 -> Refined-LR top 20% -> Neighbor-3 -> remaining pool -> FiveBin top 10% -> Neighbor-3`.

The present step does **not** redesign that policy. Its purpose is to remove the remaining implementation ambiguity before noise is introduced.

The primary rule remains:

> Truth may evaluate, but truth may not decide.

## 2. Frozen practical chain

```text
observed mixture
  -> fixed-domain strong-beta / ORO search
  -> G0 continuous-frequency refinement
  -> Refined-LR + FiveBin staged resource scheduler
  -> optional Neighbor-3
  -> final practical frequency/sub-bin estimate
  -> practical complex amplitude/phase LS estimate (audit output)
  -> recenter
  -> frozen 3-bin Wang-style transform-domain removal
  -> undo recenter
  -> full fixed-domain weak-beta search
  -> evaluation with truth (outside Proposed function)
```

## 3. Strong beta / ORO production path

Old PA5C used a scenario-specific beta grid whose limits were constructed from true strong and weak beta. That is acceptable for mechanism validation but **not** for the final Proposed path.

The practical closure therefore freezes a single fixed operational velocity support:

- `v_min = -5 m/s`
- `v_max = 35 m/s`

This exactly covers the complete current physical simulation family and is fixed before looking at individual trials. The interval is mapped to beta through the inherited residual-FM model. A 2.5-width margin and a beta-grid step of `W_beta/120` are inherited from PA5C. The PA4 measured aperture-specific widths are used as fixed calibration constants.

This is an implementation closure choice, **not a new algorithmic contribution**. If it fails, the correct conclusion is that upstream practical strong search remains an unresolved bottleneck.

## 4. Eta / continuous-frequency production path

After dechirping by the practical strong-beta estimate:

1. G0 selects the strongest integer DFT bin.
2. The PA5I continuous-ML/LS local refinement searches `±0.75 bin` with 33 bracket samples followed by `fminbnd`.
3. The frozen PA5J resource scheduler decides whether to retain G0 or call Neighbor-3.
4. Neighbor-3 refines `{k0-1,k0,k0+1}` and keeps the largest continuous objective.
5. The selected continuous coordinate is the practical `eta/frequency` estimate used for recentering.

No true eta, true branch or GlobalReference may enter this path.

## 5. Strong amplitude / phase

Given the final estimated chirp rate and continuous frequency, define a unit-amplitude strong template `h_hat`. Estimate one complex coefficient by LS:

`c_hat = (h_hat^H x)/(h_hat^H h_hat)`.

Then:

- `A_hat = |c_hat|`
- `phi_hat = angle(c_hat)`

These quantities are saved as practical estimates and close the Oracle Ledger PENDING item. The primary removal operator does not need them; therefore they are **audit outputs**, not a hidden replacement by exact waveform subtraction.

## 6. Frozen removal operator

Primary removal stays on the PA5F/PA5C mechanism path:

```text
recenter by selected continuous frequency
-> matched LFM transform using estimated strong beta
-> PlateauAwareTol peak semantics
-> 0.70 x max peak gate
-> 3-bin window around detected centers
-> inverse transform
-> subtract extracted component
-> undo recenter
```

The 3-bin window is frozen because PA5C selected 3 bins as the balanced window for both Paper1s and BeamDerived. It must not be retuned after noise is introduced.

## 7. Weak recovery semantics

The primary practical closure uses a **full fixed-domain beta search on the residual**. It does not use a truth-centered weak prior.

Truth weak beta is used only after the estimate exists, for normalized error evaluation.

The inherited residual-waveform feasibility criterion is:

`E = ||r - w_true|| / ||w_true|| <= 1`.

## 8. Natural-batch scheduler semantics

This closure remains Option A: batch / fixed-compute scheduling.

The ranking pool is the complete processing batch for one known aperture configuration. It is **not** split by true eta, true Gamma, contrast, phase, velocity regime or future SNR.

Stage 1 uses high `refined_lr_asymmetry` as high risk. Stage 2 acts only on the Stage-1-untriggered pool and uses low `fivebin_peak_fraction` as high risk. Ties are included and never split by trial ID or row order.

## 9. Comparator set

Mandatory practical paths:

- `G0_OriginalTop1`
- `Proposed_Frozen_Staged`
- `Always_Neighbor3`

Evaluation-only controls:

- `ORACLE_ExactSubtraction`
- `ORACLE_TrueBetaEta_Notch3`
- GlobalReference branch result

The oracle controls never enter Proposed decisions.

## 10. First-run status

The default config is deliberately `run_mode = "smoke"`.

The smoke grid covers:

- Paper1s + BeamDerived;
- delta-v = 2.5, 10, 20 m/s;
- weak/strong ratio = 0.1, 0.3, 0.8;
- four relative phases;
- eta = 0, 0.25, 0.5 bin;
- both LowV and HighV strong components.

This run is an **implementation/falsification test**, not final paper evidence.

Only after it passes should `run_mode` be changed to `"formal"` for the full noiseless closure.

## 11. Pre-registered failure interpretation

Stop and diagnose instead of tuning if any of the following occurs:

1. fixed-domain strong-beta estimation has large systematic error;
2. Refined-LR or FiveBin risk direction reverses after practical beta estimation;
3. Neighbor-3 creates systematic new downstream weak failures;
4. oracle firewall fails;
5. the 3-bin frozen operator becomes unusable even in noiseless integration.

A negative result here is scientifically useful: it identifies which previously isolated mechanism does not survive end-to-end practical integration.
