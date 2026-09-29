| Column | Status | Description |
|---|---|---|
| `ref_area` | R | SEN or GNB. |
| `sheet` | R | National, ADM 1, ZAE, or \* for all three. |
| `column` | R | Exact workbook header, or \* for every column. |
| `legacy_label` | R | Exact workbook label, or \* for every label. |
| `action` | R | WITHHOLD (row absent from the data file) or COMMENT (value kept, OBS_COMMENT added). |
| `obs_comment` | C | Required when action=COMMENT: the text written to OBS_COMMENT. |
| `reason` | R | Why the cell is overridden. |
| `evidence` | R | The value(s) or comparison that justify the override. |

: Columns of `LEGACY_OVERRIDES.csv` {#tbl-legacy-overrides}
