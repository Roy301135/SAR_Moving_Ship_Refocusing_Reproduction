# EXP009 / Physical Validation Track / PA5
## Physical Sequential Strong-Removal Recovery Map

### 1. PA5 的核心问题

PA4 已经说明：

> 在讨论 peak shift 之前，必须先问 weak component 是否具有独立 observable peak。

因此 PA5 不立即加噪声，而是先问一个直接对应 sequential CLEAN 工程链的问题：

> 一个在 full mixture 中没有独立 weak peak 的分量，能否在 strong removal 后重新变得可见？

---

## 2. 四个主组 + 一个 sanity 组

### G0 — WeakOnly

只有 weak component。

作用：

- intrinsic upper baseline；
- 确认 weak 自身 FrAc peak 正常。

### G1 — FullMixture

`strong + weak`

作用：

- 测 pre-removal observability；
- 定义 `pre_hidden`。

`pre_hidden = 1`：

在 full mixture 的 local FrAc peaks 中，没有 weak-associated peak。

### G2 — OracleParamCLEAN

不是 exact subtraction。

它使用：

- TRUE strong chirp parameter；
- 在 full mixture 上做 complex LS coefficient fit；
- 再减去 fitted strong atom。

因此 G2 是：

> one-atom LS CLEAN family 内的 oracle-parameter upper bound。

它能回答：

> 即使 strong 参数完全正确，projection / LS subtraction 本身会不会伤害 weak？

### G3 — PracticalCLEAN

步骤：

1. 在 G1 的 FrAc energy 上取 GLOBAL maximum；
2. 将该 beta 当成 strong estimate；
3. 合成对应 LFM atom；
4. complex LS refit；
5. subtraction；
6. residual 再做 FrAc。

这与 sequential extraction 的逻辑一致。

### Gx — ExactOracleSubtract

`mixture - exact strong = exact weak`

只作为数值 sanity check。

不用于 practical conclusion，因为它的恢复本来就应当是 trivial。

---

## 3. 为什么 G2 比“exact oracle”更重要

如果 oracle 直接减掉 true strong waveform：

`r = x - s_true = w_true`

那么 recovery 永远等于 G0，不能说明 CLEAN operator 是否会重塑 weak。

G2 采用 true strong parameter 但仍然做 LS fit：

`c_hat = <s, x>/<s,s>`

`r = x - c_hat s`

因此：

`G0 vs G2`

隔离：

> operator-induced weak distortion

而：

`G2 vs G3`

隔离：

> strong-parameter estimation / practical implementation gap

这正好承接之前 B3B.1 的 ownership 思想，但现在在 Wang/Xu 锚定参数下重新做。

---

## 4. 参数全部继承 PA4

Paper-grounded：

- `fc=3 GHz`
- `PRF=188 Hz`
- `H=3000 m`
- `L_a=2 m`
- `V=150 m/s`

代表几何：

`R0/H=sqrt(2)`

weak：

`v_w=15 m/s`

strong mirror：

`v_s=v_w +/- Delta v`

`Delta v=[2.5,5,7.5,10,15,20] m/s`

amplitude：

`A_w/A_s=[0.1,0.2,0.3,0.5,0.8]`

relative phase：

16 个均匀值。

aperture：

- `Paper1s`
- `BeamDerived`

PA5 仍然：

- `b_s=b_w=0`
- no noise

---

## 5. 主要指标

### Pre-hidden rate

`P(pre_hidden)`

回答：

> raw FrAc landscape 里 weak 多常被隐藏？

### Oracle-operator rescue

`P(G2 residual global peak -> weak | pre_hidden)`

回答：

> 如果 strong parameter 完全已知，同样的 LS-CLEAN operator 能救回来多少？

### Practical rescue

`P(G3 residual global peak -> weak | pre_hidden)`

回答：

> 实际 FrAc estimate + LS subtraction 能救回来多少？

### Implementation gap

`oracle rescue - practical rescue`

### Oracle operator distortion

`||r_G2 - w_true|| / ||w_true||`

### Practical residual error

`||r_G3 - w_true|| / ||w_true||`

### Strong estimation error

`(beta_hat_s-beta_s)/W_beta`

---

## 6. 为什么 recovery 用 residual GLOBAL maximum

sequential CLEAN 下一步真正会做的是：

> 在当前 residual 中寻找下一个最显著 component。

因此最强 recovery definition 不是“true weak 附近存在一个小 local bump”，而是：

> residual 的 GLOBAL FrAc maximum 与 true weak 对应。

代码同时也记录 local weak recovery，方便诊断。

---

## 7. 预期结果分支

### Branch A — Operator-limited recovery

如果：

- exact subtraction当然成功；
- 但 G2 oracle-parameter LS CLEAN 都经常无法揭示 weak；

则说明：

> projection / subtraction operator 本身正在破坏 weak。

这时需要优先研究 operator geometry，而不是 strong estimator。

### Branch B — Strong-estimation implementation gap

如果：

- G2 rescue 高；
- G3 rescue 明显低；

则说明：

> 主要问题是 practical strong parameter estimation error。

这会直接连接之前 residual/coherent perturbation 的研究。

### Branch C — Practical strong removal reveals hidden weak

如果：

- G2 高；
- G3 也高；
- practical residual error 合理；

则说明：

> sequential strong removal 的核心工程作用确实是“揭示 pre-CLEAN hidden weak component”。

之后才值得加 noise / clutter。

### Branch D — Mixed

可能不同：

- Gamma
- amplitude ratio
- phase

下由不同机制控制。

此时 PA5 本身会形成 recovery regime map。

---

## 8. 输出文件

优先上传：

- `summary.txt`
- `pa5_recovery_summary.csv`
- `pa5_contrast_summary.csv`
- `pa5_regime_recovery_summary.csv`
- `pa5_strong_estimation_summary.csv`
- `pa5_decision_summary.csv`
- `pa5_representative_examples.csv`

图：

- `fig01_pre_hidden_rate_vs_contrast.png`
- `fig02_rescue_rate_vs_contrast.png`
- `fig03_implementation_gap_vs_contrast.png`
- `fig04_practical_rescue_by_regime.png`
- `fig05_operator_vs_practical_error.png`
- `fig06_strong_est_error_vs_Gamma.png`
- `fig07_overall_recovery_summary.png`

---

## 9. 运行

将文件放到：

`E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation`

运行：

```matlab
results = exp09_pa5_sequential_strong_removal_map;
```

结果目录：

`results\exp09_physical_validation\exp09_pa5_sequential_strong_removal_map`

---

## 10. 研究纪律

PA5 不预设 CLEAN 有效。

允许：

- G2 本身失败；
- G3 比 G2 差很多；
- practical removal 只在高 contrast / high Gamma 下有效；
- practical removal 在 hidden weak 上系统性制造残留偏差；
- 原先 normalized EXP009 的 CLEAN 机制在 physical parameters 下失效。

做完 PA5，再决定是否进入：

> noise / clutter-conditioned recovery map

而不是提前把 SNR 加回来。
