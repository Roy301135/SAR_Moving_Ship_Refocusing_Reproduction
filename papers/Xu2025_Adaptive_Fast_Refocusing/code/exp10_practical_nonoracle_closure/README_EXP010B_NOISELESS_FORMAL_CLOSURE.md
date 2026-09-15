# EXP010-B — Noiseless Formal Closure

将本包中的文件直接复制到现有目录：

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\
papers\Xu2025_Adaptive_Fast_Refocusing\
code\exp10_practical_nonoracle_closure
```

不要删除 EXP010-A smoke 文件。

## Run

```matlab
cd('E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp10_practical_nonoracle_closure');
results = exp10b_noiseless_formal_closure;
```

## Expected upstream dependency

EXP010-B 的 DenseRisk formal validation 会读取已经冻结的 PA5I-R1 risk-state table：

```text
E:\SAR_Moving_Ship_Refocusing_Reproduction\
papers\Xu2025_Adaptive_Fast_Refocusing\
results\exp09_physical_validation\
exp09_pa5i_r1_gamma_denseeta_tail_audit\
pa5i_r1_dense_eta_risk_states.csv
```

代码会执行 storage-schema + consumer-schema + aperture/Gamma consistency audit。

## Result directory

```text
...\results\exp10_practical_nonoracle_closure\
exp10b_noiseless_formal_closure\
```

## What to send back

优先只上传：

```text
EXP010B_FEEDBACK_BUNDLE.txt
```

以及下列关键图中的 2–3 张：

```text
fig01_branch_cost_denserisk.png
fig02_weak_recovery_denserisk.png
fig03_risk_direction_auc.png
fig04_operator_gap_ladder.png
fig05_stage_branch_rescue.png
```

原始 CSV / MAT 文件保留在本地即可，除非后续审计明确要求。

## Runtime note

这是 formal full-grid run，计算量明显高于 EXP010-A smoke。程序按 validation-set / aperture natural batch 运行，并在每个 batch 完成后立即保存 batch-level CSV，避免全部结束前无落盘结果。
