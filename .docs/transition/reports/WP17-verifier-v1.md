# WP17 verifier report
Branch: transition/wp17-final-audit-v1

## Files written        (path, and rows or bytes)
- `pipeline/acceptance/wp17_final-audit.R` — 398 lines, 20,511 bytes. Standalone acceptance
  script for WP17. Runs `pipeline/validate.R`, `pipeline/reconcile.R` and
  `pipeline/convert_legacy.R` as subprocesses (never sources `pipeline/R/`), reads every
  expected number from `contract/expected_counts.csv` by `check_id`, and writes only to
  `tempfile()`/`tempdir()` locations.
- `.docs/transition/reports/WP17-verifier-v1.md` — this report.

No other file was created, edited or deleted. `git status --short` after three full runs of the
acceptance script showed only the untracked acceptance script itself; nothing was left behind
under `_site/`, `data/`, `data_raw/`, `metadata/` or `.docs/`.

## Checks               (one line per acceptance check: id, PASS or FAIL, evidence)

All 70 checks PASS: the 64 rows of `contract/expected_counts.csv` (see **Targets** below) plus
WP17.V1–WP17.V6. Ran three times (`Rscript pipeline/acceptance/wp17_final-audit.R --root .`);
the 70 `CHECK` lines were byte-identical across the second and third run (deterministic), each
run took ~55 seconds, and `Rscript` exited 0 every time.

- WP17.V1 PASS — `pipeline/validate.R --root . --out <tmp>` exit=0, ERROR=0, WARN=115, INFO=8.
  Matches the WAVE3-integration.md numbers exactly.
- WP17.V2 PASS — every WARN finding's `check_id` (`CODES.DRAFT`, `META.TBD`, `RULE.AGG_SKIPPED`,
  `TEXT.TBD`) is in the card's allowed list of 7. See **Warnings** below.
- WP17.V3 PASS — `pipeline/reconcile.R --root . --out <tmp> --csv <tmp>` exit=0.
- WP17.V4 PASS — `pipeline/convert_legacy.R --root . --country ALL --timestamp
  2026-01-01T00:00:00Z --out-root <tmp>` reproduced all 4 files under `data/`
  (`AFW360_HH_GNB_2021.csv`, `AFW360_HH_GNB_2021_manifest.csv`, `AFW360_HH_SEN_2021.csv`,
  `AFW360_HH_SEN_2021_manifest.csv`) byte for byte against `HEAD:data/*` (git blob comparison,
  never against the branch name).
- WP17.V5 PASS — all 17 `metadata/codelists/CL_*.csv` files have every row `status == "DRAFT"`,
  and both data-file manifests (`AFW360_HH_SEN_2021_manifest.csv`,
  `AFW360_HH_GNB_2021_manifest.csv`) carry `status = DRAFT`. Nothing is `ACTIVE`.
- WP17.V6 PASS — `data_raw/CHECKSUMS.sha256` lists exactly 122 files; every one verified
  (recomputed SHA-256 via R's `digest` package, compared to the listed hash — equivalent to
  `sha256sum -c` run from the repo root, which I also confirmed by hand gives the same result,
  see Deviations).

### Targets  (every check_id of contract/expected_counts.csv)

