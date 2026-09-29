# R-E: work-package executability, WP0, WP1, WP2, Gate 1

Reviewer R-E. Scope: plan.md 275-357, the sections WP1/WP2 paste, handover.md. Commands run from the repository root in Git Bash.

## Size arithmetic (bytes / 4 = tokens)

WP1 input: sections 1-2 `sed -n '27,274p'` 28,265 + preamble (275-284) 1,564 + WP1 (292-322) 2,906 + handover-derived rules ~2,000 + R4 s9 (632-763) 10,804 + R4 s11 (789-811) 3,105 + data-standard.qmd ranges it must open (1-36, 98-185, 207-291, 398-408, 477-488, 762-786, 884-924, 968-991 = 35,854, plus the stale lines at 574, 695, 847, 988-1031 ~8,000) = ~92,500 bytes = ~23k tokens. Whole qmd read instead (111,272 bytes): ~160k bytes = 40k tokens, at the limit. Rule 1 passes only if sections are read by range.
WP1 output: one file; new chapter ~150-180 lines, other edits ~100 lines. Rule 2 passes.

WP2 input: preamble 1,564 + WP2 (323-353) 3,329 + 2.4/2.5/2.9/2.10 8,349 + handover rules ~2,000 + migrate.R 1-120 5,198 + README/test/DSD/6 codelists 16,178 + docs.R 200-290 3,448 + io.R 175-206 1,288 + COLUMNS rows (7 DSD rows 568 bytes, CL_AGE rows 535) = ~41,900 bytes = ~10.5k tokens. Rule 1 passes on paper, but the global-list fetches (2.9) are unbounded (R-E-12) and the missing context (R-E-2, R-E-3, R-E-4) adds ~15k bytes.
WP2 output: fixture 34 files / 1,251 lines (`git ls-files metadata | wc -l` = 34; `cat $(git ls-files metadata) | wc -l` = 1251); migrate.R (the 0.2.0 one is 687 lines), README, test; metadata: DSD, ARTEFACTS (new), COLUMNS, 17 codelists edited (every row gains a column; 302 codelist lines in total), CL_UNIT deleted, CL_UNIT_MEASURE and CL_FREQ created, VERSION, CHANGELOG; docs.R, io.R, test-docs.R (needed, R-E-2); 2+ generated fragments. About 68 files and ~2,500 changed lines (~1,250 without the fixture). Rules 2 and 5 broken (R-E-5).

## Findings

### R-E-1
Severity: major
Where: plan.md section 3 WP0, line 287; handover.md "Setup, once" item 1
Claim: WP0 cannot run as written, and the handover makes the orchestrator skip it, so `tmp/` and the XML line-ending rule are never created.
Evidence: `git branch --show-current` -> `standard/v0.6-sdmx` (branch exists, so `git checkout -b standard/v0.6-sdmx dev/eb` fails with "already exists"); handover.md: "If the branch does not exist, do WP0 from the plan"; `grep -n tmp .gitignore` -> nothing; `grep -n xml .gitattributes` -> nothing; `ls tmp` -> "No such file or directory". Every later `> tmp/<wp>.log` redirect then fails.
Fix: WP0 first bullet: "If `standard/v0.6-sdmx` exists, `git checkout standard/v0.6-sdmx`; otherwise `git checkout -b standard/v0.6-sdmx dev/eb`." Handover item 1: "Then run WP0 unless PROGRESS.md marks it committed (the branch may already exist)." Add WP0 check: `grep -qx 'tmp/' .gitignore && grep -q '^\*\.xml text eol=lf' .gitattributes && test -d tmp && echo OK` prints OK.

### R-E-2
Severity: blocker
Where: plan.md WP2, verification bullet 5 (line ~346) and context list (line 327)
Claim: WP2 must make `test-docs` pass, but `test-docs.R` hard-codes 31 rows and `DATAFLOW`, is not in WP2's context or deliverables, and 2.11 assigns `test-docs` to WP3.
Evidence: `pipeline/tests/testthat/test-docs.R:50` "tbl-columns has one row per data-file column, positions 1 to 31"; `:55` `expect_length(rows, 31)`; `:57` `expect_match(rows[1], "^\\| 1 \\| `DATAFLOW` \\|")`; plan.md 2.11 line 244 lists `test-docs` among the WP3 test lines.
Fix: add `pipeline/tests/testthat/test-docs.R` lines 45-90 to the context and deliverables of the WP that changes docs.R (WP2c in the split below) with "update the tbl-columns test to the new DSD row count and first row `FREQ`"; remove `test-docs` from the 2.11 list.

