# AFW360 data standard and producer guidelines

Draft v0.2, 2026-09-19. Status: proposal, not yet applied to any file.

This document defines how data for the AFW 360 dashboard are structured, coded and documented, and how producers create data files and extend the codelists. It follows the SDMX information model and borrows the World Bank Data360 dimension layout, stored as plain CSV files in git.

Background on the current inputs is in [input-tables-findings.md](input-tables-findings.md). Nothing here changes the current `INPUT Tables/` files. A Python converter will produce the new files from them, and the dashboard will switch over later.

---

# 1. The idea in one page

<!-- TODO IMPROVE WRITEUP BASED ON THE STARTING TEXT: -->
This document describes the data provenance standard proposed for the West Africa Micro Data 360 platform.
It describes how the data must be stored and organized following the SDMX standard.
The key purpose of this document is to be a guiding principle of data preparation by the country economists and data scientist who deal with the micro data. 
The resulting database is meant to be a one-stop-shop about the country-level insights. 

In this data base, all indicators are derived from the country-level micro data.
In order to store these indicators in a structured way, each number in this data is attributed to the country through a `code` needed to say what that value is.
Those codes fall into two families, and telling them apart is the whole model:

<!-- END OFTHE STARTING INFO -->

|  | **Breakdown** | **Qualifier** |
|---|---|---|
| Answers | *Who* is counted | *What* is measured |
| Example | Rural households, Fatick, poorest quintile | At the $4.20 line, in 2021 PPP, on disposable income, food category |
| Population behind each category | Different subsets of the same population | The same population every time |
| Test with `N_POP` | Categories **sum** to the parent | Each category **equals** the parent |
| Empty value means | `_T` — everyone, not split | `_Z` — does not apply |
| Declared in | `TAB_PLAN.csv`, per cut | `CL_INDICATOR.csv`, per indicator |
| Columns | `GEO`, `URBANISATION`, `SEX`, `AGE`, `COMP_BREAKDOWN_1…5` | `POV_HC`, `MEASURE_QUAL_1…5` |

The reason it matters: poverty at four lines is one indicator, not eight; every population share is one indicator, not thirty; and a new grouping such as sector of employment is a row in a codelist, not a change to the file format.

This is a guiding principle of this data base construction and it must be respected diligently.


## 1.1 Common compositions, and how each number is checked

| The number you want | `INDICATOR` | Qualifiers — what is measured | Breakdowns — who is counted | How it is verified |
|---|---|---|---|---|
| Poverty rate at $4.20 (2021 PPP) | `POV_HC` | `POVLINE_PL420`, `PPP_2021` | — | In 0–1; rises with the line, so `PL300 ≤ PL420 ≤ PL830` |
| …rural | `POV_HC` | `POVLINE_PL420`, `PPP_2021` | `URBANISATION=R` | `N_POP`-weighted average of `CAP`, `OU`, `R` equals the national value |
| …Fatick | `POV_HC` | `POVLINE_PL420`, `PPP_2021` | `GEO=SN03` | Same rule over all ADM1 units; their `N_POP` sums to the country |
| …at the national line | `POV_HC` | `POVLINE_NPL` | — | In 0–1; `PPP` not applicable |
| Number of poor people | `POV_NUM` | `POVLINE_PL420`, `PPP_2021` | — | Additive: sums across any breakdown; equals `POV_HC × N_POP` |
| Food share of consumption | `CONS_SH` | `COICOP_CP01` | — | **The 13 COICOP divisions sum to 1** |
| Housing share of consumption | `CONS_SH` | `COICOP_CP04` | — | Same closure; no separate "housing burden" indicator exists |
| Food share, poorest quintile | `CONS_SH` | `COICOP_CP01` | `QUINT_Q1` | Sums to 1 over COICOP within the quintile; Q1–Q5 aggregate to the total by `N_POP` |
| Food share among the poor at $3.00 | `CONS_SH` | `POVLINE_PL300`, `PPP_2021`, `COICOP_CP01` | `POOR_Y` | `POOR_Y` and `POOR_N` aggregate to the total by `N_POP` |
| Share of employed working in agriculture | `POP_SH` | — | `EMP_SECTOR_AGR` | **Categories sum to 1**; equals the `N_POP` ratio to the variable's universe |
| Share of households with 2 enterprises | `POP_SH` | — | `HE_COUNT_2` | Same two rules |
| Gini of disposable income | `INEQ_GINI` | `WELFARE_INC_DISP` | — | In 0–1; `N_POP` equals the national population |
| Incidence of direct transfers, poorest decile | `FISC_INCIDENCE` | `WELFARE_INC_MARKET`, `FI_DIR_TRANSF` | `DEC_MKT_D01` | **Instruments sum to total incidence**; deciles aggregate by `N_POP` |
| Marginal contribution of indirect taxes to poverty | `FISC_MARG_CONTRIB` | `WELFARE_INC_CONSUMABLE`, `POVLINE_PL300`, `PPP_2021`, `FI_INDIR_TAX` | — | Instruments sum to the total effect |

Everything in the last column reduces to three generic rules, and each indicator declares which of them apply (`checks`, section 5.2):

1. **Aggregation.** Over a partition, totals sum and means or shares aggregate as `N_POP`-weighted averages.
2. **Closure.** Some qualifiers partition the *measured quantity*: COICOP divisions sum to 1, fiscal instruments sum to the total.
3. **Range and order.** Shares lie in 0–1, counts are non-negative, and the headcount rises with the poverty line.

## 1.2 The same rows, as they are actually written

| The value | `GEO` | `URBANISATION` | `INDICATOR` | `MEASURE_QUAL_1` | `MEASURE_QUAL_2` | `MEASURE_QUAL_3` | `COMP_BREAKDOWN_1` |
|---|---|---|---|---|---|---|---|
| Poverty at $4.20, national | `_T` | `_T` | `POV_HC` | `POVLINE_PL420` | `PPP_2021` | `_Z` | `_T` |
| Poverty at $4.20, rural | `_T` | `R` | `POV_HC` | `POVLINE_PL420` | `PPP_2021` | `_Z` | `_T` |
| Poverty at $4.20, Fatick | `SN03` | `_T` | `POV_HC` | `POVLINE_PL420` | `PPP_2021` | `_Z` | `_T` |
| Poverty at the national line | `_T` | `_T` | `POV_HC` | `POVLINE_NPL` | `_Z` | `_Z` | `_T` |
| Poverty at $3.00 on consumable income | `_T` | `_T` | `POV_HC` | `WELFARE_INC_CONSUMABLE` | `POVLINE_PL300` | `PPP_2021` | `_T` |
| Number of poor at $4.20 | `_T` | `_T` | `POV_NUM` | `POVLINE_PL420` | `PPP_2021` | `_Z` | `_T` |
| Food share, poorest quintile | `_T` | `_T` | `CONS_SH` | `COICOP_CP01` | `_Z` | `_Z` | `QUINT_Q1` |
| Food share among the poor at $3.00 | `_T` | `_T` | `CONS_SH` | `POVLINE_PL300` | `PPP_2021` | `COICOP_CP01` | `POOR_Y` |
| Share of employed in agriculture | `_T` | `_T` | `POP_SH` | `_Z` | `_Z` | `_Z` | `EMP_SECTOR_AGR` |
| Gini of disposable income | `_T` | `_T` | `INEQ_GINI` | `WELFARE_INC_DISP` | `_Z` | `_Z` | `_T` |
| Incidence of direct transfers, poorest decile | `_T` | `_T` | `FISC_INCIDENCE` | `WELFARE_INC_MARKET` | `FI_DIR_TRANSF` | `_Z` | `DEC_MKT_D01` |
| Poverty rate, 2017 PPP (legacy `Departement`) | `SN03` | `_T` | `POV_HC` | `POVLINE_PL300` | `PPP_2017` | `_Z` | `_T` |

