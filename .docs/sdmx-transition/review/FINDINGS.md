# Review round 1: findings, decisions, resolutions

Lead: Claude Fable 5.1, 2026-09-29. Reviewers: R-A (SDMX-ML, Opus), R-B (SDMX-CSV, Opus), R-C (registry, Opus), R-D (repository fit, Opus), R-E (WP0 to Gate 1, Opus), R-F (WP3 to Gate 3, Opus), R-G (consistency, Sonnet). Reports in this folder. This folder is working material for the review and is removed before the commit (data lead's instruction); the questions live in `plan.md` as `> REVIEW QUESTION` notes.

Counts by reviewer (blocker / major / minor): R-A 0/3/4, R-B 1/4/7, R-C 0/4/5, R-D 0/5/9, R-E 3/12/6, R-F 4/15/10, R-G 0/1/10. Total 8 blockers, 44 major, 51 minor (103 findings).

Decisions: `accept` (fixed in the documents), `reject` (with reason), `question` (Q<n> for the data lead; plan text unchanged at that spot, `> REVIEW QUESTION Q<n>` note added).

Disagreements settled by the lead:

- `global_urn` position (R-C-7 says last column; R-D-2 and R-E-7 say column 8 after `notes`): settled as the last column of every codelist. No renumbering of the ten codelists that have columns after `notes`, and the check reduces to `grep -q ',global_urn$'`. Plan 2.10 item 3 and WP2b check 4 say so.
- WP7 model (R-E-21 says Opus; R-F-21 says Sonnet): Opus. WP7 ships the three tools (`verify_sdmx.py`, `xsd_validate.py`, `check_urns.py`) that later verifications rely on; a Sonnet verifier checks it.
- Metadata targets (R-A-2 gives explicit codelist and dataflow URNs for the Metadataflow; R-B-2 proves SDMX-CSV 2.1 metadata targets are whole artefacts): both accepted together. Metadataflow targets `CL_SURVEY`, `CL_SOURCE`, `CL_FIGURE` and `AFW360_HH`; metadatasets target those four artefacts; no `CL_AREA` target.
- R-G-1 (`SN01` in the sample row): rejected. `SN01` is a real `CL_GEO` code (`metadata/codelists/CL_GEO.csv` row 3, Dakar, ADM1). The `<ref_area>_<code>` pattern in 2.5 applies to `CL_GEO_SCHEME`, not `CL_GEO`. A clarifying sentence was added to 2.3.

## Findings table

| Id | Sev | Section | Claim (one line) | Decision | Resolution (where in the revised documents) |
|---|---|---|---|---|---|
| R-A-1 | major | cheatsheet 3, 11; plan 2.8 | Semver dependency rule is IM prose; PA/MPA must reference fixed-version `(1.0)` provider schemes | accept | plan 2.1 bullet "Semver dependency rule"; plan 2.8 last sentence; cheatsheet 3 Version row; cheatsheet 11 last bullet; Q3 |
| R-A-2 | major | plan 2.7; cheatsheet 10 | Metadataflow `Target` is `WildcardUrnType`, 1..n; use explicit URNs | accept | plan 2.7 Metadataflow bullet (four explicit targets); cheatsheet 10 four `<str:Target>` lines, no UNCERTAIN |
| R-A-3 | major | plan 2.7 | Presentational parents also need `minOccurs="0"` | accept | plan 2.7 MSD bullet |
| R-A-4 | minor | plan 2.4; cheatsheet 13 | XML order is AttributeList before MeasureList | accept | plan 2.4 paragraph after the table; cheatsheet 13 first bullet |
| R-A-5 | minor | plan 2.6 | No core representation for `TIME_PERIOD` | accept | plan 2.6 last sentence |
| R-A-6 | minor | plan 2.5 | Sentinel `GLOBAL_CODE` uses short form | accept | merged into R-C-2 |
| R-A-7 | minor | plan 2.1 | `WB:AGENCIES` may collide with a real WB scheme | accept | plan 2.1 second bullet; Q4 |
| R-B-1 | blocker | plan 2.7, 2.12, WP7, row 8, risk 3 | pysdmx 1.20.0 cannot read SDMX-CSV metadata messages | accept | plan 2.7 last bullet; 2.12 "Independent reader"; WP7 deliverables; section 6 row 8; section 5 row 3 |
| R-B-2 | major | plan 2.7; cheatsheet 14 | Item-level targets do not exist in SDMX-CSV 2.1 | accept | plan 2.7 metadataset bullets; cheatsheet 14 Row example and "Targets are whole artefacts" |
| R-B-3 | major | plan D38 | D38 rationale misstates `R` semantics; `A` also deprecated | question | Q1 note after the decisions table; semantics stated in plan 2.3 rule on `ACTION` |
| R-B-4 | major | plan 2.3, 2.4 | Partial-key attributes need one value per partial key | accept | plan 2.3 rule "Attributes attached to partial keys"; WP4a deliverable `STRUCT.ATTR_LEVEL` |
| R-B-5 | major | plan 2.12, WP7 | Pin must be `pysdmx[data,xml]==1.20.0` | accept | plan 2.12; WP7 deliverables |
| R-B-6 | minor | plan D39, 2.3 | `NaN` is for float/double only; mandatory attributes never empty | question | Q2 note; plan 2.3 rule "Mandatory attributes" |
| R-B-7 | minor | plan 2.3 | CRLF/BOM statement unsupported; `na = ""` needed | accept | plan 2.3 RFC 4180 rule |
| R-B-8 | minor | cheatsheet 13 | `STRUCTURE[;]` condition incomplete; "DSD order" ambiguous | accept | cheatsheet 13 first bullet |
| R-B-9 | minor | WP3 verification | `$36` is `SOURCE_ID`; `OBS_STATUS` is field 35 | accept | WP3a check 4 uses `$35` and `$23` |
| R-B-10 | minor | plan 2.7; cheatsheet 14 | Quote all textual values in metadata messages | accept | plan 2.7 `quote = "all"` sentence; cheatsheet 14 last bullet |
| R-B-11 | minor | section 6 row 7 | pysdmx maps empty cells to `NaN` | accept | section 6 row 7 evidence |
| R-B-12 | minor | plan 2.7 | Presentational parents have no column | accept | plan 2.7 metadata-message bullet |
| R-C-1 | major | plan 2.9 | `WB:CL_REF_AREA_WDI(1.0)` lives at the WB DDP service | accept | plan 2.9 CL_AREA row |
| R-C-2 | major | plan 2.5 | Sentinel `GLOBAL_CODE` must be full URNs to each list's own `_T` | accept | plan 2.5 Sentinels bullet |
| R-C-3 | minor | plan 2.9, section 5 | CL_AGE settled: only `Y_LT15` renames to `Y0T14` | accept | plan 2.9 CL_AGE row; section 5 row removed |
| R-C-4 | minor | plan 2.9 | Exact unit matches HA, IX, CUR_LCU, NUMBER; no XOF globally | accept | plan 2.9 CL_UNIT_MEASURE row; Q5 |
| R-C-5 | minor | plan 2.9 | OBS_STATUS global names | accept | plan 2.9 CL_OBS_STATUS row |
| R-C-6 | major | plan D31, 2.1 | Shipping `WB:AGENCIES` asserts the WB namespace | accept | plan 2.1 second bullet; Q4 (D31 unchanged) |
| R-C-7 | major | plan 2.10 item 3; WP2 check | `global_urn` "after notes" contradicts "ends with" | accept | settled as last column: plan 2.10 item 3; WP2b check 4 |
| R-C-8 | minor | plan 2.9 | Record why `CL_DEG_URB` was rejected | accept | plan 2.9 CL_URBANISATION row |
| R-C-9 | minor | research/R3 | R3 wrongly says `SDMX:CL_SEX` lacks `_Z` | reject | research files are a frozen record; the plan already uses `SDMX:CL_SEX(2.1)` correctly |
| R-D-1 | major | WP2 context | `docs.R:26-35` and `test-docs.R` outside context | accept | WP2c context and deliverables |
| R-D-2 | major | plan 2.10 item 3 | `global_urn` position contradiction | accept | see R-C-7 |
| R-D-3 | major | plan 2.11 | Test-line count and file list understated | accept | plan 2.11 test sentence |
| R-D-4 | major | plan 2.11 | `CL_UNIT` references and `dsd_columns` call sites missing | accept | plan 2.11 appended sentence |
| R-D-5 | minor | plan 2.10 item 5 | `RULES.csv`, `SERIES_PLAN.csv` have no `CL_UNIT` reference | accept | plan 2.10 item 5 |
| R-D-6 | minor | plan 2.10 | Never says every `CL_*.csv` gains `global_urn` | accept | plan 2.10 item 3 |
| R-D-7 | minor | plan 2.10, WP2 | Fixture path ambiguous | accept | plan 2.10 closing paragraph; WP2b deliverable 1 |
| R-D-8 | major | plan 2.14, WP9a, WP9b | No `requirements.txt`; `.venv` lacks matplotlib | accept | plan 2.14 last sentence; WP9a deliverables and checks |
| R-D-9 | minor | WP9c | GNB map is new | accept | WP9c deliverables |
| R-D-10 | minor | WP9c | About page reads the SEN text | accept | WP9c deliverables |
| R-D-11 | minor | plan 2.2 | New paths unmarked | accept | plan 2.2 sentence under the tree |
| R-D-12 | minor | WP3, WP9b context | Ranges off | accept | WP3a context (`convert_tables.R` 381-575); WP9b context (1-183, 184-719) |
| R-D-13 | minor | plan 2.11 | Line cites off by one | accept | plan 2.11 |
| R-D-14 | minor | WP1, WP10 | R4 inconsistencies 3, 6, 13-17 unassigned | accept | WP10c deliverables |
| R-E-1 | major | WP0; handover | Branch exists, so WP0 is skipped | accept | WP0 first bullet and check; handover Setup item 1 |
| R-E-2 | blocker | WP2 | `test-docs` outside context | accept | WP2c |
| R-E-3 | major | WP2 context | `docs.R` names `CL_UNIT` outside the range | accept | WP2c context (`docs.R` 20-70) |
| R-E-4 | blocker | WP2, 2.10 | Artefact list and decisions not pasted | accept | plan 2.10 item 2 lists the 33 rows and `artefact_type` values; WP2a pastes section 1 |
| R-E-5 | blocker | WP2 | Breaks rules 2 and 5 | accept | split into WP2a, WP2b, WP2c |
| R-E-6 | major | WP2 | Fixture layout and `--out-root` convention | accept | plan 2.10 closing paragraph; WP2b deliverables 1, 2; check 1 |
| R-E-7 | major | 2.10, WP2 check | "ends with" contradiction | accept | see R-C-7; WP2b check 4 |
| R-E-8 | major | WP2 check | COLUMNS check not objective | accept | WP2b check 5 |
| R-E-9 | major | WP2 check | "failures attributable to" is a judgement | accept | WP2b check 9 |
| R-E-10 | minor | WP2 checks | Three checks need the plan | accept | WP2a check 5; ARTEFACTS count 33; WP2b check 8 |
| R-E-11 | minor | 2.10 item 5 | Same as R-D-5 | accept | merged |
| R-E-12 | major | plan 2.9 | Alignment must be embedded, not fetched at run time | accept | plan 2.9 paragraph after the table; WP2a |
| R-E-13 | minor | plan 2.5, 2.9 | Two URN forms | accept | merged into R-C-2; plan 2.9 "Every `global_urn` is a full code URN" |
| R-E-14 | major | WP1 check 3 | Layout grep vacuous | accept | WP1 check 3; deliverable 6 |
| R-E-15 | major | WP1 | "31 columns" also at lines 574, 847 | accept | WP1 deliverable 2; check 4 |
| R-E-16 | major | WP1 checks | Alternation greps; bullet 6 a judgement | accept | WP1 checks 1, 2; reading moved to Gate 1 |
| R-E-17 | major | WP1, WP2 parallel | Not independent in one tree | accept | WP1 parallel with WP2a, WP2b only; WP2c after WP1; WP1 constraint "Add no new include" |
| R-E-18 | minor | WP1 context | R4 section 9 unlisted; `fmr-guide.qmd` absent | accept | WP1 context; deliverable 1 |
| R-E-19 | major | Gate 1 | No materials, no veto procedure | accept | Gate 1 rewritten; handover Gates |
| R-E-20 | minor | preamble | `verify_sdmx.py` names no interpreter | accept | preamble baseline line |
| R-E-21 | minor | handover | No verifier budget, split rule, WP7 model | accept | handover "Context budget" (verifiers 60k) and "Recording a split"; WP7 Opus |
| R-F-1 | blocker | WP11 | `git worktree add` fails on a checked-out branch | accept | WP11 step 1 |
| R-F-2 | blocker | WP5c, WP7, rows 8, 12 | pysdmx cannot read metadata CSV | accept | merged into R-B-1; WP5c check 4; WP7 |
| R-F-3 | blocker | WP5a, WP5b, WP5c | lxml checks need WP7's venv | accept | WP5a depends on WP7; `xsd_validate.py` in WP7 |
| R-F-4 | blocker | WP7 | Needs the 37-column files | accept | WP7 depends on WP3a and WP5a1 |
| R-F-5 | major | WP3 | 11 files, mixed concerns | accept | split into WP3a, WP3b |
| R-F-6 | major | WP3 checks | Header not pasted; no grep pattern; `$36` | accept | WP3a checks 1, 4, 5; WP3b check 1 |
| R-F-7 | major | preamble | Baseline "from WP3 on" contradicts WP3/WP4a | accept | preamble "from WP4b on" |
| R-F-8 | major | WP5a | 35 files, 11 checks | accept | WP5a1 split out; `sdmx/README.md` moved to WP5c; generated files excluded from the output budget |
| R-F-9 | major | WP5a | Reads `io.R` ranges WP3 rewrites | accept | WP5a depends on WP3a; context by function-signature grep |
| R-F-10 | major | WP5b check | URN check asks the verifier to write code | accept | `check_urns.py` in WP7; WP5b check 6 |
| R-F-11 | major | WP5d | Not self-contained; `touch` cannot trigger STALE | accept | WP5d context, check 2, note on the standard |
| R-F-12 | major | WP6 | `--out-root` missing; COLUMNS not in context | accept | WP6 deliverables, context, check 3 |
| R-F-13 | major | WP9a | Excel re-implementation; wrong folder; no requirements file | accept | WP9a named pairs, `afw360/tests/test_loader.py`, root `requirements.txt` |
| R-F-14 | major | WP9b | `read_html` needs lxml; checks not objective | accept | WP9b `tools/dashboard_numbers.py`, detached-worktree baseline, named values |
| R-F-15 | major | WP9c | Values unnamed; fiscal card unchecked | accept | WP9c checks 3 to 5 |
| R-F-16 | major | WP8b, WP8c | No context; contingency mixed in | accept | WP8b context; WP8b2 new; WP8c depends-on and context |
| R-F-17 | major | WP10 | 12+ files, three concerns | accept | split into WP10a, WP10b, WP10c |
| R-F-18 | major | WP4a, WP4b | Tests outside context; faults not isolated | accept | WP4a context, check 3 (`STRUCT.ACTION`); WP4b context, check 3 |
| R-F-19 | major | handover | No split procedure; no verifier-only protocol | accept | handover "Recording a split", "Verifier-only WPs"; PROGRESS state `split` |
| R-F-20 | major | section 4, PROGRESS | Dependencies disagree | accept | section 4 rewritten; every "Depends on" line and the PROGRESS table match it |
| R-F-21 | minor | WP7 heading | "Sonnet or Opus" | accept | WP7 is Opus |
| R-F-22 | minor | preamble | Helper ownership unstated | accept | preamble: only WP3a edits `helper-*.R` |
| R-F-23 | minor | WP9a | Test in WP7's folder | accept | merged into R-F-13 |
| R-F-24 | minor | section 5 | Rows name no WP; pysdmx row wrong | accept | section 5 rewritten |
| R-F-25 | major | section 6 | Rows 2, 8, 9 without evidence | accept | `SDMX.IDENT` (WP5d); row 8 header check (WP7, WP5c); row 9 count (WP5a check 6); row 7 CRLF/UTF-8 (WP3a check 6); row 14 loop (WP10a) |
| R-F-26 | minor | PROGRESS env table | Dates in the wrong column; lxml missing | accept | PROGRESS environment table |
| R-F-27 | minor | PROGRESS table | Mismatches; split rows | accept | PROGRESS table rewritten |
| R-F-28 | minor | WP5c context | Paths lack `metadata/` | accept | WP5c context |
| R-F-29 | minor | WP10 context | Implementer reads PROGRESS.md | accept | WP10a context: orchestrator pastes the table |
| R-G-1 | major | plan 2.3 | `SN01` does not match the `CL_GEO_SCHEME` pattern | reject | `SN01` is a `CL_GEO` code (Dakar); 2.3 gained a clarifying sentence |
| R-G-2 | minor | D35 | "FMR 12" versus "FMR 12.4" | reject | decision row; "FMR 12" is the major version, not wrong |
| R-G-3 | minor | plan 2.2 | `afw360/format.py` missing | accept | plan 2.2 |
| R-G-4 | minor | plan 2.2 | `migrations/0.3.0/README.md` missing | accept | plan 2.2 |
| R-G-5 | minor | PROGRESS | WP3 depends-on omits WP2 | accept | superseded by the rewritten table |
| R-G-6 | minor | PROGRESS | WP5a depends-on omits WP0 | accept | superseded by the rewritten table |
| R-G-7 | minor | WP8c | No "Depends on" line | accept | WP8c |
| R-G-8 | minor | plan | Bare WP4/WP5/WP9 shorthand | accept | spelled out |
| R-G-9 | minor | plan 2.7 | `MDS_SOURCES`/`MDS_FIGURES` id patterns missing | accept | plan 2.7 |
| R-G-10 | minor | PROGRESS | WP10 wording | accept | superseded by the rewritten table |
| R-G-11 | minor | PROGRESS | WP7 blank cell | accept | superseded by the rewritten table |

## Questions for the data lead (also in plan.md as `> REVIEW QUESTION` notes)

| Q | Decision | Question | Recommended answer |
|---|---|---|---|
| Q1 | D38 | The rationale says a published file "is the complete replacement of that slice" and that only `I` is deprecated. The SDMX-CSV 2.1 guide says `R` replaces whole observations and "cannot be used to replace a whole dataset or a whole series"; `A` is also deprecated. Keep `R` and correct the rationale? | Yes. Keep `R`; replace the rationale with the wording in the Q1 note. |
| Q2 | D39 | The decision lets "any other measure or attribute" be empty, but `SERIES_ID`, `UNIT_MEASURE`, `OBS_STATUS`, `SOURCE_ID` are required on every row, and the guide reserves `NaN` for float/double (`#N/A` otherwise). Amend the wording? | Yes: "Any optional measure or attribute ... is left empty. Mandatory attributes are never empty." |
| Q3 | D32 | The semver rule is IM prose, and the XSD forces the PA and MPA to reference `DATA_PROVIDERS(1.0)` and `METADATA_PROVIDERS(1.0)`. Append the exception to the rationale? | Yes; the decision itself stands. |
| Q4 | D31 | `WB:AGENCIES` is now described in 2.1 as a local placeholder never submitted to a registry. Confirm? | Confirm; D31 unchanged. |
| Q5 | 2.9 (Gate 1) | Unit mapping HA, IX, CUR_LCU, NUMBER; `PPP_USD` versus `CON_PPP_USD`; keep both `LCU` and `XOF`? | Map the four; leave `PPP_USD` empty unless the unit is constant-price; keep both. |

## Observations (no plan change)

- `data/AFW360_HH_GNB_2021_SURVEY.csv` holds `700000.0000000001` for `POV_NUM.POVLINE_PL300.PPP_2021` at `GEO=_T`, a floating-point artefact already in the committed data. WP3b's projection test compares numbers, so it passes; the WP9c check uses the `$4.20` count (1090000) and the headcount rate.
