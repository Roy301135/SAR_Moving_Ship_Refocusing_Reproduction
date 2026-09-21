# EXP02-FAIR-R0 Patch

## Purpose

This patch starts the formal FAIR-CSAR real-data R0 experiment:

**Source-Aligned MC-LFM / FrAc Compatibility Audit**

It deliberately does **not** run G0, Neighbor-3, Proposed, or branch taxonomy.

The experiment asks only whether the frozen FAIR-CSAR `Motion_Defocusing_Ship`
Candidate B exhibits target-specific fractional-domain structure compatible
with the Wang/Xu MC-LFM processing object.

## Placement

Extract this ZIP directly into:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\
```

It adds only:

```text
research\
└─ branch_reliability_sar\
   ├─ code\
   │  └─ exp02_real_sar_branch_audit\
   │     └─ fair_csar\
   │        ├─ config_exp02_fair_r0.m
   │        └─ run_exp02_fair_r0.m
   │
   └─ functions\
      └─ fair_csar\
         ├─ fair_csar_load_complex_mat.m
         ├─ fair_csar_png_orientation_corr.m
         ├─ fair_csar_read_metadata_xml.m
         └─ fair_csar_fractional_line_audit.m
```

Existing EXP01 / OpenSARShip files are not moved or modified.

## Required frozen input

Expected:

```text
data\
└─ fair_csar\
   └─ pilot_candidate_B\
      ├─ SLCMats\
      │  └─ GF3_KAS_SL_028685_E139.7_N35.5_20220120_L1A_HH_L10000000001_00000_16050.mat
      ├─ PNGImages\
      │  └─ GF3_KAS_SL_028685_E139.7_N35.5_20220120_L1A_HH_L10000000001_00000_16050.png
      └─ METAXmls\
         └─ GF3_KAS_SL_028685_E139.7_N35.5_20220120_L1A_HH_L10000000001_00000_16050.xml
```

The annotation TXT is not required by this first formal R0 script.

## Legacy dependency

The script reuses the validated FrFT implementation from the existing
reproduction line:

```text
papers\Wang2023_Fast_Accurate_FrFT\code\functions\frft_direct.m
```

The run script automatically adds the repository `papers` tree to the MATLAB
path. If `frft_direct.m` is absent, the experiment stops before producing
scientific output.

## Run

From MATLAB:

```matlab
cd('E:\SAR_Moving_Ship_Refocusing_Reproduction\research\branch_reliability_sar\code\exp02_real_sar_branch_audit\fair_csar')
run_exp02_fair_r0
```

## Output

Results are written to:

```text
research\branch_reliability_sar\results\exp02_real_sar_branch_audit\
└─ fair_csar\
   └─ r0_mclfm_compatibility\
```

For result review, upload only:

```text
EXP02_FAIR_R0_FEEDBACK_BUNDLE.txt
02_frac_score_maps.png
03_best_order_vs_range.png
04_target_background_summary.png
```

Keep CSV/MAT locally unless later requested.

## Frozen stop rule

If the target lines do not show target-specific fractional-domain structure
relative to deterministic adjacent-sea controls, stop before branch audit.
Do not tune G0 / Neighbor-3 / Proposed on this sample.
