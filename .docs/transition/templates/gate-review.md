# Template: gate review

For each gate, this is what the orchestrator shows the user, the exact `AskUserQuestion` calls it makes, what happens on each answer, and the record format the scribe writes afterward (`.docs/transition/templates/decision-change.md` for G1's per-case files; the shared `GATE-{GATE_ID}.md` format at the bottom of this file for all three gates).

## G0 — standard v0.4 and the contract

**What the orchestrator shows the user.** A short written summary (not the full 900-line standard) covering: what changed from v0.3 to v0.4 (the D1–D9 user decisions folded in by WP02), the shape of the contract (`.docs/transition/contract.qmd` + `contract/*.csv`: what `output_ownership.csv` and `expected_counts.csv` contain), and the wave-1 acceptance results (WP01–WP03, from their verifier reports and `WAVE1-integration.md`). Link the actual files (`.docs/data-standard.qmd`, `.docs/transition/contract.qmd`) rather than re-typing their content into the question.

**`AskUserQuestion` call.**

```
Question: "Standard v0.4 and the contract are ready for review (wave 1 complete, all acceptance scripts pass — see WAVE1-integration.md). Approve them as the basis for wave 2?"
Options:
  - "Approve" (default) — proceed to wave 2 (WP04–WP12) as planned.
  - "Approve with notes" — proceed to wave 2, but record the user's notes for the affected WP cards before launching them.
  - "Hold" — do not start wave 2; the user will specify what needs to change first.
```

**What happens on each answer.**
- *Approve* — orchestrator launches wave 2 implementers as-is.
- *Approve with notes*: the orchestrator edits nothing itself. It hands the notes, verbatim, to the scribe, who records them in `GATE-G0.md`.
  - A note that changes a card, the contract or a decision is recorded as a `DECISION-G0-<n>.md` (template `decision-change.md`). The orchestrator then appends a pointer to that record ("Also apply `.docs/transition/reports/DECISION-G0-<n>.md`") to the implementer prompts of the affected wave-2 packages.
  - A note that changes wave-1 output (the standard or the scaffold) is fixed first by a patch agent on WP02 or WP03, with a fresh verifier and a re-integration. Only then does wave 2 start.
- *Hold* — orchestrator asks a follow-up (plain question, not another `AskUserQuestion` block) to find out what must change, then loops back to wave-1 patch attempts if needed before re-asking this gate.

## G1 — hard cases H1–H19

**What the orchestrator shows the user.** The merged wave-2 metadata (post-integration, 0 ERROR from the wave-2 metadata check) and, for each open case, its row from the hard-case table in `.docs/transition/decisions.qmd`: id, title, recommended coding (already built as DRAFT), alternative. Also show the relevant counts from `contract/expected_counts.csv` next to any case that changes a row count (e.g. H1/H10 change whether a derived indicator is stored). H15, H16, H18, H19 are already decided (D4/D3/D5) and are not asked again; H1–H14 and H17 are open.

**`AskUserQuestion` calls.** One question per open hard case, options always `Recommended (default)` / `Alternative` / `Other`, `Other` free-texted by the user. Batch at most 4 questions per call — 15 open cases need 4 calls. Suggested batching (by theme):

*Call 1 — consumption and jobs (H1–H4):*
```
Q1: "H1 — Non-food consumption share. Recommended: derive it (not stored) as 1 minus the food share. Alternative: store it as an aggregate qualifier COICOP_CP02T13."
Q2: "H2 — Own-production vs. market food share. Recommended: a new ACQ qualifier on CONS_SH + COICOP_CP01. Alternative: two separate indicators, CONS_FOOD_OWN_SH / CONS_FOOD_MKT_SH."
Q3: "H3 — Wage vs. non-wage employment. Recommended: POP_SH + a new EMP_TYPE breakdown (sums to 1.00 exactly). Alternative: a JOB_WAGE proportion indicator with non-wage derived."
Q4: "H4 — 'Employed' indicator. Recommended: EMP_STATUS_EMPLOYED only; never derive NOT_EMPLOYED. (No alternative was proposed.)"
Options (each): "Recommended" (default) / "Alternative" / "Other"
```

*Call 2 — jobs and electricity (H5–H8):*
```
Q1: "H5 — 'HH workers' in trade/transport. Recommended: POP_SH + new EMP_ISIC breakdown (sections G, H). Alternative: nest under EMP_SECTOR_SER, or separate JOB_* indicators."
Q2: "H6 — 'HH workers' informally employed. Recommended: POP_SH + new EMP_FORMAL_N, universe = employed. Alternative: universe = wage employees only, matching the current dashboard label."
Q3: "H7 — Three electricity indicators (grid connection/use/access). Recommended: keep as three DRAFT codes with a COMMENT override flagging the implausible SEN grid-connection values. Alternative: skip EN_GRID_CONN in both countries until better defined."
Q4: "H8 — Average outage duration (currently a code, not a real duration). Recommended: map as DRAFT with unit INDEX. Alternative: skip until the code's scale is documented."
Options (each): "Recommended" (default) / "Alternative" / "Other"
```

*Call 3 — households enterprises and coverage (H9–H12):*
```
Q1: "H9 — 'Cooker (proxy)' indicator, implausible pattern (clean cooking higher among the poor and rural). Recommended: keep as EN_ASSET_COOKER, name cleaned up. Alternative: skip entirely."
Q2: "H10 — 'HH owns a non-agric enterprise' vs. its owner variant. Recommended: derive one from HE_COUNT, keep the other (HE_HH_OWNER) as a separate DRAFT indicator. Alternative: model both as POP_HH_SH with an aggregate HE_COUNT_1P category."
Q3: "H11 — HE owner's sex/marital status. Recommended: POP_HE_SH + new HEO_SEX / HEO_MSTAT breakdowns. Alternative: two standalone proportion indicators."
Q4: "H12 — HE external (non-HH) employees, values look impossible (96–100% share for an 'all HEs' universe). Recommended: keep as DRAFT with a COMMENT override, universe TBD. Alternative: skip entirely."
Options (each): "Recommended" (default) / "Alternative" / "Other"
```

*Call 4 — coverage and the age cutoff (H13, H14, H17):*
```
Q1: "H13 — 'At least 1 HH member has health coverage.' Recommended: a household-level indicator, SP_HEALTH_COV_HH. Alternative: POP_HH_SH with a breakdown variable."
Q2: "H14 — Internet access, 0.00 or empty in every cell of both countries. Recommended: skip. Alternative: map it anyway with a COMMENT override."
Q3: "H17 — Household-head age cutoff ('Youth_HH'/'Older_HH'), undocumented; dashboard text implies 29 or 30. Recommended: keep DRAFT, renamable codes until confirmed with the producer. Alternative: lock in LT35/GE35 as the standard currently drafts them."
Options (each): "Recommended" (default) / "Alternative" / "Other"
```

*Call 5: questions raised by wave-2 reports.* Ask about every "open issues / questions for the user" item from the wave-2 implementer reports, at most 4 per call. For example, WP09 lists the differences between `Messages_SEN.txt` and the messages hard-coded in `index.qmd`. Ask which version is authoritative, with the options "Dashboard (index.qmd) version", "Messages file version" and "Other".

**What happens on each answer.** *Recommended* — the case is CONFIRMED, no code changes, only a `DECISION-<H_ID>.md` record. *Alternative* — the case FLIPS: the scribe records the new coding, and the orchestrator launches a patch agent (per `.docs/transition/templates/patch-prompt.md`) on the WP that owns the affected files, followed by a fresh verifier. *Other* — the orchestrator asks a short follow-up to pin down the user's actual coding, then treats it as a flip to that custom coding.

## G2 — accept outputs, decide on merging `transition/main`

**What the orchestrator shows the user.** `WAVE3-integration.md` and `WAVE4-integration.md` (or the single final wave's report if waves 3–4 collapsed), the final `.docs/transition/reports/WP15-*.md` reconciliation results, and the count comparison against `contract/expected_counts.csv` (row counts, series counts, code counts — every number in the triage report's "Expected outputs" section, actual vs. expected).

**`AskUserQuestion` call.**

```
Question: "Wave 4 (WP13–WP15) is complete: converter output matches expected counts, the reconciliation tool reports 0 ERROR. Accept these outputs, and if so, when should transition/main be merged into dev/eb?"
Options:
  - "Accept and merge now" (default) — an integrator merges transition/main into dev/eb immediately after this gate.
  - "Accept, merge later" — outputs are accepted, but the merge into dev/eb is deferred; the user will say when.
  - "Not yet" — do not merge; the user will specify what still needs fixing.
```

**What happens on each answer.** *Accept and merge now*: the orchestrator launches one more integrator run, **without `isolation`**, because `dev/eb` is checked out in the main working tree. Its prompt carries the line `G2 AUTHORIZATION: <the user's answer, verbatim>`. It follows the "Final merge into dev/eb" section of `integrator-prompt.md`; the orchestrator never merges itself. Then a scribe records G2 as done. If the main working tree has uncommitted changes, the integrator stops, and the orchestrator asks the user to commit or stash them. *Accept, merge later* — G2 is recorded as done, but no integrator is launched for the `dev/eb` merge until the user says so in a later turn. *Not yet* — orchestrator gathers what is missing, loops back to patch attempts on the relevant WPs.

## Record format: `GATE-{GATE_ID}.md`

Written by the scribe at `.docs/transition/reports/GATE-{GATE_ID}.md` for every gate.

```markdown
# Gate {GATE_ID}

**Date.** <YYYY-MM-DD>

## Questions asked

<each AskUserQuestion call's question text, verbatim, numbered>

## Answers (verbatim)

<the user's answer to each question, verbatim, in the same order — quote, don't paraphrase>

## Resulting actions

<for each question: what the orchestrator did as a result, e.g. "H7: Alternative selected -> patch WP08 (branch transition/wp08-legacy-maps-p1) -> verified PASS -> merged in WAVE2-integration.md addendum" or "G0: Approved, wave 2 launched unchanged.">
```
