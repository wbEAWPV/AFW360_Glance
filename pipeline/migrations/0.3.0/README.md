# Migration 0.2.0 -> 0.3.0

`migrate.R` rewrites `metadata/` from version 0.2.0 to 0.3.0, the metadata
release of data standard v0.6 (SDMX 3.1 alignment, decisions D27 to D46). It
follows D12: a structural change is made by a committed one-off script.

## How to run

From the repository root:

```
Rscript pipeline/migrations/0.3.0/migrate.R --root .
```

`--root` is the repository whose `metadata/` is read (default `.`). Without
`--out-root` the changes are applied in place. With `--out-root <dir>` every
file under `<root>/metadata/` is first copied to `<dir>/metadata/` and the
changes are applied there, so `<dir>/metadata/` holds the complete 0.3.0
metadata. The test `pipeline/tests/testthat/test-migrate-0.3.0.R` uses this on
the frozen 0.2.0 copy in `pipeline/tests/testthat/fixtures/metadata-0.2.0/` and
compares the result byte for byte with the committed `metadata/`.

## It runs once

The script refuses to run, writes nothing and exits 1 unless
`<root>/metadata/VERSION` is `0.2.0`. Every change is computed and checked in
memory before the first file is written. After it has run, `VERSION` is
`0.3.0`, so running it again is refused. The output is deterministic, UTF-8
without BOM, LF line endings, RFC 4180 CSV with minimal quoting.

## Inputs

Everything the script adds is authored in `inputs/`; the script holds no
names, descriptions or code values of its own.

- `DSD_AFW360_HH.csv`, `ARTEFACTS.csv`, `CL_FREQ.csv`: copied byte for byte.
- `ALIGNMENT.csv`: the code alignment (see `inputs/SOURCES.md`).
- `COLUMNS_0.3.0.csv`: the `structure/COLUMNS.csv` rows for the rewritten DSD
  file, `ARTEFACTS.csv` and `CL_FREQ.csv`; its `CL_FREQ.csv` `global_urn` row
  is the template for the `global_urn` row of every other codelist.
- `CHANGELOG_0.3.0.md`: the 0.3.0 entry of `CHANGELOG.md`.
- `SOURCES.md`: where the global codelists were fetched (documentation only).

## What it changes

New files:

- `structure/ARTEFACTS.csv`: the 33 SDMX artefacts to generate (D44).
- `codelists/CL_FREQ.csv`: code `A` (D34).

Changed files:

- `structure/DSD_AFW360_HH.csv`: rewritten to the 15-column layout and the
  34 components of the SDMX data structure (D33, D34, D46).
- `codelists/CL_UNIT.csv` renamed `codelists/CL_UNIT_MEASURE.csv`.
- Every `codelists/CL_*.csv` (19) gains `global_urn` as its last column (D32,
  D41).
- `ALIGNMENT.csv` applied: a row with an empty `code_0_2_0` adds the code
  (`status` DRAFT, `version_added` 0.3.0; today only `CL_UNIT_MEASURE.XOF`);
  any other row renames the code where `code_0_3_0` differs (`CL_AGE`
  `Y_LT15` becomes `Y0T14`; `parent` and `replaced_by` references in the same
  list follow), sets `name_en` and `definition_en` where the row fills them
  (empty keeps the 0.2.0 value) and sets `global_urn`. `CL_FREQ` rows are
  checked against `inputs/CL_FREQ.csv` rather than applied.
- `structure/COLUMNS.csv`: the DSD rows replaced; `ARTEFACTS.csv` rows added
  after the `COLUMNS.csv` rows; `CL_FREQ.csv` rows added before the first
  codelist; one `global_urn` row per codelist at position = previous column
  count + 1; `CL_UNIT.csv` becomes `CL_UNIT_MEASURE.csv` and every whole-word
  `CL_UNIT` in a description becomes `CL_UNIT_MEASURE`.
- `VERSION`: `0.3.0`; `CHANGELOG.md`: the 0.3.0 entry, before the 0.2.0 one.

`CL_INDICATOR.unit_measure` values are unchanged. The data files under `data/`
and the manifests are not touched here; the converter regenerates them.
