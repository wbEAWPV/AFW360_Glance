| Column | Status | Description |
|---|---|---|
| `describes` | R | Whose characteristic: IND, HHH, HH, HE. |
| `applies_to_units` | R | stat_unit values it may break down, e.g. HH IND HE. |
| `universe` | R | The population its categories partition. |
| `classification` | O | ISIC Rev.4, ISCED 2011, ISCO-08, etc. |
| `partition` | R | Y if categories are mutually exclusive and cover the universe. |
| `requires_qual` | C | Qualifier variables the categories depend on, e.g. POVLINE PPP for POOR. |
| `slot_order` | R | Integer, spaced by 10; ties break alphabetically by var_code. |
| `owner` | R | Team or person responsible. |

: Columns of `CL_BRK_VAR.csv`, beyond the common ones {#tbl-cl-brk-var}
