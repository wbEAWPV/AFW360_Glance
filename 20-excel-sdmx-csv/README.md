# 20-excel-sdmx-csv: legacy Excel inputs to SDMX-CSV

R code that turns the frozen legacy inputs (`10-legacy-pipeline/data_raw/`:
Excel workbooks, COD-AB shapefiles, text, the fiscal-equity figure) into
files that follow the data standard: the SDMX-CSV 2.1 data messages and
their manifests, the boundary GeoPackages, the dashboard text and figure,
and the registries those builders produce (`GEO_SOURCES.csv`,
`FIGURES.csv`). It owns the plans that map the legacy tables onto the
standard (`plans/`). How the first version was built is summarised in
`.docs/transition.qmd`.

The stage writes only into its own output folder. A separate step,
`publish.R`, copies the output to where the files live: the data and
boundaries to the SDMX stage (`30-sdmx/data/`), the registries to the
standard (`30-sdmx/data/metadata/registries/`), the text and figure to the
dashboard (`10-legacy-pipeline/data_dashboard/`). The SDMX stage then
builds and checks the SDMX files from there (`30-sdmx/README.md`).

## Layout

```
20-excel-sdmx-csv/
  convert_legacy.R   Excel workbooks -> output/data/AFW360_HH_<ISO3>_<YEAR>_SURVEY.csv + _manifest.csv
  build_geo.R        shapefiles -> output/geo/boundaries/*.gpkg + output/registries/GEO_SOURCES.csv
  build_content.R    About text, key messages, figure -> output/content/, output/assets/,
                     output/registries/FIGURES.csv
  publish.R          output/ -> its destinations (--check: exit 1 if any differs)
  reconcile.R        independent cell-by-cell check of the published data against the workbooks
  build_docs.R       plans/ -> .docs/generated/<id>.md, the tables of the legacy plans
  R/                 modules (paths, I/O, conversion, plans check, publish, docs)
  plans/             the legacy plans: TAB_PLAN.csv, LEGACY_LABELS.csv, LEGACY_COLUMNS.csv,
                     LEGACY_OVERRIDES.csv, and their column register PLAN_COLUMNS.csv
  bootstrap/         one-time generators of the standard's metadata 0.1.0 (frozen)
    seeds/           hand-written mapping tables: labels, codes, geography, columns, overrides
    text/            hand-written names and definitions
  tests/testthat/    unit tests
  output/            what the builders write (gitignored)
```

## Locations

Every location is defined once, in `R/paths.R`, relative to the stage
folder. `--root` is the stage folder (default: the folder of the script
that runs, so the scripts work from any directory). The stage reads:

| Kind | Folder | Override |
|---|---|---|
| legacy inputs (read only) | `../10-legacy-pipeline/data_raw/` | `--legacy-dir`, `AFW360_LEGACY_DIR` |
| the standard's metadata | `../30-sdmx/data/metadata/` | `--sdmx-dir <30-sdmx>`, `AFW360_SDMX_DIR` |
| published data (reconcile.R) | `../30-sdmx/data/` | as above |
| published dashboard text | `../10-legacy-pipeline/data_dashboard/content/` | `--dashboard-dir`, `AFW360_DASHBOARD_DIR` |
| generated tables | `../.docs/generated/` | |

`--out-root <dir>` is the output folder (default `output/`). It is laid out
like the destinations, and `publish.R` maps it (`PUBLISH_MAP` in
`R/paths.R`):

| Output | Destination |
|---|---|
| `output/data/` | `30-sdmx/data/` |
| `output/geo/` | `30-sdmx/data/geo/` |
| `output/registries/` | `30-sdmx/data/metadata/registries/` |
| `output/content/` | `10-legacy-pipeline/data_dashboard/content/` |
| `output/assets/` | `10-legacy-pipeline/data_dashboard/assets/` |

Nothing is ever written under `10-legacy-pipeline/data_raw/`.

## Running it

From `20-excel-sdmx-csv/` (R 4.5.3, the version recorded in the manifests
and in `SOURCES.csv`; a different R version changes the manifests'
`software` line):

