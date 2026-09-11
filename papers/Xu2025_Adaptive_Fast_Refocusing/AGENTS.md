# Project Working Rules

This is a research-code project on SAR defocusing/refocusing for complex moving ships. MATLAB is the primary experiment language.

## Research integrity

- Researchers decide the research question, experimental hypotheses, control groups, metrics, and protocol. Do not invent or change them.
- Never tune parameters merely to obtain an expected result. A negative result is a valid result.
- Before changing an existing experiment, read its corresponding README and any DESIGN document first.
- Keep these labels explicit in analysis and documentation: `Confirmed by evidence`, `Working hypothesis`, and `Planned-not-tested`.
- If README, code, and results disagree, report the conflict. Do not select one version as truth without researcher direction.

## Change discipline

- Before modifying files, check Git status when Git metadata is available. This checkout currently has no detected `.git` directory; report that fact rather than inventing Git state.
- Do not commit or push without explicit authorization.
- After modifications, report changed files and the diff.
- Do not delete historical experimental results.
- Do not modify MATLAB code, experimental parameters, or result files unless the request explicitly authorizes it.

## Project context

- `code/exp09_pilot01/` is the historical mechanism-discovery branch.
- `code/exp09_physical_validation/` is the active Physical Validation branch.
- Consult `CODEX_START_HERE.md`, `CURRENT_STATUS.md`, and `RESEARCH_LINEAGE.md` before extending EXP009.
