# Template: verifier report

Written by the verifier at `.docs/transition/reports/{WP_ID}-verifier-v{K}.md`. The first line of the file must be exactly `VERDICT: PASS` or `VERDICT: FAIL` — the orchestrator and the integrator read that line, not the prose, to decide what happens next.

```markdown
VERDICT: PASS

**WP.** {WP_ID} — {WP_TITLE}
**Attempt.** {K}
**Source branch.** {SOURCE_BRANCH}
**Verify branch.** {VERIFY_BRANCH}
**Commit sha.** <this branch's HEAD commit after your final commit>
**Acceptance script.** pipeline/acceptance/{wp_id_lower}_{slug}.R

## Results

| Check id | Result | Evidence |
|---|---|---|
| {WP_ID}.A1 | PASS / FAIL | <the exact evidence string the script printed> |

## Independent spot checks

At least 10, each traced to a raw source, not to the implementer's own output.

| # | Item | Source value | Output value | Match |
|---|---|---|---|---|
| 1 | <e.g. "SEN ADM1 row, GEO=SN07, INDICATOR=POV_HC, POVLINE_PL420"> | <value read directly from data_raw/... or INPUT .../..., cell reference> | <value in the WP's output file, row reference> | Y / N |

## Ownership check

Every path this branch changed since it diverged from {SOURCE_BRANCH}, checked against `.docs/transition/contract/output_ownership.csv`.

| Path changed | Owned by {WP_ID}? | Verdict impact |
|---|---|---|
| <path> | Y / N | — / **any N forces VERDICT: FAIL** |

## Failures to fix

<numbered, precise, reproducible — this exact block is pasted verbatim into {FAIL_REPORT} for the patch agent. "None" if VERDICT is PASS.>

1. <what failed, the check id, the exact command or comparison that shows it, and the expected vs actual value>
```

**Rules for the verdict.** `VERDICT: FAIL` if any acceptance check fails, any spot check mismatches, or the ownership check finds an unowned path — even if every acceptance check otherwise passes. `VERDICT: PASS` only when all three are clean.

**Final message to the orchestrator.** Starts with the literal line `VERDICT: PASS` or `VERDICT: FAIL`, then at most 150 words summarizing the evidence. On FAIL, this becomes (or closely mirrors) the "Failures to fix" block used as `{FAIL_REPORT}`.
