# AFW 360 At A Glance

## What this project is

A pilot dashboard from the World Bank's AFW DIP/POV team that gives a one-page view of poverty and welfare for each country: international poverty rates, regional poverty maps, household profiles (consumption, jobs, agriculture, energy), fiscal equity, and key messages. It currently covers Senegal and Guinea-Bissau.

It is a Quarto website (`index.qmd`, `_quarto.yml`) with Python chunks (pandas, matplotlib, geopandas). The chunks read pre-computed indicator tables from Excel and render them as tables, maps and charts. There is no Shiny server code yet, so the site renders as static pages.

## Objectives

1. **Standardize and harmonize the data and the data pipeline.** Every country should use the same indicator names, disaggregation columns, geographic identifiers, units and file structure, and one shared pipeline should turn those inputs into the visuals.
2. **Write guidelines for extending and enriching the dataset.** Document how to add a country, an indicator, a disaggregation, a geographic level or a year without editing the dashboard code.
3. **Make the dashboard work well now, without changing the data flow yet.** Keep reading the current Excel, shapefile and text inputs as they are, but structure the code so the data source can be swapped later in one place.

**Working rule:** until objective 3 is done, don't restructure or edit the input files or change how they are loaded. Put fixes in the code and presentation layer, and route data access through a single loader per country so the later switch to a harmonized source touches one place.

## Layout

- `index.qmd`: the entire dashboard, with one `#` section per country plus an About page.
- `INPUT Tables/Tables_<ISO3>.xlsx`: indicator tables. The sheets are `National`, `ADM 1`, `ZAE` (agro-ecological zones) and `Departement` (SEN only). Tables are wide, with an `indicator` column holding free-text labels and one `estimate<Group>` column per disaggregation. Rates are stored as shares (0–1).
- `INPUT shp/<iso3>_admin*.shp`: administrative boundaries, lines and capitals.
- `INPUT Text/`: `About_<ISO3>.txt` (methodology) and `Messages_<ISO3>.txt` (key messages).
- `INPUT Figures/`: static images (fiscal equity).
- `dsf.qqqww`, `map_test.png`, `INPUT Tables/Tables_SEN_TEST.xlsx`: scratch or test files.

Render with `quarto preview` or `quarto render`. Output goes to `_site/`, which is gitignored.

## Known issues (as of 2026-09-19)

- The Guinea-Bissau section never sets its own `file_path`, so its tables and charts are built from `Tables_SEN.xlsx`. Its fiscal-equity cards also show the Senegal figure.
- `style_table` formats every cell as a percentage, so "Number poor (millions)" shows 6.52 as `652%`. Values are also rounded with `.round(1)` before that formatting, so 0.37 displays as `40%`.
- Indicators are matched on free-text labels such as `"Poor at $4.20/day (2021 PPP)"`, so editing a label silently drops its row.
- Some column names are cut off at 32 characters (for example `estimateZiguinchor_Tamba_Kolda_S`), and the map joins regions by normalized name, not by code.
- The layout uses Quarto Dashboard syntax (`## Row {height=…}`, `{.tabset}`, `#| title:`), but the format is `html`, so the page is not laid out as a dashboard.
- `download_figure` and `download_table` call `st.download_button` (Streamlit), which is never imported. Nothing calls either function.
- The key messages are hardcoded in `index.qmd`, and the `Messages_<ISO3>.txt` files are never read. The table-building code is copied for each country and each tab.