In every row `REF_AREA=SEN`, `TIME_PERIOD=2021`, `SEX` and `AGE` are `_T` (total), `COMP_BREAKDOWN_2…5` are `_T` (total), and `MEASURE_QUAL_4…5` are `_Z` (not applicalbe).

Qualifiers occupy the slots in `slot_order`: welfare concept 10, poverty line 20, PPP 30, COICOP 40, fiscal instrument 50. That is why the COICOP code lands in slot 3 on the "food share among the poor" row.

## 1.3 Decisions taken

| Decision | Choice |
|---|---|
| Breakdowns | Named `GEO`, `URBANISATION`, `SEX`, `AGE`, plus five generic slots |
| Qualifiers | Five generic slots. Poverty line, PPP round, welfare concept, COICOP division and fiscal instrument are all qualifiers. |
| Population shares | One indicator, `POP_SH`, with the group named by the breakdown |
| Suppression | **None.** Every estimate is published, with its sample size and confidence interval attached. |
| Geography | Parallel spatial schemes, not a hierarchy. Maps only for country outlines and ADM1. |
| Language | English only |
| Who extends codelists | Producers, through pull requests reviewed by the data team |
| Tooling | Producers deliver CSV. Converter, validator and dashboard loader are Python. |

Open decisions are in section 12.

## 1.4 Where everything lives

```
metadata/
  VERSION                      semantic version of the whole metadata package
  CHANGELOG.md
  structure/
    DSD_AFW360_HH.csv          column list of the data files (data team only)
  codelists/
    CL_AREA.csv                countries
    CL_GEO_SCHEME.csv          spatial schemes, per country
    CL_GEO.csv                 spatial units
    CL_INDICATOR.csv           the indicator dictionary
    CL_BRK_VAR.csv             breakdown variables
    CL_COMP_BREAKDOWN.csv      breakdown categories
    CL_QUAL_VAR.csv            qualifier variables
    CL_QUALIFIER.csv           qualifier categories
    CL_SEX.csv  CL_AGE.csv  CL_URBANISATION.csv
    CL_OBS_STATUS.csv
    CL_THEME.csv  CL_UNIT.csv  CL_STAT_UNIT.csv  CL_STATISTIC.csv  CL_WEIGHT.csv
  surveys/
    SURVEYS.csv                one row per country x survey round
  plans/
    TAB_PLAN.csv               which cuts are produced
    LEGACY_LABELS.csv          old Excel labels -> new codes (used by the converter)
  registries/
    GEO_SOURCES.csv            boundary files and their vintages
    FIGURES.csv                images
data/
  AFW360_HH_<ISO3>_<YEAR>.csv
  AFW360_HH_<ISO3>_<YEAR>_manifest.csv
geo/
  boundaries/<ISO3>_<SOURCE_ID>.gpkg
  derived/                     generated display layers; never hand-edited
content/
  TEXT.csv                     dashboard prose, one row per slot
  text/<ISO3>/<slot>.md        long-form bodies
assets/
  figures/<ISO3>/<figure_id>.<ext>
```

---

# 2. Data structure: dataflow `AFW360_HH`

`AFW360_HH` covers everything estimated from household-survey microdata: poverty, consumption, jobs, enterprises, agriculture, energy, housing, shocks, social protection, inequality and fiscal incidence. Fiscal incidence is *not* a separate dataflow — it comes from the same households and the same cuts, and differs only in its qualifiers.

A separate dataflow is needed only when the statistical unit is not the household population at all, for example tax parameters by bracket or macroeconomic series. The rule is: **new dimensions or different units mean a new dataflow; a new source or a new round means only a new file.**

## 2.1 Columns

Data files have exactly these 26 columns, in this order.

| # | Column | Role | Values | Required |
|---|---|---|---|---|
| 1 | `DATAFLOW` | constant | `AFW360_HH` | R |
| 2 | `REF_AREA` | breakdown | `CL_AREA` (ISO 3166-1 alpha-3) | R |
| 3 | `GEO` | breakdown | `CL_GEO`, or `_T` for the whole country | R |
| 4 | `TIME_PERIOD` | reference | 4-digit year the estimate refers to | R |
| 5 | `INDICATOR` | measure | `CL_INDICATOR` | R |
| 6 | `SEX` | breakdown | `CL_SEX`, `_T`, or `_Z` | R |
| 7 | `AGE` | breakdown | `CL_AGE`, `_T`, or `_Z` | R |
| 8 | `URBANISATION` | breakdown | `CL_URBANISATION` or `_T` | R |
| 9–13 | `COMP_BREAKDOWN_1…5` | breakdown | `CL_COMP_BREAKDOWN` or `_T` | R |
| 14–18 | `MEASURE_QUAL_1…5` | qualifier | `CL_QUALIFIER` or `_Z` | R |
| 19 | `OBS_VALUE` | measure | number | R unless `OBS_STATUS` is `O` or `M` |
| 20 | `OBS_STATUS` | attribute | `CL_OBS_STATUS` | R |
| 21 | `STD_ERR` | attribute | number ≥ 0 | R where the statistic admits one |
| 22 | `CI_LOWER` | attribute | number, 95% | R where `STD_ERR` is |
| 23 | `CI_UPPER` | attribute | number, 95% | R where `STD_ERR` is |
| 24 | `N_OBS` | attribute | integer ≥ 0 | R |
| 25 | `N_POP` | attribute | number ≥ 0 | R |
| 26 | `OBS_COMMENT` | attribute | free text, English | O |

## 2.2 The two sentinels

`_T` and `_Z` are reserved. They are never listed in a codelist, and no code may start with them.

- **`_T` — total.** The value covers every unit, not split on this dimension. Valid in `GEO`, `SEX`, `AGE`, `URBANISATION` and the breakdown slots.
- **`_Z` — not applicable.** Valid in every unused qualifier slot, and in `SEX` or `AGE` when the indicator is not about individuals. A household-level indicator writes `SEX=_Z`, not `SEX=_T`, because "total over both sexes" would be a claim about a dimension that does not apply to households.
- `GEO` and `URBANISATION` are never `_Z`: every unit lives somewhere.

## 2.3 Rules for the breakdown columns

1. **Fill the slots from the left, with no gaps.** Unused slots are `_T`.
2. **Canonical order.** Several breakdowns in one row go in ascending `slot_order` from `CL_BRK_VAR`, with ties broken alphabetically by `var_code`. Each combination then has exactly one spelling.
3. **One category per variable per row.**
4. **Unit compatibility.** A breakdown variable may be used only with indicators whose `stat_unit` appears in its `applies_to_units`.
5. **Never duplicate a named dimension.** Residence, individual sex, individual age and geography always go in their own columns.
6. `SEX` and `AGE` describe **the individual being counted**, not the household head. The head's characteristics are breakdown variables (`HHH_SEX`, `HHH_AGE`) and go in the slots.
7. **An age band that defines an indicator's universe is not a breakdown.** "Employed, 15–64" has that band in its `universe` and writes `AGE=_T`.

