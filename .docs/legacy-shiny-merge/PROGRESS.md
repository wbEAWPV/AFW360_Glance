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