### R-E-3
Severity: major
Where: plan.md WP2 context, line 327 ("`pipeline/R/docs.R` lines 200 to 290")
Claim: `docs.R` names `CL_UNIT` outside the given range, so `build_docs.R --check` fails after the rename unless the implementer reads outside its context.
Evidence: `grep -n CL_UNIT pipeline/R/docs.R` -> `34:  "CL_THEME", "CL_STAT_UNIT", "CL_STATISTIC", "CL_WEIGHT", "CL_UNIT"` and `228:  CL_UNIT = "metadata/codelists/CL_UNIT.csv"`.
Fix: context "`pipeline/R/docs.R` lines 28 to 36 and 200 to 290".

### R-E-4
Severity: blocker
Where: plan.md WP2 context (line 327) and deliverable 6 (line 337); 2.10 items 2 and 6
Claim: The pasted sections do not name most of the artefacts ARTEFACTS.csv must list, nor the decisions the CHANGELOG entry must list, so the implementer cannot write either without unpasted plan sections (rule 4).
Evidence: 2.10 item 2 says "one row per artefact of 2.4 to 2.8 ... and the `WB:AGENCIES` scheme"; `CS_AFW360` (2.6), `MSD_AFW360`, `MDF_AFW360`, `METADATA_PROVIDERS`, `MPA_AFW360` (2.7), `DATA_PROVIDERS`, `PA_AFW360_HH` (2.8) and the `AGENCIES` scheme (2.1) appear only in sections not pasted; 2.10 item 6 "CHANGELOG.md gains the 0.3.0 entry listing D27 to D46" needs section 1, not pasted. No vocabulary is given for `artefact_type`, for `agency_id` of `AGENCIES` (`WB`, not `WB.AFW360`), or for `source_file` of artefacts with no CSV.
Fix: in WP2 (WP2a in the split) paste section 1 rows D27-D46 (id and first sentence each) and add to the WP text: "ARTEFACTS.csv has exactly 33 rows: AGENCIES (AgencyScheme, agency WB), CS_AFW360 (ConceptScheme), DSD_AFW360_HH (DataStructure), AFW360_HH (Dataflow), MSD_AFW360 (MetadataStructure), MDF_AFW360 (Metadataflow), METADATA_PROVIDERS (MetadataProviderScheme), MPA_AFW360 (MetadataProvisionAgreement), DATA_PROVIDERS (DataProviderScheme), PA_AFW360_HH (ProvisionAgreement), the 19 CSV codelists after migration, and CL_SERIES, CL_SOURCE, CL_SURVEY, CL_FIGURE (Codelist, source_file = the plan or registry they derive from). artefact_type uses the SDMX class names above." Uncertain: the count 33 is my derivation from 2.1 and 2.5-2.8; the lead should confirm no artefact is missing.

### R-E-5
Severity: blocker
Where: plan.md WP2, lines 323-353
Claim: WP2 breaks rule 2 (about 68 files and ~2,500 changed lines; ~1,250 without the fixture) and rule 5 (it mixes content research, a migration script, its test, a docs generator and regenerated docs).
Evidence: see "Size arithmetic" above.
Fix: split into WP2a, WP2b, WP2c (proposal at the end of this report). Treat the fixture as one mechanical deliverable verified by byte identity and not counted in the line budget.

