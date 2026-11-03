# AFW 360 At A Glance

> **Frozen (2026-11-02).** This repository is the legacy design, tagged `legacy-final`. New work happens in `worldbank/afw360-data` and `worldbank/afw360-tools`, which have their own `CLAUDE.md`; the design they follow is `.docs/01-whole-project-design.md`. The `legacy` branch takes only corrections to the Excel workbooks under `10-legacy-pipeline/data_raw/`. The rules below describe the frozen pipeline.

## What this project is

A pilot dashboard from the World Bank's AFW DIP/POV team that gives a one-page view of poverty and welfare for each country: international poverty rates, regional poverty maps, household profiles (consumption, jobs, agriculture, energy), fiscal equity, and key messages. It currently covers Senegal and Guinea-Bissau.

It is a Quarto website (`10-legacy-pipeline/AFW360/index.qmd`, `_quarto.yml`) with Python chunks (pandas, matplotlib, geopandas). The chunks read the harmonised files (SDMX-CSV 2.1 data, metadata CSVs, text, boundaries, figures) through one loader, `afw360/loader.py`, and render them as tables, maps and charts. The site renders as static pages. Next to it, in the same folder, is a Shiny for Python app (`10-legacy-pipeline/AFW360-shiny/`, started by `10-legacy-pipeline/app.py`; from branch `dev/app`) that is deployed to Posit Connect and still reads the legacy inputs; see `10-legacy-pipeline/README.md`.

## Objectives

1. **Standardize and harmonize the data and the data pipeline.** Every country should use the same indicator names, disaggregation columns, geographic identifiers, units and file structure, and one shared pipeline should turn those inputs into the visuals.
2. **Write guidelines for extending and enriching the dataset.** Document how to add a country, an indicator, a disaggregation, a geographic level or a year without editing the dashboard code.
3. **Make the dashboard work well now, without changing the data flow yet.** Keep reading the current Excel, shapefile and text inputs as they are, but structure the code so the data source can be swapped later in one place. Done (standard v0.6, 2026-09-29): both country sections and the About page read the harmonised files through `afw360/loader.py`.

**Working rule:** the dashboard reads only the harmonised files, and only through `afw360/loader.py`; a change of data source touches that module. The legacy inputs stay byte-frozen under `10-legacy-pipeline/data_raw/` (see `.docs/transition.qmd`): never edit them, and the dashboard shows nothing read from them; they are read by `20-excel-sdmx-csv/convert_legacy.R`, `build_geo.R`, `build_content.R` and `reconcile.R` (the loader keeps only a path helper to the legacy workbooks). The CSVs under `30-sdmx/data/metadata/`, `30-sdmx/data/`, `10-legacy-pipeline/data_dashboard/content/` and `20-excel-sdmx-csv/plans/` are the source of truth: change them by hand or by a script under `30-sdmx/pipeline/migrations/`, then regenerate `30-sdmx/output/` and `.docs/generated/` (never edit those by hand). Files that `20-excel-sdmx-csv/` builds (data files, GeoPackages, `GEO_SOURCES.csv`, `FIGURES.csv`, dashboard text and figure) are rebuilt there and copied by its `publish.R`, not edited in place.

**Exception:** the Shiny app in `10-legacy-pipeline/AFW360-shiny/` reads the frozen legacy inputs in `10-legacy-pipeline/data_raw/` directly (paths defined once in `data.py`: `DATA_RAW`, `TABLES_DIR`, `TEXT_DIR`, `FIGURES_DIR`). The rule "read only harmonised files through `afw360/loader.py`" applies to the Quarto dashboard. The app may only read `data_raw/`, never write to it.

## Layout

- `10-legacy-pipeline/`: both dashboards and their inputs; start with `10-legacy-pipeline/README.md` (copy-paste launch commands). One venv, `10-legacy-pipeline/.venv` (gitignored), serves both.
  - `app.py`, `requirements.txt`, `.python-version` (3.11.9), `.posit/publish/`: the Shiny launcher and its Posit Connect deployment, kept at this level because Connect publishes the whole folder (the app needs `data_raw/` and `data_dashboard/` in the bundle). `.posit/publish/deployments/deployment-OA6V.toml` ties it to Connect content `57e0a46b-db8d-4eeb-acca-994a67bfeb4c`; never edit the record.
  - `AFW360/`: the Quarto dashboard: `index.qmd` (one `#` section per country plus an About page), `_quarto.yml`, `requirements.txt`, and `afw360/`, its data-access layer (`loader.py`, `format.py` for `display_as` and `decimals`) and pytest tests. In `loader.py`, `DASHBOARD` is `AFW360/`, `DASHBOARD_DATA` is `data_dashboard/`, and `ROOT` is `30-sdmx/data/` (the data files directly in it, `metadata/`, `geo/`; override with `AFW360_ROOT`). `AFW360/` and `afw360/` differ only in case, so the package must stay nested inside `AFW360/` on Windows.
  - `AFW360-shiny/`: the Shiny app (`dashboard.py`, `data.py`, `panels_*.py`), `scripts/`, `tests/`, `requirements-dev.txt`, `DEPLOY.md` (tests, deploy, rebuilds). Paths are defined once in `data.py`.
  - `data_dashboard/`: files prepared for the dashboards: `content/` (`TEXT.csv`, `text/`) and `assets/figures/` for Quarto (published there by `20-excel-sdmx-csv/publish.R`, read by `30-sdmx` too); `geo/adm1_*.json` and `static_data/` for Shiny.
  - `data_raw/`: the byte-frozen legacy inputs (Excel tables, shapefiles, text, figures, `scratch/`), read by `20-excel-sdmx-csv/` and the Shiny app.
  - `tools/dashboard_numbers.py`: the numeric table cells of a rendered page, to compare two renders.
