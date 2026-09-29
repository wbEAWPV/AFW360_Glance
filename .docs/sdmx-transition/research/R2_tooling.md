# SDMX 3.1 tooling survey (R 4.5 pipeline / Python 3.11 dashboard on Posit Connect)

All facts below were checked against a primary source (PyPI JSON API, CRAN, official docs, GitHub README/releases/changelog) on **2026-09-29**. Version/date next to each claim is what was observed on that date.

## 1. pysdmx (BIS, PyPI `pysdmx`)

Source: PyPI JSON API (pypi.org/pypi/pysdmx/json), docs at py.sdmx.io, GitHub bis-med-it/pysdmx.

- **Latest version**: 1.20.0, released **2026-09-18** (PyPI upload time; matches GitHub release `v1.20.0` published `2026-09-18T12:51:13Z`).
- **Python support**: PyPI metadata `requires_python = ">=3.9"`. **3.11 is supported** (no explicit trove classifiers restrict this; the repo's dev/docs tooling pins Sphinx dependencies specifically for Python 3.11, confirming it's an actively tested version).
- **Licence**: Apache-2.0 (PyPI `license` field and GitHub).
- **Information model**: implements SDMX 2.1, 3.0 and 3.1 (docs at py.sdmx.io explicitly list SDMX-ML 2.1/3.0/3.1 structure and data readers/writers).

**Formats read/written** (from `py.sdmx.io/api/io/general_reader.html`, `general_writer.html`, `sdmx_ml.html`, `sdmx_json.html`, `sdmx_csv.html`, fetched 2026-09-29):

| Format | Read | Write |
|---|---|---|
| SDMX-ML 2.1 Generic / Generic-TS / Structure-Specific / Structure-Specific-TS (data) | Yes | Yes |
| SDMX-ML 2.1 Structure | Yes | Yes |
| SDMX-ML 3.0 Structure-Specific (data) | Yes | Yes |
| SDMX-ML 3.0 Structure | Yes | Yes |
| SDMX-ML 3.1 Structure-Specific (data) | Yes | Yes |
| SDMX-ML 3.1 Structure | Yes | Yes |
| SDMX-JSON 2.0.0 Structure & Reference-Metadata message | Yes | Yes (`writer.v2_0`) |
| SDMX-JSON 2.1.0 Structure & Reference-Metadata message | Yes | Yes (`writer.v2_1`) |
| SDMX-CSV 1.0.0 | Yes | Yes |
| SDMX-CSV 2.0.0 | Yes | Yes |
| SDMX-CSV 2.1.0 | Yes | Yes |

Important nuance: **SDMX-JSON support in pysdmx is structure/reference-metadata only** — "Currently, with this format, only structural metadata and reference metadata are supported" (py.sdmx.io/api/io/sdmx_json.html). There is **no SDMX-JSON *data*-message** reader/writer; data is read/written via SDMX-ML or SDMX-CSV only. GitHub release notes confirm SDMX-JSON 2.1 JSON-Schema validation was added in v1.19.0 (2026-08-14): *"Validate SDMX-JSON 2.1 against the 2.1 JSON Schema"*, and *"Add SDMX-ML support for metadata structures and reference metadata"* — so MetadataStructureDefinition / Metadataset round-tripping through SDMX-ML is recent (v1.19.0+).

**Writing structural artefacts**: `pysdmx.io.write_sdmx()` takes any `MaintainableArtefact` (DataStructureDefinition, Codelist, ConceptScheme, Dataflow, MetadataStructureDefinition, etc.) plus `AvailabilityConstraint`, and serialises to `Format.STRUCTURE_SDMX_ML_{2_1,3_0,3_1}` or `Format.STRUCTURE_SDMX_JSON_{2_0_0,2_1_0}`. One caveat from the docs: the writer currently writes *one artefact at a time* and does not auto-pull in referenced/child objects — you pass them explicitly if you want them in the same message.

