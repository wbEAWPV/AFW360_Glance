| Column | Status | Description |
|---|---|---|
| `indicator` | R | CL_INDICATOR code of the indicator that takes the qualifier variable. |
| `qual_var` | R | CL_QUAL_VAR code of the qualifier variable the indicator takes; one row per indicator and variable. |
| `allowed` | R | \* for any category of the variable, or the space-separated CL_QUALIFIER categories the indicator may use. |
| `status` | R | DRAFT, ACTIVE or DEPRECATED. |
| `version_added` | R | metadata/VERSION value at which the row was added. |
| `notes` | O | Free text. |

: Columns of `INDICATOR_QUALIFIERS.csv` {#tbl-indicator-qualifiers}
