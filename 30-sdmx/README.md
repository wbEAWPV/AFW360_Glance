# 30-sdmx: the standard, the data, and the SDMX files

This stage holds the data standard and the harmonised data, and turns them
into SDMX. `data/` is the source of truth: the standard's metadata
(`data/metadata/`), the SDMX-CSV 2.1 data messages with their manifests
(`data/*.csv`) and the boundaries (`data/geo/boundaries/*.gpkg`).
`pipeline/` builds the SDMX-ML 3.1 structure message and the SDMX-CSV 2.1
reference-metadata messages from them (`output/`), validates everything
against the standard, imports structures edited elsewhere, and holds the
independent verification tools. The standard itself is described in
`.docs/data-standard.qmd`; how the first version and the SDMX transition
were built is summarised in `.docs/transition.qmd`.

The legacy Excel inputs reach `data/` through the Excel stage,
`20-excel-sdmx-csv/` (its `publish.R` copies its output here). A producer
can also write data files in the standard format directly; both routes are
checked by the same validator.

## Layout

```
30-sdmx/
  data/
    AFW360_HH_<ISO3>_<YEAR>_<ESTIMATION>.csv   SDMX-CSV 2.1 data messages, with _manifest.csv
    metadata/        the standard: codelists, structure (DSD, COLUMNS, ARTEFACTS), plans
                     (SERIES_PLAN), registries, rules, surveys, VERSION, CHANGELOG.md
    geo/boundaries/  GeoPackages (layers adm0, adm1)
  output/            generated SDMX files (structures/, metadata/), see output/README.md
  pipeline/
    build_sdmx.R     data/metadata/ + dashboard content -> output/ (SDMX-ML 3.1 structures,
                     SDMX-CSV 2.1 metadata)
    validate.R       checks data and metadata against the standard -> findings CSV
    build_docs.R     data/metadata/ + dashboard content -> .docs/generated/<id>.md
    import_sdmx.R    SDMX-ML 3.0 or 3.1 structure message -> data/metadata/ CSVs (diff or apply)
    R/               modules (paths, I/O, codes, plans, SDMX writer and importer,
                     validator checks, docs)
    xsd/sdmx-ml-3.1/ vendored SDMX-ML 3.1.0 schemas, used to validate the structure message
    migrations/      one-off scripts that move data/metadata/ between versions (frozen)
    tests/testthat/  unit tests, with the frozen fixtures of the migrations
    tools/verify/    independent Python checks (pysdmx, lxml)
    tools/fmr/       Fusion Metadata Registry scripts; runtime/ is the local install (gitignored)
```

## Locations

Every location is defined once, in `pipeline/R/paths.R`, relative to the
stage folder. `--root` is the stage folder (default: the `30-sdmx/` of the
script that runs, so the scripts work from any directory). Code names a
location by kind, or by a logical path whose first segment is a kind
(`metadata/codelists/CL_AGE.csv`, `data/<file>.csv`, `sdmx/structures/...`):
the paths written in `ARTEFACTS.csv`, in the SDMX annotations and in the
findings `file` column are these logical paths, so they do not change when
a folder moves.

The stage reads three places outside itself, each overridable:

| Kind | Folder | Why | Override |
|---|---|---|---|
| dashboard content and figures | `../10-legacy-pipeline/data_dashboard/{content,assets}/` | `MDS_TEXT.csv` and the TEXT and ASSET checks; the content stays where the dashboard reads it | `--dashboard-dir`, `AFW360_DASHBOARD_DIR` |
| legacy plans (optional) | `../20-excel-sdmx-csv/plans/` | `TAB_PLAN.csv` and `LEGACY_*.csv`, which the coverage checks need to build the required rows; without them the validator reports one `COVER.SKIPPED` and runs everything else | `--plans-dir`, `AFW360_PLANS_DIR` |
| legacy inputs (optional, read only) | `../10-legacy-pipeline/data_raw/` | `META.SOURCES` checks the `inputs_sha256` of a source's inputs when they are present | `--legacy-dir`, `AFW360_LEGACY_DIR` |

`build_docs.R` writes `../.docs/generated/`, beside the tables the Excel
stage writes there.

## Running it

From `30-sdmx/` (R 4.5.3):

```
# Rebuild the generated files
Rscript pipeline/build_docs.R         # --check: exit 1 if a generated table is stale
Rscript pipeline/build_sdmx.R         # --check: exit 1 if a file under output/ is stale

# Check
Rscript pipeline/validate.R --out ../tmp/findings.csv     # exit 1 on any ERROR

# Unit tests
Rscript pipeline/tests/testthat.R

# Independent checks (Python, outside the pipeline; see "Tools")
pipeline/tools/verify/.venv/Scripts/python pipeline/tools/verify/verify_sdmx.py
```

