| Column | Status | Description |
|---|---|---|
| `qualifier` | R | CL_QUALIFIER category whose partners are restricted, e.g. POVLINE_PL300. |
| `with_var` | R | CL_QUAL_VAR code of the partner qualifier variable, e.g. PPP. |
| `allowed` | R | Space-separated categories of with_var that may appear with the qualifier, or _Z when it takes none, which overrides with_var being required. |
| `status` | R | DRAFT, ACTIVE or DEPRECATED. |
| `version_added` | R | metadata/VERSION value at which the row was added. |
| `notes` | O | Free text. |

: Columns of `QUALIFIER_PAIRS.csv` {#tbl-qualifier-pairs}
