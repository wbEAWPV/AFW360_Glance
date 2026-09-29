# R-B: SDMX-CSV 2.1 data and metadata messages

Primary sources (tag `v2.1.0` exists; both fetched with HTTP 200):
- DATA = https://raw.githubusercontent.com/sdmx-twg/sdmx-csv/v2.1.0/data-message/docs/sdmx-csv-field-guide.md
- META = https://raw.githubusercontent.com/sdmx-twg/sdmx-csv/v2.1.0/metadata-message/docs/sdmx-csv-field-guide.md
- pysdmx sources at tag `v1.20.0`: https://raw.githubusercontent.com/bis-med-it/pysdmx/v1.20.0/src/pysdmx/io/ (`input_processor.py`, `reader.py`, `format.py`, `csv/__csv_aux_reader.py`, `csv/sdmx21/reader/__init__.py`); PyPI https://pypi.org/pypi/pysdmx/1.20.0/json (uploaded 2026-09-18, latest version).

### R-B-1
Severity: blocker
Where: plan.md section 2.7 last bullet (line 210), section 2.12 "Independent reader" (line 252), WP7 deliverables (line 438), acceptance row 8 (line 642), risk row (line 622)
Claim: pysdmx 1.20.0 cannot read SDMX-CSV metadata messages, so "confirms that pysdmx reads it back", "reads every `sdmx/metadata/*.csv` as SDMX-CSV 2.1" and acceptance row 8 cannot be completed.
Evidence: `input_processor.py` v1.20.0, `__get_sdmx_csv_flavour`: `if "DATAFLOW" in headers: return ..., Format.DATA_SDMX_CSV_1_0_0` / `elif "STRUCTURE" in headers and "STRUCTURE_ID" in headers: return ..., Format.DATA_SDMX_CSV_2_1_0` / `raise Invalid("Validation Error", "Cannot parse input as SDMX-CSV.")`. `headers` is a list, so an `MDSTRUCTURE,...` header matches neither branch and raises. `reader.py` dispatches reference metadata only for `REFMETA_SDMX_JSON_*` and `REFMETA_SDMX_ML_3_0/3_1`. The v1.20.0 tree (GitHub API `git/trees/v1.20.0?recursive=1`) has `io/csv/sdmx10|sdmx20|sdmx21` (data only) and no CSV metadata reader; `format.py` declares `REFMETA_SDMX_CSV_2_1_0` but nothing reads it.
Fix: In 2.12 replace "reads every `data/*.csv` and `sdmx/metadata/*.csv` as SDMX-CSV 2.1" with "reads every `data/*.csv` as SDMX-CSV 2.1 with pysdmx; parses every `sdmx/metadata/*.csv` with Python's `csv` module and checks it against the SDMX-CSV 2.1 metadata guide: first header field `MDSTRUCTURE` (or `MDSTRUCTURE[x]`), then `MDSTRUCTURE_ID`, `METADATASET_ID`, optional `IS_PARTIAL_LANGUAGE`, `TARGET_TYPES`, `TARGET_IDS`; every other column is a dotted path of metadata attribute ids of the MSD that pysdmx reads from the structure message; `MDSTRUCTURE` is `metadataflow`; `TARGET_TYPES` is a REST structure resource name; `TARGET_IDS` resolves to an artefact in the structure message (pysdmx 1.20.0 has no SDMX-CSV metadata reader)." Apply the same wording to WP7 (line 438) and acceptance row 8, and delete "confirms that pysdmx reads it back with the intended target" from 2.7 and the pysdmx wording from risk row 622.