## 2.4 Rules for the qualifier columns

1. Fill from the left, no gaps, unused slots `_Z`.
2. Canonical order by `slot_order` from `CL_QUAL_VAR`, ties broken alphabetically.
3. One category per qualifier variable per row.
4. **A row may use only the qualifiers its indicator declares** in `CL_INDICATOR.qualifiers`, plus any qualifier required by a breakdown it uses. `POOR_Y` requires a poverty line, so a food-share row broken down by poverty status carries `POVLINE_*` and `PPP_*` even though `CONS_SH` does not otherwise use them.
5. Pairings must be allowed: `CL_QUALIFIER.valid_with` says which PPP rounds go with which line.

## 2.5 Values and attributes

- **Store `OBS_VALUE` unrounded**, with `.` as the decimal separator and no thousands separator or `%` sign. Rounding is a display decision (`display_as`, `decimals`).
- **Use base units.** Shares are 0–1, never 0–100. People are counted in persons, not millions. Money is in whole currency units.
- **No suppression.** Every estimate is published whatever its sample size. Reliability travels with the value instead: `N_OBS`, `N_POP`, `STD_ERR` and the confidence interval are required on every row, and the dashboard shows them (section 6.3).
- **`OBS_STATUS`:**

  | Code | Meaning | `OBS_VALUE` |
  |---|---|---|
  | `A` | Normal value | filled |
  | `E` | Model-based: projection, nowcast or microsimulation | filled |
  | `O` | In universe, but no observations fell in this cell | empty |
  | `M` | Cannot exist: the cell is outside the indicator's universe by definition | empty |

  The codes come from the SDMX cross-domain `CL_OBS_STATUS`. Cells that can never exist are normally left out of the file altogether by declaring them in `excluded_breakdowns` (5.2); `M` is for keeping the row when a producer prefers a visible gap.
- **`N_OBS`** is the unweighted number of **records of the estimation file** used: records in the group, in the indicator's universe, with a non-missing value. When a person-weighted poverty rate is computed on a household file, `N_OBS` counts households. `SURVEYS.analysis_units` records which file each `stat_unit` is estimated from, so a reader always knows what `N_OBS` counts.
- **`N_POP`** is the sum of weights over those same records: the population, households or enterprises the value refers to.
- **Precision** must reflect the survey design — weights, strata and PSUs, linearized — at 95%.

## 2.6 Which rows exist

For each indicator, the required rows are:

> (the qualifier combinations declared in `CL_INDICATOR.qualifiers`) × (the cuts in `TAB_PLAN` that cover its theme and unit) × (the categories of those cuts) − (anything listed in `excluded_breakdowns`)

Nothing extra, nothing missing. A cell with no observations is a row with `OBS_STATUS=O`, not an absent row.

---

# 3. Breakdowns

A **breakdown variable** classifies units: sex of household head, consumption quintile, sector of employment, poverty status. It is one row in `CL_BRK_VAR`; its categories are rows in `CL_COMP_BREAKDOWN`, each code beginning with its variable code.

Adding one changes no structure — two codelist rows and a line in `TAB_PLAN`.

## 3.1 Initial breakdown variables

| `var_code` | Describes | Universe | Categories | `slot_order` |
|---|---|---|---|---|
| `QUINT` | Household | All households | `QUINT_Q1` … `QUINT_Q5` | 10 |
| `HHH_SEX` | Household head | All households | `HHH_SEX_F`, `HHH_SEX_M` | 20 |
| `HHH_AGE` | Household head | All households | `HHH_AGE_LT35`, `HHH_AGE_GE35` (cutoff to be confirmed) | 30 |
| `POOR` | Household | All households | `POOR_Y`, `POOR_N` (requires a poverty line) | 40 |
| `HE_COUNT` | Household | All households | `HE_COUNT_0` … `HE_COUNT_4P` | 50 |
| `EMP_STATUS` | Individual | Persons aged 15–64 | `EMP_STATUS_EMPLOYED`, `EMP_STATUS_NOT_EMPLOYED` | 55 |
| `EMP_SECTOR` | Individual | Employed persons 15–64 | `EMP_SECTOR_AGR`, `_IND`, `_SER` | 60 |
| `DEC_MKT` | Household | All households | `DEC_MKT_D01` … `DEC_MKT_D10` | 15 |

`DEC_MKT` is registered for fiscal-incidence work, where households are ranked by market income; `QUINT` ranks them by consumption per capita. Two different rankings are two different variables, each stating its basis in `definition_en`.

## 3.2 Every breakdown variable carries a universe

`CL_BRK_VAR.universe` names the population the categories partition. This is what makes `POP_SH` work as a single indicator: the share is the category's `N_POP` divided by the universe's `N_POP`, so "share of employed in agriculture" and "share of households with two enterprises" are the same indicator with different breakdowns.

## 3.3 Worked example: adding sector of employment

1. Decide whose characteristic it is. "Sector of an individual's main job" (`EMP_SECTOR`, describes `IND`) and "sector of the household head's main job" (`HHH_SECTOR`, describes `HHH`) are two different variables. The first can break down only individual-level indicators; the second can break down household indicators such as the poverty rate.
2. Register it in `CL_BRK_VAR`: `describes = IND`, `applies_to_units = IND`, `universe = employed persons aged 15–64`, `classification = ISIC Rev.4`, `partition = Y`, `slot_order = 60`.
3. Register the categories in `CL_COMP_BREAKDOWN` (ISIC A; B–F; G–U).
4. Add a cut to `TAB_PLAN`.
5. Produce the rows. Crossed with individual sex, add `SEX=F`. Crossed with quintile, `QUINT` has the lower `slot_order`, so it takes slot 1 and `EMP_SECTOR` takes slot 2.

---

# 4. Qualifiers

A **qualifier variable** changes what is measured for the same units. It is one row in `CL_QUAL_VAR`; its categories are rows in `CL_QUALIFIER`.

| `var_code` | What it says | Categories | `slot_order` |
|---|---|---|---|
| `WELFARE` | Which welfare aggregate the measure is built on | `WELFARE_CONS_PC`, `WELFARE_INC_MARKET`, `WELFARE_INC_MARKET_PENS`, `WELFARE_INC_NETMARKET`, `WELFARE_INC_DISP`, `WELFARE_INC_CONSUMABLE`, `WELFARE_INC_FINAL` | 10 |
| `POVLINE` | Which poverty line | see below | 20 |
| `PPP` | Which PPP round the line or value uses | `PPP_2011`, `PPP_2017`, `PPP_2021` | 30 |
| `COICOP` | Which consumption division (COICOP 2018) | `COICOP_CP01` … `COICOP_CP13` | 40 |
| `FISCAL_INSTRUMENT` | Which fiscal intervention | `FI_DIR_TAX`, `FI_DIR_TRANSF`, `FI_INDIR_TAX`, `FI_SUBSIDY`, `FI_INKIND_EDU`, `FI_INKIND_HEALTH`, `FI_ALL` | 50 |

## 4.1 Poverty lines

