# sdmx/

Generated SDMX files of the AFW 360 standard. Everything here is written by
`pipeline/build_sdmx.R` from the CSV source of truth under `metadata/` and
`content/`; nothing here is edited by hand. The files are committed and
checked for staleness.

## What is here

| Path | Format | Content |
|---|---|---|
| `structures/AFW360_structures.xml` | SDMX-ML 3.1 Structure message | Agency scheme, data and metadata provider schemes, concept scheme `CS_AFW360`, the codelists, the data structure `DSD_AFW360_HH` and dataflow `AFW360_HH`, the metadata structure `MSD_AFW360` and metadataflow `MDF_AFW360`, the provision agreements `PA_AFW360_HH` and `MPA_AFW360`. Agency `WB.AFW360`, version from `metadata/VERSION`. 32 maintainables at 0.3.0: 22 codelists, 82 concepts in one scheme. |
| `metadata/MDS_SURVEYS.csv` | SDMX-CSV 2.1 metadata message | One metadataset per row of `metadata/surveys/SURVEYS.csv`, target `codelist` `WB.AFW360:CL_SURVEY(<version>)`. |
| `metadata/MDS_SOURCES.csv` | SDMX-CSV 2.1 metadata message | One metadataset per row of `metadata/registries/SOURCES.csv`, target `codelist` `WB.AFW360:CL_SOURCE(<version>)`. |
| `metadata/MDS_TEXT.csv` | SDMX-CSV 2.1 metadata message | One metadataset per row of `content/TEXT.csv`, target `dataflow` `WB.AFW360:AFW360_HH(<version>)`. `TEXT.BODY` holds the Markdown: the `body` cell, or the content of `content/text/<file>` when `file` is set. |
| `metadata/MDS_FIGURES.csv` | SDMX-CSV 2.1 metadata message | One metadataset per row of `metadata/registries/FIGURES.csv`, target `codelist` `WB.AFW360:CL_FIGURE(<version>)`. |

The data messages (SDMX-CSV 2.1) are not here; they live in `data/`.

### Metadata messages

Each metadata file has the header
`MDSTRUCTURE,MDSTRUCTURE_ID,METADATASET_ID,TARGET_TYPES,TARGET_IDS`
followed by one column per child attribute of the MSD parent the registry
maps to, dotted as `<PARENT>.<CHILD>` (for example `SURVEY.SURVEY_NAME`).
The parents `SURVEY`, `SOURCE`, `TEXT` and `FIGURE` are presentational and
have no column of their own. Child ids are the registry column names
upper-cased; the id column and `status` (and `file` for `TEXT.csv`) are not
exported.

- `MDSTRUCTURE` is `metadataflow` and `MDSTRUCTURE_ID` is
  `WB.AFW360:MDF_AFW360(<version>)` on every row.
- `METADATASET_ID` is non-versioned: `WB.AFW360:MDS_SURVEY_<survey_id>`,
  `WB.AFW360:MDS_SOURCE_<source_id>`,
  `WB.AFW360:MDS_TEXT_<slot>_<ref_area>_<time_period>_<order>`,
  `WB.AFW360:MDS_FIGURE_<figure_id>`.
- Targets are whole artefacts (`TARGET_TYPES` is a REST structure resource
  name, `TARGET_IDS` is `AGENCY:ID(VERSION)`). The item a metadataset
  describes is identified by its `METADATASET_ID` and its key attributes
  (for example `SURVEY.REF_AREA`, `SURVEY.TIME_PERIOD`).
- Every field is quoted, embedded quotes are doubled and multi-line
  Markdown stays inside one quoted field (RFC 4180). Files are UTF-8 with LF
  line endings; empty values are `""`.

## How it is generated

From the repository root:

```sh
Rscript pipeline/build_sdmx.R --root .            # rewrite structures and metadata
Rscript pipeline/build_sdmx.R --root . --check    # exit 1 if any file here is stale
```

Options: `--out-root <dir>` writes or checks `<dir>/sdmx/` instead of the
repository's, and `--timestamp <ts>` sets the structure message's
`mes:Prepared` (default `2026-01-01T00:00:00Z`, so the output is
byte-for-byte reproducible). The structure message is validated against the
vendored XSD `pipeline/xsd/sdmx-ml-3.1/SDMXMessage.xsd` before it is written.
The code is in `pipeline/R/sdmx_xml.R`, `pipeline/R/sdmx_structures.R` and
`pipeline/R/sdmx_refmeta.R`.

After editing anything under `metadata/` or `content/TEXT.csv`, rerun the
build and commit the regenerated files with the source change.

`--sdmx-ml-version 3.0` writes the same structures as an SDMX-ML 3.0
message (the `v3_0` namespaces), the profile Fusion Metadata Registry 12.4
reads. It leaves out the MSD, the metadataflow and the metadata provision
agreement, and writes only the structure message. It is never committed: it needs an `--out-root` other
than the repository and takes no `--check`:

```sh
Rscript pipeline/build_sdmx.R --root . --sdmx-ml-version 3.0 --out-root tmp/v30
```

## How it is checked

The project validator (`pipeline/validate.R`) runs six `SDMX.*` checks from
`pipeline/R/validate_sdmx.R`: `SDMX.STALE` (every file here equals a fresh
build), `SDMX.XSD` (the structure message is valid against the vendored
3.1 XSD), `SDMX.URN` (every reference resolves inside the message),
`SDMX.IDENT` (agency, version, id and English name of every maintainable),
`SDMX.CSV_HEADER` (the data files' SDMX-CSV header and `STRUCTURE_ID`) and
`SDMX.SKIPPED` (reported when a trimmed root has no `sdmx/` folder).

Independent check (Python, verification only):

```sh
tools/verify/.venv/Scripts/python tools/verify/verify_sdmx.py --root .
```

It reads the structure message with pysdmx, validates it against the XSD
with lxml, reads the data messages in `data/`, and checks the header and
targets of each metadata file here. On the metadata files it is the weaker
reader: it matches a column header to an MSD attribute by the last dotted
segment only, and does not check `MDSTRUCTURE_ID`, `TARGET_TYPES` or the
uniqueness of `METADATASET_ID`. `SDMX.CSV_HEADER` and the build itself cover
the data files; for the metadata files the build is the reference.

## Loading into FMR

Fusion Metadata Registry (FMR) 12.4.2 is installed locally under
`tools/fmr/runtime/` (not committed). It rejects the SDMX-ML 3.1 structure
message here (error 150), so it is loaded with the 3.0 profile:

1. `Rscript tools/fmr/fmr_load.R --root .` registers the `WB` agency from
   `tools/fmr/agencies_bootstrap.xml` when FMR lacks it, builds the 3.0
   profile into `tmp/fmr/v30/` and submits it.
2. Validate the data files in `data/` against the dataflow
   `WB.AFW360:AFW360_HH(<version>)` (`tools/fmr/fmr_validate.R`); FMR takes
   the SDMX-CSV 2.1 files unchanged.
3. Export the structures (FMR exports SDMX-ML 3.0 only;
   `tools/fmr/fmr_export.R`) and bring changes back with
   `Rscript pipeline/import_sdmx.R --root . --diff <export.xml>`, then
   `--apply`. An unedited export gives an empty diff.

The four `metadata/MDS_*.csv` files are not loaded into FMR: the MSD and
the metadataflow they reference are not in the 3.0 profile. Start and stop
commands and the full workflow are in `.docs/fmr-guide.qmd`; install notes
in `tools/fmr/README.md`. Changes made in FMR go back to the CSV source
with `pipeline/import_sdmx.R`, never by editing the files here.