### R-B-2
Severity: major
Where: plan.md section 2.7, bullets `MDS_SURVEYS.csv` to `MDS_FIGURES.csv` and last bullet (lines 205 to 210); sdmx-ml-cheatsheet.md section 14 "Row" bullet
Claim: The metadata guide defines targets only as whole artefacts (`AGENCY:ARTEFACT_ID(VERSION)`, typed by a REST structure resource name), so the item form `WB.AFW360:CL_SURVEY(0.3.0).<survey_id>` is not SDMX-CSV 2.1; given R-B-1 the plan's confirmation step cannot run, so the fallback has to be adopted now.
Evidence: META "Column content (all rows after header)": "The next column contains the types of all the targets of the metadataset according to the resource names defined for Structural Metadata Queries, e.g. `dataflow`. Multiple targets are separated by the special sub-field separation character ... Example for multiple target types: `dataflow;dataflow`." and "The next column contains the identification information of all the targets of the metadataset in the form *AGENCY:ARTEFACT_ID(VERSION)* (1), separated by the sub-field separation character, e.g. `AGENCY:DF1(1.0.0);AGENCY:DF2(1.0.0)`." Example 4 targets a whole codelist: `...,codelist,OECD:CL(1.0.0),Codelist name,...`. No clause or example shows an item (`.CODE`) suffix.
Fix: Replace the four target sub-bullets and the last bullet of 2.7 with: "Targets are whole artefacts, as the SDMX-CSV 2.1 metadata guide defines them: `MDS_SURVEYS.csv` targets `codelist` / `WB.AFW360:CL_SURVEY(0.3.0)`; `MDS_SOURCES.csv` `codelist` / `WB.AFW360:CL_SOURCE(0.3.0)`; `MDS_FIGURES.csv` `codelist` / `WB.AFW360:CL_FIGURE(0.3.0)`; `MDS_TEXT.csv` `dataflow` / `WB.AFW360:AFW360_HH(0.3.0)`. The item a metadataset describes is identified by its `METADATASET_ID` (`MDS_SURVEY_<survey_id>` etc.) and by the key attributes inside it (for example `SURVEY.REF_AREA`, `SURVEY.TIME_PERIOD`). The metadataflow `MDF_AFW360` targets these three codelists and the dataflow." In cheatsheet section 14 change the Row example to `metadataflow,WB.AFW360:MDF_AFW360(0.3.0),WB.AFW360:MDS_SURVEY_SEN_EHCVM_2021,codelist,WB.AFW360:CL_SURVEY(0.3.0),...` and replace "Item-level short form is UNCERTAIN (see plan 2.7)" with "Targets are whole artefacts only; SDMX-CSV 2.1 has no item-level target form."

### R-B-3
Severity: major
Where: plan.md section 1, D38 (line 44)
Claim: The rationale "A published country-year-estimation file is the complete replacement of that slice" contradicts the guide: `R` replaces only whole observations and cannot replace a dataset or series, so observations absent from a republished file are not deleted; also `A`, not only `I`, is deprecated.
Evidence: DATA "Column content", `"R": Replace`: "Because the *replace* action always takes place at specific levels, it cannot be used to replace a whole dataset or a whole series. However, a "*replace all*" effect can be achieved by combining a *Delete* row containing a completely wildcarded key (where all dimension values are omitted) with *Merge* or *Replace* rows within the same data message." The recommendation D38 cites is DATA "Recommended dataset actions in SDMX web service responses to GET data queries", item 1: "Without the *updatedAfter*, *includeHistory*, *detail*, *attributes* or *measures* URL parameters: The response message should contain the retrieved data in a *Replace* dataset (instead of the previous *information* dataset)." with footnote "So far this is recommended for systems that do not require backward-compatibility." DATA: `"I": Information - Deprecated`, `"A": Append - Deprecated`.
Fix: Replace the D38 rationale with: "The SDMX-CSV 2.1 guide recommends `R` for complete query responses (instead of the deprecated `I`; `A` is also deprecated). `R` replaces whole observations and merges attributes above observation level; it does not delete observations missing from the file. A consumer loading a file into a store who needs the slice replaced must first delete it (a `D` row with the partial key `REF_AREA`, `ESTIMATION`, `TIME_PERIOD`); the published files contain no `D` rows."

