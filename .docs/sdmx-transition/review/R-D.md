# Review R-D: repository fit

Reviewer: R-D. Scope: plan.md sections 2.2, 2.10, 2.11, 2.14, section 3 preamble, and the Context/Deliverables of WP1, WP2, WP3, WP4a, WP4b, WP5d, WP9a, WP9b, WP9c. Branch `standard/v0.6-sdmx`, checked 2026-09-29.

### R-D-1
Severity: major
Where: plan.md section 3, WP2 (Context line 327, Deliverable 5, Verification bullet "test-docs must pass")
Claim: WP2 must pass `test-docs` and `build_docs.R --check`, but the code and test that break are outside WP2's context. `pipeline/R/docs.R` lines 26-35 are not in the given range 200-290, and `pipeline/tests/testthat/test-docs.R` is not listed at all.
Evidence: `pipeline/R/docs.R:26-29` `.DOCS_COMMON_COLS <- c("code","name_en","definition_en","status","version_added","replaced_by","notes")` (the new `global_urn` column would show up in every "beyond the common ones" table); `docs.R:32-35` `.DOCS_SMALL_CODELISTS <- c(..., "CL_UNIT")` (the file is renamed by WP2); `test-docs.R:50-57` expects 31 rows in `tbl-columns` with `DATAFLOW` in position 1, and the new DSD has 34 rows and no `DATAFLOW`.
Fix: in the WP2 Context, replace "`pipeline/R/docs.R` lines 200 to 290 (the columns table generator)" with "`pipeline/R/docs.R` lines 20 to 70 (common columns, small codelists, column-table list) and 200 to 290 (the columns table generator); `pipeline/tests/testthat/test-docs.R` lines 45 to 90". Add to Deliverable 5: "`.DOCS_COMMON_COLS` gains `global_urn`; `.DOCS_SMALL_CODELISTS` uses `CL_UNIT_MEASURE` and `CL_FREQ`; `test-docs.R` updated for 34 DSD rows."

### R-D-2
Severity: major
Where: plan.md section 2.10 item 3 (line ~235), and WP2 Verification bullet 3 (line ~345)
Claim: 2.10 puts `global_urn` "after `notes`", but the WP2 check says "Every codelist header ends with `notes,global_urn`". Ten codelists have columns after `notes`, so the rule and the check describe different layouts.
Evidence: the header loop over `metadata/codelists/CL_*.csv` shows columns after `notes` in CL_AREA (`iso2,currency,wb_region`), CL_BRK_VAR, CL_COMP_BREAKDOWN, CL_GEO, CL_GEO_SCHEME, CL_INDICATOR (28 columns), CL_QUAL_VAR, CL_QUALIFIER, CL_STATISTIC and CL_URBANISATION. The check `grep -q "notes,global_urn"` passes only when `global_urn` directly follows `notes`, so it contradicts the word "ends".
Fix: pick one layout and state it in both places. Recommended: "`global_urn` is inserted immediately after `notes` (the 8th column) in every codelist; the columns after it shift by one position in COLUMNS.csv." Change the verification text to "every codelist header has `notes,global_urn` as its 7th and 8th columns: `head -1 $f | cut -d, -f7,8` equals `notes,global_urn`."

### R-D-3
Severity: major
Where: plan.md section 2.11 (line 244), "about 67 test lines (`test-convert`, `test-ctx`, `test-plan`, `test-docs`, `helper-data-fixture`)"
Claim: The test count and the file list are both understated. Four more test files hard-code the layout.
Evidence: With R4's own pattern, `grep -cE "AFW360_HH|31|19|DSD_COLUMNS|KEY_COLUMNS"` gives helper-data-fixture 4, test-convert 16, test-ctx 13, test-docs 4, test-migrate-0.2.0 5, test-plan 12, test-reconcile 6, test-validate-core 5, test-validate-coverage 7, test-validate-rules 9, for a total of 81. The five named files sum to 49. With the review's pattern (`data_raw|DATAFLOW|metadata/structure|manifest|DSD_COLUMNS|KEY_COLUMNS|dsd_columns|dsd_key_columns`) the total is 127, including test-validate-coverage 39 and test-validate-core 13. `test-validate-core.R:330` also edits `CL_UNIT.csv`. The WP contexts do name these files (WP3 test-reconcile, WP4a test-validate-coverage, WP4b test-validate-core and test-validate-rules), so only 2.11 is inaccurate.
Fix: replace "about 67 test lines (`test-convert`, `test-ctx`, `test-plan`, `test-docs`, `helper-data-fixture`)" with "about 80 test lines (`helper-data-fixture`, `test-convert`, `test-ctx`, `test-docs`, `test-plan`, `test-reconcile`, `test-validate-core` (incl. `:330` `CL_UNIT.csv`), `test-validate-coverage`, `test-validate-rules`); `test-migrate-0.2.0` is frozen and does not change".

