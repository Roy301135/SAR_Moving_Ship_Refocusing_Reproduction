# EXP009-C2.1 / Pilot-01 — Mechanism-Aware Pre-Fallback Observable Audit

## 1. 为什么做 C2.1

C2 得到了一个很重要的 Partial-PASS：

- Benefit-aware target 是合理的；
- 但只用原来的 weak-residual curve observables：
  - prominence；
  - entropy；
  - second/first；
- Linear / Quadratic Value model 并没有超过简单 Prominence / Entropy gate。

因此当前证据更支持：

> **缺的不是更复杂的模型，而是新的 information source。**

A3 / A4 / C1 已经反复说明，fallback 真正解决的是：

\[
\boxed{
\text{前一级 strong component 没有被 cheap CLEAN 干净消除}
}
\]

所以 C2.1 不再只观察“weak curve 出现了什么症状”，而开始直接观察：

> **strong-CLEAN stage 本身到底干不干净。**

---

# 2. C2.1 是否重新跑 MC？

是。

C2.1 需要回到 signal-level chain，因为 C1 的 CSV 中没有保存足够完整的 strong-stage cheap observables。

但它严格：

```text
seed = 20260909
9 selected cells
500 MC / cell
```

并完整复用 C1：

- signal model；
- noise convention；
- Cheap fixed-notch residual；
- q search；
- parametric-refit fallback；
- recovery threshold。

程序首先重新生成所有 4500 trials，然后与：

```text
c1_branch_trials.csv
```

逐 trial 检查：

```text
Cheap success
Fallback success
Cheap q
Fallback q
```

必须完全一致。

如果不一致：

> **代码直接报错并停止，不允许继续做 feature analysis。**

---

# 3. C2.1 的 experimental boundary

仍然和 C1 一样假设：

\[
q_s
\]

已经由前一级 dominant-component stage 获得。

所以当前问题仍然是：

> 在 controlled weak-stage setting 下，strong-CLEAN 的可观测状态能不能预测 fallback value？

这不是完整 sequential practical algorithm。

后续若机制成立，再加入：

```text
estimated q_strong error
multi-stage propagation
2-D ship-like target
```

---

# 4. 三组 Practical Observable

## Group A — Weak-response observables

作为 C2 baseline：

```text
cheap_prominence
cheap_entropy
cheap_second_to_first
```

---

# 5. Group B — Strong-clean observables

这些量全部来自：

\[
x_{\rm mix}
\]

在：

\[
q_s
\]

dechirp 后的 **N-point FFT**。

也就是说：

> 它们在 expensive parametric fallback 运行之前即可获得。

---

## 5.1 Fractional-bin offset

Cheap fixed-notch CLEAN 的一个核心问题是：

> strong tone 并不一定正好落在 FFT integer bin。

使用 N-point FFT 主峰三点抛物线插值，定义：

\[
\delta_f
\]

并记录：

\[
\boxed{
|\delta_f|
}
\]

输出：

```text
strong_frac_bin_offset_abs
```

直觉：

```text
接近 integer bin
    -> notch 更容易抓干净

明显 off-grid
    -> spectral leakage 更严重
```

---

## 5.2 Strong peak concentration

在 strong peak 周围：

\[
\pm 8
\]

bins 的 local window 中：

\[
C_s
=
\frac{
P_{\max}
}{
E_{\rm local}
}.
\]

输出：

```text
strong_peak_concentration
```

如果 dechirped strong peak 很尖锐：

\[
C_s\uparrow.
\]

---

## 5.3 Notch capture fraction

Cheap notch 默认移除：

\[
k_0-1,\quad k_0,\quad k_0+1.
\]

定义：

\[
\eta_{\rm notch}
=
\frac{
E_{\rm notch}
}{
E_{\rm local}
}.
\]

输出：

```text
strong_notch_capture_fraction
```

它回答：

> local strong energy 有多少本来就在 Cheap notch 能直接抓住的范围内？

---

## 5.4 Side-leakage / notch ratio

