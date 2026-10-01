# 10-legacy-pipeline: running and deploying

This folder holds two dashboards that share one set of frozen inputs.

| What | Files | Reads | Python environment |
|---|---|---|---|
| Shiny for Python app (deployed to Posit Connect) | `app.py`, `data.py`, `panels_*.py`, `geo/adm1_*.json`, `static_data/`, `scripts/`, `tests/`, `requirements.txt`, `requirements-dev.txt`, `.python-version`, `.posit/` | `data_raw/` directly (workbooks, text, figure) | `10-legacy-pipeline/.venv` |
| Quarto dashboard | `index.qmd`, `_quarto.yml`, `afw360/`, `content/`, `assets/`, `requirements-quarto.txt` | the harmonised files (`../data/`, `../metadata/`, `../geo/`) through `afw360/loader.py` | repository root `.venv` |

`data_raw/` is byte-frozen (see `data_raw/README.md`). Both dashboards only read it; nothing
may write there. The Shiny app came from branch `dev/app` (merged into this folder on
2026-10-01, see `../.docs/legacy-shiny-merge/`). Design background for the app is in
`../.docs/shiny-port-plan.md`.

## Shiny app

### Environment

Python **3.11.9**, pinned in `.python-version`. Posit Connect offers 3.8.18, 3.9.13 and
3.11.9 and matches on major.minor, so a bundle built with a newer Python fails to deploy
("Cannot find compatible environment").

This machine's Application Control policy blocks the pip-generated `.exe` wrappers
(`shiny.exe`, `rsconnect.exe`, `shinylive.exe`, and `uv.exe` launched through
`python -m uv`): "Access is denied" or `WinError 4551`. `python.exe` itself runs. So:

- run modules with `python -m shiny`, `python -m pytest`;
- run rsconnect with `python -c "from rsconnect.main import cli; cli()" <args>`;
- create the venv with the stdlib `venv` module of the uv-managed 3.11.9 interpreter.

From `10-legacy-pipeline/` (Git Bash):

```bash
"$APPDATA/uv/python/cpython-3.11.9-windows-x86_64-none/python.exe" -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements-dev.txt
```

Where `uv.exe` is allowed, `uv venv` followed by `uv pip install -r requirements-dev.txt`
does the same and reads `.python-version`. `.venv/` is gitignored.

`requirements.txt` is the runtime list that Connect installs (shiny, shinywidgets, plotly,
pandas, openpyxl, faicons). `requirements-dev.txt` adds pytest, geopandas (only for
`scripts/build_geojson.py`), rsconnect-python and shinylive. Never add geopandas to
`requirements.txt`: the app reads the pre-built `geo/*.json`, so Connect needs no GDAL.

### Run locally

```bash
.venv/Scripts/python.exe -m shiny run app.py --reload            # http://127.0.0.1:8000
.venv/Scripts/python.exe -m shiny run app.py --port 8765         # another port
```

Paths are resolved from `data.py`'s folder (`ROOT`), not the working directory, so the app
also runs when started from elsewhere. The input folders are defined once, in `data.py`:
`DATA_RAW`, `TABLES_DIR` (`data_raw/tables`), `TEXT_DIR` (`data_raw/text`),
`FIGURES_DIR` (`data_raw/figures`).

### Tests

```bash
.venv/Scripts/python.exe -m pytest tests -q          # the app: 86 tests, about 3 minutes
../.venv/Scripts/python.exe -m pytest afw360/tests -q   # the Quarto loader, root venv: 13 tests
```

Each suite runs in its own venv.

### Deploy to Posit Connect from Positron

The live content:

- server `https://w0lxdrconn01.worldbank.org`
- content id `57e0a46b-db8d-4eeb-acca-994a67bfeb4c`
- URL <https://w0lxdrconn01.worldbank.org/content/57e0a46b-db8d-4eeb-acca-994a67bfeb4c/>
- dashboard <https://w0lxdrconn01.worldbank.org/connect/#/apps/57e0a46b-db8d-4eeb-acca-994a67bfeb4c>

Publisher keeps two files in `.posit/publish/`:

- `AFW360_Glance-7O1V.toml`: the configuration (type `python-shiny`, entrypoint `app.py`,
  the file list, Python 3.11.9). Edit this one when the bundle needs to change.
- `deployments/deployment-OA6V.toml`: the deployment record that ties this folder to the
  content id above. **Do not edit it**; Publisher rewrites it on every deploy. It is what makes
  Publisher offer "Redeploy" to the same URL instead of creating new content.

Steps:

