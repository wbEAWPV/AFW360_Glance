# WAVE2 integration report

## Merged

| Package | Branch | Merge commit |
|---|---|---|
| WP04 | transition/wp04-small-codelists-v1 | 64c4651 |
| WP05 | transition/wp05-geography-v1 | a0e32e5 |
| WP06 | transition/wp06-breakdowns-qualifiers-v1 | b344589 |
| WP07 | transition/wp07-dictionary-v1 | b2550e0 |
| WP08 | transition/wp08-plans-v1 | 64926db |
| WP09 | transition/wp09-legacy-maps-v1 | 89b6fca |
| WP10 | transition/wp10-content-v1 | 8822ea8 |

## Conflicts

None. All seven branches merged with `git merge --no-ff` cleanly, with no conflicts in
metadata/CHANGELOG.md, .docs/transition/STATUS.md, or any other file.

## Checks

- `Rscript pipeline/acceptance/run_all.R --root .`: PASS (exit 0). All acceptance checks for
  WP04-WP10 report PASS (WP04.A1-A8, WP05.A1-A8, WP06.A6-A9, WP07.A1-A8, WP08.A1-A8, WP09.A1-A7,
  WP10.A1-A8), each script's SUMMARY line reads PASS (exit 0).
- `Rscript -e "testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)"`: PASS
  (`[ FAIL 0 | WARN 0 | SKIP 0 | PASS 151 ]`).
- Wave 2 duty (i), every file in metadata/structure/COLUMNS.csv exists with exactly the listed
  header: PASS. 28 files listed; all found with headers identical to the listed column order.
- Wave 2 duty (ii), required_rows() counts with the real metadata: PASS.
  `nrow(required_rows(meta, "SEN", "2021"))` = 3003 = `DATA.SEN.ROWS` in
  contract/expected_counts.csv. `nrow(required_rows(meta, "GNB", "2021"))` = 2366 =
  `GNB.MAPPED_CELLS` in contract/expected_counts.csv.
- Wave 2 duty (iii), every generator with `--out-root <tempdir>` reproduces the committed files:
  PASS. Confirmed via the acceptance scripts' own out-root checks: WP04.A8 ("rebuilt files
  byte-identical to committed ones"), WP05.A7 ("codelists byte-identical... geom_ok=TRUE" for all
  four geographies), WP06.A9 ("byte-identical reproduction in temp out-root"), WP07.A8
  ("same_bytes=TRUE"), WP08.A7 ("byte-identical=TRUE"), WP09.A7 ("out-root reproduces byte for
  byte=TRUE"), WP10.A8 ("build_content exit=0 match=TRUE; build_surveys exit=0 match=TRUE").

## Findings by owner

None. Every check passed; no failures to assign.

## Status changes

- WP04, WP05, WP06, WP07, WP08, WP09, WP10: TODO -> MERGED (branch `<pkg>-v1`, verdict PASS,
  1 attempt, 2026-09-22).
- Gate G1: PENDING -> DONE (reports/GATE-G1.md).

## Changelog lines added

- Small codelists and CL_AREA (10 files).
- Geography: 6 schemes, 35 units, 2 GeoPackages.
- Breakdown (13) and qualifier (6) variables with categories.
- Indicator dictionary (CL_INDICATOR).
- SERIES_PLAN, TAB_PLAN, and the required-row generator.
- Legacy maps: labels, columns and overrides.
- Text (TEXT.csv, about.md), figure registry, surveys.
