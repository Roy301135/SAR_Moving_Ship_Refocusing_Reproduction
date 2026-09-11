# EXP009-C3-B2 — Safe-Subset Beneficial Opportunity Audit

## 1. 这一轮为什么不是继续优化 Harm model

C3-B1.3 已经确认：

- Harmful fate 的 q-landscape morphology observability 稳定；
- Harm-aware policy 能降低 harmful allocation；
- 但 perfect Harm avoidance 只能解释剩余 TrialOracle gap 的一小部分。

所以 C3-B2 正式把问题从：

```text
哪里不该 fallback？
```

推进到：

```text
在安全 trial 中，哪里真的值得 fallback？
```

---

# 2. 核心分解

Beneficial 的定义可以精确写成：

\[
\boxed{
B
=
C \cap R
}
\]

其中：

```text
C = CheapFailure = cheap branch 错
R = RescueSuccess = fallback branch 对
```

因此：

\[
P(B|X)
=
P(C|X)
P(R|C,X)
\]

这给了我们一个比直接预测 Beneficial 更可解释的 decomposition。

---

# 3. C3-B2 要回答三个问题

## Task A — CheapFailure

能否从当前 Cheap branch 的 q-landscape / state / residual observables 判断：

> Cheap 自己是不是已经错了？

如果这个任务 AUC 明显高于 Beneficial：

```text
主要瓶颈之一就是 cheap-reliability estimation
```

---

## Task B — Rescueability

只在真实 CheapFailure trial 内问：

> Fallback 是否真的能够救回来？

也就是：

\[
P(R|C,X)
\]

如果 CheapFailure 好预测，而 Rescueability 接近 0.5：

> 真正难的是 fallback success，而不是识别 Cheap 不可靠。

---

## Task C — Beneficial

比较：

### Direct

\[
p_{B,direct}
\]

vs

### Factorized

\[
p_{B,factor}
=
p_C p_R
\]

看 structured decomposition 是否优于直接分类。

---

# 4. 为什么还要做 Safe-Subset audit

C3-B1.3 已经有一个 Harm veto。

所以 C3-B2 同时比较：

```text
All trials
OracleSafe = true Harmful == 0
PracticalSafe = predicted pH <= C3-B1.3 threshold
```

然后问：

> 一旦明显 Harmful 被排除，Beneficial 是否变得更容易预测？

这是这一轮最核心的诊断之一。

---

# 5. Harm veto 不重新调参

C3-B2 直接读取 C3-B1.3：

```text
selected_hyperparameters.csv
```

里的：

```text
best_veto_threshold
```

不重新调一个新 Harm threshold。

原因：

> 这一轮只改变 Beneficial opportunity model，不同时改变 Harm policy。

这样可以明确知道性能变化到底来自哪里。

---

# 6. 同时补上 λ boundary sanity

C3-B1.3 原来的：

\[
\lambda=4
\]

正好碰到：

```text
0 : 0.1 : 4
```

的上边界。

C3-B2 内部会重新使用相同的 OOF Harm setup，并额外扫描：

\[
\lambda = 0:0.25:20
\]

输出：

```text
lambda_boundary_sanity.csv
fig01_lambda_boundary_sanity.png
```

这只是完整性检查，不改变 C3-B2 主路线。

---

# 7. Feature groups

C3-B2 不再继续发明新 feature，而使用上一轮已经存在的 observables。

比较：

```text
StateOnly
MorphologyOnly
StrongCompetitionOnly
SubapertureOnly
AllObservable
StateAll
```

对三个任务分别算：

```text
Beneficial AUC
CheapFailure AUC
Rescueability AUC
```

重点看：

```text
within-line AUC
```

因为 pooled AUC 很容易继续受到 physical-state mixing 影响。

---

# 8. Policy

## StateOnly

原 baseline。

---

## DirectBeneficial

直接按：

\[
p_{B,direct}
\]

排序分配 fallback。

---

## FactorizedBeneficial

按：

\[
p_Cp_R
\]

排序。

这是 C3-B2 最重要的 structured opportunity pilot。

---

