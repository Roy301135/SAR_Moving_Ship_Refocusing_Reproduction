# EXP009-B2 / Pilot-01 — Regime Boundary + Physics-Derived Reliability Index Γ

## 1. B2 的目标

B1 已经证明：

- residual-induced weak failure 在参数区域内稳定存在；
- coherent cross-term 的局部斜率远大于 residual 自身功率斜率；
- 一阶 peak-shift 公式在 noiseless matched-response 上整体有效。

B2 不再扩大参数网格，而做两件事：

1. 检验一个物理定义的 difficulty / reliability index；
2. 从 B1 自动挑选少量代表性 cell，用更多 Monte Carlo 精炼 easy / perturbative / catastrophic regime。

---

## 2. 核心指标 Γ

A4/B1 得到：

\[
\delta q_{\rm pred}
\approx
-\frac{\Delta P'(q_w)}
{P_w''(q_w)}.
\]

定义：

\[
\Gamma
=
\frac{|\delta q_{\rm pred}|}{\tau_q}.
\]

其中 \(\tau_q\) 是 weak ORO recovery tolerance。

直观解释：

- `Gamma << 1`：理论 peak shift 远小于允许误差；
- `Gamma ≈ 1`：接近 recovery boundary；
- `Gamma > 1`：仅 noiseless first-order shift 就足以越过容许误差。

### 重要限制

Γ 现在仍然是 **Oracle / mechanism-level index**。

它使用真实 weak q 和解析 matched-response 信息，因此还不能直接在线应用于真实 SAR。

B2 的任务只是判断：

> 是否存在一个物理上合理的 difficulty index，可以解释 easy / dangerous regime？

---

## 3. Companion index Λ

定义：

\[
\Lambda
=
\frac{E_{\rm strong,residual}}{E_{\rm weak}}.
\]

B2 会比较：

- Γ；
- Λ；

谁更能解释 residual recovery penalty。

如果 `AUC(Gamma)`、`corr(Gamma, penalty)` 明显优于 Λ，就进一步支持：

> coherent interference geometry 比 residual energy magnitude 更能解释 weak-q failure。

---

## 4. B2 自动读取 B1

默认读取：

```text
results/
└── exp09_pilot01/
    └── exp09b1_failure_mechanism_map/
        ├── performance_map_mc.csv
        └── mechanism_map_noiseless.csv
```

如果你的 B1 目录不同，在：

```matlab
config_exp09b2.m
```

中设置：

```matlab
cfg.b1_result_dir = '你的B1结果目录';
```

---

## 5. B1 screening

只在：

```text
baseline recall >= 0.80
```

的 cell 中评价 residual-induced danger。

这样避免把：

```text
weak 本来就不可恢复
```

与：

```text
CLEAN residual 造成的额外 failure
```

混在一起。

默认 dangerous cell：

```text
residual recovery penalty >= 0.10
```

然后计算：

- Gamma AUC；
- Lambda AUC；
- Gamma vs penalty Spearman correlation；
- Lambda vs penalty correlation；
- Gamma=1 confusion matrix；
- B1 empirical optimal Gamma threshold。

其中 empirical optimal threshold 只是诊断结果，不能直接当最终算法阈值。

---

## 6. 自动选择三个 regime

B2 不对全部 B1 cell 做 500 次 MC。

会基于 **B1 empirical behavior，而不是 Gamma** 自动挑选：

### Easy

- baseline 可恢复；
- residual penalty 小；
- catastrophic rate 低。

### Perturbative

- baseline 可恢复；
- residual penalty 中等；
- catastrophic rate 低。

### Catastrophic

- residual catastrophic rate 高。

默认每类最多选择 3 个 cell，并优先覆盖不同 SNR。

总共通常约 9 个 cell。

这样避免用 Gamma 自己挑选验证样本，从而减少 circular validation。

---

## 7. Refined Monte Carlo

默认：

```text
500 MC / selected cell
```

每个 cell 的：

```text
baseline
```

和：

```text
residual branch
```

严格共享同一 noise realization。

输出：

- baseline recall + 95% Wilson CI；
- residual recall + 95% Wilson CI；
- paired recovery penalty；
- paired penalty bootstrap 95% CI；
- catastrophic rate；
- signed q bias；
- RMSE。

---

## 8. 主要输出

```text
b1_cells_with_gamma.csv
gamma_diagnostic_by_snr.csv
selected_cells.csv
refined_mc_trials.csv
refined_cell_summary.csv
diagnostic_summary.csv
summary.txt
exp09b2_results.mat
```

---

## 9. 主要图

```text
fig01_gamma_heatmap.png
fig02_gamma_vs_b1_penalty.png
fig03_lambda_vs_b1_penalty.png
fig04_gamma_roc.png
fig05_gamma_lambda_risk_plane.png
fig06_refined_penalty_vs_gamma.png
fig07_refined_recovery.png
fig08_refined_catastrophic_vs_gamma.png
fig09_gamma_distributions.png
```

---

## 10. 最理想的 B2 结果

如果得到：

```text
AUC(Gamma) > AUC(Lambda)
```

并且 refined MC 中仍然看到：

```text
Gamma ↑ -> residual penalty ↑
```

那么 Γ 可以作为一个很强的：

> **oracle physics reliability index**

这时下一阶段才研究：

> 如何用实际可观测 residual FrAc / CLEAN state 去估计 Γ 或直接预测 P(failure)。

---

## 11. 另一种同样重要的结果

如果：

```text
Gamma 很适合解释 perturbative bias
```

但：

```text
Gamma 无法解释 catastrophic mode switching
```

也完全合理。

那意味着需要明确两个机制：

### Perturbative regime

由：

\[
\Gamma
\]

描述。

### Catastrophic regime

需要额外的 peak-competition / ambiguity indicator，例如：

- peak / second-peak ratio；
- secondary local maximum；
- peak prominence；
- multi-peak structure。

这反而会形成更清晰的双机制框架。

---

## 12. 推荐目录

```text
papers/
└── Xu2025_Adaptive_Fast_Refocusing/
    ├── code/
    │   └── exp09_pilot01/
    │       ├── exp09b2_regime_gamma.m
    │       └── config_exp09b2.m
    └── results/
        └── exp09_pilot01/
            └── exp09b2_regime_gamma/
```

---

## 13. 运行

```matlab
cd <...>/Xu2025_Adaptive_Fast_Refocusing/code/exp09_pilot01
results = exp09b2_regime_gamma;
```

---

## 14. 本版代码的稳健性说明

考虑到 A4 之前出现过 MATLAB 行列维度错误，本版对核心搜索函数显式检查：

```matlab
size(D,2) == numel(x)
```

并使用：

```matlab
bsxfun(@times, D, x)
```

而不是依赖隐式矩阵方向推断。

此外，B2 不重新实现 A4 的 matched-response 矩阵乘法，而直接使用 B1 已保存的一阶预测量，减少重复引入维度错误的机会。