### R-B-4
Severity: major
Where: plan.md section 2.3 (sample row and Rules) together with section 2.4 rows 29 and 30 (lines 156 to 157)
Claim: Uncertain: `SERIES_ID` (attached to `INDICATOR`, `COMP_BREAKDOWN_1..5`, `MEASURE_QUAL_1..5`) and `UNIT_MEASURE` (attached to `REF_AREA`, `INDICATOR`) are replicated on every observation row, so each must carry exactly one value per partial key across all files (for `SERIES_ID` across all countries, years and estimations; for `UNIT_MEASURE` across all years, estimations and breakdowns), and the plan defines no check for this.
Evidence: DATA "Column content": "For rows containing the information related to one specific observation, the related values for attributes attached to partial keys may have to be replicated." and `"R"`: "Values provided for the other attributes (those above the observation level) are merged (see *Merge* action)." Replication plus merge implies one value per partial key; conflicting values would overwrite each other silently on load. The guide states no explicit error rule (hence Uncertain). `grep -n -i 'attach\|consisten\|one value per' plan.md` finds no such check.
Fix: Add to 2.3 Rules: "Attributes attached to partial keys (`SERIES_ID`, `UNIT_MEASURE`) are replicated on every row and must have one value per partial key across all data files. Validator check `SDMX.ATTR_LEVEL` (ERROR) groups all rows of all files by each attribute's relationship dimensions and reports any group with more than one distinct value." If a unit can differ across years for the same `REF_AREA` x `INDICATOR` (for example a currency change), add `TIME_PERIOD` to the `UNIT_MEASURE` relationship in 2.4.

### R-B-5
Severity: major
Where: plan.md section 2.12 "Independent reader" (line 252) and WP7 `requirements.txt` (line 438)
Claim: `pysdmx[data]` does not install the SDMX-ML reading dependencies; `xmltodict` and `sdmxschemas` (and `lxml`) are declared only under the `xml` extra, so reading `AFW360_structures.xml` with `validate=True` needs `pysdmx[data,xml]`.
Evidence: PyPI JSON for 1.20.0, `requires_dist`: `lxml>=6.1.0; sys_platform != "emscripten" and extra == "xml"`, `sdmxschemas>=1.1.0; extra == "xml"`, `xmltodict>=0.13; extra == "xml"`; the `data` extra lists only `pandas>=2.1.4` and `pyarrow<26.0,>=14.0`. That the XML reader fails without them is an inference from the extras; not executed.
Fix: Replace "`pysdmx[data]==1.20.0`, `lxml`" with "`pysdmx[data,xml]==1.20.0`" in 2.12 and in WP7's `requirements.txt`.

### R-B-6
Severity: minor
Where: plan.md D39 (line 45) and section 2.3 rule 4 (line 124)
Claim: The D39 rationale says `NaN` marks intentionally missing values "for a numeric measure", but the guide restricts `NaN` to float and double and prescribes `#N/A` for every other type (the Integer measures `N_OBS`, `N_OBS_NUM`, `DF`, and all coded or string attributes); D39's decision text also lets mandatory attributes be empty, while 2.3 says only optional attributes may be empty.
Evidence: DATA "Intentionally missing values": "To indicate **intentionally missing** observations, attributes and reference metadata values, even if mandatory, the following special values are to be used in SDMX-CSV: - Numeric data types float and double: `NaN` - All other data types: `#N/A`". DATA "Columns": "Attributes can but do not need to be included even if they have a mandatory status." `OBS_VALUE` is `Double` (plan 2.4 row 20), so the D39 decision itself is conformant.
Fix: D39 decision: "`OBS_VALUE` is `NaN` on rows whose `OBS_STATUS` is `O` or `M`. Any optional measure or attribute that a source cannot supply is left empty (omitted). Mandatory attributes (`SERIES_ID`, `UNIT_MEASURE`, `OBS_STATUS`, `SOURCE_ID`) are never empty." Rationale: "SDMX-CSV 2.1: empty means omitted; `NaN` is the intentionally-missing value for float/double components (`OBS_VALUE` is Double); `#N/A` is the intentionally-missing value for all other types and is not used."

### R-B-7
Severity: minor
Where: plan.md section 2.3, rule "RFC 4180 quoting ..." (line 126)
Claim: "RFC 4180 names CRLF but SDMX-CSV does not require it" is not supported by the guide, which bases SDMX-CSV on RFC 4180 without exempting line endings and says nothing about line endings or BOM.
Evidence: DATA "RFC 4180: A common format for CSV files": "SDMX-CSV is based on the rules defined in the RFC 4180 ... It is advised to read the (very short) RFC for a full list of requirements". `grep -n -i 'CRLF\|line ending\|BOM\|UTF' data.md` returns nothing.
Fix: Replace the parenthesis with "(project convention; a documented deviation from RFC 4180, which specifies CRLF; the SDMX-CSV 2.1 guide does not address line endings or BOM)". Also state that the writer calls `readr::write_csv(..., na = "")`, since readr's default writes `NA` and the plan relies on readr.

