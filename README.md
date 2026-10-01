# AFW 360 At A Glance

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
  data_raw/                                   A country team produces its tables
    Excel tables, maps, text, figures         directly in the standard format
          │                                             │
          ▼                                             │
  pipeline/  (R)                                        │
    convert, build maps and text                        │
          │                                             │
          └──────────────────┬──────────────────────────┘
                             ▼
      data/  geo/  metadata/  content/  assets/     ◄── pipeline/validate.R checks both routes
                             │
                             ▼
                  Dashboard  (index.qmd)
```

> **Today the dashboard still reads `data_raw/` directly.** Switching it to the standard files is the next step.

## What is where

| Folder | What it holds |
|---|---|
| `data_raw/` | The original inputs, frozen: Excel tables, shapefiles, text, figures. Never edited. |
| `data/` | The indicator values, one file per country and survey year (`AFW360_HH_SEN_2021.csv`) |
| `metadata/` | The dictionary: what each indicator, population group, area and survey means |
| `geo/` | Administrative boundaries (regions), one file per country |
| `content/`, `assets/` | Methodology text, key messages and figures |
| `pipeline/` | The R code that builds and checks all of the above |
| `index.qmd` | The dashboard (Quarto with Python) |
| `.docs/` | The data standard, the review of the input tables, and a summary of the conversion |

## How to…

### …add new data

1. Read the [data standard](.docs/data-standard.qmd). It explains how an indicator, a population group and an area are described.
2. Check that each indicator and group you need already exists in `metadata/codelists/`. If one is missing, add it.
3. Write your values as `data/AFW360_HH_<ISO3>_<YEAR>.csv`, with a manifest, following the standard.
4. Run the checks and fix every error:

   ```
   Rscript pipeline/validate.R --root . --out findings.csv
   ```

### …rebuild the standard files from `data_raw/`

```
Rscript pipeline/build_geo.R      --root .
Rscript pipeline/build_content.R  --root .
Rscript pipeline/convert_legacy.R --root . --country ALL --timestamp 2026-01-01T00:00:00Z
Rscript pipeline/validate.R       --root . --out findings.csv
Rscript pipeline/reconcile.R      --root . --out reconciliation.md
```

The output should be identical to the committed files. [`pipeline/README.md`](pipeline/README.md) has the details.

### …view the dashboard

Requires Quarto and Python 3.11 with pandas, geopandas, matplotlib and openpyxl.

```
quarto preview        # live preview
quarto render         # writes the site to _site/
```

## The data standard in brief

- **One value per row.** Each row states the country, year, indicator, population group and area it refers to.
- **Codes, not labels.** An indicator such as the poverty rate is one code (`POV_HC`). The poverty line and PPP round are separate fields, not part of the name.
- **Areas use official P-codes** (`SN01`, `GW08`), linked to the boundary files.
- **Everything is documented.** Each code has a name, a definition and a population universe in `metadata/`.
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
