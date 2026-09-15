# EXP010-B-R1 — Neighbor-3 Ownership Audit

Place these files in the existing EXP010 code folder:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\
papers\Xu2025_Adaptive_Fast_Refocusing\
code\exp10_practical_nonoracle_closure
```

Required prior result folder:

```text
...\results\exp10_practical_nonoracle_closure\
exp10b_noiseless_formal_closure
```

Required prior files are read automatically:

- `truth_metadata_all.csv`
- `practical_online_outputs_all.csv`
- `evaluation_trials_all.csv`

Run:

```matlab
results = exp10b_r1_neighbor3_ownership_audit;
```

Outputs are written to:

```text
...\results\exp10_practical_nonoracle_closure\
exp10b_r1_neighbor3_ownership_audit
```

For feedback, normally upload only:

```text
EXP010B_R1_FEEDBACK_BUNDLE.txt
figures/fig01_neighbor3_failure_ownership.png
```

The experiment is an evaluation-only mechanism audit. It does not modify the frozen Proposed policy.
