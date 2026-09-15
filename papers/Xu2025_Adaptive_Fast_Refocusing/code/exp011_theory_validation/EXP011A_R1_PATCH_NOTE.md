# EXP011-A-R1 Patch Note

## Why this rerun is needed

The first formal EXP011-A run completed, but trial-level review exposed two **audit implementation** issues and one plotting-only warning. None changes the TB1 equations or any frozen physical/search parameter.

### 1. Geometry-domain coverage

The first audit used the frozen operational GlobalReference domain `[-1.5,+1.5]` also as the domain for continuous-branch discovery. However, G0 uses the full integer DFT top-1 and may refine a seed whose local maximum lies outside that reference domain.

Therefore some actual G0 branches were labeled `BRANCH_ASSIGNMENT_UNRESOLVED` even though they are valid objective branches.

R1 separates the two domains:

- **GlobalReference remains frozen** at `[-1.5,+1.5]`;
- **geometry discovery domain** is derived mechanically from the frozen seed bank and local-search halfwidth:

```text
[seed_min-h, seed_max+h]
```

With the inherited values this is `[-3.75,+3.75]`. No label or failure outcome is used to choose it.

### 2. Nonfinite margin taxonomy

In the first run, `sign_with_tol(Inf)` returned zero, so rows with **no accessible competitor** were reported as `TYPE_III_MARGIN_NEAR_ZERO`.

R1 reports them separately as:

```text
TYPE_III_NO_ACCESSIBLE_COMPETITOR
```

This is bookkeeping only.

### 3. MATLAB SceneNode warning

The figure label is changed to explicit LaTeX:

```matlab
ylabel('Effective coarse margin $\widetilde{M}_{cb}$','Interpreter','latex');
```

This warning never affected numerical results.

## Scientific freeze

R1 does **not** change:

- physical risk states;
- eta grid;
- contrast;
- phase;
- aperture;
- true-beta control;
- G0 / N3 search semantics;
- GlobalReference domain;
- catastrophic threshold;
- branch-match tolerance;
- TB1 equations.

This is a reproducibility/audit correction, not theory tuning.
