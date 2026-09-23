# AFW 360 pipeline

The shared R library and acceptance/test infrastructure for the AFW 360
data transition. Everything here is base R plus the packages listed below;
nothing needs to be installed.

## Layout

```
pipeline/
  R/
    io.R          Standard CSV read/write, hashing, metadata loading, CLI helpers.
    constants.R    DATAFLOW_ID, sentinel codes, TBD, DSD_COLUMNS, KEY_COLUMNS.
    codes.R        Code validation and ordering: is_valid_code, slot_sort, fill_slots.
    ctx.R          build_ctx(): the shared context object every validator check receives.
  acceptance/
    run_all.R      Runs every wp*.R acceptance script and summarizes the results.
    wp*.R          One acceptance script per work package (added by later packages).
  tests/
    testthat.R              Entry point: testthat::test_dir("pipeline/tests/testthat").
    testthat/
      helper-temp-root.R    find_root(), make_temp_root(), edit_csv() (auto-sourced).
      test-io.R, test-codes.R, test-ctx.R

metadata/
  VERSION                    Single line, the current metadata version (0.1.0).
  CHANGELOG.md                One heading per released version.
  structure/
    DSD_AFW360_HH.csv         The 26-column AFW360_HH data structure definition.
    COLUMNS.csv                Machine-readable column registry for every
                                metadata and content file (generated from
                                contract/csv_headers.csv).

bootstrap/
  One-time generator scripts. Frozen after metadata 0.1.0 (decision D11):
  once metadata reaches that version, a bootstrap script is not run again
  and not edited to produce a different result. A later change to a
  codelist or the DSD is made by hand or by a new, separately-named script,
  never by re-running a frozen bootstrap script.
```

## Running things

From the repo root:

```
# Unit tests
Rscript pipeline/tests/testthat.R
# or, to stop at the first failure:
Rscript -e "testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)"

# All acceptance scripts
Rscript pipeline/acceptance/run_all.R --root .

# A single acceptance script
Rscript pipeline/acceptance/wp03_scaffold.R --root .
```

Every script takes `--root <repo root>` (default `.`) and is run from the
repo root; it never uses an absolute path. Scripts that generate files also
take `--out-root <dir>` (default: the root): inputs are read under `--root`
and outputs are written under `--out-root` at the same relative paths, so a
check can rebuild into a temporary directory and compare it against the
committed one.

## Conventions (COMMON.md sections 3-5)

- **CSV format.** Every CSV the pipeline writes is UTF-8 without a
  byte-order mark, has LF line endings and one header row, has exactly the
  columns of `contract/csv_headers.csv` for that file in that order, writes
  a missing value as an empty string (never `NA`), writes numbers in fixed
  notation with at most 10 decimals and no trailing zeros (never
  scientific notation), separates multi-valued fields with one space, and
  never has a line break inside a cell. Write through `write_std_csv()` and
  read through `read_std_csv()` (`pipeline/R/io.R`); every reader reads all
  columns as character, strips a BOM, and accepts CRLF.
- **Codes.** A code is uppercase ASCII letters, digits and `_`, starts with
  a letter, and has at most 32 characters. `_T` (total) and `_Z` (not
  applicable) are reserved: they never appear in a codelist and no code
  starts with them. Every row this transition creates has
  `status = DRAFT` and `version_added = 0.1.0`; nothing becomes `ACTIVE`
  without the user. `TBD` is allowed in a required text column on a
  `DRAFT` row when the value cannot be known from the inputs, never in a
  coded column, and never invented to avoid a gap.
- **R code.** All code lives under `pipeline/`, uses base R and the
  installed packages (readxl, dplyr, tidyr, readr, stringr, purrr, sf,
  digest, testthat, checkmate, cli, jsonlite), and finds shared code with
  `source(file.path(root, "pipeline", "R", "<module>.R"))`. Generated files
  are deterministic: the same inputs give byte-identical output, rows are
  sorted, and the current time is never written unless a card says so.
  Text from the workbooks (indicator labels, place names with accents) is
  matched and copied byte for byte, never retyped.

## Environment notes

Render Quarto with `QUARTO_R` unset and `QUARTO_PYTHON` pointed at the
Python that has geopandas:

```
env -u QUARTO_R QUARTO_PYTHON="C:/WBG/Python313/python.exe" quarto render <file>
```