Scripts that write files also take `--out-root <dir>`, a stage folder:
they read under `--root` and write under `--out-root` at the same relative
paths (`build_sdmx.R` writes `<dir>/output/`, `import_sdmx.R --apply`
writes `<dir>/data/metadata/`), so a rebuild into a temporary folder can be
compared with the committed files. With the same inputs and `--timestamp`,
the output is byte-identical.

Before committing a metadata change, run `validate.R`, `build_sdmx.R
--check` and `build_docs.R --check`; when the legacy plans or the
converter changed, also rebuild and `publish.R --check` in
`20-excel-sdmx-csv/`.

## The validator

`validate.R` runs every `vc_*` check of the `pipeline/R/validate_*.R`
modules and writes one findings CSV (`check_id, severity, file, row_key,
message`), at most 20 findings per check and file plus a SUMMARY row. It
exits 1 on any ERROR, 2 if a check crashed. `--metadata-only` skips the
data files; `--data <file>` (repeatable, a logical path `data/<file>.csv`)
validates only those. The modules follow the standard's "Validation checks"
section:

- `STRUCT` (`validate_structure.R`): the DSD header, the file name
  `AFW360_HH_<REF_AREA>_<TIME_PERIOD>_<ESTIMATION>.csv` agreeing with the rows
  and the manifest, the 19-column key.
- `CODES` (`validate_codes.R`): codelists, slots, qualifiers against
  `INDICATOR_QUALIFIERS.csv` and `QUALIFIER_PAIRS.csv`, `SERIES_ID` against
  `SERIES_PLAN.csv`, `UNIT_MEASURE` (LCU resolved to `CL_AREA.currency`),
  `SOURCE_ID` against `SOURCES.csv` and the manifest.
- `COVER` (`validate_coverage.R`): the required rows of the file's
  `ESTIMATION` (country `SERIES_PLAN` rows over `ALL`, crossed with the cuts
  of `TAB_PLAN.csv`, `NOT_PRODUCED` left out, withheld cells of
  `LEGACY_OVERRIDES.csv` subtracted), the manifest and `SURVEYS.csv`, and a
  WARN for a `SURVEYS.csv` survey with no SURVEY data file or manifest.
  `TAB_PLAN.csv` and `LEGACY_*.csv` come from `../20-excel-sdmx-csv/plans/`;
  without them `COVER.SKIPPED` (INFO) replaces `COVER.MISSING`,
  `COVER.EXTRA` and `COVER.WITHHELD_PRESENT`, and the RULE checks over
  required rows find nothing to check.
- `VALUE` (`validate_values.R`): numbers, ranges, `PRECISION`, the
  reliability attributes (required on `PRODUCER`-source rows), and the
  `OBS_STATUS` rules (`E` in a `MODEL` file, `D` on `DEVIATES` series, `U` by
  the `RULES.csv` thresholds, no `Q`).
- `RULE` (`validate_rules.R`): every row of `RULES.csv`, with tolerances
  from each row's `PRECISION`, and the `N_POP` partition sums.
- `META` (`validate_metadata.R`): every metadata and content CSV against
  `COLUMNS.csv`, references, and the rules of `RULES.csv`,
  `INDICATOR_QUALIFIERS.csv`, `QUALIFIER_PAIRS.csv`, `SERIES_PLAN.csv` and
  `SOURCES.csv`. The legacy plans are checked by the Excel stage
  (`20-excel-sdmx-csv/R/plans_check.R`) against their own register.
- `DOCS` (`validate_docs.R`): the generated tables of this stage are
  current and included (`docs_check()` of `R/docs.R`); the tables of the
  legacy plans, which the Excel stage writes, are known but not rebuilt.
- `ASSET` and `TEXT` (`validate_assets.R`, `validate_text.R`): boundaries,
  figures and dashboard text.
- `SDMX` (`validate_sdmx.R`): the files under `output/` are current
  (`SDMX.STALE`, a fresh build compared byte for byte), the structure
  message is valid against the vendored XSD (`SDMX.XSD`), every URN in it
  resolves (`SDMX.URN`), every maintainable has the right agency, version,
  id and English name (`SDMX.IDENT`), and each data file has the SDMX-CSV
  header and `STRUCTURE_ID` of the DSD (`SDMX.CSV_HEADER`); `SDMX.SKIPPED`
  is reported on a stage without `output/`.

The findings helpers the modules share live once in `R/validate_common.R`,
which `validate.R` sources first. Findings are sorted with `method = "radix"`,
so the file is the same in every locale.

## Migrations

