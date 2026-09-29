| Column | Status | Description |
|---|---|---|
| `source_id` | R | Unique id of the program run, following the code rules, e.g. SEN_EHCVM2021_LEGACY_v1; a new run gets a higher _v\<N>. |
| `kind` | R | LEGACY_CONVERSION for a converter run over a legacy workbook, PRODUCER for a producer's own estimation program. |
| `ref_area` | R | CL_AREA code of the country whose rows the run produced. |
| `survey_id` | R | SURVEYS.survey_id of the survey the run is based on, also for a model-based run. |
| `program` | R | The program that produced the rows: a repository path or the producer's program name. |
| `program_version` | R | Git commit or release of the program at the run. |
| `producer` | R | Team or agency that ran the program. |
| `software` | R | Software and version the program ran on, e.g. R 4.5.3 or Stata 18. |
| `run_date` | R | ISO 8601 date the program ran. |
| `inputs` | R | Space-separated files or datasets the run read. |
| `inputs_sha256` | C | Space-separated SHA-256 checksums of the inputs, in the same order, where they are files in this repository. |
| `status` | R | DRAFT, ACTIVE or DEPRECATED. |
| `version_added` | R | metadata/VERSION value at which the row was added. |
| `notes` | O | Free text. |

: Columns of `SOURCES.csv` {#tbl-sources}
