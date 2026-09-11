# EXP009-C2.2 / Pilot-01 — State-vs-Realization Predictability Decomposition

## 1. 为什么进入 C2.2

C2.1 已经得到一个很明确的结果：

- Cheap / Fallback / Oracle 的总体性能空间仍然很大；
- 但是新增的 strong-CLEAN scalar observables 并没有在 LOCO 下超过 WeakOnly；
- `strong_side_leakage_to_notch` 甚至不能形成有效的 Beneficial predictor；
- pooled single-feature AUC 看起来尚可，但跨 cell 的 LOCO generalization 明显下降。

因此下一步不应该继续：

```text
再加 feature
再加二次项
再上 MLP
```

而应该先回答：

> **Fallback value 到底主要是 parameter-state / cell-level property，还是 single-realization property？**

这就是 C2.2。

---

# 2. C2.2 不重新跑信号级 Monte Carlo

C2.2 直接读取：

```text
C2.1/
└── c2_1_trial_mechanism_features.csv
```

并读取：

```text
C1/
└── c1_branch_trials.csv
```

用于补充每个 cell 的实验参数：

```text
A_w / A_s
q_s - q_w
SNR
```

所以 C2.2 是纯统计诊断实验。

---

# 3. 核心研究问题

我们已经看到某些 feature pooled AUC 不低，例如：

```text
cheap prominence
cheap entropy
estimated strong/weak peak ratio
```

但这可能有两种完全不同的来源。

---

## 情况 A：真正的 single-realization predictability

同一个 parameter cell 内：

```text
trial #17
trial #18
trial #19
```

即使物理状态相同，仅仅因为 noise realization 不同，

feature 仍然能够判断：

```text
哪一个 trial 更值得 fallback。
```

如果是这种情况：

> sample-wise confidence / Value-of-Computation predictor 仍然值得继续做。

---

## 情况 B：主要是 state-level predictability

例如：

```text
Cell A 本身就是高风险状态
Cell B 本身就是低风险状态
```

而某个 feature 只是在区分：

```text
A-like states
vs
B-like states
```

并不能在 Cell A 内继续区分：

```text
哪个 realization 会被 fallback 救回来。
```

如果是这种情况：

> 未来更合适的方向可能是 region / track / history-level adaptive computation，而不是 single-shot classifier。

---

# 4. Feature Predictability Decomposition

对每一个 feature：

\[
x
\]

C2.2 同时计算三类 AUC。

---

## 4.1 Pooled AUC

直接使用所有 4500 trials：

\[
AUC_{\rm pooled}
=
AUC(x,Y_B).
\]

这就是 C2.1 中类似的 single-feature audit。

但它混合了：

```text
between-cell information
+
within-cell information
```

所以不能单独解释成 single-trial predictability。

---

## 4.2 Cell-centered pooled AUC

对每个 cell 做：

\[
x'_{ic}
=
x_{ic}-\bar x_c.
\]

也就是把每个 cell 的平均 feature level 消掉。

然后计算：

