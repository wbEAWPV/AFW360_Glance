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
| WP2b | Metadata migration 0.2.0 to 0.3.0 (script, fixture, test) | WP2a | committed | opus (113k tokens, slightly over budget; deliverables complete) | sonnet, PASS 10/10 | 16d4170 | 2026-09-29 |
| WP5a1 | Vendored SDMX-ML 3.1.0 schemas | WP0 | committed | sonnet (61k tokens) | sonnet, PASS 4/4 | 6af721e | 2026-09-29 |
| WP2c | Docs generator and DSD readers on the new DSD | WP2b, WP1 | committed | opus (69k tokens) | sonnet, PASS 6/6 | 5e37861 | 2026-09-29 |
| Gate 1 | Design approval (D38 to D46 as applied) | WP1, WP2c | pending (report written, waiting for the data lead) | | | | 2026-09-29 |
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

**Gate report, 2026-09-29.** WP5a1 (6af721e), WP2a (df94270), WP1 (a9b1b09), WP2b (16d4170) and WP2c (5e37861) are committed and verified. State: `pending`. WP3a and everything after it wait for approval.

Materials:

- `git diff --stat 883ba6b..HEAD -- metadata .docs`: 32 files changed, 889 insertions, 429 deletions (22 files under `metadata/`, 5 generated tables, the standard).
- DSD CSV: `metadata/structure/DSD_AFW360_HH.csv` (34 component rows; byte copy of `pipeline/migrations/0.3.0/inputs/DSD_AFW360_HH.csv`).
- Artefact list: `metadata/structure/ARTEFACTS.csv` (33 rows; the ten descriptions of surfaced point 5 need reading).
- Alignment table: `pipeline/migrations/0.3.0/inputs/ALIGNMENT.csv` (28 rows, six columns; fetch evidence in `inputs/SOURCES.md`).
- The standard: `.docs/data-standard.qmd`, new chapter `# SDMX conformance {#sec-sdmx}` at lines 367 to 590; `# Changes since v0.5 {#sec-changes-v06}` at lines 1261 to 1291; the decisions table gained 18 rows citing D27 to D46 and a new open decision 12 (series ids and `IDType`). The regenerated component table is `.docs/generated/tbl-columns.md`.
- Decisions D38 to D46 as applied: D38 (`ACTION` = `R`) and D39 (`NaN`) are written into the standard, the data itself is regenerated in WP3a; D40 `VERSION` = 0.3.0 and the CHANGELOG entry; D41 the mapping is in the standard, the writer comes in WP5a; D42 sentinels are declared in the DSD CSV `sentinel` column; D43 the four derived codelists are rows of `ARTEFACTS.csv` (see G1-Q1); D44 `ARTEFACTS.csv` exists with 33 rows; D45 stated in the standard; D46 the DSD CSV lists the 34 components in data-file order.

The data lead decides: (1) confirm or veto each of D38 to D46; (2) read the new chapter and list any sentence that contradicts section 2 of the plan; (3) answer G1-Q1 to G1-Q3 below. Each veto or correction becomes a `<WP>-fix` row.

**Data lead, 2026-09-29:** item (1) answered: D38 to D46 all confirmed as applied. Item (2): the data lead asked for a bullet summary of the chapter with doubtful statements flagged (produced by a reviewer agent, relayed in chat) instead of reading the chapter. Items (2) and (3) pending.

Questions raised during WP1 and WP2a:



