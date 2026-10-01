# AFW 360 At A Glance

## What this project is

A pilot dashboard from the World Bank's AFW DIP/POV team that gives a one-page view of poverty and welfare for each country: international poverty rates, regional poverty maps, household profiles (consumption, jobs, agriculture, energy), fiscal equity, and key messages. It currently covers Senegal and Guinea-Bissau.

It is a Quarto website (`10-legacy-pipeline/index.qmd`, `_quarto.yml`) with Python chunks (pandas, matplotlib, geopandas). The chunks read the harmonised files (SDMX-CSV 2.1 data, metadata CSVs, text, boundaries, figures) through one loader, `afw360/loader.py`, and render them as tables, maps and charts. The site renders as static pages. Next to it, in the same folder, is a Shiny for Python app (`10-legacy-pipeline/app.py`, from branch `dev/app`) that is deployed to Posit Connect and still reads the legacy inputs; see `10-legacy-pipeline/DEPLOY.md`.

## Objectives

1. **Standardize and harmonize the data and the data pipeline.** Every country should use the same indicator names, disaggregation columns, geographic identifiers, units and file structure, and one shared pipeline should turn those inputs into the visuals.
2. **Write guidelines for extending and enriching the dataset.** Document how to add a country, an indicator, a disaggregation, a geographic level or a year without editing the dashboard code.
3. **Make the dashboard work well now, without changing the data flow yet.** Keep reading the current Excel, shapefile and text inputs as they are, but structure the code so the data source can be swapped later in one place. Done (standard v0.6, 2026-09-29): both country sections and the About page read the harmonised files through `afw360/loader.py`.

**Working rule:** the dashboard reads only the harmonised files, and only through `afw360/loader.py`; a change of data source touches that module. The legacy inputs stay byte-frozen under `data_raw/` (see `.docs/transition.qmd`): never edit them, and the dashboard shows nothing read from them; they are read by `pipeline/convert_legacy.R`, `build_geo.R`, `build_content.R` and `reconcile.R` (the loader keeps only a path helper to the legacy workbooks). The CSVs under `metadata/`, `content/` and `data/` are the source of truth: change them by hand or by a script under `pipeline/migrations/`, then regenerate `sdmx/` and `.docs/generated/` (never edit those by hand).

**Exception:** the Shiny app in `10-legacy-pipeline/` (`app.py`, `data.py`, `panels_*.py`) reads the frozen legacy inputs in `10-legacy-pipeline/data_raw/` directly (paths defined once in `data.py`: `DATA_RAW`, `TABLES_DIR`, `TEXT_DIR`, `FIGURES_DIR`). The rule "read only harmonised files through `afw360/loader.py`" applies to the Quarto dashboard. The app may only read `data_raw/`, never write to it.

## Layout

- `10-legacy-pipeline/`: both dashboards and their shared inputs. How to run, test and deploy them: `10-legacy-pipeline/DEPLOY.md`.
  - Quarto dashboard: `index.qmd` (one `#` section per country plus an About page), `_quarto.yml`, `requirements-quarto.txt`; `afw360/`, its data-access layer (`loader.py`, `format.py` for `display_as` and `decimals`) and pytest tests. In `loader.py`, `DASHBOARD` is this folder (with `content/` and `assets/`) and `ROOT` is the repository root (`data/`, `metadata/`, `geo/`; override with `AFW360_ROOT`). Uses the root `.venv`.
  - Shiny app: `app.py`, `data.py`, `panels_*.py`, `geo/adm1_*.json`, `static_data/`, `scripts/`, `tests/`, `requirements.txt` (what Connect installs), `requirements-dev.txt`, `.python-version` (3.11.9), `.posit/publish/` (Publisher configuration and the deployment record for Connect content `57e0a46b-db8d-4eeb-acca-994a67bfeb4c`; never edit the record). Uses its own `10-legacy-pipeline/.venv`.
  - `content/` (`TEXT.csv`, `text/`: about text and key messages) and `assets/figures/` (fiscal-equity images), read by the Quarto dashboard.
  - `data_raw/`: the byte-frozen legacy inputs (Excel tables, shapefiles, text, figures, `scratch/`), read by the pipeline and the Shiny app.
- `data/AFW360_HH_<ISO3>_<YEAR>_<ESTIMATION>.csv`: observations as SDMX-CSV 2.1 data messages (37 columns, 19-column key), each with a `_manifest.csv`. Rates are shares (0–1).
- `metadata/`: the standard's metadata (codelists, DSD, plans, registries, rules, surveys), version in `metadata/VERSION` (0.3.0), changes in `metadata/CHANGELOG.md`.
- `geo/boundaries/` (GeoPackages).
- `sdmx/`: generated SDMX files: `structures/AFW360_structures.xml` (SDMX-ML 3.1) and `metadata/MDS_*.csv` (SDMX-CSV 2.1 reference metadata). See `sdmx/README.md`.
- `pipeline/`: R code that builds `data/`, `geo/`, `content/`, `sdmx/` and `.docs/generated/` from `data_raw/` and `metadata/`, the reverse SDMX importer, the validator, migrations and tests. See `pipeline/README.md`.
- `tools/verify/` (independent pysdmx and lxml checks), `tools/fmr/` (Fusion Metadata Registry scripts; the local install under `tools/fmr/runtime/` is gitignored).
- `.docs/`: the data standard, SDMX conformance, the transition record and the FMR guide.

Render with `quarto preview` or `quarto render` from `10-legacy-pipeline/`. Output goes to `10-legacy-pipeline/_site/`, which is gitignored. Before committing a metadata change run `Rscript pipeline/validate.R --root . --out tmp/findings.csv`, `Rscript pipeline/build_sdmx.R --root . --check` and `Rscript pipeline/build_docs.R --root . --check`.

## Known issues (as of 2026-09-29)

- The layout uses Quarto Dashboard syntax (`### Column {.tabset}`, `#| title:`), but the format is `html`, so the page is not laid out as a dashboard.
- Guinea-Bissau shows no fiscal-equity figure: `metadata/registries/FIGURES.csv` has none for GNB.
- Fusion Metadata Registry 12.4.2 rejects the SDMX-ML 3.1 structure message; it is loaded with the 3.0 profile (`build_sdmx.R --sdmx-ml-version 3.0`), which leaves out the MSD, the metadataflow and the metadata agreement, so the `sdmx/metadata/` files are not checked in FMR. `tools/verify` checks their headers by the last dotted segment only.
- `pipeline/*.R` (and parts of this file's wording, such as the working rule) still name `data_raw/`, `content/` and `assets/` at the repository root; they moved to `10-legacy-pipeline/`. The R pipeline paths are not updated yet.
- Every code is still `DRAFT`, and the metadata versions are marked "unreleased" in `metadata/CHANGELOG.md`.

Closed on branch `standard/v0.6-sdmx` (2026-09-29), now that the dashboard reads through the loader: Guinea-Bissau showed Senegal's data; `style_table` showed every cell as a percentage; rows were matched on free-text labels and regions by name (now series ids and geography codes); the unused Streamlit download helpers; hardcoded key messages (now `content/TEXT.csv`); table code copied per country.
