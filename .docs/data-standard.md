# AFW360 data standard and producer guidelines

Draft v0.1, 2026-09-19. Status: proposal, not yet applied to any file.

This document defines how indicator data for the AFW 360 dashboard are structured, coded and documented, and how producers (Stata developers) create data files and extend the codelists. It follows the SDMX information model and the World Bank Data360 layout (`REF_AREA`, `SEX`, `AGE`, `URBANISATION`, `COMP_BREAKDOWN_1…3`), stored as plain CSV files in git.

Background on the current inputs is in [input-tables-findings.md](input-tables-findings.md). Nothing here changes the current `INPUT Tables/` files. A Python converter will produce the new files from them, and the dashboard will switch to the new files later.

## 0. Decisions taken

| Decision | Choice |
|---|---|
| How breakdowns are represented | Named dimensions for geography, residence, and individual sex and age. Any other grouping goes into three generic slots, `COMP_BREAKDOWN_1…3` (Data360 style). |
| Poverty line and PPP round | Two separate dimensions, `POV_LINE` and `PPP` |
| Amount of metadata | As much as possible: full indicator dictionary, precision and sample size on every value, survey metadata, a production manifest per file |
| Who extends codelists | Stata developers, through pull requests reviewed by the data team |
| Tooling | Producers deliver CSV files. The converter, validator and dashboard loader are written in Python. |

Open decisions are listed in section 12.

## 1. The model in one page

- **One row is one number.** Each row of a data file holds one value and all the codes that say what the value is.
- **Dimensions identify the number:** country, sub-national area, year, indicator, poverty line, PPP round, sex, age, residence, and up to three extra breakdowns. Together they form the row's key, and no two rows share a key.
- **Attributes describe the number:** status, standard error, confidence interval, sample size, comment.
- **Codelists fix the vocabulary.** Every dimension value is a code from a codelist, and codes never change meaning.
- **Metadata files document everything else:** what each indicator measures, what each breakdown means, which survey the data come from, and which combinations are produced.

**Flexible dimensions.** Breakdown variables are not columns in the data file. They are *rows in a codelist*. To add "sector of employment", a producer registers the variable and its categories in two CSV files and then writes rows that use those codes in a `COMP_BREAKDOWN_n` column. The data file layout, the DSD, the loader and the dashboard do not change.

```
metadata/
  VERSION                      semantic version of the whole metadata package
  CHANGELOG.md
  structure/
    DSD_AFW360_HH.csv          column list of the data files (data team only)
  codelists/
    CL_AREA.csv                countries
    CL_GEO_LEVEL.csv           geographic levels (ADM1, ZAE, ...)
    CL_GEO.csv                 sub-national units
    CL_INDICATOR.csv           the indicator dictionary
    CL_POV_LINE.csv            poverty lines
    CL_PPP.csv                 PPP rounds
    CL_SEX.csv  CL_AGE.csv  CL_URBANISATION.csv
    CL_BRK_VAR.csv             registry of breakdown variables
    CL_COMP_BREAKDOWN.csv      categories of all breakdown variables
    CL_OBS_STATUS.csv
    CL_THEME.csv  CL_UNIT.csv  CL_STAT_UNIT.csv  CL_STATISTIC.csv  CL_WEIGHT.csv
  surveys/
    SURVEYS.csv                one row per country x survey round
  plans/
    TAB_PLAN.csv               which cuts are produced (the content constraint)
    LEGACY_LABELS.csv          old Excel labels -> new codes (used by the converter)
  registries/                  non-tabular assets (section 11)
    GEO_SOURCES.csv            boundary files and their vintages
    FIGURES.csv                images
    MESSAGES.csv               key messages
data/
  AFW360_HH_<ISO3>_<YEAR>.csv
  AFW360_HH_<ISO3>_<YEAR>_manifest.csv
geo/
  boundaries/<ISO3>_<SOURCE>_<VERSION>.gpkg
  derived/                     generated: dissolved zones, simplified display layers
assets/
  figures/<ISO3>/<figure_id>.<ext>
  text/<ISO3>/<id>.md          long-form text referenced from a registry
```

## 2. Data structure: dataflow `AFW360_HH`

`AFW360_HH` covers indicators estimated from household surveys. Other kinds of data, such as fiscal incidence or administrative data, will get their own dataflows that reuse the same codelists.

### 2.1 Columns

Data files have exactly these columns, in this order.

| # | Column | Role | Codelist / type | Code when not broken down | Code when not applicable |
|---|---|---|---|---|---|
| 1 | `DATAFLOW` | constant | `AFW360_HH` | | |
| 2 | `REF_AREA` | dimension | `CL_AREA` (ISO 3166-1 alpha-3) | | |
| 3 | `GEO` | dimension | `CL_GEO` | `_T` (whole country) | |
| 4 | `TIME_PERIOD` | dimension | 4-digit survey reference year | | |
| 5 | `INDICATOR` | dimension | `CL_INDICATOR` | | |
| 6 | `POV_LINE` | dimension | `CL_POV_LINE` | | `_Z` |
| 7 | `PPP` | dimension | `CL_PPP` | | `_Z` |
| 8 | `SEX` | dimension | `CL_SEX` | `_T` | |
| 9 | `AGE` | dimension | `CL_AGE` | `_T` | |
| 10 | `URBANISATION` | dimension | `CL_URBANISATION` | `_T` | |
| 11 | `COMP_BREAKDOWN_1` | dimension | `CL_COMP_BREAKDOWN` | `_T` | |
| 12 | `COMP_BREAKDOWN_2` | dimension | `CL_COMP_BREAKDOWN` | `_T` | |
| 13 | `COMP_BREAKDOWN_3` | dimension | `CL_COMP_BREAKDOWN` | `_T` | |
| 14 | `OBS_VALUE` | measure | number | | |
| 15 | `OBS_STATUS` | attribute | `CL_OBS_STATUS` | | |
| 16 | `STD_ERR` | attribute | number | | |
| 17 | `CI_LOWER` | attribute | number (95% CI) | | |
| 18 | `CI_UPPER` | attribute | number (95% CI) | | |
| 19 | `N_OBS` | attribute | integer | | |
| 20 | `N_POP` | attribute | number | | |
| 21 | `OBS_COMMENT` | attribute | free text, English | | |

