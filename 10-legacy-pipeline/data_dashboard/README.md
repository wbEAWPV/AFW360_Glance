# data_dashboard: files prepared for the dashboards

These files are made from the original inputs in `../data_raw/` (or by the repository's
pipeline). Do not edit them by hand; rebuild them as noted.

| Folder | Used by | What | How it is made |
|---|---|---|---|
| `content/` | Quarto (`AFW360/`) | `TEXT.csv` (key messages, about text) and `text/` (longer texts) | `pipeline/build_content.R` at the repository root |
| `assets/figures/` | Quarto | fiscal-equity image(s), listed in `metadata/registries/FIGURES.csv` | `pipeline/build_content.R` (a byte copy of `data_raw/figures/Fiscal Equity SEN.png`) |
| `geo/` | Shiny (`AFW360-shiny/`) | simplified region maps `adm1_sen.json`, `adm1_gnb.json` | `AFW360-shiny/scripts/build_geojson.py` from `data_raw/shp/` |
| `static_data/` | Shiny static export | the Excel tables as CSV, for the browser-only (Shinylive) version | `AFW360-shiny/scripts/build_static_data.py` from `data_raw/tables/` |

Check that `geo/` and `static_data/` still match `data_raw/` (from `10-legacy-pipeline/`):

```bash
.venv/Scripts/python AFW360-shiny/scripts/build_static_data.py --check
.venv/Scripts/python AFW360-shiny/scripts/build_geojson.py --check
```

Note: `pipeline/build_content.R` still writes `content/` and `assets/` at the repository
root, not here. Its paths have not been updated to this folder yet.
