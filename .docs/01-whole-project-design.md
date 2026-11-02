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
5. **Dashboard.** Shiny for Python on Posit Connect, reading the store through one client interface (the API becomes its second backend in step 6).
6. **Agent.** An MCP server over the same client interface, with a guidance resource and an evaluation set. Last.

Because there is no microdata yet, step 3 is built first and populated from the legacy Excel tables (step 2 in its legacy form). Step 5 follows; steps 4 and 6 come together, last, because nothing before the agent needs the API (decision of 2026-11-02).

## 4. Repositories

Two repositories replace `AFW360_Glance`.

**`afw360-data`** holds the producers and the master copy of the store:

```
afw360-data/
  00_config/          config_template.do (committed); config_local.do (gitignored)
  01_harmonize/       ehcvm_2021.do, ehcvm_2021_SEN.do, ehcvm_2021_GNB.do
                      dictionary/variables.csv, breakdowns.csv
  02_indicators/      run_all.do; POV_HC.do, AGR_CULTIVATES.do, ... (one per family)
                      _helpers/afw360_tabulate.ado
                      legacy_excel/convert.py, mapping.csv
                      out/<FAMILY>_<SURVEY_ID>.csv (gitignored; what the helper writes)
  03_store/           data/<survey_id>.csv
                      codelists.csv, geo.csv, povlines.csv
                      geo/<boundary_id>.gpkg
                      catalog/database.yaml, catalog/surveys.csv, catalog/series/<FAMILY>.yaml
                      build/ (gitignored; what afw360 build-catalog writes)
                      REVISIONS.csv, FORMAT.md
  docs/recipes/       setup.md, add-a-code.md, add-a-breakdown.md, add-a-qualifier.md,
                      add-an-indicator.md, add-a-survey.md
```

The folders are numbered in the order of work. `config_local.do` holds the machine-specific paths: `AFW360_RAW` (raw survey files), `AFW360_MICRO` (harmonised files on a shared World Bank drive, in a versioned folder such as `harmonized/2026.11`), `AFW360_LEGACY_XLSX` (the frozen Excel workbooks on the `legacy` branch of `AFW360_Glance`).

**`afw360-tools`** holds everything that reads the store: the validator, the ingest step, the catalogue builder, the release script, the API, the dashboard and later the agent, as one pip-installable Python package plus app folders. Its detailed design is settled in a separate session (see section 13). It carries a synced copy of the store in `data/` with a `data/VERSION` file naming the afw360-data release tag and commit (kept for now; how it is synced and checked is settled in the tools session, section 13). A `pins` board on Posit Connect is a second, interchangeable source of the same files, selected by `AFW360_SOURCE=local|pins`; a test opens both and checks they are identical.

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

Examples (values invented except the first two and the `POP_HH_SH` row):

```csv
SERIES,REF_AREA,TIME_PERIOD,SEX,AGE,URBANISATION,COMP_BREAKDOWN_1,COMP_BREAKDOWN_2,COMP_BREAKDOWN_3,QUAL_1,QUAL_2,QUAL_3,OBS_VALUE,UNIT_MEASURE,OBS_STATUS,STD_ERR,N_OBS,SURVEY_ID,RELEASE,OBS_COMMENT
AGR_CULTIVATES,SN01,2021,_Z,_Z,_T,_Z,_Z,_Z,_Z,_Z,_Z,0.01,SHARE,A,,,SEN_2021_EHCVM_v01_M,2026-11-15,
POV_HC,SN01,2021,_T,_T,_T,_Z,_Z,_Z,PL420,PPP21,_Z,0.03,SHARE,A,,,SEN_2021_EHCVM_v01_M,2026-11-15,
POV_HC,SEN,2021,_T,_T,R,HHH_SEX_F,_Z,_Z,PL420,PPP21,_Z,0.43,SHARE,A,0.012,905,SEN_2021_EHCVM_v01_M,2026-11-15,
CONS_SH,SN01,2021,_Z,_Z,_T,_Z,_Z,_Z,OWNPROD,CP01,_Z,0.00,SHARE,A,,,SEN_2021_EHCVM_v01_M,2026-11-15,
POP_HH_SH,SEN,2021,_Z,_Z,_T,QUINT_Q1,_Z,_Z,HE_COUNT_0,_Z,_Z,0.37,SHARE,A,,,SEN_2021_EHCVM_v01_M,2026-11-15,
DEM_AGE_GINI_HH,SEN,2021,F,_T,_T,HHH_SEX_F,_Z,_Z,_Z,_Z,_Z,0.33,INDEX,A,0.009,1650,SEN_2021_EHCVM_v01_M,2026-11-15,
```

Column meanings and rules:

