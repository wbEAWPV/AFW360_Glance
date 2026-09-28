| Column | Status | Description |
|---|---|---|
| `rule_id` | R | Unique id of the rule: \<scope_code or AFW360_HH>.\<rule>\[.\<param>\], e.g. POV_HC.MONOTONE_IN.POVLINE. |
| `scope` | R | What the rule applies to: DATAFLOW (every row), INDICATOR (every series of one indicator) or SERIES (one series). |
| `scope_code` | C | The indicator code or series_id the rule applies to; empty when scope is DATAFLOW. |
| `rule` | R | The rule from the vocabulary: RANGE_0_1, RANGE_NONNEG, AGG_SUM, AGG_NPOP_MEAN, AGG_BRACKET, SUM_TO_1_OVER, SUM_TO_1_OVER_BRK, MONOTONE_IN, RELIABILITY_MIN_NOBS or RELIABILITY_MAX_CV. |
| `param` | C | The rule's argument: the qualifier variable for SUM_TO_1_OVER and MONOTONE_IN, the threshold for the two RELIABILITY rules; empty otherwise. |
| `tolerance` | O | Absolute tolerance that overrides the validator's default, computed from each row's PRECISION; empty to use the default. |
| `severity` | R | ERROR (the file fails validation) or WARN (reported only). |
| `status` | R | DRAFT, ACTIVE or DEPRECATED. |
| `version_added` | R | metadata/VERSION value at which the row was added. |
| `notes` | O | Free text. |

: Columns of `RULES.csv` {#tbl-rules}
