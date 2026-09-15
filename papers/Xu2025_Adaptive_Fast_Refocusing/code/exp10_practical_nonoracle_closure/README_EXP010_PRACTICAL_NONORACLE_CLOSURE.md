# EXP009 — Practical Non-Oracle Closure

## Placement

Create this directory:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_practical_nonoracle_closure
```

Place the two `.m` files and the implementation-freeze document in it.

Results are written automatically to:

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\results\exp09_practical_nonoracle_closure
```

This directory is intentionally parallel to the old `code\exp09_physical_validation` directory. The old directory is not modified.

## First run

MATLAB:

```matlab
cd('E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_practical_nonoracle_closure');
results = exp09_practical_nonoracle_closure;
```

The default configuration is `run_mode = "smoke"`.

Do **not** change to `formal` before the smoke output has been audited.

## Expected outputs

```text
results\exp09_practical_nonoracle_closure\
├── truth_metadata.csv
├── practical_online_outputs.csv
├── evaluation_trials.csv
├── method_summary.csv
├── paired_outcome_summary.csv
├── oracle_firewall_audit.csv
├── summary.txt
└── figures\
    ├── fig01_weak_recovery.png
    ├── fig02_branch_cost_reliability.png
    ├── fig03_beta_eta_errors.png
    └── fig04_weak_search_vs_residual.png
```

## What to send back after running

Please send back at minimum:

- `summary.txt`
- `method_summary.csv`
- `paired_outcome_summary.csv`
- `oracle_firewall_audit.csv`
- the four figures

If MATLAB throws an error, send the complete error stack instead of modifying thresholds or search widths locally.

## Interpretation boundary

This smoke test does not yet close Claim 1 / Claim 2. It asks only whether the frozen method survives a full non-oracle deterministic chain with the remaining implementation gaps removed.
