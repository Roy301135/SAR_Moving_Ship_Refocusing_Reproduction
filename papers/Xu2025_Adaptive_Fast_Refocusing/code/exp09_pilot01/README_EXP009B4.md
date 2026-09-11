# EXP009-B4 / Pilot-01 — Observable q-Uncertainty / Stability Estimation

## 1. B4 的研究问题

B3 已经给出一个很清楚的分层结论：

- catastrophic failure 很容易从 residual concentration curve 中识别；
- perturbative failure 的单次可观测性明显更弱；
- 单纯堆 hand-crafted features 再做普通 feature fusion，并没有解决问题。

因此 B4 不再继续增加静态 curve feature，而引入一个新的信息源：

> **对同一 residual 数据做轻微 data-support perturbation，观察 q 估计是否稳定。**

核心假设：

```text
稳定 weak peak
    -> 换一个相近子孔径后 q_hat 仍然稳定

脆弱 / stochastic weak peak
    -> 主峰看起来仍合理
    -> 但 q_hat 对小的数据扰动更加敏感
```

---

## 2. 为什么 B4 用“数据扰动”，而不是继续改 q grid

B3 中的 odd/even q-grid instability 几乎没有效果。

原因是它只改变：

```text
candidate grid
```

却没有真正改变：

```text
观测数据
```

B4 改成真正 perturb data support。

默认把原始 512 点 aperture 构造成：

```text
4 个重叠连续 sub-apertures
```

每个保留：

```text
75% aperture
```

默认长度：

```text
384 samples
```

并让 4 个窗口覆盖 aperture 的不同位置。

这样每个子估计仍然保留大部分积分增益，但数据支持发生了真实变化。

---

## 3. Sub-aperture q stability

每个 residual trial 首先得到 full-aperture：

\[
\hat q_{\rm full}
\]

然后分别得到：

\[
\hat q_1,\hat q_2,\hat q_3,\hat q_4.
\]

为了避免 0.001 q-grid 量化主导 stability measurement，每个 peak 都额外使用三点抛物线做 sub-grid interpolation。

---

## 4. 主要 uncertainty observables

### 4.1 Sub-aperture standard deviation

\[
U_{\rm std}
=
\frac{\operatorname{Std}(\hat q_1,\ldots,\hat q_K)}
{\tau_q}
\]

代码：

```text
subap_std_norm
```

---

### 4.2 Sub-aperture range

\[
U_{\rm range}
=
\frac{\max \hat q_k-\min \hat q_k}
{\tau_q}
\]

代码：

```text
subap_range_norm
```

---

### 4.3 Robust MAD

\[
U_{\rm MAD}
=
\frac{
\operatorname{median}
|\hat q_k-\operatorname{median}(\hat q_k)|
}{
\tau_q
}
\]

代码：

```text
subap_mad_norm
```

---

### 4.4 Full-vs-subap disagreement

\[
U_{\rm dev}
=
\frac{
\operatorname{median}|\hat q_k-\hat q_{\rm full}|
}{
\tau_q
}
\]

代码：

```text
subap_full_dev_norm
```

---

### 4.5 Consensus fraction

统计多少 sub-aperture q estimates 与 full estimate 的差异仍在：

\[
\tau_q
\]

以内：

```text
subap_consensus_fraction
```

高 consensus 理论上更可靠。

---

## 5. Physics-guided curvature/noise uncertainty proxy

B2 后提出：

\[
\hat q-q_w
\approx
\delta q_{\rm det}
+
\epsilon_q.
\]

对于随机局部扰动：

