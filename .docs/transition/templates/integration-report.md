# Template: integration report

Written by the integrator at `.docs/transition/reports/WAVE{WAVE}-integration.md`.

```markdown
# Wave {WAVE} integration report

**Wave.** {WAVE}
**Merged branches and merge commits.**

| WP | Branch | Merge commit |
|---|---|---|
| {WP_ID} | {BRANCH} (verified as {VERIFY_BRANCH}) | <sha of the --no-ff merge commit> |

## Conflicts

<"None", or for each: which merge, which file, why it was allowed (must be `metadata/CHANGELOG.md` or `.docs/transition/STATUS.md`) and how it was resolved. Any conflict in any other file must instead appear under "Blocked" below — it is never "resolved" by the integrator.>

## Regression results

| Script | Result |
|---|---|
| pipeline/acceptance/<name>.R (wave <n>, WP<nn>) | PASS / FAIL |

<from wave 2 on, this table is produced by `Rscript pipeline/acceptance/run_all.R --root .`; for wave 1, each script was run directly.>

**testthat.** <ran / not applicable (no tests exist yet) — pass/fail summary if run>
**quarto render (wave 1 only).** <exit code; confirmation that render output was removed afterward>

## Wave 2 metadata check (wave 2 only)

**Command.** `Rscript pipeline/validate.R --root . --metadata-only --out .docs/transition/reports/WAVE2-metadata-findings.csv`
**Result.** <n> ERROR, <n> WARN, <n> INFO.

<if any ERROR: list each one with its owning WP (looked up in `.docs/transition/contract/output_ownership.csv`) so the orchestrator can launch patch agents; the wave is not integrated until a rerun shows 0 ERROR.>

| Finding | File | Owning WP |
|---|---|---|
| <check_id, message> | <path> | {WP_ID} |

## STATUS changes

<which WP rows moved to MERGED, which gate row (if any) changed, any row left un-merged and why>

## Changelog lines added

<the exact lines appended to metadata/CHANGELOG.md under `## 0.1.0 (unreleased)`, one per merged WP>

## Blocked

<anything that stopped you from completing the wave: an aborted merge with an ownership conflict outside CHANGELOG/STATUS, a regression failure, a metadata-check ERROR not yet patched. "None" if the wave is fully integrated. Never a deliverable you decided to fix yourself — you don't.>
```

**Final message to the orchestrator.** At most 150 words: which branches merged cleanly, any conflicts aborted and why, the regression result, the wave-2 metadata-check result if applicable, and whether the wave is fully integrated.