### R-B-8
Severity: minor
Where: sdmx-ml-cheatsheet.md section 13, first bullet
Claim: The cheatsheet's `STRUCTURE[;]` condition is incomplete (it omits multi-language values) and "DSD order" is ambiguous about measures versus attributes.
Evidence: DATA "Column headers (first row)": "This field must be extended with a sub-field delimiter encapsulated in squared brackets "[]", e.g. `STRUCTURE[;]`, in case the message contains multi-valued or multi-language measure or attribute values." DATA "Columns": "SDMX web services should return the columns in the order of components as defined in (each of) the underlying Data Structure Definition(s), grouped by type of component ... first the dimensions ..., then the measures ..., then the attributes ... However, any order of these columns is valid for data uploads to SDMX-consuming systems." Uncertain: in SDMX-ML 3.1 the DSD lists `AttributeList` before `MeasureList`, so an implementer reading "DSD order" off the XML could put attributes first.
Fix: Replace the bullet with: "Header: `STRUCTURE,STRUCTURE_ID,ACTION,<dimensions in DSD order, TIME_PERIOD last>,<measures in DSD order>,<attributes in DSD order>` (the guide's recommended order for responses; any order is valid on upload). `STRUCTURE[;]` is required only when multi-valued or multi-language measure or attribute values occur (none here)."

### R-B-9
Severity: minor
Where: plan.md WP3 verification (line 378); found while doing check 5
Claim: `awk -F, '$36=="O"'` tests `SOURCE_ID`; `OBS_STATUS` is field 35 of the 37-column layout, and `-F,` miscounts any row whose quoted `OBS_COMMENT` contains a comma.
Evidence: pasting the 2.3 header against the sample row, one field per line: line 35 `OBS_STATUS [A]`, line 36 `SOURCE_ID [SEN_EHCVM2021_LEGACY_v1]`.
Fix: Replace with a CSV-aware count: `Rscript -e 'd<-readr::read_csv("data/AFW360_HH_GNB_2021_SURVEY.csv",col_types=readr::cols(.default="c"),na=character());cat(sum(d$OBS_STATUS=="O"),sum(d$OBS_VALUE=="NaN"))'`, expecting `39 39`.

### R-B-10
Severity: minor
Where: plan.md section 2.7, metadata-message bullet (line 204); cheatsheet section 14 last bullet
Claim: The metadata guide recommends quoting every textual value, and the plan does not tell the writer to do so (readr quotes only when needed).
Evidence: META "Column content": "All string/textual values (complete string between column-separating characters including ID's or language codes) should always be encapsulated in quotation marks, they must be if they contain commas or inner quotation marks."
Fix: Add to 2.7: "Metadata messages are written with `readr::write_csv(quote = \"all\", na = \"\")`, because the guide recommends quoting all textual values and all MSD attributes are String."

### R-B-11
Severity: minor
Where: plan.md acceptance row 7 (line 641) and D39
Claim: A pysdmx read does not test the empty-versus-`NaN` rule, because its SDMX-CSV 2.1 reader turns both into the string `NaN`.
Evidence: `pysdmx/io/csv/sdmx21/reader/__init__.py` v1.20.0 line 46: `df_csv = df_csv.astype(str).replace({"nan": "NaN", "<NA>": "NaN"})`; pandas has already read empty cells as NaN by then.
Fix: Add to the row 7 evidence: "the `NaN` rule is checked on raw text by `STRUCT.*` and `reconcile.R`, not by pysdmx (pysdmx 1.20.0 maps empty cells to `NaN`)."

### R-B-12
Severity: minor
Where: plan.md section 2.7, first bullet and metadata-message bullet (lines 197, 204)
Claim: Uncertain: the plan does not say whether the four presentational parent attributes (`SURVEY`, `SOURCE`, `TEXT`, `FIGURE`) get their own column; the guide gives "each metadata attribute" a column and its example 1 has both `ATTRIBUTE_1` and `ATTRIBUTE_1.CHILD`, but it does not say whether a presentational parent without a value must appear.
Evidence: META "Columns": "Each metadata attribute of the included metadataset(s) is represented in one or two columns." Example 1 header: `MDSTRUCTURE,MDSTRUCTURE_ID,METADATASET_ID,TARGET_TYPES,TARGET_IDS,ATTRIBUTE_1,ATTRIBUTE_1.CHILD,ATTRIBUTE_2`.
Fix: Add to 2.7: "Presentational parents have no column; only child attributes appear, as `<PARENT>.<CHILD>`." Record in PROGRESS.md whether FMR accepts this once it is installed.

