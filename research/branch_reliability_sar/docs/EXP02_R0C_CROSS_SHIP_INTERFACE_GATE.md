# EXP02-R0C：OpenSARShip Processing-Object 跨舰重复性审计

## 核心问题

R0B 的负结果可能有两种解释：

1. 只是 `Cargo_x19112_y4564` 的个例；
2. OpenSARShip 这类 focused ship chips 与我们当前 frozen MC-LFM branch mechanism
   的生成条件本身就不匹配。

R0C 不修改方法，只在三个**事前固定**的真实目标上重复完全相同的 R0B 诊断。

## 为什么这一步比直接进入 R1 更重要

Wang 2023 的模型不是“任何 SLC line 都是 MC-LFM”，而是：

\[
\text{3-D swing}
\rightarrow
\text{spatially variant phase error}
\rightarrow
\text{erroneous azimuth matched filtering}
\rightarrow
\text{residual LFM components}
\]

从而得到：

\[
g(:,n_j)=\sum_i e^{j2\pi(0.5a_i m^2+b_i m)}.
\]

因此：

\[
\text{complex SLC}
\]

只是 processing-object 类型的必要条件，并不是 MC-LFM 生成机制成立的充分条件。

## 三个目标

固定：

- x19112_y4564；
- x48949_y5380；
- x64672_y2351。

选择标准仅使用 chip support、目标长度、AIS motion / match metadata，
不使用任何 LFM/branch outcome。

## 决策

若三个目标均重复出现：

\[
C_{\rm target}\lesssim C_{\rm background},
\]

且 target 的 chirp gain 不强于 background control，则停止把 OpenSARShip
作为 frozen branch mechanism 的直接验证源。

这不否定 OpenSARShip 的 complex-data 真实性，只说明：

\[
\text{real complex SLC}
\not\Rightarrow
\text{3-D-swing MC-LFM branch regime}.
\]

若某个事前固定目标出现明确 target-specific LFM structure，也不直接进入 R1；
先用 Wang 原始 FrAc/MC-LFM 语义做 source-aligned R0 audit。
