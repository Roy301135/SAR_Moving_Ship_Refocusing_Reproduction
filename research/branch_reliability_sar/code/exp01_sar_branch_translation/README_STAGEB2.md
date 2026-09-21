# EXP01 Stage-B2 — Controlled Hard-State Physical Embedding

## Purpose

This stage performs one pre-registered bridge test:

`one frozen EXP010-B BeamDerived DenseRisk rescue case`
→ `yaw-only physical SAR pair`
→ `sampled MC-LFM parameters`
→ `G0 / Neighbor-3 falsification after scene freeze`.

It does **not** redesign the method and does **not** optimize branch outcome.

## Dependency

The accepted EXP010-B result directory must exist at:

```text
papers/Xu2025_Adaptive_Fast_Refocusing/
└── results/
    └── exp10_practical_nonoracle_closure/
        └── exp10b_noiseless_formal_closure/
            └── evaluation_trials_all.csv
```

Stage-A / Stage-B files under the current `research/branch_reliability_sar/` module must remain in place.

## Run

From:

```text
research/branch_reliability_sar/code/exp01_sar_branch_translation/
```

run:

```matlab
run_exp01_stageB2_hardstate_embedding
```

## Target selection is deterministic

The script selects exactly one accepted upstream state:

1. DenseRisk / BeamDerived;
2. G0 catastrophic;
3. Proposed and Always-N3 non-catastrophic;
4. Proposed fallback actually triggered;
5. prefer a case where G0 weak recovery fails but Proposed weak recovery succeeds;
6. if multiple cases remain, choose the smallest `trial_id`.

No second target is tried in this stage.

## Inverse variables

The solver changes only:

- P4 aperture-center azimuth coordinate;
- P7 aperture-center azimuth coordinate;
- their shared center ground-range offset;
- yaw amplitude;
- yaw period;
- yaw phase at aperture center.

The SAR system, aperture length, platform geometry, processing convention, and all branch-search semantics remain frozen.

The inverse objective contains only parameter mismatch and physical plausibility penalties. It never evaluates G0, Neighbor-3, Proposed, or branch labels.

## Main feedback

Upload only:

```text
EXP01_STAGEB2_FEEDBACK_BUNDLE.txt
07_stageB2_physical_embedding.png
08_stageB2_branch_falsification.png
```

Keep CSV/MAT files locally for provenance.
