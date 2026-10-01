# AFW360: the Quarto website dashboard

How to start it: see `../README.md` ("Quarto website dashboard").

- `index.qmd`: the whole page, one section per country plus an About page.
- `_quarto.yml`: Quarto settings. Only `index.qmd` is rendered; output goes to `_site/`
  (not saved in git).
- `afw360/`: the Python code that reads the data (`loader.py`) and formats numbers
  (`format.py`), with its tests (`afw360/tests/`).
- `requirements.txt`: the Python packages this page needs.

Where the data comes from:

- numbers, indicator metadata and region boundaries: the harmonised files at the repository
  root (`data/`, `metadata/`, `geo/`), read through `afw360/loader.py`;
- key messages, the about text and the fiscal-equity image: `../data_dashboard/content/` and
  `../data_dashboard/assets/`.

Run the tests from `10-legacy-pipeline/`: `.venv\Scripts\python -m pytest AFW360/afw360/tests -q`.

Rendering inside this repository can stop at the very end with "os error 32" on
`site_libs` (a file lock, usually Positron's file watcher); the page in `_site/` is complete.
If `QUARTO_R` holds a broken path, the render stops with "os error 123"; unset `QUARTO_R`.
