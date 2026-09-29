| Column | Status | Description |
|---|---|---|
| `cut_id` | R | e.g. ADM1, QUINT. |
| `ref_area` | R | ISO3, or ALL. |
| `geo_scheme` | R | _T, or a CL_GEO_SCHEME code. |
| `urbanisation` | R | _T, or a set such as CAP OU R or U R. |
| `sex` | R | _T, or F M. |
| `age` | R | _T, or a set of CL_AGE codes. |
| `comp_breakdowns` | C | Breakdown variable codes in slot order, e.g. QUINT HHH_SEX. |
| `themes` | R | ALL, or a list of CL_THEME codes. |
| `status` | R | ACTIVE or DRAFT; every row is DRAFT in this transition. |

: Columns of `TAB_PLAN.csv` {#tbl-tab-plan}