### 2.2 Meaning of the dimensions

- **`_T` means total:** the value is not broken down on this dimension. A one-way breakdown by region has `GEO=SN03` and `_T` in every other breakdown column.
- **`_Z` means not applicable.** It is used only in `POV_LINE` and `PPP`, for indicators that involve no poverty line or PPP conversion.
- **`GEO`** is a sub-national unit of `REF_AREA`: an admin unit (identified by its P-code) or a zone. It holds one code, so regions and zones are never crossed with each other.
- **`TIME_PERIOD`** is the survey's reference year as recorded in `SURVEYS.csv`, for example `2021` for EHCVM 2021/22. Fieldwork dates are metadata, not part of the key.
- **`POV_LINE` and `PPP`:**
  - `POV_LINE` is not `_Z` when the indicator uses a poverty line (headcount, number poor, gap) or when a breakdown depends on one (poverty status, see 3.4).
  - `PPP` is the PPP round of a PPP-dollar line or value. It is `_Z` for national lines and for values in local currency.
  - The allowed `POV_LINE` × `PPP` pairs are listed in `CL_POV_LINE`.
- **`SEX` and `AGE`** describe **the individual being counted**. They are used only for indicators whose statistical unit is the individual (`stat_unit = IND`). The household head's sex and age are *not* `SEX` and `AGE`. They are breakdown variables (`HHH_SEX`, `HHH_AGE`) and go into the slots.
- **An age band that defines an indicator's universe is not a breakdown.** "Employed, 15–64" has universe "persons aged 15–64" in the dictionary and `AGE=_T`. `AGE` is used only to split a value into age groups.
- **`URBANISATION`** is the area of residence: `U` (urban), `R` (rural), and `CAP` (capital) and `OU` (other urban), which are children of `U`.
- **`COMP_BREAKDOWN_1…3`** hold any other breakdown. See section 3.

### 2.3 Rules for values and attributes

- **Store `OBS_VALUE` unrounded.** Use `.` as the decimal separator and no thousands separator or `%` sign. Rounding happens only in the display, using `decimals` from the dictionary.
- **Use base units.** Shares are 0–1 and never 0–100. Counts of people are in persons, not millions (6520000, not 6.52). Money is in whole currency units.
- **`OBS_STATUS` is always filled.**

  | Code | Meaning | `OBS_VALUE` |
  |---|---|---|
  | `A` | Normal value | filled |
  | `E` | Estimated or model-based (projection, nowcast, microsimulation) | filled |
  | `U` | Low reliability: 25 ≤ `N_OBS` < 50 (proposed) | filled, shown with a warning |
  | `Q` | Suppressed: `N_OBS` < 25 (proposed) | **empty**, and `STD_ERR` and CI empty too |
  | `O` | Missing: not computed, or no observations in the group | empty |

  The codes come from the SDMX cross-domain `CL_OBS_STATUS`. The proposed thresholds follow the DHS reporting convention and must be confirmed (section 12).
- **Every combination in the tabulation plan gets a row**, including missing ones, which carry status `Q` or `O`. Never leave a row out, never write 0 for a missing value, and never leave `OBS_STATUS` blank.
- **`N_OBS`** is the unweighted number of records used in the estimate: records with a non-missing indicator value that belong to both the group and the universe. It counts records of the file the estimate was computed from. For example, it counts households when a person-weighted poverty rate is computed on the household file with weight × household size.
- **`N_POP`** is the sum of weights of those same records: the estimated population, households or enterprises that the value refers to.
- **`STD_ERR`, `CI_LOWER` and `CI_UPPER`** must reflect the survey design (strata and PSUs, linearized). Leave them empty only when they cannot be estimated, and explain why in `OBS_COMMENT`.

### 2.4 Example rows

Values below are from the current SEN tables. `N_OBS`, `STD_ERR` and the CI columns are left empty because the current tables do not have them.

```csv
DATAFLOW,REF_AREA,GEO,TIME_PERIOD,INDICATOR,POV_LINE,PPP,SEX,AGE,URBANISATION,COMP_BREAKDOWN_1,COMP_BREAKDOWN_2,COMP_BREAKDOWN_3,OBS_VALUE,OBS_STATUS,STD_ERR,CI_LOWER,CI_UPPER,N_OBS,N_POP,OBS_COMMENT
AFW360_HH,SEN,_T,2021,POV_NUM,PL420,2021,_T,_T,_T,_T,_T,_T,6520000,A,,,,,,
AFW360_HH,SEN,_T,2021,POV_HC,PL420,2021,_T,_T,CAP,_T,_T,_T,0.03,A,,,,,,
AFW360_HH,SEN,SN01,2021,POV_HC,PL420,2021,_T,_T,_T,_T,_T,_T,0.03,A,,,,,,
AFW360_HH,SEN,_T,2021,CONS_SH_CP01,_Z,_Z,_T,_T,_T,QUINT_Q1,_T,_T,...,A,,,,,,
```

## 3. Flexible breakdowns: the `COMP_BREAKDOWN` slots

### 3.1 How it works

A **breakdown variable** is a classification of the population, such as sex of household head, consumption quintile or sector of employment. Each breakdown variable is one row in `CL_BRK_VAR`, and each of its categories is one row in `CL_COMP_BREAKDOWN`. A category code always starts with its variable code: `HHH_SEX_F` belongs to `HHH_SEX`.

A data row can use up to three breakdown variables at once, one per slot. It can also use `GEO`, `URBANISATION`, `SEX` and `AGE` at the same time. Examples:

| What the value is | `URBANISATION` | `COMP_BREAKDOWN_1` | `COMP_BREAKDOWN_2` |
|---|---|---|---|
| National total | `_T` | `_T` | `_T` |
| Female-headed households | `_T` | `HHH_SEX_F` | `_T` |
| Rural, female-headed households | `R` | `HHH_SEX_F` | `_T` |
| Poorest quintile, female-headed households | `_T` | `QUINT_Q1` | `HHH_SEX_F` |

### 3.2 Rules for filling the slots