| `code` | `value` | `basis` | `valid_with` |
|---|---|---|---|
| `POVLINE_PL215` | 2.15 | PPP$ per person per day | `PPP_2017` |
| `POVLINE_PL365` | 3.65 | PPP$ per person per day | `PPP_2017` |
| `POVLINE_PL685` | 6.85 | PPP$ per person per day | `PPP_2017` |
| `POVLINE_PL300` | 3.00 | PPP$ per person per day | `PPP_2021`, `PPP_2017` (legacy, see A.2) |
| `POVLINE_PL420` | 4.20 | PPP$ per person per day | `PPP_2021` |
| `POVLINE_PL830` | 8.30 | PPP$ per person per day | `PPP_2021` |
| `POVLINE_NPL` | per survey | Local currency; the value is in `SURVEYS.csv` | `_Z` |
| `POVLINE_NPL_FOOD` | per survey | Local currency; the value is in `SURVEYS.csv` | `_Z` |

$2.15 / $3.65 / $6.85 are the international, lower-middle-income country and upper-middle-income country lines at 2017 PPP; $3.00 / $4.20 / $8.30 are their 2021 PPP replacements. `POVLINE_NPL` means "the national line of this survey", whose value differs by country and round.

## 4.2 PPP beyond poverty

The `PPP` qualifier also marks values expressed in PPP dollars — mean consumption per capita per day in 2021 PPP$, for example. Values in local currency carry no `PPP` code; their currency comes from `CL_AREA`.

---

# 5. Metadata files

Rules for every CSV under `metadata/` and `content/`:

- UTF-8, comma-separated, one header row. Readers must open with `utf-8-sig`, because Excel's "CSV UTF-8" writes a byte-order mark.
- Multi-valued fields are space-separated.
- No literal newlines inside a cell. Anything that needs paragraphs goes in a Markdown file (section 9).
- Column status: **R** required, **C** required when relevant, **O** optional.
- **Every codelist has these columns**, plus the extra ones listed below it: `code`, `name_en`, `definition_en`, `status` (`DRAFT`, `ACTIVE`, `DEPRECATED`), `version_added`, `replaced_by` (C), `notes` (O).

## 5.1 Code rules

- Uppercase ASCII letters, digits and `_`; start with a letter; at most **32 characters**, the Stata variable-name limit. P-codes are used as issued and already comply.
- `_T` and `_Z` are reserved sentinels and never appear as codes.
- **A code never changes meaning, and is never reused or deleted.** A changed definition means a new code, with the old one `DEPRECATED` and `replaced_by` filled. Rewording a label is free.
- Breakdown and qualifier categories are `<var_code>_<category>`, so a `var_code` is at most 20 characters and a category suffix at most 11.
- Indicator codes are `<THEME>_<SUBJECT>[_<QUALIFIER>]` and contain no poverty line, PPP round, welfare concept, COICOP division, unit or breakdown — all of those are dimensions. Use `POV_HC`, never `POV_HC_PL420`.
- In Stata, name the variable holding an indicator after its code in lower case, so no lookup table is needed.

## 5.2 `CL_INDICATOR.csv`: the indicator dictionary

Beyond the common columns:

| Column | | Content | Example (`POP_SH`) |
|---|---|---|---|
| `short_name_en` | R | At most 40 characters, for chart labels | Population share |
| `theme` | R | `CL_THEME` | `POP` |
| `stat_unit` | R | `CL_STAT_UNIT`: what is counted | `IND` |
| `universe_unit` | R | The unit forming the denominator | `IND` |
| `universe_filter` | C | Restriction in words; empty means all units | (from the breakdown) |
| `numerator` | C | For shares and ratios | The units in the breakdown category |
| `statistic` | R | `CL_STATISTIC` | `PROPORTION` |
| `weight` | R | `CL_WEIGHT` | `POP` |
| `ref_period` | R | ISO 8601 duration (`P7D`, `P12M`, `P3Y`) or `INTERVIEW`. Always `P12M`, never `P1Y`. | `INTERVIEW` |
| `qualifiers` | R | Qualifier variables this indicator takes, with allowed categories or `*`; `_Z` if none | `_Z` |
| `excluded_breakdowns` | O | Breakdown variables or categories that lie outside its universe and must not be produced | |
| `unit_measure` | R | `CL_UNIT` | `SHARE` |
| `unit_denom` | C | What the value is per, for levels | |
| `unit_time` | C | `DAY`, `MONTH`, `YEAR`, for flows | |
| `price_basis` | C | `NOMINAL` or `DEFLATED`, for money | |
| `price_ref_year` | C | Required when `price_basis = DEFLATED` | |
| `display_as` | R | `PERCENT`, `NUMBER`, `THOUSANDS`, `MILLIONS`, `CURRENCY` | `PERCENT` |
| `decimals` | R | Decimals to display | `1` |
| `valid_min`, `valid_max` | R | Plausible range; empty means unbounded | `0`, `1` |
| `checks` | R | Machine-readable verification rules (below) | `RANGE_0_1 EQUALS_NPOP_RATIO SUM_TO_1_OVER_BRK AGG_NPOP_MEAN` |
| `higher_is` | R | `BETTER`, `WORSE`, `NEUTRAL`: colour direction on maps | `NEUTRAL` |
| `sdg_indicator` | O | | |
| `classification` | O | `COICOP2018`, `ISIC4:A`, … | |
| `related` | O | Codes of close indicators (space-separated) | |
| `related_note` | O | How this one differs from them | |
| `source_questionnaire` | R | Survey module or section | |
| `source_vars` | R | Harmonized microdata variables used | |
| `program` | R | Program that computes it | |
| `owner` | R | Team or person responsible | |

`display_as` fixes the defect the dashboard has today: a share is stored as 0.37 and displayed as `37.0%`, while `POV_NUM` is stored as 6520000 and displayed as `6.52` million.

**`checks` vocabulary:** `RANGE_0_1`, `RANGE_NONNEG`, `AGG_SUM` (totals sum over a partition), `AGG_NPOP_MEAN` (means aggregate as `N_POP`-weighted averages), `SUM_TO_1_OVER:<QUAL_VAR>` (for example COICOP), `SUM_TO_1_OVER_BRK` (categories of the breakdown sum to 1), `EQUALS_NPOP_RATIO`, `MONOTONE_IN:POVLINE`, `NONE`.

**Why the population fields matter.** `HHH_SEX_F` means "people living in female-headed households" for a person-level poverty rate and "enterprises in female-headed households" for an enterprise indicator. Without `stat_unit`, `universe_*` and `weight`, person-weighted and household-weighted numbers end up on the same chart. `statistic` matters too: a budget share can be the mean of household shares (`MEAN`) or the share of aggregate spending (`RATIO_TOTALS`), and the two differ.

## 5.3 `CL_BRK_VAR.csv`

Beyond the common columns (`code` is the `var_code`):

| Column | | Content |
|---|---|---|
| `describes` | R | Whose characteristic: `IND`, `HHH` (household head), `HH`, `HE` |
| `applies_to_units` | R | `stat_unit` values it may break down, e.g. `HH IND HE` |
| `universe` | R | The population its categories partition (section 3.2) |
| `classification` | O | ISIC Rev.4, ISCED 2011, ISCO-08, … |
| `partition` | R | `Y` if the categories are mutually exclusive and cover the universe |
| `requires_qual` | C | Qualifier variables the categories depend on, e.g. `POVLINE PPP` for `POOR` |
| `slot_order` | R | Integer; gaps of 10. Ties break alphabetically, so collisions are harmless. |
| `owner` | R | |

