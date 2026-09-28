| Column | Status | Description |
|---|---|---|
| `ref_area` | R | SEN or GNB. |
| `sheet` | R | National, ADM 1, ZAE or Departement. |
| `column` | R | Exact workbook header, e.g. estimateFemale_HH. |
| `cut_id` | C | TAB_PLAN.cut_id this column belongs to; empty on SKIP rows. |
| `GEO` | C | GEO code this column maps to, for ADM 1 / ZAE columns. |
| `URBANISATION` | C | URBANISATION code this column maps to, for National urban/rural columns. |
| `COMP_BREAKDOWN` | C | COMP_BREAKDOWN code this column maps to, for National group columns. |
| `action` | R | MAP, or SKIP for every Departement column (D3). |
| `notes` | O | Free text. |

: Columns of `LEGACY_COLUMNS.csv` {#tbl-legacy-columns-csv}