1. **Fill from the left.** Use slot 1 first, then 2, then 3. Unused slots are `_T`, and there are no gaps: `_T` in slot 1 with a code in slot 2 is invalid.
2. **Canonical order.** When several breakdown variables are used, put them in ascending order of `slot_order` from `CL_BRK_VAR`. Each combination then has exactly one spelling: "Q1 × female head" is always `QUINT_Q1, HHH_SEX_F`, never the reverse.
3. **At most one category per variable in a row.**
4. **Units must match.** A breakdown variable may be used only with indicators whose `stat_unit` is listed in the variable's `applies_to_units`. `EMP_SECTOR`, the sector of an individual's job, cannot break down a household poverty rate.
5. **Never duplicate a named dimension.** Residence, individual sex, individual age and geography always go in their named columns, never in a slot.
6. **Declare every cut.** Every combination that is produced must be listed in `TAB_PLAN.csv` (section 5.10).

Needing a fourth simultaneous breakdown would mean adding `COMP_BREAKDOWN_4`. That is a structural change the data team makes, not a producer (section 9). With the four named dimensions already available, three slots should be enough for any sample size these surveys support.

### 3.3 Initial breakdown variables (from the current tables)

| `var_code` | Describes | Categories | `slot_order` |
|---|---|---|---|
| `QUINT` | Household | `QUINT_Q1` … `QUINT_Q5` | 10 |
| `HHH_SEX` | Household head | `HHH_SEX_F`, `HHH_SEX_M` | 20 |
| `HHH_AGE` | Household head | `HHH_AGE_LT35`, `HHH_AGE_GE35` (cutoff to be confirmed before release) | 30 |

### 3.4 Worked example: adding sector of employment

1. Decide whose characteristic it is. "Sector of the individual's main job" (`EMP_SECTOR`, describes `IND`) and "sector of the household head's main job" (`HHH_SECTOR`, describes `HHH`) are two different variables. The first can break down only individual-level indicators, such as the share in wage employment. The second can break down household and individual indicators, such as the poverty rate.
2. Register the variable in `CL_BRK_VAR`: `EMP_SECTOR`, describes `IND`, applies_to_units `IND`, classification `ISIC Rev.4`, partition `Y`, slot_order `60`.
3. Register its categories in `CL_COMP_BREAKDOWN`:
   - `EMP_SECTOR_AGR` (ISIC A)
   - `EMP_SECTOR_IND` (ISIC B–F)
   - `EMP_SECTOR_SER` (ISIC G–U)
4. Add the cut to `TAB_PLAN.csv`, for example `EMP_SECTOR` for theme `JOB`, all countries.
5. Produce the rows, for example `INDICATOR=JOB_WAGE_SH, COMP_BREAKDOWN_1=EMP_SECTOR_AGR`.
   - Crossed with individual sex: add `SEX=F`.
   - Crossed with quintile: `COMP_BREAKDOWN_1=QUINT_Q1, COMP_BREAKDOWN_2=EMP_SECTOR_AGR`, because `QUINT` has the lower `slot_order`.

No file layout, loader or dashboard change is needed.

### 3.5 Breakdowns that depend on a poverty line

"Poor / non-poor" depends on which line is used. Register it as `POOR` with categories `POOR_Y` and `POOR_N`, and set `needs_pov_line = Y`. Rows that use it must carry the line in the dimensions. Example: the food budget share among people who are poor at $3.00 (2021 PPP) is `INDICATOR=CONS_SH_CP01, POV_LINE=PL300, PPP=2021, COMP_BREAKDOWN_1=POOR_Y`.

## 4. Poverty lines and PPP rounds

`CL_POV_LINE` (initial content):

| `code` | Value | Basis | `ppp_allowed` | Type |
|---|---|---|---|---|
| `PL215` | 2.15 | PPP$ per person per day | `2017` | International poverty line (2017 PPP) |
| `PL365` | 3.65 | PPP$ per person per day | `2017` | Lower-middle-income line (2017 PPP) |
| `PL685` | 6.85 | PPP$ per person per day | `2017` | Upper-middle-income line (2017 PPP) |
| `PL300` | 3.00 | PPP$ per person per day | `2021` | International poverty line (2021 PPP) |
| `PL420` | 4.20 | PPP$ per person per day | `2021` | Lower-middle-income line (2021 PPP) |
| `PL830` | 8.30 | PPP$ per person per day | `2021` | Upper-middle-income line (2021 PPP) |
| `NPL` | per survey | Local currency, per `SURVEYS.csv` | `_Z` | National poverty line |
| `NPL_FOOD` | per survey | Local currency, per `SURVEYS.csv` | `_Z` | National food (extreme) poverty line |
| `_Z` | | | `_Z` | Not applicable |

`CL_PPP`: `2011`, `2017`, `2021`, `_Z`.

Rules:
- Only the pairs listed in `ppp_allowed` are valid. The SEN `Departement` sheet contains "$3.00/day (2017 PPP)", which is not a standard World Bank pair. It would need a deliberate new entry, and it probably needs checking first.
- The value of a national line lives in `SURVEYS.csv` because it differs by country and round. The code `NPL` means "the national line of this survey".
- `PPP` is also used for non-poverty values expressed in PPP dollars, for example mean consumption per capita in 2021 PPP$. In that case `POV_LINE=_Z` and `PPP=2021`.

## 5. Metadata files