- `SERIES` is the indicator family (`POV_HC`, `CONS_SH`), never a family-plus-qualifier id. The qualifiers that make a family into a specific series live in the `QUAL_*` columns.
- `REF_AREA` is the ISO 3166-1 alpha-3 country code for national rows (`SEN`) or the OCHA COD p-code for ADM1 rows (`SN01` Dakar, `GW01` Bafatá). The national total has `URBANISATION=_T`; `URBANISATION` splits may exist at both levels. There is no separate "country total" code.
- `TIME_PERIOD` is the survey's reference year from `surveys.csv`, even when fieldwork spans two calendar years.
- `SEX` and `AGE` describe the individuals counted. The family YAML lists the named columns it uses (`uses: [SEX, AGE]`); a column not listed is `_Z`, a listed one is `_T` for the total or a code for the split. A household statistic can still use `SEX` when its members are filtered by sex (`DEM_AGE_GINI_HH`). `AGE` codes follow SDMX (`Y_GE15`, `Y15T24`), as in Data360.
- `URBANISATION`: `CAP` (capital city), `OU` (other urban), `R` (rural), `_T`. `U` (urban, the parent of `CAP` and `OU`) is in the code list for an urban total; no row carries it today.
- `COMP_BREAKDOWN_1..3` hold household or group characteristics with self-describing codes (`HHH_SEX_F`, `QUINT_Q1`, `EMP_SECTOR_AGR`). Slots are filled from slot 1 with no gaps, in alphabetical order of the breakdown (the code's `parent`), never in a per-family order, so no edit to a YAML can invalidate old rows; unused slots are `_Z`. Crossings are limited by the family's `max_cross`.
- `QUAL_1..3` hold measurement parameters (`PL420`, `PPP21`, `CP01`, `OWNPROD`). Each qualifier list the family declares has a fixed slot, in alphabetical order of the list names (`POVLINE` then `PPP`; `ACQ` then `COICOP`); a row without that qualifier has `_Z` in its slot. A share-by-category family (`POP_SH`, `POP_HH_SH`, `POP_HE_SH`) declares `BREAKDOWN` as its qualifier: the category whose share is measured is `QUAL_1` (`HE_COUNT_0`, "share of households with no enterprise") and the subgroups are breakdown slots, so the catalogue gives each category its own record (`POP_HH_SH_HE_COUNT_0`), as it does for each poverty line.
- `OBS_VALUE` is numeric; rates are shares between 0 and 1.
- `UNIT_MEASURE` is a code (`SHARE`, `INDEX`, `HA`, `XOF`, `TLU`, `DAY`, `PERSON`); the label of `SHARE` is "Share (0–1)".
- `OBS_STATUS` uses the SDMX codes: `A` normal, `P` provisional, `B` break, `E` estimated, `C` confidential (value suppressed, kept so the user knows it exists). Rows with no value and no suppression reason are not stored; an absent key means "not available".
- `STD_ERR` and `N_OBS` are required for every row computed from microdata (design-based, from `svy:`); empty only for legacy rows.
- `SURVEY_ID` is the survey's own identifier, the Microdata Library idno. The file name equals it.
- `RELEASE` is the date the row's value was last published; it changes only when the value changes.
- `OBS_COMMENT` is free text; it is not used to carry provenance.

There is no `PRODUCER` column. Provenance is the release tag, the `mapping.csv` line for the family and survey (legacy or recomputed) and `STD_ERR` on the row (section 10).

Decision history: the breakdown and qualifier slots are 3 each, chosen on 2026-11-02 after Data360's `COMP_BREAKDOWN_1..3`; today's data uses at most 2 of each. Unused slots of both kinds are `_Z`, as in Data360 (checked on its API: `COMP_BREAKDOWN_1..3 = _Z`, `SEX`, `AGE`, `URBANISATION = _T`), decided 2026-11-02.

## 6. The store: code lists

Hand-maintained; a source of truth, never written by a script. One common file plus two side files for the lists that carry extra attributes.

`03_store/codelists.csv`:

```csv
codelist,code,name_en,name_fr,parent,order,status,replaced_by,notes
REF_AREA,SEN,Senegal,Sénégal,,1,active,,ISO 3166-1 alpha-3
REF_AREA,SN01,Dakar,Dakar,SEN,1,active,,
URBANISATION,CAP,Capital city,Capitale,U,1,active,,
URBANISATION,U,Urban,Urbain,,2,active,,
URBANISATION,OU,Other urban,Autre urbain,U,2,active,,
URBANISATION,R,Rural,Rural,,3,active,,
SEX,F,Female,Femme,,1,active,,sex of the individuals counted
BREAKDOWN,HHH_SEX,Sex of household head,Sexe du chef de ménage,,1,active,,the breakdown itself; its categories have it as parent
BREAKDOWN,HHH_SEX_F,Female household head,Chef de ménage femme,HHH_SEX,1,active,,
BREAKDOWN,EMP_SECTOR_AGR,Agriculture (ISIC A),Agriculture (CITI A),EMP_SECTOR,1,active,,
POVLINE,PL420,$4.20 a day,,,2,active,,
POVLINE,PL420_X15,1.5 times $4.20 a day,,,4,active,,a relative line is just another line
PPP,PPP21,2021 PPP,,,2,active,,
COICOP,CP01,Food and non-alcoholic beverages,Produits alimentaires et boissons non alcoolisées,,1,active,,
ACQ,OWNPROD,Own production,Autoproduction,,1,active,,
THEME,POV,Poverty,Pauvreté,,1,active,,labels for the YAML themes
UNIT_MEASURE,SHARE,Share (0-1),Proportion (0-1),,1,active,,0.38 means 38 percent
OBS_STATUS,A,Normal,Normal,,1,active,,SDMX
```

`03_store/geo.csv` (one row per `REF_AREA` code, the crosswalk and the geometry link; the boundaries themselves are committed as `03_store/geo/<boundary_id>.gpkg`, one layer `adm1` with a `code` column equal to `REF_AREA`, and the tools simplify them for the dashboard at build time):

```csv
code,level,country,nso_code,ocha_pcode,wb_gad_code,boundary_id
SEN,country,SEN,,,,
SN01,ADM1,SEN,01,SN01,SEN001,SEN_CODAB_v02
```

`03_store/povlines.csv` (values for the Stata helper; a relative line is just another line, with its own code and label):

```csv
code,value
PL300,3.00
PL420,4.20
PL830,8.30
PL420_X15,6.30
```

Rules: codes are uppercase `A-Z0-9_`, unique within a list, never reused. Breakdown codes are prefixed with their breakdown (`HHH_SEX_F`), whose own row (`HHH_SEX`) is their `parent`; qualifier codes are not prefixed (`PL420`, `CP01`, `OWNPROD`), the list is their context; a relative poverty line is named after its base (`PL420_X15`). Quintiles stay `QUINT_Q1` as in the legacy lists. `_T` and `_Z` are reserved. `name_fr` may be empty until the French labels are complete; the validator warns. A code is never deleted; it gets `status=retired` and `replaced_by`, which holds several codes, space-separated, when a region is split. A code is retired only when no survey can still produce it: a round stratified on the old regions keeps publishing the old code. OCHA p-codes are the subnational code while the boundary equals the COD-AB version named in `boundary_id`; when OCHA keeps a p-code for a redrawn region, the project adds a suffix (`ML05B`), keeps the p-code in `geo.csv` and gives the new shape its own `boundary_id`.

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
unit_code: SHARE                # the unit text of the record is this code's label
level: ind                      # hh or ind: picks the weight (w_hh or w_ind) and the unit of N_OBS
uses: [SEX, AGE]                # named columns this family fills; the others are _Z
statistic: PROPORTION
universe: Individuals in ordinary households
methodology: >
  Numerator: individuals below the line. Denominator: all individuals.
  Weights: individual weights. Standard errors from the survey design (strata, PSU).
limitation: ADM1 estimates for small regions have wide confidence intervals.
qualifiers: [POVLINE, PPP]      # the rule: rows carry exactly these lists (slots in alphabetical list order)
breakdowns: [HHH_SEX, HHH_AGE, QUINT, EMP_SECTOR]   # the rule; the do-file implements it
max_cross: 2
themes: [POV]
keywords: [poverty rate, headcount, taux de pauvreté, extreme poverty]
related: [POV_NUM, POV_GAP]
display: {as: PERCENT, decimals: 1, higher_is: WORSE, valid_min: 0, valid_max: 1}
status: active                  # planned, active, retired
```

The YAML is the rule and the do-file its implementation, which may be wrong: `afw360 validate` compares the rows of a family with its YAML and reports a declared qualifier list or breakdown with no rows, rows with an undeclared one, a named column filled against `uses`, or a `UNIT_MEASURE` other than `unit_code`, naming what the rows carry and what the YAML requires.

Which qualifier combinations exist is whatever rows the data holds, not a declared cross product (a 2017 PPP line never pairs with `PPP21`). The catalogue builder expands each family into one World Bank `timeseries` record per observed combination (idno `POV_HC_PL420_PPP21`, name "Poverty headcount rate at $4.20 a day (2021 PPP)"; a family without qualifiers is one record), with `dimensions` from the breakdowns observed, `themes` filling both `themes` and `topics` (labels from the `THEME` list), `keywords` filling both `keywords` and `aliases`, and one `indicators_db` record for the whole store. There is no separate family record. It also writes a Frictionless `datapackage.json` for the data files and a flat `series_overview.csv` for Excel users and for the Stata helper. All of this goes to `03_store/build/`, which is gitignored and rebuilt by `afw360 build-catalog` whenever it is needed (release, pin upload, a Stata run); nothing in it is edited or committed. The schema.org JSON-LD block waits for the agent milestone, when there is a page to carry it.

`03_store/catalog/database.yaml` holds the facts that belong to the whole database and that every generated record needs; it is edited rarely:

```yaml
idno: AFW360_HH
title: AFW 360 At A Glance, household survey indicators
abstract: Poverty and welfare indicators from household surveys in West and Central Africa.
authoring_entity: World Bank, AFW DIP/POV team
contact: <team address>
languages: [en]                 # fr is added when every active label has name_fr
periodicity: irregular          # survey rounds; a value of the cookbook profile's vocabulary
license: {name: CC BY 4.0, uri: https://creativecommons.org/licenses/by/4.0/}
citation: "World Bank, AFW DIP/POV team. {year}. {series_name} ({idno}), release {release}. {url}."
base_url: <Connect address>     # for SOURCE_URL and definition_references
```

`03_store/catalog/surveys.csv` holds only what the pipeline needs; everything else is in the Microdata Library record that the id resolves to:

```csv
survey_id,country,year,title,url
SEN_2021_EHCVM_v01_M,SEN,2021,Senegal - EHCVM 2021/22,
GNB_2021_EHCVM_v01_M,GNB,2021,Guinea-Bissau - EHCVM 2021/22,
```

`url` is where the survey is documented and fills the record's `sources[].uri`; it may be empty for a Microdata Library survey, where the builder derives it from the idno. A survey not yet in the Microdata Library uses the id its producer gave it (NSO or DDH) and must give a `url`. Reprocessing a survey never changes its id.

## 8. Producers: harmonisation and indicators

**Harmonisation** (`01_harmonize/`) works per survey programme and wave: `ehcvm_2021.do` holds the code common to all WAEMU countries and `ehcvm_2021_SEN.do` the Senegal specifics (for example the recode of ANSD region codes to p-codes). It writes `hh.dta` and `ind.dta` into the versioned folder under `AFW360_MICRO`. The dictionary describes what those files contain:

- `variables.csv`: one row per harmonised variable (`name`, `level` hh or ind, `type`, `codelist`, `description`). Survey design variables have fixed names: `strata`, `psu`, `w_hh`, `w_ind`, so the helper always runs the same `svyset`. Breakdown variables already hold store codes (`hhh_sex` takes `HHH_SEX_F`/`HHH_SEX_M`).
- `breakdowns.csv`: one row per breakdown (`breakdown`, `level`, `variable`, `source_note`): what `codelists.csv` cannot say, which harmonised variable carries the breakdown and at what level. Its label and its codes are the parent row and its children in `codelists.csv`. A legacy-only breakdown has an empty `variable` until it is harmonised.
- A qualifier is named by the code list it draws from (`POVLINE`, `PPP`, `COICOP`), so it needs no dictionary file.

Reusing the Global Monitoring Database or the official EHCVM welfare files was considered and set aside for now; whether AFW360 poverty rates must match PIP and GMD exactly is a question for the team.

**Indicators** (`02_indicators/`) are one do-file per family, calling a shared helper that only loops and computes:

```stata
* 02_indicators/POV_HC.do
args survey
use "$AFW360_MICRO/`survey'/ind.dta", clear
foreach pl in PL300 PL420 PL830 {
    gen poor_`pl' = welfare_ppp21 / 365 < `=povline_value("`pl'")'
}
afw360_tabulate poor_*, series(POV_HC) stat(mean) qual(POVLINE PPP21) ///
    breakdowns(HHH_SEX HHH_AGE QUINT EMP_SECTOR) survey(`survey')
```

Every family do-file takes the survey id as its argument; `02_indicators/run_all.do` loops over `surveys.csv` and runs each family for each survey, so adding a survey touches no family do-file. `afw360_tabulate` runs `svyset psu [pw=w_ind], strata(strata)` (`w_hh` for a family with `level: hh`), computes the statistic for the national total, each `URBANISATION`, each `REF_AREA`, each breakdown alone and each crossing up to `max_cross`, and writes `02_indicators/out/<FAMILY>_<SURVEY_ID>.csv` (gitignored) with the keys, `OBS_VALUE`, `STD_ERR` and `N_OBS` and nothing else. A member filter (`SEX`, `AGE`) is applied by the do-file, which tells the helper which code it applied (`sex(F)`). The helper stays small (under about 150 lines). Everything about the store format happens once, in `afw360 ingest <file>` in the tools repository, which is the same code that validates: it adds the `_Z` padding and the slot order, the unit from the YAML, the survey id, `RELEASE` (today) and `OBS_STATUS=A`, replaces the family's rows for that survey in `03_store/data/<survey_id>.csv`, and runs the validator.

The within-household age Gini used as a worked example during the review needs its own computation (a per-household Gini then a weighted mean) and shows why `SEX` is a column of its own: the sex of the household head (`HHH_SEX_F`) splits households into groups and goes in a breakdown slot; the sex of the individuals counted (`SEX=F`) changes the population the statistic is computed on.

A recipe-driven engine, where the YAML carries the computation (`statistic`, `numerator`, `weight`) and a generic program computes every simple indicator with no per-family file, is recorded as future work for an R or Python implementation.

## 9. Workflows

Each fact has one home: code labels only in `codelists.csv`; what a harmonised variable means only in `variables.csv`; which variable a breakdown uses only in `breakdowns.csv`; what a family means and computes only in its YAML, which is the rule the validator holds the rows to; the do-file is the implementation of that rule.

**Set up** (`docs/recipes/setup.md`): install Python 3.11 or later and `pip install afw360-tools`; copy `config_template.do` to `config_local.do` and fill the paths; edit the CSVs in a text editor or save them as "CSV UTF-8", because Excel's default save breaks accented labels. The validator runs on the analyst's machine and in CI where CI exists; releases run from the maintainer's machine, where the Connect key is.

**Add a code** (`docs/recipes/add-a-code.md`): decide the list; pick a code following the rules; add the row with `name_en`; if it is a breakdown category, register the variable in `breakdowns.csv` when new; run `afw360 validate`; open a pull request.

**Add a breakdown** (example: household has a member with a disability): add `HH_DISAB_Y` and `HH_DISAB_N` to `codelists.csv`; add the row `HH_DISAB` to `breakdowns.csv`; build `hh_disab` in `ehcvm_2021.do` and describe it in `variables.csv`; add `HH_DISAB` to the `breakdowns` list of the families it applies to, in their YAML and in the `breakdowns()` option of their do-files; re-run those families; `afw360 ingest`; `afw360 validate`; pull request.

**Add a qualifier value** (example: a new poverty line): add the row to `codelists.csv` and `povlines.csv`; add the code to the `foreach` list of each do-file that uses `POVLINE` (unless the loop reads `povlines.csv`, as `povline_value()` does); re-run those families; `afw360 ingest`; `afw360 validate`; pull request. No YAML changes, because the family text is templated.

**Add an indicator**: classify the new concept with the table below; write the family YAML; write the do-file; run it for each survey (`do POV_HC.do SEN_2021_EHCVM_v01_M`), which writes `02_indicators/out/POV_HC_SEN_2021_EHCVM_v01_M.csv`; `afw360 ingest` that file; `afw360 validate`; one pull request with the YAML, the do-file and the rows.

| The new thing... | Example | Goes in |
|---|---|---|
| changes what is measured | poverty line, PPP base, COICOP group, acquisition mode | qualifier (`QUAL_*`), declared in the family YAML |
| is the category whose share is measured | share of households with no enterprise, share of workers in agriculture | qualifier drawn from the `BREAKDOWN` list (`POP_HH_SH`, `POP_SH`) |
| splits households or people into groups | sex of head, quintile, enterprise sector, urbanisation | breakdown (`COMP_BREAKDOWN_*`), or the named column `URBANISATION` |
| changes which individuals are counted | female members only, adults only | `SEX`, `AGE` |
| is a place | country, ADM1 | `REF_AREA` |

Urbanisation is a breakdown; it has a named column only because SDMX and Data360 give it one.

**Add a survey**: add the row to `surveys.csv`; write or extend the harmonisation files for its programme and wave; run `02_indicators/run_all.do` for the new survey id; ingest the files it wrote; validate; pull request. No family do-file changes.

## 10. Process: gates, provenance, releases, revisions

**Gate.** Any analyst opens a pull request to `afw360-data`. `afw360 validate` runs on the analyst's machine and in CI where it exists; one maintainer from the DIP/POV team reviews the meaning and merges. The do-file that produced the rows is part of the same pull request. The checks, each an error naming the file, the row key and the rule:

| Check | Rule |
|---|---|
| Columns | The 20 columns of `FORMAT.md`, in order; UTF-8 without BOM; `OBS_VALUE` numeric, empty only with `OBS_STATUS=C`. |
| Codes | Every value of `REF_AREA`, `SEX`, `AGE`, `URBANISATION`, the six slots, `UNIT_MEASURE` and `OBS_STATUS` is `_T`, `_Z` or an active code of the right list; `SERIES` has a YAML; `SURVEY_ID` is in `surveys.csv` and equals the file name. |
| Named columns | `SEX` and `AGE` are `_Z` unless the YAML `uses` lists them, then `_T` or a code; `TIME_PERIOD` equals the survey's `year`. |
| Slots | Qualifier slots hold codes of the lists the YAML declares, each list in its alphabetical slot, `_Z` elsewhere; breakdown slots hold `BREAKDOWN` codes in alphabetical parent order with no gaps, `_Z` after the last, at most `max_cross` filled. |
| YAML versus rows | Every declared qualifier list and breakdown appears in some row of the family; no row carries an undeclared one; every active YAML has rows and every family with rows has an active YAML; `UNIT_MEASURE` equals `unit_code`. |
| Keys and values | No duplicate key over the 12 key columns; `OBS_VALUE` within `display.valid_min` and `valid_max`; `RELEASE` is a date. |
| Registry | A family and survey with an active `mapping.csv` line may have empty `STD_ERR`; without one, `STD_ERR` and `N_OBS` are required. |
| Code lists | Codes match `[A-Z0-9_]+`, unique within a list, never `_T` or `_Z`; `parent` and `replaced_by` resolve; `status` is `active` or `retired`; every `geo.csv` code is a `REF_AREA` code and every `boundary_id` has a file; empty `name_fr` is a warning. |
| Standing warning | Families still legacy-only for a survey, listed, not an error. |

The row-level rules of milestone 3 (the national row, the dropped `O` rows, the withheld Guinea-Bissau cells, pooled-survey `TIME_PERIOD`, the cover-or-explain comparison when a family is recomputed) are added as checks when decided.

**Provenance.** No per-row producer column and no manifest. Provenance is the release tag, which fixes every file hash; the `mapping.csv` line per family and survey, `active` for legacy rows and `retired` or absent for recomputed rows, which carry `STD_ERR` and `N_OBS`; and the do-file in the same commit as the rows it produced.

**Releases.** Date-based tags on afw360-data: `v2026.11.1` (year, month, sequence). A release is cut by the maintainer whenever something worth publishing is merged. The format (columns, YAML fields, code-list columns) has an integer version in `03_store/FORMAT.md`, copied into the generated `datapackage.json`; a change to it comes with a migration note and a tools release that reads both. afw360-tools has its own semantic version and declares the format versions it reads. The release script (`afw360 release`) validates, rebuilds `build/`, tags, writes the revisions log, and uploads the pin when a Connect key is configured; it runs from the maintainer's machine.

**Revisions.** A changed value is replaced in place with a new `RELEASE` date; `03_store/REVISIONS.csv` is generated by diffing against the previous tag (`release, series, key, old_value, new_value, reason, pr`), with the reason taken from the pull request. Old releases remain available as tags. A provisional estimate carries `OBS_STATUS=P` until confirmed; a series break between rounds is `B`.

## 11. Legacy data: the Excel converter

The 5,271 Senegal and Guinea-Bissau observations enter the new store through a fresh converter, `02_indicators/legacy_excel/convert.py` (Python), with a `mapping.csv` (one line per family and survey with a `status`; sheet, row label to `SERIES` and `QUAL_*`/`COMP_BREAKDOWN_*`, with the category of a share-by-category series going to `QUAL_1`; column header to `REF_AREA`/`URBANISATION`). `mapping.csv` is also the only registry of which rows are legacy (section 10). The converter stays in afw360-data as the producer of the legacy rows, and runs from the maintainer's machine. The R code of `20-excel-sdmx-csv/` is not reused. Its rows have no `STD_ERR` or `N_OBS`.

The Excel workbooks are frozen at `legacy-final`; the converter reads them from `AFW360_LEGACY_XLSX`, a checkout of the `legacy` branch of `AFW360_Glance`. A workbook correction is a commit on that branch, never in afw360-data; the converter holds no value overrides.

The old SDMX CSVs (`30-sdmx/data/AFW360_HH_*_2021_SURVEY.csv`) are used once as a test oracle: after the converter runs, every value is compared and every difference explained. Then the SDMX repository is archived.

**Replacing legacy rows** happens per family and survey, in one pull request: the analyst writes `02_indicators/<FAMILY>.do`, runs it, marks the family's lines in `mapping.csv` as `retired` for that survey, and the pull request deletes the legacy rows and adds the new ones. The validator requires that the new rows cover at least the keys the legacy rows covered, or that the pull request explains the drop. The release diff logs every changed value. The validator keeps a standing warning listing families still legacy-only, so progress is visible.

## 12. Tools, API, dashboard, agent

- **Language**: Python throughout afw360-tools (`pandas`, `jsonschema`, `pydantic`, FastAPI, the official `mcp` SDK). R remains an option for dashboards. The contract (20 columns, YAML fields, World Bank JSON) is language-neutral.
- **Client interface**: `afw360_tools.client` exposes `search_series`, `get_series`, `get_observations`, `list_codes`. The dashboard uses only this interface, over one backend, the store (the pin on Connect, a checkout elsewhere). The API backend, `AFW360_BACKEND=store|api`, and the test that both backends return the same thing arrive with the agent. The four calls are also the four MCP tools.
- **API**: `/api/v1`, OpenAPI at `/api/v1/openapi.yaml`, endpoints `GET /series?q=`, `GET /series/{idno}`, `GET /series/{idno}/data?REF_AREA=&URBANISATION=&...`; every response carries `SERIES`, `REF_AREA`, `UNIT_MEASURE`, `RELEASE`, `SOURCE_URL`, `license`, `citation`, `retrieved_at`. It is built in the agent milestone, the first thing that needs it (the cookbook's rule is that the MCP server must sit on an API, not the dashboard).
- **Dashboard**: rebuilt in Shiny for Python, the existing app's panels as the specification, deployed to the existing Connect content item; each panel shows source, release date and citation.
- **Agent**: last. MCP server over the client interface, read-only tools, a guidance resource, structured outputs, a French and English evaluation set of 30 to 50 questions written before the server.
- **Provisional layout** of afw360-tools (one package, apps as folders, `data/` synced copy, `vendor/` with the pinned World Bank schemas and the cookbook profile) is recorded but will be settled in its own session.

## 13. Deferred to dedicated sessions

1. **Row-level rules and converter details**, once provisional data exists from the Excel converter: the `AGE` code list, dropped `O` rows, the national row, the withheld Guinea-Bissau cells, the full YAML field list, `TIME_PERIOD` for pooled or panel surveys, the `status` values on codes and families.
2. **afw360-tools design**: package layout, API hosting on Connect, client contract, tests, deployment bundles, and how the synced copy of the store in `data/` is refreshed and checked.
3. **Content**, an important component covering more than the dashboard: key messages, About text, analysis figures (for example the fiscal-equity chart), the agent's guidance resource, tool descriptions, the evaluation question set, the AI-use policy and component register. Where it lives and who edits it is decided when the dashboard and agent phases start.
4. **Agent**: MCP tools, evaluation, governance.

## 14. Questions for the team

- Licence (CC BY 4.0 is a placeholder).
- Microdata Library idnos for the Senegal and Guinea-Bissau EHCVM 2021 datasets (the files are named after them; renaming later is a migration).
- Whether AFW360 poverty rates must match PIP and GMD exactly.
- GitHub organisation and repository names; whether GitHub Actions is available for CI.

## 15. Milestones

1. **Freeze.** Merge `restructure/pipeline-20-30` into `master`, tag `legacy-final`, create `legacy`, point the README to the new repositories, stop FMR.
2. **Provisional store.** Create afw360-data: `FORMAT.md`, code lists and family YAMLs migrated from `CL_INDICATOR.csv`, `SERIES_PLAN.csv` and the other codelists, `database.yaml`, `surveys.csv`, the two boundary GeoPackages, the Excel converter with `mapping.csv`, and in afw360-tools the validator and `build-catalog`. Acceptance: the store for Senegal and Guinea-Bissau is compared with the SDMX values cell by cell and every difference is explained (section 11), `afw360 validate` passes the checks of section 10, every generated JSON validates against the World Bank schemas and the cookbook profile at the AI-ready level.
3. **Row-level rules session** (deferred item 1) on the provisional data; recipes written.
4. **Tools and dashboard.** Client interface over the store, dashboard rebuilt on Connect reading the pin, release script and pins. No API.
5. **Microdata path.** Harmonisation and helper, `run_all.do`, first families recomputed and legacy rows replaced.
6. **Content, API and agent.** API with OpenAPI, the second client backend and its identity test, MCP server, guidance resource, evaluation set, JSON-LD on the series pages, switch-off test.

## 16. Review corrections (2026-11-02)

Design review before implementation (simplicity audit, consistency, hand maintainability, guideline alignment). Only unambiguous corrections were applied; everything else was returned to the data lead as findings and questions. Finding numbers refer to the review report.

| # | Section | What changed | Why | Resolves |
|---|---|---|---|---|
| C1 | 5, 6 | `URBANISATION` codes are `CAP`, `OU`, `R`, `_T`, with `U` as the parent of `CAP` and `OU`; an `OU` row added to the `codelists.csv` example. | Section 5 called `U` "other urban" while section 6 made `U` the parent of `CAP` ("Urban"). The legacy list and data (`CL_URBANISATION.csv`: `U`, `R`, `CAP`, `OU`; rows carry `CAP`, `OU`, `R`) use `OU`, and the converter must reproduce them. | F11 |
| C2 | 11 | "stay byte-frozen on the `legacy` branch" replaced by "frozen at `legacy-final`; a correction is a commit on the `legacy` branch". | A branch that receives corrections is not byte-frozen; section 4 already says the branch exists for corrections. | F14 |
| C3 | 7 | The `level` comment no longer says it "fixes the `_Z` rule for SEX and AGE"; it names the unit the statistic is computed over and points to section 13. | Section 13 defers the `_Z` rule, and the design's own example (`DEM_AGE_GINI_HH`: a household statistic with `SEX=F`) cannot follow a rule keyed on `level`. | F6 |
| C4 | 7 | Added: for a family without qualifiers the family record and the series record coincide (one record). | The text asked for one record per observed combination plus one family record, which for `AGR_CULTIVATES` gave two records with the same idno. | F26 |
| C5 | 4, 8 | `01_harmonize/dictionary/qualifiers.csv` removed from the layout and the dictionary; a qualifier is named by the code list it draws from. | The file held one fact (qualifier concept = code list) that the YAML `qualifiers:` list and the code-list names already carry. Dead weight. | Simplicity table, row `qualifiers.csv` |
| C6 | 9 | "Add a breakdown": the do-files' `breakdowns()` option is edited too; ingest, validate and pull request added; "No indicator code changes" removed. | Section 8's do-file example lists the breakdowns in the helper call, so the YAML edit alone does nothing; the workflow also stopped before the rows reached the store. | F2, F22 |
| C7 | 9 | "Add a qualifier value": the do-file `foreach` list is edited (unless the loop reads `povlines.csv`); ingest, validate and pull request added. | Section 8's do-file hardcodes `PL300 PL420 PL830`, so "re-run the families" alone does not compute a new line. | F2, F22 |
| C8 | 9 | "Add an indicator": the helper's result is saved as a CSV and that file is passed to `afw360 ingest`. | The helper "returns a dataset" in memory and ingest is a CLI command; the hand-off step was missing. The file's location is still a question (F10). | F10 |
| C9 | 10 | `MANIFEST.csv` no longer records "the afw360-data commit"; the release tag names the commit. | A file inside a commit cannot contain that commit's hash. | F12 |
| C10 | 15 | Milestone 2 acceptance: "compared with the SDMX values cell by cell and every difference is explained (section 11)" instead of "matches ... cell by cell". | Section 11 expects explained differences (the converter holds no overrides, and the SDMX files withheld Guinea-Bissau cells that the workbooks contain), so an exact match is impossible by design. | F13 |

### Decisions taken on 2026-11-02 after the review

The review's open findings were put to the data lead one by one, with examples, so that no decision is left for the milestones to take. Each decision is written into the section named.

| # | Decision | Written into |
|---|---|---|
| D1 | Share-by-category families (`POP_SH`, `POP_HH_SH`, `POP_HE_SH`, 928 legacy rows): the category whose share is measured is a qualifier, `QUAL_1` drawn from the `BREAKDOWN` list; one record per category. | 5, 9, 11 |
| D2 | The YAML is the rule and the do-file the implementation; the validator compares the rows with the YAML and names both sides. Slot positions follow alphabetical order, never the YAML's list order. | 5, 7, 9, 10 |
| D3 | Unused breakdown slots are `_Z`, as unused qualifier slots and as in Data360. | 5 |
| D4 | `03_store/catalog/database.yaml` holds the database-level facts (idno, title, licence, citation, contacts, languages, periodicity, base URL). | 4, 7 |
| D5 | afw360-tools keeps a committed copy of the store for now; how it is synced and checked is settled in the tools session. | 4, 13 |
| D6 | The YAML `uses:` list says which named columns a family fills (`_Z` otherwise); `level` only picks the weight. | 5, 7, 8 |
| D7 | Region splits: `replaced_by` may hold several codes; a project code equals the p-code only while the boundary matches the COD-AB version in `boundary_id`, otherwise a suffix; a code is retired only when no survey can still produce it. | 6 |
| D8 | Boundaries are committed as `03_store/geo/<boundary_id>.gpkg`. | 4, 6 |
| D9 | Family do-files take the survey id as an argument; `run_all.do` loops over `surveys.csv`. | 4, 8, 9 |
| D10 | `mapping.csv` is the only legacy registry; rows outside an active line must carry `STD_ERR` and `N_OBS`. The do-file-existence check is dropped. | 10, 11 |
| D11 | The helper writes `02_indicators/out/<FAMILY>_<SURVEY_ID>.csv` (gitignored); `afw360 ingest <file>` completes the rows, replaces the family's rows for that survey and validates. | 4, 8, 9 |
| D12 | The API, the second client backend and the backend identity test move to the agent milestone. | 3, 12, 15 |
| D13 | No `MANIFEST.csv`; provenance is the tag, the `mapping.csv` line, `STD_ERR` and the do-file in the commit. | 4, 5, 10 |
| D14 | PPP stays a second qualifier beside the poverty line. | 7 (unchanged) |
| D15 | The Excel converter stays in afw360-data. | 11 |
| D16 | A relative poverty line is just another line: `povlines.csv` is `code,value`; the label is typed like any other code. | 6 |
| D17 | The YAML keeps `unit_code` only; the record's unit text is the code's label. | 7 |
| D18 | `03_store/build/` is gitignored and rebuilt on demand. | 4, 7, 10 |
| D19 | Qualifier codes are unprefixed; breakdown codes keep their prefix; quintiles stay `QUINT_Q1`. | 5, 6, 7, 8 |
| D20 | `surveys.csv` gets `url`; a `THEME` list in `codelists.csv`; `themes` fills `topics` and `keywords` fills `aliases` in the builder. | 6, 7 |
| D21 | The milestone 2 validator checks are listed in section 10; the row-level rules of milestone 3 are added when decided. | 10, 15 |
| D22 | No separate family record; the JSON-LD block waits for the agent milestone. | 7, 15 |
| D23 | `name_fr` is optional until complete (a warning); `languages` says `en` until then. | 6, 7 |
| D24 | `breakdowns.csv` is `breakdown, level, variable, source_note`. | 8 |
| D25 | Minimal setup: the validator runs on the analyst's machine and in CI where it exists; releases run from the maintainer's machine. | 9, 10 |