### R-E-6
Severity: major
Where: plan.md WP2 deliverable 1 (line 332) and verification bullet 6
Claim: The fixture layout and the migration's output convention are not stated, and under the 0.2.0 convention `diff -r tmp/mig/metadata metadata` can never be empty.
Evidence: `pipeline/migrations/0.2.0/migrate.R:11-12` "Only the files the migration creates or rewrites are written"; 0.3.0 does not touch `plans/TAB_PLAN.csv`, `rules/RULES.csv` and others (`grep -rln "CL_UNIT\b" metadata` -> only `COLUMNS.csv` and `DSD_AFW360_HH.csv`), so they would show as "Only in metadata". The existing fixture is a root, not a metadata copy: `ls pipeline/tests/testthat/fixtures/metadata-0.1.0` -> `data_raw metadata`; deliverable 1 says "frozen copy of the current `metadata/`" at `fixtures/metadata-0.2.0/`, while the check runs `--root pipeline/tests/testthat/fixtures/metadata-0.2.0`.
Fix: deliverable 1: "`pipeline/tests/testthat/fixtures/metadata-0.2.0/metadata/`: byte copy of every tracked file under `metadata/` at commit e24b664 (34 files)." Deliverable 2 add: "With `--out-root`, the script first copies every file of `<root>/metadata` to `<out-root>/metadata`, then applies the changes, so the out-root holds the complete 0.3.0 metadata." Add check: `for f in $(git ls-tree -r --name-only e24b664 metadata); do git show e24b664:$f | cmp -s - pipeline/tests/testthat/fixtures/metadata-0.2.0/$f || echo DIFF $f; done` prints nothing.

### R-E-7
Severity: major
Where: plan.md 2.10 item 3 (line 234) and WP2 verification bullet 3
Claim: The check text says every codelist header "ends with" `notes,global_urn`, which contradicts 2.10 ("after `notes`") for 10 of 18 codelists; the command is a substring grep, so the position of `global_urn` stays ambiguous.
Evidence: `for f in metadata/codelists/CL_*.csv; do head -1 $f | tr -d '\r' | awk -F, '{print $NF}'; done | sort | uniq -c` -> 8 end in `notes`; the others end in `admits_se`, `order` (2), `owner` (3), `parent`, `partition`, `valid_to`, `wb_region`. Confirmed: `CL_AREA.csv` header `...,notes,iso2,currency,wb_region`; `CL_COMP_BREAKDOWN.csv` `...,notes,var_code,parent,order`. Note: `rev` is not installed in this Git Bash; use awk.
Fix: 2.10 item 3: "`global_urn` (status `O`) inserted as column 8, immediately after `notes` (column 7), in every codelist; later columns shift by one and their COLUMNS.csv positions are renumbered." Check: `for f in metadata/codelists/CL_*.csv; do head -1 "$f" | tr -d '\r' | cut -d, -f7,8 | grep -qx 'notes,global_urn' || echo "BAD $f"; done` prints nothing, and `ls metadata/codelists/CL_*.csv | wc -l` is 19.

### R-E-8
Severity: major
Where: plan.md WP2 verification bullet 4
Claim: "run the small R check the implementer provides, or replicate" is not an objective check (rule 3), and COLUMNS.csv also declares files outside `metadata/`.
Evidence: `cut -d, -f1 metadata/structure/COLUMNS.csv | sort -u` includes `FIGURES.csv`, `GEO_SOURCES.csv`, `TEXT.csv`.
Fix: replace with: `Rscript -e 'c<-read.csv("metadata/structure/COLUMNS.csv",colClasses="character");b<-0;for(f in unique(c$file)){p<-list.files(c("metadata","content","geo"),pattern=paste0("^",f,"$"),recursive=TRUE,full.names=TRUE);if(length(p)!=1){cat("NOFILE",f,"\n");b<-b+1;next};h<-names(read.csv(p[1],nrows=1,check.names=FALSE));r<-c[c$file==f,];if(!identical(h,r$column[order(as.integer(r$position))])){cat("MISMATCH",f,"\n");b<-b+1}};cat("bad",b,"\n")'` prints `bad 0`.

### R-E-9
Severity: major
Where: plan.md WP2 verification bullet 5
Claim: "shows only failures attributable to the not-yet-migrated converter/validator tests" is a judgement a fresh verifier cannot settle.
Evidence: breakages outside WP2 scope are certain, e.g. `pipeline/tests/testthat/test-validate-core.R:330` edits `CL_UNIT.csv`; `pipeline/R/validate_metadata.R:234` checks against `CL_UNIT`.
Fix: test only the files the WP owns: `for t in test-migrate-0.3.0 test-migrate-0.2.0; do Rscript -e "r<-as.data.frame(testthat::test_file('pipeline/tests/testthat/$t.R'));cat('$t',sum(r\$failed),sum(r\$error),'\n')"; done` prints `0 0` for each. Record the full-suite failure list in PROGRESS.md as information, not as a pass criterion.

