# EXP009 / Physical Validation Track / P1
## Wang 2023 Five-Component MC-LFM Physical Baseline

### 1. 目的

P1 不做创新，不加噪声，不加 CLEAN。

它只回答：

> 在 Wang 2023 公开的 SAR 系统参数和 5 个 azimuth velocity 下，是否能够得到稳定分离的 5 个 residual-LFM 分量？

这是进入 `PA4 Physical Perturbation / Mirror Validation` 之前的第二个 calibration gate。

---

## 2. Wang 2023 直接提供的参数

Table 1：

- carrier frequency = 3 GHz
- PRF = 188 Hz
- bandwidth = 150 MHz
- platform height = 3000 m
- antenna length = 2 m
- platform velocity = 150 m/s
- pulse width = 1.5 μs

Table 2：

- P1–P5 azimuth velocity = `[5, 10, 15, 20, 25] m/s`

Wang Eq. (13)：

每一条 ship azimuth line 可建模为：

`g(:,n_j) = sum_i exp{j 2pi (0.5 a_i m^2 + b_i m)}`

即 MC-LFM。

---

## 3. 为什么 P1 不直接宣称“完全复现 Wang Fig. 8”

Wang 的五点 MC-LFM 实验没有在 Table 1/2 中明确给出：

- exact closest slant range `R0` / incidence angle；
- exact azimuth-line sample count `N_a`；
- each component amplitude；
- `b_i`；
- initial phase。

因此如果自行补一个唯一值，会重新回到“闭门造参数”。

P1 的做法是：

### 文献参数
严格固定 Wang 明确给出的系统参数与 velocity。

### 推导参数
用 Xu 2025 Eq. (7),(8),(11) 把 velocity 映射成 residual FM rate：

`K_A = -2(V-v_a)^2/(lambda R0)`

`K_SAR = 2V^2/(lambda R0)`

`K_res = K_SAR^2/(K_A-K_SAR) + K_SAR`

### Controlled sensitivity
对未公开的 `R0` 与 azimuth sample count 做小范围 sensitivity：

`R0/H = [1, sqrt(2), 2]`

`N = [256, 512, 1024]`

这些不是 Wang 参数，代码和输出都会明确标记。

---

## 4. 为什么用 chirp-rate matched response，而不是现在就硬套 FrFT order

P0 已经解决 Xu 的 velocity–ORO convention。

但 Wang 2023 的离散 MC-LFM / FrFT 实现还涉及未报告的离散尺度与 line length。

因此 P1 使用物理单位 `Hz/s` 的 chirp-rate matched bank，只验证：

> 5 个物理 residual chirp rates 是否可以被分离。

Wang 论文明确指出，LFM 在 ORO 上的 FrFT 能量集中等价于重新匹配；所以这一 diagnostic 用来验证 separability 是合适的，但不宣称它是 Wang 原始 FrAc 曲线的逐点复现。

---

## 5. 未知 initial phase

Wang 没给每个 MC-LFM component 的 initial phase。

因此 P1 不固定一个“好看的 phase”，而是做：

`200` 次 uniform random phase Monte Carlo。

输出：

- phase-averaged matched response；
- all-five detection rate。

---

## 6. Gate

P1 gate 同时检查：

1. phase-averaged response 是否能识别 5 个 true residual-K peaks；
2. minimum true K separation 是否大于 isolated single-component median 3-dB width；
3. random-phase Monte Carlo 中 all-five detection rate 是否达到设定 diagnostic threshold。

Gate 状态：

- `PASS`
- `PASS_WITH_SENSITIVITY`
- `FAIL`

这些 gate threshold 是数值诊断标准，不是论文参数。

---

## 7. 输出

重点：

- `summary.txt`
- `p1_gate_summary.csv`
- `scenario_summary.csv`
- `representative_component_parameters.csv`
- `fig01_velocity_to_residual_FM.png`
- `fig02_representative_five_component_response.png`
- `fig03_single_component_responses.png`
- `fig04_separability_ratio_map.png`
- `fig05_phase_mc_detection_rate.png`

---

## 8. 代码位置

放到：

`E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation`

结果自动输出到：

`...\results\exp09_physical_validation\exp09_p1_wang2023_mc_lfm_baseline`

---

## 9. P1 通过后的路线

`P0 Xu2025 velocity→ORO calibration`

→ `P1 Wang2023 MC-LFM physical baseline`

→ `PA4 Physical Perturbation / Mirror Validation`

→ `Physical B3A/B3B`

→ `Physical B3B.1 Ownership`

→ `Bias–Jitter–Regime Map`

旧 normalized EXP009 保留为 Discovery Track。
