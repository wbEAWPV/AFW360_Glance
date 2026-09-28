| Column | Status | Description |
|---|---|---|
| `short_name_en` | R | \<=40 characters, for chart labels. |
| `theme` | R | CL_THEME. |
| `stat_unit` | R | CL_STAT_UNIT: what is counted. |
| `universe_unit` | R | The unit forming the denominator. |
| `universe_filter` | C | Restriction in words; empty means all units. |
| `numerator` | C | For shares and ratios: the units in the breakdown category. |
| `statistic` | R | CL_STATISTIC. |
| `weight` | R | CL_WEIGHT. |
| `ref_period` | R | ISO 8601 duration (P7D, P12M, P3Y) or INTERVIEW; always P12M, never P1Y. |
| `excluded_breakdowns` | O | Breakdown variables or categories outside its universe; must not be produced. |
| `unit_measure` | R | CL_UNIT. |
| `unit_denom` | C | What the value is per, for levels. |
| `unit_time` | C | DAY, MONTH, YEAR, for flows. |
| `price_basis` | C | NOMINAL or DEFLATED, for money. |
| `price_ref_year` | C | Required when price_basis=DEFLATED. |
| `display_as` | R | PERCENT, NUMBER, THOUSANDS, MILLIONS, CURRENCY. |
| `decimals` | R | Decimals to display. |
| `valid_min` | C | Plausible minimum; empty means unbounded (gap i). |
| `valid_max` | C | Plausible maximum; empty means unbounded (gap i). |
| `higher_is` | R | BETTER, WORSE or NEUTRAL: colour direction on maps. |
| `sdg_indicator` | O | SDG indicator code, if any. |
| `classification` | O | COICOP2018, ISIC4:A, etc. |
| `related` | O | Codes of close indicators, space-separated. |
| `related_note` | O | How this indicator differs from the related ones. |
| `source_questionnaire` | R | Survey module or section. |
| `source_vars` | R | Harmonized microdata variables used. |
| `program` | R | Program that computes it. |
| `owner` | R | Team or person responsible. |

: Columns of `CL_INDICATOR.csv`, beyond the common ones {#tbl-cl-indicator}
