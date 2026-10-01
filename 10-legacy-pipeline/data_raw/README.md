# data_raw/

The legacy input files for the AFW 360 At A Glance dashboard, moved here byte-for-byte
from their original per-type folders at the repository root during the data
transition (see `.docs/transition.qmd`).

These files are kept exactly as received and are never edited. Any fix to what the
dashboard shows belongs in the code or presentation layer, not here.

## Subfolders

- `tables/` — `Tables_SEN.xlsx`, `Tables_GNB.xlsx`: the per-country indicator workbooks
  (sheets `National`, `ADM 1`, `ZAE`, `Departement`).
- `shp/` — the administrative boundary, line and capital shapefiles for both countries
  (`sen_admin*`, `gnb_admin*`, one file set per component: `.shp`, `.shx`, `.dbf`, `.prj`,
  `.cpg`).
- `text/` — `About.txt`, `About_SEN.txt`, `About_GNB.txt`, `Messages_SEN.txt`,
  `Messages_GNB.txt`: methodology and key-message text.
- `figures/` — `Fiscal Equity SEN.png`: the static fiscal-equity figure.
- `scratch/` — test and stray files kept for the record only: `Tables_SEN_TEST.xlsx`,
  `Messages_SEN.txt2`, `dsf.qqqww`, `map_test.png`. Nothing reads `scratch/`.

## Verifying the files

From the repository root:

```
sha256sum -c data_raw/CHECKSUMS.sha256
```

Every line should report `OK`. `CHECKSUMS.sha256` lists all 122 files, one
`<sha256 hash>  <path>` pair per line, sorted by path.
