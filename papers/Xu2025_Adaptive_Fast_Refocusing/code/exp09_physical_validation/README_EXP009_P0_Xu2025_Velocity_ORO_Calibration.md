# EXP009 / Physical Validation Track / P0
## Xu 2025 Velocity–ORO Calibration

### 1. 目的

这一阶段不是重新开始 EXP009，也不是创新实验。

P0 是进入“文献 / 工程参数锚定验证链”前的 **calibration gate**：

> 先验证 Xu 2025 给出的 `azimuth velocity → residual FM → ORO` 参数关系和 rotation-order convention，确认我们的后续物理参数实验不会继续沿用此前人工 normalized `q` 标度。

---

## 2. 论文直接提供的参数

Xu 2025 Table I：

- Bandwidth = 150 MHz
- Carrier frequency = 3 GHz
- PRF = 300 Hz
- Platform velocity = 200 m/s
- Pulse width = 4 μs
- Incidence angle = 45°
- Platform height = 10 km

Xu 2025 Table II：

- target azimuth velocities = `[-10, -5, 0, 5, 10] m/s`

Xu 2025 Table III：

- published ORO = `[-0.415, -0.457, -0.500, -0.534, -0.583]`
- published estimated speeds = `[-11.09, -5.36, 0, 4.96, 9.29] m/s`

代码中这些数值全部保持论文原值，不会为了“拟合更好看”而修改。

---

## 3. P0 为什么需要推断一个 effective N_a

Xu Eq. (20)–(22) 显式依赖：

`N_a = number of azimuth sampling points`

但 Xu Table I 并没有列出这个数值。

因此本实验不会假装 `N_a` 已知，而是：

1. 使用每一个非零 `(published ORO, published estimated speed)` 对反推 row-wise effective `N_a`；
2. 使用 median 得到 robust consensus `N_a`；
3. 另外用 target velocity 与 published ORO 做全局 grid search；
4. 检查 Eq. (22) 是否能够在合理尺度上复现论文的 velocity–ORO trend。

这属于 **parameter/convention audit**，不是对论文缺失参数进行无依据补全。

---

## 4. Rotation-order convention

Xu 2025 明确说明：

> rotation order was shifted by 0.5 overall.

本代码采用：

`p_raw = 2 * alpha / pi`

`p_reported = p_raw - 0.5`

因此：

`v_a = 0 -> p_reported = -0.5`

与 Xu Table III 对齐。

---

## 5. R0 的处理

论文 Table I 给出：

- platform height = 10 km
- incidence angle = 45°

但没有在表中直接列 `R0`。

P0 使用标准几何：

`R0 = H / cos(theta_inc)`

并在输出中明确标记这是 **derived quantity**，不是论文直接报告值。

---

## 6. Gate 判定

P0 输出：

- `xu2025_tableIII_consistency_audit.csv`
- `p0_gate_summary.csv`
- `na_grid_search.csv`
- `summary.txt`
- 4 张诊断图

Gate 状态：

- `PASS`
- `PASS_WITH_PUBLICATION_INCONSISTENCY`
- `REVIEW_REQUIRED`
- `FAIL`

如果出现单个 published row 与其余行不一致：

> 只标记，不擅自改论文数值。

---

## 7. P0 通过后做什么

按当前规划：

`P0 Xu-2025 velocity→ORO calibration`

→ `P1 Wang-2023 five-component MC-LFM baseline`

→ `Physical A4 perturbation / mirror validation`

→ `Physical B3A/B3B failure + first-order validation`

→ `Physical B3B.1 ownership`

→ `C3-B3B.2 Bias–Jitter–Regime Map`

旧 EXP009 normalized experiments 全部保留作为 Discovery Track，不从头重跑。

---

## 8. 运行

将本目录中的两个 `.m` 文件放到 MATLAB 工程路径：

```matlab
results = exp09_p0_xu2025_velocity_oro_calibration;
```

---

## 9. 本阶段最重要的实验纪律

P0 不允许：

- 人工修改 Xu published ORO；
- 为了降低 RMSE 手动挑一个 `N_a`；
- 把 inferred `N_a` 写成 “Xu paper parameter”；
- 把 P0 当成论文创新点；
- 直接将旧 EXP009 的 `q=1.47` 与 Xu 的 ORO 数值比较。

P0 的唯一目的：

> **把 normalized discovery model 与 paper-grounded physical parameterization 接起来。**
