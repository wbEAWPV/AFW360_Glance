# AFW 360 At A Glance

> **Frozen on 2026-11-02 as the legacy design**, tagged `legacy-final`. The project continues in two repositories: [afw360-data](https://github.com/worldbank/afw360-data), the Stata producers and the store, and [afw360-tools](https://github.com/worldbank/afw360-tools), the validator, catalogue, dashboard, API and agent. The design that replaces this one is [`.docs/01-whole-project-design.md`](.docs/01-whole-project-design.md). The `legacy` branch of this repository exists only for corrections to the Excel workbooks under `10-legacy-pipeline/data_raw/`; everything below describes the frozen pipeline.

A one-page poverty and welfare profile for each country in Western and Central Africa, built by the World Bank AFW Poverty team (DIP/POV). This is a pilot covering **Senegal** and **Guinea-Bissau** (EHCVM 2021/22).

Each country page shows:

- international poverty rates and the number of poor;
- poverty maps by region and agro-ecological zone;
- household profiles: consumption, jobs, agriculture, energy, enterprises;
- fiscal equity;
- key messages and methodology.

## Why this project exists

- **One structure for every country.** The same indicator names, population groups, area codes and units everywhere, so that countries can be compared and added without rework.
- **Proof of concept on existing data.** The current Excel tables were converted into the new structure without changing a single number. That shows the standard fits real survey output.
- **A basis for growth.** New countries, survey rounds, indicators and breakdowns go into the data, not into the dashboard code. The structure leaves room for sample sizes, standard errors and finer geography later.

## How it fits together

Data reach the standard files by two routes. Both end in the same place, and the dashboard reads from there.

```
  Route A: existing tables (done)             Route B: new data (the way forward)
  ──────────────────────────────              ─────────────────────────────────────
  10-legacy-pipeline/data_raw/                A country team produces its tables
    Excel tables, maps, text, figures         directly in the standard format
          │                                             │
          ▼                                             │
  20-excel-sdmx-csv/  (R)                               │
    convert, build maps and text, publish               │
          │                                             │
          └──────────────────┬──────────────────────────┘
                             ▼
      30-sdmx/data/  (data, metadata/, geo/)        ◄── 30-sdmx/pipeline/validate.R checks both routes
      10-legacy-pipeline/data_dashboard/  (content/, assets/)
                             │
                             ▼
      30-sdmx/output/ (SDMX)    Dashboard (10-legacy-pipeline/AFW360/index.qmd)
```

> **Today the dashboard still reads `data_raw/` directly.** Switching it to the standard files is the next step.

## What is where

| Folder | What it holds |
|---|---|
| `10-legacy-pipeline/data_raw/` | The original inputs, frozen: Excel tables, shapefiles, text, figures. Never edited. |
| `10-legacy-pipeline/AFW360/` | The dashboard (Quarto with Python, `index.qmd`); `AFW360-shiny/` is the Shiny version |
| `10-legacy-pipeline/data_dashboard/` | Methodology text, key messages and figures (`content/`, `assets/`) |
| `20-excel-sdmx-csv/` | The R code that turns the original inputs into the standard files, and the legacy plans |
| `30-sdmx/data/` | The indicator values, one file per country and survey year (`AFW360_HH_SEN_2021_SURVEY.csv`) |
| `30-sdmx/data/metadata/` | The dictionary: what each indicator, population group, area and survey means |
| `30-sdmx/data/geo/` | Administrative boundaries (regions), one file per country |
| `30-sdmx/output/` | The generated SDMX files |
| `30-sdmx/pipeline/` | The R code that checks all of the above and generates the SDMX files |
| `.docs/` | The data standard, the review of the input tables, and a summary of the conversion |

## How to…

### …add new data

1. Read the [data standard](.docs/data-standard.qmd). It explains how an indicator, a population group and an area are described.
2. Check that each indicator and group you need already exists in `30-sdmx/data/metadata/codelists/`. If one is missing, add it.
3. Write your values as `30-sdmx/data/AFW360_HH_<ISO3>_<YEAR>_<ESTIMATION>.csv`, with a manifest, following the standard.
4. Run the checks from `30-sdmx/` and fix every error:

   ```
   Rscript pipeline/validate.R --out ../tmp/findings.csv
   ```

### …rebuild the standard files from `data_raw/`

From `20-excel-sdmx-csv/`:

```
Rscript build_geo.R
Rscript build_content.R
Rscript convert_legacy.R --country ALL --timestamp 2026-01-01T00:00:00Z
Rscript publish.R --check        # 0 when the rebuild equals the committed files
Rscript reconcile.R --out ../tmp/reconciliation.md
```

then, from `30-sdmx/`:

```
Rscript pipeline/validate.R --out ../tmp/findings.csv
```

The output should be identical to the committed files. [`20-excel-sdmx-csv/README.md`](20-excel-sdmx-csv/README.md) and [`30-sdmx/README.md`](30-sdmx/README.md) have the details.

### …view the dashboard

Requires Quarto and Python 3.11 with pandas, geopandas, matplotlib and openpyxl.

From `10-legacy-pipeline/` (see its `README.md`):

```
quarto preview AFW360        # live preview
quarto render AFW360         # writes the site to AFW360/_site/
```

## The data standard in brief

- **One value per row.** Each row states the country, year, indicator, population group and area it refers to.
- **Codes, not labels.** An indicator such as the poverty rate is one code (`POV_HC`). The poverty line and PPP round are separate fields, not part of the name.
- **Areas use official P-codes** (`SN01`, `GW08`), linked to the boundary files.
- **Everything is documented.** Each code has a name, a definition and a population universe in `30-sdmx/data/metadata/`.
- **Nothing is final until confirmed.** Everything is `DRAFT` until the team marks it `ACTIVE`.

To learn more:

- [`.docs/data-standard.qmd`](.docs/data-standard.qmd): the full standard;
- [`.docs/transition.qmd`](.docs/transition.qmd): how the existing tables were converted;
- [`.docs/input-tables-findings.qmd`](.docs/input-tables-findings.qmd): what was found in the original tables.

## Status

- **Done:** standard v0.4; both countries converted and checked (every source value accounted for).
- **Next:** point the dashboard at the standard files; fix the known display issues listed in `CLAUDE.md`.
- **Later:** confirm the draft codes with the team; replace the Excel tables with producer files that include sample sizes and standard errors.

## Deployment

- **Posit Connect** is the main target. Deploy from Positron with Python 3.11.
- **GitHub Pages** hosts a static copy (branch `gh-pages`).

## Extending the dashboard

*To be written: step-by-step guides for adding a country, an indicator, a population group, a geographic level or a survey year.*
