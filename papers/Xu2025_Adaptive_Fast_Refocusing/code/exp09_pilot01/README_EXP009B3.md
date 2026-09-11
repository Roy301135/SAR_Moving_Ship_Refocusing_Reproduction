# EXP009-B3 / Pilot-01 — Observable Reliability Surrogate

## 1. 为什么进入 B3

B2 已经得到两个非常重要的结论：

1. Oracle physics index

\[
\Gamma=\frac{|\delta q_{\rm pred}|}{\tau_q}
\]

对 dangerous cell 有很强的排序能力；

2. 但 \(\Gamma\) 不是完整 predictor。

特别是 B2 中存在：

- 小 \(\Gamma\) 但仍出现明显 stochastic perturbative failure 的 cell；
- 以及真正 catastrophic peak replacement 的 cell。

因此现在真正的问题变成：

> **真实算法能不能只根据 residual q-search curve 本身，识别这些危险状态？**

这就是 B3。

---

## 2. B3 不再使用 Oracle 量作为输入特征

真实算法不知道：

```text
true q_weak
P_cross'
P_weak''
Gamma
```

因此 B3 的所有 candidate features 都只从：

```text
residual concentration curve M(q)
```

以及：

```text
pre-CLEAN / residual signal energy
```

中计算。

真实 q 只用于 synthetic ground-truth label。

---

## 3. Trial-level ground truth

每个 B2 selected cell 重新运行 500 次 paired Monte Carlo。

### Baseline

```text
s_weak + noise
```

### Residual

```text
s_weak + filtered_strong_residual + noise
```

使用相同 noise realization。

---

### Residual-induced failure

```text
baseline succeeds
AND
residual fails
```

这样排除了：

```text
weak 本身就不可恢复
```

导致的 intrinsic failure。

---

### Perturbative failure

```text
residual-induced failure
AND
|q_hat - q_weak| < catastrophic threshold
```

---

### Catastrophic failure

```text
baseline succeeds
AND
|q_hat - q_weak| >= 0.01
```

---

## 4. Observable feature set

### 4.1 Peak competition

```text
second_to_first
peak_margin_norm
second_peak_separation_q
competitor_count
```

其中：

\[
\text{second\_to\_first}
=
\frac{M_2}{M_1}
\]

越接近 1，说明主峰竞争越强。

---

### 4.2 Peak confidence relative to floor

```text
prominence
peak_to_floor
peak_zscore
margin_to_mad
```

其中：

\[
\text{margin\_to\_mad}
=
\frac{M_1-M_2}{\mathrm{MAD}(M)}
\]

是这版特意加入的 stochastic-stability 指标。

它比单纯：

```text
peak1 - peak2
```

更接近：

> 峰间 margin 相对于当前 curve fluctuation / noise floor 到底有多大。

---

### 4.3 Local peak stiffness / shape

```text
local_curvature_1
local_curvature_2
width50_q
width80_q
```

对应 B2 后提出的：

> peak stiffness / local uncertainty

思路。

---

### 4.4 Asymmetry

```text
local_asymmetry
abs_local_asymmetry
```

观察 estimated peak 左右局部响应是否失衡。

---

### 4.5 Global ambiguity

```text
curve_entropy
grid_instability_bins
```

其中 `grid_instability_bins` 比较：

```text
odd candidate grid peak
vs
even candidate grid peak
```

的 q 位置差异。

如果两个轻微不同的 candidate subsets 给出明显不同峰值，说明 global maximum 较不稳定。

---

### 4.6 Observable residual state

```text
residual_energy_ratio_obs
=
||residual||^2 / ||pre-CLEAN mixture||^2
```

这个量是现实算法可计算的。

---

## 5. B3 的三个分析层次

### Layer 1 — Single-feature audit

对每个 feature 分别计算：

```text
AUC(any residual-induced failure)
AUC(perturbative failure)
AUC(catastrophic failure)
```

代码自动判断：

```text
feature 越大越危险
```

还是：

```text
feature 越小越危险
```

并输出 oriented AUC。

---

### Layer 2 — Cell-level surrogate analysis

对 9 个 B2 selected cells，计算 feature 平均值，并与：

```text
oracle Gamma
B2 refined penalty
```

做 Spearman correlation。

