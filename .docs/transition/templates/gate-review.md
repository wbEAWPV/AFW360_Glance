# Gate review: what the orchestrator asks the user

There are three gates. The orchestrator asks through `AskUserQuestion`, with at most 4 questions per call. It passes the answers, word for word, to the next integrator as `{GATE_RECORDS}`. It never answers for the user, and it never passes a gate without an answer.

## G0 — hard cases (at the start, while wave 1 runs)

**Why first.** The hard cases decide codes. They are answered before anything is built, so that a flip costs one edit of the contract seeds (WP99) and no rework of files already built. Every answer can be given from the evidence in `decisions.qmd`; none of them needs built files.

**What to show.** One line saying that the full evidence for each case is in `.docs/transition/decisions.qmd`, section "Hard cases". Cases H15, H16, H18 and H19 are already decided and are not asked again.

**Questions.** One per open case. The options are always "Recommended", "Alternative" and "Other". H4 has no alternative, so its options are "Recommended" and "Other".

*Call 1: consumption and jobs*

1. "H1 — Non-food consumption share. Recommended: not stored; derived as 1 minus the food share. Alternative: stored under an aggregate qualifier COICOP_CP02T13."
2. "H2 — Own-production and market food shares. Recommended: a new ACQ qualifier on CONS_SH with COICOP_CP01. Alternative: two separate indicators."
3. "H3 — Wage and non-wage employment. Recommended: POP_SH with a new EMP_TYPE breakdown; the two sum to 1.00 exactly. Alternative: one JOB_WAGE indicator, with non-wage derived."
4. "H4 — 'Employed'. Recommended: only EMP_STATUS_EMPLOYED is stored; 'not employed' is never derived."

*Call 2: jobs and electricity*

1. "H5 — 'HH workers' in trade and transport. Recommended: POP_SH with a new EMP_ISIC breakdown (sections G and H), universe TBD. Alternative: children of EMP_SECTOR_SER, or separate indicators."
2. "H6 — 'HH workers' informally employed. Recommended: POP_SH with EMP_FORMAL_N, universe = employed persons. Alternative: universe = wage employees only, as the dashboard labels it today."
3. "H7 — Three electricity indicators. Recommended: three DRAFT codes, with a comment flagging the implausible Senegal grid-connection values. Alternative: skip EN_GRID_CONN in both countries."
4. "H8 — Average outage duration, the mean of an ordinal code. Recommended: keep as DRAFT with unit INDEX. Alternative: skip until the code scale is documented."

*Call 3: energy, enterprises and coverage*

1. "H9 — Cooker 'proxy' and clean cooking, implausible pattern in Senegal. Recommended: keep as EN_ASSET_COOKER, with a comment on the clean-cooking rows. Alternative: skip the cooker label."
2. "H10 — 'HH owns a non-agric enterprise' against 'has an enterprise owner'. Recommended: the first is derived from HE_COUNT, and the second is a new DRAFT indicator HE_HH_OWNER. Alternative: POP_HH_SH with an aggregate HE_COUNT_1P category."
3. "H11 — Enterprise owner's sex and marital status. Recommended: POP_HE_SH with new HEO_SEX and HEO_MSTAT breakdowns. Alternative: two standalone indicators."
4. "H12 — 'HE has external employees', impossible values (96 to 100 %). Recommended: keep as DRAFT with a comment. Alternative: skip."

*Call 4: coverage, age cutoff and key messages*

1. "H13 — 'At least one member has health coverage'. Recommended: a household-level indicator SP_HEALTH_COV_HH. Alternative: POP_HH_SH with a breakdown."
2. "H14 — Internet access, 0.00 or empty everywhere. Recommended: skip. Alternative: map it with a comment."
3. "H17 — Household-head age cutoff, undocumented; the dashboard says '29+'. Recommended: DRAFT codes that stay renamable until the producer confirms. Alternative: keep LT35 and GE35 as the standard drafts them."
4. "T1 — Key messages. The dashboard's hard-coded messages and the Messages files differ in titles and bodies. Which is authoritative?" The options are "Dashboard (index.qmd)", which is recommended; "Messages files"; and "Other".

**On the answers.**

- "Recommended" confirms the case, and nothing changes.
- "Alternative" or "Other" is a flip. For "Other", ask one plain follow-up to pin the coding down. Then launch WP99 with every flip in its `DECISIONS` block, and launch its verifier afterwards. WP99 merges with wave 1.
- T1 becomes `MESSAGES_SOURCE: dashboard` or `MESSAGES_SOURCE: files` in the `{NOTES}` of WP10's implementer and verifier.

## G1 — standard v0.4 and the contract (after the wave-1 integration)

**What to show.** Send a scout (see `scout-prompt.md`). Show the size of the diff of `.docs/data-standard.qmd`, its "Changes since v0.3" table, and the wave-1 checks: `data_raw/` checksums, contract check, dashboard render. If WP99 ran, show the counts it changed. Name the two files so that the user can open them.

**Question.** "Standard v0.4 and the contract are ready, and wave 1 is integrated. Approve them as the basis for building the metadata?"

- "Approve" (recommended): the contract is frozen, and wave 2 starts.
- "Approve with notes": ask for the notes. A note that concerns a wave-2 or wave-3 package goes, word for word, into that package's `{NOTES}`. A note that changes the standard goes to a WP02 patch agent in `FAILURES` mode, with the note as its input, followed by a fresh verifier and a follow-up wave-1 integrator run. Wave 2 starts only after that.
- "Hold": ask what must change. Patch, verify and integrate as above, then ask again.

## G2 — accept the results, and decide the merge (after WP17 passes)

**What to show.** Send a scout for WP17's "Targets" and "Warnings" tables. Show them, together with the validator's ERROR, WARN and INFO counts and the reconciliation result from the wave-3 integrator's message.

**Question.** "The transition is complete: every target is met, the validator reports 0 errors, and every source cell is reconciled. Accept the results, and merge into dev/eb?"

- "Accept and merge now" (recommended): launch the final-merge integrator without isolation, with the user's answer as `{G2_ANSWER}`. If it reports a dirty working tree, ask the user to commit or stash, and launch it again.
- "Accept, merge later": stop here. The user starts the merge in a later session; the resume scout will show WP17 as PASS and not merged.
- "Not yet": ask what is missing, and route it to patch agents on the owning packages.
