| # | Component | Type | Role | Codelist | Data type | Usage | Relationship | Sentinels | Required | Description |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `FREQ` | dimension | reference | `CL_FREQ` |  |  |  |  | R | Frequency of the observation; always A (annual) (D34). |
| 2 | `REF_AREA` | dimension | breakdown | `CL_AREA` |  |  |  |  | R | Country the estimate refers to: a CL_AREA code (ISO 3166-1 alpha-3). |
| 3 | `GEO` | dimension | breakdown | `CL_GEO` |  |  |  | `_T` | R | Subnational area: a CL_GEO code, or _T for the whole country. |
| 4 | `ESTIMATION` | dimension | reference | `CL_ESTIMATION` |  |  |  |  | R | How the value was produced: SURVEY or MODEL (D17). |
| 5 | `INDICATOR` | dimension | qualifier | `CL_INDICATOR` |  |  |  |  | R | The indicator measured: a CL_INDICATOR code. |
| 6 | `SEX` | dimension | breakdown | `CL_SEX` |  |  |  | `_T` `_Z` | R | Sex of the individual counted: a CL_SEX code, _T, or _Z. |
| 7 | `AGE` | dimension | breakdown | `CL_AGE` |  |  |  | `_T` `_Z` | R | Age band of the individual counted: a CL_AGE code, _T, or _Z. |
| 8 | `URBANISATION` | dimension | breakdown | `CL_URBANISATION` |  |  |  | `_T` | R | Urban or rural area of residence: a CL_URBANISATION code or _T. |
| 9 | `COMP_BREAKDOWN_1` | dimension | breakdown | `CL_COMP_BREAKDOWN` |  |  |  | `_T` | R | Breakdown slot 1 of 5, filled left to right in slot_order; a CL_COMP_BREAKDOWN code or _T. |
| 10 | `COMP_BREAKDOWN_2` | dimension | breakdown | `CL_COMP_BREAKDOWN` |  |  |  | `_T` | R | Breakdown slot 2 of 5, filled left to right in slot_order; a CL_COMP_BREAKDOWN code or _T. |
| 11 | `COMP_BREAKDOWN_3` | dimension | breakdown | `CL_COMP_BREAKDOWN` |  |  |  | `_T` | R | Breakdown slot 3 of 5, filled left to right in slot_order; a CL_COMP_BREAKDOWN code or _T. |
| 12 | `COMP_BREAKDOWN_4` | dimension | breakdown | `CL_COMP_BREAKDOWN` |  |  |  | `_T` | R | Breakdown slot 4 of 5, filled left to right in slot_order; a CL_COMP_BREAKDOWN code or _T. |
| 13 | `COMP_BREAKDOWN_5` | dimension | breakdown | `CL_COMP_BREAKDOWN` |  |  |  | `_T` | R | Breakdown slot 5 of 5, filled left to right in slot_order; a CL_COMP_BREAKDOWN code or _T. |
| 14 | `MEASURE_QUAL_1` | dimension | qualifier | `CL_QUALIFIER` |  |  |  | `_Z` | R | Qualifier slot 1 of 5, filled left to right in slot_order; a CL_QUALIFIER code or _Z. |
| 15 | `MEASURE_QUAL_2` | dimension | qualifier | `CL_QUALIFIER` |  |  |  | `_Z` | R | Qualifier slot 2 of 5, filled left to right in slot_order; a CL_QUALIFIER code or _Z. |
| 16 | `MEASURE_QUAL_3` | dimension | qualifier | `CL_QUALIFIER` |  |  |  | `_Z` | R | Qualifier slot 3 of 5, filled left to right in slot_order; a CL_QUALIFIER code or _Z. |
| 17 | `MEASURE_QUAL_4` | dimension | qualifier | `CL_QUALIFIER` |  |  |  | `_Z` | R | Qualifier slot 4 of 5, filled left to right in slot_order; a CL_QUALIFIER code or _Z. |
| 18 | `MEASURE_QUAL_5` | dimension | qualifier | `CL_QUALIFIER` |  |  |  | `_Z` | R | Qualifier slot 5 of 5, filled left to right in slot_order; a CL_QUALIFIER code or _Z. |
| 19 | `TIME_PERIOD` | time_dimension | reference |  | GregorianYear |  |  |  | R | 4-digit year the estimate refers to. |
| 20 | `OBS_VALUE` | measure | measure |  | Double | mandatory |  |  | C | Number, unrounded, in base units; NaN when OBS_STATUS is O or M (D39). |
| 21 | `STD_ERR` | measure | measure |  | Double, min 0 | optional |  |  | C | Standard error of OBS_VALUE; required on PRODUCER-source rows where CL_STATISTIC.admits_se = Y. |
| 22 | `CI_LOWER` | measure | measure |  | Double | optional |  |  | C | Lower bound of the 95% confidence interval; required where STD_ERR is. |
| 23 | `CI_UPPER` | measure | measure |  | Double | optional |  |  | C | Upper bound of the 95% confidence interval; required where STD_ERR is. |
| 24 | `N_OBS` | measure | measure |  | Integer, min 0 | optional |  |  | C | Unweighted number of records; required on PRODUCER-source rows; on a share row, the denominator's records (D19). |
| 25 | `N_POP` | measure | measure |  | Double, min 0 | optional |  |  | C | Weighted population the estimate represents; required on PRODUCER-source rows; on a share row, the denominator's population (D19). |
| 26 | `N_OBS_NUM` | measure | measure |  | Integer, min 0 | optional |  |  | C | Unweighted number of records in the numerator of a share; required where STD_ERR is (D33). |
| 27 | `DEFF` | measure | measure |  | Double, min 0 | optional |  |  | O | Design effect of the estimate: its sampling variance relative to simple random sampling (D33). |
| 28 | `DF` | measure | measure |  | Integer, min 0 | optional |  |  | O | Degrees of freedom of the variance estimate (D33). |
| 29 | `SERIES_ID` | attribute | attribute | `CL_SERIES` |  | mandatory | `INDICATOR` `COMP_BREAKDOWN_1` `COMP_BREAKDOWN_2` `COMP_BREAKDOWN_3` `COMP_BREAKDOWN_4` `COMP_BREAKDOWN_5` `MEASURE_QUAL_1` `MEASURE_QUAL_2` `MEASURE_QUAL_3` `MEASURE_QUAL_4` `MEASURE_QUAL_5` |  | R | CL_SERIES code (SERIES_PLAN.series_id); agrees with INDICATOR, qualifiers and defining category (D13). |
| 30 | `UNIT_MEASURE` | attribute | attribute | `CL_UNIT_MEASURE` |  | mandatory | `REF_AREA` `INDICATOR` |  | R | CL_UNIT_MEASURE code; an ISO 4217 code from CL_AREA.currency where the indicator's unit_measure is LCU (D14). |
| 31 | `PRECISION` | attribute | attribute |  | Double, min 0 | optional | observation |  | C | Rounding unit of OBS_VALUE in base units; empty when exact; required on rows of a LEGACY_CONVERSION source (D15). |
| 32 | `OBS_STATUS` | attribute | attribute | `CL_OBS_STATUS` |  | mandatory | observation; measure `OBS_VALUE` |  | R | CL_OBS_STATUS code; one code per row, precedence M O E D U A (D22). |
| 33 | `SOURCE_ID` | attribute | attribute | `CL_SOURCE` |  | mandatory | observation |  | R | CL_SOURCE code (SOURCES.source_id), the program run that produced the row (D16). |
| 34 | `OBS_COMMENT` | attribute | attribute |  | String | optional | observation |  | O | Free text, English; LEGACY_EMPTY: prefix required on O rows of a LEGACY_CONVERSION source (D9). |

: Components of the `DSD_AFW360_HH` data structure, in data-file order {#tbl-columns}