General rules for every CSV in `metadata/`:
- UTF-8 (Excel's "CSV UTF-8" format is fine), comma-separated, one header row, one row per code.
- Fields with several values are space-separated.
- Column status: **R** required, **C** required when relevant, **O** optional.

### 5.1 Code rules (all codelists)

- Codes are uppercase ASCII letters, digits and `_`, start with a letter, and are at most **32 characters**, the Stata variable-name limit. The exceptions are `_T`, `_Z`, the 4-digit years in `PPP` and `TIME_PERIOD`, and P-codes, which are used as issued.
- **A code never changes meaning and is never reused or deleted.** If a definition changes, create a new code and mark the old one `DEPRECATED` with `replaced_by`.
- Labels and definitions can be reworded freely, as long as the meaning stays the same.
- Indicator codes follow `<THEME>_<SUBJECT>[_<QUALIFIER>]`. They contain no poverty line, PPP round, unit, universe or breakdown, because those have their own dimensions and fields. Use `POV_HC`, not `POV_HC_PL420`.
- Breakdown category codes are `<var_code>_<category>`, so `var_code` is at most 20 characters.
- In Stata, name the variable that holds an indicator after its code, in lower case (`pov_hc`, `cons_sh_cp01`). The mapping then needs no lookup table.

### 5.2 `CL_INDICATOR.csv`: the indicator dictionary

| Column | | Content | Example (`EN_PREPAID`) |
|---|---|---|---|
| `code` | R | Indicator code | `EN_PREPAID` |
| `name_en` | R | Full name, without line, PPP or unit | Prepaid electricity meter |
| `short_name_en` | R | At most 40 characters, for chart labels | Prepaid meter |
| `name_fr`, `name_pt` | O | Translations | Compteur prépayé |
| `theme` | R | `CL_THEME` | `EN` |
| `definition_en` | R | Precise one- or two-sentence definition | Share of grid-connected households whose main meter is prepaid. |
| `stat_unit` | R | `CL_STAT_UNIT`: what is counted | `HH` |
| `universe` | R | Which units form the denominator | Households connected to the grid |
| `numerator` | C | For shares and ratios | Households with a prepaid meter |
| `statistic` | R | `CL_STATISTIC` | `PROPORTION` |
| `weight` | R | `CL_WEIGHT` | `HH` |
| `ref_period` | R | ISO 8601 duration of the recall period (`P7D`, `P12M`, `P3Y`) or `INTERVIEW` | `INTERVIEW` |
| `unit_measure` | R | `CL_UNIT` | `SHARE` |
| `unit_denom` | C | What the value is per (`PERSON`, `HH`, `HE`, `WORKER`), for levels | |
| `unit_time` | C | `DAY`, `MONTH` or `YEAR`, for flows | |
| `price_basis` | C | `NOMINAL` or `DEFLATED`, for money | |
| `decimals` | R | Decimals to display | `2` |
| `display_mult` | O | Display scale: 0, 3 or 6 (for example, millions) | |
| `valid_min`, `valid_max` | R | Plausible range. Leave empty if unbounded. | `0`, `1` |
| `higher_is` | R | `BETTER`, `WORSE` or `NEUTRAL`: sets the colour direction on maps | `NEUTRAL` |
| `additive` | R | `Y` if values sum across a partition (totals, counts) | `N` |
| `uses_pov_line` | R | `Y` if `POV_LINE` must not be `_Z` | `N` |
| `uses_ppp` | R | `Y` if the value is in PPP$ | `N` |
| `sdg_indicator` | O | For example `7.1.1` | |
| `classification` | O | External class, for example `COICOP2018:04` or `ISIC4:A` | |
| `related` | O | Codes of close indicators and how this one differs | `EN_GRID_CONN`: connection only |
| `source_questionnaire` | R | Survey module or section | EHCVM section 11 |
| `source_vars` | R | Harmonized microdata variables used | |
| `program` | R | Do-file (or other program) that computes it | |
| `owner` | R | Team or person responsible | |
| `status` | R | `DRAFT`, `ACTIVE` or `DEPRECATED` | `ACTIVE` |
| `version_added` | R | Metadata version | `1.0.0` |
| `replaced_by` | C | For deprecated codes | |
| `notes` | O | | |

Why the population fields matter: `HHH_SEX_F` means "people living in female-headed households" for a person-level poverty rate, and "enterprises in female-headed households" for an enterprise indicator. Without `stat_unit`, `universe` and `weight`, person-weighted and household-weighted numbers end up in the same chart. `statistic` matters too. A COICOP budget share can be the mean of household shares (`MEAN`) or the share of aggregate spending (`RATIO_TOTALS`), and the two give different numbers.

### 5.3 `CL_BRK_VAR.csv`: registry of breakdown variables

| Column | | Content |
|---|---|---|
| `var_code` | R | At most 20 characters, for example `HHH_SEX` |
| `name_en` | R | Sex of household head |
| `name_fr`, `name_pt` | O | |
| `definition_en` | R | How the variable is defined, including cutoffs and the ranking basis for quantiles |
| `describes` | R | Whose characteristic it is: `IND` (the individual), `HHH` (household head), `HH` (household), `HE` (enterprise) |
| `applies_to_units` | R | `stat_unit` values it may break down, for example `HH IND HE` |
| `classification` | O | ISIC Rev.4, ISCED 2011, ISCO-08, ... |
| `partition` | R | `Y` if categories are mutually exclusive and cover every unit with a non-missing value |
| `needs_pov_line` | R | `Y` if categories depend on a poverty line |
| `slot_order` | R | Integer that fixes the canonical order in the slots. Leave gaps (10, 20, …). |
| `status`, `version_added`, `owner`, `notes` | R/R/R/O | |

### 5.4 `CL_COMP_BREAKDOWN.csv`: categories

| Column | | Content |
|---|---|---|
| `code` | R | `<var_code>_<category>`, for example `HHH_SEX_F`. Also contains the single row `_T`. |
| `var_code` | R | Parent variable in `CL_BRK_VAR` |
| `name_en` | R | Female head |
| `name_fr`, `name_pt` | O | |
| `definition_en` | C | Required when the boundary is not obvious (age cutoffs, ISIC sections) |
| `parent` | O | Parent category in the same variable, for nested classifications |
| `order` | R | Display order |
| `status`, `version_added` | R | |

### 5.5 `CL_GEO_LEVEL.csv` and `CL_GEO.csv`: geography

`CL_GEO_LEVEL` has columns `code`, `name_en` and `description`, with initial codes `ADM1`, `ADM2`, `ADM3` and `ZAE`. A new zoning gets a new level code.

`CL_GEO`:

| Column | | Content | Example |
|---|---|---|---|
| `code` | R | P-code for admin units, `<ISO2>_<LEVEL><nn>` for zones | `SN01`, `GW08`, `SN_ZAE01` |
| `ref_area` | R | Country | `SEN` |
| `level` | R | `CL_GEO_LEVEL` | `ADM1` |
| `name` | R | Display name with accents | Dakar, Bafatá |
| `name_ascii` | O | | Bafata |
| `parent` | C | Containing unit (ADM2 and below) | `SN01` |
| `members` | C | For zones built from admin units: their codes | `SN03 SN06 SN08` |
| `source_id` | R | Boundary source in `GEO_SOURCES.csv` (section 11.1) | `SEN_CODAB_v02` |
| `geom_layer` | C | Layer of that file holding the polygon | `adm1` |
| `valid_from`, `valid_to` | R/C | Dates the unit is valid. `valid_to` is empty while current. | `2024-05-20` |
| `status`, `version_added` | R | | |

The shapefiles in `INPUT shp/` already carry these P-codes: `SN01` is Dakar and `GW08` is Bissau (listed as `SAB` in the current tables). Maps join on codes, never on names. SEN zones are unions of regions, so `members` lets the map dissolve region polygons into zones instead of storing a second set of polygons.

### 5.6 `CL_AREA.csv`

Columns: `code` (ISO3), `iso2` (the P-code prefix), `name_en`, `name_fr`, `currency` (ISO 4217), `status`. The currency is resolved per country because "FCFA" is ambiguous within AFW: `XOF` (WAEMU, including SEN and GNB) vs `XAF` (CEMAC).

### 5.7 Small codelists

| Codelist | Codes |
|---|---|
| `CL_SEX` | `_T`, `F`, `M` |
| `CL_AGE` | `_T`, and SDMX-style bands as needed: `Y_LT15`, `Y15T24`, `Y25T64`, `Y_GE65`, … |
| `CL_URBANISATION` | `_T`, `U`, `R`, `CAP` (parent `U`), `OU` (parent `U`) |
| `CL_OBS_STATUS` | `A`, `E`, `U`, `Q`, `O` (see 2.3) |
| `CL_THEME` | `POV`, `CONS`, `JOB`, `HE`, `AGR`, `EN`, `HOUS`, `SHK`, `SP` (add as needed) |
| `CL_STAT_UNIT` | `IND` individual, `HH` household, `HE` household enterprise, `PLOT` agricultural plot |
| `CL_STATISTIC` | `PROPORTION`, `MEAN`, `MEDIAN`, `TOTAL`, `RATIO_TOTALS` (ratio of population totals) |
| `CL_WEIGHT` | `POP` (household weight × household size), `HH`, `IND`, `HE` |
| `CL_UNIT` | `SHARE` (0–1), `PERSON`, `HH`, `LCU` (local currency; ISO code from `CL_AREA`), `PPP_USD`, `HA`, `TLU`, `DAY`, `YEAR`, `COUNT`, `CODE` (mean of an ordinal code; avoid for new indicators) |

### 5.8 `SURVEYS.csv`: one row per country × survey round

| Column | | Example (SEN, from `About_SEN.txt`) |
|---|---|---|
| `survey_id` | R | `SEN_EHCVM_2021` |
| `ref_area`, `time_period` | R | `SEN`, `2021` |
| `survey_name`, `survey_acronym` | R | Enquête Harmonisée sur les Conditions de Vie des Ménages, EHCVM |
| `producer_agency` | R | ANSD |
| `fieldwork_start`, `fieldwork_end` | R | `2021-11`, `2022-09` |
| `sample_hh`, `sample_ind` | R/O | 7100 |
| `design` | R | Stratification, stages, PSU |
| `representative_levels` | R | Levels the design supports, for example `ADM1 URBANISATION`. Cuts below these levels are flagged or suppressed. |
| `welfare_aggregate` | R | Consumption per capita |
| `welfare_adjustments` | R | Spatial and temporal deflation |
| `npl_value`, `npl_currency`, `npl_unit`, `npl_ref_year` | C | 519.8, XOF, per capita per day, 2018 |
| `ppp_rounds` | R | `2017 2021` |
| `microdata_ref` | O | World Bank Microdata Library ID or URL |
| `comparable_with` | O | `SEN_EHCVM_2018` |
| `methodology_en` | O | Free text (replaces `About_<ISO3>.txt`) |
| `contact`, `notes` | O | |

### 5.9 Manifest: one per data file

`AFW360_HH_<ISO3>_<YEAR>_manifest.csv` has two columns, `key` and `value`. It holds the dataset-level attributes:

`dataflow`, `dsd_version`, `metadata_version`, `ref_area`, `time_period`, `survey_id`, `file_name`, `n_rows`, `producer`, `program`, `software` (for example Stata 18.0), `run_timestamp` (ISO 8601), `status` (`DRAFT`, `SUBMITTED`, `VALIDATED` or `PUBLISHED`), `notes`.

### 5.10 `TAB_PLAN.csv`: which cuts are produced

This file is the content constraint. Each row is one cut, meaning one combination of breakdowns.

| Column | Content |
|---|---|
| `cut_id` | For example `ADM1_URB` |
| `ref_area` | ISO3, or `ALL` |
| `geo_level` | `_T` or a `CL_GEO_LEVEL` code |
| `urbanisation` | `_T`, `CAP OU R` or `U R` |
| `sex`, `age` | `Y` or `N` (`age` also names the band set to use) |
| `comp_breakdowns` | `var_code`s in slot order, for example `QUINT HHH_SEX` |
| `themes` | `ALL` or a list of `CL_THEME` codes |
| `status` | `ACTIVE` or `DRAFT` |

This initial plan reproduces the current Excel tables:

| `cut_id` | `geo_level` | `urbanisation` | `comp_breakdowns` | Current source |
|---|---|---|---|---|
| `TOTAL` | `_T` | `_T` | | `National` / `estimateTotal` |
| `URB` | `_T` | `CAP OU R` | | `estimateCapital`, `…Other_Urban`, `…Rural` |
| `HHH_SEX` | `_T` | `_T` | `HHH_SEX` | `estimateFemale_HH`, `…Male_HH` |
| `HHH_AGE` | `_T` | `_T` | `HHH_AGE` | `estimateYouth_HH`, `…Older_HH` |
| `QUINT` | `_T` | `_T` | `QUINT` | `estimateQ1` … `Q5` |
| `ADM1` | `ADM1` | `_T` | | `ADM 1` sheet |
| `ZAE` | `ZAE` | `_T` | | `ZAE` sheet |

## 6. What a producer delivers

For each country and survey round:

1. **`AFW360_HH_<ISO3>_<YEAR>.csv`**, UTF-8, with the columns of 2.1 in that order.
2. **One row for every combination** of indicator × cut in `TAB_PLAN.csv` × category of that cut. The only exceptions are indicators the unit rules exclude (3.2, rule 4).
3. **The manifest** (5.9).
4. **Any metadata changes** the data need (new indicators, breakdowns, codes), in the same pull request (section 8).

Before delivery, check each estimate against these rules:
- Code the indicator variable as missing for units outside its universe, so they are excluded from both the numerator and the denominator.
- Estimate with the survey design declared (weights, strata, PSUs), using subpopulation estimation for groups, not by dropping observations. This keeps standard errors correct.
- Use the weight named in the dictionary (`POP` = household weight × household size for person-level statistics on household data).
- Apply the `OBS_STATUS` thresholds of 2.3 using `N_OBS`.
- Write values unrounded and in base units.

## 7. How to extend the dataset

| I want to… | Files to edit | Structural change? | Version bump |
|---|---|---|---|
| Add an indicator | `CL_INDICATOR` (and `CL_THEME` if the theme is new) | No | minor |
| Add a category to an existing breakdown | `CL_COMP_BREAKDOWN` | No | minor |
| Add a breakdown variable, such as sector of employment | `CL_BRK_VAR`, `CL_COMP_BREAKDOWN`, `TAB_PLAN` | No | minor |
| Cross existing breakdowns | `TAB_PLAN` | No | minor |
| Add a poverty line or PPP round | `CL_POV_LINE`, `CL_PPP` | No | minor |
| Add a geographic level or units | `CL_GEO_LEVEL`, `CL_GEO`, `TAB_PLAN` | No | minor |
| Add a country | `CL_AREA`, `CL_GEO`, `SURVEYS`, `TAB_PLAN` | No | minor |
| Add a survey round | `SURVEYS` | No | minor |
| Reword a label or definition (same meaning) | The codelist concerned | No | patch |
| Change what an indicator measures | New code in `CL_INDICATOR`; old one `DEPRECATED` + `replaced_by` | No | minor |
| A 4th simultaneous breakdown, or a new named dimension | `DSD_AFW360_HH` (data team only) | **Yes** | major |
| Add boundaries, a figure or a key message | See section 11.5 | No | minor |

### 7.1 Add an indicator

1. Search `CL_INDICATOR` for the same or a similar concept.
   - If the concept already exists, reuse its code. "Food consumption share" and "COICOP 1" are the same indicator.
   - If it is close but different, create the new code and explain the difference in `related` on both rows. The three grid-electricity indicators are an example.
2. Choose a code (5.1) and fill every **R** column, plus the **C** columns that apply.
3. Say whether it uses a poverty line (`uses_pov_line`) and whether the values are in PPP$ (`uses_ppp`).
4. Produce it for every cut in `TAB_PLAN` that covers its theme.
5. Open a pull request (section 8).

### 7.2 Add a breakdown variable

Follow the worked example in 3.4:
1. Decide whose characteristic it is (`describes`) and which indicators it can break down (`applies_to_units`).
2. Reuse an international classification where one exists (ISIC, ISCO, ISCED).
3. Give it a `slot_order`, register its categories, and add the cuts to `TAB_PLAN`.
4. Check that the survey's sample supports the new groups. Expect many `U` and `Q` statuses in small groups.

### 7.3 Add a country

1. Add the country to `CL_AREA`, with its currency.
2. Load its ADM1 units (and any zones) into `CL_GEO`, using the P-codes of the boundary file you will map with, and record that file's version in `source`.
3. Add its survey rounds to `SURVEYS`.
4. Add `TAB_PLAN` rows if its cuts differ from `ALL`.

Every other code must come from the shared codelists. A country-specific category, such as a secondary-city stratum, becomes a child of a shared code (`parent = U`) and never an unrelated new code. The mapping from the survey's own variable values to shared codes lives in the producer's program.

## 8. Change control

- `metadata/` lives in git. Producers extend codelists on a branch and open a pull request, and the data team reviews it.
- Rows are **append-only**: no deletions, and no changing an existing code or its meaning (5.1).
- Every merged change bumps `metadata/VERSION` (`MAJOR.MINOR.PATCH`, per the table in section 7) and adds a line to `metadata/CHANGELOG.md`.
- Every data file's manifest records the `metadata_version` it was produced against.
- The validator (section 10) must pass before a pull request is merged or a data file is published.
- When editing a CSV in Excel, save as "CSV UTF-8". Plain "CSV" loses accented characters (`Bafatá`). Check that Excel has not converted codes into numbers or dates.

## 9. Structural changes (data team only)

Adding, removing or reordering a column of the data file is a **major** version change. It needs a new `DSD_AFW360_HH.csv`, and the converter must fill the new column with `_T` in existing files. The generic slots exist so that this should rarely be needed.

## 10. Validation checks (to be implemented in Python)

**Structure**
- The header matches the DSD exactly: same names, same order.
- No dimension cell is empty.
- The key (all dimension columns) is unique.

**Codes**
- Every code exists in its codelist with status `ACTIVE`.
- `GEO` belongs to `REF_AREA`.
- `COMP_BREAKDOWN` slots are filled from the left, in canonical order, with no variable used twice.
- `SEX`, `AGE` and breakdown variables are compatible with the indicator's `stat_unit`.
- `POV_LINE` is not `_Z` exactly when the indicator has `uses_pov_line = Y` or a breakdown has `needs_pov_line = Y`.
- The `POV_LINE` × `PPP` pair is allowed.

**Coverage**
- The rows equal `TAB_PLAN` × applicable indicators × categories: nothing missing, nothing extra.
- A `SURVEYS` row and a manifest exist, and the manifest matches the file.

**Values**
- `OBS_VALUE` is numeric and within `valid_min` / `valid_max`.
- `OBS_VALUE` is empty exactly when `OBS_STATUS` is `Q` or `O`.
- `OBS_STATUS` is consistent with the `N_OBS` thresholds.
- `STD_ERR` ≥ 0, and `CI_LOWER` ≤ `OBS_VALUE` ≤ `CI_UPPER`.
- `N_OBS` is a non-negative integer.

**Consistency**
- For partition breakdowns, the children's `N_POP` sums to the parent's `N_POP`.
- For `additive` indicators, the children's values sum to the parent's value, within a tolerance.

**Warnings (reviewed, not blocking)**
- An indicator is constant across all groups (for example, all 0.00 or all 1.00).
- An indicator is entirely missing.
- An indicator is identical to another indicator in every cell (a duplicate).
- Values are outside the range seen in other countries.

**Assets (section 11)**
- Every `geo_code` in a geometry layer exists in `CL_GEO`, with the same `ref_area` and `level`, and every `CL_GEO` code used in the data has a geometry (or is explicitly flagged as having none).
- Names in geometry layers agree with `CL_GEO`.
- Geometries are valid, unique per code, and in EPSG:4326.
- Every registry row points at a file that exists and whose `sha256` matches.
- Every number quoted in `MESSAGES.csv` resolves to a row of the data file through its `cites_*` columns, and matches it.

**Metadata files**
- Codes are unique and follow the patterns in 5.1.
- Every **R** column is filled.
- Every `parent`, `members`, `replaced_by` and `var_code` reference resolves.
- `slot_order` values are unique.

## 11. Non-tabular data: boundaries, figures and text

### 11.0 The principle

Tabular data hold **codes only**. Everything that is not a table — polygons, images, blocks of text — is an **asset**, and every asset follows the same pattern:

1. It has a **stable ID**.
2. It has a row in a **registry CSV** under `metadata/registries/`, giving its provenance, licence, checksum and the codes it belongs to (`ref_area`, `GEO`, `INDICATOR`, `TIME_PERIOD`).
3. It lives at a **path fixed by convention**.
4. Code refers to it **by ID through the registry, never by path**. Moving or re-versioning a file then changes one row, not the dashboard.
5. It is **never hand-edited**. Corrections to names, codes or descriptions go in the codelists or the registry; the asset stays as it came from its source.

Registries follow the same rules as codelists: append-only, versioned with `metadata/VERSION`, extended through pull requests (section 8).

### 11.1 Administrative boundaries

**The register and the geometry are separate.** `CL_GEO` is the authoritative list of units, names, parents and hierarchy. The geometry file holds shapes and the join key, nothing else. The two are joined on the code.

**Store geometry as GeoPackage** (`.gpkg`), one file per country per boundary vintage, with one layer per level:

```
geo/boundaries/SEN_CODAB_v02_20240520.gpkg
    layers: adm0, adm1, adm2, adm3, lines, capitals
```

Why not keep shapefiles: a shapefile is 5–6 files that must travel together, its DBF field names are cut at 10 characters (the current files show `cod_versio` and `adm1_ref_n`), text fields are limited to 254 characters, the encoding is declared in a side-car `.cpg`, and the `.prj` carries no authority code — the current files say `GCS_WGS_1984` with no EPSG number, so every tool has to guess. A GeoPackage is a single SQLite file with UTF-8 text, long field names, several layers and an SRS with its authority code. Geopandas, QGIS, ArcGIS and R all read it.

Rules:

- **Required layer fields:** `geo_code` (matches `CL_GEO.code`), `ref_area`, `level`. A `name` column may be kept for convenience in QGIS, but `CL_GEO` is authoritative and the validator checks that they agree.
- **CRS:** store as EPSG:4326 (WGS 84 longitude/latitude). Reproject only for display or area computations, never in storage.
- **Geometry hygiene:** valid geometries, no duplicated or overlapping units, one feature per code, and the union of a level covers the country.
- **Vintages are explicit.** Boundaries and P-codes change between releases. The file name carries the source and version, and `GEO_SOURCES.csv` records:

  | Column | Content |
  |---|---|
  | `source_id` | `SEN_CODAB_v02` |
  | `ref_area` | `SEN` |
  | `provider` | OCHA COD-AB, geoBoundaries, national statistics office, … |
  | `version`, `valid_on` | `v02`, `2024-05-20` |
  | `url`, `download_date` | where it came from and when |
  | `licence`, `attribution` | the credit line the map must show |
  | `crs` | `EPSG:4326` |
  | `file`, `layers`, `sha256` | file name, layers it contains, checksum |
  | `status`, `version_added`, `notes` | |

- **When a vintage changes**, add a new source and new `CL_GEO` rows if codes changed; close the old rows with `valid_to` instead of deleting them, so data produced earlier still resolve.
- **Derived layers are generated, not stored.** Zones that are unions of admin units are built by dissolving on `CL_GEO.members`; simplified display layers are built from the full-resolution source. Both go to `geo/derived/` from a build script, are never hand-edited, and may be regenerated at any time. Keep the simplification tolerance in the script, not in a file name.
- **Size.** Keep files in git while they stay small (a few MB). Beyond that, use Git LFS or an external store and keep only the URL and checksum in the registry. The current `sen_admin3.shp` is already 5 MB.
- **A country without usable boundaries** is a blocker for maps, not for data: the tables still publish with `GEO` codes, and the map appears when the geometry lands.

SDMX 3.0 can attach a geographic feature to each code of a geographic codelist. `CL_GEO` plus a GeoPackage keyed on the same codes is the practical equivalent, and can be exported that way later if needed.

### 11.2 Figures and images

Prefer generating figures from the data. An image is a last resort, used today for the fiscal-equity cards.

`assets/figures/<ISO3>/<figure_id>.<ext>`, registered in `FIGURES.csv`:

| Column | Content |
|---|---|
| `figure_id` | Stable ID, referenced by the dashboard |
| `ref_area`, `time_period` | Codes it belongs to |
| `theme` | `CL_THEME` |
| `title_en`, `caption_en` | Shown with the figure |
| `alt_text_en` | Required: the text a screen reader announces |
| `indicators` | Indicator codes shown, if any |
| `source`, `producer`, `program` | Where it came from, and what generated it |
| `licence` | |
| `file`, `sha256` | |
| `status`, `version_added`, `notes` | |

Use vector formats (SVG or PDF) for charts and diagrams, and PNG at twice the display size for anything raster. The file name is not the ID: the dashboard looks up `figure_id`.

### 11.3 Text: methodology and key messages

- **Methodology** (today `INPUT Text/About_<ISO3>.txt`) belongs in `SURVEYS.csv`, in `methodology_en`, or in `assets/text/<ISO3>/<id>.md` when it is long, with the registry pointing at the file.
- **Key messages** (today hardcoded in `index.qmd`, with `Messages_<ISO3>.txt` unread) go in `MESSAGES.csv`:

  | Column | Content |
  |---|---|
  | `message_id` | Stable ID |
  | `ref_area`, `time_period` | |
  | `order` | Display order |
  | `theme` | `CL_THEME` |
  | `text_en` (`text_fr`, `text_pt`) | The message, or empty when `text_file` is used |
  | `text_file` | Path under `assets/text/` for long messages |
  | `cites_indicator`, `cites_geo`, `cites_pov_line`, `cites_ppp` | The exact key of any number quoted in the text |
  | `author`, `status`, `version_added` | |

  The `cites_*` columns are what make messages maintainable: the validator can check a quoted number against the data file, and the dashboard can refresh it when a new round arrives instead of leaving a stale figure in prose.

### 11.4 Microdata and restricted inputs

Microdata never enter the repository. `SURVEYS.csv` records the catalogue ID or URL and the access conditions. The same applies to any input that cannot be shared: store the reference, not the file.

### 11.5 Extending

| I want to… | Files to edit |
|---|---|
| Add boundaries for a new country | `GEO_SOURCES.csv`, the `.gpkg`, `CL_GEO` |
| Refresh a boundary vintage | New `GEO_SOURCES` row and file; close superseded `CL_GEO` rows with `valid_to`, add new ones |
| Add a zoning | `CL_GEO_LEVEL`, `CL_GEO` (with `members` when it is a union), build script |
| Add a figure | `FIGURES.csv` and the file |
| Add or change a key message | `MESSAGES.csv` |

## 12. Open decisions

1. **Suppression thresholds.** The proposal is `Q` below 25 and `U` from 25 to 49 unweighted records (DHS convention). An alternative is a rule based on the coefficient of variation.
2. **Age cutoff for household heads.** The current `Youth_HH` / `Older_HH` cutoff is undocumented. Confirm it before any `HHH_AGE_*` code is published.
3. **Quintile definition.** National or within-area ranking, and person- or household-weighted. Record the answer in `CL_BRK_VAR.definition_en`.
4. **`TIME_PERIOD` convention for surveys spanning two years.** The proposal is the survey's official round year (EHCVM 2021/22 → `2021`).
5. **Governance.** Who in the data team owns `metadata/` and reviews pull requests.
6. **Translations.** Whether French and Portuguese labels are required (**R**) or optional.
7. **GNB survey metadata.** `About_GNB.txt` currently contains only a placeholder, so GNB's survey round and `TIME_PERIOD` are unknown.
8. **Boundary format.** The proposal is to convert `INPUT shp/` to GeoPackage (11.1). Keeping shapefiles is possible but keeps the 10-character field limit and the missing EPSG code.
9. **Where large binaries live.** Git, Git LFS, or an external store referenced from `GEO_SOURCES.csv`.
10. **Boundary vintage policy.** Who decides when to move to a new COD-AB release, given that P-codes can change and old data must still resolve.

## Appendix A. Mapping examples from the current labels

The full mapping goes in `plans/LEGACY_LABELS.csv` (columns `legacy_label`, `sheet`, `INDICATOR`, `POV_LINE`, `PPP`, `notes`). The Python converter uses it.

| Current label | `INDICATOR` | `POV_LINE` | `PPP` | Note |
|---|---|---|---|---|
| Poor at $3.00/day (2021 PPP) | `POV_HC` | `PL300` | `2021` | |
| Poor at $4.20/day (2021 PPP) | `POV_HC` | `PL420` | `2021` | |
| Number poor $4.20/day (millions) | `POV_NUM` | `PL420` | `2021` | Unit `PERSON`: store 6520000, display in millions |
| Poor at $3.00/day (2017 PPP) (`Departement` sheet) | `POV_HC` | `PL300` | `2017` | Pair not allowed yet (section 4) |
| COICOP 1: food & non-alc. beverages (share) | `CONS_SH_CP01` | `_Z` | `_Z` | |
| Food consumption share | `CONS_SH_CP01` | `_Z` | `_Z` | Duplicate label of the same indicator |
| Housing & utilities burden (COICOP 4 share of total cons.) | `CONS_SH_CP04` | `_Z` | `_Z` | Duplicate label of the same indicator |
| Employed (activ12m, 15–64) | `JOB_EMP` | `_Z` | `_Z` | Universe: persons 15–64; `ref_period` `P12M`; `AGE=_T` |
| Employed in agriculture (% of employed) | `JOB_SH_AGR` | `_Z` | `_Z` | Stored as a share |
| HE profits (FCFA) | `HE_PROFIT` | `_Z` | `_Z` | Unit `LCU` (`XOF` via `CL_AREA`); can be negative; period to confirm |
| Monthly electricity spend (FCFA) | `EN_ELEC_SPEND` | `_Z` | `_Z` | Unit `LCU`, `unit_time` `MONTH` |
| Access to electricity (grid, SDG 7.1.1) | `EN_ELEC_ACCESS` | `_Z` | `_Z` | `sdg_indicator` 7.1.1; `related` must explain `EN_GRID_CONN` and `EN_GRID_USE` |
| Average outage duration (code) | `EN_OUTAGE_DUR_CODE` | `_Z` | `_Z` | Unit `CODE`; consider replacing with shares by duration class |
| wood_dist [ALL MISSING] | not registered | | | `DRAFT` until computed |

Current columns map to dimensions like this:

| Current column | New dimensions |
|---|---|
| `estimateTotal` | all `_T` |
| `estimateCapital`, `estimateOther_Urban`, `estimateRural` | `URBANISATION` = `CAP`, `OU`, `R` |
| `estimateFemale_HH`, `estimateMale_HH` | `COMP_BREAKDOWN_1` = `HHH_SEX_F`, `HHH_SEX_M` |
| `estimateYouth_HH`, `estimateOlder_HH` | `COMP_BREAKDOWN_1` = `HHH_AGE_LT35`, `HHH_AGE_GE35` (cutoff to be confirmed) |
| `estimateQ1` … `estimateQ5` | `COMP_BREAKDOWN_1` = `QUINT_Q1` … `QUINT_Q5` |
| `ADM 1` sheet columns | `GEO` = P-code (`DAKAR` → `SN01`, `SAB` → `GW08`) |
| `ZAE` sheet columns | `GEO` = zone code (`SN_ZAE01` …) |