## Verified OK

- Data fixed columns `STRUCTURE`, `STRUCTURE_ID`, `ACTION`: exact spelling and order. `STRUCTURE` values are `dataflow`, `datastructure`, `dataprovision` in lower case, so `dataflow` is right. `STRUCTURE_ID` form is `AGENCY:ARTEFACT_ID(VERSION)`, and the version may be omitted only for non-versioned artefacts (footnote (1)). The plan's `WB.AFW360:AFW360_HH(0.3.0)` conforms. The cheatsheet section 3 "Short form" row is correct.
- Action codes: `I` and `A` are deprecated (Merge is assumed when they are used to update a store); `M`, `R`, `D` are current. The plan's `R` is allowed and is the recommended action for full responses. The guide contradicts itself about a missing `ACTION` column ("Information" in one clause, Merge in another); this does not affect the plan because the column is always present.
- 2.3 header: 37 fields. Sample row: 37 fields (`tr`/`awk` counts). Every field lines up: `FREQ`=A, `REF_AREA`=SEN, `GEO`=SN01, `ESTIMATION`=SURVEY, `INDICATOR`=AGR_CULTIVATES, `SEX`/`AGE`=`_Z`, `URBANISATION` and CB1..5=`_T`, MQ1..5=`_Z`, `TIME_PERIOD`=2021, `OBS_VALUE`=0.01, eight empty measures, `SERIES_ID`=AGR_CULTIVATES, `UNIT_MEASURE`=SHARE, `PRECISION`=0.01, `OBS_STATUS`=A, `SOURCE_ID`=SEN_EHCVM2021_LEGACY_v1, `OBS_COMMENT` empty. The key is 18 dimensions plus `TIME_PERIOD`, 19 columns.
- D46 order (dimensions, measures, attributes) matches the guide's recommended grouping. Any order is valid on upload. The guide does not regulate the position of `TIME_PERIOD` separately.
- `OBS_VALUE` is Double, so `NaN` is the correct intentionally-missing value, and an empty cell means omitted.
- Comma separator, decimal point, RFC 4180 quoting and doubled inner quotes all match the guide (cheatsheet 13 bullet 5). Rows for partial keys (cheatsheet 13 last bullet) are also correct.
- Metadata header `MDSTRUCTURE,MDSTRUCTURE_ID,METADATASET_ID,TARGET_TYPES,TARGET_IDS,...` matches META example 1. Other metadata points confirmed:
  - `ACTION` is deprecated and ignored, and `IS_PARTIAL_LANGUAGE` is optional.
  - `MDSTRUCTURE` takes `metadataflow` or `metadataprovision`.
  - Nested headers are dotted, multi-instance attributes take `[]` and multilingual ones `[en;fr]`.
  - `MDSTRUCTURE[;]` is needed for multiple targets, multi-instance or multi-language values.
  - `METADATASET_ID` has the form `AGENCY:ID(VERSION)` and the version may be omitted (example 6 uses `OECD:MDS`), so the non-versioned `WB.AFW360:MDS_SURVEY_<id>` conforms.
  - A metadataset may have several targets, separated by the sub-field separator.
  - One metadataset per row matches "each row contains the information related to one specific metadataset".
  - Cheatsheet 14 is correct apart from the Row example (R-B-2) and the quoting note (R-B-10).
- pysdmx 1.20.0 is the latest release on PyPI and requires Python >= 3.9. Its CSV detection sends a `STRUCTURE`/`STRUCTURE_ID` header to the SDMX-CSV 2.1 data reader, which maps `R` to `ActionType.Replace` (`__csv_aux_reader.py` lines 7 to 11). So data files can be read.

## Not checked

- Whether `R` exists in SDMX-CSV 2.0.0, as D38 states. Only the v2.1.0 guides were fetched.
- How pysdmx behaves on data files beyond flavour detection, `ACTION` mapping and NaN handling. I read the source but did not execute it, because installing was not allowed.
- Whether FMR accepts any of the forms above.
