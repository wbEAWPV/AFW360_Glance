# Template: work-package task card

Every WP card in `.docs/transition/work-packages.qmd` follows this structure exactly, so an implementer, a verifier and the orchestrator can all find the same information in the same place. One card per package (`WP00`–`WP15`). Fields are fixed; omit none — write "None" or "N/A" rather than dropping a field.

## Structure

```markdown
## WPNN: <title> {#sec-wpNN}

**Goal.** One or two sentences: what exists after this package that did not before.

**Wave.** W0 | W1 | W2 | W3 | W4

**Model.** Sonnet

**Depends on.** WPNN, WPNN (packages whose merged output this one reads; "None" for W0/W1 packages with no upstream dependency)

**Read first.**

- `.docs/data-standard.qmd`, sections: <the specific @sec- anchors this WP needs, not the whole document>
- `.docs/transition/decisions.qmd` (hard cases relevant to this WP, by id)
- Any other card or contract file this WP's steps depend on

**Inputs.**

- <exact paths this WP reads: `data_raw/...`, `metadata/codelists/...`, contract CSVs, etc. — paths, not descriptions>

**Owned outputs.** (must match the rows this WP adds to `.docs/transition/contract/output_ownership.csv` — nothing written outside this list)

- `<exact path>` — <one line: what it is>
- `<exact path>` — <one line: what it is>

**Steps.**

1. <imperative, mechanical, in order — an implementer should not have to infer intent>
2. ...

**Acceptance checks.** (numbered, mechanical, each independently checkable from raw inputs + this WP's own outputs; each gets an id `WPNN.A<n>` used verbatim in the verifier's acceptance script and report)

1. `WPNN.A1` — <a fact that is true iff the check passes, e.g. "every geo_code in CL_GEO.csv with scheme=ADM1 has exactly one feature in the matching gpkg layer">
2. `WPNN.A2` — ...

**Verifier focus.** What the verifier must trace independently, back to raw inputs (`data_raw/` or, before WP01 merges, the original `INPUT …` folders), rather than take on the implementer's word — e.g. which raw cells/files to re-derive a sample from, which counts to recompute from scratch.

**Changelog line (suggested).** One line for `metadata/CHANGELOG.md` under `## 0.1.0 (unreleased)`, in the implementer's voice, e.g. "Added CL_GEO and boundary packages for SEN and GNB ADM0/ADM1."

**Out of scope.** What this WP explicitly does NOT do, especially things adjacent enough to tempt an implementer (e.g. another WP's owned paths, a hard case this WP must leave DRAFT rather than resolve).
```

## Filled mini example

```markdown
## WP05: Geography {#sec-wp05}

**Goal.** `CL_GEO_SCHEME`, `CL_GEO` and boundary packages exist for SEN and GNB ADM0/ADM1, geometry-valid and sha256-registered.

**Wave.** W2

**Model.** Sonnet

**Depends on.** WP01 (data_raw layout), WP02 (standard v0.4), WP04 (CL_AREA.csv)

**Read first.**

- `.docs/data-standard.qmd` @sec-cl-geo, @sec-assets, @sec-maps-scope, @sec-geo-storage
- `.docs/transition/decisions.qmd`: none open for this WP (P-codes and scheme names are settled in the triage report)

**Inputs.**

- `data_raw/shp/sen_admin*.shp`, `data_raw/shp/gnb_admin*.shp` (plain, non-`_em` shapefiles)
- `metadata/codelists/CL_AREA.csv` (from WP04, for `ref_area` = SN, GW)

**Owned outputs.**

- `metadata/codelists/CL_GEO_SCHEME.csv` — spatial schemes per country (ADM0, ADM1, ZONES/AEZ)
- `metadata/codelists/CL_GEO.csv` — spatial units, one row per geo_code
- `geo/GEO_SOURCES.csv` — registry of boundary files with sha256
- `geo/SEN_CODAB_v02.gpkg`, `geo/GNB_CODAB_V01.gpkg` — adm0 + adm1 layers, EPSG:4326

**Steps.**

1. Read the plain SEN and GNB admin shapefiles from `data_raw/shp/`; do not use the `_em` variants.
2. Rebuild geometry validity with `sf::sf_use_s2(FALSE)` + `sf::st_make_valid()`; SN01 (Dakar) and SN13 (Thiès) are known to fail s2/GEOS validity and need this.
3. Write one GeoPackage per country with `adm0` and `adm1` layers, CRS EPSG:4326.
4. Populate `CL_GEO` with one row per adm0/adm1 unit using the P-codes from the triage report (SN01–SN14, GW01–GW09, plus SN/GW for ADM0) and one row per ZONES/AEZ zone code (`SN_ZONES01`–`06`, `GW_AEZ01`–`04`) with `has_geometry = N` (no shapefile source for zones).
5. Populate `CL_GEO_SCHEME` (ADM0, ADM1 per country; ZONES for SEN, AEZ for GNB).
6. Compute sha256 of each gpkg and register it in `GEO_SOURCES.csv`.

**Acceptance checks.**

1. `WP05.A1` — Each gpkg has `adm0` and `adm1` layers; adm1 feature count is 14 (SEN) / 9 (GNB).
2. `WP05.A2` — The `geo_code` set in `CL_GEO` for scheme=ADM1 equals the P-code set in the matching gpkg layer, per country.
3. `WP05.A3` — Every feature is valid (`sf::st_is_valid`) and CRS is EPSG:4326.
4. `WP05.A4` — Exactly one feature per `geo_code` in each layer.
5. `WP05.A5` — `sha256` in `GEO_SOURCES.csv` matches `digest::digest(file=, algo="sha256")` of the registered gpkg.

**Verifier focus.** Recompute both gpkg sha256 values independently. Re-load the raw shapefiles from `data_raw/shp/` (not the gpkg) and independently count features and confirm the SN01/SN13 fix actually resolves invalidity under GEOS. Cross-check 10 random P-code-to-name pairs against the triage report's list.

**Changelog line (suggested).** Added CL_GEO_SCHEME, CL_GEO and boundary packages (GEO_SOURCES) for SEN and GNB ADM0/ADM1.

**Out of scope.** ZAE/AEZ zone geometries (no shapefile source; zone codes only, per @sec-maps-scope "maps exist for countries and ADM1 only"). Departement geography (skipped, D3). Indicator data itself (WP08/WP13).
```
