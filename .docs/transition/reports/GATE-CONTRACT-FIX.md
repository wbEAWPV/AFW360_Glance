# GATE CONTRACT-FIX report

Not one of the plan gates G0, G1 or G2. Recorded for the WP17 audit; no STATUS.md gate row is added.

Date: 2026-09-22, decided by the user during wave 3, after the G1 freeze.

Background put to the user: WP11's validator reported 21 META.REQUIRED ERRORs against
metadata/plans/LEGACY_LABELS.csv because 88 of its 179 rows leave `scale` empty while the column was
marked status=R. WP11's patch agent and its v1 verifier independently concluded the marker was the
fault rather than the data or the check: the column's own description in csv_headers.csv reads
"empty on rows that are not MAP", the 88 empty rows are exactly the non-MAP rows, and sibling columns
with identical "required when X" grammar (series_id, duplicate_of, assert_rule, STD_ERR, CI_LOWER,
CI_UPPER) already used C. The same applied to N_OBS and N_POP, whose descriptions read "except legacy
ROUNDED_2DP files, where it is empty" and which are empty in 100% of rows of both converted files.

## Call 1

Q: "The contract marks `scale`, `N_OBS` and `N_POP` as R (required) although each one's own description
documents when it is legitimately empty, and sibling columns with identical grammar use C (required
when relevant). The validator enforces R literally, so it reports 21 ERRORs on LEGACY_LABELS.csv and
blocks the '0 validator errors' target. The contract was frozen at G1, so changing it is your call.
How should this be resolved?"

Options: Correct the contract to C = "Change status R->C for those three columns in csv_headers.csv,
regenerate metadata/structure/COLUMNS.csv to match (WP03), and re-verify WP03 and WP11." /
Make the check honour exceptions = "Leave the contract frozen; WP11 teaches META.REQUIRED to
skip the columns whose descriptions document an emptiness carve-out." /
Accept the 21 findings = "Change nothing; amend WP11.A1 and the '0 validator errors' target."

ANSWER: "Correct the contract to C"

Action: WP03 and WP11 were re-run against the corrected contract (see Call 2 and Resulting action
below); the contract's three status cells were changed from R to C and nothing else.

## Call 2

Q: "csv_headers.csv is marked frozen with 'no agent edits it; a change needs the user and a new plan
commit on dev/eb'. Your chosen fix requires editing it. How do you want to proceed?"

Options: You edit it, I do the rest / Authorize an agent to edit it / Switch to the code-only fix

ANSWER: "You edit it, I do the rest", and the user then instructed the orchestrator directly:
"make all the relevant edits yourself".

Action: The orchestrator made both contract-side edits itself, at the user's explicit instruction,
rather than through agents.

## Resulting action

- Commit c321d51 on dev/eb: .docs/transition/contract/csv_headers.csv, status R -> C on exactly three
  rows - LEGACY_LABELS.csv,6,scale; AFW360_HH_<ISO3>_<YEAR>.csv,24,N_OBS; AFW360_HH_<ISO3>_<YEAR>.csv,25,N_POP.
  Descriptions unchanged. Placed on dev/eb because output_ownership.csv marks that file PLAN/frozen
  with the note "A change needs the user and a new plan commit on dev/eb".
- Commit db069ac on transition/wp03-scaffold-p1: metadata/structure/COLUMNS.csv row 287
  (LEGACY_LABELS.csv,6,scale) status R -> C, so the generated registry matches the contract, with the
  report .docs/transition/reports/WP03-implementer-p1.md. N_OBS and N_POP are data-file rows that
  WP03's card excludes from COLUMNS.csv, so they do not appear there.

Outcome: WP03 verifier v2 PASS, having confirmed the contract diff is those three cells and nothing
else; WP11 patch p2 then reported validate.R exiting 0 with 0 ERROR rows on the full GNB fixture with
no change to any check module, and WP11 verifier v2 PASS confirmed it independently.

## Integration note

Both branches carrying this correction (transition/wp03-scaffold-v2, transition/wp11-validator-core-v2)
were merged into transition/main in the wave-3 integration recorded in
.docs/transition/reports/WAVE3-integration.md. `pipeline/validate.R` run at integration time against
the full merged tree confirms the fix: exit 0, ERROR: 0, WARN: 109, INFO: 8 — no META.REQUIRED
findings of any kind, so the 21 pre-fix errors are gone. Separately, the wave-3 integration surfaced
unrelated integration-only failures in the acceptance suite and unit tests (WP03, WP11, WP12, WP13;
see WAVE3-integration.md "Findings by owner") caused by validator modules from different packages
now running together against test fixtures written before the merge; these are not connected to the
CONTRACT-FIX decision and do not reopen it.
