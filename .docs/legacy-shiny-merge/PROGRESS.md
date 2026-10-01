# Progress: Shiny app into `10-legacy-pipeline/`

Contract: `plan.md` next to this file. Branch `dev/legacy-shiny`, cut from `dev/eb` at `fd48ef8`.

## WP0. Set up (2026-10-01)

- `git status` was clean at the start (no user edits pending).
- Created `dev/legacy-shiny` from `dev/eb` (`fd48ef8`).
- D2 gate: searched the repository (excluding venvs, `_site/`, `site_libs/`, FMR runtime,
  agent worktrees) for `requirements.txt`. No `.github/` or root `.posit/` exists. Every hit
  is either `tools/verify/requirements.txt` (unrelated), the plan/kickoff for this work, or a
  historical record of the former *root* `requirements.txt` in `.docs/data-standard.qmd`,
  `.docs/sdmx-transition/plan.md` and `.docs/sdmx-transition/PROGRESS.md`. Nothing relies on
  `10-legacy-pipeline/requirements.txt` being the Quarto list. Gate passed.
- Side note for the user: `.gitattributes` has `requirements.txt text eol=lf`; the renamed
  `requirements-quarto.txt` no longer matches that rule (harmless on this machine, but a fresh
  checkout with `core.autocrlf=true` gives it CRLF). Also `data_raw/** -text` is anchored to the
  root, so it does not cover `10-legacy-pipeline/data_raw/`. Both left unchanged (not in plan).
- Commit: the WP0 commit adding this file (hash recorded in the WP1 entry).

WP0 commit: `43b25d0`.

## WP1. Bring the files in (2026-10-01)

- `git merge -s ours --no-commit dev/app` first refused ("Merge with strategy ours failed")
  because the `requirements.txt` rename was already staged; reordered: merge first, then
  `git mv 10-legacy-pipeline/requirements.txt 10-legacy-pipeline/requirements-quarto.txt`
  (after the D2 gate, WP0), then `git checkout dev/app -- <paths>` and `git mv` under
  `10-legacy-pipeline/`.
