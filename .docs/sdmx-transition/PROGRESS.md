# Progress: SDMX 3.1 transition (standard v0.6, metadata 0.3.0)

Maintained by the orchestrator only. One row per work package; states are `todo`, `in progress`, `verified`, `committed`, `blocked`, `split` (replaced by the suffixed rows under it), `skipped` (the Gate 2 alternative that does not run). Gates are `pending`, `approved`, `vetoed`. Dates are ISO.

## Environment (filled at setup)

| Tool | Version seen | Date |
|---|---|---|
| R / Rscript | R 4.5.3 (2026-03-11 ucrt); readr 2.2.0, testthat 3.3.2, sf 1.1.1 | 2026-09-29 |
| xml2 | 1.3.8 | 2026-09-29 |
| quarto | 1.10.18 | 2026-09-29 |
| Java | OpenJDK 21.0.12.1 Zulu | 2026-09-29 |
| Python (.venv) | 3.11.9 (pandas, geopandas, pytest, openpyxl; no matplotlib, no lxml) | 2026-09-29 |
| tools/verify/.venv | created in WP7 | |
| Docker | not available | 2026-09-29 |

## Work packages

| WP | Title | Depends on | State | Implementer | Verifier | Commit | Date |
|---|---|---|---|---|---|---|---|
| WP0 | Scaffolding | | committed | orchestrator | orchestrator (WP0 check prints OK) | 883ba6b | 2026-09-29 |
| WP1 | Standard v0.6 draft | WP0 | committed | opus (162k tokens, over budget; deliverables complete, no split) | sonnet, PASS 7/7 | a9b1b09 | 2026-09-29 |
| WP2a | Metadata 0.3.0 inputs (alignment, artefacts, DSD rows) | WP0 | committed | opus (91k tokens) | sonnet, PASS 9/9 (check 6 re-run in corrected form by a second verifier, `bad 0` over 27 URNs) | df94270 | 2026-09-29 |
| WP2b | Metadata migration 0.2.0 to 0.3.0 (script, fixture, test) | WP2a | in progress | opus | | | 2026-09-29 |
| WP5a1 | Vendored SDMX-ML 3.1.0 schemas | WP0 | committed | sonnet (61k tokens) | sonnet, PASS 4/4 | 6af721e | 2026-09-29 |
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
| 1 | WP5a1 | `sdmx-twg/sdmx-ml` has no LICENSE, LICENCE or COPYING file at tag `v3.1.0` (all raw URLs 404) and its README states no licence terms; `pipeline/xsd/sdmx-ml-3.1/README.md` records the absence instead of quoting a licence. | WP10a (conformance page, XSD row) |
| 2 | WP5a1 | `.gitattributes` has no `*.xsd` rule, so with `core.autocrlf=true` the vendored XSDs get CRLF on a fresh checkout (git add warned on 5 files). Harmless for XSD parsing; a `*.xsd text eol=lf` line would keep them byte-identical to the download. | WP10c (`.gitattributes`) |
| 3 | WP2a | `ALIGNMENT.csv` semantics: an empty `name_en` or `definition_en` means keep the 0.2.0 value; added codes fill both (documented in `inputs/SOURCES.md`). `CL_AGE.Y0T14` keeps the project name "Under 15"; the plan asks only for the id rename. | WP2b (applies the rule); WP10a (2.9 text) |
| 4 | WP2a | DSD CSV conventions chosen: `relationship` is `observation` or a space-separated list of dimension ids (`COMP_BREAKDOWN_1` to `_5` and `MEASURE_QUAL_1` to `_5` written out, no "dimensions:" prefix); `data_type` empty on coded components; `min_value` 0 on `STD_ERR`, `N_OBS`, `N_POP`, `N_OBS_NUM`, `DEFF`, `DF`, `PRECISION`; `required` kept from v0.5 with `N_OBS_NUM` C, `DEFF` O, `DF` O, `FREQ` R. | WP5b (writer reads these columns); WP10a (standard documents the DSD CSV) |
| 5 | WP2a | `ARTEFACTS.csv` descriptions for `CL_BRK_VAR`, `CL_QUAL_VAR`, `CL_QUALIFIER`, `CL_STAT_UNIT`, `CL_STATISTIC`, `CL_THEME`, `CL_WEIGHT`, `CL_ESTIMATION`, `CL_GEO`, `CL_GEO_SCHEME` were written from the codelist header rows only. | Gate 1 (data lead reviews the file) |
| 6 | WP1 | SDMX-ML 3.1 `Code/@id` is `common:IDType` (pattern: letters, digits, underscore, at sign, dollar, hyphen; no dot; `SDMXCommonReferences.xsd` line 1578, reached through `ItemBaseType` in `SDMXStructureBase.xsd` line 53; confirmed by a read-only check of the vendored XSDs). 35 of the 91 distinct `series_id` values contain a dot, so D43's `CL_SERIES` (one code per `series_id`) cannot be XSD-valid as designed. Source ids contain no dot. The standard records this as open decision 12. | Gate 1 question G1-Q1 (changes D43 and 2.4 row 29) |
| 7 | WP1 | D43 says `TEXT.csv` rows are metadatasets "targeting the country code"; section 2.7 targets the dataflow `AFW360_HH` and carries the country in `TEXT.REF_AREA`. The standard follows 2.7. | Gate 1 question G1-Q2 (D43 wording) |
| 8 | WP1 | The generated `@tbl-columns` still lists the 31 old columns (with `DATAFLOW`) until WP2c regenerates it; until then the prose (37 columns, 34 components) and the rendered table disagree. | WP2c |
| 9 | WP1 | Sections outside WP1's scope may still call `STD_ERR`, `CI_LOWER`, `CI_UPPER`, `N_OBS`, `N_POP` "reliability attributes" (`sec-reliability`, `sec-legacy`, `sec-extend`, `sec-one-row`, `@tbl-extend`); D33 makes them measures. | WP10a (sweep) |
| 10 | WP1 | WP1 check 3 excludes line 1003 as the historical D11 row; that row moved and now passes because it contains "planned". The `data_raw/scratch/` listing (inventory inconsistency 3) is untouched. | WP10c (inconsistency 3) |

