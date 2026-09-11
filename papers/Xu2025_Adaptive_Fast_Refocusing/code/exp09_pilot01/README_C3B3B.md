# EXP009-C3-B3B — Near-Shift Mechanism and Local Peak Recovery

## 1. 为什么现在做 B3B

C3-B3A 已经把 Rescueability failure 压缩得很明确：

- fallback failure 中绝大多数是 **NearShift**；
- PeakCompetition 很少；
- strong residual / weak residual 的区分能力很弱；
- weak retention 几乎为 1；
- true weak basin 的响应通常仍接近 global maximum。

因此现在不应继续把主要精力放在：

```text
“strong 还要不要删得更干净？”
```

而要转向：

> **为什么 residual weak-q peak 会发生小幅位移，以及这种位移能否被低成本纠正？**

---

# 2. C3-B3B 的三个核心问题

## B3B-1：A4/B1 的 first-order law 能否延伸到这里？

沿用 A4 的思想。

Fallback residual 被严格分解为：

\[
R = E_w + E_s + E_n
\]

在 fine matched-response q grid 上：

\[
P_{\text{total}}(q)
=
P_w(q)
+
P_s(q)
+
P_n(q)
+
P_{ws}(q)
+
P_{wn}(q)
+
P_{sn}(q)
\]

在 weak-only peak \(q_0\) 附近：

\[
\delta q_{\text{pred}}
\approx
-\frac{\Delta P'(q_0)}
{P_w''(q_0)}
\]

其中：

\[
\Delta P
=
P_s+P_n+P_{ws}+P_{wn}+P_{sn}
\]

代码会分别输出：

```text
strong power contribution
noise power contribution
weak-strong cross contribution
weak-noise cross contribution
strong-noise cross contribution
```

目的不是为了直接做算法，而是先回答：

> **NearShift 的数学机制是不是 A4/B1 那条 perturbation slope / curvature 关系？**

---

# 3. B3B-2：是不是 q-grid 太粗？

当前：

```text
coarse q step = 0.001
tau_q = 0.003
```

所以一个非常自然的问题是：

```text
是不是只是离散网格导致：
3 bins -> success
4 bins -> failure？
```

本实验对 coarse fallback failures 再做一次：

```text
q step = 0.0005
```

的完整 full search。

如果 half-grid 能救回很多失败：

> 说明 C3-B3A 的 NearShift 很大程度是 numerical discretization。

如果 half-grid 几乎救不回来：

> 说明 peak 本身真的发生了 physical / stochastic bias，而不是网格问题。

---

# 4. B3B-3：局部 curve geometry 能不能自己把 q 拉回来？

这部分完全不使用 q_weak。

在 observed coarse fallback curve 上比较：

```text
CoarseTop1

Parabolic3
    -> top peak 左/中/右三个点做抛物线插值

LogQuadratic5
    -> top peak 附近 5 点对 log concentration 做二次拟合

LocalCentroid7
    -> top peak 附近 7 点做局部加权质心
```

这些方法几乎不增加 q-search cost。

因此它们是在测试：

> **NearShift 的 correction information 是否已经藏在 local curve shape 中？**

---

# 5. Cheap / fallback error coupling

C3-B3A 中：

```text
Cheap absolute q error
```

对 fallback success 有明显比其他 pre-fallback features 更强的区分能力。

所以本轮进一步直接测：

\[
e_C
=
\hat q_{\text{cheap}}-q_w
\]

和：

\[
e_F
=
\hat q_{\text{fallback}}-q_w
\]

之间的：

- Pearson；
- Spearman；
- sign agreement；
- linear slope。

注意：

> 这是 **oracle mechanism diagnostic**。

因为误差本身用到了 \(q_w\)。

如果二者高度相关，下一步不能直接拿 oracle error 做算法，而应转成：

```text
history prior
previous-line q
local state estimate
subaperture evidence
```

等可观测 proxy。

---

# 6. 主要输出

## Trial-level

```text
trial_diagnostics_smooth.csv
trial_diagnostics_abrupt.csv
trial_diagnostics_all.csv
```

---

## Practical local estimators

```text
estimator_comparison.csv
nearshift_correction_diagnostics.csv
```

---

## Grid audit

```text
halfgrid_rescue_diagnostic.csv
```

---

## First-order theory

```text
first_order_validation.csv
perturbation_contribution_summary.csv
```

---

## Cheap/fallback coupling

```text
cheap_fallback_error_coupling.csv
```

---

## Final decision

```text
decision_summary.csv
summary.txt
```

---

# 7. 最重要图片

优先看：

```text
fig01_firstorder_measured_vs_predicted.png

fig02_nearshift_perturbation_contributions.png

fig03_practical_local_estimators.png

fig04_halfgrid_failure_rescue.png

fig05_smooth_nearshift_error_estimators.png
fig06_abrupt_nearshift_error_estimators.png

fig07_cheap_fallback_error_coupling.png

fig08_local_correction_direction.png
```

---

# 8. 如何解释结果

## 情况 A：first-order correlation 很高

例如：

```text
Pearson / Spearman > 0.7
sign agreement 明显 > 0.5
```

说明：

> A4/B1 的数学机制已经真正延伸到 noisy fallback residual。

这是非常有价值的理论闭环。

---

## 情况 B：half-grid 几乎没救回来

说明：

> NearShift 不是 q-grid artifact，而是真实的 residual-induced peak bias。

这会大幅增强机制结论的可信度。

---

## 情况 C：Parabolic / LogQuadratic / Centroid 有明显增益

例如 recovery 明显提升且几乎没有新增 q evaluation：

> 局部 curve shape 本身已经带有 correction information。

这可能直接形成一个非常轻量的方法入口。

---

## 情况 D：局部拟合几乎没增益，但 first-order law 很强

这反而也是很干净的结果：

> shift 可以被解释，但不能只靠 top-peak 邻域观测进行恢复。

那么下一步需要额外证据：

- history；
- previous line；
- subaperture；
- multi-look；
- neighborhood consensus。

---

## 情况 E：Cheap / fallback error 强相关

说明：

> Cheap 和 fallback 可能共享同一个 perturbation direction。

下一步最自然的是：

> **C3-B3C：History/Prior-Assisted Near-Shift Correction**

而不是直接训练大模型。

---

# 9. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c3b3b_nearshift_mechanism_local_recovery.m
    │       └── config_exp09c3b3b.m
    └── results/
        └── exp09_pilot01/
            └── exp09c3b3b_nearshift_mechanism_local_recovery/
```

---

# 10. 运行

```matlab
results = exp09c3b3b_nearshift_mechanism_local_recovery;
```

---

# 11. 这一轮最希望回答的一句话

\[
\boxed{
\text{NearShift 到底是}
\;
\text{grid artifact，}
\;
\text{还是 A4 型 residual perturbation 引起的真实 peak bias？}
}
\]

以及进一步：

\[
\boxed{
\text{这种 bias 能否从 local curve geometry 里低成本纠回来？}
}
\]

这两个答案将直接决定下一步是：

```text
simple local correction
```

还是：

```text
history / subaperture / multi-look assisted correction
```