### R-D-4
Severity: major
Where: plan.md section 2.11 (line 244), and section 2.10 item 5
Claim: The hard-coded list leaves out the `CL_UNIT` references in pipeline code. It also leaves out `dsd_columns()` call sites whose meaning changes once `data_columns()` (fixed columns plus components) exists.
Evidence: `grep -rn "CL_UNIT\b" pipeline --include=*.R` finds `R/docs.R:34`, `R/docs.R:228` (`CL_UNIT = "metadata/codelists/CL_UNIT.csv"`), `R/validate_metadata.R:234` (`check_field("CL_INDICATOR","unit_measure","CL_UNIT","code")`) and `bootstrap/build_small_codelists.R:31`. The `dsd_columns` hits missing from 2.11 are `R/convert_tables.R:382` (`columns <- dsd_columns(meta)`), `convert_legacy.R:81` (`identical(names(rows), dsd_columns(meta))`), `R/validate_codes.R:43` and `R/validate_structure.R:23` (`ctx_dsd_columns`). R4 section 6d also lists `R/ctx.R:184` and `R/validate_rules.R:283` (RULES scope `DATAFLOW`), and 2.11 drops both. These are scope vocabulary and can stay, but the plan should say so.
Fix: append to the 2.11 list: "`R/docs.R:34,228`, `R/validate_metadata.R:234` (`CL_UNIT` -> `CL_UNIT_MEASURE`); `R/convert_tables.R:382`, `convert_legacy.R:81`, `R/validate_codes.R:43`, `R/validate_structure.R:23` (choose `dsd_components()` or `data_columns()` at each); `R/ctx.R:184`, `R/validate_rules.R:283`, `R/validate_metadata.R:366-409` are the RULES `scope` vocabulary `DATAFLOW`, unchanged; `bootstrap/` is frozen."

### R-D-5
Severity: minor
Where: plan.md section 2.10 item 5 (line 239)
Claim: The item updates "Every reference to `CL_UNIT` in `RULES.csv`, `SERIES_PLAN.csv`, `COLUMNS.csv` descriptions", but `RULES.csv` and `SERIES_PLAN.csv` contain no `CL_UNIT` reference.
Evidence: `grep -rln "CL_UNIT[^_]" metadata` lists only `metadata/structure/COLUMNS.csv` (rows 57-63 with `file` = `CL_UNIT.csv`, and row 185 description "CL_UNIT.") and `metadata/structure/DSD_AFW360_HH.csv:23` (rewritten by item 1). CHANGELOG.md is historical.
Fix: "Every reference to `CL_UNIT` in `COLUMNS.csv` (the seven `CL_UNIT.csv` rows become `CL_UNIT_MEASURE.csv`; the `CL_INDICATOR.unit_measure` description at row 185) is updated to `CL_UNIT_MEASURE`. `RULES.csv` and `SERIES_PLAN.csv` have none."

### R-D-6
Severity: minor
Where: plan.md section 2.10 (items 3 and 4) and WP2 Deliverables
Claim: 2.10 never says that every `CL_*.csv` file gains a `global_urn` column. Item 3 covers only COLUMNS.csv, and item 4 covers `global_urn` values for a few lists. The WP2 verification expects the column in all 19 codelists.
Evidence: plan lines 235-237. The WP2 checks expect every codelist header to contain `global_urn` and `grep -c global_urn COLUMNS.csv` to be at least 19. There are 18 `CL_*.csv` files today; after the rename plus CL_FREQ there are 19.
Fix: add to item 4: "Every `CL_*.csv` (19 files after the rename and CL_FREQ) gains the column `global_urn` (empty unless 2.9 fills it)."

### R-D-7
Severity: minor
Where: plan.md section 2.10 closing paragraph and WP2 Deliverable 1
Claim: The fixture path is ambiguous. The existing fixture convention is a root folder that holds `metadata/` and `data_raw/`, not a copy of `metadata/` itself, and the WP2 verification (`--root fixtures/metadata-0.2.0`, then `diff -r tmp/mig/metadata metadata`) assumes that root layout.
Evidence: `ls pipeline/tests/testthat/fixtures/metadata-0.1.0` shows `data_raw metadata`; `test-migrate-0.2.0.R:27` reads `file.path(fixture, "metadata", ...)`. `fixtures/metadata-0.2.0` does not exist yet; WP2 creates it.
Fix: WP2 Deliverable 1: "`pipeline/tests/testthat/fixtures/metadata-0.2.0/metadata/`: frozen copy of the current `metadata/` (all 34 files), same layout as `fixtures/metadata-0.1.0/`."