\[
\delta q
\approx
-\frac{\epsilon'(q)}{M''(q)}.
\]

因此 B4 近似构造：

\[
\hat\sigma_q
\approx
\frac{\hat\sigma_{M'}}
{|M''(\hat q)|}.
\]

其中：

\[
\hat\sigma_{M'}
\approx
\frac{\hat\sigma_M}
{\sqrt{2}\Delta q}.
\]

\(\hat\sigma_M\) 用避开主峰后的 curve MAD robustly 估计。

最终输出：

\[
\frac{\hat\sigma_q}{\tau_q}
\]

即：

```text
curvature_sigma_q_norm
```

这个量仍然只是 practical proxy，不应提前宣称为严格 CRLB 或 estimator variance。

---

## 6. B3 global ambiguity observables 仍保留少量作为参照

为了判断：

```text
local uncertainty
```

和：

```text
global ambiguity
```

是否互补，B4 仅保留少量 B3 指标：

```text
prominence
curve_entropy
second_to_first
peak_zscore
```

不再堆十几个重复 feature。

---

## 7. Ground-truth label

与 B3 一样，真实 q 仅用于 controlled synthetic evaluation。

### Any residual-induced failure

```text
baseline succeeds
AND
residual fails
```

---

### Perturbative failure

```text
baseline succeeds
AND
residual fails
AND
not catastrophic
```

B4 在计算 perturbative AUC 时会：

> **完全排除 catastrophic trials**

所以其二分类任务变成：

```text
non-catastrophic success
vs
non-catastrophic perturbative failure
```

比 B3 的 perturbative AUC 定义更加纯粹。

因此：

> B3 和 B4 的 perturbative AUC 数值不能机械地直接一一比较。

代码仍会把 B3 最优值打印为历史参考，但论文分析时必须注明 label definition 的变化。

---

## 8. 为什么还保留 B2 reproduction check

B4 会重新运行同样的：

```text
9 cells × 500 MC
```

首先输出：

```text
b2_reproduction_check.csv
```

如果：

```text
max reproduction difference
```

不是数值精度级别，就不要继续分析 feature。

---

## 9. Diagnostic fusion

B3 的 11-feature LOCO logistic：

```text
AUC = 0.645
```

表现并不好。

所以 B4 不再做大 feature fusion，只做两个非常透明的诊断模型。

### Local-only

```text
subap_std_norm
subap_range_norm
subap_full_dev_norm
curvature_sigma_q_norm
```

回答：

> estimator stability 本身是否足够预测 perturbative failure？

---

### Two-channel

```text
subap_std_norm
curvature_sigma_q_norm
prominence
curve_entropy
```

也就是：

\[
R_{\rm practical}
=
(R_{\rm local},R_{\rm ambiguity})
\]

的最简单诊断版本。

仍然使用：

```text
Leave-One-Cell-Out
```

而不是随机 trial split。

---

## 10. B4 最值得期待的结果

### Strong positive result

如果：

```text
sub-aperture stability AUC
```

明显超过 B3 静态 feature 对 perturbative failure 的水平，并且：

```text
LOCO local / two-channel fusion
```

继续提高，那么可以认为：

> **真正缺失的信息确实是 estimator stability，而不是更复杂的静态 curve classifier。**

这时 B 系列可以基本结束，进入 C。

---

### Partial positive result

如果：

```text
subap uncertainty
```

只在 cell-level 与 penalty 强相关，但 trial-level AUC 仍中等：

> 它仍然适合作为 stage / spatial-region level computation allocation signal。

这仍然有方法价值。

---

### Negative result

如果：

```text
subap stability ≈ B3 static features
```

甚至更差，那么应接受：

> 单条 residual 的 perturbative failure 可能本身就难以在线可靠预测。

那后续方法应采用更保守的 region-level / sequential-history reliability，而不是追求 single-shot failure classification。

---

## 11. 主要输出

```text
b4_trial_uncertainty_features.csv
b2_reproduction_check.csv
feature_auc_ranking.csv
cell_mean_uncertainty_features.csv
cell_feature_correlations.csv
loco_perturbative_scores.csv
loco_cell_summary.csv
diagnostic_summary.csv
summary.txt
exp09b4_results.mat
```

---

## 12. 主要图

```text
fig01_uncertainty_feature_auc.png
fig02_best_perturbative_feature.png
fig03_perturbative_uncertainty_plane.png
fig04_cell_uncertainty_correlations.png
fig05_best_cell_uncertainty_vs_penalty.png
fig06_loco_perturbative_roc.png
fig07_loco_cell_perturbative_risk.png
fig08_twochannel_risk_plane.png
fig09_representative_subap_stability.png
```

---

## 13. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09b4_observable_q_uncertainty.m
    │       └── config_exp09b4.m
    └── results/
        └── exp09_pilot01/
            └── exp09b4_observable_q_uncertainty/
```

---

## 14. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09b4_observable_q_uncertainty;
```

---

## 15. 运行时间

B4 比 B3 更重，因为每个 residual trial 除了 full q search，还要执行 4 次 75%-sub-aperture q search。

默认仍为：

```text
500 MC / cell
```

如果第一次只想确认代码逻辑，可暂时在 config 中设：

```matlab
cfg.num_mc = 50;
```

确认能够完整输出后，再恢复：

```matlab
cfg.num_mc = 500;
```

正式结果必须以完整 MC 版本为准。

---

## 16. MATLAB 稳健性

继续采用：

```matlab
bsxfun(@times,D,x)
```

并显式检查：

```text
dictionary length == signal length
```

sub-aperture dictionary 也针对各自的真实 absolute slow-time samples 单独构造，避免把截断子孔径错误地重新定义成新的归一化时间轴。

这点对 chirp-rate / q estimation 很重要。
