# Migration 0.1.0 -> 0.2.0

`migrate.R` rewrites `metadata/` from version 0.1.0 to 0.2.0, the metadata
release of data standard v0.5 (`.docs/data-standard.qmd`, decisions D12 to
D26). It is the first migration under D12: a structural change is made by a
committed one-off script, and the bootstrap stays frozen.

## How to run

From the repository root:

```
Rscript pipeline/migrations/0.2.0/migrate.R --root .
```

`--root` is the repository whose `metadata/` is read (default `.`). With
`--out-root <dir>` the 0.2.0 files are written under `<dir>/metadata/` at the
same relative paths instead of in place; only the files the migration creates
or rewrites are written. The test `pipeline/tests/testthat/test-migrate-0.2.0.R`
uses this on the frozen 0.1.0 copy in
`pipeline/tests/testthat/fixtures/metadata-0.1.0/`.

## It runs once

The script refuses to run, writes nothing and exits 1 unless
`<root>/metadata/VERSION` is `0.1.0`. After it has run, `VERSION` is `0.2.0`, so
running it again is refused. The output is deterministic: the same 0.1.0 inputs
always give byte-identical files. It reads `data_raw/CHECKSUMS.sha256` and never
writes under `data_raw/`.

## What it changes

New files:

- `codelists/CL_ESTIMATION.csv`: `SURVEY` and `MODEL` (D17).
- `rules/RULES.csv`: one `INDICATOR`-scope row per token of the old
  `CL_INDICATOR.checks` (`X:Y` becomes rule `X` with `param` `Y`; `NONE` and the
  retired `EQUALS_NPOP_RATIO` give no row), severity `ERROR`, status copied from
  the indicator; plus the two `DATAFLOW` rows `RELIABILITY_MIN_NOBS` (30) and
  `RELIABILITY_MAX_CV` (0.3). `DATAFLOW` rows first, then by `scope_code`,
  `rule`, `param` (D18, D22).
- `structure/INDICATOR_QUALIFIERS.csv`: one row per group `VAR:cat1,cat2,...` of
  the old `CL_INDICATOR.qualifiers`, `allowed` = the categories space-separated
  (or `*`); `_Z` gives no row (D18).
- `structure/QUALIFIER_PAIRS.csv`: one row per non-empty `CL_QUALIFIER.valid_with`;
  a category code pairs with its own variable, `_Z` pairs with the qualifier
  variable's `requires` (D18).
- `registries/SOURCES.csv`: one `LEGACY_CONVERSION` source per country in
  `CL_AREA.csv`, `<ISO3>_<acronym><year>_LEGACY_v1`, with the workbook's checksum
  from `data_raw/CHECKSUMS.sha256` (D16).

Changed files:

- `codelists/CL_INDICATOR.csv`: `checks` and `qualifiers` removed.
- `codelists/CL_QUALIFIER.csv`: `valid_with` removed.
- `codelists/CL_OBS_STATUS.csv`: `U`, `D` and `Q` appended (D22).
- `plans/SERIES_PLAN.csv`: `name_en` (composed from the indicator's
  `short_name_en`, the qualifier names in slot order and, for a defining
  category, `<breakdown variable name> = <category name>`, joined by ` · `) and
  `estimation` (`SURVEY` on every row) inserted before `status` (D13, D17).
- `structure/DSD_AFW360_HH.csv`: rewritten to the 31 columns of v0.5 (D26).
- `structure/COLUMNS.csv`: the three removed columns dropped, the two
  `SERIES_PLAN` columns added, full rows for the five new files, positions
  renumbered; every file the migration writes has a header equal to its rows.
- `VERSION`: `0.2.0`; `CHANGELOG.md`: a 0.2.0 entry listing D12 to D26.

New rows have `status = DRAFT` and `version_added = 0.2.0`. The data files
under `data/` are not touched here; the converter regenerates them.