### R-D-8
Severity: major
Where: plan.md section 2.14 (last sentence) and WP9a/WP9b (requirements, rendering regression)
Claim: No `requirements.txt` exists in the repository to be "updated". The project `.venv` also lacks `matplotlib`, which `index.qmd` imports, so the WP9b step "run `quarto render index.qmd` before editing" is not supported by the documented environment.
Evidence: `ls requirements*` finds no file and `git ls-files | grep -i requirements` is empty. `.venv/Scripts/python -m pip list` shows geopandas 1.1.4, pandas 3.0.6, pytest 9.1.1, openpyxl 3.1.5 and matplotlib-inline 0.2.2 only. `.venv/Scripts/python -c "import matplotlib"` gives `ModuleNotFoundError: No module named 'matplotlib'`. `index.qmd:367` has `import matplotlib.pyplot as plt`. The interpreter is Python 3.11.9. Uncertain: whether Quarto on this machine uses `.venv` or another interpreter.
Fix: in 2.14 replace "Requirements for Posit Connect (Python 3.11.9) are updated." with "A root `requirements.txt` for Posit Connect (Python 3.11.9) is created, pinning pandas, geopandas, matplotlib, openpyxl (while `data_raw` reads remain) and the Jupyter kernel packages Quarto needs." In WP9a Deliverables, change "`requirements.txt` updated if needed" to "`requirements.txt` created; `.venv` gains matplotlib (`pip install -r requirements.txt`) before WP9b's baseline render".

### R-D-9
Severity: minor
Where: plan.md WP9c Deliverables (line 522)
Claim: "the GNB map from `GNB_CODAB_V01.gpkg`" reads as a switch-over, but the Guinea-Bissau section has no map today. It draws a bar chart from the `ADM 1` sheet, so the map is a new feature.
Evidence: `index.qmd:864-883` ("Load Excel file and ADM 1 sheet ... Create horizontal bar chart"). `gpd.read_file` and `.shp` occur only in the Senegal section (`index.qmd:371,398`). `geo/boundaries/GNB_CODAB_V01.gpkg` exists, with exact case.
Fix: "add a GNB ADM1 map from `GNB_CODAB_V01.gpkg` (new; today the section shows a bar chart), built with the same helper as Senegal."

### R-D-10
Severity: minor
Where: plan.md WP9c Deliverables ("About pages from `content/`"; "no `data_raw` reference remains")
Claim: The About section reads `data_raw/text/About.txt`, and `content/TEXT.csv` has no `ALL` row. The implementer needs to know that the standard maps `About.txt` to the SEN about text.
Evidence: `index.qmd:1182` `Path("data_raw/text/About.txt")`. The only `content/TEXT.csv` slots are `about` and `messages` for SEN and GNB. `cmp About.txt About_SEN.txt` shows the files are identical. `.docs/data-standard.qmd:756` says "`About.txt` is treated as Senegal-specific (`ref_area = SEN`)".
Fix: add "the About page reads `load_text("SEN", "about")` (standard sec-text-replaces: `About.txt` is the SEN text)".

### R-D-11
Severity: minor
Where: plan.md section 2.2 (lines 67-96)
Claim: Several tree entries do not exist today and carry no "new" marker. Only `ARTEFACTS.csv`, `CL_FREQ.csv`, the renamed `CL_UNIT_MEASURE.csv`, the rewritten DSD and the two new .docs pages are marked.
Evidence: `test -e` fails for `sdmx/` (described as "generated", acceptable), `pipeline/build_sdmx.R`, `pipeline/import_sdmx.R`, `pipeline/R/sdmx_*.R`, `pipeline/R/validate_sdmx.R`, `pipeline/xsd/`, `pipeline/migrations/0.3.0/`, `tools/` and `afw360/`. It succeeds for `data/`, `metadata/`, `DSD_AFW360_HH.csv`, `CL_UNIT.csv`, `.docs/data-standard.qmd`, `.docs/transition.qmd`, `.gitattributes` and `.gitignore` (which has no `tmp/` entry yet, as the plan expects).
Fix: suffix each of those lines with "new", or add one sentence under the tree: "Every path under `sdmx/`, `tools/`, `afw360/`, `pipeline/xsd/` and `pipeline/migrations/0.3.0/`, and every `pipeline/*sdmx*` file, is new."