**DSD validation**: pysdmx's `read_sdmx(..., validate=True)` and equivalents perform **format-level validation only** — XSD validation for SDMX-ML (schemas fetched via the `sdmxschemas` helper package, PyPI `sdmxschemas` 1.1.0, "Python wrapper for SDMX Schemas") and JSON-Schema validation (via `jsonschema>=4.10`) for SDMX-JSON. This is **not** the same as validating data content against a DSD's codelists/mandatory components. For content-level (DSD) validation, the official tutorial (`py.sdmx.io/howto/validate.html`) shows a **manual** pattern: connect a `RegistryClient`/`AsyncRegistryClient` to an SDMX-REST-2.0.0+-compliant registry (the tutorial uses the BIS-hosted FMR-based SDMX Global Registry), call `get_schema()` to obtain a `Schema` object (components, data types, facets, codes, mandatory flags), then write your own loop checking each CSV row against `schema.components`. **No FMR is strictly required** — any SDMX-REST 2.0.0+ registry works, and a `Schema`-equivalent could in principle be built from a locally read DSD/Dataflow message — but there is **no single built-in "validate this file against this local DSD" call**; the check is DIY code following the documented pattern. Confidence: verified (format-level XSD/JSON-Schema validation) / partly verified (that Schema can be built without any network registry — the documented path uses a registry client).

## 2. sdmx1 (PyPI `sdmx1`, GitHub khaeru/sdmx)

Source: PyPI JSON API, `doc/index.rst`, `doc/implementation.rst`, `doc/whatsnew.rst`, `api/format.html` (pinned to `v2.27.0`), all fetched 2026-09-29.

- **Latest version**: 2.27.0, released **2026-08-06** (PyPI upload time).
- **Python support**: PyPI `requires_python = ">=3.10"`; classifiers explicitly list 3.10, 3.11, 3.12, 3.13, 3.14. **3.11 supported.**
- **Licence**: Apache-2.0 (classifier + GitHub README statement).
- **Information model**: SDMX 2.1 and **3.0.0 only**. Official doc quote (`implementation.rst`, fetched today): *"SDMX 2.1 and 3.0.0 are implemented ... with exhaustive implementation as the design goal."* SDMX 2.0 is explicitly **not** implemented, "no implementation currently planned."

**What is explicitly NOT supported for SDMX 3.x** (direct quotes from `implementation.rst`, current `main` branch, matching the released 2.27.0 line):
- *"Writing SDMX-ML 3.0.0"* — not yet supported (SDMX-ML 3.0 is **read-only** in sdmx1).
- *"Reading and writing SDMX-JSON 2.0"* — not yet supported.
- **SDMX-CSV 2.1.0**: not supported. `api/format.html` documents reader/writer support only for SDMX-CSV 1.0 (write-only, added v2.9.0; **no CSV 1.0 reader** — "sdmx does not currently support reading SDMX-CSV 1.0") and SDMX-CSV 2.0.0 (reader added v2.19.0, writer added v2.23.0, and the writer only supports `Keys.none`).
- **SDMX-ML 3.1 / SDMX 3.1 generally**: essentially unimplemented. The one exception, per `whatsnew.rst` v2.26.0 (2026-04-04): *"Read `<structure:MetadataAttributeUsage>` from SDMX-ML 3.1"* — a single new class for one element, not general 3.1 support. No SDMX-JSON 2.1 or SDMX-CSV 2.1 support anywhere in the changelog.
- The package's own version-correspondence table (`implementation.rst`) marks the whole SDMX-3.1 row ("SDMX-REST / SDMX-CSV / SDMX-JSON / SDMX-ML" sub-version numbers) with **"?"** — the maintainers themselves note they haven't pinned down the 3.1 sub-standard versions yet.

Net: **sdmx1 is not a viable tool for producing or validating SDMX-ML 3.1 / SDMX-JSON 2.1 / SDMX-CSV 2.1.** It remains a strong, mature client for querying/reading from the ~30 SDMX 2.1 web services it knows about (Eurostat, OECD, World Bank, etc.) and for SDMX 2.1/3.0 data science workflows via pandas.