1. Open the repository in Positron and open the Posit Publisher sidebar.
2. Choose the `AFW360_Glance` deployment that belongs to `10-legacy-pipeline/` and check it
   shows content id `57e0a46b-...`. If Publisher does not list a project in a subfolder,
   open `10-legacy-pipeline/` itself as the workspace folder and look again.
3. Redeploy. Then open the URL and check both countries (Senegal, Guinea-Bissau) on every
   page.

What the bundle contains (the `files` list in the configuration, about 570 KB):
`app.py`, `data.py`, `panels_*.py`, `requirements.txt`, `geo/`, `static_data/`,
`data_raw/tables/Tables_SEN.xlsx`, `data_raw/tables/Tables_GNB.xlsx`, `data_raw/text/`,
`data_raw/figures/` and the two `.posit` files. Left out on purpose: the Quarto dashboard
(`index.qmd`, `_quarto.yml`, `afw360/`, `content/`, `assets/`), `data_raw/shp/` (28.6 MB, only
`scripts/build_geojson.py` reads it), `data_raw/scratch/`, `scripts/`, `tests/`,
`requirements-dev.txt` and `requirements-quarto.txt`. If you add a runtime file to the app,
add it to `files` too.

### Command-line alternative (rsconnect)

From `10-legacy-pipeline/`, with the app venv, after `add`ing the server and an API key once
(`python -c "from rsconnect.main import cli; cli()" add --server ... --name ... --api-key ...`):

```bash
.venv/Scripts/python.exe -c "from rsconnect.main import cli; cli()" deploy shiny . \
  --app-id 57e0a46b-db8d-4eeb-acca-994a67bfeb4c --entrypoint app \
  --exclude=index.qmd --exclude=_quarto.yml --exclude=DEPLOY.md --exclude=.gitignore \
  "--exclude=requirements-*.txt" "--exclude=afw360/**" "--exclude=content/**" \
  "--exclude=assets/**" "--exclude=data_raw/shp/**" "--exclude=data_raw/scratch/**" \
  "--exclude=data_raw/*.md" "--exclude=data_raw/*.sha256" \
  "--exclude=scripts/**" "--exclude=tests/**"
```

rsconnect does not read the Publisher configuration, so its bundle is set by the excludes.
Two traps: write each pattern as `--exclude=PATTERN` (click expands `*` in a separate
argument against the disk on Windows, which turns `afw360/*` into file names), and use `**`
(`*` matches one level only). With these excludes the bundle is the Publisher list plus
`.python-version`. Check it first without deploying: the same arguments after
`write-manifest shiny . --overwrite` (instead of `deploy shiny . --app-id ...`) write a
`manifest.json` that lists the files; delete it afterwards. Publisher is the primary route.

## Static export (Shinylive, GitHub Pages)

Secondary to Connect. `scripts/build_static_site.py` stages exactly the runtime files (with
`static_data/` instead of reading the workbooks, because Pyodide has no openpyxl) and exports
to `_shinylive/` (gitignored):

```bash
.venv/Scripts/python.exe scripts/build_static_site.py            # build
.venv/Scripts/python.exe scripts/build_static_site.py --serve    # build and serve on :8008
```

## Regenerating the app's derived files

Both are committed and must match `data_raw/`:

```bash
.venv/Scripts/python.exe scripts/build_static_data.py --check   # static_data/ vs the workbooks
.venv/Scripts/python.exe scripts/build_static_data.py           # rebuild static_data/
.venv/Scripts/python.exe scripts/build_geojson.py --check       # geo/*.json vs shapefiles and workbooks
.venv/Scripts/python.exe scripts/build_geojson.py               # rebuild geo/*.json (needs geopandas)
```

## Quarto dashboard

Uses the repository root `.venv` (Python 3.11.9) with the packages in
`requirements-quarto.txt` (pandas, geopandas, matplotlib, openpyxl, Jupyter kernel, jinja2,
pyyaml). From `10-legacy-pipeline/`:

```bash
QUARTO_PYTHON=../.venv/Scripts/python.exe quarto render    # or: quarto preview
```

`_quarto.yml` lists only `index.qmd` under `render:`, so Quarto ignores the app's `.py` files.
Output goes to `_site/` (gitignored).

Known local problems, neither caused by the app:

- Inside the repository the render can fail at the very end, at the `site_libs` cleanup, with
  "os error 32" (a file lock, most likely Positron's file watcher). The same files render with
  exit 0 from a copy outside the repository.
- If `QUARTO_R` holds a broken path (seen in a Claude Code session: `R-4.6.1\bin` with `\b`
  turned into a backspace), the render stops after the cells with "os error 123". Unset
  `QUARTO_R` for the render.
