# R-C review: global alignment and registry facts

Reviewer R-C, 2026-09-29. Primary source: SDMX Global Registry REST v2 (`https://registry.sdmx.org/sdmx/v2/structure/...`, JSON 2.0.0 and SDMX-ML 3.0), World Bank DDP SDMX service (`https://api.worldbank.org/v2/sdmx/rest/...`), SDMX-ML 3 schema `SDMXStructureOrganisation.xsd` (github.com/sdmx-twg/sdmx-ml, master). All calls used `curl --ssl-no-revoke -s`; responses were saved to the session scratchpad `reg/` folder.

### R-C-1
Severity: major
Where: plan.md section 2.9, line 226 (row CL_AREA); D32 line 38
Claim: `WB:CL_REF_AREA_WDI(1.0)` is not in the SDMX Global Registry. It is published only by the World Bank's own DDP SDMX service. The URN in the plan is exactly right, but the plan does not say where the list lives, so an implementer checking it against the registry gets a 404.
Evidence: `GET https://registry.sdmx.org/sdmx/v2/structure/codelist/WB/CL_REF_AREA_WDI/1.0` returned `404` (54 bytes). `GET https://api.worldbank.org/v2/sdmx/rest/codelist/WB/CL_REF_AREA_WDI/1.0/` returned 200 with `<Codelist id="CL_REF_AREA_WDI" urn="urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB:CL_REF_AREA_WDI(1.0)" agencyID="WB" version="1.0" isFinal="true">`, contains `id="SEN"` and `id="GNB"`, and emits `urn="urn:sdmx:org.sdmx.infomodel.codelist.Code=WB:CL_REF_AREA_WDI(1.0).SEN"`.
Fix: In the 2.9 CL_AREA row, append: "Published by the World Bank DDP service, not the Global Registry: `https://api.worldbank.org/v2/sdmx/rest/codelist/WB/CL_REF_AREA_WDI/1.0/` (trailing slash required). `SEN` and `GNB` both exist; GNB gets `urn:sdmx:org.sdmx.infomodel.codelist.Code=WB:CL_REF_AREA_WDI(1.0).GNB`."

### R-C-2
Severity: major
Where: plan.md section 2.5, line 186 (Sentinels bullet)
Claim: The sentinel `GLOBAL_CODE` value is given as `SDMX:CL_SEX(2.1)._T` / `._Z`. That is a short reference, not a URN, so it breaks the rule that `GLOBAL_CODE` holds a URN (2.5 line 177; the validator treats "a `global_urn` without the prefix" as a fault, line 407). The bullet also points every list at `CL_SEX`, even though most of the aligned global lists have their own `_T`. `_Z` does not exist in `IAEG-SDGs:CL_AGE` or `CL_URBANISATION`.
Evidence: Code ids from the registry. `SDMX:CL_SEX(2.1)`: `F M _N _O _T _U _Z`. `IAEG-SDGs:CL_AGE(1.25)`: has `_T` ("All age ranges or no breakdown by age"), `_U`, `_X` ("Not available"), no `_Z`. `IAEG-SDGs:CL_URBANISATION(1.10)`: `_T U R CITY TSUB`. `IAEG-SDGs:CL_QUANTILE(1.1)`: `_T Q1 Q2 Q3 Q4 Q5 B40 R60 B50 R50`. The registry emits code URNs as `urn:sdmx:org.sdmx.infomodel.codelist.Code=SDMX:CL_SEX(2.1)._T` (grep of the XML response).
Fix: Replace "Each carries `GLOBAL_CODE` pointing at `SDMX:CL_SEX(2.1)._T` or `._Z`" with: "Each carries `GLOBAL_CODE` = the full URN of the matching code in the list's own global counterpart where it exists: `CL_SEX` → `urn:sdmx:org.sdmx.infomodel.codelist.Code=SDMX:CL_SEX(2.1)._T` / `._Z`; `CL_AGE._T` → `...Code=IAEG-SDGs:CL_AGE(1.25)._T`; `CL_URBANISATION._T` → `...Code=IAEG-SDGs:CL_URBANISATION(1.10)._T`; `CL_COMP_BREAKDOWN._T` → `...Code=IAEG-SDGs:CL_QUANTILE(1.1)._T`. Where the own list has no such code (`CL_AGE._Z`, `CL_GEO._T`, `CL_QUALIFIER._Z`), fall back to `...Code=SDMX:CL_SEX(2.1)._T` / `._Z`."

