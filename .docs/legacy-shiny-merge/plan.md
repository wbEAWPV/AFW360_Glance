# Plan: bring the Shiny app from `dev/app` into `10-legacy-pipeline/`

Written 2026-10-01. Status: approved in outline by the user, not started.
Progress is logged in `PROGRESS.md` next to this file.

## 1. Goal

Put the working Shiny for Python dashboard from branch `dev/app` **next to** the
Quarto dashboard in `10-legacy-pipeline/`, so that:

- the Quarto dashboard (`index.qmd`, `_quarto.yml`, `afw360/`, `content/`,
  `assets/`) keeps working exactly as it does now. Nothing of it is removed;
- the Shiny app runs from `10-legacy-pipeline/` and reads the frozen legacy inputs
  in `10-legacy-pipeline/data_raw/` (no copies of the data);
- the folder carries everything needed to **redeploy to the same Posit Connect
  content**, so a redeploy from Positron updates the existing URL;
- the deployment is documented in the folder itself.

Out of scope: deploying (the user does that from Positron), changing anything
under `data_raw/`, changing the harmonised pipeline (`data/`, `metadata/`, `sdmx/`,
`pipeline/`), and porting the app to the harmonised data.

## 2. What `dev/app` is

Shiny for **Python** (not R). 9 commits by Eduard Bukin on 2026-09-21
(`39b1566`..`50d14ad`), branched at `82d9cb9`, 179 commits behind `dev/eb`.

| Path on `dev/app` | Role |
|---|---|
| `app.py` | `page_navbar` + global sidebar (country filter); assembles the pages |
| `panels_overview.py`, `panels_geography.py`, `panels_profile.py`, `panels_explore.py`, `panels_about.py` | one module per page |
| `data.py` | the only module that reads workbooks; `ROOT = Path(__file__).parent` |
| `geo/adm1_sen.json`, `geo/adm1_gnb.json` | pre-built ADM1 GeoJSON (no geopandas at runtime) |
| `static_data/` | CSV mirror of the workbooks + `manifest.json`; `data.py` prefers it when present |
| `scripts/build_geojson.py`, `build_static_data.py`, `build_static_site.py` | offline builders (GeoJSON, CSV mirror, Shinylive export) |
| `tests/test_app.py`, `tests/test_data.py` | pytest |
| `requirements.txt` | runtime: shiny 1.8.0, shinywidgets 0.8.1, plotly 7.1.0, pandas 3.0.6, openpyxl 3.1.5, faicons 0.2.2 |
| `requirements-dev.txt` | `-r requirements.txt` + pytest, geopandas, rsconnect-python, shinylive |
| `.python-version` | `3.11.9` (Connect has 3.8.18 / 3.9.13 / 3.11.9, matches major-minor) |
| `.posit/publish/AFW360_Glance-7O1V.toml` | Posit Publisher configuration (`type = "python-shiny"`, `entrypoint = "app.py"`) |
| `.posit/publish/deployments/deployment-OA6V.toml` | deployment record, auto-generated ("do not edit") |
| `CLAUDE.md` | app-era project notes; the "Commands" and venv notes are still useful |

Live deployment (from the record):

- server `https://w0lxdrconn01.worldbank.org`
- content id `57e0a46b-db8d-4eeb-acca-994a67bfeb4c`
- URL `https://w0lxdrconn01.worldbank.org/content/57e0a46b-db8d-4eeb-acca-994a67bfeb4c/`
- deployed 2026-09-22, bundle 131272, Publisher client 2.13.9

