# EXP009 / Physical Validation Track / P1B
## Aperture-Constrained FrAc Consistency Audit

### 1. 为什么增加 P1B

P1 已经确认：

- Wang 2023 的 5 个速度可以映射成有序的 physical residual FM rates；
- 但使用 matched-chirp-rate proxy 时，5 分量是否可分强烈依赖 observation length。

因此不能直接为了得到 5 个峰选择 `N=512/1024`。

P1B 改用两个有来源的 aperture scale，并改成更贴近 Wang Eq. (17)–(22) 的 FrAc statistic。

---

## 2. Wang 2023 直接支持的内容

Wang 2023 明确给出：

- `fc = 3 GHz`
- `PRF = 188 Hz`
- `B = 150 MHz`
- `H = 3000 m`
- `L_a = 2 m`
- `V_SAR = 150 m/s`
- `pulse width = 1.5 us`
- five-point azimuth velocities = `[5,10,15,20,25] m/s`

并且：

- Eq. (13) 将 azimuth line 建模为 MC-LFM；
- Eq. (17) 定义 FrAc；
- Eq. (20) 表明 auto-term 在 `tan(beta)=a_i` 时集中；
- Eq. (22) 定义 FrAc energy `E_rho(beta)`；
- FrAc peak 对应 `alpha = beta + pi/2` 的 FrFT ORO；
- 文中指出 ship swing 在约 1 s synthetic-aperture time 内可进行低阶近似。

---

## 3. P1B 的两个 aperture prescription

### A. Paper time-scale anchor

`T_ap = 1 s`

`N = round(PRF * T_ap) = 188`

注意：

> 这只是 Wang 文本中的时间尺度锚点，不等于论文明确说 Fig. 8 的五点实验恰好用了 N=188。

### B. Beam-derived engineering estimate

采用一阶 beamwidth：

`beta_az ~= lambda / L_a`

以及：

`T_ap ~= R0 * beta_az / V`

由于 Wang 五点实验没有报告 exact `R0 / incidence angle`，继续保留：

`R0/H = [1, sqrt(2), 2]`

作为几何 sensitivity。

---

## 4. FrAc 离散实现

Wang Eq. (13)：

`x_i[m] = exp{j2pi(0.5*a_i*m^2 + b_i*m)}`

物理 residual FM：

`a_i = K_res_i / PRF^2`

Wang Eq. (20) auto-term condition：

`tan(beta) = a_i`

P1B 使用：

`R_beta[k] ~= sum_m x[m+k] conj(x[m]) exp{-j2pi m k tan(beta)}`

`E(beta) = sum_k |R_beta[k]|^2`

实现时通过 lag-wise ambiguity FFT 加速。

由于当前 `beta ~ 1e-3 rad`，代码同时输出：

`small_angle_audit.csv`

检查 `1-cos(beta)` 是否确实足够小。

这比 P1 matched-K proxy 更贴近 Wang 的 FrAc 机制，但仍不会声称逐点复现 Wang 原始 MATLAB FrAc 实现，因为论文没有公开全部离散实现细节。

---

## 5. 未公开参数如何处理

Wang 五点实验未明确公开：

- exact `R0`
- exact azimuth line length
- each component amplitude
- `b_i`
- initial phase

P1B 因此：

- `R0` 做明确 sensitivity；
- aperture length 来自 1 s anchor 或 beam-derived estimate；
- amplitude 全部设为 1，仅隔离 chirp-rate separability；
- `b_i = 0`；
- initial phase 做 40 次 Monte Carlo；
- 不加 noise；
- 不加 CLEAN。

这些全部标为 controlled / derived，不伪装成 paper parameter。

---

## 6. 输出

优先检查：

- `summary.txt`
- `p1b_gate_summary.csv`
- `scenario_summary.csv`
- `representative_component_parameters.csv`
- `small_angle_audit.csv`
- `fig01_aperture_constraints.png`
- `fig02_representative_paper1s_frac.png`
- `fig03_representative_beam_frac.png`
- `fig04_phase_mc_detection_rate.png`
- `fig05_frac_separability_ratio.png`
- `fig06_velocity_to_frac_beta.png`

---

## 7. Gate 不是“必须复现五峰”

可能状态：

- `CONSISTENT_AT_1S_SCALE`
- `CONSISTENT_AT_BEAM_DERIVED_SCALE`
- `PARTIALLY_CONSISTENT`
- `UNRESOLVED_WITH_REPORTED_PARAMETERS`

如果最后一项出现，不允许通过随意增大 `N` 强行制造五峰。

正确结论是：

> Wang 2023 公开参数不足以唯一复现其 Fig. 8 的 5-peak FrAc result。

然后 PA4 使用 physically plausible controlled separation sweep，而不是声称 exact Wang reproduction。

---

## 8. 目录

代码放到：

`E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation`

运行：

```matlab
results = exp09_p1b_aperture_constrained_frac_consistency;
```

结果自动进入：

`results\exp09_physical_validation\exp09_p1b_aperture_constrained_frac_consistency`

---

## 9. P1B 之后

如果物理 plausible aperture 下 FrAc separability survives：

`P1B -> PA4 Physical Perturbation / Mirror Validation`

如果不 survives：

先记录 literature-reproduction limitation，再让 PA4 使用显式的 dimensionless separation / response-width sweep。