## 5.4 `CL_COMP_BREAKDOWN.csv`

Extra columns: `var_code` (R), `parent` (O, a category of the same variable, for nested classifications), `order` (R, display order). `definition_en` is required wherever the boundary is not obvious — age cutoffs, ISIC groupings, quantile ranking rules.

## 5.5 `CL_QUAL_VAR.csv` and `CL_QUALIFIER.csv`

`CL_QUAL_VAR` extra columns: `slot_order` (R), `requires` (C, other qualifier variables that must appear with it, such as `PPP` for `POVLINE`), `owner` (R).

`CL_QUALIFIER` extra columns: `var_code` (R), `value` (C, the numeric parameter, such as 3.00 for `POVLINE_PL300`), `basis` (C, what that value is expressed in), `valid_with` (C, allowed categories of other qualifier variables), `order` (R).

## 5.6 `CL_GEO_SCHEME.csv` and `CL_GEO.csv`

**Schemes are parallel, not nested.** ADM1 regions, ADM2 départements, Senegal's geopolitical zones and Guinea-Bissau's agro-ecological zones are four different ways of cutting a country. None is derived from another, and no scheme is required to decompose into any other.

`CL_GEO_SCHEME` has one row per country and scheme, keyed `ref_area` + `code`:

| Column | | Content | Example |
|---|---|---|---|
| `code` | R | `ADM1`, `ADM2`, `ZONES`, `AEZ` | `ADM2` |
| `ref_area` | R | Country | `SEN` |
| `local_name_en` | R | What that level is called in the country | Département |
| `has_geometry` | R | `Y` only for `ADM0` and `ADM1` (section 8.1) | `N` |
| `nests_in` | O | Another scheme, only where nesting is genuine; used for optional roll-up checks, never to derive geometry | `ADM1` |
| `partition` | R | `Y` if its units cover the country exactly once | `Y` |

`CL_GEO`:

| Column | | Content | Example |
|---|---|---|---|
| `code` | R | P-code for admin units; `<ISO2>_<SCHEME><nn>` for other schemes | `SN03`, `GW08`, `SN_ZONES01` |
| `ref_area` | R | | `SEN` |
| `scheme` | R | `CL_GEO_SCHEME.code` for that country | `ADM1` |
| `name_en` | R | Name as issued by the boundary source | Fatick |
| `parent` | C | Containing unit, only when `nests_in` is set | |
| `source_id` | C | `GEO_SOURCES.csv`; required when `has_geometry = Y` | `SEN_CODAB_v02` |
| `geom_layer` | C | Layer holding the polygon | `adm1` |
| `valid_from`, `valid_to` | R/C | The **boundary vintage** the code belongs to, not the validity of the data. `valid_to` is empty while current. | `2024-05-20` |

The shapefiles in `INPUT shp/` already carry these P-codes: `SN01` is Dakar, `SN03` is Fatick, `GW08` is Bissau (the current tables call it `SAB`). Maps join on codes, never on names.

## 5.7 `CL_AREA.csv`

Extra columns: `iso2` (R, the P-code prefix), `currency` (R, ISO 4217), `wb_region` (R).

Currency matters more than it looks. "FCFA" is two different currencies — `XOF` (CFA Franc BCEAO, WAEMU, including SEN and GNB) and `XAF` (CFA Franc BEAC) — and eight AFW economies use neither. Monetary values in `LCU` are therefore **not comparable across countries**; comparison needs a PPP-denominated indicator.

## 5.8 Small codelists

| Codelist | Codes |
|---|---|
| `CL_SEX` | `F`, `M` (plus the sentinels) |
| `CL_AGE` | SDMX-style bands as needed: `Y_LT15`, `Y15T24`, `Y25T64`, `Y_GE65`, … |
| `CL_URBANISATION` | `U`, `R`, `CAP` (`parent = U`), `OU` (`parent = U`) — this codelist has a `parent` column |
| `CL_OBS_STATUS` | `A`, `E`, `O`, `M` (section 2.5) |
| `CL_THEME` | `POV`, `INEQ`, `FISC`, `POP`, `CONS`, `JOB`, `HE`, `AGR`, `EN`, `HOUS`, `SHK`, `SP` |
| `CL_STAT_UNIT` | `IND`, `HH`, `HE`, `PLOT` |
| `CL_STATISTIC` | `PROPORTION`, `MEAN`, `MEDIAN`, `TOTAL`, `RATIO_TOTALS`, `GINI`, `INDEX` |
| `CL_WEIGHT` | `POP` (household weight × household size), `HH`, `IND`, `HE` |
| `CL_UNIT` | `SHARE` (0–1), `INDEX` (for Gini and similar), `PERSON`, `HH`, `HE`, `LCU`, `PPP_USD`, `HA`, `TLU`, `DAY`, `YEAR`, `COUNT` |

## 5.9 `SURVEYS.csv`

| Column | | Example (SEN, from `About_SEN.txt`) |
|---|---|---|
| `survey_id` | R | `SEN_EHCVM_2021` |
| `ref_area`, `time_period` | R | `SEN`, `2021` |
| `survey_name`, `survey_acronym` | R | Enquête Harmonisée sur les Conditions de Vie des Ménages, EHCVM |
| `producer_agency` | R | ANSD |
| `fieldwork_start`, `fieldwork_end` | R | `2021-11`, `2022-09` |
| `sample_hh`, `sample_ind` | R/O | 7100 |
| `design` | R | Stratification, stages, PSU |
| `representative_levels` | R | Levels the design supports, as **advisory metadata** the dashboard may display. It does not gate publication. |
| `analysis_units` | R | Which file each `stat_unit` is estimated from, so `N_OBS` is interpretable |
| `welfare_aggregate` | R | Consumption per capita |
| `welfare_adjustments` | R | Spatial and temporal deflation |
| `npl_value`, `npl_currency`, `npl_unit`, `npl_ref_year` | C | 519.8, XOF, per capita per day, 2018 (the source says "estimated using the EHCVM 2018 … in current prices"; the price year is an inference — record it as such) |
| `ppp_rounds` | R | `2017 2021` |
| `microdata_ref` | O | Catalogue ID or URL |
| `comparable_with` | O | `SEN_EHCVM_2018` |
| `contact`, `notes` | O | |

## 5.10 Manifest

`AFW360_HH_<ISO3>_<YEAR>_manifest.csv` has two columns, `key` and `value`:

`dataflow`, `dsd_version`, `metadata_version`, `ref_area`, `time_period`, `source_type` (`SURVEY`, `PROJECTION`, `ADMIN`), `survey_id` (the base survey, also for a projection), `precision` (`EXACT` or `ROUNDED_2DP` for legacy conversions), `file_name`, `n_rows`, `producer`, `program`, `software`, `run_timestamp` (ISO 8601), `status` (`DRAFT`, `SUBMITTED`, `VALIDATED`, `PUBLISHED`), `notes`.

`TIME_PERIOD` is the year the estimate refers to, which is **not** always a survey year: a microsimulated 2026 poverty rate is `TIME_PERIOD=2026`, `source_type=PROJECTION`, `survey_id=SEN_EHCVM_2021`, with every row `OBS_STATUS=E`.

