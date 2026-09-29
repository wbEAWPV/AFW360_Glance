# SDMX global codelists, cross-domain concepts, and the World Bank as an SDMX agency

Researched 2026-09-29. All registry.sdmx.org calls used `Accept: application/vnd.sdmx.structure+json;version=2.0.0` against the SDMX REST v2 path `https://registry.sdmx.org/sdmx/v2/structure/...`; the legacy v1 path `https://registry.sdmx.org/ws/public/sdmxapi/rest/...` also works (verified) and is what the v2 responses link to internally.

## 1. Global codelists maintained by agency `SDMX`

Full list of agency **SDMX**'s codelists (`GET /sdmx/v2/structure/codelist/SDMX/all/latest?detail=allstubs`, 200 OK, 28 codelists):

| ID | Version | Name |
|---|---|---|
| CL_ACTIVITY_ANZSIC06 | 1.0 | Activity - ANZSIC 2006 |
| CL_ACTIVITY_ISIC4 | 1.0 | Activity - ISIC, Revision 4 |
| CL_ACTIVITY_NACE2 | 1.0 | Activity - NACE, Revision 2 |
| CL_ACTIVITY_NACE2_1 | 1.0 | Activity - NACE, Revision 2.1 |
| CL_AGE | 1.0 | Age |
| CL_AREA | 2.0.1 | Reference area code list |
| CL_BREAK_REASON | 1.0 | Reason for the break in time series |
| CL_CIVIL_STATUS | 1.0 | Civil (or Marital) Status |
| CL_COFOG_1999 | 1.0 | Classification of the Functions of Government |
| CL_COICOP_1999 | 1.1 | COICOP, 1999 revision |
| CL_COICOP_2018 | 1.0 | COICOP, 2018 revision |
| CL_CONF_STATUS | 1.4 | Confidentiality Status |
| CL_COPNI_1999 | 1.0 | Classification of Purposes of Non-Profit Institutions |
| CL_COPP_1999 | 1.0 | Classification of Outlays of Producers by Purpose |
| CL_DECIMALS | 1.0 | Decimals |
| CL_DEG_URB | 1.0 | Code list for degree of urbanisation |
| CL_FREQ | 2.1 | Frequency |
| CL_OBS_STATUS | 2.3 | Observation Status |
| CL_OCCUPATION | 1.0 | Occupation |
| CL_SEASONAL_ADJUST | 1.0 | Seasonal Adjustment |
| CL_SEX | 2.1 | Sex |
| CL_STATISTICAL_OPERATION | 1.0 | Statistical operation |
| CL_TIMETRANS | 1.0 | Time Transformation |
| CL_TIMETRANS_PER | 1.0 | Time Transformation Period |
| CL_TIMETRANS_TYPE | 1.0 | Time Transformation Type |
| CL_TIME_FORMAT | 1.0 | Time Format |
| CL_TIME_PER_COLLECT | 1.0 | Time Period - Collection |
| CL_UNIT_MULT | 1.1 | Unit Multiplier |

**Not present under agency SDMX**: `CL_UNIT_MEASURE` (direct fetch → 404 `No Results Found`) and `CL_EDUCATION_LEV` (404) and a bare `CL_ACTIVITY` (404). A plain `CL_ACTIVITY` never existed at agency SDMX — only classification-specific variants (ISIC4/NACE2/ANZSIC06) exist there. UNIT_MEASURE and EDUCATION_LEV exist as concepts (see §2) but their global enumerations live at agency **IAEG-SDGs**, not SDMX (see §5/§6).

### Codes for the requested codelists