A structural change to the standard's metadata (adding, removing or
reordering a column, or a new file) is made by a one-off script in
`pipeline/migrations/<version>/`, one folder per target version, with a
README saying what it changes. Each script runs once: it is guarded on the
version it migrates from and refuses to run (exit 1) on any other
`metadata/VERSION`. Its test runs it with `--out-root` on a frozen copy of
the old metadata under `tests/testthat/fixtures/`. The migrations are
frozen: they take `--root <folder holding metadata/>`, which is `data/`
here:

```
Rscript pipeline/migrations/0.2.0/migrate.R --root data
Rscript pipeline/migrations/0.3.0/migrate.R --root data
```

Both have run; `data/metadata/VERSION` is `0.3.0`, so each now refuses to
run and is kept as the record of the change. Their output still contains
the legacy plans under `metadata/plans/`, which moved to
`20-excel-sdmx-csv/plans/` afterwards; `test-migrate-0.3.0.R` compares each
part with where it now lives.

## SDMX files: build and reverse import

`build_sdmx.R` writes `output/structures/AFW360_structures.xml` (one SDMX-ML
3.1 structure message: agency scheme, concepts, codelists, the DSD and
dataflow, the MSD and metadataflow, provider schemes, provision agreements)
and the four SDMX-CSV 2.1 metadata messages `output/metadata/MDS_*.csv`,
from `data/metadata/` and the dashboard's `content/TEXT.csv`. The structure
message is validated against `pipeline/xsd/sdmx-ml-3.1/` before it is
written; `--check` compares instead of writing. `--sdmx-ml-version 3.0
--out-root <dir>` writes the SDMX-ML 3.0 profile that Fusion Metadata
Registry 12.4 reads (no MSD, metadataflow or metadata provision agreement;
never committed). The code is in `R/sdmx_xml.R`, `R/sdmx_structures.R` and
`R/sdmx_refmeta.R`; `output/README.md` describes the files.

`import_sdmx.R` is the reverse direction, for structures edited elsewhere
(for example in FMR): it reads an SDMX-ML 3.0 or 3.1 structure message and
prints a unified diff against the CSVs under `data/metadata/` (`--diff`, the
default), or writes them (`--apply`, with `--out-root` to write elsewhere).
The generated sentinel codes `_T` and `_Z` are stripped. Rebuilding
`output/` from the imported CSVs gives the same file byte for byte, and an
unedited FMR export gives an empty diff. The code is in `R/sdmx_import.R`.

```
Rscript pipeline/import_sdmx.R --diff  <message.xml>
Rscript pipeline/import_sdmx.R --apply <message.xml>
```

## Tools

`pipeline/tools/` holds code outside the R pipeline, which never writes its
outputs:

- `tools/verify/` checks the SDMX files independently of the R code:
  `verify_sdmx.py` reads the structure message with pysdmx, validates it
  with lxml against the vendored XSD, reads the data messages and checks the
  metadata headers and targets; `check_urns.py` checks that every
  `WB.AFW360` URN in a message resolves. Its virtual environment is made by
  `make_venv.ps1` or `make_venv.sh` (`pipeline/tools/verify/README.md`). On
  the metadata files it is weaker than the build (see `output/README.md`).
- `tools/fmr/` holds the Fusion Metadata Registry scripts (`fmr_load.R`,
  `fmr_validate.R`, `fmr_export.R`) and install notes; the local FMR lives
  under `pipeline/tools/fmr/runtime/` (gitignored), the scripts keep their
  responses in the repository's `tmp/fmr/`, and the workflow is in
  `.docs/fmr-guide.qmd`.

The dashboard reads this stage's `data/` through
`10-legacy-pipeline/AFW360/afw360/loader.py` (`AFW360_ROOT` overrides it).

## Shared modules

Each stage has its own `R/` folder and runs on its own. The modules the
Excel stage also needs are copied, not shared across folders; an identical
copy of each lives in `20-excel-sdmx-csv/R/`:

- `io.R` (standard CSV and SDMX-CSV reading and writing, metadata loading, flags)
- `codes.R` (code syntax, slot ordering)
- `constants.R` (agency, dataflow, sentinels)
- `manifest.R` (data file names and manifests)
- `docs_md.R` (Markdown tables and the check of the generated tables)

Change both copies together; `20-excel-sdmx-csv/tests/testthat/test-shared-modules.R`
fails when they differ. `R/paths.R` is per stage and differs on purpose.

## Conventions

- **CSV format.** UTF-8 without a byte-order mark, LF line endings, one
  header row, the columns listed for that file in
  `data/metadata/structure/COLUMNS.csv` in that order. A missing value is an
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
  importer and XSD validation). Scripts source `pipeline/R/paths.R` from
  their own folder and every module through `stage_path(paths, "code", ...)`.
  Output is deterministic: rows are sorted and the current time is never
  written.