### R-C-3
Severity: minor
Where: plan.md section 2.9, line 222 (row CL_AGE); section 5 risk row, line 624
Claim: The open item is now settled. Three of the project's four age bands already use the global ids. Only `Y_LT15` needs renaming, to `Y0T14`.
Evidence: `IAEG-SDGs:CL_AGE` latest = 1.25 (same 61672-byte response for `/1.25` and `/latest`), 177 codes. Mapping (project → global, global name):

| Project id | Global id (IAEG-SDGs:CL_AGE(1.25)) | Global name |
|---|---|---|
| `Y_LT15` | `Y0T14` | under 15 years old |
| `Y15T24` | `Y15T24` | 15 to 24 years old |
| `Y25T64` | `Y25T64` | 25 to 64 years old |
| `Y_GE65` | `Y_GE65` | 65 years old and over |

`grep -rn Y_LT15 metadata pipeline/R` finds only `metadata/codelists/CL_AGE.csv:2`.
Fix: Replace the 2.9 CL_AGE alignment cell with: "Rename `Y_LT15` → `Y0T14`; `Y15T24`, `Y25T64`, `Y_GE65` already match. All four get `global_urn` = `urn:sdmx:org.sdmx.infomodel.codelist.Code=IAEG-SDGs:CL_AGE(1.25).<id>`. No data row uses an age band today." Delete the risk row at line 624, or mark it "resolved by review R-C-3".

### R-C-4
Severity: minor
Where: plan.md section 2.9, line 225 (row CL_UNIT_MEASURE)
Claim: `IAEG-SDGs:CL_UNIT_MEASURE(1.20)` has no ISO 4217 codes (no `XOF`), and it has no `PERSONS` or `PERSON` code, so the plan is right to add `XOF` with `global_urn` empty. However, several project units have an exact global match, and the plan does not list them, which leaves "identical meaning" up to the implementer's judgement.
Evidence: The registry list has 57 codes, including `HA` "Hectares", `IX` "Index", `CUR_LCU` "Local currency", `NUMBER` "Number", `PT` "Percent", `USD`, `CON_USD`, `CON_PPP_USD` "Constant PPP USD", `LCU_PPP_USD` "Local currency per USD (PPP)" (a conversion rate, not a unit of amount). There is no `XOF`, `PERSON`, `PERSONS`, `SHARE` or `HH`. Project `CL_UNIT.csv` ids: `SHARE INDEX PERSON HH HE LCU PPP_USD HA TLU DAY YEAR COUNT`.
Fix: Replace the alignment cell with: "`global_urn` = `urn:sdmx:org.sdmx.infomodel.codelist.Code=IAEG-SDGs:CL_UNIT_MEASURE(1.20).<id>` for `HA`→`HA`, `INDEX`→`IX`, `LCU`→`CUR_LCU`, `COUNT`→`NUMBER`. `PPP_USD` stays empty: `CON_PPP_USD` means constant-price PPP USD, so it matches only if the project unit is defined at constant prices; confirm first. `SHARE` (0 to 1), `PERSON`, `HH`, `HE`, `TLU`, `DAY`, `YEAR` have no equivalent. Add each ISO 4217 code in `CL_AREA.currency` (today `XOF`) with `global_urn` empty and a note that `LCU` is the currency-neutral alternative." Uncertain: whether keeping both `LCU` and `XOF` is intended. It is a project design question, not a registry fact.

### R-C-5
Severity: minor
Where: plan.md section 2.9, line 224 (row CL_OBS_STATUS)
Claim: All seven ids exist in `SDMX:CL_OBS_STATUS(2.3)`, which is also the latest version. Their meanings differ from the project names in ways the words "align names" do not settle.
Evidence: The registry has 23 codes, `A B D E F G I K W O M P S L H Q J N U V _U X R`. Global names: `A` Normal value, `E` Estimated value, `M` "Missing value; data cannot exist", `O` Missing value, `U` Low reliability, `D` Definition differs, `Q` "Missing value; suppressed". Project names: `E` Model-based value, `O` No value available, `M` Not applicable, `Q` Suppressed.
Fix: Replace "check ids exist and align names" with "ids verified in 2.3; set `name_en` to the global names exactly: A Normal value; E Estimated value; M Missing value; data cannot exist; O Missing value; U Low reliability; D Definition differs; Q Missing value; suppressed. Keep the project's more specific wording in `definition_en`."

