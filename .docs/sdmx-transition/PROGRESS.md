# Progress: SDMX 3.1 transition (standard v0.6, metadata 0.3.0)

Maintained by the orchestrator only. One row per work package; states are `todo`, `in progress`, `verified`, `committed`, `blocked`. Gates are `pending`, `approved`, `vetoed`. Dates are ISO.

## Environment (filled at setup)

| Tool | Version seen | Date |
|---|---|---|
| R / Rscript | | |
| xml2 | | |
| quarto | 1.10.18 (2026-09-29) | |
| Java | OpenJDK 21.0.12.1 Zulu (2026-09-29) | |
| Python (.venv) | 3.11.9 (2026-09-29) | |
| Docker | not available (2026-09-29) | |

## Work packages

| WP | Title | Depends on | State | Implementer | Verifier | Commit | Date |
|---|---|---|---|---|---|---|---|
| WP0 | Scaffolding | | todo | orchestrator | | | |
| WP1 | Standard v0.6 draft | | todo | | | | |
| WP2 | Metadata migration 0.2.0 to 0.3.0 | | todo | | | | |
| Gate 1 | Design approval | WP1, WP2 | pending | | | | |
| WP3 | Converter, manifest, reconciliation; data regenerated | Gate 1 | todo | | | | |
| WP4a | Validator: structure, context, plan, coverage | WP3 | todo | | | | |
| WP4b | Validator: codes, values, rules, metadata | WP4a | todo | | | | |
| WP5a | SDMX-ML writer: agency, concepts, codelists | WP2 | todo | | | | |
| WP7 | Independent verification tool (pysdmx) | | todo | | | | |
| WP5b | SDMX-ML writer: DSD, dataflow, providers, MSD, metadataflow | WP5a | todo | | | | |
| WP5c | Reference metadata as SDMX-CSV | WP5b | todo | | | | |
| WP5d | Validator: SDMX checks | WP5c, WP4b | todo | | | | |
| WP6 | Reverse importer (round trip) | WP5b | todo | | | | |
| WP9a | Dashboard loader | WP3, WP2 | todo | | | | |
| WP9b | Dashboard switch-over, Senegal | WP9a | todo | | | | |
| WP9c | Dashboard switch-over, Guinea-Bissau and About | WP9b | todo | | | | |
| WP8a | FMR spike (no install) | WP5b | todo | | | | |
| Gate 2 | FMR install decision | WP8a | pending | | | | |
| WP8b | FMR install, load, validate, round trip | Gate 2, WP6 | todo | | | | |
| WP8c | FMR deferred (only if Gate 2 defers) | Gate 2 | todo | | | | |
| WP10 | Documentation finalisation | all above | todo | | | | |
| WP11 | Final acceptance run | WP10 | todo | | | | |
| Gate 3 | Acceptance and merge | WP11 | pending | | | | |

## Gate reports

### Gate 1

(what was done, what to decide, diff summary; decision and date)

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