- `git mv .posit 10-legacy-pipeline/.posit` failed with "Permission denied" (most likely
  Positron's Publisher watching the new folder); moved its two files one by one instead, and
  the empty root `.posit/` was removed.
- Checks: every brought-in file has the same blob as on `dev/app` (`app.py`, `data.py`,
  `panels_*.py`, `geo/adm1_*.json`, `static_data/`, `scripts/`, `tests/`, `requirements*.txt`,
  `.python-version`, both `.posit` files); `requirements-quarto.txt` has the blob of the old
  Quarto `requirements.txt`; merge parents are `43b25d0` and `dev/app` (`50d14ad`).
- Not brought in, as D5 says: `dev/app`'s root `index.qmd`, `_quarto.yml`, `CLAUDE.md`,
  `.gitignore`, `.nojekyll`, `.claude/`, `INPUT */`, `.docs/`.
- Commit: `55225a2` (merge commit).
- Seen, not mine, left alone: `.docs/10-full-pipeline.qmd` shows as modified in the working
  tree (it was clean at WP0; the user is editing it).

## WP2. Repoint inputs (2026-10-01)

- `data.py`: added `DATA_RAW`, `TABLES_DIR`, `TEXT_DIR`, `FIGURES_DIR` next to `ROOT`;
  `_WORKBOOK_FILES` and `about_text()` use them; error message and docstring name
  `data_raw/...`.
- `panels_profile.py`: `FISCAL_FIGURE = data.FIGURES_DIR / "Fiscal Equity SEN.png"`.
- Scripts define their own paths: `build_static_data.py` `WORKBOOK_DIR = ROOT / "data_raw" /
  "tables"`; `build_geojson.py` `SHP_DIR = ROOT / "data_raw" / "shp"`, `TABLE_DIR = ROOT /
  "data_raw" / "tables"`; `build_static_site.py` `DIRS`/`WORKBOOKS` stage `data_raw/text`,
  `data_raw/figures`, `data_raw/tables/Tables_{SEN,GNB}.xlsx`.
- Comments/docstrings: `panels_about.py`, `panels_overview.py`, `tests/test_app.py`,
  `scripts/build_geojson.py`, `scripts/build_static_site.py`. No `INPUT ` left in any `.py`.
  (The two `.posit` files still name `INPUT */`; the configuration is fixed in WP5, the
  record is never edited.)
- Checks (root `.venv`, which has pandas and openpyxl):
  - `scripts/build_static_data.py --check`: all 7 sheets match, exit 0.
  - `scripts/build_geojson.py --check`: SEN PASS (14/14), GNB PASS (9/9), exit 0.
  - Full `build_geojson.py` rebuild in a scratch copy outside the repository: output is 44,891
    and 30,060 bytes, the same size as the committed blobs, and JSON-equal to them; the
    working-copy files differ only by the CRLF that `core.autocrlf` adds on checkout. `geo/`
    not regenerated. `data_raw/` untouched (`git status` shows nothing under it).

WP2 commit: `40042ca`.

## WP3. App environment and tests (2026-10-01)

- Deviation from D6: `..\.venv\Scripts\python.exe -m uv venv` fails here with
  `OSError: [WinError 4551] An Application Control policy has blocked this file`
  (`python -m uv` only locates and spawns `uv.exe`, which the policy blocks). Fallback used:
  the stdlib `venv` module of the same uv-managed interpreter that the root `.venv` is based on
  (`%APPDATA%\uv\python\cpython-3.11.9-windows-x86_64-none\python.exe -m venv .venv`), then
  `.venv\Scripts\python.exe -m pip install -r requirements-dev.txt`. Result: Python 3.11.9,
  shiny 1.8.0, pandas 3.0.6, plotly 7.1.0, rsconnect-python installed. `.venv/` is gitignored.
- `.venv\Scripts\python.exe -m pytest tests -q` (app venv): **86 passed**, 2 warnings
  (shinywidgets `Widget.widgets is deprecated`), 169 s. No fixes were needed.
- `..\.venv\Scripts\python.exe -m pytest afw360/tests -q` (root venv): **13 passed**.
- No commit for code in this WP; this log entry is committed on its own.

WP3 commit: `8fc77ee`.

## WP4. Run the app (2026-10-01)

- From `10-legacy-pipeline/`: `.venv\Scripts\python.exe -m shiny run app.py --port 8765`
  in the background. `GET /` returned **200** (70,732 bytes; the navbar names Overview,
  Profile, Geography, Explore, About). Server log: startup complete, one `GET / 200 OK`, no
  tracebacks. Server stopped afterwards.
- **Visual check not done**: no browser tool was connected in this session. What covers it
  instead are the in-memory server tests run in WP3, which render the outputs for both
  countries, among them `test_the_senegal_fiscal_figure_is_shown_for_senegal_only`
  (reads `data_raw/figures/`), `test_guinea_bissau_gets_its_own_region_map`,
  `test_the_about_text_renders_and_is_not_senegals_for_guinea_bissau` (reads
  `data_raw/text/`) and `test_sweep_every_country_line_breakdown_and_geography_renders`.
  The user should still click through the five pages for SEN and GNB once.

WP4 commit: `b5820b0`.

## WP5. Connect configuration (2026-10-01)

- Read the Publisher v3 schema (`posit-publishing-schema-v3.json`) and
  `docs/configuration.md`: `files` takes project-relative, `.gitignore`-syntax patterns; a
  leading `/` anchors to the project folder; a directory includes its contents. `[python]`
  keys: `version`, `package_file`, `package_manager`, `requires_python`.
- `.posit/publish/AFW360_Glance-7O1V.toml` rewritten as D4 says: the 16 runtime entries, and
  `[python]` `version = "3.11.9"`, `package_file = "requirements.txt"`,
  `package_manager = "auto"`, `requires_python = "~=3.11.0"`. `type`, `entrypoint`, `title`,
  `validate`, `product_type`, `$schema` and the header comments unchanged; CRLF kept.
  Removed from the list: `/requirements-dev.txt`, `/INPUT *` (4), `/index.qmd`, `/scripts`.
  The deployment record `deployment-OA6V.toml` is not edited (it still shows the old file list
  and `version = "3.13.7"`; Publisher rewrites it on the next deploy).
- Note: the v3 schema's `package_manager` enum lists pip/conda/pipenv/poetry/none (the docs
  say pip/uv/none); `"auto"` is in neither, but Publisher 2.13.9 wrote it into the record's
  `[configuration.python]`, so it was kept as the plan says. If Publisher flags it, change it
  to `"pip"` or delete the line.
