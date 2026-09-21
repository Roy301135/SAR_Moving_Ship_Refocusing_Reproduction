# EXP02-R0B：真实复数方位线局部 LFM 兼容性审计

## Research Question

在 OpenSARShip 真实 focused complex SLC ship chip 中，自然目标 range cells
对应的 complex azimuth lines \(g(:,n)\)，是否表现出与当前 signal-level
discrete-LFM 家族一致的 coherent chirp-like structure？

该问题必须在 branch occurrence audit 之前回答。

## Why not direct phase fitting?

真实 ship line 往往是多散射中心 coherent mixture。直接 unwrap 原始混合相位
再做单一 quadratic fit，容易把多分量干涉、speckle 和 amplitude null
误解释成模型失效。

因此 R0B 使用 matched LFM projection：

\[
C=
\frac{\max_{\beta,\nu}|\langle x,s_{\beta,\nu}\rangle|^2}
{N\|x\|^2}.
\]

它只是 diagnostic，不成为新的 reliability feature。

## Pools

Target 沿用 R0A 的 \(E(n)>\bar E\)。

Background control 选择相同数量的最低能量非目标 columns。

代表 line 按 target-line energy 固定选择：

- strongest selected;
- median selected;
- weakest selected.

不按结果挑图。

## Stop Rule

若 target lines 相对 controls 没有可解释的 coherent nonzero-beta structure，
停止在该 chip 上做 branch occurrence。

若 target lines 表现出稳定的 interior chirp-like structure，则进入 EXP02-R1。