**CL_SEX** (v2.1, agency SDMX) — 7 codes:
`F`=Female, `M`=Male, `_N`=Non response, `_O`=Other, `_T`=Total, `_U`=Unknown, `_Z`=Not applicable.
Reserved codes present: `_T`, `_U`, `_O` all present with the expected meaning; `_Z` also present ("Not applicable"); `_X` is **not** in this list (SDMX's CL_SEX uses `_N` for non-response instead, where other schemes use `_X`).

**CL_AGE** (v1.0, agency SDMX) — 5 codes, and it is *not* an age-group list. It enumerates the time units used to express age as an ISO 8601 duration facet: `Y`=Year(s), `M`=Month(s), `W`=Week(s), `D`=Day(s), `H`=Hour(s). There are no age-band codes (0-4, 5-9, etc.) at agency SDMX — those live in IAEG-SDGs `CL_AGE` (see §5).

**CL_OBS_STATUS** (v2.3, agency SDMX) — 23 codes, e.g. `A`=Normal value, `B`=Time series break, `E`=Estimated value, `F`=Forecast value, `M`=Missing value; data cannot exist, `O`=Missing value, `P`=Provisional value, `U`=Low reliability, `V`=Unvalidated value, `X`=Observation status unavailable from external organisation, `_U`=Unknown, plus 12 more missing/derogation/strike-event variants. Only `_U` of the reserved set appears (no `_T`, `_Z`, `_O`, `_X` as generic reserved codes — `X` here is a specific status meaning, not the generic "not applicable" marker).

**CL_UNIT_MEASURE**: no such codelist at agency SDMX (404). See IAEG-SDGs `CL_UNIT_MEASURE` in §5.

**Urban/rural — CL_DEG_URB** (v1.0, agency SDMX) — 14 codes: `_T`=Total, `URB`=Urban area, `CITY`=City, `TSUB`=Town and semi-dense area, `DTOW`=Dense town, `STOW`=Semi-dense town, `SUBU`=Suburban/peri-urban area, `RUR`=Rural area, `VILL`=Village, `DISP`=Dispersed rural area, `UNIN`=Mostly uninhabited area, `_O`=Other, `_U`=No data/unknown, `_Z`=Not applicable. Reserved codes `_T`, `_O`, `_U`, `_Z` all present with the standard meanings; `_X` absent.

There is a **second, competing** degree-of-urbanisation list at agency IAEG-SDGs: `CL_URBANISATION` (v1.10) — much shorter, 5 codes: `_T`=Total, `U`=Urban, `R`=Rural, `CITY`=City, `TSUB`=Town and semi-dense area. Codes for "urban"/"rural" differ (`URB`/`RUR` at SDMX vs `U`/`R` at IAEG-SDGs) — these are not interchangeable; pick one and stick to it.

Source: `https://registry.sdmx.org/sdmx/v2/structure/codelist/SDMX/<ID>/latest`.

## 2. Cross-domain concept scheme

`GET /sdmx/v2/structure/conceptscheme/SDMX/CROSS_DOMAIN_CONCEPTS/latest` → 200 OK.

- id: **CROSS_DOMAIN_CONCEPTS**, agency **SDMX**, version **2.0**, name "SDMX Cross Domain Concept Scheme", **229 concepts**.
- Confirmed presence of all concepts named in the brief: `REF_AREA` (Reference area), `TIME_PERIOD` (Time period), `OBS_VALUE` (Observation value), `OBS_STATUS` (Observation status), `UNIT_MEASURE` (Unit of measure), `UNIT_MULT` (Unit multiplier), `DECIMALS` (Decimals), `COMMENT` (Comment), `FREQ` (Frequency of observation), `SEX` (Sex), `AGE` (Age), plus `EDUCATION_LEV` (Education level), `ACTIVITY` (Economic activity), `OCCUPATION` (Occupation), `CIVIL_STATUS` (Civil status), `CONF_STATUS` (Confidentiality - status), `TIME_FORMAT` (Time format), `COUNTERPART_AREA`, `CURRENCY`, `INDICATOR` (Statistical indicator), `DATA_SOURCE`, and many quality/metadata-governance concepts (RELEVANCE, ACCURACY, COHERENCE, TIMELINESS, etc.) not relevant to this dashboard.
- Note: the concept scheme defines *concepts* (IDs + names + descriptions), not their representation (codelist). Which codelist backs a concept (e.g. `SEX` → `CL_SEX`) is decided by whoever builds a DSD using the concept; COG (see §5/§6) gives the recommended pairing.

Source: `https://registry.sdmx.org/sdmx/v2/structure/conceptscheme/SDMX/CROSS_DOMAIN_CONCEPTS/latest`.

## 3. The World Bank as an SDMX agency

`GET /sdmx/v2/structure/agencyscheme/SDMX/AGENCIES/latest` → 200 OK. This is the **only** agency scheme registered (`GET /sdmx/v2/structure/agencyscheme/*/*/*` returns exactly one scheme, `SDMX:AGENCIES(1.0)`). It lists 21 agencies, i.e. this is a curated top-level list of registry participants, not a global directory of every national statistical office.

The World Bank's exact agency ID is **`WB`** — `{"id":"WB","name":"World Bank (WB)"}`. No `WB_WDI`, `WB.AFW` or other WB variant/sub-agency appears in this scheme. Other agencies of note in the same 21-item list: `IMF`, `ESTAT`, `UIS`, `OECD`, `ILO`, `UNSD`, `IAEG-SDGs`, `BIS`, `ECB`, `STATSNZ`, and — relevant to this project — **`GW_INE`** ("National Statistical Institute of Guinea-Bissau — Instituto Nacional de Estatística da Guiné-Bissau"), already registered as its own agency. No Senegal NSO (e.g. ANSD) is registered in this scheme.

Querying the registry for artefacts maintained *by* `WB` came back empty: `GET /sdmx/v2/structure/codelist/WB/all/latest` → 404 "No Results Found", and `GET /sdmx/v2/structure/dataflow/WB/all/latest` → 404. So the World Bank is a registered agency ID, but has not published any codelists/dataflows into the **SDMX Global Registry** itself (its structures live on its own endpoints — see §4).

**Hierarchical sub-agencies**: per SDMX's own registry model (confirmed via web search of SDMX registry/agency-scheme documentation), "An Agency in an Agency Scheme can set up a sub agency scheme... the agencies in the agency scheme are deemed to be sub agencies of the maintenance agency of the scheme in which they reside," and agency IDs commonly use dot notation (example given: `int.ddi` with sub-agency `int.ddi.cv`). So a hierarchical ID like `WB.AFW` is structurally allowed by the SDMX information model — but it requires the **World Bank itself** (as the agency already registered as `WB`) to create and register its own sub-agency scheme in the registry; the SDMX Secretariat/registry only registers the top-level `WB` entry, not sub-agencies under it. Nothing under `WB.*` currently exists in the registry.

Sources: `https://registry.sdmx.org/sdmx/v2/structure/agencyscheme/SDMX/AGENCIES/latest`; SDMX registry wiki/spec pages found via web search (`wiki.registry.sdmx.org`, SDMX Registry Specification PDF).

## 4. World Bank Data360

Two separate World Bank SDMX-ish surfaces exist; they are **not the same system**:

### 4a. `api.worldbank.org/v2/sdmx/rest` (the older "DDP" SDMX-ML 2.1 service, WDI only)
`GET https://api.worldbank.org/v2/sdmx/rest/dataflow` → 200 OK, SDMX-ML. Lists two dataflows: `UNSD:SDG(1.0)` and **`WB:WDI(1.0)`** ("World Development Indicators"). Fetching the DSD (`GET https://api.worldbank.org/v2/sdmx/rest/datastructure/WB/WDI/1.0/?references=all` — note: trailing slash required, otherwise 307-redirects to `dataapi.worldbank.org`) → 200 OK, 493 KB.

- DSD `WB:WDI(1.0)` dimensions in order: **`FREQ`** (pos 1) → **`SERIES`** (pos 2, the indicator code) → **`REF_AREA`** (pos 3) → **`TIME_PERIOD`** (pos 4, time dimension). Attribute: `UNIT_MULT` (mandatory). Measure: `OBS_VALUE`.
- No slot-style generic dimensions here, and no SEX/AGE/URBANISATION dimensions — WDI's DSD is the classic "one indicator dimension encodes everything" pattern.
- Bundled codelist `WB:CL_REF_AREA_WDI(1.0)` uses **ISO 3166-1 alpha-3** codes (`AFG`, `ALB`, `DZA`, ... same convention as this project's `data_raw/tables/Tables_<ISO3>.xlsx`). Bundled `WB:CL_FREQ_WDI(1.0)`: `A`, `2A`, `3A`, `S`, `Q`, `M`.

Source: `https://api.worldbank.org/v2/sdmx/rest/dataflow` and `https://api.worldbank.org/v2/sdmx/rest/datastructure/WB/WDI/1.0/?references=all`.

### 4b. `data360api.worldbank.org/data360` (the newer Data360 platform, many databases)
This is **not** a standard SDMX REST structure API — naive SDMX-style paths (`/sdmx/v2/structure/...`, `/codelist/...`) all 404. It exposes a custom REST/JSON `data` endpoint and a `structure` endpoint that needs `datasetId`/`indicatorId` query params (returned 417 "unexpected error" for the pair tried; no working example found). No swagger/OpenAPI doc was found at guessed paths (`/swagger/v1/swagger.json` → 404 both at root and under `/data360`).

What *is* confirmed, from live data rows (`GET https://data360api.worldbank.org/data360/data?DATABASE_ID=WB_WDI&INDICATOR=WB_WDI_NY_GDP_PCAP_KD&timePeriodFrom=2020&timePeriodTo=2020&top=5` → 200 OK, and the same for `DATABASE_ID=WB_PIP`), each observation is a flat record with these fields, which function as the DSD's dimensions/attributes/measure:

`OBS_VALUE, TIME_FORMAT, UNIT_MULT, COMMENT_OBS, OBS_STATUS, OBS_CONF, AGG_METHOD, DECIMALS, COMMENT_TS, DATA_SOURCE, LATEST_DATA, DATABASE_ID, INDICATOR, REF_AREA, SEX, AGE, URBANISATION, COMP_BREAKDOWN_1, COMP_BREAKDOWN_2, COMP_BREAKDOWN_3, TIME_PERIOD, FREQ, UNIT_MEASURE, UNIT_TYPE`

- **Yes, generic slot dimensions are used**: `COMP_BREAKDOWN_1`, `COMP_BREAKDOWN_2`, `COMP_BREAKDOWN_3` (not `MEASURE_QUAL_1` as guessed in the brief — the actual name is `COMP_BREAKDOWN_<n>`). These match agency **IAEG-SDGs**'s `CL_COMP_BREAKDOWN` codelist (396 codes, v1.24) almost certainly by design — Data360's DSD looks modelled on the UN SDG Global DSD pattern.
- `REF_AREA` uses ISO alpha-3 (`TCD`, `CHI`, `CHL`, `CHN`, `COL`, `AGO`, `SEN` all seen) — consistent with this project's convention.
- `SEX`, `AGE`, `URBANISATION` observed values so far are all `_T` (WDI) or `_Z`/`_T` mixed (PIP: `SEX=_Z`, `AGE=_Z`, `URBANISATION=_T`) — i.e. reserved codes `_T` (total) and `_Z` (not applicable) are actively used in real data, matching the IAEG-SDGs reserved-code convention (`_T`, and presumably `_Z`/`_X` elsewhere), not SDMX-agency's CL_SEX (`_N`, `_O`, `_U`, `_Z`, no plain not-applicable-only pattern).
- `UNIT_MEASURE` values seen: `USD_K_2015` (WDI GDP per capita) and `PT_POP` (PIP headcount rate, "percent of population") — these look like IAEG-SDGs-style unit codes (short, semantic mnemonics) but are not literally verified as codes drawn 1:1 from `IAEG-SDGs:CL_UNIT_MEASURE` (that list's sample codes are things like `USD`, `PT`, `PER_1000_POP` — close in style, but `USD_K_2015` and `PT_POP` were not found verbatim in the first 40 IAEG-SDGs codes printed in §5, so Data360 likely extends/adapts the pattern rather than reusing the codelist unchanged).
- `WB_PIP` (Poverty & Inequality Platform) sample rows for indicator `WB_PIP_HEADCOUNT_LMIC` (poverty headcount): `COMP_BREAKDOWN_1="WB_PIP_C"` — a Data360/PIP-specific code (not a global SDMX code) that appears to flag the welfare aggregate as consumption-based ("C"). No separate "poverty line" or "welfare aggregate" dimension exists; that information is folded into the `INDICATOR` ID and into dataset-specific `COMP_BREAKDOWN_*` codes.

Sources: `https://data360api.worldbank.org/data360/data?DATABASE_ID=WB_WDI&INDICATOR=WB_WDI_NY_GDP_PCAP_KD&timePeriodFrom=2020&timePeriodTo=2020&top=5`; `https://data360api.worldbank.org/data360/data?DATABASE_ID=WB_PIP&top=3`; metadata via the Data360 MCP tool matched `https://data360api.worldbank.org/data360/data?top=1000&skip=0&DATABASE_ID=WB_WDI&INDICATOR=WB_WDI_NY_GDP_PCAP_KD` and `csv_link`/`json_link` at `data360files.worldbank.org`.

## 5. Global codelists for sub-national geography and household-survey concepts (poverty line, welfare aggregate, quintile)

No SDMX (agency `SDMX`) or World Bank global codelist for **sub-national geographic units** was found — `CL_AREA` at both agency SDMX (v2.0.1, 899 codes, M49 numeric + ISO alpha-2 only — see note below) and agency IAEG-SDGs (v1.23) are national/regional-aggregate lists, with no ADM1/ADM2/district-level codes. Sub-national geography is not something any global SDMX codelist covers; it would have to come from a national statistical office's own codelist (e.g. `GW_INE`, already an SDMX-registered agency, might have one — not checked, out of scope) or a non-SDMX gazetteer (GADM, geoBoundaries, UN P-Codes).

For **household-survey/poverty concepts**, agency **IAEG-SDGs** (the UN SDG custodian agency, used for the Global SDG Indicators Database and evidently the template Data360 follows) maintains a much richer set of global codelists than agency SDMX does. Full list (`GET /sdmx/v2/structure/codelist/IAEG-SDGs/all/latest?detail=allstubs`, 200 OK — note: this endpoint answered in SDMX-ML v3.0 XML even with a JSON Accept header, so it was re-fetched per-codelist for JSON):

| ID | Version | Name |
|---|---|---|
| CL_CUST_BREAKDOWN | 1.14 | SDG custom breakdown code list |
| CL_URBANISATION | 1.10 | Degree of urbanisation code list |
| CL_NATURE | 1.0 | Nature code list |
| CL_AREA | 1.23 | SDG reference area code list |
| CL_AGE | 1.25 | SDG age group code list |
| CL_GEO_INFO_TYPE | 1.0 | Geoinformation type code list |
| CL_PRODUCT | 1.23 | SDG Type of product code list |
| **CL_QUANTILE** | **1.1** | **Income/wealth quantile code list** |
| CL_ACTIVITY | 1.6 | Economic activity code list |
| CL_DISABILITY | 1.0 | Disability status code list |
| CL_EDUCATION_LEV | 1.10 | SDG Education Level code list |
| CL_COMP_BREAKDOWN | 1.24 | SDG composite breakdown code list |
| CL_REPORTING_TYPE | 1.0 | Reporting type code list |
| CL_SERIES | 1.25 | SDG Series Code List |
| CL_UNIT_MEASURE | 1.20 | SDG Unit of Measure code list |
| CL_SEX | 1.1 | Sex code list |
| CL_OCCUPATION | 1.8 | SDG Occupation code list |

**CL_QUANTILE (v1.1, 10 codes)** directly covers the "quintile" need: `_T`=Total (national average) or no breakdown, `Q1`=Quintile 1 (poorest) ... `Q5`=Quintile 5 (richest), `B40`=Bottom 40%, `R60`=Richest 60%, `B50`=Bottom 50%, `R50`=Richest 50%.

Searched the 396-code `CL_COMP_BREAKDOWN` (v1.24) for anything matching "poverty line" or "welfare aggregate" by name — **none found**. It does contain fiscal-incidence-relevant codes such as `FIS_PREFIS_INC` (Fiscal intervention stage: Prefiscal income) and `FIS_POSTFIS_DIS_INC`/`FIS_POSTFIS_CON_INC` (post-fiscal disposable/consumable income), which are conceptually adjacent to this project's fiscal-equity cards but are not a poverty-line or welfare-aggregate-type codelist as such.

**Conclusion for this section: no global codelist exists for "poverty line" (e.g. $3.00/$4.20/$8.30-a-day thresholds) or "welfare aggregate" (consumption vs. income) as such — these remain indicator- or database-specific (e.g. baked into Data360's `INDICATOR` IDs like `WB_PIP_HEADCOUNT_LMIC`, or into ad hoc `COMP_BREAKDOWN` values like `WB_PIP_C`).** Quintile is covered (`CL_QUANTILE`). Sub-national geography is not covered by any global list found.

Sources: `https://registry.sdmx.org/sdmx/v2/structure/codelist/IAEG-SDGs/all/latest?detail=allstubs`; per-list JSON at `https://registry.sdmx.org/sdmx/v2/structure/codelist/IAEG-SDGs/<ID>/latest`.

## 6. Conclusion — coverage of this project's needs

| Need | Covered by a global codelist? |
|---|---|
| Sex | Yes, twice, with **different reserved codes**: `SDMX:CL_SEX(2.1)` (`F`,`M`,`_N`,`_O`,`_T`,`_U`,`_Z`) and `IAEG-SDGs:CL_SEX(1.1)` (`F`,`M`,`_N`,`_O`,`_T`,`_U`,`_X`). Pick one; Data360 data uses `_T`/`_Z` style values matching neither list exactly in reserved-code spelling, so verify against live Data360 payloads before committing. |
| Age | Only as age-band groups at `IAEG-SDGs:CL_AGE(1.25)`; `SDMX:CL_AGE(1.0)` is a duration-unit list (Y/M/W/D/H), not age bands, and would be the wrong choice for a "poverty by age group" breakdown. |
| Urban/rural | Yes, twice, with **different codes**: `SDMX:CL_DEG_URB(1.0)` (14 codes, `URB`/`RUR`) vs `IAEG-SDGs:CL_URBANISATION(1.10)` (5 codes, `U`/`R`). Data360's `URBANISATION` field values seen (`_T`) are consistent with either as a reserved code, so the choice is open. |
| Quintile (welfare distribution) | Yes: `IAEG-SDGs:CL_QUANTILE(1.1)` (Q1–Q5, B40/R60, B50/R50, `_T`). |
| Unit of measure | Yes, but only at `IAEG-SDGs:CL_UNIT_MEASURE(1.20)` (57 codes: percent, counts, per-population rates, currency units, etc.) — **not** at agency SDMX, which has no `CL_UNIT_MEASURE` at all. Coverage for this project's actual units ("share 0–1", "millions of people", "national-currency amount") would need mapping/extension: COG's own unit-of-measure guidance (per a November 2025 supplementary document, "Guidelines for Modelling Units of Measure in SDMX") treats unit as largely non-enumerated/free-form in general SDMX practice, and the IAEG-SDGs list does not include a plain "share/rate 0–1" code (project rates are stored as 0–1 shares, whereas `IAEG-SDGs:CL_UNIT_MEASURE` has `PT` = Percent, implying 0–100). |
| Observation status | Yes: `SDMX:CL_OBS_STATUS(2.3)` (23 codes covering normal/estimated/forecast/provisional/missing-reason variants) is comprehensive and directly reusable. |
| Country / reference area | Partially, and with a **format mismatch to resolve**: `SDMX:CL_AREA(2.0.1)` keys its 899 codes on **M49 numeric** IDs (`686`=Senegal, `624`=Guinea-Bissau) with ISO alpha-2 (`SN`, `GW`) as separate codes and alpha-3 only in free-text descriptions ("ISO 3166-2 code: SN") — **no alpha-3 code IDs exist in it at all**. By contrast, `WB:CL_REF_AREA_WDI(1.0)` (World Bank's own WDI codelist, ISO alpha-3, e.g. `SEN`) and Data360's live `REF_AREA` values (also alpha-3, e.g. `SEN`, `TCD`, `AGO`) match this project's existing `Tables_<ISO3>.xlsx` file-naming/ISO3 convention exactly. So: the *World Bank's own* reference-area codelist is the better fit for reuse, not the generic SDMX-agency `CL_AREA`. |

**Overall**: sex, observation status and quintile are well covered by existing global lists (pick one sex/urban-rural list and be consistent — SDMX-agency vs. IAEG-SDGs offer different code vocabularies for the same concepts). Country/reference-area is covered, but by the World Bank's own ISO3 list rather than the generic SDMX `CL_AREA` (which is M49/alpha-2 based and would require a code-format change this project's "don't touch the data layer yet" rule wouldn't allow). Age-band and urban/rural need the IAEG-SDGs variants specifically (SDMX-agency's versions either aren't age-bands at all, or use different urban/rural codes). Unit of measure is the weakest fit: a global list exists (IAEG-SDGs) but doesn't cleanly cover this project's 0–1 share convention or its currency/millions-of-people units without extension. Sub-national admin units, poverty-line thresholds, and welfare-aggregate type have **no global codelist** at all — those stay project- or Data360-indicator-specific.

## Endpoints that failed or needed adjustment
- `https://data360api.worldbank.org/data360/` and naive SDMX-style structure paths under it → 404 (Data360 is not a standard SDMX REST structure API).
- `https://data360api.worldbank.org/data360/structure?...` → exists (400 without params, 417 with a plausible `datasetId`/`indicatorId` pair) but never returned usable structure JSON.
- No swagger/OpenAPI doc found at `/swagger/v1/swagger.json` (root or under `/data360`) → 404.
- `https://api.worldbank.org/v2/sdmx/rest/datastructure/WB/WDI/1.0?references=all` (no trailing slash) → 307-redirects to `dataapi.worldbank.org`; the trailing-slash form works directly.
- Direct fetch of `SDMX:CL_UNIT_MEASURE`, `SDMX:CL_EDUCATION_LEV`, bare `SDMX:CL_ACTIVITY` → all 404 (they simply don't exist at agency SDMX; IAEG-SDGs has equivalents).
- `WB:codelist/all/latest` and `WB:dataflow/all/latest` in the SDMX Global Registry → 404 (World Bank has not published structures into the registry itself).
- `GET /sdmx/v2/structure/codelist/IAEG-SDGs/all/latest` answered in SDMX-ML v3.0 XML despite a JSON Accept header (registry inconsistency); worked around by requesting each codelist individually, which did honour the JSON Accept header.
- All registry.sdmx.org and api.worldbank.org calls required `curl --ssl-no-revoke` in this environment (Windows schannel OCSP revocation-check failure otherwise); no content failures once that flag was added.
