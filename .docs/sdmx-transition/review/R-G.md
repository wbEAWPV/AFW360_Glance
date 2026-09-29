# Review R-G: consistency sweep (plan.md, sdmx-ml-cheatsheet.md, handover.md, PROGRESS.md)

### R-G-1
Severity: major
Where: plan.md section 2.3, line 113 (sample data row), vs section 2.5, line 185
Claim: The sample data row's `GEO` value (`SN01`) does not follow the code-id pattern that section 2.5 defines for `CL_GEO_SCHEME`, and is not the documented `_T` sentinel either, even though the row's other breakdown dimensions (`SEX=_Z`, `AGE=_Z`, `URBANISATION=_T`, `COMP_BREAKDOWN_1..5=_T`, `MEASURE_QUAL_1..5=_Z`) show this is a national-total observation with no sub-national breakdown.
Evidence: plan.md:185 "`CL_GEO_SCHEME.csv` is keyed by `ref_area` + `code`; the SDMX code id is `<ref_area>_<code>` (for example `SEN_ADM1`)"; plan.md:138 "`GEO | dimension | breakdown | CL_GEO | ... | _T`" (sentinel `_T` = Total); plan.md:113 sample row has `GEO=SN01`, which matches neither `SEN_ADM1`-style ids nor `_T`. `grep -n "SN01" plan.md` shows this value occurs nowhere else in the plan.
Fix: Either change the sample row's `GEO` value to `_T` (if this is meant to be a national aggregate with no geographic breakdown), or to a correctly-formed code such as `SEN_ADM1`/`SEN_NAT` if a real sub-national or national-pseudo code is intended, and state which. This example is copied verbatim into `.docs/data-standard.qmd` by WP1 item 1 ("the SDMX-CSV data message (2.3, with the header example)"), so the error would propagate into the published standard.

### R-G-2
Severity: minor
Where: plan.md section 1, line 41 (D35), vs lines 259, 269, 534, 620, 653
Claim: D35 states the FMR version as "FMR 12" while every other mention in the plan (2.12 line 259, 2.13 line 269, WP8a line 534, risk table line 620, Appendix A line 653) says "FMR 12.4" or "FMR 12.4.2".
Evidence: plan.md:41 "Tomcat 10.1 plus the FMR 12 WAR ... FMR 12 needs Tomcat 10.1+"; plan.md:259 "FMR 12.4 WAR"; plan.md:653 "FMR 12.4.2 (Tomcat 10.1+, Java 21)".
Fix: In D35 (line 41), change both occurrences of "FMR 12" to "FMR 12.4" to match the rest of the document.

### R-G-3
Severity: minor
Where: plan.md section 2.2, line 92 vs WP9a deliverables, line 498
Claim: Section 2.2's repository-layout tree lists only `afw360/__init__.py` and `afw360/loader.py`, but WP9a's deliverables also create `afw360/format.py`, which is absent from the 2.2 listing.
Evidence: plan.md:91-92 "afw360/ Python package for the dashboard loader (D37)\n  __init__.py  loader.py"; plan.md:498 "Deliverables: `afw360/__init__.py`, `afw360/loader.py` ..., `afw360/format.py` (`format_value(value, display_as, decimals)`) ...".
Fix: In line 92, change "`__init__.py  loader.py`" to "`__init__.py  loader.py  format.py`".

### R-G-4
Severity: minor
Where: plan.md section 2.2, line 88 vs WP2 deliverable 2, line 332
Claim: Section 2.2 lists only `migrations/0.3.0/migrate.R`, but WP2 deliverable 2 also creates a `README.md` in that same folder, which 2.2 omits.
Evidence: plan.md:88 "migrations/0.3.0/migrate.R           0.2.0 -> 0.3.0"; plan.md:332 "`pipeline/migrations/0.3.0/migrate.R` and `README.md` implementing 2.10 items 1 to 6 ...".
Fix: Change line 88 to "migrations/0.3.0/migrate.R, README.md      0.2.0 -> 0.3.0" (or add a second line for the README).

### R-G-5
Severity: minor
Where: PROGRESS.md line 24 (WP3 row) vs plan.md line 360
Claim: PROGRESS.md's "Depends on" column for WP3 shows only "Gate 1", omitting WP2, which plan.md states as an explicit dependency.
Evidence: plan.md:360 "Depends on: WP2, Gate 1."; PROGRESS.md:24 "| WP3 | Converter, manifest, reconciliation; data regenerated | Gate 1 | todo | | | | |". (Not a functional blocker: Gate 1 itself depends on WP1 and WP2 per PROGRESS.md line 23, so the chain is preserved transitively, but the stated rule in the review brief is to list literal differences.)
Fix: Change PROGRESS.md line 24's Depends-on cell from "Gate 1" to "WP2, Gate 1".