### R-D-12
Severity: minor
Where: plan.md WP3 Context (`convert_tables.R` lines 440 to 575) and WP9b Context (`index.qmd` lines 1 to 720, "the Senegal section")
Claim: Both ranges are workable but slightly off. `build_country_rows()` starts at line 381, and its `dsd_columns(meta)` call at 382 falls outside the range. The Senegal section is lines 184-719; lines 1-183 are shared setup (the STEP 1 to 4 helpers).
Evidence: `grep -n "<- function" convert_tables.R` gives `381:build_country_rows` and `548:finalize_rows` (the file has 575 lines). `index.qmd` headings: `184:# Senegal`, `720:# Guinea Bissau`, `1177:# About` (the file has 1195 lines).
Fix: WP3: "`pipeline/R/convert_tables.R` lines 381 to 575 (`build_country_rows()` and `finalize_rows()`)". WP9b: "`index.qmd` lines 1 to 183 (shared setup and helpers) and 184 to 719 (the Senegal section), in pieces".

### R-D-13
Severity: minor
Where: plan.md section 2.11 line citations
Claim: A few cited lines are off by one or point at a line next to the hard-coded item.
Evidence:
- `convert_legacy.R:73` is `estimation <- "SURVEY"`; `dsd_key_columns` is at 74.
- `convert_legacy.R:82` is the `stop(...)` message; the `dsd_columns` comparison is at 81.
- `validate.R:55` is the discovery pattern (correct); the `_manifest` exclusion is at 56.
- All other cited lines match: ctx.R 79/91/126, plan.R 28/307, convert_tables.R 493/523, manifest.R 23/55, reconcile.R 20-25/40/222/304-315/385, validate_structure.R 62/100-105, validate_coverage.R 224, validate_codes.R 72, validate_metadata.R 47/366-409, docs.R 212/263-273.
Fix: "`convert_legacy.R:51,73-74,81-82`" and "`validate.R:55-56`".

### R-D-14
Severity: minor
Where: plan.md WP1 Deliverables items 6 and 8 and WP10 item 8 (R4 section 11 inconsistencies)
Claim: R4 section 11 has 19 numbered items (18 and 19 are "no mismatch"). The plan assigns 1 and 2 (WP1 item 6), 4, 5 and 7 (WP1 item 8), and 8 to 12 (WP10). Items 3, 6, 13, 14, 15, 16 and 17 are not assigned by number. Item 13 (the `_SURVEY` literal) is covered by WP4a in substance, and item 14 (CLAUDE.md layout) partly by WP9c. The number 15 in the review prompt does not appear in plan.md.
Evidence: `research/R4_repo_inventory.md:789-812`; `grep -n "inconsisten" plan.md` hits only lines 305, 307 and 577.
Fix: add to WP10 item 8: "and 3, 6, 15, 16, 17 (or record each as deliberately deferred in PROGRESS.md); 13 is closed by WP4a, 14 by WP9c."

## Verified OK

