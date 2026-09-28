| Column | Status | Description |
|---|---|---|
| `ref_area` | R | Country. |
| `scheme` | R | CL_GEO_SCHEME.code for that country. |
| `parent` | C | Containing unit, only when nests_in is set. |
| `source_id` | C | GEO_SOURCES.csv key; required when has_geometry=Y. |
| `geom_layer` | C | Layer holding the polygon (adm0/adm1); empty for schemes with no geometry. |
| `valid_from` | R | Boundary vintage the code belongs to (not data validity). |
| `valid_to` | C | Empty while current. |

: Columns of `CL_GEO.csv`, beyond the common ones {#tbl-cl-geo}