Machine note (from `dev/app` `CLAUDE.md`): Application Control blocks the pip
wrapper `.exe`s (`shiny.exe`, `rsconnect.exe`, `shinylive.exe`, "Access is
denied"). Always run `python -m shiny ...`, `python -m pytest ...`, and for
rsconnect `python -c "from rsconnect.main import cli; cli()" <args>`.

## 3. Facts already verified (2026-10-01)

- Every runtime input of the app exists **byte-identical** (same git blob) in
  `10-legacy-pipeline/data_raw/`:

  | `dev/app` path | `dev/eb` path |
  |---|---|
  | `INPUT Tables/Tables_SEN.xlsx`, `Tables_GNB.xlsx` | `data_raw/tables/` |
  | `INPUT Tables/Tables_SEN_TEST.xlsx` | `data_raw/scratch/` (not needed at runtime) |
  | `INPUT Text/About*.txt`, `Messages_*.txt` | `data_raw/text/` |
  | `INPUT Text/Messages_SEN.txt2` | `data_raw/scratch/` (not needed) |
  | `INPUT Figures/Fiscal Equity SEN.png` | `data_raw/figures/` |
  | `INPUT shp/*` | `data_raw/shp/` (only `scripts/build_geojson.py` uses it) |

- Every hard-coded input path in the app (the full list to rewrite):
  - `data.py:63-64` `ROOT / "INPUT Tables" / ...`; `data.py:658` `ROOT / "INPUT Text" / ...`;
    docstrings/messages at `data.py:104,118-119,652`
  - `panels_profile.py:111` `data.ROOT / "INPUT Figures" / "Fiscal Equity SEN.png"`
  - `scripts/build_static_data.py:32` `WORKBOOK_DIR = ROOT / "INPUT Tables"`
  - `scripts/build_static_site.py:39-40` `DIRS = [..., "INPUT Text", "INPUT Figures"]`,
    `WORKBOOKS = ["INPUT Tables/...", ...]`, and the staging that copies them
  - `scripts/build_geojson.py:41-42` `SHP_DIR = ROOT / "INPUT shp"`, `TABLE_DIR = ROOT / "INPUT Tables"`
  - comments in `panels_about.py:10-11,31`, `panels_overview.py:95`, `tests/test_app.py:275`
  - `geo/` and `static_data/` paths are relative to `ROOT` and need no change.
- `.docs/shiny-port-plan.md` and `.docs/input-tables-findings.qmd` already exist on
  `dev/eb` (the port plan differs by one line). Do not copy them again; link to them.
- The repository-root `.gitignore` already has the app rules (`.venv/`,
  `__pycache__/`, `_shinylive/`, `rsconnect-python/`, ...). `10-legacy-pipeline/.gitignore`
  holds only Quarto rules.
- The root `.venv` is Python 3.11.9 with the Quarto dashboard's packages (geopandas,
  matplotlib); `uv` is installed in it (`.venv/Scripts/uv`).
