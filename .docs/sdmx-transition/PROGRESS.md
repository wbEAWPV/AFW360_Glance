# Progress: SDMX 3.1 transition (standard v0.6, metadata 0.3.0)

Maintained by the orchestrator only. One row per work package; states are `todo`, `in progress`, `verified`, `committed`, `blocked`, `split` (replaced by the suffixed rows under it), `skipped` (the Gate 2 alternative that does not run). Gates are `pending`, `approved`, `vetoed`. Dates are ISO.

## Environment (filled at setup)

| Tool | Version seen | Date |
|---|---|---|
| R / Rscript | | |
| xml2 | | |
| quarto | 1.10.18 | 2026-09-29 |
| Java | OpenJDK 21.0.12.1 Zulu | 2026-09-29 |
| Python (.venv) | 3.11.9 (pandas, geopandas, pytest, openpyxl; no matplotlib, no lxml) | 2026-09-29 |
| tools/verify/.venv | created in WP7 | |
| Docker | not available | 2026-09-29 |

## Work packages

| WP | Title | Depends on | State | Implementer | Verifier | Commit | Date |
|---|---|---|---|---|---|---|---|
| WP0 | Scaffolding | | todo | orchestrator | | | |
| WP1 | Standard v0.6 draft | WP0 | todo | | | | |
| WP2a | Metadata 0.3.0 inputs (alignment, artefacts, DSD rows) | WP0 | todo | | | | |
| WP2b | Metadata migration 0.2.0 to 0.3.0 (script, fixture, test) | WP2a | todo | | | | |
| WP5a1 | Vendored SDMX-ML 3.1.0 schemas | WP0 | todo | | | | |
| WP2c | Docs generator and DSD readers on the new DSD | WP2b, WP1 | todo | | | | |
| Gate 1 | Design approval (D38 to D46 as applied) | WP1, WP2c | pending | | | | |
| WP3a | Converter, I/O, manifest; data regenerated | Gate 1 | todo | | | | |
| WP3b | Reconciliation and 0.2.0 projection test | WP3a | todo | | | | |
| WP7 | Independent verification tools (pysdmx, lxml) | WP3a, WP5a1 | todo | | | | |
| WP9a | Dashboard loader | WP3a, WP2c | todo | | | | |
| WP4a | Validator: structure, context, plan, coverage | WP3b | todo | | | | |
| WP4b | Validator: codes, values, rules, metadata | WP4a | todo | | | | |
| WP5a | SDMX-ML writer: agency, concepts, codelists | WP2c, WP3a, WP5a1, WP7 | todo | | | | |
| WP5b | SDMX-ML writer: DSD, dataflow, providers, MSD, metadataflow | WP5a | todo | | | | |
| WP9b | Dashboard switch-over, Senegal | WP9a | todo | | | | |
| WP9c | Dashboard switch-over, Guinea-Bissau and About | WP9b | todo | | | | |
| WP5c | Reference metadata as SDMX-CSV; sdmx/README | WP5b | todo | | | | |
| WP6 | Reverse importer (round trip) | WP5b | todo | | | | |
| WP8a | FMR spike (no install) | WP5b | todo | | | | |
| WP5d | Validator: SDMX checks | WP5c, WP4b | todo | | | | |
| Gate 2 | FMR install decision | WP8a | pending | | | | |
| WP8b | FMR install, load, validate, round trip | Gate 2 (install), WP6 | todo | | | | |
| WP8b2 | SDMX-ML 3.0 output profile (only if FMR rejects v3_1) | WP8b | todo | | | | |
| WP8c | FMR deferred (only if Gate 2 defers) | Gate 2 (defer), WP6 | todo | | | | |
| WP10a | Standard final and conformance page | every WP that ran (WP8b or WP8c, not both) | todo | | | | |
| WP10b | Project documentation | every WP that ran (WP8b or WP8c, not both) | todo | | | | |
| WP10c | Inventory inconsistencies | every WP that ran (WP8b or WP8c, not both) | todo | | | | |
| WP11 | Final acceptance run | WP10a, WP10b, WP10c | todo | | verifier only | | |
| Gate 3 | Acceptance and merge | WP11 | pending | | | | |

## Gate reports

### Gate 1

Review questions answered by the data lead on 2026-09-29, ahead of the gate: Q1 (D38) rationale corrected, `R` kept; Q2 (D39) wording amended to optional-only, mandatory attributes never empty; Q3 (D32) exception for the `(1.0)` organisation schemes appended; Q4 (D31) `WB:AGENCIES` confirmed as a local placeholder; Q5 (2.9) units `HA`, `INDEX`, `LCU`, `COUNT` mapped, `PPP_USD` left empty, `LCU` and `XOF` both kept. The plan text carries these answers.

(gate materials per plan: diff stat, DSD CSV, ARTEFACTS.csv, ALIGNMENT.csv, the new chapter's line range; decisions D38 to D46 as applied; decision and date)

### Gate 2

### Gate 3

## Surfaced points (facts found during implementation that the standard or the plan must reflect)

| # | WP | Point | Resolved in |
|---|---|---|---|

## Plan amendments

| Date | WP | Amendment | Why |
|---|---|---|---|

## Blocked

(nothing)

## Log

| Date | Event |
|---|---|
| 2026-09-29 | Plan written and committed on branch `standard/v0.6-sdmx`. |
| 2026-09-29 | Review round 1: seven reviewers, 103 findings (8 blockers) triaged; plan, cheat-sheet, handover and this file revised; WP2, WP3, WP5a, WP8b and WP10 split; five questions for the data lead recorded in `plan.md` (Q1 to Q5). |
| 2026-09-29 | Review round 1 re-verified by four Sonnet verifiers on the revised documents: 100 accepted findings PASS, 0 FAIL; 11 consistency checks PASS. Audit reports committed in `bcd1816` and removed again; the kick-off prompt is `kickoff-prompt.md`. |
| 2026-09-29 | Data lead answered Q1 to Q5 (all as recommended); answers folded into `plan.md` and recorded under Gate 1. |