在 notch 外部，但仍靠近 strong peak 的：

```text
|bin offset| = 2...5
```

区域测量：

\[
L_s
=
\frac{
E_{\rm side}
}{
E_{\rm notch}
}.
\]

输出：

```text
strong_side_leakage_to_notch
```

这是 C2.1 最值得关注的 feature 之一。

如果：

\[
L_s\uparrow
\]

说明 strong energy 在 cheap notch 外还有明显局部结构。

它比 global residual energy 更贴近 A3/A4 发现的 coherent residual mechanism。

---

## 5.5 Local spectral width

用 strong local spectrum 的二阶矩估计：

\[
W_s
=
\sqrt{
\sum_k
(k-\bar k)^2
w_k
}.
\]

输出：

```text
strong_local_spectral_width
```

---

## 5.6 Local asymmetry

定义：

\[
A_s
=
\frac{
|E_R-E_L|
}{
E_R+E_L
}.
\]

输出：

```text
strong_local_asymmetry
```

它用于检测 strong leakage 是否呈明显单侧结构。

---

## 5.7 Global removed fraction

Cheap notch 中包含的能量占整个 dechirped spectrum：

\[
\eta_{\rm global}
=
\frac{
E_{\rm notch}
}{
E_{\rm total}
}.
\]

输出：

```text
strong_global_removed_fraction
```

它会同时受：

- strong amplitude；
- noise；
- weak component；

影响，因此既是 practical feature，也是可能的 SNR/SCR proxy。

---

# 6. Group C — Practical geometry/history observables

## 6.1 Estimated q separation

当前 previous strong stage 已有：

\[
q_s
\]

Cheap weak search 已产生：

\[
\hat q_w.
\]

因此实际可以计算：

\[
\boxed{
|\hat q_s-\hat q_w|
}
\]

当前 controlled setting 中：

\[
\hat q_s=q_s.
\]

输出：

```text
estimated_q_separation_abs
```

注意：

> 它不是 true \(|q_s-q_w|\)，而是使用 Cheap 输出的 practical estimate。

A4/B1 已经说明 relative q geometry 会影响 coherent interference，所以这一量具有明确机制依据。

---

## 6.2 Estimated strong/weak response ratio

Strong stage 主峰功率：

\[
P_s
\]

Cheap weak-search 主峰功率：

\[
P_w^{\rm cheap}
\]

构造：

\[
\boxed{
10\log_{10}
\frac{P_s}{P_w^{\rm cheap}}
}
\]

输出：

```text
estimated_strong_weak_peak_ratio_db
```

它是 practical relative-strength proxy。

---

# 7. C2.1 不再增加复杂模型

为了回答“新信息有没有价值”，模型仍然只使用简单 LOCO logistic Value model：

\[
V(x)
=
P(B|x)-P(H|x).
\]

比较五组输入：

### WeakOnly

```text
prominence
entropy
second/first
```

### StrongCleanOnly

只使用 strong-CLEAN observables。

### GeometryOnly

```text
estimated q separation
estimated strong/weak peak ratio
```

### MechanismCombined

```text
StrongClean + Geometry
```

### AllCombined

```text
Weak + StrongClean + Geometry
```

---

# 8. 为什么这次不做 Quadratic / MLP

C2 已经显示：

> quadratic complexity 没有解决问题，反而出现跨-cell calibration shift。

所以 C2.1 首先问：

\[
\boxed{
\text{新 information source 是否带来提升？}
}
\]

如果 StrongClean / MechanismCombined 已经明显优于 WeakOnly：

> 证明方向正确。

然后才讨论是否需要更灵活的 model。

---

# 9. Budget policy

仍然采用：

```text
trigger -> directly use fallback
```

不再做 post-fallback prominence selector。

评价：

\[
10\%,\quad25\%,\quad50\%
\]

及完整：

\[
0\%-100\%
\]

预算曲线。

---

# 10. 对照 policy

C2.1 比较：

```text
Prominence
Entropy
SideLeakage
WeakOnly
StrongCleanOnly
GeometryOnly
MechanismCombined
AllCombined
Oracle
RandomExpected
```

