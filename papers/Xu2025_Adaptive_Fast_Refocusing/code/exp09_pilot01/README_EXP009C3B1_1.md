# EXP009-C3-B1.1 — State + Instantaneous Realization Complementarity

## 1. 为什么在 C3-B1 后插入这一轮

C3-B1 已经给出了三个非常关键的事实：

1. 连续变化的 signal parameters 确实产生了稳定、可重复的 line-level fallback-utility state；
2. EMA 只小幅改善 trial-level state observability，并没有稳定改善 matched-budget recovery；
3. PhysicalStatePrior 有价值，但依然远低于 TrialOracle。

因此当前真正的问题已经从：

```text
history 是否还能更聪明？
```

转成：

> **在相同 physical state 下，instantaneous residual evidence 是否还能解释“这一发为什么值得 fallback”？**

即：

\[
P(B\mid S,X)
\]

是否显著优于：

\[
P(B\mid S)
\]

和：

\[
P(B\mid X),
\]

其中：

- \(S\)：signal-generated physical-state prior；
- \(X\)：当前 realization 的 observable residual evidence。

---

# 2. 本实验不重新跑 signal simulation

C3-B1.1 直接复用：

```text
exp09c3b1_signal_level_continuous_state/
```

中的：

```text
train_trials_smooth.csv
train_trials_abrupt.csv
test_trials_smooth.csv
test_trials_abrupt.csv
```

因此这轮运行速度会远快于 C3-B1。

---

# 3. 一个非常重要的 anti-leakage 设计

TEST state prior：

\[
u_{\rm train}(k)
=
E_{\rm TRAIN}
[
\text{fallback success}
-
\text{cheap success}
\mid k
]
\]

只由 TRAIN ensemble 得到。

TEST label 完全不参与。

---

## TRAIN 也做 cross-fit

为了避免 TRAIN 某个 realization 的自身 outcome 反过来进入自己的 state feature：

对 TRAIN sequence \(m\)，构造：

\[
u_{-m}(k)
\]

时排除整个 sequence \(m\) 在对应 line 的 outcome。

也就是：

```text
TRAIN realization
    -> state prior from OTHER TRAIN sequences
```

随后再做与 C3-B1 相同的 7-line smoothing。

这样 StateOnly / Additive / Interaction 的 TRAIN 输入不会直接含有自身标签。

---

# 4. Signed fallback value

每个 trial 定义：

\[
Y
=
I(\text{Fallback success})
-
I(\text{Cheap success})
\]

因此：

```text
Beneficial -> +1
Neutral    ->  0
Harmful    -> -1
```

这和：

\[
P_B-P_H
\]

完全对应。

---

# 5. Instantaneous observables

第一版仍然只保留两个已经反复验证过的 observable：

```text
cheap prominence
cheap entropy
```

不继续堆 feature。

利用 pooled TRAIN empirical CDF：

\[
r_p
=
1-F_p(\text{prominence})
\]

\[
r_e
=
F_e(\text{entropy})
\]

得到：

```text
risk_prominence
risk_entropy
```

同时保留：

\[
r_{\rm legacy}
=
(r_p+r_e)/2
\]

作为 C3-B1 InstantPE reference。

---

# 6. 四个嵌套模型

为了让“信息增益”而不是“模型复杂度”成为唯一主要变化，所有模型都使用同一种：

> **two-headed ridge logistic model**

即：

\[
p_B
=
P(Beneficial\mid X)
\]

\[
p_H
=
P(Harmful\mid X)
\]

最后：

\[
\boxed{
V
=
p_B-p_H
}
\]

作为 fallback-value score。

---

## 6.1 StateOnly

输入：

\[
X_S=[u(k)].
\]

问：

> 只知道当前 physical state，能做到多少？

---

## 6.2 InstantOnly

输入：

\[
X_I=[r_p,r_e].
\]

问：

> 只知道当前 realization 的 residual evidence，能做到多少？

---

## 6.3 Additive

