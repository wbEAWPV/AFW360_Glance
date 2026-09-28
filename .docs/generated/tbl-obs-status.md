| Code | Meaning | Definition |
|---|---|---|
| `A` | Normal value | A normal value. |
| `E` | Model-based value | A model-based value: a projection, nowcast or microsimulation. |
| `O` | No value available | No value is available; the value is empty. |
| `M` | Not applicable | The cell is outside the indicator's universe by definition; the value is empty. |
| `U` | Low reliability | The value rests on fewer records than RELIABILITY_MIN_NOBS or its coefficient of variation exceeds RELIABILITY_MAX_CV (RULES.csv). Written by the producer and recomputed by the validator; the value is published, not hidden. |
| `D` | Definition differs | The series is produced for this country under a definition that departs from the dictionary's; SERIES_PLAN.csv carries the country's row with status DEVIATES and the reason. |
| `Q` | Suppressed | Reserved: a value withheld under a confidentiality rule. Not used; the database publishes every estimate. |

: Observation status codes {#tbl-obs-status}