| check_id | expected | tolerance | actual | result |
|---|---|---|---|---|
| CELLS.SEN_National | 1261 | 0 | 1261 | PASS |
| CELLS.SEN_National.NONEMPTY | 1248 | 0 | 1248 | PASS |
| CELLS.SEN_National.EMPTY | 13 | 0 | 13 | PASS |
| CELLS.SEN_ADM1 | 1358 | 0 | 1358 | PASS |
| CELLS.SEN_ADM1.NONEMPTY | 1340 | 0 | 1340 | PASS |
| CELLS.SEN_ADM1.EMPTY | 18 | 0 | 18 | PASS |
| CELLS.SEN_ZAE | 582 | 0 | 582 | PASS |
| CELLS.SEN_ZAE.NONEMPTY | 575 | 0 | 575 | PASS |
| CELLS.SEN_ZAE.EMPTY | 7 | 0 | 7 | PASS |
| CELLS.SEN_Departement | 1148 | 0 | 1148 | PASS |
| CELLS.SEN_Departement.NONEMPTY | 1142 | 0 | 1142 | PASS |
| CELLS.SEN_Departement.EMPTY | 6 | 0 | 6 | PASS |
| CELLS.GNB_National | 1261 | 0 | 1261 | PASS |
| CELLS.GNB_National.NONEMPTY | 1233 | 0 | 1233 | PASS |
| CELLS.GNB_National.EMPTY | 28 | 0 | 28 | PASS |
| CELLS.GNB_ADM1 | 873 | 0 | 873 | PASS |
| CELLS.GNB_ADM1.NONEMPTY | 828 | 0 | 828 | PASS |
| CELLS.GNB_ADM1.EMPTY | 45 | 0 | 45 | PASS |
| CELLS.GNB_ZAE | 388 | 0 | 388 | PASS |
| CELLS.GNB_ZAE.NONEMPTY | 378 | 0 | 378 | PASS |
| CELLS.GNB_ZAE.EMPTY | 10 | 0 | 10 | PASS |
| LABELS.SHARED | 97 | 0 | 97 | PASS |
| LABELS.DEPARTEMENT | 82 | 0 | 82 | PASS |
| LABELS.TOTAL | 179 | 0 | 179 | PASS |
| SERIES.COUNT | 91 | 0 | 91 | PASS |
| INDICATOR.CODES | 62 | 0 | 62 | PASS |
| DATA.SEN.ROWS | 3003 | 0 | 3003 | PASS |
| DATA.SEN.ROWS.A | 3003 | 0 | 3003 | PASS |
| SOURCE.SEN.ACCOUNTING | 3201 = 3003 + 198 | 0 | 3201 = 3003 + 198 (source cells from xlsx=3201) | PASS |
| GNB.MAPPED_CELLS | 2366 | 0 | 2366 | PASS |
| GNB.WITHHELD_CELLS | 98 | 0 | 98 | PASS |
| GNB.DATA.ROWS | 2268 | 0 | 2268 | PASS |
| GNB.DATA.ROWS.A | 2229 | 0 | 2229 | PASS |
| GNB.DATA.ROWS.O | 39 | 0 | 39 | PASS |
| SOURCE.GNB.ACCOUNTING | 2522 = 2366 + 156 | 0 | 2522 = 2366 + 156 (source cells from xlsx=2522) | PASS |
| DEPARTEMENT.SKIPPED | 1148 | 0 | 1148 | PASS |
| POVNUM.SEN.PL300 | 3.13 | 0.005 | 3.13 | PASS |
| POVNUM.SEN.PL420 | 6.52 | 0.005 | 6.52 | PASS |
| POVNUM.GNB.PL300 | 0.7 | 0.005 | 0.7 | PASS |
| POVNUM.GNB.PL420 | 1.09 | 0.005 | 1.09 | PASS |
| META.CL_INDICATOR | 62 | 0 | 62 | PASS |
| META.SERIES_PLAN | 91 | 0 | 91 | PASS |
| META.TAB_PLAN | 8 | 0 | 8 | PASS |
| META.CL_BRK_VAR | 13 | 0 | 13 | PASS |
| META.CL_COMP_BREAKDOWN | 60 | 0 | 60 | PASS |
| META.CL_QUAL_VAR | 6 | 0 | 6 | PASS |
| META.CL_QUALIFIER | 42 | 0 | 42 | PASS |
| META.CL_GEO | 35 | 0 | 35 | PASS |
| META.CL_GEO_SCHEME | 6 | 0 | 6 | PASS |
| META.CL_AREA | 2 | 0 | 2 | PASS |
| META.GEO_SOURCES | 2 | 0 | 2 | PASS |
| META.SURVEYS | 2 | 0 | 2 | PASS |
| META.LEGACY_LABELS | 179 | 0 | 179 | PASS |
| META.LEGACY_COLUMNS | 73 | 0 | 73 | PASS |
| META.LEGACY_OVERRIDES | 12 | 0 | 12 | PASS |
| META.TEXT | 8 | 0 | 8 | PASS |
| META.FIGURES | 1 | 0 | 1 | PASS |
| META.DSD | 26 | 0 | 26 | PASS |
| META.SMALL_CODELISTS | 9 | 0 | 9 | PASS |
| GEOM.SEN.ADM0 | 1 | 0 | 1 | PASS |
| GEOM.SEN.ADM1 | 14 | 0 | 14 | PASS |
| GEOM.GNB.ADM0 | 1 | 0 | 1 | PASS |
| GEOM.GNB.ADM1 | 9 | 0 | 9 | PASS |
| LEGACY.FILES | 122 | 0 | 122 | PASS |

