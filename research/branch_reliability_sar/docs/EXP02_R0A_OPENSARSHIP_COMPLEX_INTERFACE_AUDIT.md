# EXP02-R0A：OpenSARShip 真实复数舰船 Chip 接口审计

## 目标

确认 OpenSARShip 的原始 SLC ship chip 是否能稳定建立：

\[
\text{OpenSARShip TIFF}
\rightarrow
(S_{VH},S_{VV})
\rightarrow
g(:,n)
\]

这一真实复数数据入口。

本阶段只做数据与接口验证，不进行 branch analysis。

## 数据对象

首个 science-pilot chip：

```text
Cargo_x19112_y4564.tif
```

选择依据不包含任何 branch outcome：

- 257 × 257，提供较长的 azimuth support；
- SAR manual length 约 252 m；
- AIS/SAR length match 较好；
- 存在非零 AIS ground speed；
- 与当前 controlled B4 的约 267 azimuth samples 数量级接近。

这只是首个真实 signal probe，不代表“最难目标”或“最可能产生 D-class”。

## 轴与复数定义

OpenSARShip ReadMe 明确：

\[
x=\text{range},\qquad y=\text{azimuth}.
\]

SLC Patch 四个 band：

\[
B_1=\Re(S_{VH}),\quad
B_2=\Im(S_{VH}),
\]

\[
B_3=\Re(S_{VV}),\quad
B_4=\Im(S_{VV}).
\]

因此 MATLAB 中：

\[
g(:,n)=S(:,n)
\]

定义为固定 range cell 的 complex azimuth line。

## 关于“三维扰动量”

OpenSARShip 没有给出逐目标同步的：

- roll(t)
- pitch(t)
- yaw(t)
- heave(t)
- sway(t)
- surge(t)

真值时间序列。

AIS 提供的是导航层变量，例如 SOG、COG、True Head、ROT 等。它们不能等价替代舰船三维姿态扰动。

真实海面运动若存在，其 roll/pitch/yaw 等效影响可能已经隐含进入 complex SLC 的相位、散射中心迁移和失焦结构，但无法从该数据集直接当作已知 ground truth 使用。

因此 EXP02 的定位应是：

\[
\text{real complex observation}
\rightarrow
\text{natural signal-state occurrence audit}
\]

而不是：

\[
\text{known 3-D motion truth}
\rightarrow
\text{branch-failure supervised mapping}.
\]

## 下一 Gate

R0A 通过后进入 R0B：

> 真实 \(g(:,n)\) 是否仍具有足够的 local MC-LFM / quadratic signal-model validity？

只有 R0B 通过后，才进入 R1：

> 是否自然出现 D-like / G-like branch geometry？
