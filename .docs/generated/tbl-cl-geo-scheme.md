| Column | Status | Description |
|---|---|---|
| `code` | R | The code itself; uppercase ASCII, digits, _; starts with a letter; \<=32 chars. |
| `name_en` | R | Short English name. |
| `definition_en` | R | Full English definition; required where a boundary is not obvious (age cutoffs, groupings, ranking rules). |
| `status` | R | DRAFT, ACTIVE or DEPRECATED. |
| `version_added` | R | metadata/VERSION value at which the code was added. |
| `replaced_by` | C | Required when status=DEPRECATED: the code that replaces it. |
| `notes` | O | Free text. |
| `ref_area` | R | Country (keyed with code). |
| `local_name_en` | R | What that level is called in the country, in English. |
| `has_geometry` | R | Y only for ADM0 and ADM1. |
| `nests_in` | O | Another scheme, only where nesting is genuine; roll-up checks only, never used to derive geometry. |
| `partition` | R | Y if its units cover the country exactly once. |

: Columns of `CL_GEO_SCHEME.csv` {#tbl-cl-geo-scheme}
