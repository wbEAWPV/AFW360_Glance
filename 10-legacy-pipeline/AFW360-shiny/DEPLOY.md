# AFW360-shiny: develop, test and deploy

How to start the dashboard: see `../README.md`. This file is for developers. All commands
run from `10-legacy-pipeline/`.

## Code

| File | Role |
|---|---|
| `../app.py` | Launcher: adds this folder to `sys.path` and imports `app` from `dashboard.py`. Connect and `shiny run` use it. |
| `dashboard.py` | The Shiny app: `page_navbar`, the sidebar's country filter, wiring of the pages |
| `panels_overview.py`, `panels_profile.py`, `panels_geography.py`, `panels_explore.py`, `panels_about.py` | One module per page |
| `data.py` | The only module that opens input files. Paths are defined once here: `DATA_RAW` (`../data_raw/`: `TABLES_DIR`, `TEXT_DIR`, `FIGURES_DIR`) and `DASHBOARD_DATA` (`../data_dashboard/`: `GEO_DIR`, the CSV copy) |
| `scripts/` | Offline builders: `build_geojson.py`, `build_static_data.py`, `build_static_site.py` |
| `tests/` | pytest suite (in-memory Shiny server tests through `../app.py`, and data tests) |
| `requirements-dev.txt` | `../requirements.txt` plus pytest, geopandas, rsconnect-python, shinylive |

Design background: `../../.docs/shiny-port-plan.md`. Origin: branch `dev/app`, merged on
2026-10-01 (`../../.docs/legacy-shiny-merge/`).

## Environment

Python **3.11.9** (`../.python-version`). Posit Connect offers 3.8.18, 3.9.13 and 3.11.9 and
matches on major.minor, so deploying from a newer Python fails ("Cannot find compatible
environment"). A local run works with 3.11 or newer.

This machine's Application Control policy blocks the pip-generated `.exe` wrappers
(`shiny.exe`, `rsconnect.exe`, `shinylive.exe`, and `uv.exe`, also when started by
`python -m uv`). `python.exe` runs. So use `python -m shiny`, `python -m pytest`,
`python -c "from rsconnect.main import cli; cli()" <args>`, and make the venv with the
stdlib `venv` of a 3.11.9 interpreter:

```bash
"$APPDATA/uv/python/cpython-3.11.9-windows-x86_64-none/python.exe" -m venv .venv
.venv/Scripts/python.exe -m pip install -r AFW360-shiny/requirements-dev.txt -r AFW360/requirements.txt
```

One venv, `10-legacy-pipeline/.venv`, serves both dashboards. Never add geopandas to
`../requirements.txt`: the app reads the pre-built `data_dashboard/geo/*.json`, so Connect
needs no GDAL.

## Run and test

```bash
.venv/Scripts/python.exe -m shiny run app.py --reload       # http://127.0.0.1:8000
.venv/Scripts/python.exe -m pytest AFW360-shiny/tests -q    # 86 tests, about 3 minutes
```

## Deploy to Posit Connect

The live content: server `https://w0lxdrconn01.worldbank.org`, content id
`57e0a46b-db8d-4eeb-acca-994a67bfeb4c`,
<https://w0lxdrconn01.worldbank.org/content/57e0a46b-db8d-4eeb-acca-994a67bfeb4c/>.

What is published is the folder `10-legacy-pipeline/`, with `app.py` as the entry point. The
bundle (about 570 KB) holds `app.py`, `requirements.txt`, `AFW360-shiny/dashboard.py`,
`AFW360-shiny/data.py`, `AFW360-shiny/panels_*.py`, `data_dashboard/geo/`,
`data_dashboard/static_data/`, `data_raw/tables/Tables_{SEN,GNB}.xlsx`, `data_raw/text/`,
`data_raw/figures/` and the `.posit` files. Left out: the Quarto dashboard, `data_raw/shp/`
(28.6 MB, used only by `build_geojson.py`), `data_raw/scratch/`, `scripts/`, `tests/`, the
READMEs and the other requirements files. If you add a runtime file to the app, add it to the
bundle too (both routes below).

### From Positron (Publisher)

`../.posit/publish/` holds the configuration `AFW360_Glance-7O1V.toml` (type, entry point,
`files` list, Python 3.11.9; edit this one) and the deployment record
`deployments/deployment-OA6V.toml`, which ties the folder to the content id. Do not edit the
record; Publisher rewrites it on each deploy.

1. Open the repository in Positron, open the Posit Publisher sidebar.
2. Choose the `AFW360_Glance` deployment of `10-legacy-pipeline/` (content id `57e0a46b-...`).
   If Publisher does not list a project in a subfolder, open `10-legacy-pipeline/` as the
   workspace folder.
3. Redeploy, then open the URL and check both countries on every page.

### From the command line (rsconnect)

Once, save the server with your API key (Connect: your name > API Keys):

```bash
.venv/Scripts/python.exe -c "from rsconnect.main import cli; cli()" add \
  --server https://w0lxdrconn01.worldbank.org --name wbconnect --api-key <YOUR_KEY>
```

Then deploy from `10-legacy-pipeline/` with the 3.11.9 venv:

```bash
.venv/Scripts/python.exe -c "from rsconnect.main import cli; cli()" deploy shiny . \
  --name wbconnect --app-id 57e0a46b-db8d-4eeb-acca-994a67bfeb4c --entrypoint app \
  --exclude=README.md --exclude=.gitignore \
  "--exclude=AFW360/**" "--exclude=data_dashboard/content/**" \
  "--exclude=data_dashboard/assets/**" "--exclude=data_dashboard/README.md" \
  "--exclude=AFW360-shiny/scripts/**" "--exclude=AFW360-shiny/tests/**" \
  "--exclude=AFW360-shiny/*.md" "--exclude=AFW360-shiny/requirements-dev.txt" \
  "--exclude=data_raw/shp/**" "--exclude=data_raw/scratch/**" \
  "--exclude=data_raw/*.md" "--exclude=data_raw/*.sha256" \
  "--exclude=.quarto/**" "--exclude=_shinylive/**"
```

rsconnect does not read the Publisher configuration; the excludes set the bundle. Write each
pattern as `--exclude=PATTERN` (on Windows, click expands a separate `*` argument against
the disk) and use `**` for folders (`*` matches one level). To see the bundle without
deploying, replace `deploy shiny . --name wbconnect --app-id ...` by
`write-manifest shiny . --overwrite` with the same excludes, read `manifest.json`, then
delete it.

## Static export (Shinylive, GitHub Pages)

Secondary to Connect. Pyodide has no openpyxl, so the export reads
`data_dashboard/static_data/` instead of the workbooks:

```bash
.venv/Scripts/python.exe AFW360-shiny/scripts/build_static_site.py            # to _shinylive/
.venv/Scripts/python.exe AFW360-shiny/scripts/build_static_site.py --serve    # and serve on :8008
```

## Rebuilding the prepared files

```bash
.venv/Scripts/python.exe AFW360-shiny/scripts/build_static_data.py --check   # CSV copy vs workbooks
.venv/Scripts/python.exe AFW360-shiny/scripts/build_static_data.py           # rebuild it
.venv/Scripts/python.exe AFW360-shiny/scripts/build_geojson.py --check       # maps vs shapefiles
.venv/Scripts/python.exe AFW360-shiny/scripts/build_geojson.py               # rebuild (needs geopandas)
```
