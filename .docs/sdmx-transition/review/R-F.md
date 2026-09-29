# Review R-F: WP3 to Gate 3, order, risks, checklist, handover

Scope: plan.md lines 358 to 655, handover.md, PROGRESS.md. Byte counts are from `wc -c` or `sed -n 'a,bp' | wc -c`; tokens = bytes / 4.

## Input-size arithmetic (rule 1)

Plan sections measured: 2.1 789, 2.3 1529, 2.4 2957, 2.5 2211, 2.6 887, 2.7 2357, 2.8 305, 2.9 1520, 2.11 1026, 2.12 1424, 2.13 1544, 2.14 858; sections 1 and 2 together (27-274) 28265. Cheat-sheet 16461. R1 sections 3,4,5,6.1,13,14 = 15095; 7,8,9.1-9.3,11 = 17499; 9.4 = 3939. R2 s1 4125, s3 4862, s6 3943. R4 s11 3105. Web (curl): field guide 22409, pysdmx general_reader 24521, sdmx_csv 34042 (raw HTML, upper bound).

| WP | Items (bytes) | Sum | Tokens |
|---|---|---|---|
| WP3 | WP 2939; 2.3/2.4/2.11 5512; constants 1844; io 6001; manifest 2967; convert_legacy 3949; convert_tables 440-575 4691 + grep 466; R/reconcile ranges 8445; test grep ~9038; helper-data-fixture 6059 | 51911 | 13.0k |
| WP4a | WP 1549; 2.3/2.4 4486; ctx 6833; plan ranges 5216; validate_structure 5540; coverage 2465+177; validate.R 40-70 1074; test grep ~2872 | 30212 | 7.6k |
| WP4b | WP 1646; 2.4/2.5/2.9 6688; codes grep 2446; values grep 4670; rules 190-300 3707; metadata ranges 5140; test grep ~6780 | 31077 | 7.8k |
| WP5a | WP 2875; 2.1/2.5/2.6 3887; cheat-sheet 16461; R1 15095; ARTEFACTS ~3000 (WP2, est.); DSD 2942; io ranges 3119; build_docs 1620 | 48999 | 12.2k |
| WP7 | WP 1238; 2.12 1424; R2 8068; two pysdmx pages 58563 | 69293 | 17.3k |
| WP5b | WP 2118; 2.4/2.6/2.7/2.8 6506; cheat-sheet 16461; R1 17499; sdmx_xml.R ~8000 (est.); signatures ~1000; DSD 2942; COLUMNS grep ~6400 (est.) | 60926 | 15.2k |
| WP5c | WP 1292; 2.7 2357; R1 9.4 3939; field guide 22409; four heads ~3000; io helper ~2000 | 34997 | 8.7k |
| WP5d | WP 1137; validate_docs 1673; validate_common 3478; validate.R 1-60 2401; sdmx_xml.R ~8000; 2.12 1424 | 18113 | 4.5k |
| WP6 | WP 1580; 2.5/2.13 3755; sdmx_xml.R ~8000; codelist fn ~4000; ARTEFACTS ~3000; head ~500 | 20835 | 5.2k |
| WP9a | WP 1456; 2.14 858; index 180-330 + 361-430 6821; heads ~1200; TEXT 2008; FIGURES 999; listings ~500 | 13842 | 3.5k |
| WP9b | WP 1525; loader.py ~15000 (est.); index 1-720 20559; LEGACY_LABELS grep ~3000; listings ~500 | 40584 | 10.1k |
| WP9c | WP 1058; loader ~15000; index 720-1195 ~11754; Senegal pattern ~15000 | 42812 | 10.7k |
| WP8a | WP 1322; 2.13 1544; R2 s3 4862; two web pages ~40000 (est.); java ~300 | 48028 | 12.0k |
| WP8b | WP 953; no context list | n/a | n/a |
| WP8c | WP 537; no context list | n/a | n/a |
| WP10 | WP 2322; PROGRESS surfaced ~3000; plan s1+s2 28265; standard SDMX chapter ~20000 (est., WP1); transition.qmd 9527; pipeline/README 6824; CLAUDE.md 3843; R4 s11 3105 | 76886 | 19.2k (see R-F-17) |

All WPs are under 40k input tokens. The problems are output size, verification, self-containment and dependencies.

## Findings

