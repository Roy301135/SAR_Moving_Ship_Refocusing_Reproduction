# EXP009 / Pilot-01 / C3-B3B.1
## NearShift Mechanism Ownership Test — 实验设计与代码说明

### 1. Research Question

C3-B3B 已确认：

- 一阶扰动律在 noisy NearShift 中仍然高度成立；
- 将 q-grid 从 0.001 加密到 0.0005 不能救回 coarse failures；
- Parabolic / LogQuadratic / Centroid 等同一局部峰形插值无法恢复真实 `q_weak`；
- 当前 SNR=3 dB 下，G3 的 WeakNoiseCross 贡献远大于 WeakStrongCross。

因此 C3-B3B.1 不再问“NearShift 是否存在”，而问：

> **NearShift 的主要因果归属是什么：弱分量低 SNR 随机峰漂移、practical CLEAN/projection 对 weak/noise 的重塑、strong residual 的相干扰动，还是它们的交互作用？**

---

### 2. 四个 paired ownership groups

对每一个相同的 `strong / weak / noise realization`，先从 practical full mixture：

`X = S_s + S_w + N`

估计一次实际 fallback projection atom，并固定该 operator。

得到：

`E_s = P_hat S_s`

`E_w = P_hat S_w`

`E_n = P_hat N`

随后构造：

- `G0_WeakOnly = S_w + N`
- `G1_OperatorOnly = E_w + E_n`
- `G2_ResidualOnly = S_w + N + E_s`
- `G3_FullCLEAN = E_w + E_n + E_s`

关键点：

> G1 并不是对 `S_w+N` 重新独立拟合一次 CLEAN，而是使用 **G3 同一个 practical full-mixture fitted operator**。这样才能真正隔离“这个实际 operator 对 weak/noise 做了什么”。

---

### 3. 固定变量

全部沿用已经完成的 C3-B3B：

- `q_strong`：oracle / known；
- `SNR = 3 dB`；
- `q_weak = 1.470`；
- q search grid、matched diagnostic grid；
- `tau_q = 0.003`；
- Smooth / Abrupt physical trajectories；
- strong/weak amplitude trajectory；
- `q_s-q_w` trajectory；
- refit NFFT、projection / CLEAN 实现；
- 每个 Monte-Carlo trial 中 G0–G3 使用 **完全相同的 AWGN realization**。

不允许四个组各自重新 `randn`。

---

### 4. 为什么不是 OracleSubtract 作为第四个核心组

`X - S_s = S_w + N`

理论上就是 G0。

因此 OracleSubtract 只作为 numerical sanity check：

`max |(X-S_s) - (S_w+N)|`

应该接近机器精度。

核心四组要用于真正的 `Operator × Residual` 因果分解。

---

### 5. Primary outputs

#### 5.1 All-trial paired statistics

每组：

- Success / Failure rate
- NearShift rate
- MAE
- RMSE
- median absolute error
- absolute-error CDF

不要只在各自 failure subset 内比较，避免 selection bias。

#### 5.2 G3-NearShift-conditioned counterfactual

固定：

`I_NS = {trial: G3 is NearShift}`

再对完全相同的 trial 检查：

- 如果改成 G0，会有多少成功？
- 如果改成 G1，会有多少成功？
- 如果改成 G2，会有多少成功？

这是真正的 paired counterfactual mechanism check。

#### 5.3 Operator weak preservation

保存：

- weak retention；
- group-specific weak-only peak center；
- operator baseline bias；
- normalized weak curvature：

`kappa_norm = -P_w''(q0) / P_w(q0)`

用于区分：

- numerator perturbation 增强；
- denominator / restoring curvature 变弱。

---

### 6. Ownership factorial effects

对于 metric `M`，定义：

`Operator = M1 - M0`

`Residual = M2 - M0`

`Interaction = M3 - M1 - M2 + M0`

`Total = M3 - M0`

代码同时对：