输入：

\[
X_A=[u,r_p,r_e].
\]

这是本轮最关键的模型。

如果：

\[
\boxed{
Additive
>
\max(StateOnly,InstantOnly)
}
\]

说明：

> state information 和 realization information 真正互补。

---

## 6.4 Interaction

增加：

\[
u\cdot r_p
\]

和：

\[
u\cdot r_e.
\]

因此：

\[
X_{\rm int}
=
[u,r_p,r_e,u r_p,u r_e].
\]

它回答更深一层的问题：

> 同一个 instantaneous observable，在不同 physical states 下是否具有不同含义？

如果：

```text
Interaction >> Additive
```

则未来值得做 state-conditioned nonlinear policy。

如果：

```text
Interaction ≈ Additive
```

则简单 additive fusion 已经够了，不必马上引入复杂 AI。

---

# 7. 为什么不直接上深度学习

这一轮是 information audit。

如果连：

```text
State + 2 instantaneous features
```

都没有显著互补性，

那么直接上：

```text
MLP / Transformer / GRU
```

很可能只是增加复杂度，而不是解决缺信息。

反之，如果明确发现：

```text
state information
+
within-state realization information
```

互补，

那么后续才有充分理由让学习模型去拟合：

\[
P(B\mid S,X).
\]

---

# 8. Ridge 参数

固定：

```text
lambda = 0.10
```

不做大规模 hyperparameter search。

原因是当前目标不是寻找最高 AUC，而是判断：

> nested feature sets 之间是否存在稳定的信息增益。

---

# 9. 第一组核心指标：Pooled AUC

分别计算：

```text
Beneficial AUC
Harmful AUC
```

四个模型严格同架构比较。

最重要的是：

\[
AUC_{Add}
-
\max(AUC_{State},AUC_{Instant}).
\]

---

# 10. 第二组核心指标：Within-line AUC

这是本实验最重要的新指标之一。

对每一条固定 azimuth line \(k\)：

```text
physical state fixed
```

只比较同一 line 不同 Monte-Carlo realizations。

计算：

\[
AUC_k.
\]

再按：

\[
N_{B,k}N_{\bar B,k}
\]

做 pair-count weighted average。

因此：

\[
\boxed{
\text{Within-line AUC}
}
\]

直接回答：

> **在 state 完全固定以后，instantaneous observables 还能不能区分 realization fate？**

---

## StateOnly 的预期

同一 line：

\[
u(k)
\]

完全一样。

因此理论上：

\[
AUC_{\rm within,State}=0.5.
\]

---

## InstantOnly 如果明显大于 0.5

例如：

\[
AUC_{\rm within,Instant}>0.55,
\]

则可以非常明确地说：

> realization-level information 确实存在。

---

# 11. 第三组：State-bin conditional AUC

把 state prior 分成约 5 个 bins。

分别计算：

```text
InstantOnly
Additive
Interaction
```

在每个 state bin 内的 Beneficial AUC。

这可以判断：

### 情况 A

所有 state bin 都：

\[
AUC>0.5
\]

说明 instantaneous evidence 跨状态都有价值。

### 情况 B

只有高风险 / 低风险 state 有明显 AUC

说明：

> realization information 本身是 state-dependent。

这时 Interaction / state-conditioned model 就更合理。

---

# 12. 第四组：Quality–Cost

仍采用统一定义：

\[
\text{Normalized q-search budget}
=
1+
\text{fallback rate}.
\]

比较：

```text
StateOnly
InstantOnly
Additive
Interaction
TrialOracle
RandomExpected
```

重点仍然看：

```text
10%
25%
50%
```

fallback budget。

---

# 13. 第五组：Oracle-gap capture

对固定 budget：

\[
f
=
\frac{
R_{\rm model}-R_{\rm random}
}{
R_{\rm oracle}-R_{\rm random}
}.
\]

它回答：

> 当前信息集解释了 TrialOracle allocation opportunity 的多少？

