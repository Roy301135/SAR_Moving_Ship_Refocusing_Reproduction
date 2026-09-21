# EXP01 Stage-B — SAR-to-Branch Interface Audit

## Research Question

Does the accepted Stage-A physical SAR scene naturally map to the sampled MC-LFM / branch-search representation frozen in EXP009/010, and does that physical mixture naturally instantiate a G0 branch catastrophe recoverable by Neighbor-3?

## Scope

Stage-B is an interface / falsification gate inside the same `exp01_sar_branch_translation` experiment.

It does **not**:

- change yaw motion;
- move scatterers;
- change P4/P7 amplitude ratio or phase;
- redesign reliability features;
- run the frozen staged Proposed scheduler;
- add noise or clutter;
- create a new experiment ID.

## Physical-to-Algorithm Bridge

From the accepted Stage-A moving-scene range histories, define one canonical stationary reference range history at:

- azimuth reference: scene center `x_ref = 0`;
- ground-range reference: the aperture-center common P4/P7 range coordinate.

For each physical scatterer `p`, evaluate the ideal range-compressed contribution along this reference history:

```text
x_p[m]
= c_p sinc(2B/c * (R_ref[m]-R_p[m]))
  exp(-j 4pi (R_p[m]-R_ref[m])/lambda)
```

This produces a finite sampled residual signal with the same implementation convention used by EXP009/010:

```text
x[m] = A[m] exp{ j 2pi [0.5 a m^2 + (nu/N)m] + j phi }
```

with:

```text
a = tan(beta)
```

The physical amplitude envelope is retained rather than forced to a constant.

## Primary / Diagnostic Signals

Primary mechanism signal:

```text
exact-forward full-scene residual history
```

Controls:

```text
P4 strong-only
P7 weak-only
P4+P7 pair-only
stored range-grid extraction
```

The range-grid extraction is only a discretization diagnostic; it is not allowed to redefine the branch mechanism.

## Branch Audit

Stage-B uses the fitted physical strong `a_s` as an evaluation-only oracle control, then applies the inherited branch semantics:

```text
de-chirp by a_s
-> integer DFT Top-1 (G0 seed)
-> +/-0.75-bin local refinement, 33 bracket samples + fminbnd
-> Neighbor-3 seeds {k0-1,k0,k0+1}
```

Evaluation-only global continuous reference scans the full unique DFT period.

Inherited evaluation threshold:

```text
catastrophic branch error > 0.10 bin
```

## Falsifier / Stop Rule

- If the physical P4/P7 histories are not well represented by the sampled MC-LFM form, stop before Proposed.
- If the full physical mixture gives G0 catastrophe and N3 rescue, proceed to Stage-C frozen Proposed integration.
- If G0 succeeds, do not tune the physical scene in this run. First audit why the canonical physical state does not lie in the previously frozen branch-vulnerable regime.

## Feedback Policy

Upload only:

```text
EXP01_STAGEB_FEEDBACK_BUNDLE.txt
05_stageB_physical_interface.png
06_stageB_branch_landscape.png
```

Keep CSV/MAT locally for provenance unless a specific anomaly requires inspection.