## Plan amendments

| Date | WP | Amendment | Why |
|---|---|---|---|
| 2026-09-29 | WP2a, WP2b | `pipeline/migrations/0.3.0/inputs/ALIGNMENT.csv` gains a sixth column `definition_en`, placed between `name_en` and `global_urn` (header `codelist,code_0_2_0,code_0_3_0,name_en,definition_en,global_urn`). Convention: an empty `name_en` or `definition_en` means keep the 0.2.0 value; an added code (today only `CL_UNIT_MEASURE.XOF`) fills both. WP2b applies the column like `name_en`. Plan section 2.9 names five columns; the WP2a checks are unchanged (they select by column name or row prefix). | Section 2.9 adds `XOF` as a new code but gives no source for its `definition_en`, and 2.10 forbids hand-typed names or descriptions in the migration script. Surfaced by the WP2a implementer. |
| 2026-09-29 | WP2a, WP5a | In WP2a check 6 and WP5a check 6 the R regexes are over-escaped: the plan text puts four backslashes before each dot, which R reads as "a literal backslash, then any character", so the WP2a check prints 27 instead of 0 and the WP5a `list.files` pattern would match no file. The intended R source has two backslashes before each dot (the usual R spelling of an escaped regex dot). Verifiers run the corrected forms; the WP2a re-run is recorded in the WP2a row. | Markdown escaping doubled the backslashes when the plan was written; found by the WP2a verifier (check 6 FAIL on the literal command, 27 non-empty URNs all well-formed). |

## Blocked

(nothing)

## Log

| Date | Event |
|---|---|
| 2026-09-29 | Plan written and committed on branch `standard/v0.6-sdmx`. |
| 2026-09-29 | Review round 1: seven reviewers, 103 findings (8 blockers) triaged; plan, cheat-sheet, handover and this file revised; WP2, WP3, WP5a, WP8b and WP10 split; five questions for the data lead recorded in `plan.md` (Q1 to Q5). |
| 2026-09-29 | Review round 1 re-verified by four Sonnet verifiers on the revised documents: 100 accepted findings PASS, 0 FAIL; 11 consistency checks PASS. Audit reports committed in `bcd1816` and removed again; the kick-off prompt is `kickoff-prompt.md`. |
| 2026-09-29 | Data lead answered Q1 to Q5 (all as recommended); answers folded into `plan.md` and recorded under Gate 1. |
| 2026-09-29 | Orchestration started (Fable session). WP0 committed (883ba6b): `tmp/`, `.gitignore`, `.gitattributes`; environment table filled. Implementer briefs are extracted verbatim from `plan.md` with `sed` into `tmp/briefs/` (gitignored) and read by each agent as its first step, so the pasted text is byte-exact. |
