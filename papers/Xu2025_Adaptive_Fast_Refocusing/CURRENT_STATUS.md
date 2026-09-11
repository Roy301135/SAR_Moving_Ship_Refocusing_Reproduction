# Current Status

## Active Branch

`Physical Validation`

## Current Experiment

`PA5J-A` -- Internal Unreliability Indicator Discovery.

## Current Research Question

Can `G0_OriginalTop1` recognize its own impending catastrophic branch failure from internally available observables, so that Neighbor-3 is used only when needed?

## Confirmed So Far

- **Confirmed by evidence:** Pilot-01 identified practical CLEAN residual/coherent-interference mechanisms in a controlled discovery model.
- **Confirmed by evidence:** Physical PA5 work identified the fractional-bin fence effect, coarse-winner instability, and rare catastrophic branch switching.
- **Confirmed by evidence:** Neighbor-3 had zero catastrophic failures on the tested PA5I-R1 dense-risk manifold; this does not prove safety outside that tested deterministic regime.
- **Confirmed by evidence:** PA5J-A reconstructs upstream G0 inputs and screens internal features on both the original PA5I grid and PA5I-R1 dense-risk set.
- The final PA5J-A decision branch has not been confirmed from result content.

## Working Hypotheses

- A low-cost internal observable can transfer from the original grid to the dense-risk stress set and identify trials needing Neighbor-3.
- An adaptive trigger can reduce extra refinement cost without concealing rare catastrophic failures.

## Known Documentation/Code Mismatches

- The README treats cross-aperture performance as a requirement for a useful indicator, but the current automatic pass/decision logic does not include a per-aperture pass condition.
- README cost class 1 says no extra objective evaluation is required after G0; the current script explicitly computes `Jcoarse` for `refinement_gain_rel`. The theoretical feature may be available from prior work, but the current execution does not fully match that description.
- An early PA5J-A assumption that dense trial rows contained chirp parameters was fixed. The current interface joins the normalized dense trials with `pa5i_r1_dense_eta_risk_states.csv` by `risk_state_id`; this is not an open current-interface mismatch.

## Open Questions

- Which PA5J-A indicator, if any, passes stable original-grid and dense-risk screening?
- Does it retain sufficient performance across both apertures once cross-aperture acceptance is made explicit?
- What trigger fraction and false-trigger cost are acceptable for an eventual adaptive gate?

## Next Decision Gate

Do not force a threshold merely to enter PA5J-B.

- Only proceed to `PA5J-B` when an internal indicator stably passes screening on both the original set and dense-risk set.
- If only a post-G0 indicator works, complete G0 first, then decide whether to run Neighbor-3.
- If only a two-extra-evaluation indicator works, make its computational cost trade-off explicit.
- If no robust univariate indicator exists, investigate a multivariate indicator model or a new mechanism-derived observable before claiming an adaptive gate.
