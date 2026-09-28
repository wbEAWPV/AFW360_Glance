| Column | Status | Description |
|---|---|---|
| `survey_id` | R | e.g. SEN_EHCVM_2021. |
| `ref_area` | R | ISO3. |
| `time_period` | R | 4-digit year. |
| `survey_name` | R | Full survey name. |
| `survey_acronym` | R | e.g. EHCVM. |
| `producer_agency` | R | e.g. ANSD. |
| `fieldwork_start` | R | YYYY-MM. |
| `fieldwork_end` | R | YYYY-MM. |
| `sample_hh` | R | Household sample size. |
| `sample_ind` | O | Individual sample size. |
| `design` | R | Stratification, stages, PSU. |
| `representative_levels` | R | Levels the design supports; advisory metadata, does not gate publication. |
| `analysis_units` | R | Which file each stat_unit is estimated from. |
| `welfare_aggregate` | R | e.g. Consumption per capita. |
| `welfare_adjustments` | R | Spatial and temporal deflation. |
| `npl_value` | C | National poverty line value. |
| `npl_currency` | C | ISO 4217. |
| `npl_unit` | C | e.g. per capita per day. |
| `npl_ref_year` | C | Price year (an inference where the source does not state one). |
| `ppp_rounds` | R | e.g. 2017 2021. |
| `microdata_ref` | O | Catalogue ID or URL. |
| `comparable_with` | O | e.g. SEN_EHCVM_2018. |
| `contact` | O | Contact person/team. |
| `notes` | O | Free text. |
| `status` | R | Added per gap resolution g; e.g. DRAFT for GNB_EHCVM_2021 pending producer confirmation of the survey round (D6). |

: Columns of `SURVEYS.csv` {#tbl-surveys}
