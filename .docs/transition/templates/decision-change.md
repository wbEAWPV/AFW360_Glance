# Template: decision-change record

Written by the scribe at `.docs/transition/reports/DECISION-<H_ID>.md`, one file per hard case answered at gate G1 (or any later gate where a case is revisited) — whether the user confirmed the recommended coding or flipped to the alternative. `<H_ID>` is the case id, e.g. `H07`.

```markdown
# Decision <H_ID>

**Case.** <the case's short title, from the hard-case table, e.g. "Three electricity indicators">
**Date.** <YYYY-MM-DD, the date the user answered>
**Decided by.** User (relayed via the orchestrator at gate {GATE_ID})

**Previous coding (as built, DRAFT).** <what the triage report's "Recommended" column produced — the codes/fields as they exist in the merged wave-2 output before this decision>

**New coding.** <CONFIRMED: identical to the previous coding, now locked in — no file changes needed> / <FLIPPED: the "Alternative" coding from the hard-case table, spelled out as concretely as the previous-coding line above>

**Affected files / rows.**

| File | Rows affected | Owning WP |
|---|---|---|
| <path> | <how many / which key values> | {WP_ID} |

**Patch branch.** <the {BRANCH}-p{K} that implements the flip, or "N/A — confirmed, no patch needed">

**Verification result.** <the verifier's VERDICT on the patch branch that re-checks this case, or "N/A — confirmed">
```

**Confirmed vs. flipped.** A confirmed case still gets a `DECISION-<H_ID>.md` file (for the audit trail) but no patch branch and no new verification — its "Patch branch" and "Verification result" fields both read "N/A". A flipped case gets both, filled in once the orchestrator has launched the patch agent (per `.docs/transition/templates/patch-prompt.md`, using this file's "New coding" as `{DECISION}`) and its verifier has returned — the scribe may need to revisit this file after that verifier returns to fill in the last two fields, rather than writing them at gate time.