## 5.11 `TAB_PLAN.csv`: which cuts are produced

One row per cut. Columns give the codes used, not yes/no flags.

| Column | Content |
|---|---|
| `cut_id` | `ADM1`, `QUINT`, … |
| `ref_area` | ISO3, or `ALL` |
| `geo_scheme` | `_T`, or a scheme code |
| `urbanisation` | `_T`, or a set such as `CAP OU R` or `U R` |
| `sex` | `_T`, or `F M` |
| `age` | `_T`, or a set of `CL_AGE` codes |
| `comp_breakdowns` | Breakdown variable codes in slot order, e.g. `QUINT HHH_SEX` |
| `themes` | `ALL`, or a list of `CL_THEME` codes |
| `status` | `ACTIVE` or `DRAFT` |

The initial plan reproduces the current Excel tables. Every row has `ref_area = ALL`, `sex = _T`, `age = _T`, `themes = ALL`, `status = ACTIVE`:

| `cut_id` | `geo_scheme` | `urbanisation` | `comp_breakdowns` | Current source |
|---|---|---|---|---|
| `TOTAL` | `_T` | `_T` | | `estimateTotal` |
| `URB` | `_T` | `CAP OU R` | | `estimateCapital`, `…Other_Urban`, `…Rural` |
| `HHH_SEX` | `_T` | `_T` | `HHH_SEX` | `estimateFemale_HH`, `…Male_HH` |
| `HHH_AGE` | `_T` | `_T` | `HHH_AGE` | `estimateYouth_HH`, `…Older_HH` |
| `QUINT` | `_T` | `_T` | `QUINT` | `estimateQ1` … `Q5` |
| `ADM1` | `ADM1` | `_T` | | `ADM 1` sheet |
| `ZONES` | `ZONES` / `AEZ` | `_T` | | `ZAE` sheet |

---

# 6. What a producer delivers

For each country and reference year:

1. **`AFW360_HH_<ISO3>_<YEAR>.csv`**, UTF-8, with the 26 columns of 2.1 in that order.
2. **Every required row** (2.6), including cells with no observations.
3. **The manifest** (5.10).
4. **Any metadata changes** the data need, in the same pull request (section 10).

## 6.1 Estimation rules

- Code the indicator variable as missing for units outside its universe, so they leave both the numerator and the denominator.
- Estimate with the survey design declared — weights, strata, PSUs — using subpopulation estimation for groups rather than dropping observations, so standard errors stay correct.
- Use the weight named in the dictionary (`POP` = household weight × household size for person-level statistics computed on household data).
- Publish every estimate. Do not blank, round away or drop a small cell; report its `N_OBS`.
- Write values unrounded, in base units.

## 6.2 A note on legacy conversions

Files produced by the converter from the current Excel inherit values already rounded to two decimals and carry no sample sizes. Such a file sets `precision = ROUNDED_2DP` in its manifest; the validator relaxes aggregation tolerances accordingly and does not demand `STD_ERR`, `CI_*` or `N_OBS`. This exemption applies only to converted legacy files, never to new production.

## 6.3 How the dashboard shows reliability

Since nothing is suppressed, the dashboard carries the burden of honesty:

- Every value is reachable with its `N_OBS` — on hover, in a details panel, or in the downloaded table.
- Charts show the confidence interval where one exists.
- A cell resting on few records is visually de-emphasised rather than hidden, and `OBS_STATUS=O` renders as "no observations", never as zero.

---

# 7. How to extend

| I want to… | Files to edit | Structural? | Version |
|---|---|---|---|
| Add an indicator | `CL_INDICATOR` (and `CL_THEME` if new) | No | minor |
| Add a category to an existing breakdown | `CL_COMP_BREAKDOWN` | No | minor |
| Add a breakdown variable | `CL_BRK_VAR`, `CL_COMP_BREAKDOWN`, `TAB_PLAN` | No | minor |
| Add a qualifier variable or category | `CL_QUAL_VAR`, `CL_QUALIFIER`, `CL_INDICATOR.qualifiers` | No | minor |
| Add a poverty line or PPP round | `CL_QUALIFIER` | No | minor |
| Cross existing breakdowns | `TAB_PLAN` | No | minor |
| Add a spatial scheme or its units | `CL_GEO_SCHEME`, `CL_GEO`, `TAB_PLAN` | No | minor |
| Add a country | `CL_AREA`, `CL_GEO_SCHEME`, `CL_GEO`, `SURVEYS`, `TAB_PLAN` | No | minor |
| Add a survey round or a projection | `SURVEYS` (for a survey); a new data file and manifest | No | minor |
| Reword a label, same meaning | The codelist concerned | No | patch |
| Change what an indicator measures | New code; old one `DEPRECATED` + `replaced_by` | No | minor |
| A 6th breakdown or qualifier slot, or a new named dimension | `DSD_AFW360_HH` (data team only) | **Yes** | major |
| Add boundaries, a figure or dashboard text | See 8.4 and 9.4 | No | minor |

## 7.1 Add an indicator

1. Search `CL_INDICATOR` for the same concept. If it exists, reuse it. **Before creating a code, check whether the difference is a qualifier:** a different poverty line, PPP round, welfare concept or COICOP division is never a new indicator. Neither is a population share — that is `POP_SH` with a breakdown.
2. If a near-duplicate exists, fill `related` and `related_note` on both rows.
3. Fill every **R** column and the **C** columns that apply, including `qualifiers` and `checks`.
4. Produce it for every applicable cut.
5. Open a pull request (section 10).

## 7.2 Add a breakdown variable

Follow 3.3: decide `describes` and `applies_to_units`, write the `universe`, reuse an international classification if one exists, set `slot_order`, register the categories, add the cuts. Expect small `N_OBS` in fine groups — publish them anyway, with their sample sizes.

## 7.3 Add a qualifier variable

1. Confirm it is a qualifier: the population behind each category is the same one (section 1).
2. Register it with a `slot_order` and, if it depends on another qualifier, `requires`.
3. Register its categories, with `value`, `basis` and `valid_with` where they apply.
4. List it in the `qualifiers` field of every indicator that takes it, naming the allowed categories.

## 7.4 Add a country

1. Add it to `CL_AREA`, with its currency.
2. Register its spatial schemes in `CL_GEO_SCHEME`, with the local level names, and its units in `CL_GEO`, using the P-codes of the boundary file you will map with.
3. Add its survey rounds to `SURVEYS`.
4. Add `TAB_PLAN` rows if its cuts differ from `ALL`.

Every other code comes from the shared codelists. A country-specific category becomes a child of a shared code — a secondary-city stratum is `parent = U` — never an unrelated new code. Mapping the survey's own variable values to shared codes happens in the producer's program.

---

# 8. Boundaries and figures

Every non-tabular asset follows the same pattern: a stable ID, a row in a registry carrying provenance, licence and checksum, a path fixed by convention, and reference **by ID, never by path**. Assets are never hand-edited; corrections go in the codelists.

## 8.1 Maps exist for countries and ADM1 only

`has_geometry = Y` is set for `ADM0` and `ADM1`. Every other scheme — ADM2, zones, agro-ecological zones — publishes as tables with no map, no geometry file and no missing-geometry error. Guinea-Bissau's agro-ecological zones therefore need no polygons, and Senegal's zones need none either.

## 8.2 Storage