64/64 targets PASS. `SOURCE.SEN.ACCOUNTING` and `SOURCE.GNB.ACCOUNTING` carry an equation in
their `expected` column rather than a bare number (see Deviations); both were verified as an
exact equality (tolerance 0), not a tolerance comparison.

### Warnings  (count per check_id, from a fresh `pipeline/validate.R` run)

| check_id | severity | count | allowed by WP17.V2? |
|---|---|---|---|
| CODES.DRAFT | WARN | 42 | yes |
| META.TBD | WARN | 42 | yes |
| RULE.AGG_SKIPPED | WARN | 27 | yes |
| TEXT.TBD | WARN | 4 | yes |
| META.SLOT_ORDER_TIE | WARN | 0 (did not occur) | yes |
| TEXT.REFERENCE | WARN | 0 (did not occur) | yes |
| ASSET.NAME_MISMATCH | WARN | 0 (did not occur) | yes |

Total WARN = 115 (42+42+27+4), matching `WAVE3-integration.md` exactly. No WARN `check_id`
outside the card's allowed list of 7 occurred. INFO findings (not gated by WP17.V2, shown for
completeness): `RULE.CLOSURE_PARTIAL` = 6, `VALUE.N` = 2 (total INFO = 8, also matching
WAVE3-integration.md). ERROR = 0.

## Deviations           (what the card said, what you did, why)

- **SOURCE.SEN.ACCOUNTING / SOURCE.GNB.ACCOUNTING expected format.** These two rows of
  `contract/expected_counts.csv` hold an equation string in `expected` (`"3201 = 3003 + 198"`,
  `"2522 = 2366 + 156"`), not a bare number, so the template's generic `expected()`/`meets()`
  helper (`as.numeric(row$expected)`) cannot parse them (`as.numeric("3201 = 3003 + 198")` is
  `NA`). I added `expected_raw()` to read the string unparsed, and checked the card's own
  definition directly: "the classes on the three sheets [National, ADM 1, ZAE] sum to the number
  of source cells." Concretely: total reconciliation-cell count for `ref_area` across those three
  sheets (all 5 classes: `converted`, `derived`, `duplicate`, `skipped`, `withheld`) must equal
  the independently-computed source-cell count from `data_raw/tables/Tables_<ISO3>.xlsx`
  (`CELLS.<ref>_National + CELLS.<ref>_ADM1 + CELLS.<ref>_ZAE`), and must equal "mapped" +
  "non-series" cells as the card defines them (mapped = `converted` + `withheld`; non-series =
  everything else). I additionally spot-checked a few rows of each class (`derived`, `duplicate`,
  `skipped`, `withheld`) to confirm they are mutually exclusive per-cell dispositions, not an
  artifact of double-counting — the identity is a genuine accounting check, not a coincidental
  arithmetic match.
- **`A` as an environment, not a list.** While developing the script I hit a reproducible R
  scoping issue: complex superassignment (`A[[id]] <<- value`) inside a `tryCatch({...})` block
  fails with "object 'A' not found", even though a plain read of `A` and a simple superassignment
  (`A <<- newlist`) both work fine in the same position. (Minimal repro: `A <- list();
  tryCatch({ A[["x"]] <<- 1 }, error = function(e) print(e))` raises exactly this error.) I
  therefore made the check-id → actual-value store `A <- new.env()` and mutate it with plain
  `A[[id]] <- value` everywhere (environments have reference semantics, so this works
  identically inside or outside `tryCatch`). This is an implementation detail; it does not change
  what is checked or how `check()`/`.failures` work (both unchanged from the template).
- **WP17.V6 via R's `digest` package instead of shelling out to `sha256sum -c`.** The card's
  literal command is `sha256sum -c data_raw/CHECKSUMS.sha256`, which I confirmed by hand gives
  `122/122 OK` when run from the repo root (paths in the file are root-relative, so running it
  from inside `data_raw/` — my first attempt — fails to find every file; from the root it passes
  cleanly). Inside the R script, rather than depend on the working directory of a shelled-out
  `sha256sum` process, I parse `data_raw/CHECKSUMS.sha256` and recompute each SHA-256 with
  `digest::digest(file, algo = "sha256", file = TRUE)` (an approved package per COMMON.md
  §5), which is equivalent and independent of cwd.
