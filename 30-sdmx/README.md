# AFW 360 pipeline

R code that turns the legacy inputs in `data_raw/` into files that follow the
data standard (`.docs/data-standard.qmd`): `data/`, `geo/`, `metadata/`,
`content/` and `assets/`, and generates the SDMX files under `sdmx/`. The
data files are SDMX-CSV 2.1 data messages; the structures are one SDMX-ML
3.1 structure message. How the first version and the SDMX transition were
built is summarised in `.docs/transition.qmd`.

## Layout

```
pipeline/
  convert_legacy.R   Excel workbooks -> data/AFW360_HH_<ISO3>_<YEAR>_SURVEY.csv + _manifest.csv
  build_geo.R        shapefiles -> geo/boundaries/*.gpkg + metadata/registries/GEO_SOURCES.csv
  build_content.R    About text, key messages, figures -> content/, assets/, FIGURES.csv
  validate.R         checks data and metadata against the standard -> findings CSV
  reconcile.R        independent cell-by-cell check of data/ against the workbooks
  build_docs.R       metadata/ + content/ -> .docs/generated/<id>.md, the standard's generated tables
  build_sdmx.R       metadata/ + content/ -> sdmx/ (SDMX-ML 3.1 structures, SDMX-CSV 2.1 metadata)
  import_sdmx.R      SDMX-ML 3.0 or 3.1 structure message -> metadata/ CSVs (diff or apply)
  R/                 shared functions (I/O, codes, plans, conversion, SDMX writer and
                     importer, validator checks)
  xsd/sdmx-ml-3.1/   vendored SDMX-ML 3.1.0 schemas, used to validate the structure message
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
#   and their _manifest.csv (SDMX-CSV 2.1: 37 columns, 19-column key, ESTIMATION = SURVEY)
Rscript pipeline/build_docs.R     --root .            # --check: exit 1 if a generated table is stale
Rscript pipeline/build_sdmx.R     --root .            # --check: exit 1 if a file under sdmx/ is stale

# Check them
Rscript pipeline/validate.R  --root . --out findings.csv     # exit 1 on any ERROR
Rscript pipeline/reconcile.R --root . --out reconciliation.md

# Unit tests
Rscript pipeline/tests/testthat.R

# Independent checks (Python, outside the pipeline; see "Tools and the dashboard loader")
tools/verify/.venv/Scripts/python tools/verify/verify_sdmx.py --root .
```

Every script takes `--root <repo root>` (default `.`). Scripts that write
files also take `--out-root <dir>`: they read under `--root` and write under
`--out-root` at the same relative paths, so a rebuild into a temporary folder
can be compared with the committed files. With the same inputs and
`--timestamp`, the output is byte-identical (GeoPackages excepted: they are
compared by content).

## The validator

`validate.R` runs every `vc_*` check of the `R/validate_*.R` modules and
writes one findings CSV (`check_id, severity, file, row_key, message`), at
most 20 findings per check and file plus a SUMMARY row. It exits 1 on any
ERROR, 2 if a check crashed. `--metadata-only` skips the data files; `--data
<file>` (repeatable) validates only those. The modules follow the standard's
"Validation checks" section:

- `STRUCT` (`validate_structure.R`): the DSD header, the file name
  `AFW360_HH_<REF_AREA>_<TIME_PERIOD>_<ESTIMATION>.csv` agreeing with the rows
  and the manifest, the 19-column key.
- `CODES` (`validate_codes.R`): codelists, slots, qualifiers against
  `INDICATOR_QUALIFIERS.csv` and `QUALIFIER_PAIRS.csv`, `SERIES_ID` against
  `SERIES_PLAN.csv`, `UNIT_MEASURE` (LCU resolved to `CL_AREA.currency`),
  `SOURCE_ID` against `SOURCES.csv` and the manifest.
- `COVER` (`validate_coverage.R`): the required rows of the file's
  `ESTIMATION` (country `SERIES_PLAN` rows over `ALL`, `NOT_PRODUCED` left
  out, withheld cells subtracted), the manifest and `SURVEYS.csv`, and a WARN
  for a `SURVEYS.csv` survey with no SURVEY data file or manifest.
- `VALUE` (`validate_values.R`): numbers, ranges, `PRECISION`, the
  reliability attributes (required on `PRODUCER`-source rows), and the
  `OBS_STATUS` rules (`E` in a `MODEL` file, `D` on `DEVIATES` series, `U` by
  the `RULES.csv` thresholds, no `Q`).
- `RULE` (`validate_rules.R`): every row of `RULES.csv`, with tolerances
  from each row's `PRECISION`, and the `N_POP` partition sums.
- `META` (`validate_metadata.R`): every metadata and content CSV against
  `COLUMNS.csv`, references, and the rules of `RULES.csv`,
  `INDICATOR_QUALIFIERS.csv`, `QUALIFIER_PAIRS.csv`, `SERIES_PLAN.csv` and
  `SOURCES.csv`.
