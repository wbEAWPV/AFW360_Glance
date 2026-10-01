# AFW 360 At A Glance: legacy dashboards

This folder holds two versions of the AFW 360 poverty and welfare dashboard (Senegal and
Guinea-Bissau):

- **`AFW360/`: the website dashboard made with Quarto.** It reads the harmonised data of
  this repository (`data/`, `metadata/`, `geo/` at the repository root).
- **`AFW360-shiny/`: the interactive Python Shiny dashboard.** This is the one published on
  Posit Connect:
  <https://w0lxdrconn01.worldbank.org/content/57e0a46b-db8d-4eeb-acca-994a67bfeb4c/>.
  It reads the original Excel tables in `data_raw/`.

## Start a dashboard on your computer

You need Python (3.11 recommended, the version Connect uses) and, for the Quarto dashboard,
Quarto (it comes with Positron and RStudio). Open a terminal **in the repository folder
`AFW360_Glance`** (in Positron: *Terminal > New Terminal*), paste one block and press Enter.
The first run installs the packages into `10-legacy-pipeline/.venv` and takes a few minutes;
later runs start in seconds. Stop a dashboard with `Ctrl+C`.

### Python Shiny dashboard

PowerShell:

```powershell
cd 10-legacy-pipeline
if (-not (Test-Path .venv)) { python -m venv .venv }
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python -m shiny run app.py --launch-browser
```

Git Bash:

```bash
cd 10-legacy-pipeline
[ -d .venv ] || python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt
.venv/Scripts/python -m shiny run app.py --launch-browser
```

The dashboard opens in your browser at <http://127.0.0.1:8000>.

### Quarto website dashboard

PowerShell:

```powershell
cd 10-legacy-pipeline
if (-not (Test-Path .venv)) { python -m venv .venv }
.venv\Scripts\python -m pip install -r AFW360\requirements.txt
$env:QUARTO_PYTHON = "$PWD\.venv\Scripts\python.exe"
quarto preview AFW360
```

Git Bash:

```bash
cd 10-legacy-pipeline
[ -d .venv ] || python -m venv .venv
.venv/Scripts/python -m pip install -r AFW360/requirements.txt
QUARTO_PYTHON="$PWD/.venv/Scripts/python.exe" quarto preview AFW360
```

Quarto builds the page (about a minute) and opens it in your browser.

On macOS or Linux, write `.venv/bin/python` instead of `.venv/Scripts/python`.

## What is in this folder

```
10-legacy-pipeline/
├── README.md            this file
├── app.py               starts the Shiny dashboard (the only Shiny file kept here)
├── requirements.txt     Python packages of the Shiny dashboard (Posit Connect installs these)
├── .python-version      Python version for Posit Connect (3.11.9)
├── .posit/              Posit Connect deployment settings (used by Positron's Publisher)
├── AFW360/              Quarto website dashboard: index.qmd, its code (afw360/), requirements.txt
├── AFW360-shiny/        Shiny dashboard: its code, tests, scripts, DEPLOY.md
├── data_dashboard/      files prepared for the dashboards: key messages and about text
│                        (content/), fiscal-equity image (assets/), region maps (geo/),
│                        a CSV copy of the Excel tables (static_data/)
└── data_raw/            the original inputs, never edited: Excel tables, text, figures,
                         shapefiles (see data_raw/README.md)
```

`app.py`, `requirements.txt`, `.python-version` and `.posit/` stay at the top because Posit
Connect publishes this whole folder: the Shiny dashboard needs `data_raw/` and
`data_dashboard/` to be inside what is published.

## Python packages (`requirements*.txt`)

A `requirements.txt` file lists the Python packages a program needs, with exact versions;
`pip install -r <file>` installs them. Both dashboards share one environment,
`10-legacy-pipeline/.venv` (a private folder of packages, not shared with other projects and
not saved in git).

| File | For | What it adds |
|---|---|---|
| `requirements.txt` | Shiny dashboard, locally and on Posit Connect | shiny, plotly, pandas, openpyxl |
| `AFW360/requirements.txt` | Quarto dashboard | pandas, geopandas, matplotlib, Jupyter |
| `AFW360-shiny/requirements-dev.txt` | developers of the Shiny dashboard | the Shiny list plus pytest, rsconnect-python, shinylive, geopandas |

To install everything at once:
`.venv\Scripts\python -m pip install -r AFW360-shiny\requirements-dev.txt -r AFW360\requirements.txt`.

## More

- Tests, deploying to Posit Connect, and rebuilding the maps and CSV copy:
  `AFW360-shiny/DEPLOY.md`.
- The Quarto dashboard: `AFW360/README.md`.
- The prepared files: `data_dashboard/README.md`. The original inputs: `data_raw/README.md`.
- If this computer blocks programs such as `shiny.exe` ("Access is denied"), keep using
  `python -m ...` as in the blocks above; they never call those programs.