### R-E-10
Severity: minor
Where: plan.md WP2 verification bullets 1, 2 and 7
Claim: Three checks are not runnable by a fresh verifier without the plan: "equals the column list of 2.10 item 1", "at least 25 rows" (weak), and "Running the migration on the live root exits 1" (no command).
Evidence: the DSD table in 2.4 does give 18 dimension, 1 time_dimension, 9 measure and 6 attribute rows = 34 (positions 1-8 and 9-18; 19; 20-28; 29-34), so `wc -l` 35 and the grep counts are right; `,dimension,` does not match `,time_dimension,` or `dimensions:`.
Fix: bullet 2: `head -1 metadata/structure/DSD_AFW360_HH.csv | tr -d '\r'` equals `position,id,component,role,name_en,codelist,data_type,usage,relationship,measure_relationship,required,sentinel,min_value,max_value,description`. Bullet 1: `tail -n +2 metadata/structure/ARTEFACTS.csv | wc -l` is 33 (see R-E-4). Bullet 7: `Rscript pipeline/migrations/0.3.0/migrate.R --root . --out-root tmp/mig-guard > tmp/mig-guard.log 2>&1; echo $?` prints 1; `grep -c "not 0.2.0" tmp/mig-guard.log` is at least 1; `test ! -e tmp/mig-guard/metadata && echo OK` prints OK.

### R-E-11
Severity: minor
Where: plan.md 2.10 item 5 (line 237) and WP2 verification bullet 9
Claim: 2.10 says `RULES.csv` and `SERIES_PLAN.csv` reference `CL_UNIT`; they do not, and the check's "except historical CHANGELOG lines" is a judgement.
Evidence: `grep -rln "CL_UNIT\b" metadata` -> `metadata/structure/COLUMNS.csv`, `metadata/structure/DSD_AFW360_HH.csv` only.
Fix: item 5: "Every reference to `CL_UNIT` in `COLUMNS.csv` and `DSD_AFW360_HH.csv` becomes `CL_UNIT_MEASURE`." Check: `grep -rnw CL_UNIT metadata --include='*.csv'` prints nothing.

### R-E-12
Severity: major
Where: plan.md 2.9 (lines 216-229), used by WP2
Claim: The plan does not say that the global alignment must be embedded in the migration rather than fetched at run time, gives a fetch URL only for CL_AGE, and leaves the fetch output size unbounded in the implementer's context.
Evidence: 2.9 rows CL_OBS_STATUS(2.3), CL_UNIT_MEASURE(1.20), CL_QUANTILE(1.1), CL_FREQ(2.1) have no URL; 2.10 requires deterministic, byte-identical output, which a run-time network fetch cannot guarantee.
Fix: add to 2.9: "The implementer fetches each global list once with `curl --ssl-no-revoke -H 'Accept: application/vnd.sdmx.structure+json;version=2.0.0' https://registry.sdmx.org/sdmx/v2/structure/codelist/<AGENCY>/<ID>/<VERSION> -o tmp/<ID>.json`, reads only the ids and names it needs with grep, and commits the result as `pipeline/migrations/0.3.0/inputs/ALIGNMENT.csv` (codelist, code_0_2_0, code_0_3_0, name_en, global_urn). The migration reads that table and makes no network call." Uncertain: I did not fetch the lists to confirm each URL resolves.

### R-E-13
Severity: minor
Where: plan.md 2.5 "Sentinels" (line ~184) vs 2.9 CL_AREA row (line 226)
Claim: Two forms are used for the global reference: short `SDMX:CL_SEX(2.1)._T` in 2.5 and the full URN in 2.9, while the column is named `global_urn`.
Evidence: 2.5 "carries `GLOBAL_CODE` pointing at `SDMX:CL_SEX(2.1)._T`"; 2.9 "`global_urn` = `urn:sdmx:org.sdmx.infomodel.codelist.Code=WB:CL_REF_AREA_WDI(1.0).SEN`".
Fix: 2.5: "pointing at `urn:sdmx:org.sdmx.infomodel.codelist.Code=SDMX:CL_SEX(2.1)._T` (or `._Z`)"; 2.9 add "Every `global_urn` is a full code URN."