GeoPackage (`.gpkg`), one file per country per boundary vintage, with one layer per level:

```
geo/boundaries/SEN_CODAB_v02.gpkg     layers: adm0, adm1
```

A shapefile is 5–6 files that must travel together, its DBF field names are cut at 10 characters (the current files show `cod_versio` and `adm1_ref_n`), text fields stop at 254 characters, the encoding is declared in a side-car `.cpg`, and the `.prj` carries no authority code — the current files say `GCS_WGS_1984` with no EPSG number. A GeoPackage is one SQLite file with UTF-8 text, long field names, several layers and an SRS with its authority code, readable by geopandas, QGIS, ArcGIS and R.

Rules:

- **Required layer fields:** `geo_code` (matching `CL_GEO.code`), `ref_area`, `scheme`. A `name` column may be kept for convenience; `CL_GEO` is authoritative and disagreement is a warning, not an error.
- **CRS:** EPSG:4326 in storage. Reproject only for display or area computation.
- **Hygiene:** valid geometries, one feature per code, units covering the country exactly once.
- **Vintages are explicit.** `valid_from` / `valid_to` in `CL_GEO` describe the boundary release a code belongs to, not the period the data cover: SEN's COD-AB v02 dates from 2024 while the data are for 2021, and that is not an error.
- **Derived layers are generated**, never hand-edited: simplified display copies live in `geo/derived/` and may be rebuilt at any time, with the simplification tolerance kept in the build script.
- **Size:** keep files in git while they are small. Beyond a few MB use Git LFS or an external store, with the URL and checksum in the registry.

`GEO_SOURCES.csv`: `source_id`, `ref_area`, `provider`, `version`, `valid_on`, `url`, `download_date`, `licence`, `attribution` (the credit line the map must show), `crs`, `file`, `layers`, `sha256`, `status`, `version_added`, `notes`.

## 8.3 Figures

`assets/figures/<ISO3>/<figure_id>.<ext>`, registered in `FIGURES.csv`: `figure_id`, `ref_area`, `time_period`, `theme`, `title_en`, `caption_en`, `alt_text_en` (required — what a screen reader announces), `indicators`, `source`, `producer`, `program`, `licence`, `file`, `sha256`, `status`, `version_added`, `notes`.

Prefer generating figures from the data; an image is a last resort. Use SVG or PDF for charts, and PNG at twice display size for anything raster. The dashboard asks for `figure_id`, not a file name.

## 8.4 Extending

| I want to… | Files to edit |
|---|---|
| Add ADM0/ADM1 boundaries for a country | `GEO_SOURCES.csv`, the `.gpkg`, `CL_GEO` |
| Refresh a boundary vintage | New `GEO_SOURCES` row and file; close superseded `CL_GEO` rows with `valid_to`, add the new ones |
| Add a spatial scheme with no map | `CL_GEO_SCHEME` (`has_geometry = N`), `CL_GEO` |
| Add a figure | `FIGURES.csv` and the file |

---

# 9. Dashboard text

All prose the dashboard shows lives in one place and is written by hand, in English.

```
content/TEXT.csv                one row per slot
content/text/<ISO3>/<slot>.md   long-form bodies
```

## 9.1 `TEXT.csv`

| Column | | Content |
|---|---|---|
| `slot` | R | Where it appears: `about`, `messages`, `energy_intro`, `map_note`, … The dashboard asks for a slot by name. |
| `ref_area` | R | ISO3, or `ALL` for shared boilerplate |
| `time_period` | R | Year, or `ALL` |
| `order` | R | Position within a slot that holds several items, such as key messages |
| `title` | O | |
| `body` | C | The text, one paragraph, no line breaks |
| `file` | C | Path under `content/text/` for anything longer. Exactly one of `body` and `file` is filled. |
| `status` | R | `DRAFT` or `PUBLISHED`; the dashboard shows only `PUBLISHED` in production |
| `updated_on` | R | ISO date |

A country row overrides an `ALL` row for the same slot, which keeps shared methodology in one place instead of copied per country — the current `About.txt` and `About_SEN.txt` are byte-identical copies.

Markdown in `body` and in the files is limited to paragraphs, emphasis, links, lists and footnotes. No raw HTML.

## 9.2 Live numbers in prose

Numbers quoted in text go stale and nothing checks them — the current key messages are typed into `index.qmd` by hand. Instead, reference the data inline:

```
Poverty fell to {{POV_HC:PL420}} percent, and {{POV_NUM:PL420}} people remain poor.
Rural poverty stands at {{POV_HC:PL420@URBANISATION=R}} percent.
```

- The country, year and national total come from the row, so a plain `{{INDICATOR:QUALIFIER}}` is usually enough.
- Anything unusual is added after `@` as `DIMENSION=CODE`, separated by commas.
- The dashboard formats the number with that indicator's `display_as` and `decimals`, so prose and tables cannot disagree.
- The validator resolves every reference to exactly one observation and fails if it finds none or several.

## 9.3 What this replaces

`About_<ISO3>.txt`, `Messages_<ISO3>.txt`, and every string hardcoded in `index.qmd`. Figure captions stay in `FIGURES.csv` with their images.

## 9.4 Extending

Add or edit a row in `TEXT.csv`; add a `.md` file if it is long. Same pull request rules as codelists.

---

# 10. Change control

- `metadata/` and `content/` live in git. Producers extend them on a branch and open a pull request; the data team reviews.
- Rows are **append-only**: no deletions, no changing an existing code or its meaning. Deprecate instead.
- Every merged change bumps `metadata/VERSION` (`MAJOR.MINOR.PATCH`, per the table in section 7) and adds a line to `metadata/CHANGELOG.md`.
- Every data file's manifest records the `metadata_version` it was produced against.
- The validator must pass before a pull request is merged or a file is published.
- Editing a CSV in Excel is fine if you save as "CSV UTF-8" and check that codes have not been turned into numbers or dates. The BOM Excel writes is expected and stripped on read.

**Structural changes** — adding, removing or reordering a column — are made by the data team only, need a new `DSD_AFW360_HH.csv` and a major version, and require the converter to backfill existing files with `_T` or `_Z`. `DSD_AFW360_HH.csv` itself has columns `position`, `id`, `role` (`dimension`, `qualifier`, `measure`, `attribute`), `codelist`, `required`, `sentinel`, `description`, and the data-file header must match it exactly.

---

# 11. Validation checks (to be implemented in Python)

**Structure**
- Header matches the DSD exactly: same names, same order (after stripping a BOM).
- No dimension or qualifier cell is empty.
- The key — all dimension and qualifier columns — is unique.

**Codes**
- Every code exists in its codelist. Newly produced rows use `ACTIVE` codes; existing rows are valid against any code that is not `DRAFT`, with `valid_from` / `valid_to` respected for geography.
- `GEO` belongs to `REF_AREA`, and its `scheme` is registered for that country.
- Breakdown slots are filled from the left in canonical order, no variable twice; unused are `_T`.
- Qualifier slots likewise, unused are `_Z`.
- `SEX` and `AGE` are `_Z` when the indicator's `stat_unit` is not `IND`, `_T` or a code otherwise.
- Breakdown variables are compatible with the indicator's `stat_unit`.
- Every qualifier used is declared by the indicator, or required by a breakdown in the same row.
- `valid_with` pairings hold, for example `POVLINE_PL420` only with `PPP_2021`.

