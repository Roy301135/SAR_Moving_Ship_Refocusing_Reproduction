# EXP01 Stage-B5：Frozen 3-D Scene ERV / IPP Quasi-Stationarity Audit

## 1. Research Question

在已经接受、不得调参的 Stage-B4 三维刚体摆动场景中：

> 当前约 1.4 s 合成孔径内，雷达有效转动矢量 ERV 与图像投影面 IPP 到底变化多大？

该实验仅解释 Stage-B4 的物理观测状态，不寻找新的 D-class，也不运行 Proposed。

---

## 2. Served Claim / Evidence Gap

Stage-B4 已知：

- roll + pitch + yaw 三维刚体摆动；
- 图像存在明显空间变失焦；
- local quadratic / MC-LFM fit 仍很好；
- 25 条自然 target lines 中 `E=24, G=1, D=0`。

当前尚未直接验证的 alternative explanation 是：

> `D=0` 是否只是因为约 1.4 s aperture 本质上仍处于 radar-effective quasi-stationary interval？

Stage-B5 只补这一解释性证据。

---

## 3. Frozen Protocol

严格禁止：

- motion / scene retuning；
- aperture sweep；
- motion sweep；
- 新 hard-state construction；
- 新 branch feature；
- 重新运行 Proposed；
- 通过结果反向选择 motion parameters。

只允许对 Stage-B4 已冻结参数进行几何重分析。

---

## 4. Coordinate Convention

沿用现有 SAR 场景：

- world x：方位 / 平台飞行方向；
- world y：地距离方向；
- world z：向上；
- `u_LOS`：雷达平台指向舰船质心；
- body-to-world rotation：`Rx(roll)*Ry(pitch)*Rz(yaw)`。

舰船角速度不通过三个 Euler-angle 导数直接相加，而从旋转矩阵运动学得到：

\[
\Omega_{\rm ship}
=
\dot R R^T,
\]

取其反对称部分并执行 vee 映射：

\[
\omega_{\rm ship}
=
\operatorname{vee}
\left[
\frac{\Omega_{\rm ship}-\Omega_{\rm ship}^T}{2}
\right].
\]

平台导致的 LOS 转动定义为满足

\[
\dot u_{\rm LOS}
=
\omega_{\rm SAR}\times u_{\rm LOS}
\]

的最小角速度：

\[
\omega_{\rm SAR}
=
u_{\rm LOS}\times\dot u_{\rm LOS}.
\]

按综述定义：

\[
\omega_{\rm eff}
=
(\omega_{\rm SAR}+\omega_{\rm ship})
\times u_{\rm LOS}.
\]

横向方向：

\[
u_{\rm CR}
=
\frac{\omega_{\rm eff}\times u_{\rm LOS}}
{\|\omega_{\rm eff}\times u_{\rm LOS}\|}.
\]

IPP 由

\[
\{u_{\rm LOS},u_{\rm CR}\}
\]

张成，其法向量为

\[
n_{\rm IPP}
=
\frac{u_{\rm LOS}\times u_{\rm CR}}
{\|u_{\rm LOS}\times u_{\rm CR}\|}.
\]

在这些定义下，`n_IPP` 与归一化 `omega_eff` 理论上同向。因此二者漂移不是两项独立证据，而用于定义一致性自检。

---

## 5. Metrics

仅报告：

### ERV

- mean / min / max magnitude；
- center magnitude；
- coefficient of variation；
- maximum / RMS direction drift。

### LOS

- maximum / RMS angular drift。

### IPP

- maximum / RMS normal drift；
- cross-range direction drift。

### Context

- mean / max ship angular speed；
- mean / max SAR-induced LOS angular speed；
- ship/SAR angular-speed ratio。

### Existing Stage-B4 model evidence

直接读取已冻结结果：

- scatterer quadratic-fit NRMSE median / max；
- selected-line dominant-component NRMSE median / max。

---

## 6. No New Threshold

本实验不人为定义：

```text
IPP drift < X deg => quasi-stationary
```

因为当前没有冻结的、文献支持的统一阈值。

因此代码不自动给出 YES / NO 科学结论，只输出描述性指标。最终通过：

\[
(\Delta\omega_{\rm eff},\Delta IPP)
+
\text{quadratic-fit evidence}
+
\text{Stage-B4 D=0}
\]

联合解释。

---

## 7. Falsifier / Outcomes

### Outcome A

ERV / IPP drift 很小，同时 quadratic fit 很好：

\[
\Rightarrow
\]

当前 B4 aperture 可合理解释为 quasi-stationary local interval。

### Outcome B

ERV / IPP 已明显变化，但 quadratic fit 仍好，且 B4 仍 `D=0`：

\[
\Rightarrow
\]

dynamic observation geometry 本身并不足以推出 discrete-first branch vulnerability；D-class 仍依赖更具体的 multi-component signal geometry。

### Outcome C

rotation / LOS / IPP 自检异常：

只做 coordinate / implementation audit，不允许开启 motion sweep。

---

## 8. Stop Rule

Outcome A 或 B 均意味着：

```text
controlled rigid-body simulation FREEZE
```

Stage-B5 后不增加 B6/B7 motion experiments。

下一真实性层级应转向：

```text
real / public complex SAR
→ local model validity
→ natural branch-state occurrence audit
```