这比单纯比较 recovery 差 0.01 更有解释性。

---

# 14. 最关键的 GO / NO-GO

## Strong GO — 真正互补

如果两种 regime 下大体满足：

\[
AUC_{Add}
>
\max(AUC_{State},AUC_{Instant})
\]

并且：

\[
R_{Add,25}
>
\max(R_{State,25},R_{Instant,25}),
\]

同时 within-line Instant AUC 明显：

\[
>0.5,
\]

那么可以建立：

\[
\boxed{
\text{physical state}
+
\text{realization evidence}
}
\]

两层信息架构。

这将成为后续方法设计最重要的依据。

---

## Partial GO — realization information 存在，但 fusion 仍弱

如果：

```text
within-line AUC > 0.5
```

明显成立，

但 Additive policy improvement 很小，

说明：

> 信息存在，但当前两个 scalar observables / 线性融合不足。

这时才值得继续：

```text
curve shape
sub-aperture consistency
strong-refit residual features
small learned model
```

---

## Interaction GO

如果：

\[
Interaction>Additive
\]

明显成立，

说明：

> observable 的语义依赖 physical state。

未来可考虑：

```text
state-conditioned MLP
mixture-of-experts
lightweight gating
```

而不是一个全局统一 score。

---

## NO-GO — 真正缺 realization information

如果：

\[
AUC_{\rm within,Instant}\approx0.5
\]

且：

```text
Additive ≈ StateOnly
```

那么可以比较有把握地说：

> prominence / entropy 主要只是在估计 state，而没有提供足够的 within-state realization information。

此时下一步应转向寻找新的 signal observables，而不是继续融合或堆模型。

---

# 15. 输出

```text
state_prior_reproducibility.csv
model_coefficients.csv

test_predictions_smooth.csv
test_predictions_abrupt.csv

model_information_audit.csv
state_bin_conditional_auc.csv

complementarity_budget_curves.csv
reported_budget_points.csv

oracle_gap_capture.csv
complementarity_summary.csv
interaction_value_calibration.csv

summary.txt
exp09c3b1_1_results.mat
```

---

# 16. 主要图

```text
fig01_beneficial_auc_audit.png

fig02_within_line_beneficial_auc.png

fig03_smooth_quality_cost.png
fig04_abrupt_quality_cost.png

fig05_policy_comparison_25pct.png

fig06_oracle_gap_capture_25pct.png

fig07_smooth_state_bin_auc.png
fig08_abrupt_state_bin_auc.png

fig09_interaction_value_calibration.png

fig10_smooth_state_realization_plane.png
```

---

# 17. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c3b1_1_state_realization_complementarity.m
    │       └── config_exp09c3b1_1.m
    └── results/
        └── exp09_pilot01/
            ├── exp09c3b1_signal_level_continuous_state/
            └── exp09c3b1_1_state_realization_complementarity/
```

---

# 18. 运行

确保 C3-B1 的四个 raw trial CSV 已经存在。

然后：

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01

results = exp09c3b1_1_state_realization_complementarity;
```

本轮不重新生成 MC-LFM，因此应该明显快于 C3-B1。

---

# 19. 优先返回给我的结果

请优先上传：

```text
summary.txt
model_information_audit.csv
complementarity_summary.csv
reported_budget_points.csv
oracle_gap_capture.csv
```

以及：

```text
fig01_beneficial_auc_audit.png
fig02_within_line_beneficial_auc.png
fig03_smooth_quality_cost.png
fig04_abrupt_quality_cost.png
fig05_policy_comparison_25pct.png
fig06_oracle_gap_capture_25pct.png
fig07_smooth_state_bin_auc.png
fig08_abrupt_state_bin_auc.png
fig09_interaction_value_calibration.png
```

其中最先看：

```text
fig02
complementarity_summary.csv
fig06
```

因为这三项最直接回答：

> **同一 physical state 下，当前 realization 到底有没有额外可利用的信息？**