\[
AUC_{\rm centered}
=
AUC(x',Y_B).
\]

如果：

\[
AUC_{\rm pooled}\gg0.5
\]

但：

\[
AUC_{\rm centered}\approx0.5,
\]

说明 feature 的预测信息主要来自：

\[
\boxed{\text{between-cell state difference}}
\]

而不是 realization difference。

---

## 4.3 Same-direction Within-cell AUC

首先利用 pooled relationship 确定统一方向：

```text
feature 越大越危险
```

或：

```text
feature 越小越危险。
```

然后这个方向在所有 cell 内保持固定。

对每个拥有正负样本的 cell：

\[
AUC_c
\]

单独计算。

最后报告：

```text
mean within-cell AUC
weighted within-cell AUC
std
valid cell count
```

这里故意不允许：

> 每个 cell 自己翻转 feature 方向。

否则会人为夸大 within-cell predictability。

---

# 5. Between-cell eta-squared

对 feature：

\[
x
\]

计算：

\[
\boxed{
\eta^2
=
\frac{SS_{\rm between}}
{SS_{\rm total}}
}
\]

它回答：

> feature 总方差中，有多少是由 cell mean difference 解释的？

同时对 target 本身：

```text
Beneficial
Harmful
Net fallback utility
```

也计算 cell-level：

\[
\eta^2.
\]

这能判断：

> fallback value 本身到底有多强的 state heterogeneity。

---

# 6. State-level fallback utility

每个 cell 定义：

\[
p_{B,c}
=
P(Beneficial|c)
\]

\[
p_{H,c}
=
P(Harmful|c)
\]

因此：

\[
\boxed{
u_c
=
p_{B,c}
-
\lambda_H p_{H,c}
}
\]

默认：

\[
\lambda_H=1.
\]

解释：

> 如果在这个 cell 内随机挑一个 realization 做 fallback，平均能得到多少 recovery gain？

---

# 7. State Oracle

这是 C2.2 最关键的 diagnostic upper bound。

State Oracle：

- **不知道 individual trial 是否 Beneficial**；
- 只知道每个 cell 的平均：
  \[
  u_c
  \]
- 预算优先分给高 \(u_c\) cell；
- 在同一个 cell 内随机选择 trial。

因此它介于：

\[
\text{Random}
\]

和：

\[
\text{Trial Oracle}
\]

之间。

---

# 8. 三个核心 upper bound

## Random Expected

完全不知道 state，也不知道 realization：

\[
R_{\rm random}(b)
=
R_C
+
b(P_B-\lambda_HP_H).
\]

---

## State Oracle

知道：

\[
u_c
\]

但不知道 cell 内 individual trial fate。

---

## Trial Oracle

直接知道：

```text
Cheap fail
Fallback success
```

的具体 trial。

它仍然是完整上界。

---

# 9. 最关键的 C2.2 指标

定义在相同 budget 下：

\[
R_R
=
R_{\rm random}
\]

\[
R_S
=
R_{\rm state}
\]

\[
R_T
=
R_{\rm trial-oracle}.
\]

则：

\[
\boxed{
F_{\rm state}
=
\frac{
R_S-R_R
}{
R_T-R_R
}
}
\]

表示：

> **全部“智能 allocation”相对于随机分配能获得的优势中，有多少仅靠 state knowledge 就已经可以解释？**

---

## 如果 \(F_{\rm state}\) 很高

例如：

\[
0.6,\ 0.7,\ 0.8...
\]

说明：

\[
\boxed{
\text{fallback value 很大程度是 state-level property}
}
\]

那么下一步应转向：

```text
track
region
history
sequential state
```

而不是继续 feature fishing。

---

## 如果 \(F_{\rm state}\) 很低

但 within-cell AUC 明显高于 0.5：

说明：

> single-realization information 仍然很重要。

这时继续 sample-wise Value predictor 才有意义。

---

# 10. Cell-level physical-state map

C2.2 同时把：

\[
u_c
\]

画在：

\[
(q_s-q_w,\ A_w/A_s)
\]

平面上。

SNR 信息保存在：

```text
cell_state_summary.csv
```

中。

这一步不是为了建立物理参数 oracle 方法，而是确认：

> parameter-state risk 是否呈稳定结构。

---

# 11. Practical Prominence / Entropy 仍作为参考

如果 C2.1 的：

```text
mechanism_budget_curves.csv
```

存在，

C2.2 会把：

```text
Prominence
Entropy
```

一起画进：

\[
\text{State Oracle vs Trial Oracle}
\]

quality-cost 图中。

这样可以直观看：

```text
Practical single-shot baseline
vs
State-level upper bound
vs
Trial-level upper bound
```

之间分别还有多少空间。

---

# 12. 主要输出

```text
cell_state_summary.csv
label_state_variance.csv

state_vs_realization_predictability.csv
within_cell_auc_by_feature.csv
state_feature_correlations.csv

state_vs_trial_budget_curves.csv
state_oracle_gain_decomposition.csv

summary.txt
exp09c2_2_results.mat
```

---

# 13. 主要图

```text
fig01_pooled_vs_within_auc.png
fig02_feature_between_cell_eta2.png
fig03_label_state_variance.png
fig04_within_cell_auc_heatmap.png

fig05_state_vs_trial_quality_cost.png
fig06_state_explainable_gain.png

fig07_cell_state_utility_map.png
fig08_cellmean_feature_correlations.png
```

---

# 14. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c2_2_state_vs_realization.m
    │       └── config_exp09c2_2.m
    └── results/
        └── exp09_pilot01/
            └── exp09c2_2_state_vs_realization/
```

---

# 15. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09c2_2_state_vs_realization;
```

本轮不重新运行 FrAc / CLEAN / fallback，因此速度应该很快。

---

# 16. C2.2 的判断标准

## Case A — Strong State-Level Evidence

出现：

```text
pooled AUC 明显高
centered / within-cell AUC 接近 0.5
State Oracle 吃到 Trial Oracle 大部分 selection advantage
```

则下一步转向：

\[
\boxed{
\text{history / track / region-level adaptive computation}
}
\]

---

## Case B — Mixed Hierarchy

State Oracle 能解释一部分，但 within-cell AUC 仍明显大于 0.5。

则后续应做：

```text
state prior
+
single-shot refinement
```

即 hierarchical policy。

---

## Case C — Strong Realization-Level Evidence

State Oracle 与 Random 接近，

但 within-cell predictor 很强。

则继续：

```text
single-shot Value-of-Computation predictor
```

更合理。

---

# 17. 一个重要边界

`StateOracle` 使用真实 cell-average beneficial/harmful rates，因此：

> 它是 diagnostic upper bound，不是 practical method。

C2.2 的目标不是直接投稿一个 state oracle，而是决定：

\[
\boxed{
\text{我们下一阶段应该在哪一个时间/空间尺度上预测计算价值？}
}
\]