- Rendering the Quarto page **inside the repository** fails at Quarto's final
  `site_libs` cleanup with "os error 32" (a file lock, most likely Positron's watcher).
  The same files render with exit 0 outside the repository. Not caused by this work; do
  not try to fix it here.

## 4. Decisions

- **D1. Layout: flat.** The app's files go directly in `10-legacy-pipeline/`, beside
  `index.qmd`. Reason: Connect bundles only the deployed folder, and the app reads
  `data_raw/`, so the deployed folder must contain `data_raw/`. A subfolder
  (`10-legacy-pipeline/shiny/`) would put the data outside the bundle.

  ```
  10-legacy-pipeline/
    index.qmd  _quarto.yml  afw360/  content/  assets/       Quarto dashboard (unchanged)
    app.py  data.py  panels_*.py                             Shiny app
    geo/adm1_*.json  static_data/  scripts/  tests/          Shiny app
    data_raw/                                                shared, byte-frozen
    .python-version  requirements.txt  requirements-dev.txt  Shiny app
    requirements-quarto.txt                                  Quarto dashboard (renamed)
    .posit/publish/...                                       Connect configuration + record
    DEPLOY.md                                                how to run and deploy both
  ```

- **D2. Requirements.** The app keeps `requirements.txt` (what Connect reads). The
  Quarto dashboard's list is renamed `requirements-quarto.txt`. Do not merge them: that
  would put geopandas/GDAL on Connect, which the app was designed to avoid.
  *Gate:* before renaming, search the repository (`.github/`, `.posit/`, docs, scripts)
  for anything that relies on `10-legacy-pipeline/requirements.txt` being the Quarto list.
  If something does, stop and ask the user.

- **D3. Paths.** One place defines the input folders. In `data.py` add, next to `ROOT`:
  ```python
  DATA_RAW = ROOT / "data_raw"
  TABLES_DIR = DATA_RAW / "tables"
  TEXT_DIR = DATA_RAW / "text"
  FIGURES_DIR = DATA_RAW / "figures"
  ```
  and use them in `data.py` and `panels_profile.py`. Scripts may define their own
  equivalents (they run standalone), with `SHP_DIR = ROOT / "data_raw" / "shp"`.

- **D4. Same Connect content.** Copy `.posit/publish/` from `dev/app` into
  `10-legacy-pipeline/.posit/publish/`, keeping both file names and the deployment record
  unchanged, so Publisher matches it to content `57e0a46b-...` and offers "Redeploy".
  Edit only the configuration file `AFW360_Glance-7O1V.toml`:
  - `files` = exactly the runtime set:
    `/app.py`, `/data.py`, `/panels_about.py`, `/panels_explore.py`,
    `/panels_geography.py`, `/panels_overview.py`, `/panels_profile.py`,
    `/requirements.txt`, `/geo`, `/static_data`,
    `/data_raw/tables/Tables_SEN.xlsx`, `/data_raw/tables/Tables_GNB.xlsx`,
    `/data_raw/text`, `/data_raw/figures`,
    `/.posit/publish/AFW360_Glance-7O1V.toml`,
    `/.posit/publish/deployments/deployment-OA6V.toml`.
    Leave out `index.qmd`, `_quarto.yml`, `afw360/`, `content/`, `assets/`,
    `data_raw/shp` (28.6 MB), `data_raw/scratch`, `scripts/`, `tests/`,
    `requirements-dev.txt`, `requirements-quarto.txt`.
  - `[python]`: `version = "3.11.9"`, `package_file = "requirements.txt"`,
    `package_manager = "auto"`, `requires_python = "~=3.11.0"` (match the
    `[configuration.python]` block in the record, but with 3.11.9).
  - Keep `title = "AFW360_Glance"`, `type = "python-shiny"`, `entrypoint = "app.py"`.
  Never edit the deployment record; Publisher rewrites it on the next deploy.
  Before writing the config, read the Publisher schema linked in its `$schema`
  line (WebFetch) to confirm the keys and the leading-`/` file pattern syntax.

- **D5. History.** Record `dev/app` as merged so its 9 commits stay reachable:
  `git merge -s ours --no-commit dev/app`, then bring the files in with
  `git checkout dev/app -- <paths>` and `git mv` them under `10-legacy-pipeline/`,
  then commit once as the merge commit. Do **not** bring `dev/app`'s root `index.qmd`,
  `_quarto.yml`, `CLAUDE.md`, `.gitignore`, `.nojekyll`, `.claude/`, `INPUT */`,
  `.docs/` or root `geo/` (root `geo/` on `dev/eb` holds the harmonised GeoPackages).

- **D6. Two virtual environments.** The app gets its own
  `10-legacy-pipeline/.venv` (gitignored by the root rule), made with
  `..\.venv\Scripts\python.exe -m uv venv` from `10-legacy-pipeline/` (reads
  `.python-version`), then `-m uv pip install -r requirements-dev.txt`. The Quarto
  dashboard keeps using the root `.venv`. Run `tests/` with the app venv and
  `afw360/tests` with the root venv.

- **D7. Branch.** Work on a new branch `dev/legacy-shiny` cut from `dev/eb`. Commit
  after each work package. Merge into `dev/eb` only after the user approves the final
  report. Never push, never deploy.

## 5. Work packages

**WP0. Set up.** Check `git status`. The user may have uncommitted edits (on
2026-10-01: `.docs/10-full-pipeline.qmd`): never stage, stash, revert or commit them,
and always `git add` explicit paths. Create `dev/legacy-shiny` from `dev/eb`. Create
`PROGRESS.md` here.

**WP1. Bring the files in (D5).** Merge with `-s ours --no-commit`; check out from
`dev/app`: `app.py`, `data.py`, `panels_*.py`, `geo/adm1_sen.json`,
`geo/adm1_gnb.json`, `static_data/`, `scripts/`, `tests/`, `requirements.txt`
(after WP2's rename, see the order below), `requirements-dev.txt`, `.python-version`,
`.posit/`. Move each under `10-legacy-pipeline/`. Order inside this WP: first
`git mv 10-legacy-pipeline/requirements.txt 10-legacy-pipeline/requirements-quarto.txt`
(after the D2 gate), then bring in the app's `requirements.txt`. Commit as the merge
commit: "Merge dev/app: Shiny app next to the Quarto dashboard in 10-legacy-pipeline".
At this point the app still points at `INPUT *`; that is fixed in WP2.

**WP2. Repoint inputs (D3).** Apply the path list in section 3. Update docstrings and
comments that name `INPUT ...` so they name `data_raw/...`. Run
`scripts/build_static_data.py --check`: `static_data/` must still match the workbooks
byte for byte (it should, since the workbooks are identical). Do not regenerate
`geo/*.json` unless `build_geojson.py` output differs; if it differs, report it and
keep the committed files.

**WP3. App environment and tests (D6).** Create the venv, install
`requirements-dev.txt`, run `python -m pytest tests -q`. Fix only failures caused by
the move (paths). Any other failure: record it in `PROGRESS.md` and report, do not
fix. Also run the Quarto loader tests with the root venv:
`..\.venv\Scripts\python.exe -m pytest afw360/tests -q` (13 tests passed on
2026-10-01).

**WP4. Run the app.** `python -m shiny run app.py --port 8765` in the background from
`10-legacy-pipeline/`. Check `GET /` returns 200 and the log has no tracebacks. If a
browser tool is available, click through the five pages for SEN and GNB, and confirm the
fiscal-equity figure, the maps and the About text load; otherwise state that the visual
check was not done. Stop the server afterwards.

**WP5. Connect configuration (D4).** Edit `AFW360_Glance-7O1V.toml` as specified.
Verify the bundle locally without deploying, using rsconnect's write-manifest from a
throwaway copy:
`python -c "from rsconnect.main import cli; cli()" write-manifest shiny <tmpcopy> --overwrite`
on a scratch copy that contains only the `files` list. Confirm the app starts from that
copy (`python -m shiny run app.py` in the copy, `GET /` 200). This proves the listed
files are sufficient. Delete the scratch copy.

**WP6. Quarto dashboard unaffected.** Render a scratch copy of the same layout outside
the repository (repository `data/`, `metadata/`, `geo/` + `10-legacy-pipeline/` minus
`.venv`) with `QUARTO_PYTHON` set to the root venv; expect exit 0, sections Senegal,
Guinea Bissau, About, 14 tables, 4 maps, no tracebacks. Make sure `_quarto.yml`'s
`render:` list still names only `index.qmd`, so Quarto ignores the `.py` files.

**WP7. Documentation.**
- `10-legacy-pipeline/DEPLOY.md` (new). Sections: what is in the folder (two dashboards,
  shared `data_raw/`); run the Shiny app locally (venv, `python -m shiny run app.py
  --reload`, the Application Control note); tests; the Python 3.11.9 pin and why; deploy
  to Connect from Positron (open the repository, Publisher sidebar → choose the
  `AFW360_Glance` deployment in `10-legacy-pipeline/` → Redeploy; the content id and URL
  from section 2; what the bundle contains and why `data_raw/shp` is left out); the
  rsconnect command-line alternative; the Shinylive export
  (`scripts/build_static_site.py`, GitHub Pages is secondary); rendering the Quarto
  dashboard (`requirements-quarto.txt`, root venv, the `site_libs` lock note);
  regenerating `static_data/` and `geo/`. Link `.docs/shiny-port-plan.md` for design
  background.
- Root `CLAUDE.md`: update Layout for `10-legacy-pipeline/` (both dashboards,
  `content/`, `assets/`, `data_raw/` now live there; the loader's `ROOT` vs
  `DASHBOARD`); add the exception to the working rule: *the Shiny app in
  `10-legacy-pipeline/` reads the frozen legacy inputs directly; the rule "read only
  harmonised files through `afw360/loader.py`" applies to the Quarto dashboard.* Keep the
  rest; do not rewrite unrelated sections.
- Do not touch `.docs/10-full-pipeline.qmd` (user's work in progress).

**WP8. Report.** Update `PROGRESS.md` with what was done, commit hashes, test results,
what was not verified, and the manual steps left for the user (below). Stop and wait
for the user before merging into `dev/eb`.

## 6. Manual steps for the user (not for the agent)

1. In Positron, open the Publisher sidebar and check that it lists the `AFW360_Glance`
   deployment from `10-legacy-pipeline/` with content id `57e0a46b-...`.
   If Publisher does not pick up a project in a subfolder, open `10-legacy-pipeline/`
   as the workspace folder and look again.
2. Redeploy, then open the URL and check both countries.

## 7. Known risks

- Publisher's handling of a project in a subfolder of the workspace is not verified
  here (step 6.1). If it cannot see it, the fallback is opening `10-legacy-pipeline/`
  as the workspace in Positron, or the rsconnect command line from that folder.
- `data_raw/` is byte-frozen. The app only reads it; any write (for example a
  regenerated file landing there) is a bug.
- `pipeline/*.R` and the root `CLAUDE.md` still reference root `data_raw/`, `content/`,
  `assets/` (moved by the user before this work). Fixing the R pipeline paths is out of
  scope; mention it in the report.
