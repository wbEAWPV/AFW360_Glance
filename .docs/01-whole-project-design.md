# AFW 360: whole-project design (reshape v1)

Status: design agreed in discussion on 2026-11-02; nothing implemented yet.
Owner: AFW DIP/POV team (data lead: Eduard Bukin).
Supersedes: the SDMX-based standard v0.6 (`data-standard.qmd`, `sdmx-conformance.qmd`, `transition.qmd`), which is frozen as the legacy design.

This page records every decision taken in the design review, with the examples that were used to take them, so that the next sessions (provisional data, tools design, content, agent) start from a shared understanding. Where a point is deferred or belongs to the team, it is listed as such at the end.

## 1. Why the project is reshaped

The SDMX transition (standard v0.6, metadata 0.3.0) is complete and verified: two SDMX-CSV 2.1 data files, an SDMX-ML 3.1 structure message, reference metadata, a validator, a reverse importer and an FMR round trip. It was never released (every code is `DRAFT`). The machinery is far larger than its payload: about 14,000 lines of R pipeline code, 6,000 lines of tests, 24 modules, 30 metadata CSVs and 7,700 lines of documentation for 5,271 observations from two countries. Most of it was written by agents, and a human cannot maintain or extend it by hand.

The goal of the reshape is a project that new users can take over and extend: compute new indicators for new countries and surveys in Stata, store the results in a simple, documented and discoverable form, and serve them through an API, a dashboard and an agent.

## 2. Guidelines adopted

Two World Bank sources were studied (by two research agents, 2026-11-02) and are adopted as the project's guidelines.