- Bundle check, in a scratch copy outside the repository with only the 16 `files` entries
  (28 files, 567 KB):
  - `python -c "from rsconnect.main import cli; cli()" write-manifest shiny <copy> --overwrite`:
    exit 0, `appmode = python-shiny`, entrypoint `app`, Python 3.11.9, the same 28 files.
    Warning "Python version constraint missing from pyproject.toml, setup.cfg or
    .python-version" (`.python-version` is not in the bundle; Publisher sends the version from
    `[python]`, so this concerns only the rsconnect command line).
  - In the copy, `data.py` sees both workbooks (Excel, not the CSV fallback), `about_text("SEN")`
    is 1,533 characters, the fiscal figure exists.
  - `python -m shiny run app.py --port 8766` in the copy: `GET /` **200**, no tracebacks.
  - Extra: the app's 86 tests, copied into the scratch copy only, **pass** against it.
  - Scratch copy deleted.

WP5 commit: `f19a873`.

## WP6. Quarto dashboard unaffected (2026-10-01)

- Scratch copy outside the repository: repository `data/`, `metadata/`, `geo/` and
  `10-legacy-pipeline/` without `.venv`, `_site`, `site_libs`, `.quarto`, `.pytest_cache`
  (so the copy includes the new app files). `_quarto.yml` `render:` still lists only
  `index.qmd`.
- First two attempts (Git Bash, then PowerShell) ran all 32 cells and then failed at the
  pandoc step: `ERROR: The filename, directory name, or volume label syntax is incorrect.
  (os error 123): stat 'C:\Program Files\R\R-4.6.1<BS>ind'`. Cause: this session's
  environment has `QUARTO_R` set to `C:\Program Files\R\R-4.6.1\bin` with `\b` turned into a
  backspace character. Not set in the user's persistent environment variables (only in the
  process environment Claude Code inherited); not caused by this work.
- With `QUARTO_R` unset and `QUARTO_PYTHON` = root `.venv`: `quarto render` **exit 0**,
  `Output created: _site\index.html`. Sections `Senegal`, `Guinea Bissau`, `About`;
  **14** `<table>`; **4** figure PNGs (the maps); no `Traceback`. `_site/` holds only
  `index.html`, `index_files/`, `assets/`, `site_libs/`, `search.json`: the `.py` files are
  not rendered. Scratch copy deleted.

WP6 commit: `4a6340b`.

## WP7. Documentation (2026-10-01)

- New `10-legacy-pipeline/DEPLOY.md`: what is in the folder (two dashboards, shared
  `data_raw/`); the app venv (with the Application Control workaround from WP3); running
  locally; both test suites; the Python 3.11.9 pin and why; deploying from Positron
  (content id, URLs, the two `.posit` files, what the bundle contains and why `data_raw/shp`
  is left out); the rsconnect command-line alternative; the Shinylive export; regenerating
  `static_data/` and `geo/`; rendering the Quarto dashboard (`requirements-quarto.txt`, root
  venv, the `site_libs` lock and the broken-`QUARTO_R` notes). Links
  `../.docs/shiny-port-plan.md`.
- The rsconnect command in DEPLOY.md was checked with `write-manifest shiny` (same
  arguments) on a scratch copy of the whole folder (without `.venv`, `_site`, ...): 29 files,
  the 28 of the Publisher bundle plus `.python-version`. Two traps found and documented:
  click expands `*` in a separate argument against the disk on Windows (first try failed with
  "File 'afw360\tests' is a directory"), so patterns are written `--exclude=PATTERN`; and `*`
  matches one level only, so `**` is used. `deploy` itself was not run (never deploy).