### R-C-6
Severity: major
Where: plan.md D31 line 37; section 2.1 line 58
Claim: D31's rationale says "the team does not own the bare `WB` namespace", yet the plan ships a maintainable `WB:AGENCIES` scheme, which is an artefact maintained by agency `WB`. SDMX makes the maintainer of an agency scheme the parent of every agency in it, so only the World Bank's SDMX owner can legitimately publish `WB:AGENCIES`. Uncertain: no registry policy page was consulted on whether an unregistered sub-agency may be used locally. The schema text below is the only primary source.
Evidence: The `SDMXStructureOrganisation.xsd` AgencySchemeType documentation reads: "The agency scheme maintained by a particular maintenance agency is always provided a fixed identifier and is never versioned... the actual parent agency for an agency in a scheme is the agency which defines the scheme." `id` is `fixed="AGENCIES"`. `SDMX:AGENCIES` lists 21 agencies, including `WB` "World Bank (WB)". No id starts with `WB` other than `WB`, and no id contains a dot. It is the only agency scheme in the registry (`agencyscheme/*/*/*` returned one, `SDMX:AGENCIES`).
Fix: Add to D31 and 2.1: "The shipped `WB:AGENCIES` scheme is a local placeholder so that `WB.AFW360` resolves in FMR and pysdmx. It asserts nothing in the World Bank's namespace, must not be submitted to any registry, and is replaced by the World Bank's own scheme at registration." Also add a Phase-5 check that no deliverable pushes `WB:AGENCIES` to an external registry.

### R-C-7
Severity: major
Where: plan.md section 2.10 item 3, line 234 (and its verification at line 344)
Claim: Item 3 puts `global_urn` "after `notes`", but the verification requires every codelist header to end with `notes,global_urn`. `CL_AREA.csv` and `CL_COMP_BREAKDOWN.csv` have columns after `notes`, so both instructions cannot be satisfied. An implementer who follows item 3 fails the check, or the reverse.
Evidence: `head -1 metadata/codelists/CL_AREA.csv` gives `code,name_en,definition_en,status,version_added,replaced_by,notes,iso2,currency,wb_region`. `head -1 metadata/codelists/CL_COMP_BREAKDOWN.csv` gives `...,notes,var_code,parent,order`.
Fix: Make item 3 read "`global_urn` (status `O`) added as the last column of every codelist". Change the line 344 check to `head -1 $f | grep -q ",global_urn$"`.

### R-C-8
Severity: minor
Where: plan.md section 2.9, line 223 (row CL_URBANISATION)
Claim: `SDMX:CL_DEG_URB(1.0)` exists (latest; the only `CL_DEG_URB` of any agency), but its codes are `URB` and `RUR`, not `U` and `R`. `IAEG-SDGs:CL_URBANISATION(1.10)` is the right target, as the plan has it. The plan should record that `CL_DEG_URB` was considered and rejected so the question does not come back. The URBANISATION dimension is not a cross-domain concept in either case.
Evidence: `SDMX:CL_DEG_URB(1.0)` codes: `_T URB CITY TSUB DTOW STOW SUBU RUR VILL DISP UNIN _O _U _Z`. `codelist/*/CL_DEG_URB/*` returned only `SDMX:CL_DEG_URB(1.0)`. `IAEG-SDGs:CL_URBANISATION` latest = 1.10, codes `_T U R CITY TSUB`. `CROSS_DOMAIN_CONCEPTS(2.0)` has no `URBANISATION` or `DEG_URB`.
Fix: Append to the row: "Not `SDMX:CL_DEG_URB(1.0)` (uses `URB`/`RUR`; value alignment would force renames). `CAP` is not the global `CITY` (degree-of-urbanisation class), so no `global_urn` for `CAP` or `OU`."

### R-C-9
Severity: minor
Where: research/R3_global_codelists.md section 4b (bullet on SEX/AGE/URBANISATION values) and section 6 row "Sex"
Claim: R3 says Data360's `_T`/`_Z` values match "not SDMX-agency's CL_SEX" and "neither list exactly". That contradicts R3's own section 1 and the registry: `SDMX:CL_SEX(2.1)` contains both `_T` and `_Z`. Only `IAEG-SDGs:CL_SEX(1.1)` lacks `_Z`, because it uses `_X`.
Evidence: `SDMX:CL_SEX(2.1)` codes `F M _N _O _T _U _Z`. `IAEG-SDGs:CL_SEX(1.1)` codes `_T F M _N _O _U _X`.
Fix: In R3 section 6 "Sex", replace "Data360 data uses `_T`/`_Z` style values matching neither list exactly" with "Data360's `_T`/`_Z` values are both codes of `SDMX:CL_SEX(2.1)`; `IAEG-SDGs:CL_SEX(1.1)` lacks `_Z`." Correct the section 4b bullet the same way. The plan already uses `SDMX:CL_SEX(2.1)`, so the plan itself is unaffected.