**Practical Guide to AI-Ready Data Dissemination** (<https://worldbank.github.io/ai4data/cookbook/ai-ready-dissemination/>, v0.1), with its companion guide *Serving Statistics to AI Agents*. The points that shape this design:

- Data as a tidy long file, one row per observation, codes in the data and labels in code lists, column names taken from SDMX concepts (`SERIES`, `REF_AREA`, `TIME_PERIOD`, `OBS_VALUE`, `OBS_STATUS`, `UNIT_MEASURE`, `RELEASE`). SDMX-CSV is the first-choice format; a CSV with SDMX concept names plus a table schema (Frictionless or CSVW) is the accepted alternative where SDMX tooling is not in place. This project takes the alternative.
- One complete catalogue record per series, following the World Bank `timeseries-schema.json`, checked with `check_metadata.py` against `profile_indicator.json` (structure, completeness, validity). Units must be explicit; a share stored as 0.38 must never be readable as 38 percent.
- Stable, predictable URLs per series and a bulk file; a `RELEASE` date that changes when a value changes; a revisions log; a citation format; licence in every response.
- A REST API described by OpenAPI 3 with the version in the path, and later a read-only MCP server with four tools (`search_series`, `get_series_metadata`, `get_observations`, `list_code_values`), a guidance resource, structured outputs using the schema's field names, and an evaluation question set. Building an MCP server without an API and data layer underneath is listed as a mistake, and chat interfaces come last.
- The data and API must work with the AI layer switched off, and a new person must be able to run the updates from the documentation alone.

**World Bank metadata schemas** (<https://github.com/worldbank/metadata-schemas>, JSON Schema draft-07; `timeseries` 1.0.0, `timeseries-db`, `microdata` 1.1.0, `geospatial` 1.0.0, `script` 1.0.0). The records this project will generate:

- one `indicators_db` record for the database (`database_description.title_statement.idno`, `indicators[]`, `dimensions[]`, `geographic_granularity`, `access_options[]`);
- one `timeseries` record per published series (`series_description.idno`, `name`, `definition_long`, `measurement_unit`, `periodicity`, `time_periods[]`, `geographic_units[]`, `sources[]`, `dimensions[]`, `methodology`, `universe`, `limitation`, `license[]`, `citation_requirement`, `databases[{id, is_primary}]`), with project-specific fields under `additional`;
- `microdata` records are not written by this project; the surveys are documented in the World Bank Microdata Library and referenced by their idno;
- `geospatial` and `script` records are optional later additions.

The schemas are validated against the JSON files in `schemas/` directly. The PyPI package `metadataschemas` (0.1.3) and the Excel templates lag behind the 1.0.0 schemas and are not relied on. The World Bank Data360 structure (named dimensions `SEX`, `AGE`, `URBANISATION`, generic `COMP_BREAKDOWN_1..3` slots, `_T` for totals) is followed for the column layout.

## 3. The pipeline in six steps

1. **Raw data.** Survey microdata (EHCVM 2021 for Senegal and Guinea-Bissau today). Never stored in a repository, never sent to an AI service. Documented in the Microdata Library.
2. **Indicator code.** Stata: a harmonisation step per survey programme and wave, then one do-file per indicator family. A recipe-driven engine (indicator defined by metadata, computed generically) is noted as future work for an R or Python implementation.
3. **Store.** Long CSV files with SDMX column names, hand-maintained code lists and family metadata in YAML, generated World Bank JSON records. This is the core of the reshape and the subject of most of this page.
4. **API.** `/api/v1` with OpenAPI, serving the store with provenance in every response.
5. **Dashboard.** Shiny for Python on Posit Connect, reading the store or the API through one client interface.
6. **Agent.** An MCP server over the same client interface, with a guidance resource and an evaluation set. Last.

Because there is no microdata yet, step 3 is built first and populated from the legacy Excel tables (step 2 in its legacy form). Steps 4 and 5 follow together; step 6 last.

## 4. Repositories

Two repositories replace `AFW360_Glance`.

**`afw360-data`** holds the producers and the master copy of the store:

```
afw360-data/
  00_config/          config_template.do (committed); config_local.do (gitignored)
  01_harmonize/       ehcvm_2021.do, ehcvm_2021_SEN.do, ehcvm_2021_GNB.do
                      dictionary/variables.csv, breakdowns.csv, qualifiers.csv
  02_indicators/      POV_HC.do, AGR_CULTIVATES.do, ... (one per family)
                      _helpers/afw360_tabulate.ado
                      legacy_excel/convert.py, mapping.csv
  03_store/           data/<survey_id>.csv
                      codelists.csv, geo.csv, povlines.csv
                      catalog/series/<FAMILY>.yaml, catalog/surveys.csv
                      MANIFEST.csv, REVISIONS.csv, FORMAT.md
  docs/recipes/       add-a-code.md, add-a-breakdown.md, add-a-qualifier.md,
                      add-an-indicator.md, add-a-survey.md
```

The folders are numbered in the order of work. `config_local.do` holds the machine-specific paths: `AFW360_RAW` (raw survey files), `AFW360_MICRO` (harmonised files on a shared World Bank drive, in a versioned folder such as `harmonized/2026.11`), `AFW360_LEGACY_XLSX` (the frozen Excel workbooks on the `legacy` branch of `AFW360_Glance`).

**`afw360-tools`** holds everything that reads the store: the validator, the ingest step, the catalogue builder, the release script, the API, the dashboard and later the agent, as one pip-installable Python package plus app folders. Its detailed design is settled in a separate session (see section 13). It carries a synced copy of the store in `data/` with a `data/VERSION` file naming the afw360-data release tag and commit; `afw360 sync <tag>` refreshes it and CI fails if the copy differs from the tag. A `pins` board on Posit Connect is a second, interchangeable source of the same files, selected by `AFW360_SOURCE=local|pins`; a test opens both and checks they are identical.

**`AFW360_Glance`** becomes the legacy repository: `restructure/pipeline-20-30` is merged into `master`, tagged `legacy-final`, a branch `legacy` is created for corrections to the Excel workbooks only, and the README points to the two new repositories. The SDMX work stays findable; nothing is deleted. The FMR runtime is stopped and left on disk (gitignored). None of the existing documentation (`.docs/`, the stage READMEs, `CLAUDE.md`) is carried into the new repositories: they describe the legacy design and stay here. The new repositories start with this page as their only inherited document, and each writes its own README and recipes.

## 5. The store: observation files

One file per survey, named after the survey id: `03_store/data/SEN_2021_EHCVM_v01_M.csv`. A new survey round adds a file; existing files change only through revisions (section 10). The per-series files and the bulk file that the cookbook asks for are generated by the tools for the API, not stored.

Format version 1 has 20 columns:

```
SERIES, REF_AREA, TIME_PERIOD, SEX, AGE, URBANISATION,
COMP_BREAKDOWN_1, COMP_BREAKDOWN_2, COMP_BREAKDOWN_3,
QUAL_1, QUAL_2, QUAL_3,
OBS_VALUE, UNIT_MEASURE, OBS_STATUS, STD_ERR, N_OBS,
SURVEY_ID, RELEASE, OBS_COMMENT
```

Examples (values invented except the first two):

```csv
SERIES,REF_AREA,TIME_PERIOD,SEX,AGE,URBANISATION,COMP_BREAKDOWN_1,COMP_BREAKDOWN_2,COMP_BREAKDOWN_3,QUAL_1,QUAL_2,QUAL_3,OBS_VALUE,UNIT_MEASURE,OBS_STATUS,STD_ERR,N_OBS,SURVEY_ID,RELEASE,OBS_COMMENT
AGR_CULTIVATES,SN01,2021,_Z,_Z,_T,_T,_T,_T,_Z,_Z,_Z,0.01,SHARE,A,,,SEN_2021_EHCVM_v01_M,2026-11-15,
POV_HC,SN01,2021,_T,_T,_T,_T,_T,_T,PL420,PPP21,_Z,0.03,SHARE,A,,,SEN_2021_EHCVM_v01_M,2026-11-15,
POV_HC,SEN,2021,_T,_T,R,HHH_SEX_F,_T,_T,PL420,PPP21,_Z,0.43,SHARE,A,0.012,905,SEN_2021_EHCVM_v01_M,2026-11-15,
CONS_SH,SN01,2021,_Z,_Z,_T,_T,_T,_T,CP01,ACQ_OWNPROD,_Z,0.00,SHARE,A,,,SEN_2021_EHCVM_v01_M,2026-11-15,
DEM_AGE_GINI_HH,SEN,2021,F,_T,_T,HHH_SEX_F,_T,_T,_Z,_Z,_Z,0.33,INDEX,A,0.009,1650,SEN_2021_EHCVM_v01_M,2026-11-15,
```

Column meanings and rules:

- `SERIES` is the indicator family (`POV_HC`, `CONS_SH`), never a family-plus-qualifier id. The qualifiers that make a family into a specific series live in the `QUAL_*` columns.
- `REF_AREA` is the ISO 3166-1 alpha-3 country code for national rows (`SEN`) or the OCHA COD p-code for ADM1 rows (`SN01` Dakar, `GW01` Bafatá). The national total has `URBANISATION=_T`; `URBANISATION` splits may exist at both levels. There is no separate "country total" code.
- `TIME_PERIOD` is the survey's reference year from `surveys.csv`, even when fieldwork spans two calendar years.
- `SEX` and `AGE` describe the individuals counted. Household-level series carry `_Z`; individual-level series carry `_T` for the total and codes for the split. `AGE` codes follow SDMX (`Y_GE15`, `Y15T24`), as in Data360.
- `URBANISATION`: `CAP` (capital city), `U` (other urban), `R` (rural), `_T`.
- `COMP_BREAKDOWN_1..3` hold household or group characteristics with self-describing codes (`HHH_SEX_F`, `QUINTILE_Q1`, `EMP_SECTOR_AGR`). Slots are filled from slot 1 with no gaps, in the order the family YAML lists its breakdowns; unused slots are `_T`. Crossings are limited by the family's `max_cross`.
- `QUAL_1..3` hold measurement parameters (`PL420`, `PPP21`, `CP01`, `ACQ_OWNPROD`), in the order the family YAML lists its qualifiers; unused slots are `_Z`.
- `OBS_VALUE` is numeric; rates are shares between 0 and 1.
- `UNIT_MEASURE` is a code (`SHARE`, `INDEX`, `HA`, `XOF`, `TLU`, `DAY`, `PERSON`); the label of `SHARE` is "Share (0–1)".
- `OBS_STATUS` uses the SDMX codes: `A` normal, `P` provisional, `B` break, `E` estimated, `C` confidential (value suppressed, kept so the user knows it exists). Rows with no value and no suppression reason are not stored; an absent key means "not available".
- `STD_ERR` and `N_OBS` are required for every row computed from microdata (design-based, from `svy:`); empty only for legacy rows.
- `SURVEY_ID` is the survey's own identifier, the Microdata Library idno. The file name equals it.
- `RELEASE` is the date the row's value was last published; it changes only when the value changes.
- `OBS_COMMENT` is free text; it is not used to carry provenance.

There is no `PRODUCER` column. Provenance is carried by the release manifest and the producer registries (section 10).

Decision history: the breakdown and qualifier slots are 3 each, chosen on 2026-11-02 after Data360's `COMP_BREAKDOWN_1..3`; today's data uses at most 2 of each.

## 6. The store: code lists

Hand-maintained; a source of truth, never written by a script. One common file plus two side files for the lists that carry extra attributes.

`03_store/codelists.csv`:

```csv
codelist,code,name_en,name_fr,parent,order,status,replaced_by,notes
REF_AREA,SEN,Senegal,Sénégal,,1,active,,ISO 3166-1 alpha-3
REF_AREA,SN01,Dakar,Dakar,SEN,1,active,,
URBANISATION,CAP,Capital city,Capitale,U,1,active,,
URBANISATION,U,Urban,Urbain,,2,active,,
URBANISATION,R,Rural,Rural,,3,active,,
SEX,F,Female,Femme,,1,active,,sex of the individuals counted
BREAKDOWN,HHH_SEX_F,Female household head,Chef de ménage femme,HHH_SEX,1,active,,
BREAKDOWN,EMP_SECTOR_AGR,Agriculture (ISIC A),Agriculture (CITI A),EMP_SECTOR,1,active,,
POVLINE,PL420,$4.20 a day,,,2,active,,
PPP,PPP21,2021 PPP,,,2,active,,
COICOP,CP01,Food and non-alcoholic beverages,Produits alimentaires et boissons non alcoolisées,,1,active,,
UNIT_MEASURE,SHARE,Share (0-1),Proportion (0-1),,1,active,,0.38 means 38 percent
OBS_STATUS,A,Normal,Normal,,1,active,,SDMX
```

`03_store/geo.csv` (one row per `REF_AREA` code, the crosswalk and the geometry link):

```csv
code,level,country,nso_code,ocha_pcode,wb_gad_code,boundary_id
SEN,country,SEN,,,,
SN01,ADM1,SEN,01,SN01,SEN001,SEN_CODAB_v02
```

`03_store/povlines.csv` (values for the Stata helper; relative lines need no new text):

```csv
code,value,base,multiplier
PL300,3.00,,
PL420,4.20,,
PL830,8.30,,
PL420_X15,6.30,PL420,1.5
PL420_X2,8.40,PL420,2
```

Rules: codes are uppercase `A-Z0-9_`, unique within a list, never reused; breakdown codes are prefixed with their variable (`HHH_SEX_F`); relative poverty lines are prefixed with their base (`PL420_X15`). `_T` and `_Z` are reserved. A code is never deleted; it gets `status=retired` and `replaced_by`. OCHA p-codes are the primary subnational code; a redrawn region gets a new code and its own `boundary_id`.

## 7. The store: family metadata

One YAML per indicator family in `03_store/catalog/series/`, with the qualifiers declared and the text templated, so a family with three poverty lines and two PPP bases is one file, not six.

`03_store/catalog/series/POV_HC.yaml`:

```yaml
idno: POV_HC
name: Poverty headcount rate at {POVLINE} ({PPP})
definition_short: Share of individuals living below {POVLINE} in {PPP} terms.
definition_long: >
  Share of individuals whose per-capita consumption, in {PPP} dollars,
  is below {POVLINE} per person per day, weighted by individual survey weights.
measurement_unit: Share of individuals (0-1)
unit_code: SHARE
level: ind                      # hh or ind; fixes the _Z rule for SEX and AGE
statistic: PROPORTION
universe: Individuals in ordinary households
methodology: >
  Numerator: individuals below the line. Denominator: all individuals.
  Weights: individual weights. Standard errors from the survey design (strata, PSU).
limitation: ADM1 estimates for small regions have wide confidence intervals.
qualifiers: [POVLINE, PPP]      # order fixes QUAL_1, QUAL_2
breakdowns: [HHH_SEX, HHH_AGE, QUINTILE, EMP_SECTOR]
max_cross: 2
themes: [POV]
keywords: [poverty rate, headcount, taux de pauvreté, extreme poverty]
related: [POV_NUM, POV_GAP]
display: {as: PERCENT, decimals: 1, higher_is: WORSE, valid_min: 0, valid_max: 1}
status: active                  # planned, active, retired
```

Which qualifier combinations exist is whatever rows the data holds, not a declared cross product (a 2017 PPP line never pairs with `PPP21`). The catalogue builder expands each family into one World Bank `timeseries` record per observed combination (idno `POV_HC_PL420_PPP21`, name "Poverty headcount rate at $4.20 a day (2021 PPP)") plus one family record whose `dimensions` list the qualifiers and breakdowns, and one `indicators_db` record for the whole store. It also writes a schema.org `Dataset` JSON-LD, a Frictionless `datapackage.json` for the data files, and a flat `series_overview.csv` for Excel users and for the Stata helper. All of this goes to a generated `build/` folder and is never edited.

`03_store/catalog/surveys.csv` holds only what the pipeline needs; everything else is in the Microdata Library record that the id resolves to:

```csv
survey_id,country,year,title
SEN_2021_EHCVM_v01_M,SEN,2021,Senegal - EHCVM 2021/22
GNB_2021_EHCVM_v01_M,GNB,2021,Guinea-Bissau - EHCVM 2021/22
```

A survey not yet in the Microdata Library uses the id its producer gave it (NSO or DDH), and `title` says where it is documented. Reprocessing a survey never changes its id.

## 8. Producers: harmonisation and indicators

**Harmonisation** (`01_harmonize/`) works per survey programme and wave: `ehcvm_2021.do` holds the code common to all WAEMU countries and `ehcvm_2021_SEN.do` the Senegal specifics (for example the recode of ANSD region codes to p-codes). It writes `hh.dta` and `ind.dta` into the versioned folder under `AFW360_MICRO`. The dictionary describes what those files contain:

- `variables.csv`: one row per harmonised variable (`name`, `level` hh or ind, `type`, `codelist`, `description`). Survey design variables have fixed names: `strata`, `psu`, `w_hh`, `w_ind`, so the helper always runs the same `svyset`. Breakdown variables already hold store codes (`hhh_sex` takes `HHH_SEX_F`/`HHH_SEX_M`).
- `breakdowns.csv`: one row per breakdown (`breakdown`, `name_en`, `level`, `variable`, `codes`, `source_note`).
- `qualifiers.csv`: one row per qualifier concept with the list it draws from.

Reusing the Global Monitoring Database or the official EHCVM welfare files was considered and set aside for now; whether AFW360 poverty rates must match PIP and GMD exactly is a question for the team.

**Indicators** (`02_indicators/`) are one do-file per family, calling a shared helper that only loops and computes:

```stata
* 02_indicators/POV_HC.do
use "$AFW360_MICRO/SEN_2021_EHCVM_v01_M/ind.dta", clear
foreach pl in PL300 PL420 PL830 {
    gen poor_`pl' = welfare_ppp21 / 365 < `=povline_value("`pl'")'
}
afw360_tabulate poor_*, series(POV_HC) stat(mean) qual(POVLINE PPP21) ///
    breakdowns(HHH_SEX HHH_AGE QUINTILE EMP_SECTOR)
```

`afw360_tabulate` runs `svyset psu [pw=w_ind], strata(strata)`, computes the statistic for the national total, each `URBANISATION`, each `REF_AREA`, each breakdown alone and each crossing up to `max_cross`, and returns a dataset with the keys, `OBS_VALUE`, `STD_ERR` and `N_OBS`. It stays small (under about 150 lines). Everything about the store format (`_T`/`_Z` filling, unit, survey id, release date, replacing existing rows, validation) happens once, in `afw360 ingest` in the tools repository, which is the same code that validates.

The within-household age Gini used as a worked example during the review needs its own computation (a per-household Gini then a weighted mean) and shows why `SEX` is a column of its own: the sex of the household head (`HHH_SEX_F`) splits households into groups and goes in a breakdown slot; the sex of the individuals counted (`SEX=F`) changes the population the statistic is computed on.

A recipe-driven engine, where the YAML carries the computation (`statistic`, `numerator`, `weight`) and a generic program computes every simple indicator with no per-family file, is recorded as future work for an R or Python implementation.

## 9. Workflows

Each fact has one home: code labels only in `codelists.csv`; what a harmonised variable means only in `variables.csv`; which variable a breakdown uses only in `breakdowns.csv`; what a family means only in its YAML. The validator checks that they agree.

**Add a code** (`docs/recipes/add-a-code.md`): decide the list; pick a code following the rules; add the row with `name_en`; if it is a breakdown category, register the variable in `breakdowns.csv` when new; run `afw360 validate`; open a pull request.

**Add a breakdown** (example: household has a member with a disability): add `HH_DISAB_Y` and `HH_DISAB_N` to `codelists.csv`; add the row `HH_DISAB` to `breakdowns.csv`; build `hh_disab` in `ehcvm_2021.do` and describe it in `variables.csv`; add `HH_DISAB` to the `breakdowns` list of the families it applies to; re-run those families. No indicator code changes.

**Add a qualifier value** (example: a new poverty line): add the row to `codelists.csv` and `povlines.csv`; re-run the families that use `POVLINE`. No YAML changes, because the family text is templated.

**Add an indicator**: classify the new concept with the table below; write the family YAML; write the do-file; run it and `afw360 ingest`; `afw360 validate`; one pull request with the YAML, the do-file and the rows.

| The new thing... | Example | Goes in |
|---|---|---|
| changes what is measured | poverty line, PPP base, COICOP group, acquisition mode | qualifier (`QUAL_*`), declared in the family YAML |
| splits households or people into groups | sex of head, quintile, enterprise sector, urbanisation | breakdown (`COMP_BREAKDOWN_*`), or the named column `URBANISATION` |
| changes which individuals are counted | female members only, adults only | `SEX`, `AGE` |
| is a place | country, ADM1 | `REF_AREA` |

Urbanisation is a breakdown; it has a named column only because SDMX and Data360 give it one.

**Add a survey**: add the row to `surveys.csv`; write or extend the harmonisation files for its programme and wave; run every family; ingest; validate; pull request.

## 10. Process: gates, provenance, releases, revisions

**Gate.** Any analyst opens a pull request to `afw360-data`. CI runs `afw360 validate`: columns, codes in the lists, slot order, values within the family's `valid_min`/`valid_max`, no duplicate keys, `STD_ERR`/`N_OBS` present for microdata rows, every `SERIES` has a YAML and every active YAML has rows, every `SERIES` in the data has a producer (`02_indicators/<FAMILY>.do` or an active line in `legacy_excel/mapping.csv`, never both for the same survey). One maintainer from the DIP/POV team reviews the meaning and merges. The do-file that produced the rows is part of the same pull request.

**Provenance.** No per-row producer column. At release, `03_store/MANIFEST.csv` records each data file with its sha256, the afw360-data commit, and the producer scripts that ran with their hashes. Per family and survey, the producer registries say whether rows are legacy or recomputed.

**Releases.** Date-based tags on afw360-data: `v2026.11.1` (year, month, sequence). A release is cut by the maintainer whenever something worth publishing is merged. The format (columns, YAML fields, code-list columns) has a separate integer version in `03_store/FORMAT.md` and in `datapackage.json`; a change to it comes with a migration note and a tools release that reads both. afw360-tools has its own semantic version and declares the format versions it reads. The release script (`afw360 release`) validates, tags, writes the manifest and the revisions log, and uploads the pin when a Connect key is configured.

**Revisions.** A changed value is replaced in place with a new `RELEASE` date; `03_store/REVISIONS.csv` is generated by diffing against the previous tag (`release, series, key, old_value, new_value, reason, pr`), with the reason taken from the pull request. Old releases remain available as tags. A provisional estimate carries `OBS_STATUS=P` until confirmed; a series break between rounds is `B`.

## 11. Legacy data: the Excel converter

The 5,271 Senegal and Guinea-Bissau observations enter the new store through a fresh converter, `02_indicators/legacy_excel/convert.py` (Python), with a `mapping.csv` (sheet, row label to `SERIES` and `QUAL_*`/`COMP_BREAKDOWN_*`; column header to `REF_AREA`/`URBANISATION`). The R code of `20-excel-sdmx-csv/` is not reused. Its rows have no `STD_ERR` or `N_OBS`.

The Excel workbooks stay byte-frozen on the `legacy` branch of `AFW360_Glance`; the converter reads them from `AFW360_LEGACY_XLSX`. A workbook correction is committed on that branch, never in afw360-data; the converter holds no value overrides.

The old SDMX CSVs (`30-sdmx/data/AFW360_HH_*_2021_SURVEY.csv`) are used once as a test oracle: after the converter runs, every value is compared and every difference explained. Then the SDMX repository is archived.

**Replacing legacy rows** happens per family and survey, in one pull request: the analyst writes `02_indicators/<FAMILY>.do`, runs it, marks the family's lines in `mapping.csv` as `retired` for that survey, and the pull request deletes the legacy rows and adds the new ones. The validator requires that the new rows cover at least the keys the legacy rows covered, or that the pull request explains the drop. The release diff logs every changed value. The validator keeps a standing warning listing families still legacy-only, so progress is visible.

## 12. Tools, API, dashboard, agent

- **Language**: Python throughout afw360-tools (`pandas`, `jsonschema`, `pydantic`, FastAPI, the official `mcp` SDK). R remains an option for dashboards. The contract (20 columns, YAML fields, World Bank JSON) is language-neutral.
- **Client interface**: `afw360_tools.client` exposes `search_series`, `get_series`, `get_observations`, `list_codes`, with two backends chosen by `AFW360_BACKEND=store|api`. The dashboard uses only this interface, so it works against the files or the API from day one; a test runs the same queries against both backends and checks identity. The four calls are also the four MCP tools later.
- **API**: `/api/v1`, OpenAPI at `/api/v1/openapi.yaml`, endpoints `GET /series?q=`, `GET /series/{idno}`, `GET /series/{idno}/data?REF_AREA=&URBANISATION=&...`; every response carries `SERIES`, `REF_AREA`, `UNIT_MEASURE`, `RELEASE`, `SOURCE_URL`, `license`, `citation`, `retrieved_at`. It is built in the same phase as the dashboard.
- **Dashboard**: rebuilt in Shiny for Python, the existing app's panels as the specification, deployed to the existing Connect content item; each panel shows source, release date and citation.
- **Agent**: last. MCP server over the client interface, read-only tools, a guidance resource, structured outputs, a French and English evaluation set of 30 to 50 questions written before the server.
- **Provisional layout** of afw360-tools (one package, apps as folders, `data/` synced copy, `vendor/` with the pinned World Bank schemas and the cookbook profile) is recorded but will be settled in its own session.

## 13. Deferred to dedicated sessions

1. **Row-level rules and converter details**, once provisional data exists from the Excel converter: the `_Z` rules for `SEX`/`AGE`, the `AGE` code list, dropped `O` rows, the national row, the withheld Guinea-Bissau cells, the exact shape of `breakdowns.csv`, the full YAML field list, `TIME_PERIOD` for pooled or panel surveys, the `status` values on codes and families.
2. **afw360-tools design**: package layout, API hosting on Connect, client contract, tests, deployment bundles.
3. **Content**, an important component covering more than the dashboard: key messages, About text, analysis figures (for example the fiscal-equity chart), the agent's guidance resource, tool descriptions, the evaluation question set, the AI-use policy and component register. Where it lives and who edits it is decided when the dashboard and agent phases start.
4. **Agent**: MCP tools, evaluation, governance.

## 14. Questions for the team

- Licence (CC BY 4.0 is a placeholder).
- Microdata Library idnos for the Senegal and Guinea-Bissau EHCVM 2021 datasets.
- French labels now or later.
- Whether AFW360 poverty rates must match PIP and GMD exactly.
- GitHub organisation and repository names; whether GitHub Actions is available for CI.

## 15. Milestones

1. **Freeze.** Merge `restructure/pipeline-20-30` into `master`, tag `legacy-final`, create `legacy`, point the README to the new repositories, stop FMR.
2. **Provisional store.** Create afw360-data: `FORMAT.md`, code lists and family YAMLs migrated from `CL_INDICATOR.csv`, `SERIES_PLAN.csv` and the other codelists, `surveys.csv`, the Excel converter, and in afw360-tools the validator and `build_catalog`. Acceptance: the store for Senegal and Guinea-Bissau matches the SDMX values cell by cell, `afw360 validate` passes, every generated JSON validates against the World Bank schemas and the cookbook profile.
3. **Row-level rules session** (deferred item 1) on the provisional data; recipes written.
4. **Tools, API and dashboard.** Client interface with both backends, API on Connect, dashboard rebuilt, sync and pins.
5. **Microdata path.** Harmonisation and helper, first families recomputed and legacy rows replaced.
6. **Content and agent.**