### R-G-6
Severity: minor
Where: PROGRESS.md line 27 (WP5a row) vs plan.md line 413
Claim: PROGRESS.md's "Depends on" for WP5a shows only "WP2", omitting WP0, which plan.md states explicitly.
Evidence: plan.md:413 "Depends on: WP2 (metadata), WP0 (xml2). Parallel with WP4a/b, WP7, WP9a (disjoint files)."; PROGRESS.md:27 "| WP5a | ... | WP2 | todo | | | | |".
Fix: Change PROGRESS.md line 27's Depends-on cell from "WP2" to "WP2, WP0".

### R-G-7
Severity: minor
Where: plan.md section 3, line 554 (WP8c heading) vs PROGRESS.md line 39
Claim: Every other WP in plan.md section 3 has an explicit "Depends on:" line directly under its heading; WP8c (line 554) has none — its dependency on Gate 2 is only implied by its subtitle "(Opus, only if Gate 2 defers)". PROGRESS.md nonetheless states "Gate 2" as WP8c's dependency, which cannot be checked against an explicit plan.md statement.
Evidence: `grep -n "^### WP\|^Depends on:" plan.md` shows a "Depends on:" line following every WP heading except WP8c's (line 554, next content line 556 "Deliverables:"); PROGRESS.md:39 "| WP8c | FMR deferred (only if Gate 2 defers) | Gate 2 | todo | | | | |".
Fix: Add "Depends on: Gate 2 (only if deferred)." after the WP8c heading in plan.md, for consistency with every other WP section.

### R-G-8
Severity: minor
Where: plan.md lines 283, 338, 494, 530 (baseline-check text, constraints, "Parallel with" notes)
Claim: The plan uses bare "WP4", "WP5", "WP9" as informal shorthand for the WP4a/b, WP5a/b/c/d and WP9a/b/c groups, but no "### WP4", "### WP5" or "### WP9" heading exists — only the lettered ones do.
Evidence: `grep -n "^### WP" plan.md` lists only lettered headings (WP4a, WP4b, WP5a, WP5b, WP5c, WP5d, WP9a, WP9b, WP9c) and never bare WP4/WP5/WP9; yet plan.md:283 says "From WP5 on also ...", plan.md:338 says "do not edit ... (WP3, WP4)", plan.md:494 says "Parallel with WP5", plan.md:530 says "Runs in parallel with WP6, WP9".
Fix: No functional error (context makes the group reference clear), but for an implementer scanning literally for "WP4"/"WP5"/"WP9" as an id, consider spelling out the members once, e.g. "From WP5 (5a-5d) on also ...".

### R-G-9
Severity: minor
Where: plan.md section 2.7, lines 206 and 208, vs lines 205 and 207
Claim: The per-row `METADATASET_ID` naming pattern is spelled out for `MDS_SURVEYS.csv` (`WB.AFW360:MDS_SURVEY_<survey_id>`) and `MDS_TEXT.csv` (`MDS_TEXT_<slot>_<ref_area>_<time_period>_<order>`), but not for `MDS_SOURCES.csv` or `MDS_FIGURES.csv`, which only state the target ("target `CL_SOURCE` code" / "target `CL_FIGURE` code") without an id pattern.
Evidence: plan.md:205 "`MDS_SURVEYS.csv`: `METADATASET_ID` = `WB.AFW360:MDS_SURVEY_<survey_id>`; target the code ..."; plan.md:206 "`MDS_SOURCES.csv`: target `CL_SOURCE` code." (no id pattern given); plan.md:208 "`MDS_FIGURES.csv`: target `CL_FIGURE` code." (no id pattern given).
Fix: Add explicit `METADATASET_ID` patterns for `MDS_SOURCES.csv` (e.g. `WB.AFW360:MDS_SOURCE_<source_id>`) and `MDS_FIGURES.csv` (e.g. `WB.AFW360:MDS_FIGURE_<figure_id>`), matching the style used for SURVEYS and TEXT.

