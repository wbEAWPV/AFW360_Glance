# data_dashboard: files prepared for the dashboards

These files are made from the original inputs in `../data_raw/` (or by the repository's
`20-excel-sdmx-csv/` stage). Do not edit them by hand; rebuild them as noted.

| Folder | Used by | What | How it is made |
|---|---|---|---|
| `content/` | Quarto (`AFW360/`) | `TEXT.csv` (key messages, about text) and `text/` (longer texts) | `20-excel-sdmx-csv/build_content.R`, copied here by `20-excel-sdmx-csv/publish.R` |
| `assets/figures/` | Quarto | fiscal-equity image(s), listed in `30-sdmx/data/metadata/registries/FIGURES.csv` | `20-excel-sdmx-csv/build_content.R` and `publish.R` (a byte copy of `data_raw/figures/Fiscal Equity SEN.png`) |
| `geo/` | Shiny (`AFW360-shiny/`) | simplified region maps `adm1_sen.json`, `adm1_gnb.json` | `AFW360-shiny/scripts/build_geojson.py` from `data_raw/shp/` |
| `static_data/` | Shiny static export | the Excel tables as CSV, for the browser-only (Shinylive) version | `AFW360-shiny/scripts/build_static_data.py` from `data_raw/tables/` |

Check that `geo/` and `static_data/` still match `data_raw/` (from `10-legacy-pipeline/`):

```bash
.venv/Scripts/python AFW360-shiny/scripts/build_static_data.py --check
.venv/Scripts/python AFW360-shiny/scripts/build_geojson.py --check
```

`content/` and `assets/` are rebuilt from `20-excel-sdmx-csv/` (into its `output/`) and
copied here by `Rscript publish.R`; `Rscript publish.R --check` exits 1 when they differ.
`30-sdmx/` reads them here too (its `MDS_TEXT.csv` and the TEXT and ASSET checks).