- Root `CLAUDE.md`: the project description names the Shiny app; an **Exception** paragraph
  after the working rule (the Shiny app reads `10-legacy-pipeline/data_raw/` directly; the
  loader rule applies to the Quarto dashboard); Layout now has a `10-legacy-pipeline/` entry
  (Quarto dashboard with `DASHBOARD` vs `ROOT`, Shiny app, `content/`, `assets/`,
  `data_raw/`) and the root `content/`, `assets/` and `data_raw/` entries are gone; the render
  line says "from `10-legacy-pipeline/`"; one Known issue added: `pipeline/*.R` still use root
  `data_raw/`, `content/`, `assets/` (checked: `pipeline/build_content.R:46,56,78` use
  `repo_path(root, "data_raw", ...)` and `repo_path(out_root, "content", ...)`). Other sections
  unchanged.
- `.docs/10-full-pipeline.qmd` not touched (it is still modified in the working tree by the
  user, unstaged).

WP7 commit: `3f87b9c`.

## WP8. Report (2026-10-01)

Status: WP0–WP8 done on `dev/legacy-shiny`. Not merged into `dev/eb`, not pushed, not deployed.
Waiting for the user.

Commits (first parent, oldest first): `43b25d0` WP0, `55225a2` WP1 (merge of `dev/app`),
`40042ca` WP2, `8fc77ee` WP3, `b5820b0` WP4, `f19a873` WP5, `4a6340b` WP6, `3f87b9c` WP7, and
the WP8 commit adding this entry.

Final checks:

- `git diff dev/eb HEAD` touches nothing under any `data_raw/`.
- `deployment-OA6V.toml` has the same blob as on `dev/app` (`41247e8`).
- `index.qmd`, `_quarto.yml`, `afw360/`, `content/`, `assets/` in `10-legacy-pipeline/` are
  unchanged against `dev/eb`; the only Quarto-side change is the D2 rename.

| Check | Result |
|---|---|
| App tests, app venv (`tests/`) | 86 passed |
| Quarto loader tests, root venv (`afw360/tests`) | 13 passed |
| `build_static_data.py --check` | 7/7 sheets match |
| `build_geojson.py --check`, rebuild in scratch | PASS; rebuild equals the committed blobs |
| App from `10-legacy-pipeline/`, `GET /` | 200, no tracebacks |
| Bundle-only scratch copy: `write-manifest`, `GET /`, the 86 tests | OK, 200, 86 passed |
| Quarto render in scratch copy outside the repo | exit 0 (with `QUARTO_R` unset), 3 sections, 14 tables, 4 maps |

Not verified:

