| Column | Status | Description |
|---|---|---|
| `legacy_label` | R | Free-text indicator label exactly as it appears in the workbook's indicator column. |
| `sheet` | R | National, ADM 1, ZAE, Departement, or \* for National+ADM 1+ZAE. |
| `action` | R | MAP, DUPLICATE_OF, DERIVED, or SKIP. |
| `series_id` | C | SERIES_PLAN.series_id; required when action=MAP. |
| `duplicate_of` | C | series_id of the MAP row this label resolves against; required when action is DUPLICATE_OF or DERIVED. |
| `scale` | C | Multiplier applied to the raw cell value to reach base units, written as a plain decimal (1 or 1000000, never 1e6); empty on rows that are not MAP. |
| `assert_rule` | C | EQUALS:\<series_id> or ONE_MINUS:\<series_id>, optionally followed by ' tol=\<number>' (default tolerance 0); required when action is DUPLICATE_OF or DERIVED. |
| `notes` | O | Free text, e.g. the hard-case ID (H1-H19) that decided this row. |

: Columns of `LEGACY_LABELS.csv` {#tbl-legacy-labels}
