# EXP009 / Physical Validation Track / PA4
## Physical Two-Component Resolution–Perturbation Regime Validation

### 1. 为什么 PA4 不再机械重跑旧 A4

P1/P1B/P1C 已经表明：

- physical velocity → residual FM / FrAc parameter mapping是稳定的；
- 在 Wang-like short aperture 下，5 个分量的主要限制首先是 intrinsic resolution；
- 即使拿掉 cross-term，ideal incoherent auto envelope 也可能没有独立峰。

因此旧 A4 默认的：

> “weak peak 先存在，然后被 strong residual 推偏”

不能再无条件使用。

PA4 的第一任务是先判断：

> weak component 是否具有可识别的 observable peak。

---

## 2. 核心无量纲变量

定义：

`Gamma = |beta_s - beta_w| / W_beta,weak`

其中：

`W_beta,weak`

是当前 aperture 下 isolated weak component 的 FrAc 3-dB width。

因此以后不再用人工的 `Delta q=0.02` 作为主要分离尺度。

---

## 3. 物理设置

Wang 2023：

- `fc = 3 GHz`
- `PRF = 188 Hz`
- `H = 3000 m`
- `L_a = 2 m`
- `V = 150 m/s`

代表几何：

`R0/H = sqrt(2)`

弱分量固定：

`v_w = 15 m/s`

强分量做 velocity mirror：

`v_s = v_w - Delta v`

或

`v_s = v_w + Delta v`

其中：

`Delta v = [2.5, 5, 7.5, 10, 15, 20] m/s`

说明：

- `Delta v <= 10 m/s` 覆盖 Wang 五点 `[5,25] m/s` 的原始速度跨度；
- `15/20 m/s` 是显式 controlled extension，用于观察 resolution boundary；
- 不会把它们写成 Wang paper parameter。

---

## 4. 两套 aperture

### Paper1s

Wang 文本中的约 1 s time-scale anchor。

### BeamDerived

`T_ap ~= R0 * (lambda/L_a) / V`

两者都继承 P1B/P1C 的 provenance discipline。

---

## 5. 强弱比与相位

`A_s = 1`

`A_w/A_s = [0.1,0.2,0.3,0.5,0.8]`

由于 Wang 没有给五点实验唯一 amplitude ratio，所以这是 controlled sweep。

相位：

16 个均匀的 relative phase：

`phi_ws in [0,2pi)`

PA4 不加随机噪声。

---

## 6. b_i

P1C 已经证明，在当前短 aperture 条件下，改变 b_i 可以改变 cross contamination，但不能解决 ideal-auto resolution limit。

因此 PA4 第一轮固定：

`b_s = b_w = 0`

目的是隔离：

`chirp-rate separation × amplitude contrast × coherent phase`

如果未来确有需要，b_i 只作为 nuisance sensitivity，而不再作为 reproduction 补丁。

---

## 7. PA4 允许出现三个 regime

### Unresolved

`Gamma < 0.5`

预期：

- weak-associated peak可能不存在；
- 不能强行定义 NearShift；
- 主要研究 merged-response / identifiability。

### Partial

`0.5 <= Gamma < 1.5`

预期可能出现：

- shoulder；
- peak attraction / repulsion；
- phase-sensitive split / merge；
- non-perturbative coherent interaction。

### ResolvedCandidate

`Gamma >= 1.5`

只有在 weak-associated peak确实存在时，才验证旧 A4：

`delta_beta_pred = -DeltaP'(beta_w)/P_w''(beta_w)`

以及 mirror symmetry。

这些 0.5/1.5 是诊断标签，不是假装成普适物理常数。

---

## 8. FrAc 计算

预计算：

- `R_ss`
- `R_ww`
- `R_sw`
- `R_ws`

对于：

`x = s + r exp(jphi) w`

有：

`R_total = R_ss + r^2 R_ww + r exp(-jphi) R_sw + r exp(+jphi) R_ws`

然后：

`P(beta) = sum_k |R_total(beta,k)|^2`

这使 amplitude / phase sweep 不需要重复做大量 FFT。

---

## 9. 核心输出

### Topology

- observable peak count
- weak peak found
- strong peak found
- two-component resolved
- merged / split transition

### Shift

只有 weak peak可识别时才输出：

- weak shift
- weak shift / response width

### First-order law

只在 local bounded cases 上验证：

`delta_beta_pred = -DeltaP'/P_w''`

输出：

- Pearson
- slope
- RMSE
- sign agreement

### Mirror

同一个：

- aperture
- Delta v
- amplitude ratio
- relative phase

配对比较：

`LowV strong`

与：

`HighV strong`

输出 weak-shift sign flip rate 和 antisymmetry error。

---

## 10. 重点文件

运行后优先上传：

- `summary.txt`
- `pa4_intrinsic_width_calibration.csv`
- `pa4_regime_summary.csv`
- `pa4_firstorder_summary.csv`
- `pa4_mirror_summary.csv`
- `pa4_decision_summary.csv`

以及：

- `fig01_deltaV_to_Gamma.png`
- `fig02_highGamma_resolved_rate.png`
- `fig03_weak_shift_vs_Gamma.png`
- `fig04_firstorder_scatter.png`
- `fig05_mirror_sign_flip.png`
- `fig06_paper_dv5_landscape.png`
- `fig07_paper_dvMax_landscape.png`
- `fig08_beam_dv5_landscape.png`
- `fig09_beam_dvMax_landscape.png`

---

## 11. 运行

放在：

`E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation`

运行：

```matlab
results = exp09_pa4_resolution_perturbation_regime;
```

结果：

`results\exp09_physical_validation\exp09_pa4_physical_two_component_resolution_perturbation_regime`

---

## 12. 研究纪律

PA4 不保护旧 A4 结论。

允许：

- 旧 coherent NearShift 只在 resolved regime 成立；
- 旧 first-order law 在 physical parameters 下失效；
- Partial regime 出现新的 phase-sensitive merge/split mechanism；
- 整个 tested velocity range 仍然 resolution-limited。

任何一个结果都是真实的 physical-validation outcome。

下一步方法由 PA4 结果决定，而不是提前决定。

---

## 13. MATLAB 文件名补丁

MATLAB 的函数名最大长度为 63 个字符。

原配置函数名：

`config_exp09_pa4_physical_two_component_resolution_perturbation_regime`

长度为 70，因此会被 MATLAB 截断并导致函数无法识别。

本补丁将 PA4 的实际 MATLAB 文件改为：

- `exp09_pa4_resolution_perturbation_regime.m`
- `config_exp09_pa4_resolution_perturbation_regime.m`

ZIP 包名称和结果目录仍保留完整描述，不影响实验归档语义。

同时将参数来源文件改为：

`PARAMETER_PROVENANCE_PA4.csv`

避免与 P0/P1/P1B/P1C 的 provenance 文件在同一代码目录中互相覆盖。