### R-G-10
Severity: minor
Where: PROGRESS.md line 40 (WP10 row) vs plan.md line 564
Claim: Plan.md states WP10's dependency as "everything except WP11"; PROGRESS.md's table instead says "all above". These are consistent in effect only because WP11 is listed below WP10 in the same table (so "all above" excludes it), but the wording differs and is not self-evidently equivalent to a reader checking the two documents side by side.
Evidence: plan.md:564 "Depends on: everything except WP11."; PROGRESS.md:40 "| WP10 | Documentation finalisation | all above | todo | | | | |".
Fix: Change PROGRESS.md line 40's Depends-on cell to "everything except WP11" to match plan.md's wording exactly, removing any ambiguity.

### R-G-11
Severity: minor
Where: PROGRESS.md line 28 (WP7 row) vs plan.md line 434
Claim: Plan.md states WP7's dependency as "nothing (runs on whatever files exist)"; PROGRESS.md leaves the Depends-on cell blank. Same effective meaning, different representation from the "no dependency" cells for WP0/WP1/WP2 (also blank), so the convention is at least applied consistently within PROGRESS.md itself, but does not literally match plan.md's wording.
Evidence: plan.md:434 "Depends on: nothing (runs on whatever files exist). Parallel with WP5a."; PROGRESS.md:28 "| WP7 | Independent verification tool (pysdmx) | | todo | | | | |".
Fix: No change required; noted only because the review brief calls this comparison out explicitly. If precision is wanted, PROGRESS.md could use a literal "—" or "(none)" instead of an empty cell to distinguish "not yet filled in" from "no dependency", but this is cosmetic.

## Verified OK

