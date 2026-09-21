# EXP01 — SAR-Level Translation of Branch Error and Reliability-Aware Recovery

## 1. Research Question

Can the already-established search-level branch failure and reliability-aware branch rescue be translated into physically meaningful SAR consequences and recovery, specifically through the chain

`branch error -> residual signal distortion -> scattering-energy redistribution -> weak-scatterer loss / sidelobe / ghost structure -> branch rescue -> SAR structure recovery`?

## 2. Scope freeze

EXP01 is one causal-translation experiment. It is **not** split into separate “mapping” and “rescue” experiments.

The experiment will eventually compare the frozen groups:

- G0;
- Proposed frozen staged policy;
- Always-Neighbor-3;
- Oracle control.

Stage A in the current code package implements only the common SAR physical foundation.

## 3. Stage-A physical chain

`Sparse ship scatterers`
`-> yaw motion`
`-> exact slant-range history R_p(eta)`
`-> ideal range-compressed complex echo`
`-> stationary-reference backprojection`
`-> static reference / moving-target defocused SAR image`

The moving-image degradation therefore originates from physical range/phase mismatch, not an image-domain blur kernel.

## 4. Literature-anchored system parameters

The current foundation uses the simulation parameters reported by Wang et al. for swing-ship SAR experiments:

- carrier frequency: 3 GHz;
- PRF: 188 Hz;
- bandwidth: 150 MHz;
- platform height: 3000 m;
- antenna length: 2 m;
- platform velocity: 150 m/s.

For yaw, the foundation uses the reported 38 deg double amplitude as +/-19 deg and the reported average yaw period 14.2 s.

## 5. Strong/weak pair geometry

A designated strong/weak pair is embedded in the sparse ship skeleton. Their body-frame positions are chosen so that, after the frozen aperture-center yaw rotation, they share the same ground-range coordinate at eta=0. This provides a physically meaningful same-range-line pair for later MC-LFM / branch analysis.

Stage A does not tune their relative phase to force a branch failure.

## 6. Model-consistency audit

For each scatterer, compute the exact motion-induced residual phase relative to the ship frozen at its aperture-center pose:

`Delta phi_p(eta) = -4*pi/lambda * [R_moving,p(eta) - R_static,p(eta)]`.

Fit

`Delta phi_p(eta) ~= a0 + a1*eta + a2*eta^2`

and report:

- quadratic-fit NRMSE;
- R^2;
- maximum absolute phase-fit residual;
- exact residual-phase span.

No automatic acceptance threshold is imposed in Stage A. The strong/weak histories are reviewed before the frozen branch chain is connected.

## 7. Current stop rule

Do not proceed to G0 / Proposed integration if the SAR foundation itself is not interpretable, e.g.:

- the static scene is not correctly focused by the common BP imager;
- the moving-target effect is dominated by an implementation artifact rather than target motion;
- the designated strong/weak histories are clearly incompatible with the short-aperture local quadratic-phase model.

If Stage A passes, the next implementation step stays within EXP01 and connects the already-frozen branch/recovery chain. No new reliability feature, budget, Neighbor-K variant, noise sweep, or clutter model is introduced.