其中：

```text
SideLeakage
```

是一个完全不学习、机制可解释的 scalar baseline：

\[
L_s\uparrow
\Rightarrow
\text{更优先 fallback}.
\]

---

# 11. C2.1 最重要的评价

## 11.1 Single-feature Beneficial AUC

首先看：

> 是否有某个 strong-stage observable 单独就明显超过 Prominence / Entropy？

如果有，这会非常漂亮。

---

## 11.2 Group LOCO AUC

比较：

\[
WeakOnly
\]

和：

\[
StrongCleanOnly
\]

以及：

\[
MechanismCombined.
\]

如果：

\[
AUC_B(\text{MechanismCombined})
\gg
AUC_B(\text{WeakOnly}),
\]

说明缺失信息已经被找到。

---

## 11.3 Beneficial Capture @ fixed budget

这是最重要的 policy metric。

尤其 25% budget：

C2 baseline 大约只能捕获：

\[
55\%-57\%
\]

beneficial trials。

如果 mechanism-aware features 能明显提高到更高水平，就意味着：

\[
\boxed{
\text{从 strong-stage 直接观察 cancellation quality 是有效的}
}
\]

---

## 11.4 Weak Recovery / Cost Pareto

最终仍然看：

\[
\boxed{
\text{Quality--Computation trade-off}
}
\]

而不是只看 AUC。

---

# 12. Success criteria

## Strong GO

如果出现：

```text
StrongCleanOnly / MechanismCombined
    > WeakOnly
    > Prominence/Entropy
```

并且：

- Beneficial Capture 明显提高；
- 25% budget Recall 明显提高；
- Harmful allocation 不恶化；
- LOCO 下仍成立；

那么下一阶段就可以开始正式形成：

> **Mechanism-aware Benefit Predictor**

甚至这时才有理由考虑 small learned model。

---

## Partial GO

某些 strong-stage scalar 很有信息，但融合模型跨 cell 不稳定。

那么优先设计：

> 更简单的 physics score / monotonic policy，

而不是更复杂分类器。

---

## NO-GO

StrongClean / Geometry 都没有超过 WeakOnly。

那么说明：

> 目前这种 N-point cheap-stage observable 仍然没有直接暴露真正 residual contamination state。

后续才考虑：

-更局部的 residual projection；
- matched-response contamination proxy；
- sequential history；
- weak-aware residual suppression。

---

# 13. 主要输出

```text
c2_1_trial_mechanism_features.csv
mechanism_feature_audit.csv
group_loco_diagnostics.csv
mechanism_budget_curves.csv
reported_budget_points.csv
cell_mechanism_diagnostics.csv
summary.txt
exp09c2_1_results.mat
```

---

# 14. 主要图

```text
fig01_mechanism_feature_auc.png
fig02_group_loco_auc.png
fig03_beneficial_capture_vs_budget.png
fig04_quality_cost_pareto.png
fig05_policy_comparison_25pct.png
fig06_precision_25pct.png
fig07_side_leakage_by_value_class.png
fig08_geometry_leakage_plane.png
fig09_cell_mechanism_map.png
```

---

# 15. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09c2_1_mechanism_observable_audit.m
    │       └── config_exp09c2_1.m
    └── results/
        └── exp09_pilot01/
            └── exp09c2_1_mechanism_observable_audit/
```

---

# 16. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09c2_1_mechanism_observable_audit;
```

---

# 17. 运行成本

C2.1 重新执行完整 4500-trial signal chain：

```text
Cheap q search
+
Parametric-refit fallback
+
Strong-stage observable extraction
```

所以运行时间预计接近 C1，而不是 C2。

建议正式结果直接使用：

```matlab
cfg.num_mc = 500;
```

因为程序需要与 C1 逐 trial 精确复现。

如果改成 50：

> 就无法与现有 C1 CSV 做完整 reproduction check。

因此本轮不建议先改小 MC，直接运行完整版本。