- Clicking through the app in a browser (no browser tool in this session).
- That Positron's Publisher picks up the project in `10-legacy-pipeline/` and offers
  "Redeploy" to content `57e0a46b-...` (needs the user's Positron).
- That Publisher accepts `package_manager = "auto"` against its v3 schema (see WP5).
- The actual deploy (out of scope).
- A render of the Quarto page inside the repository (plan section 3: known `site_libs` lock).

Deviations from the plan: the venv is made with the stdlib `venv` module, not `uv venv`
(WP3); the `.posit` folder was moved file by file (WP1); the merge was started before the
rename (WP1).

For the user to decide or do:

1. In Positron, open the Publisher sidebar and check it lists the `AFW360_Glance`
   deployment from `10-legacy-pipeline/` with content id `57e0a46b-...`. If not, open
   `10-legacy-pipeline/` as the workspace folder.
2. Redeploy, then open the URL and check both countries on every page.
3. Merge `dev/legacy-shiny` into `dev/eb` when satisfied.
4. Optional follow-ups, not done here: `pipeline/*.R` still read root `data_raw/` and write
   root `content/`; `.gitattributes` has no `eol=lf` rule for `requirements-quarto.txt` and
   its `data_raw/** -text` rule is anchored to the root, so it does not cover
   `10-legacy-pipeline/data_raw/`; the session environment's `QUARTO_R` value is broken
   (see WP6) — if it comes from a Positron or shell setting, fix it there.

Untouched working-tree changes that are not mine: `.docs/10-full-pipeline.qmd` (modified) and
`.docs/15-legacy-verification.qmd` (new, untracked).

WP8 commit: `498f15d`.

## Phase 2. Restructure of `10-legacy-pipeline/` (2026-10-01, user request after WP8)

User decisions: the Quarto dashboard goes in `AFW360/`, the Shiny app in `AFW360-shiny/`,
the launcher stays at the top; the files built for the dashboards go in a sibling
`data_dashboard/` (not inside the frozen `data_raw/`); the harmonised data stays at the
repository root; Claude deploys with rsconnect.

New layout:

```
10-legacy-pipeline/
  README.md  app.py  requirements.txt  .python-version  .posit/
  AFW360/          index.qmd  _quarto.yml  requirements.txt  README.md  afw360/ (loader, tests)
  AFW360-shiny/    dashboard.py (was app.py)  data.py  panels_*.py  scripts/  tests/
                   requirements-dev.txt  DEPLOY.md
  data_dashboard/  content/  assets/  geo/  static_data/  README.md
  data_raw/        unchanged
```

- Case clash: on Windows `AFW360/` and the package `afw360/` are the same folder; the first
  `git mv` put the Quarto files into `afw360/`. Fixed by moving the package out, renaming
  the folder, and nesting the package as `AFW360/afw360/`.
- The Shiny `app.py` became `AFW360-shiny/dashboard.py`; the top-level `app.py` adds
  `AFW360-shiny/` to `sys.path` and imports `app` from it. Connect and `shiny run` use it,
  and so do the tests (`test_app.py` `APP` points at it).
- Path changes: `data.py` (`LEGACY`, `DATA_RAW = LEGACY/"data_raw"`, `DASHBOARD_DATA`,
  `GEO_DIR`, `_STATIC_DIR`); `panels_geography.py` and `panels_overview.py` use
  `data.GEO_DIR` (the overview one was missed at first: the test
  `test_guinea_bissau_gets_its_own_region_map` caught "14 of 0 regions"); the three scripts;
  `build_static_site.py` stages the new layout; `requirements-dev.txt` includes
  `-r ../requirements.txt`; `loader.py` gains `DASHBOARD_DATA`, and `ROOT` is now
  `DASHBOARD.parent.parent`; `index.qmd` embeds the fiscal-equity PNG as a data URI, because it
  is now outside the Quarto project and would not be copied into `_site/`.
- Publisher configuration: `files` updated for the new paths (13 entries, 29 files).
- One venv for both dashboards: `10-legacy-pipeline/.venv` now also has
  `AFW360/requirements.txt` installed; `pip check` clean.
- Docs: new `README.md` (plain-language, copy-paste launch blocks for PowerShell and Git
  Bash, structure, requirements files), `AFW360/README.md`, `data_dashboard/README.md`;
  `AFW360-shiny/DEPLOY.md` rewritten; root `CLAUDE.md` layout updated.
- Removed local, gitignored leftovers of the old layout: `_site/`, `site_libs/`,
  `.pytest_cache/`, `__pycache__/`. Not removed: `10-legacy-pipeline/.quarto/`, held open by a
  Quarto preview the user runs in Positron (PID 5152, port 4848); excluded from the rsconnect
  bundle.

Checks:

| Check | Result |
|---|---|
| App tests, `.venv` (`AFW360-shiny/tests`) | 86 passed (after the overview fix; 85 + 1 failure before) |
| Loader tests (`AFW360/afw360/tests`) | 13 passed |
| `build_static_data.py --check`, `build_geojson.py --check` | 7/7 sheets; SEN and GNB PASS |
| `python -m shiny run app.py` from `10-legacy-pipeline/` | `GET /` 200, no tracebacks |
| Copy holding only the Publisher `files` | 29 files; Excel, about text, figure, both maps found; `GET /` 200 |
| rsconnect `write-manifest` with the DEPLOY.md excludes | 30 files (Publisher list + `.python-version`), Python 3.11.9 |
| `quarto render` in `AFW360/` inside the repository | page complete (3 sections, 14 tables, 4 maps, figure), then the known `site_libs` "os error 32" |
| `quarto render` in a copy outside the repository | exit 0, same content |
| README blocks, PowerShell, fresh copy with system Python 3.13.7 and no venv | Shiny: install OK, `GET /` 200. Quarto: install OK, render exit 0, 14 tables |

The first fresh-copy attempt failed with `WinError 206` (path too long) because the scratch path
was very deep; at a short path it passed. The repository's own path is short enough.
