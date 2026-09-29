## 0.3.0 (unreleased)

SDMX 3.1 alignment (standard v0.6); migrated from 0.2.0 by `pipeline/migrations/0.3.0/migrate.R`. `structure/DSD_AFW360_HH.csv` is rewritten to the 34 components of the SDMX data structure; new `structure/ARTEFACTS.csv` and `codelists/CL_FREQ.csv`; `CL_UNIT.csv` is renamed `CL_UNIT_MEASURE.csv`; every codelist gains `global_urn`; `CL_AGE` `Y_LT15` becomes `Y0T14`; `CL_OBS_STATUS` takes the SDMX names; `CL_UNIT_MEASURE` gains `XOF`.

- D27: target the SDMX 3.1 family: SDMX-CSV 2.1.0 for data and reference metadata, SDMX-ML 3.1.0 for structures.
- D28: the CSVs under `metadata/`, `content/` and `data/` are the source of truth; SDMX-ML is generated, committed and checked for staleness.
- D29: SDMX-ML 3.1 only; no SDMX-JSON.
- D30: the pipeline stays R and writes and XSD-validates the XML; Python only in the dashboard loader and in the separate verification tool `tools/verify/` (pysdmx).
- D31: agency id `WB.AFW360`, a sub-agency of the registered World Bank agency `WB`, declared in a project `WB:AGENCIES(1.0)` scheme.
- D32: project codes aligned to global code values where a global list exists (SDMX, IAEG-SDGs, WB), by value where the code rule allows, otherwise by the `GLOBAL_CODE` annotation; codelists gain `global_urn`.
- D33: nine measures: `OBS_VALUE`, `STD_ERR`, `CI_LOWER`, `CI_UPPER`, `N_OBS`, `N_POP`, `N_OBS_NUM`, `DEFF`, `DF`.
- D34: a `FREQ` dimension, first, always `A`, coded by the new `CL_FREQ` aligned to SDMX `CL_FREQ`.
- D35: FMR round-trip without Docker (Tomcat 10.1 and the FMR 12 WAR on Java 21), or FMR as a later step with FMR-loadable files.
- D36: everything is published as plain files in the repository (`sdmx/`, `data/`); no live registry or REST service.
- D37: the dashboard reads `data/`, `metadata/`, `content/`, `geo/` and `assets/` through a single loader; `index.qmd` stops reading `data_raw/`.
- D38: `ACTION` is `R` (replace) in every published data file.
- D39: `OBS_VALUE` is `NaN` on rows whose `OBS_STATUS` is `O` or `M`; optional measures and attributes a source cannot supply are empty; mandatory attributes are never empty.
- D40: every SDMX artefact carries the version in `metadata/VERSION`; a released version is immutable; edits between releases happen on a `-draft` copy.
- D41: codelist CSV columns map to SDMX by convention: `code`, `name_en`, `definition_en`, `parent`, `global_urn` (annotation `GLOBAL_CODE`), every other column an annotation `AFW_<COLUMN>`.
- D42: sentinels `_T` and `_Z` are added by the generator as real codes and stripped by the importer; they never appear in the CSV codelists.
- D43: registries become codelists plus metadatasets: `CL_SOURCE`, `CL_SURVEY`, `CL_FIGURE`, with descriptive columns as metadata attributes of `MSD_AFW360`; `SERIES_PLAN.csv` derives no codelist, and `SERIES_ID` is an uncoded mandatory `String` attribute (series ids contain dots, which the SDMX `IDType` forbids) whose values the project validator checks against `SERIES_PLAN.csv`.
- D44: new `structure/ARTEFACTS.csv` lists every SDMX artefact to generate, with its name and description.
- D45: project-only metadata stays CSV, documented as tooling metadata outside SDMX; no VTL and no DataConstraint in this release.
- D46: data file column order follows the DSD: fixed columns, dimensions, `TIME_PERIOD`, measures, attributes; 37 columns, 19-column key.
- Generated from this version by `pipeline/build_sdmx.R`: `sdmx/structures/AFW360_structures.xml`, one SDMX-ML 3.1 structure message with 32 maintainables (agency scheme, 22 codelists, concept scheme `CS_AFW360` with 82 concepts, `DSD_AFW360_HH`, dataflow `AFW360_HH`, `MSD_AFW360`, metadataflow `MDF_AFW360`, data and metadata provider schemes, provision agreements `PA_AFW360_HH` and `MPA_AFW360`), and four SDMX-CSV 2.1 metadata messages `sdmx/metadata/MDS_*.csv`.
- `data/` regenerated as SDMX-CSV 2.1 data messages; every value unchanged (reconciliation and the 0.2.0 projection match).
- `pipeline/import_sdmx.R` reads a structure message back into these CSVs; the round trip is byte-identical.
- The validator gains six `SDMX.*` checks (`pipeline/R/validate_sdmx.R`).
- Fusion Metadata Registry 12.4.2 rejects SDMX-ML 3.1; it loads the SDMX-ML 3.0 profile (`build_sdmx.R --sdmx-ml-version 3.0`, without the MSD, metadataflow and metadata agreement) once the `WB` agency is registered, validates both data files unchanged, and its 3.0 export imports with an empty diff.
