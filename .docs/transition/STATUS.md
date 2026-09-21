# Transition status board

Written only by integrators, on branch `transition/main`. The copy on `dev/eb` is the initial state.

**Git is the source of truth.** This board is a readable summary. The state of a package between integrations is read from branch names and commit subjects (`WPNN: verify v1 - VERDICT: PASS`); see the resume question in `templates/scout-prompt.md`.

States: `TODO` · `MERGED` (integrated into `transition/main`) · `BLOCKED` (escalated to the user) · `SKIPPED` (WP99 when no hard case was flipped).

## Work packages

| WP | Title | Wave | State | Latest branch | Verdict | Attempts | Updated |
|---|---|---|---|---|---|---|---|
| WP00 | Setup and environment check | W0 | TODO | — | n/a | 0 | — |
| WP01 | Move legacy inputs to data_raw | W1 | TODO | — | — | 0 | — |
| WP02 | Data standard v0.4 | W1 | TODO | — | — | 0 | — |
| WP03 | Pipeline scaffold | W1 | TODO | — | — | 0 | — |
| WP99 | Apply G0 answers to the contract (conditional) | W1 | TODO | — | — | 0 | — |
| WP04 | Small codelists and CL_AREA | W2 | TODO | — | — | 0 | — |
| WP05 | Geography | W2 | TODO | — | — | 0 | — |
| WP06 | Breakdowns and qualifiers | W2 | TODO | — | — | 0 | — |
| WP07 | Indicator dictionary | W2 | TODO | — | — | 0 | — |
| WP08 | Plans and the required-row generator | W2 | TODO | — | — | 0 | — |
| WP09 | Legacy maps | W2 | TODO | — | — | 0 | — |
| WP10 | Text, figures and surveys | W2 | TODO | — | — | 0 | — |
| WP11 | Validator core | W3 | TODO | — | — | 0 | — |
| WP12 | Validator coverage and values | W3 | TODO | — | — | 0 | — |
| WP13 | Validator rules | W3 | TODO | — | — | 0 | — |
| WP14 | Validator assets and text | W3 | TODO | — | — | 0 | — |
| WP15 | Legacy converter | W3 | TODO | — | — | 0 | — |
| WP16 | Independent reconciliation tool | W3 | TODO | — | — | 0 | — |
| WP17 | Final audit | after W3 | TODO | — | — | 0 | — |

## Gates

| Gate | What the user decides | State | Date | Record |
|---|---|---|---|---|
| G0 | Hard cases H1–H14, H17 and key messages T1 | PENDING | — | — |
| G1 | Standard v0.4 and the contract | PENDING | — | — |
| G2 | Accept results; merge into dev/eb | PENDING | — | — |
