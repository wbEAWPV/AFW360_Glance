| Column | Status | Description |
|---|---|---|
| `series_id` | R | Stable identifier for one indicator x qualifier-set x defining-breakdown combination. |
| `ref_area` | R | ISO3, or ALL. |
| `INDICATOR` | R | CL_INDICATOR code. |
| `MEASURE_QUALS` | C | Space-separated CL_QUALIFIER codes for this series; empty if none. |
| `DEFINING_BREAKDOWN` | C | The CL_BRK_VAR category this series is implicitly about (e.g. HE_COUNT_0 for row 53); empty if none. |
| `name_en` | R | Display name of the series for charts and reports, composed from the indicator's short_name_en and the qualifier and category names; a human may overwrite it. |
| `estimation` | R | File kinds in which the series is expected: SURVEY, MODEL, or both, space-separated (CL_ESTIMATION). |
| `status` | R | DRAFT, ACTIVE, NOT_PRODUCED or DEVIATES; the last two only on a row for a specific ref_area, with notes, overriding the ALL row for the same series_id. |
| `notes` | O | Free text, e.g. provenance of a hard-case decision (H-number). |

: Columns of `SERIES_PLAN.csv` {#tbl-series-plan}