- `20-excel-sdmx-csv/`: R code that turns `10-legacy-pipeline/data_raw/` into the harmonised files: `convert_legacy.R`, `build_geo.R`, `build_content.R` write only into `output/` (gitignored); `publish.R` copies it to `30-sdmx/data/`, `30-sdmx/data/geo/`, `30-sdmx/data/metadata/registries/` and `10-legacy-pipeline/data_dashboard/{content,assets}/` (`--check` exits 1 on any difference); `reconcile.R`, `build_docs.R` (the tables of the plans); `plans/` (`TAB_PLAN.csv`, `LEGACY_*.csv`, their register `PLAN_COLUMNS.csv`), `bootstrap/` (frozen), `R/`, `tests/`. See `20-excel-sdmx-csv/README.md`.
- `30-sdmx/`: the standard, the data and the SDMX files. See `30-sdmx/README.md`.
  - `data/AFW360_HH_<ISO3>_<YEAR>_<ESTIMATION>.csv`: observations as SDMX-CSV 2.1 data messages (37 columns, 19-column key), each with a `_manifest.csv`. Rates are shares (0–1).
  - `data/metadata/`: the standard's metadata (codelists, DSD, `SERIES_PLAN.csv`, registries, rules, surveys), version in `data/metadata/VERSION` (0.3.0), changes in `data/metadata/CHANGELOG.md`.
  - `data/geo/boundaries/` (GeoPackages).
  - `output/`: generated SDMX files: `structures/AFW360_structures.xml` (SDMX-ML 3.1) and `metadata/MDS_*.csv` (SDMX-CSV 2.1 reference metadata). See `30-sdmx/output/README.md`.
  - `pipeline/`: `build_sdmx.R`, `validate.R`, `build_docs.R`, `import_sdmx.R`, `R/`, `xsd/`, `migrations/` (frozen), `tests/`, and `tools/verify/` (independent pysdmx and lxml checks), `tools/fmr/` (Fusion Metadata Registry scripts; the local install under `tools/fmr/runtime/` is gitignored).
- Each stage defines every location once in its `paths.R` (`20-excel-sdmx-csv/R/paths.R`, `30-sdmx/pipeline/R/paths.R`); `--root` is the stage folder (default: the stage of the script). The shared modules `io.R`, `codes.R`, `constants.R`, `manifest.R` and `docs_md.R` are byte-identical copies in both stages (a 20 test checks it). `30-sdmx` reads outside itself only the dashboard content and figures, the legacy plans (optional: without them the coverage checks report `COVER.SKIPPED`) and the legacy inputs for one hash check (optional).
- `.docs/`: the data standard, SDMX conformance, the transition record and the FMR guide.

Render with `quarto preview AFW360` or `quarto render AFW360` from `10-legacy-pipeline/` (with `QUARTO_PYTHON` set to its `.venv`). Output goes to `10-legacy-pipeline/AFW360/_site/`, which is gitignored. Run the R scripts with R 4.5.3 (the version recorded in the manifests). Before committing a metadata change run, from `30-sdmx/`, `Rscript pipeline/validate.R --out ../tmp/findings.csv`, `Rscript pipeline/build_sdmx.R --check` and `Rscript pipeline/build_docs.R --check`; after a change to the plans or the converter, from `20-excel-sdmx-csv/`, rebuild, `Rscript publish.R --check` and `Rscript build_docs.R --check`.

## Known issues (as of 2026-09-29)

- The layout uses Quarto Dashboard syntax (`### Column {.tabset}`, `#| title:`), but the format is `html`, so the page is not laid out as a dashboard.
- Guinea-Bissau shows no fiscal-equity figure: `30-sdmx/data/metadata/registries/FIGURES.csv` has none for GNB.
- Fusion Metadata Registry 12.4.2 rejects the SDMX-ML 3.1 structure message; it is loaded with the 3.0 profile (`build_sdmx.R --sdmx-ml-version 3.0`), which leaves out the MSD, the metadataflow and the metadata agreement, so the `30-sdmx/output/metadata/` files are not checked in FMR. `30-sdmx/pipeline/tools/verify` checks their headers by the last dotted segment only.
- Every code is still `DRAFT`, and the metadata versions are marked "unreleased" in `30-sdmx/data/metadata/CHANGELOG.md`.
- The manifests and `SOURCES.csv` record the converter as `pipeline/convert_legacy.R` (its path when the data were produced); the value is data and changes only with a metadata version.

Closed on branch `standard/v0.6-sdmx` (2026-09-29), now that the dashboard reads through the loader: Guinea-Bissau showed Senegal's data; `style_table` showed every cell as a percentage; rows were matched on free-text labels and regions by name (now series ids and geography codes); the unused Streamlit download helpers; hardcoded key messages (now `content/TEXT.csv`); table code copied per country.
