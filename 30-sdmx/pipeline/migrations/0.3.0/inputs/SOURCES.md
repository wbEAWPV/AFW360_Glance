# Global codelists used for the 0.3.0 alignment

Fetched once on 2026-09-29 for `ALIGNMENT.csv` (plan section 2.9, decision D32). The migration reads `ALIGNMENT.csv` and makes no network call.

Registry lists were fetched with
`curl --ssl-no-revoke -H "Accept: application/vnd.sdmx.structure+json;version=2.0.0" <URL>`.
The World Bank list was fetched with `curl --ssl-no-revoke <URL>` (SDMX-ML 2.1 response).
The code count is the number of codes in the response.

| Global list | URL fetched | Version | Fetch date | Codes seen |
|---|---|---|---|---|
| SDMX:CL_FREQ | https://registry.sdmx.org/sdmx/v2/structure/codelist/SDMX/CL_FREQ/2.1 | 2.1 | 2026-09-29 | 34 |
| SDMX:CL_SEX | https://registry.sdmx.org/sdmx/v2/structure/codelist/SDMX/CL_SEX/2.1 | 2.1 | 2026-09-29 | 7 |
| SDMX:CL_OBS_STATUS | https://registry.sdmx.org/sdmx/v2/structure/codelist/SDMX/CL_OBS_STATUS/2.3 | 2.3 | 2026-09-29 | 23 |
| IAEG-SDGs:CL_AGE | https://registry.sdmx.org/sdmx/v2/structure/codelist/IAEG-SDGs/CL_AGE/1.25 | 1.25 | 2026-09-29 | 177 |
| IAEG-SDGs:CL_URBANISATION | https://registry.sdmx.org/sdmx/v2/structure/codelist/IAEG-SDGs/CL_URBANISATION/1.10 | 1.10 | 2026-09-29 | 5 |
| IAEG-SDGs:CL_QUANTILE | https://registry.sdmx.org/sdmx/v2/structure/codelist/IAEG-SDGs/CL_QUANTILE/1.1 | 1.1 | 2026-09-29 | 10 |
| IAEG-SDGs:CL_UNIT_MEASURE | https://registry.sdmx.org/sdmx/v2/structure/codelist/IAEG-SDGs/CL_UNIT_MEASURE/1.20 | 1.20 | 2026-09-29 | 57 |
| WB:CL_REF_AREA_WDI | https://api.worldbank.org/v2/sdmx/rest/codelist/WB/CL_REF_AREA_WDI/1.0/ | 1.0 | 2026-09-29 | 241 |

## Codes checked

- SDMX:CL_FREQ: `A` "Annual".
- SDMX:CL_SEX: `F` "Female", `M` "Male", `_T` "Total", `_Z` "Not applicable".
- SDMX:CL_OBS_STATUS: `A` "Normal value", `E` "Estimated value", `M` "Missing value; data cannot exist", `O` "Missing value", `U` "Low reliability", `D` "Definition differs", `Q` "Missing value; suppressed".
- IAEG-SDGs:CL_AGE: `Y0T14` "under 15 years old", `Y15T24`, `Y25T64`, `Y_GE65`, `_T`; no `_Z` and no `Y_LT15`.
- IAEG-SDGs:CL_URBANISATION: `U` "Urban", `R` "Rural", `_T` "Total", `CITY` "City" (not used for the project's `CAP`).
- IAEG-SDGs:CL_QUANTILE: `Q1` to `Q5` ("Quintile 1 (poorest)" to "Quintile 5 (richest)"), `_T`.
- IAEG-SDGs:CL_UNIT_MEASURE: `HA` "Hectares", `IX` "Index", `CUR_LCU` "Local currency", `NUMBER` "Number"; `CON_PPP_USD` exists but is not aligned (review Q5); no ISO 4217 code such as `XOF`.
- WB:CL_REF_AREA_WDI: `SEN` "Senegal", `GNB` "Guinea-Bissau".

## Reading ALIGNMENT.csv

One row per code that is renamed, given a new name, added, or given a `global_urn`. `code_0_2_0` is empty for a code added in 0.3.0. `name_en` and `definition_en` hold the 0.3.0 name and definition when new or changed; an empty `name_en` or `definition_en` means "keep the 0.2.0 value", and an added code fills both (the `CL_FREQ` definition comes from `CL_FREQ.csv`). `global_urn` is empty when no global code matches. `CL_UNIT_MEASURE` rows refer to the list named `CL_UNIT` in 0.2.0.