## DirectBeneficialHarmVeto

```text
Direct Beneficial score
+
fixed C3-B1.3 Harm veto
```

---

## FactorizedBeneficialHarmVeto

```text
Factorized opportunity score
+
fixed C3-B1.3 Harm veto
```

它对应我们逐渐形成的三层逻辑：

\[
\boxed{
state / observables
\rightarrow
harm veto
\rightarrow
beneficial rescue ranking
}
\]

---

## OracleSafeFactorized

使用真实 Harmful label 完美 veto，再用 factorized Beneficial 排序。

它回答：

> 如果 Harmful 问题完全解决，当前 factorized Beneficial predictor 的 ceiling 是多少？

---

## TrialOracle

最终 upper bound。

---

# 9. 最重要的 GO / NO-GO 判据

## Case 1 — CheapFailure 强，Rescueability 弱

例如：

```text
CheapFailure within AUC ~0.7+
Rescueability within AUC ~0.5-0.55
```

则：

\[
\boxed{
\text{主要瓶颈 = fallback rescueability}
}
\]

下一步应研究 fallback branch 自身的可预测物理条件。

---

## Case 2 — CheapFailure 弱，Rescueability 强

则主要问题变成：

> Cheap branch 自己是否错误难以在线识别。

这时需要更直接的 Cheap-quality observables。

---

## Case 3 — 两者都中等，但 Factorized > Direct

这是很好的结果。

说明：

> structured decomposition 比直接 Beneficial classifier 更合理。

---

## Case 4 — Factorized + HarmVeto > StateOnly / Direct

这是 Strong GO。

说明：

\[
\boxed{
\text{State / Harm / Rescue 三层 computation policy 开始成立}
}
\]

---

## Case 5 — Safe-subset Beneficial 仍然 ~0.5

这是同样重要的结果。

它说明：

> 即使 Harmful 被排除，现有 observables 仍不足以判断“值不值得 rescue”。

此时不应该继续堆 logistic/MLP，而应回到信号处理机制：

```text
Cheap failure 是怎样形成的？
Fallback 为什么某些 trial 能救、某些不能？
```

然后设计新的 physically meaningful observables。

---

# 10. 目录

建议：

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c3b2_safe_subset_beneficial_audit.m
    │       └── config_exp09c3b2.m
    └── results/
        └── exp09_pilot01/
            └── exp09c3b2_safe_subset_beneficial_audit/
```

---

# 11. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01

results = exp09c3b2_safe_subset_beneficial_audit;
```

它会自动寻找：

```text
results/exp09_pilot01/
├── exp09c3b1_2_mechanism_observable_audit/
└── exp09c3b1_3_harm_aware_fallback/
```

所以请保留 C3-B1.2 和 C3-B1.3 的结果目录。

---

# 12. 最重要输出

```text
lambda_boundary_sanity.csv

feature_group_task_audit.csv
direct_vs_factorized_beneficial_audit.csv
safe_subset_composition.csv

policy_curves.csv
primary_25pct_policy_comparison.csv

beneficial_bottleneck_decomposition.csv
decision_summary.csv

summary.txt
```

---

# 13. 最重要图片

```text
fig01_lambda_boundary_sanity.png

fig02_smooth_task_audit.png
fig03_abrupt_task_audit.png

fig04_direct_vs_factorized_safe_auc.png
fig05_practical_safe_composition.png

fig06_policy_recovery_25pct.png

fig07_smooth_quality_cost.png
fig08_abrupt_quality_cost.png

fig09_beneficial_bottleneck_decomposition.png

fig10_smooth_factorized_opportunity_plane.png
fig11_abrupt_factorized_opportunity_plane.png
```

---

# 14. 本轮最想得到的答案

C3-B1.3 已经回答：

```text
我们能比较好地知道哪里不该算。
```

C3-B2 要回答：

\[
\boxed{
\text{我们到底缺的是“发现 Cheap 错了”，}
\quad
\text{还是“判断 Fallback 能不能救”？}
}
\]

这个答案会直接决定后续下一层实验应该研究哪一个物理机制。
