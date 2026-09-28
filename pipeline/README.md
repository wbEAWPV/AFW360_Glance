# AFW 360 pipeline

R code that turns the legacy inputs in `data_raw/` into files that follow the
data standard (`.docs/data-standard.qmd`): `data/`, `geo/`, `metadata/`,
`content/` and `assets/`. How the first version was built is summarised in
`.docs/transition.qmd`.

## Layout

```
pipeline/
  convert_legacy.R   Excel workbooks -> data/AFW360_HH_<ISO3>_<YEAR>_SURVEY.csv + _manifest.csv
  build_geo.R        shapefiles -> geo/boundaries/*.gpkg + metadata/registries/GEO_SOURCES.csv
  build_content.R    About text, key messages, figures -> content/, assets/, FIGURES.csv
  validate.R         checks data and metadata against the standard -> findings CSV
  reconcile.R        independent cell-by-cell check of data/ against the workbooks
  R/                 shared functions (I/O, codes, plans, conversion, validator checks)
  migrations/        one-off scripts that move metadata/ between versions, one folder per version
  tests/testthat/    unit tests
  bootstrap/         one-time generators of metadata/ (frozen, see below)
    seeds/           hand-written mapping tables: labels, codes, geography, columns, overrides
    text/            hand-written names and definitions
```

## Running it

From the repository root:

```
# Rebuild the outputs
Rscript pipeline/build_geo.R      --root .
Rscript pipeline/build_content.R  --root .
Rscript pipeline/convert_legacy.R --root . --country ALL --timestamp 2026-01-01T00:00:00Z
#   writes data/AFW360_HH_SEN_2021_SURVEY.csv, data/AFW360_HH_GNB_2021_SURVEY.csv
#   and their _manifest.csv (31 DSD columns, ESTIMATION = SURVEY)

# Check them
Rscript pipeline/validate.R  --root . --out findings.csv     # exit 1 on any ERROR
Rscript pipeline/reconcile.R --root . --out reconciliation.md

# Unit tests
Rscript pipeline/tests/testthat.R
```

Every script takes `--root <repo root>` (default `.`). Scripts that write
files also take `--out-root <dir>`: they read under `--root` and write under
`--out-root` at the same relative paths, so a rebuild into a temporary folder
can be compared with the committed files. With the same inputs and
`--timestamp`, the output is byte-identical (GeoPackages excepted: they are
compared by content).

## The bootstrap scripts are frozen

`pipeline/bootstrap/build_*.R` generated the first version (0.1.0) of every
file under `metadata/` from `seeds/` and `text/`. From 0.1.0 onward the CSV
files under `metadata/` are the source of truth and are edited directly; the
bootstrap scripts are not rerun or edited. They stay as the record of how the
first version was built. A new codelist or a larger change gets a new,
separately named script.

## Migrations

A structural change to `metadata/` (adding, removing or reordering a column,
or a new file) is made by a one-off script in `pipeline/migrations/<version>/`,
one folder per target version, with a README saying what it changes. Each
script runs once: it is guarded on the version it migrates from and refuses to
run (exit 1) on any other `metadata/VERSION`. Its test runs it with
`--out-root` on a frozen copy of the old metadata under
`tests/testthat/fixtures/`. The first is `migrations/0.2.0/migrate.R`
(0.1.0 to 0.2.0, standard v0.5):

```
Rscript pipeline/migrations/0.2.0/migrate.R --root .
```

## Conventions

- **CSV format.** UTF-8 without a byte-order mark, LF line endings, one
  header row, the columns listed for that file in
  `metadata/structure/COLUMNS.csv` in that order. A missing value is an
  empty string (never `NA`); numbers are in fixed notation with at most 10
  decimals; multi-valued fields are separated by one space. Write through
  `write_std_csv()` and read through `read_std_csv()` (`R/io.R`), which reads
  every column as character.
- **Codes.** Uppercase ASCII letters, digits and `_`, starting with a letter,
  at most 32 characters. `_T` (total) and `_Z` (not applicable) are reserved.
  New rows start as `status = DRAFT`; nothing becomes `ACTIVE` without the
  team's sign-off. `TBD` is allowed in a required text column on a `DRAFT`
  row only.
- **R code.** Base R plus readxl, dplyr, tidyr, readr, stringr, purrr, sf,
  digest, testthat, checkmate, cli and jsonlite. Shared code is loaded with
  `source(file.path(root, "pipeline", "R", "<module>.R"))`. Output is
  deterministic: rows are sorted and the current time is never written.
  Text from the workbooks (labels, accented place names) is copied byte for
  byte, never retyped.
