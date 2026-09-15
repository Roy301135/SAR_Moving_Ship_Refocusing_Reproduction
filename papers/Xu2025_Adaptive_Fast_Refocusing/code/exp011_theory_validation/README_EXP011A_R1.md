# EXP011-A-R1 — TB1 T3A Audit Correction

Place both `.m` files in:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp011_theory_validation
```

Keep the original EXP011-A files unchanged for provenance.

Run first:

```matlab
results = exp011a_r1_tb1_t3a_geometry_audit("smoke");
```

Then, if smoke is clean:

```matlab
results = exp011a_r1_tb1_t3a_geometry_audit("formal");
```

Results are written to a new directory:

```text
results\exp011_theory_validation\exp011a_r1_tb1_t3a_geometry_audit\
```

Send back:

```text
EXP011A_R1_TB1_T3A_FEEDBACK_BUNDLE.txt
exp011a_r1_tb1_t3a_verdict.csv
exp011a_r1_tb1_t3a_regime_summary.csv
exp011a_r1_tb1_t3a_mismatch_taxonomy.csv
```

This rerun changes no theory or frozen experiment parameter.