- **No "Verifier focus" section on this card.** See Questions.

## Questions            (contract doubts, and anything only the user can decide)

- **CONTRACT DOUBT: WP17.md has no "Verifier focus" heading.** My orchestrator prompt's step 4
  says "do the card's 'Verifier focus' by hand," but `.docs/transition/packages/WP17.md` has no
  such section (its headings are Goal, Read, Owned outputs, What the script checks, Report,
  Verdict, Out of scope only — confirmed with `grep -n "^#"`). I did not invent one. In its
  place I did extra by-hand due diligence within the card's own "What the script checks" and
  "Read" scope: re-ran the acceptance script three times and diffed the `CHECK` lines byte for
  byte (deterministic); spot-checked sample rows of each reconciliation `class`
  (`converted`/`derived`/`duplicate`/`skipped`/`withheld`) to confirm the accounting identity is
  semantically real, not coincidental; confirmed by hand that `sha256sum -c
  data_raw/CHECKSUMS.sha256` run from the repo root independently gives 122/122 OK; grepped the
  finished script for `pipeline/R/`, `transition/main` and `run_all` to confirm none of the
  three forbidden patterns are present; and confirmed `git status --short` is clean of stray
  writes after three runs.
- **Carried forward from the orchestrator's open-items list (d), not investigated further per
  instruction — one line each on whether it still stands, given only what this audit's own
  checks cover:**
  1. Shared-name validator helpers (`.vc_bind`, `.vc_apply_cap`, `.vc_cap`) picked by alphabetical
     file order, causing a tolerated double cap — still stands; not probed (WP17 has no check of
     validator internals), and WP17.V1's ERROR/WARN/INFO split (0/115/8) is unchanged from
     WAVE3-integration.md, consistent with the same tolerated behavior still being in effect.
  2. WP13's `vc_rule_sum_to_1_qual()` double-caps per `SUM_TO_1_OVER:<VAR>` — still stands; same
     basis as (1), not independently probed.
  3. Cards WP03, WP05, WP07, WP08, WP09, WP16 have "Read" lists narrower than their steps — still
     stands; out of this card's scope, not reread.
  4. `contract/expected_counts.csv` has no rows for WP11 or WP13 — still stands; confirmed
     directly, since I read every row of this file for the acceptance script: none of its 64
     `check_id` values names WP11 or WP13.
  5. No check covers WP07's `universe_unit`/`theme` derivation — still stands; WP17's own check
     list (the card's "What the script checks" table) has no such check either, and I added none
     beyond the card.
  6. `pipeline/README.md`'s top-level `bootstrap/` vs. cards' `pipeline/bootstrap/` — still
     stands; `pipeline/README.md` is outside WP17's "Read" list, not reread.
  7. WP02's card cites decision D2 for gap (e) where decisions.qmd puts it under D11 — still
     stands; `decisions.qmd` is outside WP17's "Read" list, not reread.
  8. `HE_COSTS.unit_time` = "TBD" and the `HE_HH_OWNER -> POP_HH_SH` one-directional link — still
     open (user questions, not decidable by an agent); consistent with what WP17.V1/V2 see: `TBD`
     values are present and flagged `META.TBD`/`TEXT.TBD` (WARN, not ERROR), which is the
     expected, allowed behavior for a `DRAFT`-stage TBD per COMMON.md §4.
  9. SEN key message 2 differs between `data_raw/text/Messages_SEN.txt` and `index.qmd` (user
     chose the dashboard version at G0, `##` placeholder retained) — still stands; `index.qmd`
     and `content/` text are outside WP17's checks, not reread.

## Changelog line       (implementers only: the card's line, adjusted if needed)
None (verifier report; WP17 has no implementer and no changelog line).

## Failures to fix   (numbered; for each: the check ID, the exact command or comparison, expected against actual. Write "None" on PASS.)
None. All 70 checks (64 `contract/expected_counts.csv` targets + WP17.V1–WP17.V6) PASS, and the
verifier-focus due diligence described above found no defect.