- **G1-Q1 (D43, 2.4 row 29): `CL_SERIES` cannot be XSD-valid.** SDMX-ML 3.1 `Code/@id` is `common:IDType` (letters, digits, underscore, at sign, dollar, hyphen; no dot), and 35 of the 91 `series_id` values contain a dot (surfaced point 6). Options: (A, recommended) keep `series_id` dotted everywhere in the project; in SDMX, `SERIES_ID` becomes an uncoded mandatory attribute (`TextFormat textType="String"`), `CL_SERIES` is not generated, and D43 is amended to "registries except `SERIES_PLAN`"; the validator keeps checking `SERIES_ID` against `SERIES_PLAN` as a project rule. Consequences: one row less in `ARTEFACTS.csv` (32 artefacts, 22 codelists), DSD row 29 without a codelist, the standard's D43 row and open decision 12 updated, and the plan's counts in WP2a check 4, WP4b, WP5a check 3 and WP5b check 5 become 22 and 32 (run as `WP2a-fix`, `WP2b-fix`, `WP1-fix`). (B) keep `CL_SERIES` with code ids that replace the dot by an underscore or hyphen and change the `SERIES_ID` values in the data and in `SERIES_PLAN` to match: touches data values, the projection test, the loader API and the standard's series-id convention; not recommended. (C) generate `CL_SERIES` with transformed ids while the data keeps dotted, uncoded values: a codelist nothing references; not recommended.
- **G1-Q2 (D43 wording): target of the `TEXT` metadatasets.** D43 says they target "the country code"; section 2.7 (and the standard as written) targets the dataflow `AFW360_HH` and carries the country in `TEXT.REF_AREA`, because the SDMX-CSV 2.1 metadata guide has no item-level target (surfaced point 7). Recommended: amend the D43 wording to match 2.7; no file changes.
- **G1-Q3 (review): `ARTEFACTS.csv` descriptions.** Ten codelist descriptions were written from header rows only (surfaced point 5); please read `metadata/structure/ARTEFACTS.csv` and correct any wording (a `WP2a-fix` if the inputs change).
- **G1-Q4 (plan 2.5, sentinel annotations): `GLOBAL_CODE` on sentinels without a global counterpart.** Plan 2.5 gives `CL_AGE._Z`, `CL_GEO._T` and `CL_QUALIFIER._Z` a `GLOBAL_CODE` pointing at `SDMX:CL_SEX(2.1)._Z` or `._T`, a list unrelated to theirs (chapter line 484). The reviewer calls this semantically odd. Recommended: drop those three annotations, keep the five whose own global list has the sentinel; WP5a checks 4 and 6 then count 5 sentinel `GLOBAL_CODE`s instead of 8. Not a D-level decision (D42 covers the codes, not the annotation).

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
| 11 | WP2b | `COLUMNS.csv` descriptions for the eight new DSD columns, the nine `ARTEFACTS.csv` columns and `global_urn` were written by the implementer (`inputs/COLUMNS_0.3.0.csv`); the old DSD rows were corrected (position range 1 to 34, role list without "constant"). Statuses chosen: `data_type`, `usage`, `relationship` C; `measure_relationship`, `min_value`, `max_value`, `global_urn` O. | Gate 1 (review); WP10a (standard's metadata-file section) |
| 12 | WP2b | Migration choices the plan leaves open: `COLUMNS.csv` order puts the `CL_FREQ` block before `CL_SEX` and the `ARTEFACTS.csv` block after the `COLUMNS.csv` rows; `XOF` is appended as the last row of `CL_UNIT_MEASURE.csv` with status `DRAFT` and `version_added` 0.3.0; a code rename also rewrites `parent` and `replaced_by` references in the same list (none exist today); the `CL_FREQ` rows of `ALIGNMENT.csv` are checked against `inputs/CL_FREQ.csv`, not applied; the CHANGELOG heading is `## 0.3.0 (unreleased)`. | WP10a (2.10 text in the standard) |
| 13 | WP2b | `.gitattributes` gives the fixture copies of `VERSION` (`pipeline/tests/testthat/fixtures/metadata-0.*/metadata/VERSION`, no extension) no `eol` rule, so a fresh checkout with `core.autocrlf=true` may write them with CRLF; the migration trims the value and rewrites the file, so the tests still pass, but WP2b check 1 (`cmp` against the blob) would fail on such a checkout. A rule `VERSION text eol=lf` (basename pattern) covers all copies. | WP10c (`.gitattributes`) |
| 14 | WP1 | Chapter review at Gate 1 (Opus reviewer, relayed to the data lead): the chapter matches plan section 2 in every count, id, URN form and table. Wording to fix, no decision changes: line 589 states the SDMX-ML 3.0 profile as an existing capability (it is the WP8b2 contingency); line 549 "SDMX cannot express required coverage or arithmetic rules" overstates (VTL and DataConstraint exist; say the project validator keeps that job and neither is used in this release, as D45 does); "FMR 12" (line 582) versus "FMR 12.4" (line 589); "37 columns, in DSD order" (line 405) versus `Pos` being CSV order only (line 451); the `MDS_TEXT.csv` source `content/TEXT.csv` is never named (lines 508 and 514); line 570 "a pull request fails the check" must match how the staleness check is actually run. Line 486 ("real codelists for `SERIES_ID` and `SOURCE_ID`") depends on G1-Q1. | WP10a |
| 15 | WP1 | Plan 2.6 and the chapter (line 494) annotate `INDICATOR` with `SDMX_CROSS_DOMAIN_CONCEPT`; the reviewer doubts that `INDICATOR` exists in `SDMX:CROSS_DOMAIN_CONCEPTS(2.0)`. WP5a fetches the scheme once (2.9 curl form) and writes the annotation only for ids that exist, reporting any dropped id. | WP5a (check), WP10a (text) |

## Plan amendments

| Date | WP | Amendment | Why |
|---|---|---|---|
| 2026-09-29 | WP2a, WP2b | `pipeline/migrations/0.3.0/inputs/ALIGNMENT.csv` gains a sixth column `definition_en`, placed between `name_en` and `global_urn` (header `codelist,code_0_2_0,code_0_3_0,name_en,definition_en,global_urn`). Convention: an empty `name_en` or `definition_en` means keep the 0.2.0 value; an added code (today only `CL_UNIT_MEASURE.XOF`) fills both. WP2b applies the column like `name_en`. Plan section 2.9 names five columns; the WP2a checks are unchanged (they select by column name or row prefix). | Section 2.9 adds `XOF` as a new code but gives no source for its `definition_en`, and 2.10 forbids hand-typed names or descriptions in the migration script. Surfaced by the WP2a implementer. |
| 2026-09-29 | WP2a, WP5a | In WP2a check 6 and WP5a check 6 the R regexes are over-escaped: the plan text puts four backslashes before each dot, which R reads as "a literal backslash, then any character", so the WP2a check prints 27 instead of 0 and the WP5a `list.files` pattern would match no file. The intended R source has two backslashes before each dot (the usual R spelling of an escaped regex dot). Verifiers run the corrected forms; the WP2a re-run is recorded in the WP2a row. | Markdown escaping doubled the backslashes when the plan was written; found by the WP2a verifier (check 6 FAIL on the literal command, 27 non-empty URNs all well-formed). |
| 2026-09-29 | WP2b | `pipeline/migrations/0.3.0/inputs/` gains two authored files: `COLUMNS_0.3.0.csv` (the `COLUMNS.csv` rows for the rewritten DSD file, `ARTEFACTS.csv` and `CL_FREQ.csv`; its `CL_FREQ` `global_urn` row is the template for the other 18 codelists) and `CHANGELOG_0.3.0.md` (the 0.3.0 entry, one line per decision D27 to D46). The migration copies or applies them. WP2a check 1 (exactly five files) described the state at the WP2a commit; the final folder holds seven files. The `notes` cell of the `CL_UNIT_MEASURE` row of `ARTEFACTS.csv` was reworded so the old list name does not appear (WP2b check 6 forbids the whole word anywhere under `metadata/`, while check 3 requires the file to be a byte copy of the input). | 2.10 item 3 asks for new `COLUMNS.csv` rows and item 6 for a CHANGELOG entry but gives no source for their text, and 2.10 forbids hand-typed text in the script. Surfaced by the WP2b implementer. |

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
| 2026-09-29 | WP5a1, WP2a, WP1, WP2b, WP2c verified and committed (6af721e, df94270, a9b1b09, 16d4170, 5e37861). Three plan amendments and 13 surfaced points recorded. Gate 1 report written; three questions (G1-Q1 series ids versus `IDType`, G1-Q2 D43 wording, G1-Q3 artefact descriptions) put to the data lead. Waiting. |