### R-F-1
Severity: blocker
Where: plan.md section 3 WP11, line 589
Claim: `git worktree add tmp/final standard/v0.6-sdmx` fails, because that branch is checked out in the main working tree.
Evidence: git-worktree documentation (https://git-scm.com/docs/git-worktree, "add"): "By default, add refuses to create a new worktree when <commit-ish> is a branch name and is already checked out by another worktree". The orchestrator works on `standard/v0.6-sdmx` (handover.md, setup step 1).
Fix: replace with "`git worktree add --detach tmp/final standard/v0.6-sdmx` (a detached checkout of the branch tip; remove it afterwards with `git worktree remove tmp/final`)". Add to step 1: "Python steps use the main tree's interpreters by absolute path (`<repo>/.venv/Scripts/python`, `<repo>/tools/verify/.venv/Scripts/python`), because the gitignored venvs are not in the worktree." Pass `--root .` to every script in step 1 (`convert_legacy.R` is listed without it).

### R-F-2
Severity: blocker
Where: plan.md WP5c verification, line 464; WP7 deliverables, line 438; section 6 rows 8 and 12
Claim: WP5c's check "`verify_sdmx.py` reads them without error and reports the metadataset count" and WP7's deliverable "reads ... `sdmx/metadata/*.csv` ... as SDMX-CSV" cannot be executed, because pysdmx 1.20.0 reads only SDMX-CSV data messages (fact established by a parallel reviewer).
Evidence: lead-supplied established fact; plan.md:438, :464.
Fix: WP7 deliverable: replace "reads each `data/*.csv` and `sdmx/metadata/*.csv` if present as SDMX-CSV" with "reads each `data/*.csv` as SDMX-CSV 2.1 with pysdmx; for each `sdmx/metadata/*.csv` it parses the file with Python's `csv` module (RFC 4180), checks that the first five header cells are `MDSTRUCTURE,MDSTRUCTURE_ID,METADATASET_ID,TARGET_TYPES,TARGET_IDS`, and checks that every other header's dotted path ends in an MSD metadata attribute id read from the structure message with pysdmx". WP5c check: "`verify_sdmx.py --root .` exits 0 and prints one line per metadata file with its row count". WP7 requirements: `pysdmx[data,xml]==1.20.0`.

### R-F-3
Severity: blocker
Where: plan.md WP5a verification, line 428; WP5b line 452; WP5c line 464
Claim: the WP5a, WP5b and WP5c verification lists use `tools/verify` (lxml XSD validation, `verify_sdmx.py`), but none of them depends on WP7, and `.venv` has no lxml.
Evidence: `.venv/Scripts/python -m pip list | grep -i "lxml\|html5lib\|bs4\|beautifulsoup"` prints nothing. WP5a: "Depends on: WP2 (metadata), WP0 (xml2)"; WP5b: "WP5a"; WP5c: "WP5b".
Fix: WP5a "Depends on: WP2, WP0, WP7 (lxml venv)"; WP5b "Depends on: WP5a, WP7"; WP5c keeps WP5b (WP7 is then transitive). Replace WP5a's "`python -c "import lxml"` in `.venv` or `tools/verify` venv then an XSD validation" with "`tools/verify/.venv/Scripts/python tools/verify/xsd_validate.py pipeline/xsd/sdmx-ml-3.1/SDMXMessage.xsd sdmx/structures/AFW360_structures.xml` prints `valid`", and add `xsd_validate.py` to WP7's deliverables.

### R-F-4
Severity: blocker
Where: plan.md WP7, lines 434 and 440
Claim: WP7 says "Depends on: nothing", but its verification needs the 37-column SDMX-CSV 2.1 files that only WP3 produces. Today's files have 31 columns and start with `DATAFLOW`, which is not an SDMX-CSV 2.x header.
Evidence: `head -1 data/AFW360_HH_SEN_2021_SURVEY.csv` gives `DATAFLOW,REF_AREA,GEO,TIME_PERIOD,...,OBS_COMMENT`. plan.md:440 says "read both data files as SDMX-CSV 2.1 and report 3003 and 2268 observations". Uncertain: whether pysdmx would read the old header as SDMX-CSV 1.0 (not tested; either way it would not be 2.1).
Fix: "Depends on: WP3 (SDMX-CSV 2.1 data files). Parallel with WP4a and WP9a; WP5a waits for it (R-F-3)."

### R-F-5
Severity: major
Where: plan.md WP3 deliverables, lines 364 to 371
Claim: WP3 changes more than 8 files and mixes the converter, reconciliation and tests, which breaks rules 2 and 5.
Evidence: files touched: `R/constants.R`, `R/io.R`, `R/manifest.R`, `convert_legacy.R`, `R/convert_tables.R`, `R/reconcile.R`, `test-convert.R`, `test-reconcile.R`, `helper-data-fixture.R`, `test-io.R` (must pass per plan.md:381, but is not in context), and the projection script. That is 11 hand-written files, plus 4 regenerated data and manifest files. Estimated about 550 hand-written lines (io +80, constants +30, manifest +20, convert +50, reconcile +80, tests +200, helper +40, projection +60). Current sizes: test-convert 448 lines, test-reconcile 333, helper 141, test-io 98.
Fix: split.
- **WP3a Converter and I/O on SDMX-CSV 2.1 (Opus).**
  - Depends on: WP2, Gate 1.
  - Context: 2.3, 2.4, 2.11 (pasted); constants.R; io.R; manifest.R; convert_legacy.R; convert_tables.R 440-575 + grep; test-io.R; test-convert.R grep; helper-data-fixture.R.
  - Deliverables: 1, 2, 4 (for convert and io only) and 5.
  - Files (8): constants.R, io.R, manifest.R, convert_legacy.R, convert_tables.R, test-io.R, test-convert.R, helper-data-fixture.R, plus the regenerated data.
  - Verification: header, row 2, `wc -l`, NaN and O counts, manifest, `test-io` and `test-convert` pass.
  - Commit: `Data as SDMX-CSV 2.1: converter and manifest on DSD 0.3.0; regenerate SEN and GNB`.
- **WP3b Reconciliation and 0.2.0 projection test (Opus).**
  - Depends on: WP3a.
  - Context: 2.3 (pasted); R/reconcile.R ranges; pipeline/reconcile.R; test-reconcile.R grep.
  - Deliverables: 3 and 6, with the projection kept as `pipeline/tests/testthat/test-projection-0.2.0.R`.
  - Files: 3.
  - Verification: the reconcile run, the projection test, `test-reconcile` passes, and a grep of reconcile.R for the independent column list.
  - Commit: `Reconciliation on SDMX-CSV 2.1; projection test against 0.2.0 data`.

WP4a then depends on WP3b, and WP9a and WP7 on WP3a.

### R-F-6
Severity: major
Where: plan.md WP3 verification, lines 375 to 383
Claim: three WP3 checks cannot be run by a fresh verifier from the check text alone, and one uses the wrong field.
Evidence:
- (a) "equals the 37-column header of 2.3 exactly": handover step 4 gives the verifier only the verification list, and 2.3 shows the header wrapped over five lines (plan.md:108-112).
- (b) "the report says every cell matches (grep for the mismatch count line)" gives no pattern. The report writes `- %s / %s: %s = %d` lines with results `MISMATCH, MISSING_ROW, DUPLICATE_ROW, WITHHELD_PRESENT, ASSERT_FAIL` (pipeline/R/reconcile.R:572-573, 585).
- (c) `grep -c ... data/*_manifest.csv` over two files prints two `file:n` lines, not "2".
- (d) `$36=="O"`: OBS_STATUS is field 35 (established).
Fix:
- (a) Paste the header on one line: `STRUCTURE,STRUCTURE_ID,ACTION,FREQ,REF_AREA,GEO,ESTIMATION,INDICATOR,SEX,AGE,URBANISATION,COMP_BREAKDOWN_1,COMP_BREAKDOWN_2,COMP_BREAKDOWN_3,COMP_BREAKDOWN_4,COMP_BREAKDOWN_5,MEASURE_QUAL_1,MEASURE_QUAL_2,MEASURE_QUAL_3,MEASURE_QUAL_4,MEASURE_QUAL_5,TIME_PERIOD,OBS_VALUE,STD_ERR,CI_LOWER,CI_UPPER,N_OBS,N_POP,N_OBS_NUM,DEFF,DF,SERIES_ID,UNIT_MEASURE,PRECISION,OBS_STATUS,SOURCE_ID,OBS_COMMENT`.
- (b) "exits 0 and `grep -cE ': (MISMATCH|MISSING_ROW|DUPLICATE_ROW|WITHHELD_PRESENT|ASSERT_FAIL) = [1-9]' tmp/wp3-reconciliation.md` is 0".
- (c) `cat data/*_manifest.csv | grep -c "^structure_id,WB.AFW360:AFW360_HH(0.3.0)$"` is 2, and `cat data/*_manifest.csv | grep -c "^dataflow,"` is 0.
- (d) `awk -F, 'NR>1 && $35=="O"' data/AFW360_HH_GNB_2021_SURVEY.csv | wc -l` is 39. Today 39 GNB rows have OBS_STATUS `O` (field 24) and none are `M`.

### R-F-7
Severity: major
Where: plan.md section 3 conventions, line 283, against WP3 line 381 and WP4a line 395
Claim: the baseline says tests and the validator stay green "from WP3 on", but WP3 accepts validator-test failures and WP4a accepts `CODES`, `VALUE`, `RULE` and `META` errors.
Evidence: plan.md:283; :381 "remaining failures only in validator tests"; :395.
Fix: line 283: "Baseline checks that must stay green from WP4b on (WP3 and WP4a may leave only the failures and errors their verification lists name): ...".

### R-F-8
Severity: major
Where: plan.md WP5a deliverables and verification, lines 415 to 428
Claim: WP5a creates or changes 35 files and has 11 verification checks, which breaks rules 2 and 3. Downloading the 30 schemas is also a separate, mechanical concern.
Evidence:
- `curl --ssl-no-revoke -s "https://api.github.com/repos/sdmx-twg/sdmx-ml/contents/schemas?ref=v3.1.0" | grep -c '"name"'` gives 30 (29 `SDMX*.xsd` plus `xml.xsd`).
- The other files: the xsd README, sdmx_xml.R (~200 lines), sdmx_structures.R part 1 (~250), build_sdmx.R (~100), the test (~120), sdmx/README.md (~40), and the generated XML.
- The 11 checks: build, `--check`, lxml, Codelist count, `_T`, AFW_STATUS, GLOBAL_CODE, agency scheme, Agency AFW360, tests, sha256.
Fix: split.
- **WP5a1 Vendored SDMX-ML 3.1.0 schemas (Sonnet).**
  - Depends on: WP0.
  - Deliverables: `pipeline/xsd/sdmx-ml-3.1/` (the 30 files listed by the GitHub contents API at `ref=v3.1.0`) and its README (tag, date, licence).
  - Verification: `ls pipeline/xsd/sdmx-ml-3.1/*.xsd | wc -l` is 30; `grep -c "v3.1.0" pipeline/xsd/sdmx-ml-3.1/README.md` is at least 1; `sha256sum pipeline/xsd/sdmx-ml-3.1/SDMXMessage.xsd` equals the hash of `curl --ssl-no-revoke -s https://raw.githubusercontent.com/sdmx-twg/sdmx-ml/v3.1.0/schemas/SDMXMessage.xsd | sha256sum`.
  - Commit: `Vendor SDMX-ML 3.1.0 XSDs`.
- **WP5a** keeps deliverables 2 to 5 and depends on WP5a1, WP2 and WP7.
- Move deliverable 6 (`sdmx/README.md`) to WP5c, the first WP where `sdmx/` is complete.
- Merge the agency-scheme and Agency greps into one check.
- Replace "AFW_STATUS at least the total number of codes" (no total is given) with a count against a stated source.
- Give the codelist-count command: `grep -c "<str:Codelist " sdmx/structures/AFW360_structures.xml` equals `awk -F, 'NR>1 && $2=="Codelist"' metadata/structure/ARTEFACTS.csv | wc -l`. Uncertain: that the `artefact_type` value is literally `Codelist`; ARTEFACTS.csv does not exist yet, and WP2 defines it.
- State in section 3 that generated files (data, XML) do not count toward the 800-line output budget.

### R-F-9
Severity: major
Where: plan.md WP5a Depends-on, line 413, and context, line 415; section 4, lines 606-607; PROGRESS.md WP5a row
Claim: WP5a reads line ranges of `pipeline/R/io.R`, which WP3 rewrites. With "Depends on: WP2" (plan and PROGRESS.md), the orchestrator may run WP5a during WP3, while section 4 draws WP5a after WP3.
Evidence: plan.md:413 against :607 (`\-> WP5a || WP7 || WP9a` under WP3); PROGRESS.md WP5a "WP2"; WP3 deliverable 1 edits io.R. The line ranges 1-60 and 175-206 are counted on today's 206-line file.
Fix: WP5a "Depends on: WP3a (io.R stable), WP5a1, WP7". Replace the line ranges with "`grep -n "^[a-z_.]* <- function" pipeline/R/io.R`, then the bodies of the CSV read and write helpers".

### R-F-10
Severity: major
Where: plan.md WP5b verification, line 452
Claim: WP5b is self-contained for the MSD design (2.7 is pasted), but its URN-resolution check asks the verifier to write code ("a short Python or R one-liner is acceptable"), which is not an objective check.
Evidence: plan.md:452.
Fix: add `tools/verify/check_urns.py <xml>` (prints `unresolved: <n>`) to WP7's deliverables, and change the check to "`tools/verify/.venv/Scripts/python tools/verify/check_urns.py sdmx/structures/AFW360_structures.xml` prints `unresolved: 0`". WP7 then has 7 files (README, requirements, verify_sdmx.py, xsd_validate.py, check_urns.py and two venv scripts).

### R-F-11
Severity: major
Where: plan.md WP5d, lines 470 to 476
Claim: WP5d is not self-contained, one check cannot produce its expected result, and one deliverable is ambiguous.
Evidence:
- (a) `vc_sdmx_stale` must regenerate `sdmx/`, but `build_sdmx.R` and `sdmx_refmeta.R` are not in context. `vc_sdmx_csv_header` needs the column helpers WP3 adds to constants.R and io.R, which are not in context either.
- (b) "touch a codelist CSV name and confirm `SDMX.STALE`": `touch` changes only the mtime, and the check compares content ("regenerate to temp, compare").
- (c) "the standard's validation section gains the four check ids (recorded as a surfaced point for WP10)" does not say whether WP5d edits `.docs/data-standard.qmd`.
Fix:
- Context: add "`pipeline/build_sdmx.R` (whole); `grep -n "data_columns\|structure_id" pipeline/R/constants.R pipeline/R/io.R`".
- Check: "copy `metadata/`, `data/` and `sdmx/` to `tmp/wp5d-root/`, change one `name_en` value in `tmp/wp5d-root/metadata/codelists/CL_SEX.csv`, run `Rscript pipeline/validate.R --root tmp/wp5d-root --out tmp/wp5d-stale.csv`, and `grep -c "SDMX.STALE" tmp/wp5d-stale.csv` is at least 1".
- Deliverable: "WP5d does not edit `.docs/data-standard.qmd`; it lists the four check ids as a surfaced point".

### R-F-12
Severity: major
Where: plan.md WP6, lines 486 and 488
Claim: the verification calls `import_sdmx.R ... --out-root tmp/rt2`, but the deliverable's CLI has no `--out-root`. The column order comes from `COLUMNS.csv`, which is not in the context list.
Evidence: plan.md:486 `pipeline/import_sdmx.R --root . [--diff | --apply] <structure-message.xml>`; :488 uses `--out-root tmp/rt2`.
Fix:
- Deliverable CLI: `pipeline/import_sdmx.R --root . [--out-root <dir>] [--diff | --apply] <structure-message.xml>`.
- Context: add "`grep -n "codelists/\|ARTEFACTS" metadata/structure/COLUMNS.csv`".
- Add a check: `diff tmp/rt2/metadata/structure/ARTEFACTS.csv metadata/structure/ARTEFACTS.csv` is empty. The write-back of ARTEFACTS.csv is currently unchecked.

### R-F-13
Severity: major
Where: plan.md WP9a deliverables, line 498
Claim: the loader test mixes a second concern (re-implementing the legacy label and column mapping in Python) with files outside its context. It also sits in the wrong venv's folder, and the `requirements.txt` it names does not exist.
Evidence:
- `ls metadata/plans/` gives LEGACY_COLUMNS.csv, LEGACY_LABELS.csv, LEGACY_OVERRIDES.csv, SERIES_PLAN.csv and TAB_PLAN.csv. The legacy files exist but are not in WP9a's context list, and the overrides that reconcile.R needs (pipeline/R/reconcile.R:44) are not mentioned.
- `ls requirements*.txt` at the root gives "No such file".
- `tools/verify/` holds WP7's pysdmx venv, and WP7 runs in parallel. test_loader runs in `.venv`.
Fix:
- Replace the Excel clause with "`load_data('SEN')` values equal those read directly with `pandas.read_csv` for three named `SERIES_ID`/`GEO` pairs (listed in the check). The Excel equivalence is already proven by `reconcile.R` (WP3b)."
- Move the test to `afw360/tests/test_loader.py`.
- Replace "`requirements.txt` updated if needed" with either "root `requirements.txt` created for Posit Connect, listing pandas, geopandas and matplotlib at the `.venv` versions" or "no requirements file is created", whichever the data lead decides.

### R-F-14
Severity: major
Where: plan.md WP9b, lines 508 and 510
Claim: the regression script cannot run in `.venv`, two checks are not objective, and a fresh verifier cannot confirm the before-snapshot.
Evidence:
- `pandas.read_html` needs lxml or bs4 with html5lib, and the pip-list grep above shows none installed.
- "spot-check three values" names no values.
- "the implementer's before/after comparison script" gives no path.
- `tmp/before-sen.csv` is produced by the implementer before editing, so the verifier cannot reproduce it.
Fix:
- Deliverable: "`tools/dashboard_numbers.py <html> <out.csv>` extracts every numeric table cell of the Senegal section with the standard library's `html.parser` (no new dependency), and `--compare a.csv b.csv` prints `differences: <n>`."
- Check: "render the pre-WP9b commit in a `git worktree add --detach tmp/before <WP9a commit>` checkout, extract from both `_site/index.html` files, and `--compare` prints `differences: 0`."
- Name the three spot-check values: series id, GEO and the expected displayed string.
- Replace "shows only lines in the Guinea-Bissau or About sections" with "every line number printed is at least the line number of `grep -n '^# Guinea Bissau' index.qmd`".
- No split is needed: the output is 3 files (index.qmd, a loader helper, the script), about 600 changed lines.

### R-F-15
Severity: major
Where: plan.md WP9c verification, line 524
Claim: "three GNB values match" names no values, and the 0.70M and 1.09M expectation cites "the transition summary", which the verifier cannot open. The fiscal-equity deliverable has no check.
Evidence: plan.md:524. Uncertain: I did not check 0.70M and 1.09M against the data.
Fix: give each expected value with the command that produces it, e.g. `awk -F, '$5=="GNB" && $8=="<series>" && $6=="<geo>"' data/AFW360_HH_GNB_2021_SURVEY.csv | cut -d, -f23`, with the three triples written out. Add an objective check that the GNB fiscal-equity card has no `<img>` in the rendered HTML (the exact grep depends on the card markup WP9b produces).

### R-F-16
Severity: major
Where: plan.md WP8b, line 544; WP8c, line 554
Claim: WP8b and WP8c have no context list (rule 4), and WP8c has no "Depends on" line (rule 6). WP8b also mixes the FMR scripts, the guide and the 3.0 contingency, which changes `build_sdmx.R` and `sdmx_xml.R` (rule 5).
Evidence: plan.md:544-552, :554-560.
Fix:
- WP8b context: "`tools/fmr/README.md` (whole); section 2.13 (pasted); `grep -n "args\|--" pipeline/build_sdmx.R`".
- Move the contingency to **WP8b2 SDMX-ML 3.0 output profile (Opus)**:
  - Depends on: WP8b. Run only if FMR rejects the v3_1 namespaces.
  - Files: `pipeline/R/sdmx_xml.R`, `pipeline/build_sdmx.R` and a test file.
  - Verification: `Rscript pipeline/build_sdmx.R --root . --sdmx-ml-version 3.0 --out-root tmp/v30` exits 0, and the FMR import of the resulting file succeeds.
- WP8c: add "Depends on: Gate 2 (defer), WP6. Context: `tools/fmr/README.md`; section 2.13 (pasted)".

### R-F-17
Severity: major
Where: plan.md WP10, lines 568 to 579
Claim: WP10 changes 12 or more files across three concerns (breaking rules 2 and 5). "Fold in every surfaced point" can touch any part of a 111,272-byte standard that is not in context (rule 4). One check requires editing PROGRESS.md, which implementers may not do.
Evidence:
- Files: data-standard.qmd, sdmx-conformance.qmd, transition.qmd, .docs/_quarto.yml, pipeline/README.md, CLAUDE.md, metadata/CHANGELOG.md, sdmx/README.md, .gitattributes, R header comments (several files), build_content.R and figures_text.csv.
- `wc -c .docs/data-standard.qmd` gives 111272.
- handover.md step 2: the implementer "must not edit `PROGRESS.md`".
Fix: split.
- **WP10a Standard final and conformance page (Opus).**
  - Files: data-standard.qmd, sdmx-conformance.qmd, .docs/_quarto.yml.
  - Context: the surfaced points, pasted by the orchestrator, each with the line range of the standard's section it affects.
- **WP10b Project docs (Opus).**
  - Files: transition.qmd, pipeline/README.md, CLAUDE.md, metadata/CHANGELOG.md, sdmx/README.md.
- **WP10c Inventory inconsistencies 8 to 12 (Sonnet).**
  - Files: .gitattributes, the R headers named in R4 section 11, build_content.R, and the figures_text.csv move.

Replace the PROGRESS.md check with "the WP10a report maps each surfaced point number to the standard section that resolves it; the orchestrator marks the points resolved in PROGRESS.md".

### R-F-18
Severity: major
Where: plan.md WP4a, lines 389 to 395; WP4b, lines 401 to 407
Claim: the WP4a and WP4b verification lists name test files and data that are not in their context, and the fault injections do not isolate the check under test.
Evidence:
- WP4a's verification needs the `test-validate-core` structure tests to pass, but that file is not in WP4a's context.
- WP4b's META checks need the `ARTEFACTS.csv` columns (D44, plan.md:233), which are not pasted.
- In WP4a, the missing manifest in `tmp/` alone can trigger "a `STRUCT` error appears".
- WP4b's "`global_urn` without the prefix" gives no way to validate a modified copy of the metadata.
Fix:
- WP4a context: add "`test-validate-core.R` (grep for `STRUCT`)".
- WP4a check: "copy the data file and its manifest to `tmp/`, set `ACTION` to `I` on row 2, run `Rscript pipeline/validate.R --root . --data tmp/<file> --out tmp/f.csv`, and `grep -c 'STRUCT.ACTION' tmp/f.csv` is at least 1" (use the check id WP4a assigns).
- WP4b context: add "`head -3 metadata/structure/ARTEFACTS.csv`".
- WP4b metadata fault: "copy `metadata/` to `tmp/wp4b-root/metadata`, edit one `global_urn`, and run `validate.R --root tmp/wp4b-root --metadata-only --out ...`".

### R-F-19
Severity: major
Where: handover.md "Running a work package", "Context budget for implementers" and "Your role"
Claim: the handover has no procedure for recording a WP split: the orchestrator may edit only PROGRESS.md, and nothing says where the split WP's text lives. It also has no protocol for WP11, a verifier-only WP to which steps 2, 3 and 5 do not apply.
Evidence: handover.md "Your role" ("The only files you edit yourself are `.docs/sdmx-transition/PROGRESS.md`"); the context-budget section ("Split a WP if ... Split along the file lists"); plan.md:583 "Sonnet verifier only; no implementer".
Fix: add under "Context budget for implementers":
"**Recording a split.** When you split a WP (before launch, or after a report shows it ran out of room), keep the parent id and add suffixes (`WP3a`, `WP3b`; `WP5a1`). Write the full text of each new WP (goal, model, depends on, context list, deliverables, constraints, verification list, commit message) under "Plan amendments" in `PROGRESS.md`, with the date and the reason. Add one row per new WP to the work-package table directly under the parent, and set the parent's state to `split`. Do not edit `plan.md`. When you compose prompts for a split WP, use the amendment text in place of the plan section."
Add under "Running a work package":
"**Verifier-only WPs (WP11).** Skip steps 2, 3 and 5. Launch the verifier with the WP text verbatim. On FAIL, record the failing items under "Blocked" and ask the data lead which WP to reopen."
Add `split` to PROGRESS.md's list of states.

### R-F-20
Severity: major
Where: plan.md section 4, lines 605 to 611, against the WP Depends-on lines and PROGRESS.md
Claim: section 4, the WP lines and PROGRESS.md disagree on several dependencies, and some real dependencies appear nowhere.
Evidence:
- WP5a: plan "WP2, WP0"; PROGRESS "WP2"; section 4 places it after WP3.
- WP7: plan "nothing"; PROGRESS blank; section 4 places it after WP3. Its real dependency is WP3 (R-F-4).
- WP5b and WP5c need WP7 (R-F-3), which no source lists.
- WP8b: plan "Gate 2, WP6"; section 4 omits WP6.
- WP8c: the plan has no Depends-on line; PROGRESS says "Gate 2".
- WP3: plan "WP2, Gate 1"; PROGRESS "Gate 1". This is transitively the same (minor).
- WP10: "everything except WP11" includes whichever of WP8b and WP8c never runs.
- There is no cycle, either as written or after the fixes.

Dependency list after the fixes proposed here:
- WP0 -> WP1, WP2, WP5a1
- WP1 + WP2 -> Gate 1 -> WP3a -> WP3b -> WP4a -> WP4b
- WP3a -> WP7, WP9a
- WP3a + WP5a1 + WP7 + WP2 -> WP5a -> WP5b -> WP5c, WP6, WP8a
- WP4b + WP5c -> WP5d
- WP9a -> WP9b -> WP9c
- WP8a -> Gate 2 -> WP8b (also needs WP6) [-> WP8b2], or WP8c (also needs WP6)
- every WP that ran -> WP10a, WP10b, WP10c -> WP11 -> Gate 3

Fix: replace section 4 with
```
WP0 -> (WP1 || WP2 || WP5a1) -> Gate 1 -> WP3a -> WP3b -> WP4a -> WP4b
                                WP3a -> (WP7 || WP9a)
WP7 + WP5a1 -> WP5a -> WP5b -> (WP5c || WP6 || WP8a) ; WP4b + WP5c -> WP5d
WP9a -> WP9b -> WP9c
WP8a -> Gate 2 -> (WP8b [-> WP8b2] | WP8c) ; WP6 -> WP8b, WP8c
all that ran -> (WP10a || WP10b || WP10c) -> WP11 -> Gate 3 -> merge
```
Make every WP's "Depends on" line and the PROGRESS.md column match it. WP10: "Depends on: every WP that ran (WP8b or WP8c, not both)".

### R-F-21
Severity: minor
Where: plan.md WP7 heading, line 432; handover.md step 3
Claim: "Sonnet or Opus" leaves WP7's model open, while handover step 3 only knows "opus (or sonnet where the plan says so)". WP8a (Sonnet) and WP11 (Sonnet verifier) are consistent with the handover.
Evidence: plan.md:432; handover.md step 3.
Fix: change the WP7 heading to "(Sonnet)". The tool is a small script against documented APIs.

### R-F-22
Severity: minor
Where: handover.md "Parallel work"; plan.md section 3 conventions
Claim: the helper-file rule holds as planned: WP3 and WP4a run in sequence, and WP5a runs alongside WP4a but touches different test files. But the plan never says which WP owns the `helper-*.R` files, so the rule cannot be checked in advance.
Evidence: WP3 deliverable 4 edits `helper-data-fixture.R`, and no other WP names a helper. `pipeline/tests/testthat/` has `helper-data-fixture.R` and `helper-temp-root.R`.
Fix: add to plan.md section 3 conventions: "Only WP3a edits `pipeline/tests/testthat/helper-*.R`; any other WP that needs a helper change reports it as a surfaced point."

### R-F-23
Severity: minor
Where: plan.md WP9a, lines 498 and 500; WP7, line 438
Claim: WP9a writes `tools/verify/test_loader.py` into WP7's folder while the two run in parallel. The files differ, but the folder is shared, and the test runs under a different interpreter (`.venv`).
Evidence: plan.md:498; :500 `.venv/Scripts/python -m pytest tools/verify/test_loader.py`.
Fix: see R-F-13 (move the test to `afw360/tests/`).

### R-F-24
Severity: minor
Where: plan.md section 5, lines 620 to 627
Claim: four risk rows name no WP or gate, one row relies on the pysdmx metadata read that is not possible, and missing Python packages are not listed as a risk.
Evidence:
- "SDMX-CSV metadata item-target syntax unconfirmed | pysdmx reads a different target": pysdmx cannot read metadata CSV.
- "TIME_PERIOD not accepted" names no WP.
- "Agent context overrun" and "Test suite runtime" name no WP or gate.
Fix:
- Row 3 signal: "the WP5c field-guide check or FMR (WP8b) rejects the target"; response: "dataflow target fallback (2.7), applied in WP5c; documented".
- Row 4 response: append "confirmed by WP5b's XSD validation".
- Rows 7 and 8: append "(orchestrator; handover.md, context budget)".
- New row: "Python package missing (lxml, bs4) | import error in WP5a or WP9b | lxml only in `tools/verify/.venv` (WP7); the dashboard regression script uses the standard library".

### R-F-25
Severity: major
Where: plan.md section 6 conformance checklist, lines 633 to 648
Claim: no WP verification list contains the evidence for rows 2, 8 and 9, and rows 7, 12 and 14 are covered only in part.
Evidence (for each row, the WP whose verification holds the evidence):
- Row 1: WP5a and WP5b (lxml), WP5d (`vc_sdmx_xsd`), WP11 step 6. OK.
- Row 2: none. `SDMX.URN` (WP5d) checks references, not names, versions or NCName ids.
- Row 3: WP5a (`agencyID="WB" id="AGENCIES"` grep). OK.
- Row 4: WP5b (URN resolution) and WP5d. OK.
- Row 5: WP5b counts, and verify_sdmx reports 1 DSD. OK.
- Row 6: WP4b, WP11 step 3, WP8b. OK.
- Row 7: WP3 header, WP4a `STRUCT`, WP5d `SDMX.CSV_HEADER`, WP7 read. RFC 4180 quoting and UTF-8 have no check.
- Row 8: none. pysdmx cannot read the files (R-F-2), and no WP compares the header paths with the MSD ids.
- Row 9: none. WP5a only checks `GLOBAL_CODE` at least 12.
- Row 10: WP5d (`SDMX.STALE`) and the baseline `build_docs --check`. OK.
- Row 11: WP6. OK.
- Row 12: WP7 and WP11, but only for data and structures (R-F-2).
- Row 13: WP8b. OK.
- Row 14: WP1 greps only D27 and D46.
Fix:
- Row 2: add to WP5d a check `SDMX.IDENT`: "every maintainable has `agencyID` `WB.AFW360` (`WB` for AGENCIES), a version matching `^[0-9]+\.[0-9]+\.[0-9]+$`, an id matching the XSD `IDType`, and a `com:Name xml:lang="en"`". Evidence: "`SDMX.IDENT` has zero findings".
- Row 8: evidence "the `verify_sdmx.py` header check (R-F-2)".
- Row 9: add to WP5a's verification "`grep -c 'GLOBAL_CODE' sdmx/structures/AFW360_structures.xml` equals the number of non-empty `global_urn` cells across `metadata/codelists/CL_*.csv` plus the number of sentinel codes". Uncertain: the exact counting command depends on the position of the `global_urn` column, which WP2 sets. Give it once WP2 is committed.
- Row 7: add to WP4a "`grep -c $'\r' data/*.csv` is 0 for each file, and `iconv -f UTF-8 -t UTF-8 data/*.csv > /dev/null` exits 0".
- Row 14: add to WP10a "`for d in $(seq 27 46); do grep -q "D$d" .docs/data-standard.qmd || echo missing D$d; done` prints nothing".

### R-F-26
Severity: minor
Where: PROGRESS.md environment table
Claim: versions and dates share one column ("1.10.18 (2026-09-29)" under "Version seen", with Date empty), and the Python packages the plan needs are not recorded.
Evidence: PROGRESS.md environment rows.
Fix: put the date in the Date column; add the rows "lxml (.venv) | not installed | 2026-09-29" and "tools/verify venv | (created in WP7) |".

### R-F-27
Severity: minor
Where: PROGRESS.md work-package table
Claim: the table lists exactly the plan's WPs and gates, in an order compatible with section 4. Its Depends-on column carries the mismatches of R-F-20 (WP5a, WP7, WP3).
Evidence: PROGRESS.md table: WP5a "WP2", WP7 blank, WP3 "Gate 1".
Fix: update the column as in R-F-20, and add rows for the split WPs (WP3a, WP3b, WP5a1, WP8b2, WP10a, WP10b, WP10c) through the amendment procedure of R-F-19.

### R-F-28
Severity: minor
Where: plan.md WP5c context, line 460
Claim: the paths `registries/SOURCES.csv` and `registries/FIGURES.csv` omit the `metadata/` prefix, while `content/TEXT.csv` is written relative to the root.
Evidence: the files exist at `metadata/registries/SOURCES.csv`, `metadata/registries/FIGURES.csv` and `content/TEXT.csv` (`wc -c` succeeded on all three).
Fix: write `metadata/registries/SOURCES.csv` and `metadata/registries/FIGURES.csv`.

### R-F-29
Severity: minor
Where: plan.md WP10 context, line 566
Claim: the WP10 implementer is told to read `PROGRESS.md`, which is the orchestrator's working file. Reading it is not forbidden, but its content changes between runs.
Evidence: handover.md step 2 (the implementer must not edit PROGRESS.md and must not read outside its context list).
Fix: "The orchestrator pastes the 'Surfaced points' table from `PROGRESS.md`."

## Verified OK

- `wc -l data/*.csv`: SEN 3004, GNB 2269 (confirmed). `awk -F, 'NR>1 && $24=="O"'` gives 39 GNB rows and 0 SEN rows; there are no `M` rows.
- WP9a's expected shape: 37 - 3 = 34 columns; 3003 and 2268 rows match the line counts.
- The `git show a32096c:data/...` target exists (`a32096c Merge branch 'standard/v0.5' into dev/eb`; its header starts `DATAFLOW,`).
- The CLIs that the checks use exist: `validate.R --root/--data/--out/--metadata-only`, `reconcile.R --root --out`, `convert_legacy.R --root --country --timestamp --out-root`, `build_docs.R --check`.
- The converter does not source ctx.R or plan.R (convert_legacy.R:29-33), so WP3 does not depend on WP4a's files.
- Self-containment:
  - WP3's rules (D38, D39, D46) are restated in 2.3 (plan.md:121-124).
  - WP5a's sentinel rule (D42) and derived codelists (D43) are restated in 2.5 (plan.md:186-188).
  - WP5b has 2.7 pasted for the MSD design.
- `geo/boundaries/SEN_CODAB_v02.gpkg`, `geo/boundaries/GNB_CODAB_V01.gpkg`, `metadata/plans/LEGACY_LABELS.csv` and `metadata/plans/LEGACY_COLUMNS.csv` exist.
- `index.qmd` sections: Senegal 184-719, Guinea Bissau 720-1176, About 1177-1195. WP9b's range 1-720 is 20559 bytes, well within budget.
- The root `_quarto.yml` has an explicit render list (`index.qmd` only), so a root render does not pick up a worktree under `tmp/`.
- Parallel file sets:
  - WP5c, WP6 and WP8a are disjoint.
  - `build_sdmx.R` edits run in sequence (WP5a, then WP5b, then WP5c; WP8b later).
  - CLAUDE.md (WP9c, then WP10) and sdmx/README.md (WP5a, then WP10) are edited in sequence.
  - WP5d's `validate.R` edit comes after WP4a's.
- There is no dependency cycle.
- WP8a (Sonnet) and WP11 (Sonnet) match the handover. Every WP except WP11 has a commit message, and WP11 needs none.
- Verification counts are at most 10 for every WP except WP5a (11; R-F-8): WP3 9, WP4a 3, WP4b 4, WP5b about 10, WP5c 5, WP5d 4, WP6 3, WP7 2, WP9a 2, WP9b 4, WP9c 4, WP8a 3, WP8b 5, WP8c 3, WP10 5, WP11 9.

## Not checked

- WP1 and WP2 file lists (outside my line range). I did not check whether WP2's regeneration of the generated `.docs` tables races with WP1's render while the two run in parallel.
- Whether the output of `build_geo.R` (GeoPackage, SQLite) is byte-deterministic, as WP11 step 1 requires. Uncertain.
- The GNB 0.70M and 1.09M figures against the data.
- The rendered content of the pysdmx documentation pages (sizes only).
