# EXP009 / PA5C
## Wang-2023 Algorithm-2 Filter-Removal Bridge

PA5B established a clean rank-1 LS projection mechanism. PA5C now tests
whether that mechanism survives under the **actual operator structure
described by Wang et al. (2023), Algorithm 2**.

## 1. What the paper actually specifies

Wang Algorithm 2 describes the following per-component sequence:

1. perform FrFT at the component optimal rotation order;
2. detect peaks whose magnitude exceeds `0.7 * max`;
3. isolate those peaks with narrowband windows;
4. accumulate the isolated/refocused signal;
5. subtract it in the fractional domain;
6. inverse FrFT the residual before processing the next component.

Therefore PA5C no longer uses only a rank-1 time-domain LS subtraction.

## 2. What the paper does **not** fully specify

Two details cannot honestly be treated as fixed paper parameters:

- the algorithm defines a narrowband window length `l`, but does not give
  one unique numerical `l` in the Algorithm-2 text;
- the paper gives the continuous FrFT definition but not a fully specified
  bit-exact discrete implementation/scaling for reproducing the authors'
  code.

PA5C therefore does **not** invent these missing details.

Instead:

- `l = [1,3,5,9,17]` bins is a controlled sensitivity sweep;
- the fractional-domain removal is implemented as a clearly labelled
  **LFM-matched unitary bridge**:

```text
dechirp at a_hat
-> unitary FFT
-> Wang 0.7 peak detection
-> narrowband binary window
-> inverse FFT
-> re-chirp
```

For the discrete LFM model used in EXP009, an exactly matched LFM becomes
an impulse-like spectral peak, so this reproduces the functional
focus-filter-inverse-transform action required by Algorithm 2.

It is **not** presented as a bit-exact reproduction of the authors'
private DFrFT implementation.

## 3. Operator groups

### LS-P

Corrected practical LS projector from PA5B.

This is the analytic reference.

### W-O

Wang-style transform-domain filter removal using the **true** strong
chirp parameter.

This measures the filter/window operator itself.

### W-P

Wang-style filter removal using the **FrAc-estimated** practical strong
parameter.

This is the main practical bridge.

## 4. Exact error ownership still exists

For a fixed Wang binary mask `Q` under the unitary bridge:

```text
r = (I-Q)(s+w)
e = r-w = (I-Q)s - Qw
```

Because `Q` is an orthogonal projector for a fixed mask:

```text
||e||^2
=
||(I-Q)s||^2
+
||Qw||^2
```

Therefore PA5C still decomposes error into:

- strong leakage;
- weak projection loss.

The important new question is whether window width creates the expected
tradeoff:

```text
larger l
-> lower strong leakage
-> higher weak projection loss
```

and whether the PA5B contrast-scaled subtraction-tolerance law survives.

## 5. Weak-stage success is now source-aligned

Wang Algorithm 2 already has the optimal-order set before sequential
refocusing.

Therefore PA5C does not re-run FrAc on the residual as the primary
success test.

Instead, after strong removal the residual is transformed at the **true
weak order**, and the weak focused bin is checked against Wang's own
Algorithm-2 `0.7 * max` peak criterion.

This answers:

> after removing the strong component, is the weak component ready to be
> accepted/refocused at its own known optimal order?

## 6. Physical grid

Inherited unchanged from PA5B:

- `fc = 3 GHz`
- `PRF = 188 Hz`
- `H = 3000 m`
- `La = 2 m`
- `V = 150 m/s`
- `R0/H = sqrt(2)` representative geometry
- `v_w = 15 m/s`
- `Delta v = [2.5,5,7.5,10,15,20] m/s`
- `A_w/A_s = [0.1,0.2,0.3,0.5,0.8]`
- 16 relative phases
- Paper1s and BeamDerived apertures
- `b_s = b_w = 0`
- no noise

## 7. Controlled filter-width sweep

```matlab
filter_window_length_bins = [1 3 5 9 17];
```

These are **controlled values**, not claimed as Wang-reported values.

The purpose is to determine whether there is a genuine:

```text
strong-leakage <-> weak-loss
```

operator tradeoff.

## 8. Controlled tolerance bridge

For one representative physical geometry:

```text
Delta v = 10 m/s
HighV
```

PA5C directly imposes:

```text
delta_beta / W_beta in [-0.30,0.30]
```

and computes the maximum allowed strong-order error for:

```text
||r-w||/||w|| <= 1
```

for every:

- aperture;
- `A_w/A_s`;
- window length `l`.

This tests whether the approximately linear PA5B relation

```text
allowed beta error ~ weak/strong ratio
```

survives under Wang-style filtering.

## 9. Priority outputs

First inspect:

- `pa5c_projection_identity_summary.csv`
- `pa5c_window_tradeoff_summary.csv`
- `pa5c_balanced_window_summary.csv`
- `pa5c_tolerance_summary.csv`
- `pa5c_decision_summary.csv`

Then:

- `pa5c_contrast_window_summary.csv`
- `pa5c_regime_window_summary.csv`

Figures:

- `fig01_practical_success_vs_window.png`
- `fig02_practical_error_vs_window.png`
- `fig03_leakage_loss_tradeoff.png`
- `fig04_operator_identity.png`
- `fig05_ls_vs_wang_error.png`
- `fig06_beam_contrast_window_error_map.png`
- `fig07_tolerance_vs_contrast_by_window.png`
- `fig08_regime_success_balanced_window.png`

## 10. Run

Place in:

`E:\SAR_Moving_Ship_Refocusing_Reproduction\papers\Xu2025_Adaptive_Fast_Refocusing\code\exp09_physical_validation`

Run:

```matlab
results = exp09_pa5c_wang_filter_removal_bridge;
```

Results:

`results\exp09_physical_validation\exp09_pa5c_wang_filter_removal_bridge`

## 11. Interpretation discipline

PA5C is deliberately designed so that every outcome is useful.

If Wang-style filtering preserves the PA5B tolerance scaling:

> the strong-subtraction sensitivity mechanism survives the operator
> bridge.

If a strong window-width tradeoff appears:

> the practical design variable becomes not only estimator accuracy but
> also fractional-domain filter width.

If PA5B scaling collapses:

> the LS result was operator-specific and should not be generalized.

If the paper's unspecified `l` strongly changes the result:

> this becomes an important algorithm-sensitivity / reproducibility issue,
> not something to hide by selecting one convenient `l`.

Noise/clutter still remain OFF until this operator bridge is closed.
