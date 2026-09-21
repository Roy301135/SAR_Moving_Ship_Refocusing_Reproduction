# EXP01 Stage-B2 — Hard-State Physical Realizability Audit

## Research Question

Can one already-frozen signal-level branch-vulnerable state from EXP010-B be realized by a physically generated yawing-ship SAR configuration, without optimizing or retuning the branch algorithm?

## Served Evidence Gap

Stage-A established:

`motion physics -> SAR defocus`.

Stage-B established:

`SAR history -> sampled MC-LFM`.

The canonical scene was an easy branch regime. Stage-B2 therefore tests the one missing bridge:

`frozen DenseRisk branch state -> physically realizable SAR state`.

## Pre-registered target rule

Only one target is selected from the accepted EXP010-B `DenseRisk / BeamDerived` results. It must satisfy G0 catastrophic failure, Proposed recovery, Always-N3 recovery, and actual Proposed fallback. A simultaneous downstream weak-waveform rescue is preferred. The smallest `trial_id` is the deterministic tie-break.

No second target is permitted if the physical mapping fails.

## Physical inverse model

The solver remains within a yaw-only rigid-body family and changes only designated P4/P7 geometry plus yaw amplitude/period/phase. P4 and P7 are constrained to the same ground-range coordinate at aperture center. Their physical slant-range histories generate the residual complex SAR signals; no artificial LFM is injected.

The inverse objective matches:

- strong and weak `beta`;
- strong and weak fractional DFT-bin offset;
- strong/weak absolute branch proximity;
- local quadratic-phase consistency;
- basic geometry/envelope plausibility.

Critically, the inverse objective contains **no branch-success term**.

## Formal Falsifier

After the numerical inverse solve completes, the physical scene is frozen. Only then are G0 and Neighbor-3 evaluated.

- Mapping fails -> STOP before Proposed.
- Mapping passes but no G0 catastrophe -> report that the selected frozen state is not realized under this pre-registered yaw-only physical family.
- G0 catastrophe but N3 does not rescue -> STOP and audit physical-versus-signal branch geometry.
- Full-scene G0 catastrophe + N3 rescue -> Stage-B2 closes and Stage-C may integrate the frozen Proposed chain at SAR image level.

## Anti-expansion rule

Do not add a second target, motion family, SNR level, roll/pitch case, or new algorithm feature in Stage-B2.