### R-E-14
Severity: major
Where: plan.md WP1 verification bullet 3 (line ~314) and deliverable 6
Claim: The layout check is vacuous: it misses both tree entries it is meant to catch.
Evidence: `grep -n "acceptance\|derived/" .docs/data-standard.qmd` -> `122:  acceptance/ ...`, `170:  derived/ ...`, `695:` (`geo/derived/`), `1003:` (D11 history row). The plan's pattern `pipeline/acceptance\|geo/derived` matches only line 695.
Fix: check `grep -n "acceptance/\|derived/" .docs/data-standard.qmd | grep -v "planned" | grep -v "^1003:"` prints nothing. Deliverable 6 add "and line 695 in `## Storage`".

### R-E-15
Severity: major
Where: plan.md WP1 deliverables 2 and 8, verification bullet 4
Claim: "31 columns must be gone" conflicts with the historical D26 row, and two stale statements lie outside the deliverables list.
Evidence: `grep -n "31 columns\|DATAFLOW" .docs/data-standard.qmd` -> `217` (Columns, listed), `574:` "with the 31 columns of @tbl-columns" (# What a producer delivers), `847:` "sorted by the 19 key columns (@tbl-columns, `DATAFLOW` through `MEASURE_QUAL_5`)" (# Validation checks), `988:| D26 | The data file has 31 columns ...` (Changes since v0.4, history). Only 217 is in a listed section.
Fix: deliverable 2 add "and the same statements in `# What a producer delivers` item 1 and the key-sort rule in `# Validation checks`". Check: `grep -n "31 columns\|DATAFLOW through\|DATAFLOW=AFW360_HH" .docs/data-standard.qmd | grep -v "^988:"` prints nothing (history rows stay).

### R-E-16
Severity: major
Where: plan.md WP1 verification bullets 1, 2, 6
Claim: Bullets 1 and 2 use one grep with alternation, which cannot show that each term is present; bullet 6 is a judgement, not a check (rule 3); nothing checks the new subtitle.
Evidence: `grep -c "D27\|D46" .docs/data-standard.qmd` counts lines matching either term (0 today; 1 with only D27 present).
Fix: bullet 1: `for t in D27 D38 D46 sec-sdmx sec-changes-v06 "Draft v0.6 · metadata 0.3.0"; do grep -qF "$t" .docs/data-standard.qmd || echo "MISSING $t"; done` prints nothing. Bullet 2: the same loop over `STRUCTURE_ID NaN FREQ WB.AFW360 CL_UNIT_MEASURE ARTEFACTS.csv`. Bullet 6: move to Gate 1 (the data lead reads the chapter), or replace with `grep -c "^| D[2-4][0-9] |" .docs/data-standard.qmd` rising by 20 (Uncertain: assumes the decisions-table row format `| Dnn |` seen at line 988).

### R-E-17
Severity: major
Where: plan.md WP1 and WP2 "Parallel with", section 4 line 606; handover "Parallel work"
Claim: WP1 and WP2 are not independent in one working tree: WP2's `build_docs.R --check` reads the standard's includes, WP1's render reads `.docs/generated/` while WP2 rewrites it, and the handover's `git status` scope check cannot separate two uncommitted WPs.
Evidence: `pipeline/R/docs.R:527` `standard <- file.path(qmd_dir, "data-standard.qmd")` (include check); WP2 deliverable 5 regenerates `.docs/generated/`; handover step 6 "confirm only files within the WP's scope changed".
Fix: WP1 constraint add "Add no new `{{< include >}}`." Run WP1 in parallel only with WP2a and WP2b (below), which touch neither `.docs/` nor `docs.R`; run WP2c after WP1 is committed. Alternatively launch the parallel implementer with `isolation: "worktree"`.

### R-E-18
Severity: minor
Where: plan.md WP1 context (line 298) and deliverable 1 (line 305)
Claim: The context relies on research/R4 section 9 for line ranges without listing it, and the chapter must point to `fmr-guide.qmd`, which does not exist until a later WP.
Evidence: `grep -n "^## " research/R4_repo_inventory.md` -> section 9 at line 632 (10,804 bytes); `.docs/fmr-guide.qmd` absent.
Fix: context "`research/R4_repo_inventory.md` sections 9 (lines 632-763) and 11 (lines 789-811)". Deliverable 1: "the FMR workflow summary (2.13), naming `fmr-guide.qmd` as planned, without a link".

### R-E-19
Severity: major
Where: plan.md Gate 1, lines 354-357
Claim: Gate 1 gives no commands for the materials, no file for "the global alignment applied", and no rule for turning a veto into a numbered, verified work package.
Evidence: "vetoes become follow-up edits to WP1 and WP2" names no WP id, verifier or PROGRESS row; handover "Gates" records decisions but not how a follow-up edit is run.
Fix: "The orchestrator writes under Gate 1 in PROGRESS.md: `git diff --stat <WP0 hash>..HEAD -- metadata .docs`; the DSD CSV; ARTEFACTS.csv; `pipeline/migrations/0.3.0/inputs/ALIGNMENT.csv`; the new chapter's line range; and the question 'Confirm or veto each of D38 to D46'. The data lead answers per decision. Each veto becomes `WP1-fix` or `WP2-fix` with its own PROGRESS row, run through the normal implementer and verifier cycle; Gate 1 is `approved` only when those rows are `committed`."

### R-E-20
Severity: minor
Where: plan.md section 3 preamble, line 283
Claim: The baseline checks are runnable as written except `tools/verify/verify_sdmx.py`, which names no interpreter; all `tmp/` outputs need WP0 (R-E-1).
Evidence: `pipeline/validate.R:14` usage `--root . ... --out <findings.csv>`, `:46` requires `--out`; `pipeline/build_docs.R:9` `--check`; `pipeline/tests/testthat.R` exists and runs `testthat::test_dir("pipeline/tests/testthat")`.
Fix: "`.venv/Scripts/python tools/verify/verify_sdmx.py` (exit 0)".

### R-E-21
Severity: minor
Where: handover.md "Running a work package" and "Context budget"
Claim: The handover gives no token budget for verifiers, no rule for recording a split, and no single model for WP7 ("Sonnet or Opus").
Evidence: handover.md budgets only implementers ("Every implementer must finish with under 100k tokens"); "Split a WP ... along the file lists" says nothing about ids or PROGRESS rows; plan.md line 432 "WP7 Independent verification tool (Sonnet or Opus)".
Fix: add "Verifiers: under 60k tokens; logs to tmp/, read only tails." Add "A split keeps the id and adds a letter (WP2 -> WP2a, WP2b, WP2c); replace the PROGRESS row with one row per part, update dependents, and note the split under Plan amendments with the date." Set WP7 to Opus (a Sonnet verifier checks it).

## Proposed split of WP2 (parts WP2a, WP2b, WP2c)

Order: WP0 -> (WP1 || (WP2a -> WP2b)) -> WP2c (after WP1 is committed) -> Gate 1. In PROGRESS.md, dependents of WP2 (WP5a, WP9a) depend on WP2c.

### WP2a Alignment and artefact inputs (Opus)
Paste: 2.1, 2.4, 2.5 "Derived codelists" bullet, 2.6 first sentence, 2.7 first three bullets, 2.8, 2.9, 2.10 items 1-4, section 1 rows D32 and D41-D44, the artefact list of R-E-4, the fetch rule of R-E-12. Context: `metadata/codelists/CL_AGE.csv`, `CL_OBS_STATUS.csv`, `CL_UNIT.csv`, `CL_AREA.csv`, `CL_SEX.csv`, `CL_URBANISATION.csv`; `grep "^QUINT" metadata/codelists/CL_COMP_BREAKDOWN.csv`; `head -1` of every `metadata/codelists/CL_*.csv`; `metadata/structure/DSD_AFW360_HH.csv`. About 35k bytes.
Creates (5 files, ~150 lines): `pipeline/migrations/0.3.0/inputs/ALIGNMENT.csv`, `inputs/ARTEFACTS.csv`, `inputs/DSD_AFW360_HH.csv`, `inputs/CL_FREQ.csv`, `inputs/SOURCES.md` (URL, version and fetch date per global list).
Checks (I = `pipeline/migrations/0.3.0/inputs`):
1. `ls I` prints exactly the 5 names.
2. `head -1 I/ARTEFACTS.csv | tr -d '\r'` is `artefact_id,artefact_type,agency_id,source_file,name_en,description_en,status,version_added,notes`; `tail -n +2 I/ARTEFACTS.csv | wc -l` is 33.
3. `for id in AGENCIES CS_AFW360 DSD_AFW360_HH AFW360_HH MSD_AFW360 MDF_AFW360 METADATA_PROVIDERS MPA_AFW360 DATA_PROVIDERS PA_AFW360_HH CL_FREQ CL_UNIT_MEASURE CL_SERIES CL_SOURCE CL_SURVEY CL_FIGURE; do grep -q "^$id," I/ARTEFACTS.csv || echo MISSING $id; done` prints nothing; `cut -d, -f1 I/ARTEFACTS.csv | sort | uniq -d` prints nothing.
4. `Rscript -e 'a<-read.csv("pipeline/migrations/0.3.0/inputs/ARTEFACTS.csv",colClasses="character");cat(sum(a$name_en==""|a$description_en==""))'` prints 0.
5. I/DSD_AFW360_HH.csv: header as in R-E-10; `wc -l` 35; `grep -c ",dimension,"` 18; `grep -c ",time_dimension,"` 1; `grep -c ",measure,"` 9; `grep -c ",attribute,"` 6.
6. `awk -F, 'NR>1 && $5!="" && $5 !~ /^urn:sdmx:org\.sdmx\.infomodel\.codelist\.Code=/' I/ALIGNMENT.csv` prints nothing.
7. `grep -c "^CL_OBS_STATUS," I/ALIGNMENT.csv` is 7; `grep -c "^CL_UNIT_MEASURE,XOF," I/ALIGNMENT.csv` is 1; `grep -c "^CL_AREA," I/ALIGNMENT.csv` is 2.
8. `grep -c "^A," I/CL_FREQ.csv` is 1.
9. `git status --short` lists only paths under `pipeline/migrations/0.3.0/inputs/`.
Commit: `Metadata 0.3.0 inputs: global alignment table, artefact list, DSD rows`.

### WP2b Migration script, fixture and test (Opus). Depends on WP2a.
Paste: 2.5 (mapping table and special cases), 2.10 with the fixes of R-E-6, R-E-7 and R-E-11, section 1 rows D27-D46 (id and first sentence, for CHANGELOG). Context: `pipeline/migrations/0.2.0/migrate.R` lines 1-120, its README, `pipeline/tests/testthat/test-migrate-0.2.0.R`, `pipeline/migrations/0.3.0/inputs/*`, `grep -n "CL_AGE.csv\|CL_AREA.csv\|DSD_AFW360_HH.csv" metadata/structure/COLUMNS.csv`, `head -12 metadata/CHANGELOG.md`.
Creates or changes: the fixture (34 files, mechanical copy), `pipeline/migrations/0.3.0/migrate.R`, `pipeline/migrations/0.3.0/README.md`, `pipeline/tests/testthat/test-migrate-0.3.0.R` (~700 hand-written lines in 3 files), plus the machine-written `metadata/` output.
Checks:
1. Fixture identity loop of R-E-6 prints nothing; `find pipeline/tests/testthat/fixtures/metadata-0.2.0 -type f | wc -l` is 34.
2. `cat metadata/VERSION` is 0.3.0; `test ! -e metadata/codelists/CL_UNIT.csv && test -f metadata/codelists/CL_UNIT_MEASURE.csv && test -f metadata/codelists/CL_FREQ.csv && echo OK` prints OK.
3. `cmp metadata/structure/ARTEFACTS.csv pipeline/migrations/0.3.0/inputs/ARTEFACTS.csv && cmp metadata/structure/DSD_AFW360_HH.csv pipeline/migrations/0.3.0/inputs/DSD_AFW360_HH.csv && echo SAME` prints SAME.
4. Codelist column check of R-E-7 prints nothing; 19 codelists.
5. COLUMNS check of R-E-8 prints `bad 0`.
6. `grep -rnw CL_UNIT metadata --include='*.csv'` prints nothing.
7. `Rscript pipeline/migrations/0.3.0/migrate.R --root pipeline/tests/testthat/fixtures/metadata-0.2.0 --out-root tmp/mig; echo $?` prints 0, then `diff -r tmp/mig/metadata metadata` prints nothing.
8. Guard check of R-E-10 bullet 7.
9. Test loop of R-E-9 over `test-migrate-0.3.0 test-migrate-0.2.0` prints `0 0` for each.
10. `git status --short` lists only `metadata/`, `pipeline/migrations/0.3.0/`, `pipeline/tests/testthat/fixtures/metadata-0.2.0/`, `pipeline/tests/testthat/test-migrate-0.3.0.R`.
Commit: `Metadata 0.3.0: migration 0.2.0 -> 0.3.0 (SDMX DSD table, ARTEFACTS.csv, global alignment)`.

### WP2c Docs generator and DSD readers on the new DSD (Opus). Depends on WP2b and WP1.
Paste: 2.4, 2.10 item 1, 2.11 last paragraph. Context: `pipeline/R/docs.R` lines 28-36 and 200-290, `pipeline/R/io.R` lines 175-206, `pipeline/tests/testthat/test-docs.R` lines 45-90, `head -5 metadata/structure/DSD_AFW360_HH.csv`.
Changes: `pipeline/R/docs.R`, `pipeline/R/io.R`, `pipeline/tests/testthat/test-docs.R` (~80 lines), and regenerated `.docs/generated/*.md`.
Decision needed first: does `tbl-columns` show the 34 DSD components or all 37 data-file columns (3 fixed + 34)? The checks below assume 34.
Checks:
1. `Rscript pipeline/build_docs.R --root . --check; echo $?` prints 0.
2. Test loop of R-E-9 over `test-docs test-io` prints `0 0` for each.
3. `grep -c "^| [0-9]" .docs/generated/tbl-columns.md` is 34.
4. `grep -c "DATAFLOW" .docs/generated/tbl-columns.md` is 0; `grep -c "FREQ" .docs/generated/tbl-columns.md` is at least 1.
5. `grep -nw CL_UNIT pipeline/R/docs.R` prints nothing.
6. `Rscript -e 'source("pipeline/R/io.R");m<-load_metadata(".");cat(length(dsd_columns(m)),length(dsd_key_columns(m)))'` prints `34 19` (Uncertain: assumes io.R sources on its own, as `pipeline/build_docs.R:23` does).
7. `git status --short` lists only `pipeline/R/docs.R`, `pipeline/R/io.R`, `pipeline/tests/testthat/test-docs.R`, `.docs/generated/`.
Commit: `Docs generator and DSD readers on the 0.3.0 DSD; generated tables refreshed`.

## Verified OK

- Section 3 preamble argument forms: `validate.R --root . --out`, `build_docs.R --root . --check` and `pipeline/tests/testthat.R` exist as written.
- WP1 render path `cd .docs && ... > ../tmp/wp1-render.log` resolves to the root `tmp/` (once WP0 creates it); `.docs/_quarto.yml` writes to `_site`, which `.gitignore:5` `_site/` covers.
- DSD table in 2.4: 18 dimensions, 1 time dimension, 9 measures, 6 attributes = 34 rows; the plan's `wc -l` 35 and grep counts are consistent and the greps do not cross-match.
- WP1 input budget (~23k tokens with the qmd read by section) and output (~280 lines, 1 file) are within rules 1 and 2.
- WP2 input budget as listed (~10.5k tokens) is within rule 1.
- WP2 editing `io.R` and WP3 editing it later is not a conflict: WP3 follows Gate 1.
- The existing fixture convention (`fixtures/metadata-0.1.0/` holds `metadata/` and `data_raw/`, 14 files) and the 0.2.0 CLI (`--root`, `--out-root`, guard exits 1 on a wrong VERSION) match what WP2 asks to copy, apart from R-E-6.
- Commit messages are present and specific for WP0, WP1 and WP2.
- `CL_OBS_STATUS` codes today are A E O M U D Q, as 2.9 says; `CL_UNIT` lacks XOF, as 2.9 says.
- The handover's commit rule, retry protocol (SendMessage, then a fresh implementer, then Blocked) and implementer budget match the section 3 preamble.

## Not checked

- Did not run `quarto render` or the test suite, because both write files outside my report.
- Did not fetch the global codelists; the URLs in 2.9 and the claims about which codes match are unverified.
- Did not check whether the 0.2.0 CHANGELOG entry "(unreleased)" makes a 0.3.0 bump necessary under D40.