```
# Rebuild into output/
Rscript build_geo.R
Rscript build_content.R
Rscript convert_legacy.R --country ALL --timestamp 2026-01-01T00:00:00Z
#   writes output/data/AFW360_HH_SEN_2021_SURVEY.csv, AFW360_HH_GNB_2021_SURVEY.csv
#   and their _manifest.csv (SDMX-CSV 2.1: 37 columns, 19-column key, ESTIMATION = SURVEY)

# Compare with what is published, then publish
Rscript publish.R --check        # exit 1 if any destination differs
Rscript publish.R                # copy what differs

# Check the published data against the workbooks
Rscript reconcile.R --out ../tmp/reconciliation.md

# The tables of the legacy plans in the documentation
Rscript build_docs.R             # --check: exit 1 if a generated table is stale

# Unit tests
Rscript tests/testthat.R
```

With the same inputs and `--timestamp`, a rebuild is byte-identical to the
published files, so `publish.R --check` exits 0 after an unchanged rebuild.
GeoPackages are the exception: their bytes change on every build, so
`publish.R` compares them by content (layers, CRS, attributes, geometries)
and keeps the published file and its `sha256` in `GEO_SOURCES.csv` when the
content is unchanged.

After publishing a change, rebuild and check the SDMX stage from
`30-sdmx/`: `Rscript pipeline/build_sdmx.R`, `Rscript pipeline/build_docs.R`
and `Rscript pipeline/validate.R --out ../tmp/findings.csv`.

## The plans

`plans/` holds the four tables that describe the legacy workbooks and how
their cells map onto the standard: `LEGACY_LABELS.csv` (row label to
series), `LEGACY_COLUMNS.csv` (column to cut and code), `LEGACY_OVERRIDES.csv`
(withheld cells and comments) and `TAB_PLAN.csv` (the cuts, which with the
standard's `SERIES_PLAN.csv` define the required rows). Their columns are
listed in `plans/PLAN_COLUMNS.csv`, in the format of the standard's
`COLUMNS.csv`. `R/plans_check.R` checks them (header and required columns
against `PLAN_COLUMNS.csv`, references into the standard: series ids,
geography, urbanisation and breakdown codes, cut ids; TBD cells), and
`convert_legacy.R` refuses to run while it reports an ERROR.

The SDMX stage reads `TAB_PLAN.csv` and the `LEGACY_*.csv` files from here
when this folder is present, for its coverage checks; without them it
reports `COVER.SKIPPED` and runs everything else.

## Shared modules

Each stage has its own `R/` folder and runs on its own. The modules both
stages need are copied, not shared across folders; an identical copy of
each lives in `30-sdmx/pipeline/R/`:

- `io.R` (standard CSV and SDMX-CSV reading and writing, metadata loading, flags)
- `codes.R` (code syntax, slot ordering)
- `constants.R` (agency, dataflow, sentinels)
- `manifest.R` (data file names and manifests)
- `docs_md.R` (Markdown tables and the check of the generated tables)

Change both copies together. `tests/testthat/test-shared-modules.R` fails
when they differ (it is skipped when `30-sdmx/` is not present).
`R/paths.R` is per stage and differs on purpose.

## The bootstrap scripts are frozen

`bootstrap/build_*.R` generated the first version (0.1.0) of every file
under the standard's metadata from `seeds/` and `text/`. From 0.1.0 onward
the CSV files are the source of truth and are edited directly; the
bootstrap scripts are not rerun or edited. They stay as the record of how
the first version was built, and still name the paths of that time.
`build_content.R` reads `bootstrap/text/figures_text.csv`, the one-off
caption of the fiscal-equity figure.

## Conventions

- **CSV format.** UTF-8 without a byte-order mark, LF line endings, one
  header row, the columns listed for that file in the standard's
  `metadata/structure/COLUMNS.csv` (or `plans/PLAN_COLUMNS.csv`) in that
  order. A missing value is an empty string (never `NA`); numbers are in
  fixed notation with at most 10 decimals. Write through `write_std_csv()`
  and read through `read_std_csv()` (`R/io.R`).
- **R code.** Base R plus readxl, dplyr, tidyr, readr, stringr, purrr, sf,
  digest, testthat and cli. Scripts source `R/paths.R` from their own
  folder and every module through `stage_path(paths, "code", ...)`; no other
  code builds a path from the root. Output is deterministic: rows are
  sorted and the current time is never written. Text from the workbooks
  (labels, accented place names) is copied byte for byte, never retyped.
- **Recorded program name.** The manifests and `SOURCES.csv` record the
  converter as `pipeline/convert_legacy.R`, its path when the data were
  produced. The value is data and is kept until a metadata version changes
  it in both places.
