# AFW 360 At A Glance

## What this project is

A pilot dashboard from the World Bank's AFW DIP/POV team that gives a one-page view of poverty and welfare for each country: international poverty rates, regional poverty maps, household profiles (consumption, jobs, agriculture, energy), fiscal equity, and key messages. It currently covers Senegal and Guinea-Bissau.

It is a Quarto website (`index.qmd`, `_quarto.yml`) with Python chunks (pandas, matplotlib, geopandas). The chunks read pre-computed indicator tables from Excel and render them as tables, maps and charts. There is no Shiny server code yet, so the site renders as static pages.

## Objectives

1. **Standardize and harmonize the data and the data pipeline.** Every country should use the same indicator names, disaggregation columns, geographic identifiers, units and file structure, and one shared pipeline should turn those inputs into the visuals.
2. **Write guidelines for extending and enriching the dataset.** Document how to add a country, an indicator, a disaggregation, a geographic level or a year without editing the dashboard code.
3. **Make the dashboard work well now, without changing the data flow yet.** Keep reading the current Excel, shapefile and text inputs as they are, but structure the code so the data source can be swapped later in one place.

**Working rule:** until objective 3 is done, don't restructure or edit the input files or change how they are loaded. Put fixes in the code and presentation layer, and route data access through a single loader per country so the later switch to a harmonized source touches one place. The inputs now live under byte-frozen `data_raw/` (moved from their original per-type folders during the data transition; see `.docs/transition.qmd`) and are still not edited.

## Layout

- `index.qmd`: the entire dashboard, with one `#` section per country plus an About page.
- `data_raw/tables/Tables_<ISO3>.xlsx`: indicator tables. The sheets are `National`, `ADM 1`, `ZAE` (agro-ecological zones) and `Departement` (SEN only). Tables are wide, with an `indicator` column holding free-text labels and one `estimate<Group>` column per disaggregation. Rates are stored as shares (0–1).
- `data_raw/shp/<iso3>_admin*.shp`: administrative boundaries, lines and capitals.
- `data_raw/text/`: `About_<ISO3>.txt` (methodology) and `Messages_<ISO3>.txt` (key messages).
- `data_raw/figures/`: static images (fiscal equity).
- `data_raw/scratch/`: scratch or test files (`Tables_SEN_TEST.xlsx`, `dsf.qqqww`, `map_test.png`, `Messages_SEN.txt2`). Nothing reads this folder.

Render with `quarto preview` or `quarto render`. Output goes to `_site/`, which is gitignored.

## Known issues (as of 2026-09-19)

Closed on branch `standard/v0.6-sdmx` (2026-09-29): the Guinea-Bissau section now reads Guinea-Bissau data through `afw360/loader.py` (it used to show Senegal's tables, charts and fiscal-equity figure; it shows no fiscal-equity figure while `metadata/registries/FIGURES.csv` has none for GNB), and every cell follows its indicator's `display_as` and `decimals` (the old `style_table` showed every cell as a percentage, so 6.52 million poor read `652%`).
- Indicators are matched on free-text labels such as `"Poor at $4.20/day (2021 PPP)"`, so editing a label silently drops its row.
- Some column names are cut off at 32 characters (for example `estimateZiguinchor_Tamba_Kolda_S`), and the map joins regions by normalized name, not by code.
- The layout uses Quarto Dashboard syntax (`## Row {height=…}`, `{.tabset}`, `#| title:`), but the format is `html`, so the page is not laid out as a dashboard.
- `download_figure` and `download_table` call `st.download_button` (Streamlit), which is never imported. Nothing calls either function.
- The key messages are hardcoded in `index.qmd`, and the `Messages_<ISO3>.txt` files are never read. The table-building code is copied for each country and each tab.