**Coverage**
- Rows equal the set defined in 2.6: nothing missing, nothing extra.
- Nothing listed in `excluded_breakdowns` appears.
- A `SURVEYS` row and a manifest exist, and the manifest matches the file.

**Values**
- `OBS_VALUE` is numeric and within `valid_min` / `valid_max`.
- `OBS_VALUE` is empty exactly when `OBS_STATUS` is `O` or `M`.
- `STD_ERR ≥ 0` and `CI_LOWER ≤ OBS_VALUE ≤ CI_UPPER`.
- `N_OBS` is a non-negative integer and `N_POP` is non-negative. Both are present except in legacy files (6.2).
- `N_OBS = 0` implies `OBS_STATUS = O`.

**Verification rules from `checks`**
- `AGG_SUM`: children sum to the parent over a partition.
- `AGG_NPOP_MEAN`: the `N_POP`-weighted average of the children equals the parent.
- `SUM_TO_1_OVER:<QUAL_VAR>` and `SUM_TO_1_OVER_BRK`: the categories sum to 1.
- `EQUALS_NPOP_RATIO`: the value equals the child's `N_POP` over the universe's.
- `MONOTONE_IN:POVLINE`: the value does not fall as the line rises.
- `RANGE_0_1`, `RANGE_NONNEG`.
- **The parent of a row** is the same row with one breakdown set to `_T`; if that breakdown required a qualifier (`POOR` requires `POVLINE`), the qualifier is cleared to `_Z` in the parent unless the indicator itself declares it.
- Children's `N_POP` sums to the parent's for any `partition = Y` breakdown.
- Tolerances are relaxed for manifests with `precision = ROUNDED_2DP`.

**Assets**
- Every `geo_code` in a geometry layer exists in `CL_GEO` with the same `ref_area` and `scheme`.
- Every `CL_GEO` code whose scheme has `has_geometry = Y` has a geometry; schemes with `N` are skipped.
- Geometries are valid, unique per code, in EPSG:4326.
- Every registry row points at a file that exists, with a matching `sha256`.

**Text**
- Every `{{…}}` reference resolves to exactly one observation.
- Exactly one of `body` and `file` is filled, and referenced files exist.
- Every slot the dashboard requests exists for the country and year, or inherits from `ALL`.

**Metadata files**
- Codes are unique and follow 5.1.
- Every **R** column is filled.
- Every `var_code`, `parent`, `replaced_by`, `source_id`, `scheme` and `nests_in` reference resolves.
- `slot_order` values are unique within `CL_BRK_VAR` and within `CL_QUAL_VAR`; ties, if any, are broken alphabetically rather than rejected.

---

# 12. Open decisions

1. **Age cutoff for household heads.** The current `Youth_HH` / `Older_HH` boundary is undocumented; confirm it before publishing any `HHH_AGE_*` code.
2. **Quintile definition.** National or within-area ranking, person- or household-weighted. The answer goes in `CL_BRK_VAR.definition_en`.
3. **Governance.** Who owns `metadata/` and reviews pull requests.
4. **GNB survey metadata.** `About_GNB.txt` contains only a placeholder, so the round and its `TIME_PERIOD` are unknown.
5. **Where large binaries live.** Git, Git LFS, or an external store referenced from `GEO_SOURCES.csv`.
6. **Boundary vintage policy.** Who decides when to adopt a new COD-AB release, given that P-codes can change and older data must still resolve.

---

# Appendix A. Mapping the current tables

The full mapping goes in `plans/LEGACY_LABELS.csv`, with columns `legacy_label`, `sheet`, `INDICATOR`, `MEASURE_QUAL_1…5`, `notes`. It must cover all four sheets, including the `Departement` sheet's raw-variable labels (`npoor300`, `npoor420`, `(max) con_1` … `con_15`, `(max) ext_emp`).

## A.1 Indicators

| Current label | `INDICATOR` | Qualifiers | Note |
|---|---|---|---|
| Poor at $3.00/day (2021 PPP) | `POV_HC` | `POVLINE_PL300`, `PPP_2021` | |
| Poor at $4.20/day (2021 PPP) | `POV_HC` | `POVLINE_PL420`, `PPP_2021` | |
| Number poor $4.20/day (millions) | `POV_NUM` | `POVLINE_PL420`, `PPP_2021` | Store 6520000; `display_as = MILLIONS` |
| COICOP 1: food & non-alc. beverages (share) | `CONS_SH` | `COICOP_CP01` | |
| Food consumption share | `CONS_SH` | `COICOP_CP01` | Same series; not a second code |
| Housing & utilities burden (COICOP 4 …) | `CONS_SH` | `COICOP_CP04` | Same series as COICOP 4 |
| Employed (activ12m, 15–64) | `POP_SH` | — | Breakdown `EMP_STATUS_EMPLOYED`; universe persons 15–64; `ref_period = P12M` |
| Employed in agriculture (% of employed) | `POP_SH` | — | Breakdown `EMP_SECTOR_AGR`; universe employed 15–64 |
| HH has 0 / 1 / 2 / 3 / 4+ HE | `POP_SH` | — | Breakdown `HE_COUNT_0` … `HE_COUNT_4P` |
| HE profits (FCFA) | `HE_PROFIT` | — | Unit `LCU` (`XOF` via `CL_AREA`); may be negative; period to confirm |
| Monthly electricity spend (FCFA) | `EN_ELEC_SPEND` | — | Unit `LCU`, `unit_time = MONTH` |
| Access to electricity (grid, SDG 7.1.1) | `EN_ELEC_ACCESS` | — | `sdg_indicator` 7.1.1; `related` must distinguish it from `EN_GRID_CONN` and `EN_GRID_USE` |
| Average outage duration (code) | `EN_OUTAGE_DUR_CODE` | — | Mean of an ordinal code; consider replacing with shares by duration class |
| wood_dist [ALL MISSING] | not registered | | `DRAFT` until computed |

## A.2 The `Departement` sheet

Its labels are taken at face value: "Poor at $3.00/day (2017 PPP)" maps to `POVLINE_PL300` + `PPP_2017`, which is why that pair is allowed in 4.1. Its geography is whichever admin scheme the sheet actually holds — `ADM1` or `ADM2` depending on the country — and is recorded as such in `LEGACY_LABELS.csv`.

## A.3 Columns to dimensions

| Current column | New dimensions |
|---|---|
| `estimateTotal` | all `_T` |
| `estimateCapital`, `estimateOther_Urban`, `estimateRural` | `URBANISATION` = `CAP`, `OU`, `R` |
| `estimateFemale_HH`, `estimateMale_HH` | `COMP_BREAKDOWN_1` = `HHH_SEX_F`, `HHH_SEX_M` |
| `estimateYouth_HH`, `estimateOlder_HH` | `COMP_BREAKDOWN_1` = `HHH_AGE_LT35`, `HHH_AGE_GE35` (cutoff to be confirmed) |
| `estimateQ1` … `estimateQ5` | `COMP_BREAKDOWN_1` = `QUINT_Q1` … `QUINT_Q5` |
| `ADM 1` sheet columns | `GEO` = P-code, scheme `ADM1` (`DAKAR` → `SN01`, `SAB` → `GW08`) |
| `ZAE` sheet columns | `GEO` = zone code, scheme `ZONES` (SEN) or `AEZ` (GNB) |
