# Transition status board

Written only by integrators, on branch `transition/main`. The copy on `dev/eb` is the initial state.

**Git is the source of truth.** This board is a readable summary. The state of a package between integrations is read from branch names and commit subjects (`WPNN: verify v1 - VERDICT: PASS`); see the resume question in `templates/scout-prompt.md`.

States: `TODO` · `MERGED` (integrated into `transition/main`) · `BLOCKED` (escalated to the user) · `SKIPPED` (WP99 when no hard case was flipped).

## Work packages

| WP | Title | Wave | State | Latest branch | Verdict | Attempts | Updated |
|---|---|---|---|---|---|---|---|
| WP00 | Setup and environment check | W0 | MERGED | transition/main | STATUS: DONE | 1 | 2026-09-22 |
| WP01 | Move legacy inputs to data_raw | W1 | MERGED | transition/wp01-data-raw-v2 | PASS | 2 | 2026-09-22 |
| WP02 | Data standard v0.4 | W1 | MERGED | transition/wp02-standard-v04-v1 | PASS | 1 | 2026-09-22 |
| WP03 | Pipeline scaffold | W1 | MERGED | transition/wp03-scaffold-v2 | PASS | 2 | 2026-09-22 |
| WP99 | Apply G0 answers to the contract (conditional) | W1 | TODO | — | — | 0 | — |
| WP04 | Small codelists and CL_AREA | W2 | MERGED | transition/wp04-small-codelists-v1 | PASS | 1 | 2026-09-22 |
| WP05 | Geography | W2 | MERGED | transition/wp05-geography-v1 | PASS | 1 | 2026-09-22 |
| WP06 | Breakdowns and qualifiers | W2 | MERGED | transition/wp06-breakdowns-qualifiers-v1 | PASS | 1 | 2026-09-22 |
| WP07 | Indicator dictionary | W2 | MERGED | transition/wp07-dictionary-v1 | PASS | 1 | 2026-09-22 |
| WP08 | Plans and the required-row generator | W2 | MERGED | transition/wp08-plans-v2 | PASS | 2 | 2026-09-22 |
| WP09 | Legacy maps | W2 | MERGED | transition/wp09-legacy-maps-v1 | PASS | 1 | 2026-09-22 |
| WP10 | Text, figures and surveys | W2 | MERGED | transition/wp10-content-v1 | PASS | 1 | 2026-09-22 |
| WP11 | Validator core | W3 | MERGED | transition/wp11-validator-core-v5 | PASS | 5 | 2026-09-23 |
| WP12 | Validator coverage and values | W3 | MERGED | transition/wp12-validator-coverage-v2 | PASS | 2 | 2026-09-23 |
| WP13 | Validator rules | W3 | MERGED | transition/wp13-validator-rules-v3 | PASS | 3 | 2026-09-23 |
| WP14 | Validator assets and text | W3 | MERGED | transition/wp14-validator-assets-text-v1 | PASS | 1 | 2026-09-22 |
| WP15 | Legacy converter | W3 | MERGED | transition/wp15-converter-v1 | PASS | 1 | 2026-09-22 |
| WP16 | Independent reconciliation tool | W3 | MERGED | transition/wp16-reconcile-v1 | PASS | 1 | 2026-09-22 |
| WP17 | Final audit | after W3 | MERGED | transition/wp17-final-audit-v1 | PASS | 1 | 2026-09-23 |

## Gates

| Gate | What the user decides | State | Date | Record |
|---|---|---|---|---|
| G0 | Hard cases H1–H14, H17 and key messages T1 | DONE | 2026-09-22 | reports/GATE-G0.md |
| G1 | Standard v0.4 and the contract | DONE | 2026-09-22 | reports/GATE-G1.md |
| G2 | Accept results; merge into dev/eb | DONE | 2026-09-23 | reports/GATE-G2.md |