## 3. Fusion Metadata Registry (FMR), sdmx.io / BIS Open Tech

Source: sdmx.io software pages, GitHub `bis-med-it/fmr-public` README, `fmrwiki.sdmx.io/12.4.2` changelog, Docker Hub `sdmxio/fmr-mysql` tags — all fetched 2026-09-29.

- **Lineage note** (verified via search of sdmx.org / Regnology press release): the original "Fusion Registry" product was built by **Metadata Technology (MetaTech)**, which was **acquired by Regnology in March 2023**. The BIS took over/forked the codebase and now publishes it as **Fusion Metadata Registry (FMR)** under the **BIS Open Tech** initiative, free to use. I found **no current "Community Edition" label** on the BIS product — it's simply called FMR and described as free. A commercially-branded "Fusion Registry Enterprise Edition" still appears to exist under the Regnology/MetaTech lineage (`demo11.metadatatechnology.com`), which is a **separate product**, not something confirmed to still originate from BIS's FMR. Treat "Community Edition by MetaTech" as historical framing — the currently maintained free tool is BIS's FMR.
- **Latest version**: **12.4.2**, released **2026-09-19** (FMR changelog, `fmrwiki.sdmx.io/12.4.2/reference/changelogs/ChangelogFMR/`). The static download page (`sdmx.io/software/fmr/download/`) lists 12.4.0 (31 Aug 2026) as its newest WAR download at time of fetch — it lags the changelog/Docker tags by a couple of patch releases (12.4.1, 12.4.2 are on GitHub releases and Docker Hub already).
- **Cost/licence**: "free to use" per BIS/sdmx.io and the GitHub README. **Source code is not publicly published** in `bis-med-it/fmr-public` (no LICENSE file found there; that repo only carries docs/release pointers) — full source access requires emailing `contact.sdmx.io@bis.org`. I could not verify a specific OSS licence (e.g., Apache-2.0) for the FMR source itself from a primary source; treat any such claim as unverified.
- **How it's run**: Docker (primary path) — `docker run --name fmr -p 8080:8080 sdmxio/fmr-mysql:latest` (GitHub README, verbatim). Docker Hub `sdmxio/fmr-mysql` current tags observed: **12.4.2** (~9 days old), 12.4.1, 12.4.0, 12.3.0, 11.25.3 — a self-contained image bundling MySQL, suited to testing/personal/light production use. Without Docker: deploy the WAR to a Java application server. **FMR 12 requires OpenJDK 21 (recommended) and Apache Tomcat 10.1+ ("FMR 12 requires Apache Tomcat 10.1 and later")**; the older FMR 11 line (maintained with security patches only until end 2026) needs OpenJDK 17 and Tomcat 9 (won't run on Tomcat 10+). DB options: MySQL 5.7/8, MariaDB, SQL Server, Oracle.
- **SDMX versions/formats imported & exported**: per FMR's own changelog (all entries reviewed back to 2023, none mention "3.1" or "SDMX-JSON 2.1"), FMR imports/exports **SDMX-ML 2.0/2.1/3.0, SDMX-JSON 1.0/2.0, SDMX-CSV 1.0/2.0.0, plus SDMX-EDI**. **No evidence FMR accepts or exports SDMX-ML 3.1 or SDMX-JSON 2.1** as of v12.4.2 (2026-09-19) — this looks like a real capability gap versus pysdmx, which already supports 3.1/2.1.0.
- **SDMX-CSV validation**: FMR's `SdmxCsvData` doc page (fmrwiki.sdmx.io/12.4.2) confirms SDMX-CSV 1.0.0 and 2.0.0 import/export ("recommended" to use 2.0.0); **no mention of SDMX-CSV 2.1 support**. Validation happens via the **Data Validation Web Service**: `POST /ws/public/data/validate` (fmrwiki.sdmxcloud.org/Data_Validation_Web_Service), which accepts CSV, XLSX, SDMX-ML, SDMX-EDI ("any format for which there is a Data Reader"), takes a `Structure` header (URN of a Dataflow/DSD/Provision Agreement) and returns structural violations (disallowed dimension values, type mismatches, mandatory-component checks, etc.) — i.e., real DSD-content validation, not just well-formedness. An async variant exists too (Asynchronous Data Validation and Transformation Web Service, returns a polling token).
- **Format conversion**: FMR's REST data-query API does content-negotiated conversion between the formats it supports (SDMX-ML ⇄ SDMX-JSON ⇄ SDMX-CSV 1.0/2.0, Excel) since import and export share the same reader/writer stack; there's also a dedicated microservice line as of FMR 12.3.0 ("FMR-24: FMR data processing microservices / command line tools", "FMR-246: Data validation microservice"). No evidence of SDMX-CSV 2.1 in this conversion path.
- **Codelist CSV import**: yes, but it is a **tool-specific UI feature, not a standard SDMX format**. Via the Codelist Wizard (Items → Codelist → maintenance/cogs icon → step 2), you paste CSV text into a text box; a plain Codelist uses **4 columns**, a Template/Item-type Codelist uses **6** (to carry validity start/end period). Delimiter and import-language are chosen from dropdowns above the text area; values needing the delimiter must be quoted, embedded quotes doubled. This is FMR's own bulk-edit convenience format, unrelated to SDMX-CSV.

