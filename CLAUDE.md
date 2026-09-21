# AFW 360 At A Glance

## What this project is

A pilot dashboard from the World Bank's AFW DIP/POV team that gives a one-page view of poverty and welfare for each country: international poverty rates, regional poverty maps, household profiles (consumption, jobs, agriculture, energy), fiscal equity, and key messages. It currently covers Senegal and Guinea-Bissau.

It began as a Quarto website (`index.qmd`, `_quarto.yml`) with Python chunks (pandas, matplotlib, geopandas) that read pre-computed indicator tables from Excel and render them as static tables, maps and charts. It is being ported to a **Shiny for Python app** (`app.py`) deployed to Posit Connect, with a static export kept on GitHub Pages. See `.docs/shiny-port-plan.md` — that document is the implementation contract for the port.

## Objectives

1. **Standardize and harmonize the data and the data pipeline.** Every country should use the same indicator names, disaggregation columns, geographic identifiers, units and file structure, and one shared pipeline should turn those inputs into the visuals.
2. **Write guidelines for extending and enriching the dataset.** Document how to add a country, an indicator, a disaggregation, a geographic level or a year without editing the dashboard code.
3. **Make the dashboard work well now, without changing the data flow yet.** Keep reading the current Excel, shapefile and text inputs as they are, but structure the code so the data source can be swapped later in one place.

**Working rule:** until objective 3 is done, don't restructure or edit the input files or change how they are loaded. Put fixes in the code and presentation layer, and route data access through a single loader per country so the later switch to a harmonized source touches one place.

## Commands

```bash
# Shiny app (the live dashboard)
.venv/Scripts/python -m shiny run app.py --reload    # local dev server
.venv/Scripts/python -m pytest                       # tests
.venv/Scripts/python scripts/build_geojson.py        # regenerate geo/*.json (needs geopandas)

# Legacy Quarto page (left in place, not the deliverable)
quarto preview
quarto render
```

Dependencies live in a **project-local `.venv`** created with `uv venv`. Never install into
the shared `C:\WBG\Python313`. `requirements.txt` is runtime only — geopandas, pytest and
rsconnect-python are dev-only and live in `requirements-dev.txt`.

## Layout

- `app.py`: the Shiny app — `page_navbar`, sidebar filters, wiring. Panels are split one module per page (`panels_overview.py`, `panels_profile.py`, `panels_geography.py`, `panels_explore.py`, `panels_about.py`) so that work on one page never collides with another.
- `data.py`: the **only** place that reads workbooks. Breakdown groups, the level-indicator format dict, `fmt()`, and the indicator catalogue. A later swap to a harmonized source touches this file alone (objective 3).
- `geo/adm1_{sen,gnb}.json`: simplified ADM1 GeoJSON, committed. Built offline by `scripts/build_geojson.py`; the running app needs no geopandas/GDAL.
- `index.qmd`: the legacy Quarto page, with one `#` section per country plus an About page. Left in place, unused by the app.
- `INPUT Tables/Tables_<ISO3>.xlsx`: indicator tables. The sheets are `National`, `ADM 1`, `ZAE` (agro-ecological zones) and `Departement` (SEN only). Tables are wide, with an `indicator` column holding free-text labels and one `estimate<Group>` column per disaggregation. Rates are stored as shares (0–1). The same 97 indicator labels appear in the same order in every 97-row sheet.
- `INPUT shp/<iso3>_admin*.shp`: administrative boundaries, lines and capitals.
- `INPUT Text/`: `About_<ISO3>.txt` (methodology) and `Messages_<ISO3>.txt` (key messages).
- `INPUT Figures/`: static images (fiscal equity).
- `dsf.qqqww`, `map_test.png`, `INPUT Tables/Tables_SEN_TEST.xlsx`: scratch or test files.

**Do not modify anything under `INPUT Tables/`, `INPUT shp/`, `INPUT Text/` or `INPUT Figures/`.**
The input files are producer-owned. Fixes go in the code and presentation layer.

## Data conventions

- Percentages are stored as fractions in the workbooks and formatted at display time; never pre-multiply by 100.
- **15 of the 97 indicators are levels, not shares** (FCFA, hectares, TLU, years, counts, "millions"). They must not be formatted with `{:.0%}`. The list lives in `data.py`; see plan §9.3.
- Indicator rows are selected by exact string match, including **en-dash U+2013** (`Employed (activ12m, 15–64)`, `Safe drinking water – dry season`) and **U+2265** (`≥1 HH member has health coverage …`).
- Select rows with `.reindex()`, never `.loc[row_order]` — a drifted label should leave a blank row, not raise `KeyError` and kill the render.
- **Empty is not zero.** A blank cell means "not computed" or "too few observations"; the workbooks do not distinguish them. Render as "–", never as `0`.
- Region names join to Excel columns through a normalisation that strips `estimate`, ASCII-folds and uppercases. GNB's capital is `estimateSAB` in Excel and `Bissau` in the shapefile — the alias is handled in the GeoJSON build.

## Upstream data defects — flag, do not fix

These are producer-side problems. The dashboard **shows them with a flag rather than hiding
them**, and never fabricates a replacement number. Full evidence in plan §10.

- **Fiscal Equity has no data** in either workbook (0 of its 5 indicators exist). It renders an explicit empty state. Four Agriculture rows and one Energy row are likewise code-only placeholders.
- **GNB `estimateCapital` is a copy of a zone, not Bissau**, so GNB's residence breakdown does not add up (~14% too high).
- **GNB `Cultivated area (ha)` is corrupt** — isolated cells in the tens of millions where the row is otherwise 1–15 ha.
- **SEN `Departement` sheet** is region-keyed despite its name, on 2017 PPP, and disagrees with `ADM 1` on 54 of 60 shared indicators. Leave it unread.
- `HH has internet access` and `wood_dist [ALL MISSING]` carry no information. Three overlapping electricity indicators span a 32-point spread and need definitions before any one is labelled "electricity access".

## Known issues in the legacy `index.qmd` (fixed by the port)

Kept as a record of what the port must not reproduce; evidence with line numbers in plan §9.1.

- The Guinea-Bissau section never sets its own `file_path`, so its tables and charts are built from `Tables_SEN.xlsx`. Its fiscal-equity cards also show the Senegal figure.
- `style_table` formats every cell as a percentage, so "Number poor (millions)" shows 6.52 as `652%`. Values are also rounded with `.round(1)` before that formatting, so 0.37 displays as `40%`.
- The layout uses Quarto Dashboard syntax (`## Row {height=…}`, `{.tabset}`, `#| title:`), but the format is `html`, so the page is not laid out as a dashboard. The 27 `#| title:` strings are the intended panel titles and are reused verbatim as card headers in the app.
- `download_figure` and `download_table` call `st.download_button` (Streamlit), which is never imported. Nothing calls either function.
- The key messages are hardcoded in `index.qmd`, and the `Messages_<ISO3>.txt` files are never read. The table-building code is copied for each country and each tab.
- `quarto render` fails outright on an unconditional `import geopandas as gpd` at `index.qmd:365`.

## Branches

`master` is the default branch. `dev/eb` carries the docs and the legacy page. **The Shiny
port is implemented on `dev/app`**, cut from `dev/eb`. Do not push, open a PR, or merge
across branches without asking.
