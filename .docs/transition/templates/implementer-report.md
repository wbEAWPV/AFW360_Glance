# Template: implementer report

Written by the implementer (or patch agent) at `.docs/transition/reports/{WP_ID}-implementer.md` (or `-p{K}.md` for a patch attempt). Every section below must appear, in order; write "None" rather than dropping a section that has nothing to say.

```markdown
# {WP_ID} implementer report

**WP.** {WP_ID} — {WP_TITLE}
**Attempt.** {K} (1 for a first implementer pass; matches the `-p{K}` suffix for a patch)
**Branch.** {BRANCH} (or {BRANCH}-p{K})
**Commit sha.** <the branch's HEAD commit after your final commit>

## Files written

| Path | Rows or size |
|---|---|
| <path> | <row count for a CSV/data file, or byte size for anything else> |

## Steps done

<numbered list matching the card's "Steps", one line each: what you actually did, in order. Note any step you skipped or reordered and why.>

## Tests run

| Test | Result |
|---|---|
| <what you ran, e.g. "testthat::test_dir on pipeline/tests/testthat/wp05"> | PASS / FAIL — <detail if FAIL> |

## Acceptance self-check

| Check id | Result | Evidence |
|---|---|---|
| {WP_ID}.A1 | PASS / FAIL | <the concrete fact you checked, e.g. "14 SEN + 9 GNB adm1 features counted from the gpkg"> |

## Deviations from card or contract

<must be empty ("None") or, for each deviation: what the card/contract said, what you did instead, and why. A card ambiguity you resolved a specific way belongs here even if you did not "deviate" from a literal instruction.>

## Open issues / questions for the user

<anything you could not resolve yourself and are not positioned to guess at — a genuine ambiguity in the standard, a hard case the card assumed was closed but wasn't, a contract gap. "None" if you hit nothing.>

## Suggested changelog line

<one line, in the implementer's voice, for the integrator to append to metadata/CHANGELOG.md under `## 0.1.0 (unreleased)`>
```

**Final message to the orchestrator.** The implementer's (or patch agent's) last message is not this report — it is a plain-text summary of it, at most 150 words, covering: what was written, what passed, and any deviations or open questions. The orchestrator reads the full report from disk; it does not need the report pasted into the message.