## 4. Other validators / converters

| Tool | SDMX 3.1 support | Notes | Source |
|---|---|---|---|
| Eurostat **SDMX Converter** | **No** | Format matrix on the Eurostat CROS page only lists SDMX 2.1 (Generic/Compact/Utility/Cross-Sectional), GESMES/TS, Excel, flat CSV — no SDMX-ML 3.0/3.1, no SDMX-JSON. | cros.ec.europa.eu/dashboard/sdmx-converter, fetched 2026-09-29 |
| **SDMX-RI** (SDMX Reference Infrastructure) | Not confirmed | Building blocks for dissemination from a data warehouse (Java/.NET); no 3.x claim found. | sdmx.org, cros.ec.europa.eu/dashboard/sdmx-ri |
| **SDMX TWG Test Compliance Kit** (`sdmx-twg/sdmx-tck`) | Unverified for 3.1 | Certifies **RESTful SDMX web-service** compliance (querying), not static file validation. GitHub API shows repo last pushed **2025-10-14** — roughly a year stale relative to SDMX 3.1 (finalised May 2025 per sdmx1 docs) and to today. An open GitHub issue (#16) discusses adding "API version >= 2.0.0" data-validity/availability query support, suggesting 3.0/3.1-era REST coverage was still being built out. Not directly useful for this project anyway (it tests a live REST endpoint, not a file). | github.com/sdmx-twg/sdmx-tck, GitHub API metadata |
| **XSD-based CLI validation for SDMX-ML 3.1** | **Yes, schemas exist** | Official XSDs are published and tagged in `sdmx-twg/sdmx-ml`; GitHub API confirms a **`v3.1.0`** tag exists alongside `v3.0.0`, `v2.1`, `v1.0.3`. Any standard XSD validator (`xmllint --schema`, `lxml.etree.XMLSchema`) can validate against these. pysdmx already wraps this (`validate=True` on `read_sdmx`/`write_sdmx` for SDMX-ML, using `lxml` + the `sdmxschemas` helper package), covering 2.1/3.0/**3.1**. sdmx1's `sdmx.validate_xml()`/`install_schemas()` helper, by contrast, only documents **2.1 and 3.0** (no 3.1) per its own how-to page. | api.github.com/repos/sdmx-twg/sdmx-ml/tags; py.sdmx.io/api/io/sdmx_ml.html; sdmx1.readthedocs.io/en/latest/howto/validate.html |
| **JSON-Schema validator for SDMX-JSON 2.1** | **Yes** | Official schemas published at `json.sdmx.org` (e.g. `https://json.sdmx.org/2.1/sdmx-json-structure-schema.json`, `.../sdmx-json-metadata-schema.json`) from `sdmx-twg/sdmx-json`. Any generic JSON-Schema validator (e.g. Python `jsonschema`) can be pointed at these. pysdmx already does exactly this internally (v1.19.0 release note: "Validate SDMX-JSON 2.1 against the 2.1 JSON Schema"). | github.com/sdmx-twg/sdmx-json; pysdmx v1.19.0 GitHub release notes |

## 5. R packages

Source: CRAN package pages (fetched 2026-09-29) and GitHub.

| Package | CRAN version | Published | Licence | Scope | 3.x evidence |
|---|---|---|---|---|---|
| **rsdmx** | 0.6-5 | 2025-02-27 | GPL-2 \| GPL-3 | Read-only client for SDMX-ML web services (Eurostat, OECD, etc.); description explicitly says "currently focusing on the SDMX XML standard format (SDMX-ML)," no CSV/JSON mention | None found — no NEWS/CRAN text claiming SDMX 3.x |
| **readsdmx** | 0.3.1 | 2023-09-02 | GPL-3 | Reads local/remote SDMX-ML into a data frame "as is," via a bundled RapidXML C++ parser | None found; last CRAN release predates most SDMX 3.0/3.1 tooling |
| **RJSDMX** (note capitalisation — CRAN package is `RJSDMX`, not `rjsdmx`; Bank of Italy) | 3.9.0 | 2026-04-09 | EUPL 1.1/1.2 | Java-backed (`rJava`, requires **Java ≥ 8**) client for querying SDMX web services into `zoo` time series; source at github.com/amattioc/SDMX | None found in CRAN description; adds a JVM dependency on top of R |

None of the three R SDMX packages document SDMX-ML 3.1, SDMX-JSON, or SDMX-CSV support, and none write/author SDMX structures — they are read/query-only. **No R package was found that claims SDMX 3.x support**, let alone 3.1.

**Practical options for writing SDMX-ML/JSON from R**, given the above gap:
1. **Hand-rolled templates** with `xml2` (for SDMX-ML) or `jsonlite`/`{jsonvalidate}` (for SDMX-JSON, `{jsonvalidate}` wraps the `ajv` JS validator and can check against the official 2.1 JSON-Schema files). This is unverified as a turnkey path — no package does the SDMX-aware templating for you; it would be DIY string/tree building against the XSD/JSON-Schema structure.
2. **`reticulate` + pysdmx**: since pysdmx supports Python ≥3.9 and R 4.5 machines can run a matching Python 3.11 venv (the same interpreter version already used by the dashboard), calling pysdmx's `write_sdmx()`/`read_sdmx()` from R via `reticulate::import("pysdmx")` is a credible route to get full SDMX-ML 3.1 / SDMX-JSON 2.1.0 / SDMX-CSV 2.1.0 read-write and XSD/JSON-Schema validation without leaving the R pipeline. This is **partly verified**: pysdmx's Python-side capabilities are directly confirmed (Section 1); the `reticulate` call pattern itself is standard practice but I did not find a project- or SDMX-specific write-up doing this exact integration, so treat the *combination* as unverified/untested, not the underlying pysdmx feature set.

## 6. Recommended minimal toolchain

| Step | Tool | Version (verified 2026-09-29) | Command / entry point | Confidence |
|---|---|---|---|---|
| (a) Generate SDMX-ML 3.1 and SDMX-JSON 2.1 structure files from CSV codelists | **pysdmx** | 1.20.0 | Build `Codelist`/`ConceptScheme`/`DataStructureDefinition` model objects (e.g. from a CSV you loop over with `csv`/pandas) then `pysdmx.io.write_sdmx(obj, sdmx_format=Format.STRUCTURE_SDMX_ML_3_1)` or `Format.STRUCTURE_SDMX_JSON_2_1_0` | Verified (write path exists and is documented with exact `Format` enum members) / partly verified (no built-in "CSV → Codelist" loader — you write the small mapping loop yourself) |
| (b) Validate those structure files | **pysdmx** (built-in) | 1.20.0 | `pysdmx.io.read_sdmx(path, validate=True)` — XSD validation for SDMX-ML 3.1 via `lxml`+`sdmxschemas`; JSON-Schema validation for SDMX-JSON 2.1.0 via `jsonschema`+`sdmxschemas` | Verified |
| (b, alt/independent check) | Official XSDs / JSON Schemas directly | `sdmx-ml` tag `v3.1.0`; `json.sdmx.org/2.1/*.json` | `xmllint --noout --schema SDMXStructure.xsd file.xml`, or Python `jsonschema.validate()` against the fetched schema | Verified (schemas exist and are tagged/published); the exact XSD entry-point filename inside the v3.1.0 tarball wasn't individually opened — treat file layout as partly verified |
| (c) Validate SDMX-CSV 2.1 data files against the DSD | **FMR** Data Validation Web Service | FMR 12.4.2 (Docker `sdmxio/fmr-mysql:12.4.2`) | `POST /ws/public/data/validate` with `Data-Format`/`Structure` headers and the CSV body/file | Partly verified — the endpoint, DSD-based checks and CSV acceptance are confirmed; **FMR's own SDMX-CSV support tops out at 2.0.0** in the docs reviewed, so validating a true **2.1.0** file may fail or be silently treated as 2.0.0 depending on FMR's format sniffing. This is a real risk, not just a documentation gap — verify empirically before relying on it. |
| (c, alternative) | **pysdmx** local schema-based checks | 1.20.0 | `read_sdmx(csv, validate=True)` (format sniffing/structural read for SDMX-CSV 2.1.0) plus the manual `Schema`-driven component/facet/code checks from `py.sdmx.io/howto/validate.html`, fed by a `RegistryClient` (FMR or any SDMX-REST 2.0.0+ registry) or a locally-read DSD | Partly verified — pysdmx definitely reads SDMX-CSV 2.1.0 and definitely supports the manual validation pattern; whether a fully offline (no registry call) `Schema` can be built from a local DSD file wasn't confirmed from the docs pages fetched |
| (d) Read SDMX-CSV 2.1 in a Python dashboard (Posit Connect, Python 3.11) | **pysdmx** | 1.20.0 (`pip install pysdmx[data]`) | `pysdmx.io.get_datasets(data="file.csv")` → `Sequence[PandasDataset]`, or `pysdmx.io.read_sdmx(...)` | Verified — `requires_python >=3.9` covers 3.11; SDMX-CSV 2.1.0 read is documented; returns pandas-ready objects, a natural fit for a dashboard |

Overall shape: **pysdmx is the load-bearing tool** for everything that touches SDMX 3.1/2.1.0/2.1.0 (ML/JSON/CSV) because it is, as of today, the only library in this survey that claims and documents that full trio. **FMR is the only DSD-content validator with a network service**, but its own format support currently lags pysdmx (stuck at SDMX-CSV 2.0.0, SDMX-ML 3.0, SDMX-JSON 2.0) — so for a pure "validate SDMX-CSV 2.1 against a DSD" need, pysdmx's own local schema-driven checks may end up doing more of the work than FMR does, or you downgrade to writing/validating SDMX-CSV 2.0.0 against FMR until it catches up. On the R side, there is no ready-made package, so either write CSV→SDMX-ML/JSON generation by hand with `xml2`, or bridge to pysdmx via `reticulate` (recommended, since it reuses the same code the Python dashboard would use, cutting duplication between the R pipeline and Python dashboard — this reuse benefit is my own inference, not a documented recommendation from any source).

## 7. Gaps — what the team would have to write themselves

1. **CSV-codelist → SDMX Codelist/ConceptScheme mapping code.** No tool in this survey reads an arbitrary flat CSV of codes and auto-produces a pysdmx `Codelist`/`ConceptScheme` object; FMR's CSV-paste importer is UI-only, tool-specific, and requires manual paste into its wizard (not scriptable via a documented REST endpoint in the pages reviewed). A small Python/R script mapping the project's CSV columns to `Code(id=..., name=...)` objects is needed regardless of which validator is used downstream.
2. **A genuinely offline, no-registry DSD-content validator.** pysdmx's documented validation pattern is registry-driven (`RegistryClient.get_schema()`); FMR's is a running server. Neither vendor documents a pure "load local DSD file, get local Schema object, validate local CSV offline, no server involved" one-call function in the pages this survey reached — building that (likely: read the local DSD with `pysdmx.io.read_sdmx`, then hand-write the same component/facet/code loop the tutorial shows, adapted to not require a `RegistryClient`) is on the team.
3. **SDMX-CSV 2.1 support gap in FMR.** If validation-by-FMR is wanted, either wait for FMR to add 2.1.0 support (not on its public roadmap in the changelog reviewed) or normalise to SDMX-CSV 2.0.0 before sending data to FMR, and treat pysdmx as the source of truth for anything genuinely 2.1-specific.
4. **R-side SDMX authoring.** No R package writes any SDMX format (all three read-only). If the R pipeline (R 4.5) must produce SDMX-ML/JSON/CSV itself rather than handing CSVs to the Python side, that's either hand-rolled `xml2`/`jsonlite` templating (unverified effort, no existing scaffolding found) or a `reticulate` bridge to pysdmx (feasible per each side's independently-verified facts, but the bridge itself is untested by any source I found).
5. **CI-style structural (XSD/JSON-Schema) validation for SDMX-ML 3.1 as a standalone CLI step**, independent of pysdmx's Python API — e.g., a plain `xmllint`-against-`sdmx-ml` v3.1.0-XSD step for a non-Python CI stage. The XSDs exist and are tagged, but no one publishes a ready CLI wrapper for this; the team would fetch the XSDs from the tag and invoke `xmllint` themselves.
6. **Verifying FMR's actual 3.1/2.1.0 posture empirically.** This survey relied on changelog silence as negative evidence ("no changelog entry mentions 3.1/2.1"), which is reasonably strong but not the same as reading FMR's source or running a live test against a v3.1 file. Before committing to FMR as a validation service, do one real `POST /ws/public/data/validate` test with an actual SDMX-CSV 2.1.0 file and confirm how it's handled (accepted as 2.1, silently downgraded, or rejected).

---

### Sources consulted (primary)
- pypi.org/pypi/pysdmx/json, pypi.org/pypi/sdmx1/json, pypi.org/pypi/sdmxschemas/json (PyPI JSON API, 2026-09-29)
- py.sdmx.io (start.html, api/io/general_reader.html, general_writer.html, sdmx_ml.html, sdmx_json.html, sdmx_csv.html, howto/validate.html, howto/io_structure.html, api/fmr.html) — fetched 2026-09-29
- github.com/bis-med-it/pysdmx (README.rst, pyproject.toml, releases v1.20.0/v1.19.0 via GitHub API) — fetched 2026-09-29
- sdmx1.readthedocs.io (doc/index.rst, doc/implementation.rst, doc/whatsnew.rst, api/format.html pinned to v2.27.0) — fetched 2026-09-29
- www.sdmx.io/software/fmr/, .../download/; github.com/bis-med-it/fmr-public README; fmrwiki.sdmx.io/12.4.2 (ChangelogFMR, SdmxCsvData); fmrwiki.sdmxcloud.org (Data_Validation_Web_Service, Codelists, Change_Log — legacy mirror); hub.docker.com/r/sdmxio/fmr-mysql/tags — fetched 2026-09-29
- cros.ec.europa.eu/dashboard/sdmx-converter, /sdmx-ri — fetched 2026-09-29
- github.com/sdmx-twg/sdmx-tck (GitHub API repo metadata), github.com/sdmx-twg/sdmx-ml (tags via GitHub API), github.com/sdmx-twg/sdmx-json — fetched 2026-09-29
- cran.r-project.org/web/packages/{rsdmx,readsdmx,RJSDMX}/index.html — fetched 2026-09-29
- sdmx.org, Regnology press release (Metadata Technology acquisition) — via web search, 2026-09-29