- Numeric consistency: 37 columns / 19-column key (D46, lines 52, 121, 301, 367, 375, 383) all agree; 18 dimensions + 1 time + 9 measures (D33) + 6 attributes = 34 DSD rows (lines 121, 161, 232, 343, 450, 639) all agree; SEN 3003 observations / 3004 lines and GNB 2268 observations / 2269 lines (header + 1) agree everywhere (lines 377, 440, 498, 500); 39 GNB `NaN`/`O` rows agrees at lines 254 and 378; `structure/ARTEFACTS.csv` "at least 25 rows" (line 342) is a loose bound, no contradiction found.
- Header/sample-row column-by-column check (2.3, lines 108-116): both the header and the sample row split into exactly 37 comma-separated fields, in the same order as the 2.4 DSD table's `Id` column from position 4 onward (`FREQ` ... `OBS_COMMENT`); every value is plausible for its column except `GEO` (R-G-1). D46's wording ("fixed columns, dimensions, TIME_PERIOD, measures, attributes. 37 columns, 19-column key") matches the file order exactly (3 fixed + 18 dims + 1 time + 9 measures + 6 attributes = 37).
- Artefact ids/versions: `WB.AFW360`, `WB_AFW360` (used only as the dot-free message-header sender id, explained at line 62 and matching cheatsheet line 26), `AFW360_HH`, `DSD_AFW360_HH`, `CS_AFW360`, `MSD_AFW360`, `MDF_AFW360`, `MPA_AFW360`, `PA_AFW360_HH`, `DATA_PROVIDERS`, `METADATA_PROVIDERS`, `AFW_POV`, `AGENCIES` all spelled identically at every occurrence checked. Version `0.3.0` used consistently for every `WB.AFW360:*` artefact reference in both plan.md and the cheatsheet; no stray `0.2.0`/`1.0` mix-ups found for versioned artefacts (the `(1.0)` fixed-version notation for `AGENCIES`/`DATA_PROVIDERS`/`METADATA_PROVIDERS` is deliberate — see next bullet).
- D31 ("WB:AGENCIES(1.0)" scheme) vs section 2.1 ("no version attribute in XML") vs cheatsheet section 3 ("omit the version attribute in XML" / "Fixed-version item URN: ...Agency=WB:AGENCIES(1.0).AFW360"): not a contradiction. All three consistently apply the real SDMX convention that fixed-version maintainables omit the XML `version` attribute but are referenced with an implied version "1.0" in URNs; the same nuance is applied uniformly to `AGENCIES`, `DATA_PROVIDERS`, `METADATA_PROVIDERS`.
- `CL_*` ids: all well-formed and consistent; apparent bare "`CL_UNIT`" hits (lines 327, 350, 403) are legitimate references to the old pre-migration file/pattern being removed, not typos for `CL_UNIT_MEASURE`.
- `MDS_SURVEY_` vs `MDS_SURVEYS`: legitimate file-name (`MDS_SURVEYS.csv`) vs per-row-id (`MDS_SURVEY_<survey_id>`) distinction, not a typo.
- `SDMX.CSV_HEADER` vs `vc_sdmx_csv_header`, and the parallel `SDMX.XSD`/`vc_sdmx_xsd`, `SDMX.URN`/`vc_sdmx_urn`, `SDMX.STALE`/`vc_sdmx_stale`: consistent naming convention (check id `SDMX.<NAME>` implemented by R function `vc_sdmx_<name>`), applied uniformly.
- File paths: cross-checked every WP-mentioned path against section 2.2 and the repository; `pipeline/tests/testthat/` and `pipeline/R/` exist as expected pre-existing directories; `tools/`, `afw360/` do not yet exist (expected, both are new deliverables). `sdmx/README.md`, `.docs/fmr-guide.qmd`, `.docs/sdmx-conformance.qmd`, and all four `sdmx/metadata/MDS_*.csv` files listed in 2.2 are each produced by a specific WP (WP5c/WP8b/WP10/WP1).
- Decisions D27-D46: every D-id referenced in sections 2-6 and the cheatsheet exists in the section-1 table and its referencing sentence matches the decision's content (spot-checked D32/2.9, D33/WP1 item 2, D35+D40/2.13, D37/2.14, D38-39/WP1 item 3, D41-D44/2.5, D42/WP1 item 4, D46 throughout). Section 0's "eleven decisions" (D27-D37) and section 1's "D38 to D46 are design decisions" (9) are both arithmetically correct and consistent with each other.
- Cross-references: all "section 2.x" and "(2.x)" references in plan.md point to a section that exists and covers the claimed topic (checked 2.1, 2.4, 2.5, 2.7, 2.9, 2.10, 2.12, 2.13, 2.14 against their citing sentences). Plan's own sections 3, 4, 5, 6 exist at the exact line numbers given in the review brief's boundaries. Research references `R4 section 6d`, `R4 section 9`, `R4 section 11`, `R1 sections 3,4,5,6.1,13,14`, `R1 sections 7,8,9.1,9.2,9.3,11`, `R1 section 9.4`, `R2 section 1`, `R2 section 6`, `R2 section 3` all resolve to existing, topically-matching headings in the research files (checked via heading-only grep).
- WP ids: every `WP<n>[a-c]` referenced in plan.md, handover.md and PROGRESS.md corresponds to an existing `### WP` heading in plan.md; PROGRESS.md's WP/Gate list matches plan.md's set exactly (no WP present in one table but not the other). Depends-on columns match for WP0, WP1, WP2, Gate 1, WP4a, WP4b, WP5b, WP5c, WP5d, WP6, WP9a, WP9b, WP9c, WP8a, Gate 2, WP8b, WP11, Gate 3 (differences for WP3, WP5a, WP7, WP8c, WP10 listed above).
- Cheatsheet vs plan contradiction checks: 2.7/cheatsheet-10 agree `MDSTRUCTURE` = `metadataflow`; 2.5/cheatsheet-4 agree on `Annotation id`/`AnnotationType`/`AnnotationValue` form; 2.4's "No MSD link on the DSD" is not contradicted anywhere in the cheatsheet's DSD example (section 8, no MSD reference shown); cheatsheet section 9's `Dataflow`/`ProvisionAgreement` and section 10's `MetadataStructure`/`Metadataflow`/`MetadataProvisionAgreement` XML skeletons match plan 2.7/2.8's prose exactly (agency, ids, `OBS_STATUS` MeasureRelationship, `TIME_PERIOD` required LocalRepresentation).
- handover.md vs plan.md section 3 conventions: implementer report length "at most 40 lines" matches at both plan.md:279 and handover.md:27; verifier model (Sonnet, fresh agent, never fixes) matches at plan.md:280 and handover.md:29; commit-after-verifier-pass rule matches at plan.md:281 and handover.md:31; PROGRESS.md fields (`todo`/`in progress`/`verified`/`committed`/`blocked`, gate states `pending`/`approved`/`vetoed`) match PROGRESS.md:3 and handover.md's references to "committed" (line 15, 21) and "approved" (line 21, 50).
- Terminology: "metadataset" used consistently (never "metadata set"); "Metadataflow"/"metadataflow" used consistently as the SDMX class/check name (one lowercase-prose instance at cheatsheet:209 is plain English inside a `<com:Name>` display string, not a technical term); "GregorianYear" spelled identically at all 5 occurrences; `sdmx_csv_version` (manifest key, underscores) used consistently with no `sdmx-csv-version` dash variant anywhere; "sub-agency", "reconcile"/"reconciliation" spelled consistently throughout.

## Not checked

None — all ten checks in the assigned order were completed within budget.