- **Metadata inventory.** `metadata/` has 34 tracked files. Each is either touched by 2.10 or unaffected.
  - Touched: DSD (item 1), ARTEFACTS (item 2, new), COLUMNS (items 3 and 5), all 18 CL_*.csv (global_urn, see R-D-6), CL_AGE, CL_OBS_STATUS and CL_UNIT → CL_UNIT_MEASURE (items 3 and 4), CL_AREA (currency closure and global_urn), VERSION and CHANGELOG (item 6).
  - Unaffected: plans/* (LEGACY_*, SERIES_PLAN and TAB_PLAN have no CL_UNIT or DATAFLOW reference), registries/* (FIGURES, GEO_SOURCES, SOURCES), surveys/SURVEYS, INDICATOR_QUALIFIERS, QUALIFIER_PAIRS, and rules/RULES (its scope value `DATAFLOW` and rule ids `AFW360_HH.*` are vocabulary, not the DSD column).
- **Metadata state.** `metadata/VERSION` = `0.2.0`, and `metadata/CHANGELOG.md` exists. The DSD has 31 rows with header `position,id,role,codelist,required,sentinel,description`.
- **Functions** exist where cited:
  - `DATAFLOW_ID` constants.R:14, `DSD_COLUMNS` :31, `KEY_COLUMNS` :67.
  - `dsd_columns` io.R:181, `dsd_key_columns` io.R:201.
  - `order_and_pad` convert_tables.R:250, `finalize_rows` convert_tables.R:548.
  - `validate_docs.R` is 36 lines and defines `vc_docs_fragments`; `validate_common.R` (96 lines) holds the `.vc_*` helpers.
  - The new names in 2.11 (`AGENCY_ID`, `SDMX_CSV_FIXED`, `structure_id`, `ACTION_PUBLISHED`, `dsd_components`, `data_columns`) do not exist yet, as intended.
- **Line ranges** still point at the described content (file length in brackets):
  - migrate.R [687] 1-120: header, guard 40-52, helpers to 108.
  - docs.R [554] 200-290: `.docs_read`, `.docs_tbl_columns`.
  - io.R [206] 175-206: `dsd_columns`, `dsd_key_columns`.
  - reconcile.R [614] 1-60, 200-240 (`expected_rows` 201), 290-400.
  - plan.R [373] 1-60 and 290-373 (DATAFLOW at 307).
  - validate_coverage.R [546] 200-260 (`vc_cover_file_missing` 213).
  - validate.R [150] 40-70.
  - validate_rules.R [782] 190-300 (`.vc_build_rows` starts at 184; scope at 283).
  - validate_metadata.R [637] 30-60 (key map 47), 220-240 (CL_UNIT at 234), 360-410 (rules).
  - index.qmd [1195] 180-330 (SEN national tables) and 361-430 (SEN ADM1 map).
- **Tests.**
  - `pipeline/tests/testthat.R` runs `testthat::test_dir("pipeline/tests/testthat")`.
  - `fixtures/` (metadata-0.1.0 only) and `helper-data-fixture.R` exist.
  - Every cited test file exists: test-convert, test-reconcile, test-io, test-ctx, test-plan, test-validate-coverage, test-validate-core, test-validate-rules, test-docs, test-migrate-0.2.0.
- **Baseline commands** parse as written:
  - `validate.R`: `--root`, `--out` (required).
  - `build_docs.R`: `--root`, `--check`.
  - `reconcile.R`: `--root`, `--out` (required).
  - `convert_legacy.R`: `--root`, `--country SEN|GNB|ALL`, `--timestamp`, `--out-root`.
  - `write_std_csv` creates parent directories (io.R:39), so `tmp/` need not exist beforehand.
- **Data files.**
  - The SEN header has 31 columns. SEN is 3004 lines (3003 rows) and GNB 2269 lines (2268 rows).
  - Each manifest is 17 lines: a header plus 16 keys. This matches plan line 128 (`dataflow` plus 15 others) and `manifest.R:7` ("16 keys"). The review prompt's "17 keys" is the line count, not the key count.
  - OBS_STATUS is column 24. Parsed with pandas, GNB has 39 `O` rows and SEN none.
- **WP9c figures.** `.docs/transition.qmd:81` states "SEN 3.13M / 6.52M and GNB 0.70M / 1.09M poor at $3.00 / $4.20", which backs WP9c.
- **Loader inputs** exist:
  - `geo/boundaries/SEN_CODAB_v02.gpkg` and `GNB_CODAB_V01.gpkg`, with exact case.
  - `content/TEXT.csv` (columns slot, ref_area, time_period, order, title, body, file, status, updated_on; about and messages rows for SEN and GNB).
  - `metadata/registries/FIGURES.csv` (17 columns including file and sha256; one SEN row) and `assets/figures/SEN/SEN_FISCAL_EQUITY.png`.
  - `LEGACY_LABELS.csv` and `LEGACY_COLUMNS.csv` (the latter has `cut_id`).
  - `CL_INDICATOR.csv` has `short_name_en`, `display_as`, `decimals` and `higher_is`.
- **How index.qmd reads data today:**
  - `Tables_SEN.xlsx`: sheet National (SEN tables, lines 215-600), ADM 1 (map, 384) and ZAE (438).
  - `sen_admin1.shp` with `adm1_name` (371, 398).
  - GNB chunks use the SEN `file_path` (sheets National, ADM 1, ZAE; lines 748-1057).
  - `Fiscal Equity SEN.png` appears in both sections (658, 665, 1115, 1122).
  - About texts are read at 675, 1132 and 1182; base64 downloads of Tables_SEN and Tables_GNB are built at 694 and 1151.
  - `Messages_*.txt` are never read.
- **R4 inventory.** Section 9 exists, and its line-to-heading table matches `grep -n "^# \|^## " .docs/data-standard.qmd` (1032 lines; spot-checked lines 37 to 398, 717, 787, 884, 968 and 992). Section 11 exists with 19 items.

## Not checked

- Content of `research/R4_repo_inventory.md` beyond sections 6d, 9 and 11.
- Whether Quarto renders with `.venv` (R-D-8 is marked Uncertain on that point). No script or test suite was executed; the checks used only grep/sed/ls/pip list and a pandas read of the data files.
- The GNB headcount values in `data/` themselves (only the transition.qmd statement was checked).