目标是区分：

### Physics surrogate

哪些 observable 更像 \(\Gamma\)？

### Practical risk surrogate

哪些 observable 更像实际 recovery penalty？

这两个未必是同一个指标。

---

### Layer 3 — Transparent observable fusion

B3 还包含一个：

> **leave-one-cell-out logistic fusion diagnostic**

使用预先固定的一组 observable features。

注意：

- 不是深度学习；
- 不是最终算法；
- 不参与 B2 cell 选择；
- 每次留出一个完整 parameter cell；
- 标准化只在训练 cells 上完成。

它的作用只是回答：

> 多个 observable 是否包含互补的信息？

如果 fusion 明显优于最佳单变量，那么后续 learned reliability 是有潜力的。

如果没有明显提升，就没必要急着上 AI。

---

## 6. 为什么使用 Leave-One-Cell-Out

随机拆 trial train/test 会过于乐观。

因为同一个 parameter cell 的 500 个样本高度同分布。

所以 B3 使用：

```text
train = 其他 8 个 cells
test  = 整个留出的 1 个 cell
```

逐 cell 轮换。

这样更接近：

> 对未见过的 signal condition 能否泛化。

---

## 7. 运行前置条件

必须已经完成 B2，并保留：

```text
results/
└── exp09_pilot01/
    └── exp09b2_regime_gamma/
        ├── selected_cells.csv
        └── refined_cell_summary.csv
```

如果目录不同：

```matlab
cfg.b2_result_dir = '你的 B2 结果目录';
```

---

## 8. 目录建议

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09b3_observable_reliability.m
    │       └── config_exp09b3.m
    └── results/
        └── exp09_pilot01/
            └── exp09b3_observable_reliability/
```

---

## 9. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09b3_observable_reliability;
```

---

## 10. 主要输出

```text
observable_trial_features.csv
b2_reproduction_check.csv
feature_auc_ranking.csv
cell_mean_observables.csv
cell_feature_correlations.csv
loco_logistic_scores.csv
loco_logistic_cell_summary.csv
summary.txt
exp09b3_results.mat
```

---

## 11. 主要图

```text
fig01_feature_auc_ranking.png
fig02_best_feature_distribution.png
fig03_peak_competition_plane.png
fig04_ambiguity_plane.png
fig05_cell_feature_correlations.png
fig06_best_cell_observable_vs_penalty.png
fig07_loco_logistic_roc.png
fig08_loco_cell_risk.png
fig09_representative_curves.png
```

---

## 12. 最值得关注的结果类型

### Case A：单一 observable 已经很好

例如：

```text
margin_to_mad AUC > 0.8
```

那么后续 adaptive method 可以优先保持简单规则。

---

### Case B：Perturbative 和 catastrophic 需要不同指标

例如：

```text
curvature / margin_to_mad
```

更适合 perturbative；

而：

```text
second_to_first / competitor_count / grid instability
```

更适合 catastrophic。

这会支持双通道 practical reliability：

\[
R_{\rm practical}
=
(R_{\rm local},R_{\rm ambiguity})
\]

---

### Case C：单变量一般，但 LOCO fusion 很好

这说明多个 observable 有互补性。

这时才值得认真讨论：

- logistic reliability；
- shallow MLP；
- small learned confidence head；

而不是直接上复杂深度网络。

---

### Case D：所有 observable 都弱

那说明：

> A4/B2 的 oracle mechanism 虽然解释力强，但 practical observability 不足。

这时应该回头设计新的 residual diagnostic，而不是强行进入 adaptive method。

---

## 13. 一个非常重要的判断原则

B3 的目标不是让：

```text
observable ≈ Gamma
```

尽可能精确。

真正最终目标是：

```text
observable state
    -> 是否值得增加额外计算预算
```

因此：

> **prediction of practical failure risk 比复现 oracle Gamma 更重要。**

Gamma 在 B3 中只是 theory-guided latent reference。

---

## 14. MATLAB 稳健性

考虑到 A4 曾出现行列维度错误，本版继续使用：

```matlab
bsxfun(@times,D,x)
```

并显式检查：

```text
dictionary signal length == input signal length
```

不依赖隐式矩阵方向推断。

B3 也没有重新实现 A4 的 oracle matched-response decomposition。