- absolute error；
- failure indicator；

计算 paired effect。

95% CI 使用 **complete Monte-Carlo sequence cluster bootstrap**，而不是把 121 条相邻 azimuth line 当作独立样本。

---

### 7. 一阶扰动模型

对每个 group 单独定义该组的 weak-only matched response：

`P_w,g(q)`。

该组的 weak-only peak：

`q0,g = argmax P_w,g(q)`。

Operator baseline bias：

`b_g = q0,g - q_weak`。

总 matched response：

`P_g = P_w + P_s + P_n + P_ws + P_wn + P_sn`。

局部 perturbation：

`delta_q_g ≈ -DeltaP_g'(q0,g) / P_w,g''(q0,g)`。

因此相对于真实 `q_weak`：

`q_hat - q_weak ≈ b_g + delta_q_g`。

这比只写 `delta_q` 更完整，因为它允许 CLEAN/operator 自身先把 weak-only landscape 重塑。

---

### 8. 四种结果分支

#### Branch A — intrinsic noise-limited

若：

`G0 ≈ G1 ≈ G2 ≈ G3`

且 WeakNoiseCross 一直主导，则：

> 当前 NearShift 主要是 weak-component low-SNR stochastic peak jitter。

后续优先考虑 independent evidence / averaging，而不是继续改 strong suppression。

#### Branch B — operator amplification

若：

`G1 ≈ G3 >> G0`

且：

`G2 ≈ G0`

并伴随 weak retention / curvature 下降，则：

> practical projection 对 weak/noise 的重塑放大了随机扰动敏感度。

下一步可转向 weak-preserving / curvature-preserving CLEAN。

#### Branch C — strong residual dominated

若：

`G2 ≈ G3 >> G0`

且：

`G1 ≈ G0`

则：

> strong residual coherent geometry 仍是主要 owner。

下一步优先 residual-aware suppression / correction。

#### Branch D — interaction dominated

若：

`G1 > G0`、`G2 > G0`，但：

`G3` 明显超过 additive expectation：

`G1 + G2 - G0`

且 interaction 95% CI 不跨 0，则：

> operator reshaping 与 residual/noise perturbation 存在超加性耦合。

这时可进一步建立：

`numerator amplification + denominator weakening`

的统一数学模型。

---

### 9. 运行方式

把：

`exp09c3b3b1_nearshift_mechanism_ownership.m`

放到与当前 EXP009 / Pilot-01 MATLAB 代码相同的工程环境中，并确保原有：

`config_exp09c3b3b.m`

在 MATLAB path 上。

运行：

```matlab
results = exp09c3b3b1_nearshift_mechanism_ownership;
```

---

### 10. 重点输出文件

优先上传：

- `summary.txt`
- `decision_summary.csv`
- `ownership_effects_with_cluster_bootstrap.csv`
- `g3_nearshift_counterfactual.csv`
- `group_summary.csv`
- `first_order_group_validation.csv`
- `perturbation_contribution_by_group.csv`
- `fig01_smooth_abs_error_cdf.png`
- `fig02_abrupt_abs_error_cdf.png`
- `fig03_group_failure_rates.png`
- `fig04_smooth_g3_nearshift_counterfactual.png`
- `fig05_abrupt_g3_nearshift_counterfactual.png`
- `fig06_group_weak_curvature.png`
- `fig07_smooth_contribution_anatomy.png`
- `fig08_abrupt_contribution_anatomy.png`
- `fig09_abs_error_ownership_effects.png`
- `fig10_g3_cohort_counterfactual_success.png`

---

### 11. 当前实验纪律

C3-B3B.1 只做 SNR=3 dB ownership decomposition。

暂时不要同时：

- sweep SNR；
- 加 history；
- 加 sub-aperture；
- 改 CLEAN width；
- 加 learned model。

先确认 ownership，再进入 C3-B3B.2 SNR regime/crossover test。