- `DOCS` (`validate_docs.R`): the generated tables of the standard are
  current (`docs_check()` of `R/docs.R`).
- `ASSET` and `TEXT` (`validate_assets.R`, `validate_text.R`): boundaries,
  figures and dashboard text.
- `SDMX` (`validate_sdmx.R`): the files under `sdmx/` are current
  (`SDMX.STALE`, a fresh build compared byte for byte), the structure
  message is valid against the vendored XSD (`SDMX.XSD`), every URN in it
  resolves (`SDMX.URN`), every maintainable has the right agency, version,
  id and English name (`SDMX.IDENT`), and each data file has the SDMX-CSV
  header and `STRUCTURE_ID` of the DSD (`SDMX.CSV_HEADER`); `SDMX.SKIPPED`
  is reported on a root without `sdmx/`.

The findings helpers the modules share live once in `R/validate_common.R`,
which `validate.R` sources first. Findings are sorted with `method = "radix"`,
so the file is the same in every locale.

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
(0.1.0 to 0.2.0, standard v0.5); the second is `migrations/0.3.0/migrate.R`
(0.2.0 to 0.3.0, standard v0.6, SDMX 3.1 alignment), which reads its new
files (`ARTEFACTS.csv`, `CL_FREQ.csv`, the rewritten `DSD_AFW360_HH.csv`,
the code alignment) from `migrations/0.3.0/inputs/`:

```
Rscript pipeline/migrations/0.2.0/migrate.R --root .
Rscript pipeline/migrations/0.3.0/migrate.R --root .
```

Both have run; `metadata/VERSION` is `0.3.0`, so each now refuses to run on
the repository and is kept as the record of the change.

## SDMX files: build and reverse import

`build_sdmx.R` writes `sdmx/structures/AFW360_structures.xml` (one SDMX-ML
3.1 structure message: agency scheme, concepts, codelists, the DSD and
dataflow, the MSD and metadataflow, provider schemes, provision agreements)
and the four SDMX-CSV 2.1 metadata messages `sdmx/metadata/MDS_*.csv`, from
`metadata/` and `content/TEXT.csv`. The structure message is validated
against `xsd/sdmx-ml-3.1/` before it is written; `--check` compares instead
of writing. `--sdmx-ml-version 3.0 --out-root <dir>` writes the SDMX-ML 3.0
profile that Fusion Metadata Registry 12.4 reads (no MSD, metadataflow or
metadata provision agreement; never committed). The code is in
`R/sdmx_xml.R`, `R/sdmx_structures.R` and `R/sdmx_refmeta.R`; `sdmx/README.md`
describes the files.

`import_sdmx.R` is the reverse direction, for structures edited elsewhere
(for example in FMR): it reads an SDMX-ML 3.0 or 3.1 structure message and
prints a unified diff against the CSVs under `metadata/` (`--diff`, the
default), or writes them (`--apply`, with `--out-root` to write elsewhere).
The generated sentinel codes `_T` and `_Z` are stripped. Rebuilding
`sdmx/` from the imported CSVs gives the same file byte for byte, and an
unedited FMR export gives an empty diff. The code is in `R/sdmx_import.R`.

```
Rscript pipeline/import_sdmx.R --root . --diff  <message.xml>
Rscript pipeline/import_sdmx.R --root . --apply <message.xml>
```

## Tools and the dashboard loader

These folders sit outside `pipeline/` and never write its outputs:

- `tools/verify/` checks the SDMX files independently of the R code:
  `verify_sdmx.py` reads the structure message with pysdmx, validates it
  with lxml against the vendored XSD, reads the data messages and checks the
  metadata headers and targets; `check_urns.py` checks that every
  `WB.AFW360` URN in a message resolves. Its
  virtual environment is made by `make_venv.ps1` or `make_venv.sh`
  (`tools/verify/README.md`). On the metadata files it is weaker than the
  build (see `sdmx/README.md`).
- `tools/fmr/` holds the Fusion Metadata Registry scripts (`fmr_load.R`,
  `fmr_validate.R`, `fmr_export.R`) and install notes; the local FMR lives
  under `tools/fmr/runtime/` (gitignored) and the workflow is in
  `.docs/fmr-guide.qmd`.
- `tools/dashboard_numbers.py` extracts the numeric table cells of a
  rendered dashboard section, to compare two renders.
- `afw360/` is the dashboard's single data-access layer: `loader.py` reads
  `data/`, `metadata/`, `content/`, `geo/` and `assets/` (never `data_raw/`)
  and `format.py` applies each indicator's `display_as` and `decimals`.
  Its tests run with `python -m pytest afw360/tests`.

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
  digest, testthat, checkmate, cli, jsonlite and xml2 (the SDMX-ML writer,
  importer and XSD validation). Shared code is loaded with
  `source(file.path(root, "pipeline", "R", "<module>.R"))`. Output is
  deterministic: rows are sorted and the current time is never written.
  Text from the workbooks (labels, accented place names) is copied byte for
  byte, never retyped.