## Verified OK

- Existence and version (all 200, and each equals latest): `SDMX:CL_FREQ(2.1)`, `SDMX:CL_SEX(2.1)`, `SDMX:CL_OBS_STATUS(2.3)`, `IAEG-SDGs:CL_AGE(1.25)`, `IAEG-SDGs:CL_URBANISATION(1.10)`, `IAEG-SDGs:CL_UNIT_MEASURE(1.20)`, `IAEG-SDGs:CL_QUANTILE(1.1)`. `WB:CL_REF_AREA_WDI(1.0)` exists at the WB DDP service only (R-C-1). `SDMX:CL_DEG_URB(1.0)` exists (R-C-8).
- Code values: `_T` and `_Z` in `SDMX:CL_SEX(2.1)`. `A` "Annual" in `CL_FREQ(2.1)`. `A E M O U D Q` in `CL_OBS_STATUS(2.3)`. `U`, `R`, `_T` in `CL_URBANISATION(1.10)`. `Q1`..`Q5` in `CL_QUANTILE(1.1)` (project `QUINT_Q1`..`QUINT_Q5` map one-to-one). `SEN` and `GNB` in `WB:CL_REF_AREA_WDI(1.0)`. `F` and `M` in the project's `CL_SEX` match the global codes.
- URN form: the registry emits `urn:sdmx:org.sdmx.infomodel.codelist.Code=SDMX:CL_SEX(2.1).F`, and the WB service emits `urn:sdmx:org.sdmx.infomodel.codelist.Code=WB:CL_REF_AREA_WDI(1.0).SEN`. The plan's `global_urn` example is character-for-character identical: version in parentheses, then `.CODE`.
- Agency scheme versioning: the registry's SDMX-ML 3.0 output `<str:AgencyScheme urn="urn:sdmx:org.sdmx.infomodel.base.AgencyScheme=SDMX:AGENCIES(1.0)" ... agencyID="SDMX" id="AGENCIES">` has no version attribute, while its URN carries `(1.0)`. The JSON shows version `1.0`. So "no version attribute in XML" (2.1) together with `WB:AGENCIES(1.0)` in URNs (D31) is consistent. Declaring `Agency id="AFW360"` (no dot) inside `WB:AGENCIES`, which yields `WB.AFW360`, is the correct construction.
- `WB` exists in `SDMX:AGENCIES` as "World Bank (WB)", with no sub-agencies. This matches D31's rationale.
- `SDMX:CROSS_DOMAIN_CONCEPTS(2.0)` exists and is latest (229 concepts). `FREQ`, `REF_AREA`, `TIME_PERIOD`, `OBS_VALUE`, `OBS_STATUS`, `UNIT_MEASURE`, `SEX`, `AGE`, `INDICATOR`, `COMMENT`, `DATA_SOURCE` all exist with those exact ids.
- R3 facts re-confirmed: SDMX codelist versions for CL_FREQ, CL_SEX, CL_OBS_STATUS and CL_DEG_URB; CL_OBS_STATUS has 23 codes, and `_U` is its only reserved code; CL_DEG_URB has 14 codes; IAEG-SDGs CL_URBANISATION has 5 codes; CL_QUANTILE has 10; CL_UNIT_MEASURE has 57; CL_SEX(1.1) uses `_X`; CROSS_DOMAIN_CONCEPTS is 2.0 with 229 concepts; AGENCIES has 21 agencies including `WB` and `GW_INE`; WB publishes no codelists in the Global Registry; CL_REF_AREA_WDI uses ISO alpha-3 codes. No R3 registry fact is stale apart from the inference corrected in R-C-9.

## Not checked

- D32's premise that "SDMX forbids a semver artefact from referencing a legacy-versioned one". This is outside the registry scope; R1 line 97 quotes it from the technical notes, and I did not re-fetch that source.
- The Global Registry's policy pages on registering sub-agencies; R-C-6 rests on the XSD documentation only.
- Data360's live `URBANISATION` and `UNIT_MEASURE` code values (R3 section 4b) were not re-queried.
- plan.md section 2.10 items 4 to 7, beyond their codelist references.
