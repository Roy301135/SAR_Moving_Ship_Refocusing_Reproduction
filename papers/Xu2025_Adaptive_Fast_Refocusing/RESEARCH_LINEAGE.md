# EXP009 Research Lineage

Evidence labels: **Confirmed by evidence** records statements explicit in the reviewed README/code chain, not independent re-analysis of raw result files. **Working hypothesis** and **Planned-not-tested** must remain distinct.

## Pilot-01

**Research Question** -> Where does weak-component failure first enter sequential MC-LFM/CLEAN processing?

**Key Experiment** -> Oracle Ladder and controlled A--C3B3B.1 mechanism studies.

**Confirmed Evidence** -> The reviewed Pilot documentation identifies practical CLEAN residual and coherent cross-term geometry, rather than dominant-q estimation alone, as the controlled weak-recovery failure source.

**Remaining Unknown** -> Transfer to paper-grounded parameters, realistic errors, clutter, and SAR data.

**Why Next** -> Move from normalized q discovery to physical validation.

## Physical Validation P0

**Research Question** -> How do Xu 2025 velocity, residual FM, and ORO conventions map to a physical experiment?

**Key Experiment** -> Velocity--ORO calibration, effective azimuth-sample audit, and rotation-order convention check.

**Confirmed Evidence** -> P0 defines a calibration gate and distinguishes published, derived, and inferred quantities; its final gate result was not reviewed.

**Remaining Unknown** -> Whether the P0 gate passed and all publication consistency details.

**Why Next** -> Establish the physical baseline chain.

## P1 / P1B / P1C

**Research Question** -> Establish a Wang-2023 MC-LFM baseline and test aperture-constrained FrAc consistency and center-frequency cross-term sensitivity.

**Key Experiment** -> `P1`, `P1B`, and `P1C` scripts and READMEs.

**Confirmed Evidence** -> These nodes exist in the Physical Validation chain.

**Remaining Unknown** -> Their detailed results were not recovered in the first canonical context pass.

**Why Next** -> Proceed to a physical resolution/perturbation coordinate.

## PA4

**Research Question** -> What physical two-component resolution/perturbation regime is relevant?

**Key Experiment** -> Physical resolution perturbation-regime validation.

**Confirmed Evidence** -> Later PA5I-R1 documentation reuses PA4 beta-width anchors for `Paper1s` and `BeamDerived`.

**Remaining Unknown** -> Full PA4 conclusions and result statistics.

**Why Next** -> Analyze sequential strong removal under that physical coordinate.

## PA5 / PA5B / PA5C / PA5D / PA5E / PA5E-R1

**Research Question** -> Why does finite-window strong removal retain a recoverability floor?

**Key Experiment** -> Sequential removal mapping, projection decomposition, Wang-filter bridge, window/fence robustness, peak-support audit, and numerical tie audit.

**Confirmed Evidence** -> Tie handling matters, but PA5E-R1 still leaves a nonzero finite-window floor.

**Remaining Unknown** -> Detailed result boundaries for each subnode.

**Why Next** -> Actively remove fractional-bin offset before narrowband deletion.

## PA5F

**Research Question** -> Can sub-bin recentering remove off-grid strong leakage?

**Key Experiment** -> Baseline, oracle recentering, strong-only estimation, and mixture estimation; compare measured leakage with the finite-length Dirichlet model.

**Confirmed Evidence** -> Later PA5G documentation reports that oracle recentering collapsed the off-grid floor and the Dirichlet prediction matched it; practical interpolation was the bottleneck.

**Remaining Unknown** -> Robust practical estimation under mixture contamination.

**Why Next** -> Replace fixed parabolic interpolation with continuous estimation and a gate.

## PA5G

**Research Question** -> Can continuous ML remove interpolation bias and can evidence gating suppress false correction?

**Key Experiment** -> Continuous ML with BIC plus split-aperture consistency gate.

**Confirmed Evidence** -> PA5H reports strong-only interpolation bias removed; mixture-induced bias persists and blind recentering is unsafe near on-grid states.

**Remaining Unknown** -> Adequacy of the gate against a per-trial decision oracle.

**Why Next** -> Model mixture bias and quantify gate regret.

## PA5H / PA5H-R1

**Research Question** -> Does a first-order law explain mixture bias, and why can the coarse-to-fine estimator still fail?

**Key Experiment** -> Bias/regret audit followed by mode-switch/tie audit.

**Confirmed Evidence** -> PA5I documents a fractional-bin fence effect: the coarse DFT winner can change, causing local refinement to enter the wrong basin, while the continuous objective remains translation-equivariant.

**Remaining Unknown** -> Full PA5H numerical closure and the range of validity of its first-order law.

**Why Next** -> Protect local refinement with a small candidate set.

## PA5I

**Research Question** -> Can low-cost multi-candidate continuous refinements eliminate sparse catastrophic branch switching?

**Key Experiment** -> OriginalTop1, Neighbor3, Top2Coarse, Top3Coarse, and a global-reference diagnostic.

**Confirmed Evidence** -> PA5I-R1 reports rare G0 failures; Neighbor-3 had zero catastrophic failures on PA5I's original five-point eta grid, while Top2 retained some failures and Top3 removed nearly all.

**Remaining Unknown** -> Behavior between sparse eta points and on the actual risk manifold.

**Why Next** -> Run a dense-eta rare-tail audit.

## PA5I-R1

**Research Question** -> Is Neighbor-3 branch-safe on dense eta values for empirically observed PA5I risk states?

**Key Experiment** -> Restored PA4 Gamma anchors, dense eta sweep, accelerated global-reference cross-check, and rare-tail metrics.

**Confirmed Evidence** -> PA5J-A reports zero Neighbor-3 catastrophic failures on the tested dense-risk manifold. This is not a proof outside the tested deterministic regime.

**Remaining Unknown** -> Whether G0 can recognize when Neighbor-3 is needed.

**Why Next** -> Discover a transferable internal unreliability indicator.

## PA5J-A

**Research Question** -> Can G0 OriginalTop1 detect impending catastrophic branch failure from internal observables?

**Key Experiment** -> Reconstruct G0 from PA5I and PA5I-R1 inputs; screen 17 coarse/G0-local indicators using original-grid and dense-risk transfer metrics.

**Confirmed Evidence** -> The discovery implementation, reconstruction audit, candidate features, and decision rules exist. The final observed decision branch has not been confirmed from results.

**Remaining Unknown** -> Which indicator, if any, transfers robustly and at acceptable cost.

**Why Next** -> Proceed to PA5J-B only if an internal indicator consistently passes original-grid and dense-risk screening; otherwise investigate multivariate or new mechanism-derived observables.
