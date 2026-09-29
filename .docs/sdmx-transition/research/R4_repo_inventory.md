# R4 — Repository inventory (AFW360_Glance, branch `dev/eb`, 2026-09-29)

Read-only inventory for planning the SDMX 3.1 conversion. Excluded: `data_raw/` contents (listed only), `.venv/`, `_site/`, `.quarto/`, `.docs/.quarto/` (Quarto cache, gitignored), `.claude/`, `node_modules/`. Counts from `wc -lc`; "lines" for `.gpkg`/`.png` is `bin`.

## 1. Tree

`data_raw/` (listed only, byte-frozen, D2): `CHECKSUMS.sha256`, `README.md`, `figures/Fiscal Equity SEN.png`, `scratch/{dsf.qqqww, map_test.png, Messages_SEN.txt2, Tables_SEN_TEST.xlsx}`, `shp/` (110 files: `sen_admin{0,1,2,3}[_em]`, `sen_admin{capitals,lines,lines_em,points}`, `gnb_admin{0,1,2}[_em]`, `gnb_admin{capitals,centroids,lines,lines_em}`, each .cpg/.dbf/.prj/.shp/.shx), `tables/{Tables_GNB.xlsx, Tables_SEN.xlsx}`, `text/{About.txt, About_GNB.txt, About_SEN.txt, Messages_GNB.txt, Messages_SEN.txt}`.

Not present although named in the standard's layout (`.docs/data-standard.qmd:109-176`): `pipeline/acceptance/`, `geo/derived/`, `content/SLOTS.csv` (declared "planned").

### .docs/ (29 files, 196,963 bytes)

| path | bytes | lines |
|---|---:|---:|
| `.docs/.gitignore` | 38 | 3 |
| `.docs/_quarto.yml` | 1649 | 50 |
| `.docs/data-standard.qmd` | 111272 | 1032 |
| `.docs/generated/tbl-brk-vars.md` | 1496 | 17 |
| `.docs/generated/tbl-cl-brk-var.md` | 706 | 12 |
| `.docs/generated/tbl-cl-geo.md` | 556 | 11 |
| `.docs/generated/tbl-cl-geo-scheme.md` | 980 | 16 |
| `.docs/generated/tbl-cl-indicator.md` | 1806 | 32 |
| `.docs/generated/tbl-columns.md` | 3626 | 35 |
| `.docs/generated/tbl-indicator-qualifiers.md` | 611 | 10 |
| `.docs/generated/tbl-initial-plan.md` | 823 | 12 |
| `.docs/generated/tbl-legacy-columns-csv.md` | 703 | 13 |
| `.docs/generated/tbl-legacy-labels.md` | 982 | 12 |
| `.docs/generated/tbl-legacy-overrides.md` | 652 | 12 |
| `.docs/generated/tbl-obs-status.md` | 993 | 11 |
| `.docs/generated/tbl-povlines.md` | 648 | 12 |
| `.docs/generated/tbl-qualifier-pairs.md` | 601 | 10 |
| `.docs/generated/tbl-qual-vars.md` | 675 | 10 |
| `.docs/generated/tbl-rules.md` | 1186 | 14 |
| `.docs/generated/tbl-series-plan.md` | 1096 | 13 |
| `.docs/generated/tbl-small-codelists.md` | 734 | 14 |
| `.docs/generated/tbl-sources.md` | 1278 | 18 |
| `.docs/generated/tbl-surveys.md` | 1392 | 29 |
| `.docs/generated/tbl-tab-plan.md` | 570 | 13 |
| `.docs/generated/tbl-text.md` | 659 | 13 |
| `.docs/input-tables-findings.qmd` | 19412 | 303 |
| `.docs/shiny-port-plan.md` | 30446 | 600 |
| `.docs/styles.css` | 1846 | 66 |
| `.docs/transition.qmd` | 9527 | 103 |

### data/ (4 files, 823,601 bytes)

| path | bytes | lines |
|---|---:|---:|
| `data/AFW360_HH_GNB_2021_SURVEY.csv` | 352870 | 2269 |
| `data/AFW360_HH_GNB_2021_SURVEY_manifest.csv` | 411 | 17 |
| `data/AFW360_HH_SEN_2021_SURVEY.csv` | 469909 | 3004 |
| `data/AFW360_HH_SEN_2021_SURVEY_manifest.csv` | 411 | 17 |

### metadata/ (34 files, 144,907 bytes)

| path | bytes | lines |
|---|---:|---:|
| `metadata/CHANGELOG.md` | 2786 | 42 |
| `metadata/codelists/CL_AGE.csv` | 387 | 5 |
| `metadata/codelists/CL_AREA.csv` | 194 | 3 |
| `metadata/codelists/CL_BRK_VAR.csv` | 3703 | 14 |
| `metadata/codelists/CL_COMP_BREAKDOWN.csv` | 9909 | 61 |
| `metadata/codelists/CL_ESTIMATION.csv` | 408 | 3 |
| `metadata/codelists/CL_GEO.csv` | 4866 | 36 |
| `metadata/codelists/CL_GEO_SCHEME.csv` | 980 | 7 |
| `metadata/codelists/CL_INDICATOR.csv` | 26352 | 63 |
| `metadata/codelists/CL_OBS_STATUS.csv` | 1087 | 8 |
| `metadata/codelists/CL_QUAL_VAR.csv` | 1660 | 7 |
| `metadata/codelists/CL_QUALIFIER.csv` | 6193 | 43 |
| `metadata/codelists/CL_SEX.csv` | 328 | 3 |
| `metadata/codelists/CL_STAT_UNIT.csv` | 387 | 5 |
| `metadata/codelists/CL_STATISTIC.csv` | 412 | 8 |
| `metadata/codelists/CL_THEME.csv` | 775 | 13 |
| `metadata/codelists/CL_UNIT.csv` | 753 | 13 |
| `metadata/codelists/CL_URBANISATION.csv` | 295 | 5 |
| `metadata/codelists/CL_WEIGHT.csv` | 360 | 5 |
| `metadata/plans/LEGACY_COLUMNS.csv` | 3491 | 74 |
| `metadata/plans/LEGACY_LABELS.csv` | 23660 | 180 |
| `metadata/plans/LEGACY_OVERRIDES.csv` | 2379 | 13 |
| `metadata/plans/SERIES_PLAN.csv` | 8192 | 92 |
| `metadata/plans/TAB_PLAN.csv` | 372 | 9 |
| `metadata/registries/FIGURES.csv` | 999 | 2 |
| `metadata/registries/GEO_SOURCES.csv` | 478 | 3 |
| `metadata/registries/SOURCES.csv` | 803 | 3 |
| `metadata/rules/RULES.csv` | 10793 | 131 |
| `metadata/structure/COLUMNS.csv` | 27102 | 348 |
| `metadata/structure/DSD_AFW360_HH.csv` | 2942 | 32 |
| `metadata/structure/INDICATOR_QUALIFIERS.csv` | 465 | 7 |
| `metadata/structure/QUALIFIER_PAIRS.csv` | 363 | 9 |
| `metadata/surveys/SURVEYS.csv` | 1027 | 3 |
| `metadata/VERSION` | 6 | 1 |

### content/ (2 files, 3,546 bytes)

| path | bytes | lines |
|---|---:|---:|
| `content/TEXT.csv` | 2008 | 9 |
| `content/text/SEN/about.md` | 1538 | 3 |

### geo/ (2 files, 4,034,560 bytes)

| path | bytes | lines |
|---|---:|---:|
| `geo/boundaries/GNB_CODAB_V01.gpkg` | 237568 | bin |
| `geo/boundaries/SEN_CODAB_v02.gpkg` | 3796992 | bin |

### assets/ (1 files, 102,826 bytes)

| path | bytes | lines |
|---|---:|---:|
| `assets/figures/SEN/SEN_FISCAL_EQUITY.png` | 102826 | bin |

### pipeline/ (81 files, 747,844 bytes)

| path | bytes | lines |
|---|---:|---:|
| `pipeline/bootstrap/build_breakdowns_qualifiers.R` | 6662 | 177 |
| `pipeline/bootstrap/build_geo_codelists.R` | 3942 | 113 |
| `pipeline/bootstrap/build_indicators.R` | 8674 | 269 |
| `pipeline/bootstrap/build_legacy_maps.R` | 12966 | 369 |
| `pipeline/bootstrap/build_plans.R` | 1901 | 53 |
| `pipeline/bootstrap/build_small_codelists.R` | 3745 | 112 |
| `pipeline/bootstrap/build_surveys.R` | 1619 | 44 |
| `pipeline/bootstrap/seeds/codes.csv` | 8492 | 177 |
| `pipeline/bootstrap/seeds/csv_headers.csv` | 26238 | 339 |
| `pipeline/bootstrap/seeds/geo_codes.csv` | 3064 | 36 |
| `pipeline/bootstrap/seeds/label_triage.csv` | 32601 | 180 |
| `pipeline/bootstrap/seeds/legacy_national_columns.csv` | 423 | 14 |
| `pipeline/bootstrap/seeds/legacy_overrides.csv` | 1590 | 13 |
| `pipeline/bootstrap/seeds/tab_plan.csv` | 317 | 9 |
| `pipeline/bootstrap/text/breakdowns_qualifiers_text.csv` | 20338 | 122 |
| `pipeline/bootstrap/text/figures_text.csv` | 799 | 2 |
| `pipeline/bootstrap/text/geo_schemes_text.csv` | 807 | 7 |
| `pipeline/bootstrap/text/indicators_text.csv` | 20749 | 63 |
| `pipeline/bootstrap/text/small_codelists_text.csv` | 3804 | 56 |
| `pipeline/bootstrap/text/surveys_text.csv` | 1027 | 3 |
| `pipeline/build_content.R` | 5831 | 173 |
| `pipeline/build_docs.R` | 1620 | 50 |
| `pipeline/build_geo.R` | 3637 | 107 |
| `pipeline/convert_legacy.R` | 3949 | 119 |
| `pipeline/migrations/0.2.0/migrate.R` | 31325 | 687 |
| `pipeline/migrations/0.2.0/README.md` | 3276 | 68 |
| `pipeline/R/codes.R` | 1883 | 59 |
| `pipeline/R/constants.R` | 1844 | 67 |
| `pipeline/R/content.R` | 3444 | 92 |
| `pipeline/R/convert_tables.R` | 20957 | 575 |
| `pipeline/R/ctx.R` | 6833 | 189 |
| `pipeline/R/docs.R` | 20663 | 554 |
| `pipeline/R/geo.R` | 3155 | 77 |
| `pipeline/R/io.R` | 6001 | 206 |
| `pipeline/R/manifest.R` | 2967 | 77 |
| `pipeline/R/plan.R` | 14273 | 373 |
| `pipeline/R/reconcile.R` | 24117 | 614 |
| `pipeline/R/validate_assets.R` | 12631 | 397 |
| `pipeline/R/validate_codes.R` | 22888 | 579 |
| `pipeline/R/validate_common.R` | 3478 | 96 |
| `pipeline/R/validate_coverage.R` | 20353 | 546 |
| `pipeline/R/validate_docs.R` | 1673 | 36 |
| `pipeline/R/validate_metadata.R` | 27292 | 637 |
| `pipeline/R/validate_rules.R` | 29924 | 782 |
| `pipeline/R/validate_structure.R` | 5540 | 152 |
| `pipeline/R/validate_text.R` | 7821 | 258 |
| `pipeline/R/validate_values.R` | 19880 | 523 |
| `pipeline/README.md` | 6824 | 136 |
| `pipeline/reconcile.R` | 2024 | 58 |
| `pipeline/tests/testthat.R` | 234 | 8 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/data_raw/CHECKSUMS.sha256` | 11857 | 122 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/CHANGELOG.md` | 1067 | 22 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/codelists/CL_AREA.csv` | 194 | 3 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/codelists/CL_BRK_VAR.csv` | 3703 | 14 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/codelists/CL_COMP_BREAKDOWN.csv` | 9909 | 61 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/codelists/CL_INDICATOR.csv` | 28332 | 63 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/codelists/CL_OBS_STATUS.csv` | 487 | 5 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/codelists/CL_QUAL_VAR.csv` | 1634 | 7 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/codelists/CL_QUALIFIER.csv` | 6246 | 43 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/plans/SERIES_PLAN.csv` | 4456 | 92 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/structure/COLUMNS.csv` | 23032 | 306 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/structure/DSD_AFW360_HH.csv` | 2153 | 27 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/surveys/SURVEYS.csv` | 1027 | 3 |
| `pipeline/tests/testthat/fixtures/metadata-0.1.0/metadata/VERSION` | 7 | 1 |
| `pipeline/tests/testthat/helper-data-fixture.R` | 6059 | 141 |
| `pipeline/tests/testthat/helper-temp-root.R` | 2087 | 64 |
| `pipeline/tests/testthat/test-codes.R` | 1267 | 34 |
| `pipeline/tests/testthat/test-content.R` | 4275 | 120 |
| `pipeline/tests/testthat/test-convert.R` | 17667 | 448 |
| `pipeline/tests/testthat/test-ctx.R` | 3267 | 87 |
| `pipeline/tests/testthat/test-docs.R` | 4403 | 108 |
| `pipeline/tests/testthat/test-geo.R` | 3045 | 79 |
| `pipeline/tests/testthat/test-io.R` | 3173 | 98 |
| `pipeline/tests/testthat/test-migrate-0.2.0.R` | 6916 | 160 |
| `pipeline/tests/testthat/test-plan.R` | 13732 | 341 |
| `pipeline/tests/testthat/test-reconcile.R` | 11293 | 333 |
| `pipeline/tests/testthat/test-validate-assets-text.R` | 9797 | 287 |
| `pipeline/tests/testthat/test-validate-core.R` | 33301 | 776 |
| `pipeline/tests/testthat/test-validate-coverage.R` | 26940 | 673 |
| `pipeline/tests/testthat/test-validate-rules.R` | 24621 | 600 |
| `pipeline/validate.R` | 5802 | 150 |

### root/ (7 files, 43,678 bytes)

| path | bytes | lines |
|---|---:|---:|
| `.gitattributes` | 500 | 16 |
| `.gitignore` | 304 | 23 |
| `.nojekyll` | 0 | 0 |
| `_quarto.yml` | 741 | 26 |
| `CLAUDE.md` | 3843 | 36 |
| `index.qmd` | 32313 | 1195 |
| `README.md` | 5977 | 117 |


## 2. Every CSV under metadata/, content/, data/ (manifests)

All metadata/content CSVs: UTF-8, comma, one header row, multi-valued fields space-separated, no newlines in cells (`{#sec-metadata}`, data-standard.qmd:390-396). Every codelist starts with the 7 common columns `code, name_en, definition_en, status, version_added, replaced_by, notes`. `metadata/VERSION` = `0.2.0`.

**`metadata/structure/COLUMNS.csv` explained.** 347 rows, header `file, position, column, status, description`. It is the column registry (change (aa), `{#sec-metadata}`, `{#sec-validation}` "Metadata files"): one row per (metadata/content file, column), giving the column's 1-based position, R/C/O status and description. It declares 33 files: all 18 `CL_*.csv`, `COLUMNS.csv` itself (5 rows, self-describing), `DSD_AFW360_HH.csv` (7), `INDICATOR_QUALIFIERS.csv` (6), `QUALIFIER_PAIRS.csv` (6), `RULES.csv` (10), `SERIES_PLAN.csv` (9), `TAB_PLAN.csv` (9), `LEGACY_COLUMNS.csv` (9), `LEGACY_LABELS.csv` (8), `LEGACY_OVERRIDES.csv` (8), `SOURCES.csv` (14), `GEO_SOURCES.csv` (16), `FIGURES.csv` (17), `SURVEYS.csv` (25), `TEXT.csv` (9). It does NOT declare the data files (those are declared by `DSD_AFW360_HH.csv`) nor the manifests (keys are hard-coded in `pipeline/R/manifest.R` `MANIFEST_KEYS`). Consumers: `vc_meta_header`/`vc_meta_required` (`pipeline/R/validate_metadata.R`), `.docs_tbl_file_columns` in `pipeline/R/docs.R` (generates the per-file column tables of the standard), migration `migrate.R` rewrites it. **Cross-check done:** for every declared file, the declared column list equals the actual header exactly (same names, same order); no metadata/content CSV is undeclared. The `file` column holds bare file names (e.g. `CL_GEO.csv`), not paths.

Per-file inventory (row counts exclude header; first-row values truncated at 50 characters, empty cells omitted):

**`metadata/codelists/CL_AGE.csv`**: 4 rows. Purpose: Small codelist: age of the individual counted {#sec-small-codelists}

- Header (7): `code, name_en, definition_en, status, version_added, replaced_by, notes`
- First row (non-empty cells, truncated at 50 chars): code=`Y_LT15` · name_en=`Under 15` · definition_en=`The individual counted is under 15 years of age.` · status=`DRAFT` · version_added=`0.1.0`

**`metadata/codelists/CL_AREA.csv`**: 2 rows. Purpose: Countries, with iso2 (P-code prefix), ISO 4217 currency, wb_region {#sec-cl-area}

- Header (10): `code, name_en, definition_en, status, version_added, replaced_by, notes, iso2, currency, wb_region`
- First row (non-empty cells, truncated at 50 chars): code=`SEN` · name_en=`Senegal` · definition_en=`Senegal.` · status=`DRAFT` · version_added=`0.1.0` · iso2=`SN` · currency=`XOF` · wb_region=`AFW`

**`metadata/codelists/CL_BRK_VAR.csv`**: 13 rows. Purpose: Breakdown variables (describes, applies_to_units, universe, partition, requires_qual, slot_order) {#sec-cl-brk-var}

- Header (15): `code, name_en, definition_en, status, version_added, replaced_by, notes, describes, applies_to_units, universe, classification, partition, requires_qual, slot_order, owner`
- First row (non-empty cells, truncated at 50 chars): code=`QUINT` · name_en=`Consumption quintile` · definition_en=`Quintile (fifth) of household consumption per capi…` · status=`DRAFT` · version_added=`0.1.0` · notes=`Ranking level (national vs. within-area) and weigh…` · describes=`HH` · applies_to_units=`IND HH HE` · universe=`All households` · partition=`Y` · slot_order=`10` · owner=`AFW DIP/POV team`

**`metadata/codelists/CL_COMP_BREAKDOWN.csv`**: 60 rows. Purpose: Breakdown categories, linked by var_code {#sec-cl-comp-breakdown}

- Header (10): `code, name_en, definition_en, status, version_added, replaced_by, notes, var_code, parent, order`
- First row (non-empty cells, truncated at 50 chars): code=`QUINT_Q1` · name_en=`Quintile 1 (poorest)` · definition_en=`Poorest fifth of the consumption-per-capita distri…` · status=`DRAFT` · version_added=`0.1.0` · var_code=`QUINT` · order=`1`

**`metadata/codelists/CL_ESTIMATION.csv`**: 2 rows. Purpose: How a value was produced: SURVEY or MODEL (D17) {#sec-estimation-method}

- Header (7): `code, name_en, definition_en, status, version_added, replaced_by, notes`
- First row (non-empty cells, truncated at 50 chars): code=`SURVEY` · name_en=`Survey estimate` · definition_en=`A direct estimate from the survey microdata of the…` · status=`DRAFT` · version_added=`0.2.0`

**`metadata/codelists/CL_GEO.csv`**: 35 rows. Purpose: Spatial units (P-codes, or <ISO2>_<SCHEME><nn>) with boundary vintage {#sec-cl-geo}

- Header (14): `code, name_en, definition_en, status, version_added, replaced_by, notes, ref_area, scheme, parent, source_id, geom_layer, valid_from, valid_to`
- First row (non-empty cells, truncated at 50 chars): code=`SN` · name_en=`Sénégal` · definition_en=`ADM0 unit of SEN in boundary source SEN_CODAB_v02` · status=`DRAFT` · version_added=`0.1.0` · notes=`Geometry-only; no legacy source column (gap k). GE…` · ref_area=`SEN` · scheme=`ADM0` · source_id=`SEN_CODAB_v02` · geom_layer=`adm0` · valid_from=`2024-05-20`

**`metadata/codelists/CL_GEO_SCHEME.csv`**: 6 rows. Purpose: Spatial schemes per country; parallel, not nested {#sec-cl-geo}

- Header (12): `code, name_en, definition_en, status, version_added, replaced_by, notes, ref_area, local_name_en, has_geometry, nests_in, partition`
- First row (non-empty cells, truncated at 50 chars): code=`ADM0` · name_en=`Country` · definition_en=`Whole territory of Senegal (national level).` · status=`DRAFT` · version_added=`0.1.0` · ref_area=`SEN` · local_name_en=`Country` · has_geometry=`Y` · partition=`Y`

**`metadata/codelists/CL_INDICATOR.csv`**: 62 rows. Purpose: The indicator dictionary {#sec-cl-indicator}

- Header (35): `code, name_en, definition_en, status, version_added, replaced_by, notes, short_name_en, theme, stat_unit, universe_unit, universe_filter, numerator, statistic, weight, ref_period, excluded_breakdowns, unit_measure, unit_denom, unit_time, price_basis, price_ref_year, display_as, decimals, valid_min, valid_max, higher_is, sdg_indicator, classification, related, related_note, source_questionnaire, source_vars, program, owner`
- First row (non-empty cells, truncated at 50 chars): code=`AGR_CULT_AREA` · name_en=`Cultivated area` · definition_en=`Area of land cultivated by the household, in hecta…` · status=`DRAFT` · version_added=`0.1.0` · notes=`H19: values above 100 ha (the valid_max) are withh…` · short_name_en=`Cultivated area` · theme=`AGR` · stat_unit=`HH` · universe_unit=`HH` · statistic=`MEAN` · weight=`HH` · ref_period=`INTERVIEW` · unit_measure=`HA` · display_as=`NUMBER` · decimals=`2` · valid_min=`0` · valid_max=`100` · higher_is=`NEUTRAL` · source_questionnaire=`TBD` · source_vars=`TBD` · program=`TBD` · owner=`AFW DIP/POV team`

**`metadata/codelists/CL_OBS_STATUS.csv`**: 7 rows. Purpose: Observation status codes, precedence M O E D U A (D22) {#sec-values}

- Header (7): `code, name_en, definition_en, status, version_added, replaced_by, notes`
- First row (non-empty cells, truncated at 50 chars): code=`A` · name_en=`Normal value` · definition_en=`A normal value.` · status=`DRAFT` · version_added=`0.1.0`

**`metadata/codelists/CL_QUALIFIER.csv`**: 42 rows. Purpose: Qualifier categories (value, basis, order) {#sec-cl-qual}

- Header (11): `code, name_en, definition_en, status, version_added, replaced_by, notes, var_code, value, basis, order`
- First row (non-empty cells, truncated at 50 chars): code=`WELFARE_CONS_PC` · name_en=`Consumption per capita` · definition_en=`Household consumption expenditure divided by house…` · status=`DRAFT` · version_added=`0.1.0` · var_code=`WELFARE` · order=`1`

**`metadata/codelists/CL_QUAL_VAR.csv`**: 6 rows. Purpose: Qualifier variables (slot_order, requires) {#sec-cl-qual}

- Header (10): `code, name_en, definition_en, status, version_added, replaced_by, notes, slot_order, requires, owner`
- First row (non-empty cells, truncated at 50 chars): code=`WELFARE` · name_en=`Welfare aggregate` · definition_en=`Welfare aggregate the measure is built on: consump…` · status=`DRAFT` · version_added=`0.1.0` · slot_order=`10` · owner=`AFW DIP/POV team`

**`metadata/codelists/CL_SEX.csv`**: 2 rows. Purpose: Small codelist: sex of the individual counted {#sec-small-codelists}

- Header (7): `code, name_en, definition_en, status, version_added, replaced_by, notes`
- First row (non-empty cells, truncated at 50 chars): code=`F` · name_en=`Female` · definition_en=`The individual counted is female. Refers to the se…` · status=`DRAFT` · version_added=`0.1.0`

**`metadata/codelists/CL_STATISTIC.csv`**: 7 rows. Purpose: Small codelist: statistic, with admits_se {#sec-small-codelists}

- Header (8): `code, name_en, definition_en, status, version_added, replaced_by, notes, admits_se`
- First row (non-empty cells, truncated at 50 chars): code=`PROPORTION` · name_en=`Proportion` · definition_en=`A proportion.` · status=`DRAFT` · version_added=`0.1.0` · admits_se=`Y`

**`metadata/codelists/CL_STAT_UNIT.csv`**: 4 rows. Purpose: Small codelist: statistical unit counted {#sec-small-codelists}

- Header (7): `code, name_en, definition_en, status, version_added, replaced_by, notes`
- First row (non-empty cells, truncated at 50 chars): code=`IND` · name_en=`Individuals` · definition_en=`The statistic counts individuals.` · status=`DRAFT` · version_added=`0.1.0`

**`metadata/codelists/CL_THEME.csv`**: 12 rows. Purpose: Small codelist: themes {#sec-small-codelists}

- Header (7): `code, name_en, definition_en, status, version_added, replaced_by, notes`
- First row (non-empty cells, truncated at 50 chars): code=`POV` · name_en=`Poverty` · definition_en=`Indicators about poverty.` · status=`DRAFT` · version_added=`0.1.0`

**`metadata/codelists/CL_UNIT.csv`**: 12 rows. Purpose: Small codelist: units of the dictionary {#sec-small-codelists}

- Header (7): `code, name_en, definition_en, status, version_added, replaced_by, notes`
- First row (non-empty cells, truncated at 50 chars): code=`SHARE` · name_en=`Share` · definition_en=`A share from 0 to 1, never 0 to 100.` · status=`DRAFT` · version_added=`0.1.0`

**`metadata/codelists/CL_URBANISATION.csv`**: 4 rows. Purpose: Small codelist: residence, with parent (CAP, OU children of U) {#sec-small-codelists}

- Header (8): `code, name_en, definition_en, status, version_added, replaced_by, notes, parent`
- First row (non-empty cells, truncated at 50 chars): code=`U` · name_en=`Urban` · definition_en=`The area is urban.` · status=`DRAFT` · version_added=`0.1.0`

**`metadata/codelists/CL_WEIGHT.csv`**: 4 rows. Purpose: Small codelist: weights {#sec-small-codelists}

- Header (7): `code, name_en, definition_en, status, version_added, replaced_by, notes`
- First row (non-empty cells, truncated at 50 chars): code=`POP` · name_en=`Population weight` · definition_en=`Household weight times household size, for person-…` · status=`DRAFT` · version_added=`0.1.0`

**`metadata/plans/LEGACY_COLUMNS.csv`**: 73 rows. Purpose: Maps each legacy Excel column to breakdown dimensions {#sec-legacy-maps}

- Header (9): `ref_area, sheet, column, cut_id, GEO, URBANISATION, COMP_BREAKDOWN, action, notes`
- First row (non-empty cells, truncated at 50 chars): ref_area=`SEN` · sheet=`National` · column=`estimateTotal` · cut_id=`TOTAL` · action=`MAP`

**`metadata/plans/LEGACY_LABELS.csv`**: 179 rows. Purpose: Maps each legacy Excel label to a series / action (MAP, DUPLICATE_OF, DERIVED, SKIP) {#sec-legacy-maps}

- Header (8): `legacy_label, sheet, action, series_id, duplicate_of, scale, assert_rule, notes`
- First row (non-empty cells, truncated at 50 chars): legacy_label=`Access to electricity (grid, SDG 7.1.1)` · sheet=`*` · action=`MAP` · series_id=`EN_ELEC_ACCESS` · scale=`1` · notes=`H7: sdg_indicator 7.1.1; distinguish from EN_GRID_…`

**`metadata/plans/LEGACY_OVERRIDES.csv`**: 12 rows. Purpose: Withheld (WITHHOLD) or commented (COMMENT) legacy cells (D5) {#sec-legacy-maps}

- Header (8): `ref_area, sheet, column, legacy_label, action, obs_comment, reason, evidence`
- First row (non-empty cells, truncated at 50 chars): ref_area=`GNB` · sheet=`National` · column=`estimateCapital` · legacy_label=`*` · action=`WITHHOLD` · reason=`The column is a copy of the zone Zonas_Costeiras_d…` · evidence=`equal to ZAE estimateZonas_Costeiras_do_Sul on 97 …`

**`metadata/plans/SERIES_PLAN.csv`**: 91 rows. Purpose: Explicit list of series to produce, with display name, estimation, status (D13, D17, D23) {#sec-series-plan}

- Header (9): `series_id, ref_area, INDICATOR, MEASURE_QUALS, DEFINING_BREAKDOWN, name_en, estimation, status, notes`
- First row (non-empty cells, truncated at 50 chars): series_id=`AGR_CULTIVATES` · ref_area=`ALL` · INDICATOR=`AGR_CULTIVATES` · name_en=`Cultivates land` · estimation=`SURVEY` · status=`DRAFT`

**`metadata/plans/TAB_PLAN.csv`**: 8 rows. Purpose: Which cuts are produced {#sec-tab-plan}

- Header (9): `cut_id, ref_area, geo_scheme, urbanisation, sex, age, comp_breakdowns, themes, status`
- First row (non-empty cells, truncated at 50 chars): cut_id=`TOTAL` · ref_area=`ALL` · geo_scheme=`_T` · urbanisation=`_T` · sex=`_T` · age=`_T` · themes=`ALL` · status=`DRAFT`

**`metadata/registries/FIGURES.csv`**: 1 rows. Purpose: Figure registry (id, captions, alt text, file, sha256) {#sec-figures}

- Header (17): `figure_id, ref_area, time_period, theme, title_en, caption_en, alt_text_en, indicators, source, producer, program, licence, file, sha256, status, version_added, notes`
- First row (non-empty cells, truncated at 50 chars): figure_id=`SEN_FISCAL_EQUITY` · ref_area=`SEN` · time_period=`2021` · theme=`FISC` · title_en=`Fiscal incidence of taxes and transfers, Senegal` · caption_en=`Direct and indirect taxes, social contributions, t…` · alt_text_en=`Stacked bar chart with two overlaid lines showing …` · source=`TBD` · producer=`TBD` · licence=`TBD` · file=`SEN/SEN_FISCAL_EQUITY.png` · sha256=`9842d034ab862046343e74cb3a32a1b160524134b69f8ea39e…` · status=`DRAFT` · version_added=`0.1.0`

**`metadata/registries/GEO_SOURCES.csv`**: 2 rows. Purpose: Boundary-file registry {#sec-geo-storage}

- Header (16): `source_id, ref_area, provider, version, valid_on, url, download_date, licence, attribution, crs, file, layers, sha256, status, version_added, notes`
- First row (non-empty cells, truncated at 50 chars): source_id=`SEN_CODAB_v02` · ref_area=`SEN` · provider=`OCHA COD-AB` · version=`v02` · valid_on=`2024-05-20` · licence=`TBD` · attribution=`TBD` · crs=`EPSG:4326` · file=`SEN_CODAB_v02.gpkg` · layers=`adm0 adm1` · sha256=`035daf04e376838a87bcf99343750d378e1ded8169a8d37b42…` · status=`DRAFT` · version_added=`0.1.0`

**`metadata/registries/SOURCES.csv`**: 2 rows. Purpose: Program runs that produced data rows; kind PRODUCER / LEGACY_CONVERSION (D16) {#sec-sources}

- Header (14): `source_id, kind, ref_area, survey_id, program, program_version, producer, software, run_date, inputs, inputs_sha256, status, version_added, notes`
- First row (non-empty cells, truncated at 50 chars): source_id=`SEN_EHCVM2021_LEGACY_v1` · kind=`LEGACY_CONVERSION` · ref_area=`SEN` · survey_id=`SEN_EHCVM_2021` · program=`pipeline/convert_legacy.R` · program_version=`0.2.0` · producer=`AFW DIP/POV team` · software=`R 4.5.3` · run_date=`2026-01-01` · inputs=`data_raw/tables/Tables_SEN.xlsx` · inputs_sha256=`ffe33a59213991792dae1c9b1036d4a1ad4746b75813462552…` · status=`DRAFT` · version_added=`0.2.0` · notes=`Legacy conversion of the Senegal workbook; values …`

**`metadata/rules/RULES.csv`**: 130 rows. Purpose: Verification rules per DATAFLOW / INDICATOR / SERIES scope (D18) {#sec-rules}

- Header (10): `rule_id, scope, scope_code, rule, param, tolerance, severity, status, version_added, notes`
- First row (non-empty cells, truncated at 50 chars): rule_id=`AFW360_HH.RELIABILITY_MIN_NOBS` · scope=`DATAFLOW` · rule=`RELIABILITY_MIN_NOBS` · param=`30` · severity=`ERROR` · status=`DRAFT` · version_added=`0.2.0` · notes=`Minimum N_OBS below which a row is OBS_STATUS U (D…`

**`metadata/structure/COLUMNS.csv`**: 347 rows. Purpose: Column registry of every metadata/content CSV (change (aa)) {#sec-metadata}, {#sec-layout}

- Header (5): `file, position, column, status, description`
- First row (non-empty cells, truncated at 50 chars): file=`DSD_AFW360_HH.csv` · position=`1` · column=`position` · status=`R` · description=`1-31, the data file's column order.`

**`metadata/structure/DSD_AFW360_HH.csv`**: 31 rows. Purpose: Column list of the data files, 31 columns (D26) {#sec-columns}, {#sec-change-control}

- Header (7): `position, id, role, codelist, required, sentinel, description`
- First row (non-empty cells, truncated at 50 chars): position=`1` · id=`DATAFLOW` · role=`constant` · required=`R` · description=`Constant AFW360_HH.`

**`metadata/structure/INDICATOR_QUALIFIERS.csv`**: 6 rows. Purpose: Which qualifier variables/categories each indicator takes (D18) {#sec-relations}

- Header (6): `indicator, qual_var, allowed, status, version_added, notes`
- First row (non-empty cells, truncated at 50 chars): indicator=`CONS_SH` · qual_var=`COICOP` · allowed=`COICOP_CP01 COICOP_CP02 COICOP_CP03 COICOP_CP04 CO…` · status=`DRAFT` · version_added=`0.2.0`

**`metadata/structure/QUALIFIER_PAIRS.csv`**: 8 rows. Purpose: Allowed pairings of a qualifier category with another qualifier variable (D18) {#sec-relations}

- Header (6): `qualifier, with_var, allowed, status, version_added, notes`
- First row (non-empty cells, truncated at 50 chars): qualifier=`POVLINE_PL215` · with_var=`PPP` · allowed=`PPP_2017` · status=`DRAFT` · version_added=`0.2.0`

**`metadata/surveys/SURVEYS.csv`**: 2 rows. Purpose: One row per country x survey round {#sec-surveys}

- Header (25): `survey_id, ref_area, time_period, survey_name, survey_acronym, producer_agency, fieldwork_start, fieldwork_end, sample_hh, sample_ind, design, representative_levels, analysis_units, welfare_aggregate, welfare_adjustments, npl_value, npl_currency, npl_unit, npl_ref_year, ppp_rounds, microdata_ref, comparable_with, contact, notes, status`
- First row (non-empty cells, truncated at 50 chars): survey_id=`SEN_EHCVM_2021` · ref_area=`SEN` · time_period=`2021` · survey_name=`Enquête Harmonisée sur les Conditions de Vie des M…` · survey_acronym=`EHCVM` · producer_agency=`ANSD` · fieldwork_start=`2021-11` · fieldwork_end=`2022-09` · sample_hh=`7100` · design=`TBD` · representative_levels=`National, geopolitical zones, urban and rural` · analysis_units=`TBD` · welfare_aggregate=`Consumption per capita` · welfare_adjustments=`Temporal and spatial cost-of-living adjustment acr…` · npl_value=`519.8` · npl_currency=`XOF` · npl_unit=`per capita per day` · npl_ref_year=`2018` · ppp_rounds=`2021` · comparable_with=`SEN_EHCVM_2018` · notes=`npl_ref_year (2018) is inferred from About_SEN.txt…` · status=`DRAFT`

**`content/TEXT.csv`**: 8 rows. Purpose: Dashboard prose, one row per slot/country/year/order {#sec-text-csv}

- Header (9): `slot, ref_area, time_period, order, title, body, file, status, updated_on`
- First row (non-empty cells, truncated at 50 chars): slot=`about` · ref_area=`SEN` · time_period=`2021` · order=`1` · file=`SEN/about.md` · status=`DRAFT` · updated_on=`2026-09-21`

**`data/AFW360_HH_GNB_2021_SURVEY_manifest.csv`**: 16 rows. Purpose: Manifest: key/value summary of a data file, 16 keys {#sec-manifest}

- Header (2): `key, value`
- Content (all rows): `dataflow=AFW360_HH`; `dsd_version=0.2.0`; `metadata_version=0.2.0`; `ref_area=GNB`; `time_period=2021`; `estimation=SURVEY`; `survey_id=GNB_EHCVM_2021`; `sources=GNB_EHCVM2021_LEGACY_v1`; `file_name=AFW360_HH_GNB_2021_SURVEY.csv`; `n_rows=2268`; `producer=AFW DIP/POV team`; `program=pipeline/convert_legacy.R`; `software=R 4.5.3`; `run_timestamp=2026-01-01T00:00:00Z`; `status=DRAFT`; `notes=Legacy conversion of data_raw/tables/Tables_GNB.xlsx`

**`data/AFW360_HH_SEN_2021_SURVEY_manifest.csv`**: 16 rows. Purpose: Manifest: key/value summary of a data file, 16 keys {#sec-manifest}

- Header (2): `key, value`
- Content (all rows): `dataflow=AFW360_HH`; `dsd_version=0.2.0`; `metadata_version=0.2.0`; `ref_area=SEN`; `time_period=2021`; `estimation=SURVEY`; `survey_id=SEN_EHCVM_2021`; `sources=SEN_EHCVM2021_LEGACY_v1`; `file_name=AFW360_HH_SEN_2021_SURVEY.csv`; `n_rows=3003`; `producer=AFW DIP/POV team`; `program=pipeline/convert_legacy.R`; `software=R 4.5.3`; `run_timestamp=2026-01-01T00:00:00Z`; `status=DRAFT`; `notes=Legacy conversion of data_raw/tables/Tables_SEN.xlsx`


## 3. `metadata/codelists/CL_INDICATOR.csv`

35 columns, **62 indicators** (the "35" is the column count). All 62 have `status = DRAFT`, `program = TBD`, `source_questionnaire = TBD`; `excluded_breakdowns` is empty on all 62; `related` is filled on 8.

| # | column | kind | references / values seen |
|---|---|---|---|
| 1 | `code` | code (identifier) | referenced by DSD `INDICATOR`, `SERIES_PLAN.INDICATOR`, `INDICATOR_QUALIFIERS.indicator`, `RULES.scope_code` (scope INDICATOR), `LEGACY_LABELS` via series |
| 2 | `name_en` | descriptive text | |
| 3 | `definition_en` | descriptive text | |
| 4 | `status` | enum | DRAFT / ACTIVE / DEPRECATED (all DRAFT) |
| 5 | `version_added` | version string | metadata/VERSION value |
| 6 | `replaced_by` | code → CL_INDICATOR | empty on all |
| 7 | `notes` | descriptive text | |
| 8 | `short_name_en` | descriptive text (≤40 chars) | |
| 9 | `theme` | code → CL_THEME | HE 23, EN 17, HOUS 5, SHK 5, AGR 4, POP 3, POV 2, SP 2, CONS 1 |
| 10 | `stat_unit` | code → CL_STAT_UNIT | HH 35, HE 23, IND 4 |
| 11 | `universe_unit` | code → CL_STAT_UNIT (not validated by `vc_meta_reference`) | HH 35, HE 23, IND 4 |
| 12 | `universe_filter` | descriptive text | |
| 13 | `numerator` | descriptive text | |
| 14 | `statistic` | code → CL_STATISTIC | PROPORTION 47, MEAN 14, TOTAL 1 |
| 15 | `weight` | code → CL_WEIGHT | HH 35, HE 23, POP 3, IND 1 |
| 16 | `ref_period` | rule-like value (ISO 8601 duration or `INTERVIEW`) | INTERVIEW 55, P3Y 5, P7D 2 |
| 17 | `excluded_breakdowns` | codes → CL_BRK_VAR / CL_COMP_BREAKDOWN (rule: cells not to produce) | empty on all |
| 18 | `unit_measure` | code → CL_UNIT | SHARE 48, LCU 5, PERSON 4, HA/TLU/DAY/INDEX/YEAR 1 each |
| 19 | `unit_denom` | code (CL_UNIT values, not validated) | PERSON 1, else empty |
| 20 | `unit_time` | enum DAY/MONTH/YEAR | MONTH 1, TBD 1, else empty |
| 21 | `price_basis` | enum NOMINAL/DEFLATED | NOMINAL 5 |
| 22 | `price_ref_year` | number (year) | empty |
| 23 | `display_as` | enum (presentation rule) | PERCENT 48, NUMBER 8, CURRENCY 5, MILLIONS 1 |
| 24 | `decimals` | number (presentation) | |
| 25 | `valid_min` | number (range rule) | |
| 26 | `valid_max` | number (range rule) | |
| 27 | `higher_is` | enum BETTER/WORSE/NEUTRAL (presentation rule) | BETTER 31, NEUTRAL 20, WORSE 11 |
| 28 | `sdg_indicator` | external code (SDG) | |
| 29 | `classification` | external code (e.g. COICOP2018) | COICOP2018 1 |
| 30 | `related` | codes → CL_INDICATOR (space-separated) | 8 filled |
| 31 | `related_note` | descriptive text | |
| 32 | `source_questionnaire` | descriptive text (provenance) | TBD ×62 |
| 33 | `source_vars` | descriptive text (provenance) | |
| 34 | `program` | descriptive text (provenance) | TBD ×62 |
| 35 | `owner` | descriptive text | |

`vc_meta_reference` validates only `theme`, `stat_unit`, `statistic`, `weight`, `unit_measure` against codelists (`pipeline/R/validate_metadata.R:230-234`). In SDMX terms: columns 9–10, 14–15, 18 behave like coded attributes; 16, 17, 19–27 are concept/presentation metadata (reference-metadata candidates); 2–3, 8, 12–13, 28–35 are documentation text.

First 15 codes: `AGR_CULT_AREA, AGR_CULTIVATES, AGR_LIVESTOCK_ANY, AGR_TLU, CONS_SH, EN_ASSET_AC, EN_ASSET_COOKER, EN_ASSET_FAN, EN_ASSET_WATER_HEATER, EN_COOK_BIOMASS, EN_COOK_CLEAN, EN_ELEC_ACCESS, EN_ELEC_INFORMAL, EN_ELEC_SPEND, EN_GRID_CONN`.

Related metadata sizes: `SERIES_PLAN.csv` 91 series, all `ref_area=ALL`, `estimation=SURVEY`, `status=DRAFT` (multi-series indicators: CONS_SH 15, POP_SH 9, POP_HH_SH 5, POV_HC 2, POV_NUM 2). `RULES.csv` 130 rows: AGG_BRACKET 60, RANGE_0_1 48, RANGE_NONNEG 13, SUM_TO_1_OVER_BRK 3, MONOTONE_IN 2, AGG_SUM 1, SUM_TO_1_OVER 1, RELIABILITY_MIN_NOBS 1, RELIABILITY_MAX_CV 1 (scope INDICATOR 128, DATAFLOW 2). `LEGACY_LABELS.csv` 179 rows: MAP 91, SKIP 84 (82 on sheet `Departement`), DUPLICATE_OF 2, DERIVED 2. `LEGACY_COLUMNS.csv` 73 rows (MAP 59, SKIP 14 = SEN Departement). `TAB_PLAN.csv` 8 cuts: TOTAL, URB (`CAP OU R`), HHH_SEX, HHH_AGE, QUINT, ADM1 (ALL); ZONES (SEN), AEZ (GNB).

## 4. `metadata/structure/DSD_AFW360_HH.csv` (full)

```
position,id,role,codelist,required,sentinel,description
1,DATAFLOW,constant,,R,,Constant AFW360_HH.
2,REF_AREA,breakdown,CL_AREA,R,,CL_AREA (ISO 3166-1 alpha-3).
3,GEO,breakdown,CL_GEO,R,_T,"CL_GEO, or _T for the whole country."
4,TIME_PERIOD,reference,,R,,4-digit year the estimate refers to.
5,ESTIMATION,reference,CL_ESTIMATION,R,,How the value was produced: SURVEY or MODEL (D17).
6,INDICATOR,qualifier,CL_INDICATOR,R,,CL_INDICATOR.
7,SEX,breakdown,CL_SEX,R,_T _Z,"CL_SEX, _T, or _Z."
8,AGE,breakdown,CL_AGE,R,_T _Z,"CL_AGE, _T, or _Z."
9,URBANISATION,breakdown,CL_URBANISATION,R,_T,CL_URBANISATION or _T.
10,COMP_BREAKDOWN_1,breakdown,CL_COMP_BREAKDOWN,R,_T,"slot 1 of 5, filled left to right in slot_order."
11,COMP_BREAKDOWN_2,breakdown,CL_COMP_BREAKDOWN,R,_T,"slot 2 of 5, filled left to right in slot_order."
12,COMP_BREAKDOWN_3,breakdown,CL_COMP_BREAKDOWN,R,_T,"slot 3 of 5, filled left to right in slot_order."
13,COMP_BREAKDOWN_4,breakdown,CL_COMP_BREAKDOWN,R,_T,"slot 4 of 5, filled left to right in slot_order."
14,COMP_BREAKDOWN_5,breakdown,CL_COMP_BREAKDOWN,R,_T,"slot 5 of 5, filled left to right in slot_order."
15,MEASURE_QUAL_1,qualifier,CL_QUALIFIER,R,_Z,"slot 1 of 5, filled left to right in slot_order."
16,MEASURE_QUAL_2,qualifier,CL_QUALIFIER,R,_Z,"slot 2 of 5, filled left to right in slot_order."
17,MEASURE_QUAL_3,qualifier,CL_QUALIFIER,R,_Z,"slot 3 of 5, filled left to right in slot_order."
18,MEASURE_QUAL_4,qualifier,CL_QUALIFIER,R,_Z,"slot 4 of 5, filled left to right in slot_order."
19,MEASURE_QUAL_5,qualifier,CL_QUALIFIER,R,_Z,"slot 5 of 5, filled left to right in slot_order."
20,SERIES_ID,attribute,SERIES_PLAN,R,,"SERIES_PLAN.series_id; agrees with INDICATOR, qualifiers and defining category (D13)."
21,OBS_VALUE,measure,,C,,"Number, unrounded, base units; required unless OBS_STATUS is O or M."
22,UNIT_MEASURE,attribute,CL_UNIT,R,,"CL_UNIT code, or an ISO 4217 code from CL_AREA.currency where the indicator's unit_measure is LCU (D14)."
23,PRECISION,attribute,,C,,Rounding unit of OBS_VALUE in base units; empty when exact; required on rows of a LEGACY_CONVERSION source (D15).
24,OBS_STATUS,attribute,CL_OBS_STATUS,R,,"CL_OBS_STATUS; one code per row, precedence M O E D U A (D22)."
25,STD_ERR,attribute,,C,,Number >= 0; required on PRODUCER-source rows where CL_STATISTIC.admits_se = Y.
26,CI_LOWER,attribute,,C,,"Number, 95%; required where STD_ERR is."
27,CI_UPPER,attribute,,C,,"Number, 95%; required where STD_ERR is."
28,N_OBS,attribute,,C,,"Integer >= 0; required on PRODUCER-source rows; on a share row, the denominator's records (D19)."
29,N_POP,attribute,,C,,"Number >= 0; required on PRODUCER-source rows; on a share row, the denominator's population (D19)."
30,SOURCE_ID,attribute,SOURCES,R,,"SOURCES.source_id, the program run that produced the row (D16)."
31,OBS_COMMENT,attribute,,O,,"Free text, English; LEGACY_EMPTY: prefix required on O rows of a LEGACY_CONVERSION source (D9)."
```

Roles: constant 1, breakdown 9 (REF_AREA, GEO, SEX, AGE, URBANISATION, COMP_BREAKDOWN_1..5), reference 2 (TIME_PERIOD, ESTIMATION), qualifier 6 (INDICATOR, MEASURE_QUAL_1..5), measure 1, attribute 10 (plus OBS_VALUE measure). Key = roles constant/breakdown/reference/qualifier = positions 1–19 (`dsd_key_columns()`, `pipeline/R/io.R:193-206`). Note for SDMX mapping: `DATAFLOW` becomes the SDMX-CSV `STRUCTURE_ID` column; `TIME_PERIOD` is the SDMX time dimension; `SERIES_ID` and `UNIT_MEASURE` have "codelists" `SERIES_PLAN`/`CL_UNIT` where UNIT_MEASURE may also hold ISO 4217 codes (XOF) not in CL_UNIT.

## 5. Data files

Both files have the identical 31-column header in DSD order: `DATAFLOW, REF_AREA, GEO, TIME_PERIOD, ESTIMATION, INDICATOR, SEX, AGE, URBANISATION, COMP_BREAKDOWN_1, COMP_BREAKDOWN_2, COMP_BREAKDOWN_3, COMP_BREAKDOWN_4, COMP_BREAKDOWN_5, MEASURE_QUAL_1, MEASURE_QUAL_2, MEASURE_QUAL_3, MEASURE_QUAL_4, MEASURE_QUAL_5, SERIES_ID, OBS_VALUE, UNIT_MEASURE, PRECISION, OBS_STATUS, STD_ERR, CI_LOWER, CI_UPPER, N_OBS, N_POP, SOURCE_ID, OBS_COMMENT`. LF endings, no BOM (per `write_std_csv`).

| | `data/AFW360_HH_SEN_2021_SURVEY.csv` | `data/AFW360_HH_GNB_2021_SURVEY.csv` |
|---|---|---|
| rows (excl. header) | 3003 (469,909 bytes) | 2268 (352,870 bytes) |
| DATAFLOW | `AFW360_HH` | `AFW360_HH` |
| REF_AREA | `SEN` | `GNB` |
| TIME_PERIOD | `2021` | `2021` |
| ESTIMATION | `SURVEY` | `SURVEY` |
| OBS_STATUS | `A` 3003 | `A` 2229, `O` 39 |
| UNIT_MEASURE | SHARE 2508, XOF 165, PERSON 165, HA 33, TLU 33, DAY 33, INDEX 33, YEAR 33 | SHARE 1900, XOF 125, PERSON 125, TLU 25, DAY 25, INDEX 25, YEAR 25, HA 18 |
| SOURCE_ID | `SEN_EHCVM2021_LEGACY_v1` | `GNB_EHCVM2021_LEGACY_v1` |
| SEX / AGE | `_Z` 2541, `_T` 462 | `_Z` 1918, `_T` 350 |
| URBANISATION | `_T` 2730, CAP 91, OU 91, R 91 | `_T` 2087, OU 91, R 90 |
| distinct INDICATOR | 62 | 62 |
| empty OBS_VALUE | 0 | 39 (= the O rows) |
| non-empty STD_ERR | 0 | 0 |
| non-empty N_OBS | 0 | 0 |
| non-empty PRECISION | 3003 (all) | 2268 (all) |
| non-empty OBS_COMMENT | 99 | 64 |

CI_LOWER, CI_UPPER, N_POP are also empty on all rows (legacy source). First SEN row: `AFW360_HH,SEN,SN01,2021,SURVEY,AGR_CULTIVATES,_Z,_Z,_T,_T,_T,_T,_T,_T,_Z,_Z,_Z,_Z,_Z,AGR_CULTIVATES,0.01,SHARE,0.01,A,,,,,,SEN_EHCVM2021_LEGACY_v1,`.

Manifests (`*_manifest.csv`, 16 keys, `key,value`): see section 2; they differ only in `ref_area`, `survey_id`, `sources`, `file_name`, `n_rows`, `notes`. `run_timestamp=2026-01-01T00:00:00Z` (injected).

## 6. Pipeline

Shared loading: most entry points `source()` modules from `pipeline/R/`. `load_metadata(root)` (`R/io.R`) reads **every** CSV under `metadata/` and `content/` into a named list keyed by file stem, so any script that calls it implicitly reads all of `metadata/**` and `content/TEXT.csv`. All CSV I/O goes through `read_std_csv()` / `write_std_csv()` (readr), `R/io.R:15-53`.

### 6a. Entry points (top level)

| path | lines | purpose (header) | reads | writes | functions defined |
|---|---:|---|---|---|---|
| `pipeline/convert_legacy.R` | 119 | WP15 legacy converter: Tables_<ISO3>.xlsx → data file + manifest, driven by LEGACY_* plans, columns from DSD | `metadata/**` (load_metadata; requires DSD_AFW360_HH, LEGACY_LABELS, LEGACY_COLUMNS, LEGACY_OVERRIDES, SERIES_PLAN, SURVEYS, SOURCES, CL_AREA, CL_INDICATOR, CL_BRK_VAR, CL_QUAL_VAR, CL_COMP_BREAKDOWN, CL_QUALIFIER), `metadata/VERSION`, `data_raw/tables/Tables_<ISO3>.xlsx` | `data/AFW360_HH_<ISO3>_<YEAR>_SURVEY.csv`, `data/..._manifest.csv` | `.arg` |
| `pipeline/validate.R` | 150 | validator entry point; sources io, constants, codes, ctx, plan, manifest, docs, validate_common, all `validate_*.R`; runs every `vc_*` | `metadata/**`, `content/**`, `data/AFW360_HH_*.csv` + manifests (via build_ctx), geo/assets/.docs via modules | findings CSV (`--out`) | `.cli_root`, `.has_summary_row` |
| `pipeline/reconcile.R` | 58 | WP16 independent reconciliation data/ ↔ workbooks | via R/reconcile.R: `metadata/**`, `data_raw/tables/*.xlsx`, `data/AFW360_HH_<ISO3>_<YEAR>_SURVEY.csv` | report `.md` (`--out`), optional cells CSV (`--csv`) | none |
| `pipeline/build_geo.R` | 107 | WP05: GeoPackages (layers adm0, adm1) + GEO_SOURCES | `data_raw/shp/{sen,gnb}_admin{0,1}.shp` (hard-coded list lines 28-39) | `geo/boundaries/<source_id>.gpkg`, `metadata/registries/GEO_SOURCES.csv` | none |
| `pipeline/build_content.R` | 173 | WP10: TEXT.csv, about.md, figure, FIGURES.csv | `data_raw/text/About_SEN.txt`, `index.qmd` (the "## Row Messages" blocks), `data_raw/text/Messages_{SEN,GNB}.txt`, `data_raw/figures/Fiscal Equity SEN.png`, `pipeline/bootstrap/text/figures_text.csv` | `content/TEXT.csv`, `content/text/SEN/about.md`, `assets/figures/SEN/SEN_FISCAL_EQUITY.png`, `metadata/registries/FIGURES.csv` | `.arg`, `get_messages`, `msg_rows` |
| `pipeline/build_docs.R` | 50 | writes the standard's generated tables (D20); `--check` exits 1 if stale | `metadata/**`, `content/**` (via R/docs.R) | `.docs/generated/*.md` (22 files) | none |

### 6b. `pipeline/R/` modules

| path | lines | purpose | reads | writes | functions |
|---|---:|---|---|---|---|
| `R/io.R` | 206 | CSV read/write, hashing, metadata loading, CLI args, DSD column helpers | any CSV; `metadata/`, `content/` (load_metadata) | any CSV | `read_std_csv write_std_csv fmt_num sha256_file load_metadata repo_path cli_arg cli_args cli_flag dsd_columns dsd_key_columns` |
| `R/constants.R` | 67 | `DATAFLOW_ID`, sentinels, `TBD`, `DSD_COLUMNS` (31), `KEY_COLUMNS` (1:19) | – | – | none (constants only) |
| `R/codes.R` | 59 | code syntax, slot ordering | – | – | `is_valid_code slot_sort fill_slots` |
| `R/ctx.R` | 189 | builds shared validator context | data files + `<key>_manifest.csv`, metadata | – | `build_ctx ctx_key_columns ctx_dsd_columns ctx_row_keys ctx_source_kind ctx_parse_file_name ctx_file_estimation ctx_rules ctx_dataflow_threshold` |
| `R/plan.R` | 373 | required-row generator from SERIES_PLAN × TAB_PLAN | meta list | – | `.plan_key_columns effective_series_plan .plan_estimation_applies .plan_tokens required_rows` |
| `R/manifest.R` | 77 | data-file name + manifest (16 `MANIFEST_KEYS`) | – | – | `data_file_name manifest_file_name build_manifest` |
| `R/convert_tables.R` | 575 | pure conversion workbook → rows | `Tables_<ISO3>.xlsx` (readxl, line 39) | – | `is_blank wildcard_sheets read_legacy_workbook melt_workbook validate_workbook_plan parse_assert_rule check_label_assertions order_and_pad match_overrides legacy_source_id resolve_unit_measure legacy_precision build_country_rows finalize_rows` |
| `R/reconcile.R` | 614 | independent reconciliation | metadata, workbooks (line 87), data files (line 356) | – | `.reconcile_data_path .reconcile_match_wildcard source_cells expected_rows reconcile reconcile_report_md` |
| `R/content.R` | 92 | strip message wrappers, parse index.qmd messages, split About text | text files | – | `strip_message_wrappers parse_message_block extract_row_messages read_about_paragraphs` |
| `R/geo.R` | 77 | read/normalise admin shapefiles (GEOS, s2 off) | shapefiles | – | `read_admin_layer make_boundary_layer` |
| `R/docs.R` | 554 | generator of `.docs/generated/*.md`, include checker | 20 named metadata CSVs (lines 211-228), `.docs/data-standard.qmd` | `.docs/generated/*.md` | `docs_fragment_ids md_oneline md_text md_code md_codes md_table md_categories docs_fragments docs_build docs_includes docs_check` + 12 private `.docs_*` |
| `R/validate_common.R` | 96 | shared findings helpers, cap at 20 | – | – | `.vc_finding .vc_row_key .vc_file_path .vc_empty .vc_apply_cap .vc_bind` |
| `R/validate_structure.R` | 152 | STRUCT: header vs DSD, file name, DATAFLOW constant, empty key, dup key | ctx | – | `vc_struct_header vc_struct_file_name vc_struct_dataflow vc_struct_empty_key vc_struct_duplicate_key` (+2 private) |
| `R/validate_codes.R` | 579 | CODES: codelists, GEO/area, slots, SEX/AGE, qualifiers, pairs, SERIES_ID, UNIT, SOURCE_ID, DRAFT | ctx | – | `vc_codes_unknown vc_codes_geo_area vc_codes_geo_adm0 vc_codes_brk_slots vc_codes_qual_slots vc_codes_sex_age_unit vc_codes_brk_unit vc_codes_qual_declared vc_codes_qual_pairs vc_codes_series_id vc_codes_unit vc_codes_source_id vc_codes_draft` (+7 private) |
| `R/validate_coverage.R` | 546 | COVER: required rows, withheld cells, manifest, SURVEYS | ctx, file existence | – | `withheld_rows vc_cover_file_missing vc_cover_missing vc_cover_extra vc_cover_withheld_present vc_cover_manifest vc_cover_survey` (+4 private) |
| `R/validate_values.R` | 523 | VALUE: numeric, range, status/empty, LEGACY_EMPTY, SE/CI, N, precision, status rules | ctx | – | `vc_value_numeric vc_value_range vc_value_status_empty vc_value_legacy_empty vc_value_se_ci vc_value_n vc_value_se_required vc_value_precision vc_value_status_model vc_value_status_deviates vc_value_status_reliability vc_value_status_q` (+7 private) |
| `R/validate_rules.R` | 782 | RULE: RULES.csv checks + N_POP partition | ctx | – | `vc_rule_range_0_1 vc_rule_range_nonneg vc_rule_agg_sum vc_rule_agg_bracket vc_rule_agg_npop_mean vc_rule_sum_to_1_qual vc_rule_sum_to_1_brk vc_rule_monotone vc_rule_npop_partition` (+17 private) |
| `R/validate_metadata.R` | 637 | META: headers vs COLUMNS.csv, required, code syntax/unique, references, TBD, slot ties, RULES, IQ, QP, SERIES_PLAN, SOURCES | ctx; `inputs` files for sha256 | – | `vc_meta_header vc_meta_required vc_meta_code_syntax vc_meta_code_unique vc_meta_reference vc_meta_tbd vc_meta_slot_order_tie vc_meta_rules vc_meta_indicator_qualifiers vc_meta_qualifier_pairs vc_meta_series_plan vc_meta_sources` (+8 private) |
| `R/validate_assets.R` | 397 | ASSET: GEO_SOURCES/FIGURES files, sha256, layers, CRS, geo_code, geometry | `geo/boundaries/*.gpkg`, `assets/figures/**` | – | `vc_asset_file_missing vc_asset_sha256 vc_asset_layers vc_asset_crs vc_asset_geo_code vc_asset_missing_geometry vc_asset_duplicate_feature vc_asset_invalid_geometry vc_asset_name_mismatch` (+6 private) |
| `R/validate_text.R` | 258 | TEXT: TEXT.csv body/file, html, references, TBD | `content/TEXT.csv`, `content/text/**` | – | `vc_text_body_file vc_text_file_missing vc_text_linebreak vc_text_html vc_text_reference vc_text_tbd` (+8 private) |
| `R/validate_docs.R` | 36 | DOCS: wraps `docs_check()` | `.docs/` | – | `vc_docs_fragments` |

Largest: `validate_rules.R` 782, `migrate.R` 687, `validate_metadata.R` 637, `reconcile.R` (R/) 614, `validate_codes.R` 579, `convert_tables.R` 575, `docs.R` 554, `validate_coverage.R` 546, `validate_values.R` 523. Total `pipeline/R/` = 6,489 lines.

### 6c. Migrations and bootstrap (listed)

- `pipeline/migrations/0.2.0/migrate.R` (687 lines): one-off 0.1.0 → 0.2.0; refuses unless VERSION = 0.1.0. Reads CL_INDICATOR, CL_QUALIFIER, CL_QUAL_VAR, CL_BRK_VAR, CL_COMP_BREAKDOWN, CL_OBS_STATUS, CL_AREA, SERIES_PLAN, SURVEYS, COLUMNS, CHANGELOG.md, `data_raw/CHECKSUMS.sha256`; writes CL_ESTIMATION, CL_OBS_STATUS, CL_INDICATOR, CL_QUALIFIER, RULES, INDICATOR_QUALIFIERS, QUALIFIER_PAIRS, DSD_AFW360_HH, COLUMNS, SOURCES, SERIES_PLAN, VERSION, CHANGELOG. Functions: `.script_dir fail mpath need_cols c_order split_ws compose_name dsd_row slot_rows drop_column set_desc block insert_after_file replace_file_block opath write_text_lf`. Has its own `DATAFLOW_ID` (line 17) and builds the 31-row DSD inline (lines ~430-475). `migrations/0.2.0/README.md` 68 lines.
- `pipeline/bootstrap/` (frozen, D11): `build_breakdowns_qualifiers.R` 177, `build_geo_codelists.R` 113, `build_indicators.R` 269, `build_legacy_maps.R` 369, `build_plans.R` 53, `build_small_codelists.R` 112, `build_surveys.R` 44; `seeds/` 7 CSVs (`codes.csv`, `csv_headers.csv`, `geo_codes.csv`, `label_triage.csv`, `legacy_national_columns.csv`, `legacy_overrides.csv`, `tab_plan.csv`); `text/` 6 CSVs.

### 6d. Hard-coded structure (pipeline/, excluding bootstrap/)

Code that has metadata loaded reads the column list from the DSD (`dsd_columns()`, `dsd_key_columns()` in `R/io.R:181-206`; used by `convert_legacy.R:74,81`, `ctx_key_columns`/`ctx_dsd_columns`, `plan.R:25`, `validate_structure.R`). Fallbacks and literals below are what changes if the data-file layout changes (e.g. to SDMX-CSV with STRUCTURE, STRUCTURE_ID, ACTION leading columns).

| file:line | what is hard-coded |
|---|---|
| `R/constants.R:14` | `DATAFLOW_ID <- "AFW360_HH"` (used by manifest.R, ctx.R, plan.R, convert_tables.R, validate_structure.R, validate_coverage.R, validate_metadata.R) |
| `R/constants.R:31-63` | `DSD_COLUMNS`, the full 31-column vector |
| `R/constants.R:67` | `KEY_COLUMNS <- DSD_COLUMNS[1:19]` |
| `R/ctx.R:79`, `R/ctx.R:91` | fallback to `KEY_COLUMNS` / `DSD_COLUMNS` when no DSD loaded |
| `R/ctx.R:126` | file-name regex `^AFW360_HH_([A-Z]{3})_([0-9]{4})_(...)$` |
| `R/ctx.R:184` | `rules$scope == "DATAFLOW"` |
| `R/plan.R:28` | fallback to `KEY_COLUMNS` |
| `R/plan.R:307` | `DATAFLOW = DATAFLOW_ID` in generated rows; plan.R also names `COMP_BREAKDOWN_`/`MEASURE_QUAL_` (6 lines each), SEX/AGE/GEO/URBANISATION |
| `R/convert_tables.R:493` | `DATAFLOW = DATAFLOW_ID`; builds rows naming COMP_BREAKDOWN_/MEASURE_QUAL_ slots (5–6 lines each), SERIES_ID, UNIT_MEASURE, PRECISION, OBS_STATUS, SOURCE_ID, OBS_COMMENT |
| `R/convert_tables.R:523` | error text "column(s) not in DSD_AFW360_HH" |
| `R/manifest.R:23` | `sprintf("%s_%s_%s_%s.csv", DATAFLOW_ID, ...)` file-name pattern |
| `R/manifest.R:55` | `dataflow = DATAFLOW_ID` manifest key; `MANIFEST_KEYS` (16) |
| `R/reconcile.R:20-25` | `.reconcile_key_cols`: the 19 key columns as literals (deliberately independent) |
| `R/reconcile.R:27,30` | `.reconcile_sheets_star`, `.reconcile_estimation <- "SURVEY"` |
| `R/reconcile.R:40` | `paste0("AFW360_HH_", ref_area, "_", time_period, "_", ...)` |
| `R/reconcile.R:222, 304-315` | `DATAFLOW <- rep("AFW360_HH", n)` and the row tibble with all key columns by name |
| `R/reconcile.R:385` | regex `^.*AFW360_HH_([A-Z]+)_.*$` |
| `R/validate_structure.R:62` | file-name pattern message using DATAFLOW_ID |
| `R/validate_structure.R:100-105` | `df$DATAFLOW` must equal DATAFLOW_ID (check STRUCT.DATAFLOW) |
| `R/validate_coverage.R:224` | `stem <- paste0(DATAFLOW_ID, "_", ref_area, "_", time_period, "_SURVEY")` (SURVEY literal) |
| `R/validate_codes.R:27`, `R/validate_common.R:40`, `R/validate_structure.R:18`, `R/validate_rules.R:206` | `paste0("data/", key, ".csv")` path pattern |
| `R/validate_codes.R:72` | `ctx$meta$DSD_AFW360_HH` (reads DSD `codelist` column to map columns→codelists) |
| `R/validate_metadata.R:47` | `.META_KEY_MAP` `DSD_AFW360_HH = "id"` |
| `R/validate_metadata.R:366-409` | scope vocabulary `DATAFLOW/INDICATOR/SERIES`; rule_id prefix `DATAFLOW_ID` (line 397) |
| `R/validate_rules.R:283` | `DATAFLOW = rep(TRUE, ...)` scope handling |
| `R/docs.R:212, 263-273` | reads `DSD_AFW360_HH`, caption "Columns of an `AFW360_HH` data file" (tbl-columns) |
| `R/io.R:182-206` | `meta$DSD_AFW360_HH` table name; key = roles constant/breakdown/reference/qualifier |
| `R/codes.R:16` | code regex `{0,31}` (32-char code limit, not the column count) |
| `validate.R:55` | data-file discovery pattern `^AFW360_HH_.*\.csv$`, excludes `_manifest.csv` |
| `convert_legacy.R:51,82` | required table `DSD_AFW360_HH`; `estimation <- "SURVEY"` (line 73) |
| `migrations/0.2.0/migrate.R:17, 224-225, 434, 475, 496, 535-537, 633, 654` | own `DATAFLOW_ID`; DSD rows inline; `nrow(dsd) != 31` guard; "1-31" description (frozen, historical) |

Column-literal usage per file (lines mentioning the column name, incl. comments; files not listed = 0): `OBS_STATUS` validate_values 30, reconcile 6; `OBS_VALUE` validate_values 22, reconcile 12; `STD_ERR` validate_values 19; `N_OBS` validate_values 17; `CI_LOWER` validate_values 14; `N_POP` validate_rules 13, validate_values 10; `PRECISION` validate_values 12, reconcile 7, validate_rules 3; `SOURCE_ID` validate_codes 14, validate_coverage 4, validate_values 4; `SERIES_ID` validate_codes 11, reconcile 6; `UNIT_MEASURE` validate_codes 7; `INDICATOR` validate_codes 17, validate_metadata 16; `REF_AREA` validate_codes 13, reconcile 6; `ESTIMATION` plan 5, reconcile 5, manifest 4, ctx 4, validate_structure 4, validate_rules 4; `COMP_BREAKDOWN_`/`MEASURE_QUAL_` constants, convert_tables, plan, reconcile, validate_codes, validate_coverage, validate_rules (1–6 each). So `validate_values.R`, `validate_codes.R`, `reconcile.R`, `convert_tables.R` are the files most coupled to attribute column names.

Tests with hard-coded structure (lines matching `AFW360_HH|31|19|DSD_COLUMNS|KEY_COLUMNS`): test-convert 16 (e.g. :274-308 "19-column key", "31 DSD columns"), test-ctx 13, test-plan 12 (:282), test-validate-coverage 5, helper-data-fixture 4 (+ its own `.FIXTURE_MANIFEST_KEYS`), test-docs 4 (:50-56 positions 1..31), test-migrate-0.2.0 4 (:41-51), test-reconcile 4, test-validate-core 3 (:435), test-validate-rules 2.

## 7. Tests

Run: `Rscript pipeline/tests/testthat.R` (calls `testthat::test_dir("pipeline/tests/testthat")`, from repo root). Helpers auto-sourced: `helper-temp-root.R` (64 lines; `find_root()`, `make_temp_root()`, `edit_csv()`; sources io.R, validate_common.R) and `helper-data-fixture.R` (141 lines; `make_data_fixture()` builds a synthetic 31-column legacy-like data file + manifest from `required_rows()`). 218 `test_that` blocks.

| test file | lines | test_that | tests |
|---|---:|---:|---|
| `test-codes.R` | 34 | 6 | R/codes.R |
| `test-content.R` | 120 | 10 | R/content.R (+io.R) |
| `test-convert.R` | 448 | 19 | R/convert_tables.R, R/manifest.R (converter end to end on workbooks) |
| `test-ctx.R` | 87 | 6 | R/ctx.R |
| `test-docs.R` | 108 | 8 | R/docs.R (fragments, includes, check) |
| `test-geo.R` | 79 | 8 | R/geo.R |
| `test-io.R` | 98 | 9 | R/io.R |
| `test-migrate-0.2.0.R` | 160 | 12 | migrations/0.2.0/migrate.R on fixture |
| `test-plan.R` | 341 | 9 | R/plan.R (+ constants vs DSD) |
| `test-reconcile.R` | 333 | 16 | R/reconcile.R and pipeline/reconcile.R |
| `test-validate-assets-text.R` | 287 | 18 | validate_assets.R, validate_text.R |
| `test-validate-core.R` | 776 | 42 | validate.R end to end; validate_structure, validate_codes, validate_metadata, validate_docs (incl. a synthetic `validate_zzzcrash.R` crash module) |
| `test-validate-coverage.R` | 673 | 33 | validate_coverage.R, validate_values.R |
| `test-validate-rules.R` | 600 | 22 | validate_rules.R (+ metadata, structure) |

Fixtures: `pipeline/tests/testthat/fixtures/metadata-0.1.0/` = frozen 0.1.0 copy for the migration test: `data_raw/CHECKSUMS.sha256`, `metadata/VERSION` (0.1.0), `metadata/CHANGELOG.md`, `metadata/codelists/{CL_AREA, CL_BRK_VAR, CL_COMP_BREAKDOWN, CL_INDICATOR, CL_OBS_STATUS, CL_QUAL_VAR, CL_QUALIFIER}.csv`, `metadata/plans/SERIES_PLAN.csv`, `metadata/structure/{COLUMNS, DSD_AFW360_HH}.csv` (0.1.0 DSD: 27 lines = 26 columns), `metadata/surveys/SURVEYS.csv`. Other tests build temp roots by copying the live `metadata/` (make_temp_root) and synthesise data files.

## 8. Dashboard

- `index.qmd`: 1195 lines, 32,313 bytes. Sections: `# Senegal` (184), `## Row Messages` (191), `## Row International Poverty` (209), `## Row Figures and Maps` (325), `## Row Profile` (467) with `### Column {.tabset}` (469), `## Row About Data` (670); `# Guinea Bissau` (720) with the same rows at 723/742/859/923/1127; `# About` (1177). Front matter lines 1-11, `title: "AFW 360 PILOT"`.
- Reads today (all under `data_raw/`): `file_path = "data_raw/tables/Tables_SEN.xlsx"` (188, never reassigned for GNB); `pd.read_excel(file_path, sheet_name=...)` at 215, 273, 384 (ADM 1), 438 (ZAE), 475, 503, 531, 570, 600, 748, 805, 865 (ADM 1), 896 (ZAE), 931, 959, 987, 1026, 1057 (so the GNB section 748-1057 reads SEN data); map chunk 361-430: `base_dir / "data_raw" / "tables" / "Tables_SEN.xlsx"` (370), `data_raw/shp/sen_admin1.shp` (371) via `gpd.read_file` (398), joined on `adm1_name`; images `data_raw/figures/Fiscal Equity SEN.png` (658, 665, 1115, 1122); text `data_raw/text/About_SEN.txt` (675), `About_GNB.txt` (1132), `About.txt` (1182); download links embed `data_raw/tables/Tables_SEN.xlsx` (694) and `Tables_GNB.xlsx` (1151) as base64.
- **No loader reads `data/`, `metadata/`, `content/`, `geo/` or `assets/` yet** (grep finds none).
- `_quarto.yml` (26 lines): project `website`, `output-dir: _site`, `render: [index.qmd]` only; format `html` (cosmo), `code-fold: true` — not `dashboard`.
- `.docs/_quarto.yml` (50 lines): nested website project, `output-dir: _site` (i.e. `.docs/_site`), renders `data-standard.qmd` (→ index.html), `input-tables-findings.qmd`, `transition.qmd`; `shiny-port-plan.md` deliberately excluded; css `styles.css`. Rendered with `quarto render .docs`.
- `.docs/generated/` (22 fragments, produced by `pipeline/build_docs.R` via `R/docs.R::docs_build`, checked by `docs_check`/`vc_docs_fragments`): `tbl-brk-vars.md, tbl-cl-brk-var.md, tbl-cl-geo.md, tbl-cl-geo-scheme.md, tbl-cl-indicator.md, tbl-columns.md, tbl-indicator-qualifiers.md, tbl-initial-plan.md, tbl-legacy-columns-csv.md, tbl-legacy-labels.md, tbl-legacy-overrides.md, tbl-obs-status.md, tbl-povlines.md, tbl-qualifier-pairs.md, tbl-qual-vars.md, tbl-rules.md, tbl-series-plan.md, tbl-small-codelists.md, tbl-sources.md, tbl-surveys.md, tbl-tab-plan.md, tbl-text.md`. All 22 are included by the standard, and every include resolves.

## 9. The standard: `.docs/data-standard.qmd` (1032 lines)

Front matter 1-15 (title "AFW 360 data standard and producer guidelines", subtitle "Draft v0.5 · metadata 0.2.0", date 2026-09-28, `output-file: index.html`); intro + reading guide 17-35.

| line | heading |
|---:|---|
| 37 | # The idea in one page {#sec-idea} |
| 43 | ## One row is one number {#sec-one-row} |
| 67 | ## Common compositions, and how each number is checked {#sec-compositions} |
| 98 | ## Where everything lives {#sec-layout} |
| 186 | ## How the database grows {#sec-growth} |
| 207 | # Data structure: dataflow `AFW360_HH` {#sec-data} |
| 215 | ## Columns {#sec-columns} |
| 228 | ## The two sentinels {#sec-sentinels} |
| 238 | ## Estimation method {#sec-estimation-method} |
| 249 | ## Rules for the breakdown columns {#sec-breakdown-rules} |
| 259 | ## Rules for the qualifier columns {#sec-qualifier-rules} |
| 267 | ## Values and attributes {#sec-values} |
| 292 | ## Which rows exist {#sec-required-rows} |
| 308 | ## Example rows {#sec-example-rows} |
| 332 | # Breakdowns {#sec-breakdowns} |
| 340 | ## Initial breakdown variables {#sec-initial-breakdowns} |
| 350 | ## Every breakdown variable carries a universe {#sec-universe} |
| 356 | ## Worked example: adding sector of employment {#sec-example-sector} |
| 364 | # Qualifiers {#sec-qualifiers} |
| 372 | ## Poverty lines {#sec-povlines} |
| 380 | ## PPP beyond poverty {#sec-ppp} |
| 384 | # Metadata files {#sec-metadata} |
| 398 | ## Code rules {#sec-code-rules} |
| 409 | ## `CL_INDICATOR.csv`: the indicator dictionary {#sec-cl-indicator} |
| 421 | ## `CL_BRK_VAR.csv` {#sec-cl-brk-var} |
| 427 | ## `CL_COMP_BREAKDOWN.csv` {#sec-cl-comp-breakdown} |
| 433 | ## `CL_QUAL_VAR.csv` and `CL_QUALIFIER.csv` {#sec-cl-qual} |
| 441 | ## `CL_GEO_SCHEME.csv` and `CL_GEO.csv` {#sec-cl-geo} |
| 457 | ## `CL_AREA.csv` {#sec-cl-area} |
| 463 | ## Small codelists {#sec-small-codelists} |
| 471 | ## `SURVEYS.csv` {#sec-surveys} |
| 477 | ## Manifest {#sec-manifest} |
| 489 | ## `TAB_PLAN.csv`: which cuts are produced {#sec-tab-plan} |
| 501 | ## `SERIES_PLAN.csv` {#sec-series-plan} |
| 513 | ## Verification rules: `RULES.csv` {#sec-rules} |
| 534 | ## Relations: `INDICATOR_QUALIFIERS.csv` and `QUALIFIER_PAIRS.csv` {#sec-relations} |
| 546 | ## Sources: `SOURCES.csv` {#sec-sources} |
| 554 | ## Legacy mapping files {#sec-legacy-maps} |
| 570 | # What a producer delivers {#sec-deliver} |
| 580 | ## Estimation rules {#sec-estimation} |
| 588 | ## A note on legacy conversions {#sec-legacy} |
| 596 | ## How the dashboard shows reliability {#sec-reliability} |
| 606 | # How to extend {#sec-extend} |
| 633 | ## Add an indicator {#sec-add-indicator} |
| 643 | ## Add a breakdown variable {#sec-add-breakdown} |
| 647 | ## Add a qualifier variable {#sec-add-qualifier} |
| 654 | ## Add a country {#sec-add-country} |
| 671 | # Boundaries and figures {#sec-assets} |
| 675 | ## Maps exist for countries and ADM1 only {#sec-maps-scope} |
| 679 | ## Storage {#sec-geo-storage} |
| 700 | ## Figures {#sec-figures} |
| 706 | ## Extending {#sec-extend-assets} |
| 717 | # Dashboard text {#sec-text} |
| 726 | ## `TEXT.csv` {#sec-text-csv} |
| 738 | ## Live numbers in prose {#sec-live-numbers} |
| 752 | ## What this replaces {#sec-text-replaces} |
| 758 | ## Extending {#sec-extend-text} |
| 762 | # Change control {#sec-change-control} |
| 776 | ## Generated tables {#sec-generated-tables} |
| 787 | # Validation checks (to be implemented in R) {#sec-validation} |
| 884 | # Decisions {#sec-decisions} |
| 886 | ## Decisions taken {#sec-decisions-taken} |
| 911 | ## Open decisions {#sec-open-decisions} |
| 925 | # Annex. Mapping the current tables {#sec-appendix-legacy .unnumbered} |
| 931 | ## Annex 1. Indicators {#sec-legacy-indicators .unnumbered} |
| 954 | ## Annex 2. The `Departement` sheet {#sec-legacy-departement .unnumbered} |
| 958 | ## Annex 3. Columns to dimensions {#sec-legacy-columns .unnumbered} |
| 968 | # Changes since v0.4 {#sec-changes-v05} |
| 992 | # Changes since v0.3 {#sec-changes-v04} |

Top-level section summaries:

- **sec-idea (37-206):** One row = one number; codes split into breakdowns (who, `_T`, sum to parent) and qualifiers (what, `_Z`, equal the parent); series = indicator + qualifiers + defining category (D13). Repository layout of seven folders, "metadata first, data last", bootstrap frozen (D11), migrations as scripts (D12).
- **sec-data (207-331):** Dataflow `AFW360_HH`: exactly 31 columns, 19-column key; sentinels `_T/_Z` (+ reserved `_U/_O/_X`); ESTIMATION SURVEY/MODEL; slot-filling rules; unrounded base-unit values, UNIT_MEASURE/PRECISION/SOURCE_ID per row, no suppression, OBS_STATUS precedence; required rows = SERIES_PLAN × TAB_PLAN − exclusions − withheld.
- **sec-breakdowns (332-363):** Breakdown variables in CL_BRK_VAR/CL_COMP_BREAKDOWN with universe, applies_to_units, slot_order (immutable once ACTIVE); worked example sector of employment.
- **sec-qualifiers (364-383):** Qualifier variables in CL_QUAL_VAR/CL_QUALIFIER; poverty lines and PPP rounds as qualifiers; LCU values carry no PPP.
- **sec-metadata (384-569):** Reference for every metadata/content CSV: common codelist columns, code rules (≤32 chars, series ids dot-joined, source ids `_v<N>`), each codelist's extra columns, SURVEYS, manifest keys, TAB_PLAN, SERIES_PLAN, RULES vocabulary and rule_id convention, relations tables, SOURCES, legacy maps.
- **sec-deliver (570-605):** Producer checklist (data file, all rows, SOURCES row, manifest, metadata PR); estimation rules (design-based SE, publish everything); legacy exemption by source kind; dashboard reliability display and loader contract (name_en, UNIT_MEASURE, display_as, decimals).
- **sec-extend (606-670):** Extension table (files to edit, structural?, version bump); step lists for indicator, breakdown, qualifier, country.
- **sec-assets (671-716):** Maps only ADM0/ADM1; GeoPackage storage in EPSG:4326 with `geo_code/ref_area/scheme`; FIGURES registry; references by ID.
- **sec-text (717-761):** TEXT.csv + `content/text/<ISO3>/<slot>.md`; planned SLOTS.csv; live-number syntax `{{INDICATOR:QUALIFIER@DIM=CODE}}` (sketch); what it replaces.
- **sec-change-control (762-786):** Git PRs, append-only rows, VERSION bump + CHANGELOG, 0.x pre-release (D24); structural changes need new DSD/COLUMNS + migration; generated tables via build_docs.R (D20).
- **sec-validation (787-883):** Validator spec: findings CSV columns; Structure, Codes, Coverage, Values, RULES checks with tolerances, deterministic output (sort by 19 key columns, LF, no BOM, empty not NA), Assets, Text, Metadata files, Documentation.
- **sec-decisions (884-924):** Decisions table and 11 open decisions.
- **Annex (925-967):** Legacy label/column mapping pointers; Departement sheet skipped (D3).
- **Changes since v0.4 / v0.3 (968-1032):** D12–D26 and D1–D11 + lettered changes (a)–(aa).

Includes (22): `generated/tbl-columns.md` (219), `tbl-obs-status` (283), `tbl-brk-vars` (344), `tbl-qual-vars` (370), `tbl-povlines` (376), `tbl-cl-indicator` (413), `tbl-cl-brk-var` (425), `tbl-cl-geo-scheme` (447), `tbl-cl-geo` (451), `tbl-small-codelists` (467), `tbl-surveys` (475), `tbl-tab-plan` (495), `tbl-initial-plan` (499), `tbl-series-plan` (505), `tbl-rules` (517), `tbl-indicator-qualifiers` (540), `tbl-qualifier-pairs` (544), `tbl-sources` (550), `tbl-legacy-labels` (560), `tbl-legacy-columns-csv` (564), `tbl-legacy-overrides` (568), `tbl-text` (730).

**Decisions table (tbl-decisions, 888-909)** has unnumbered rows: Breakdowns (named GEO/URBANISATION/SEX/AGE + 5 slots); Qualifiers (5 slots); Population shares (POP_SH/POP_HH_SH/POP_HE_SH); Suppression (none); Geography (parallel schemes, maps ADM0/ADM1); Language (English); Who extends codelists (producers via PR); Tooling (R pipeline, Python/Quarto dashboard, one loader); Estimation method (D17); Series identity (D13); Units and precision (D14, D15); Provenance (D16); Rules and relations (D18); Counts on share rows (D19); Reliability (D22); Series a country cannot match (D23); Versioning (D24); Documentation (D20).

Numbered decisions (from the change tables 972-1031):

| id | choice |
|---|---|
| D1 | R for bootstrap, converter, validator; dashboard stays Python/Quarto with one loader |
| D2 | `data_raw/` byte-frozen, proven by CHECKSUMS.sha256 |
| D3 | `Departement` sheet skipped (all 82 labels SKIP) |
| D4 | population shares split POP_SH / POP_HH_SH / POP_HE_SH |
| D5 | defective legacy cells withheld via LEGACY_OVERRIDES (WITHHOLD / COMMENT) |
| D6 | GNB survey = EHCVM 2021/22, TIME_PERIOD 2021, `GNB_EHCVM_2021` |
| D7, D8, D10 | **not present** in the document |
| D9 | OBS_STATUS=O = "no value available"; legacy O rows need `LEGACY_EMPTY:` comment |
| D11 | `pipeline/` layout; bootstrap generates 0.1.0 then frozen; SERIES_PLAN, LEGACY_COLUMNS, LEGACY_OVERRIDES added |
| D12 | structural changes via one-off migration scripts |
| D13 | SERIES_ID attribute + SERIES_PLAN.name_en; id = indicator.qualifiers.defining category |
| D14 | UNIT_MEASURE per row, LCU resolved to ISO 4217 |
| D15 | PRECISION per row; manifest `precision` key removed |
| D16 | SOURCE_ID per row + SOURCES.csv; manifest `sources` |
| D17 | ESTIMATION key dimension (SURVEY/MODEL), CL_ESTIMATION, file name suffix |
| D18 | RULES.csv, INDICATOR_QUALIFIERS.csv, QUALIFIER_PAIRS.csv replace packed columns |
| D19 | share rows: N_OBS/N_POP are the denominator; EQUALS_NPOP_RATIO retired |
| D20 | generated doc tables, stale = validator ERROR |
| D21 | `_U/_O/_X` reserved; no code starts with `_` |
| D22 | OBS_STATUS U/D/Q added; U by RULES thresholds; precedence M O E D U A |
| D23 | SERIES_PLAN country rows NOT_PRODUCED / DEVIATES |
| D24 | 0.x pre-release: structural changes = minor bumps until 1.0.0 |
| D25 | slot_order immutable once ACTIVE |
| D26 | 31 columns, 19-column key; validator checks specified |

Open decisions (911-923): 1 HHH age cutoff; 2 quintile definition; 3 governance; 4 GNB survey (closed by D6); 5 where large binaries live; 6 boundary vintage policy; 7 where variable-level metadata lives; 8 country cannot produce (closed by D23); 9 Departement sheet (closed by D3); 10 reference syntax for live numbers; 11 MODEL value that also fails reliability (E hides U).

**`.docs/transition.qmd` (103 lines):** 13 `# In one paragraph`; 17 `# Before and after`; 28 `# What was done by hand`; 44 `# What was done by code`; 63 `# Main decisions`; 74 `# Results`; 83 `# What is still open`; 90 `# After acceptance: standard v0.5 and metadata 0.2.0`; 101 `# How the work was run` (detailed plan removed, in git history at `af378e9` under `.docs/transition/`).

Other `.docs/` files: `input-tables-findings.qmd` 303 lines (Appendix A), `shiny-port-plan.md` 600 lines (not rendered), `styles.css` 66.

## 10. Git

- Branch: `dev/eb` (main branch `master`).
- Untracked: `README.md` (root; `git status --short` shows only `?? README.md`).
- Last 15 commits:
```
a32096c Merge branch 'standard/v0.5' into dev/eb
6c260b9 WP-C review follow-ups: COVER.FILE_MISSING, radix sorts, shared helpers
a23e5ab Standard: a missing country file is a WARN; clarify partial partitions; mark deferred text checks
1be4bb2 Standard: settle the six points the validator implementation surfaced
0ae5b02 WP-C: validator on metadata 0.2.0 and the 31-column data files (standard v0.5)
6844160 build_docs: sort by position and slot_order; keep each cell on one line
7c473c1 Transition appendix: v0.5 follow-up, new file names, migration and docs steps
cdc4232 Standard wording after WP-B and WP-D; fix the DEFINING_BREAKDOWN description
0c4c37a Merge WP-D: documentation generator and the 22 generated table fragments
71bf70f WP-B: converter, manifest and reconciliation on DSD 0.2.0; regenerate data
ecf6454 Documentation generator: build_docs.R and the 22 generated tables (standard v0.5, WP-D)
d0ae53a Reword the last mentions of the removed valid_with and qualifiers columns
5f33855 Metadata 0.2.0: migration 0.1.0 -> 0.2.0 (standard v0.5, WP-A)
1266f84 Standard v0.5: series, unit, precision, source and estimation columns; rules as tables
52226c1 Replace the transition working files with a one-page summary
```
- `.gitignore` does **not** exclude `data/`, `geo/` or `assets/` (43 files tracked under data/geo/assets/content/metadata). Its full content: `*_files/`, `*.html`, `.Rhistory`, `*.quarto_ipynb`, `_site/`, `*_libs/`, `.quarto/`, `/.quarto/`, `**/*.quarto_ipynb`, `site_libs/clipboard/clipboard.min.js`, `.venv/`, `__pycache__/`, `*.py[cod]`, `.pytest_cache/`, `rsconnect-python/`, `_shinylive/`, `.claude/worktrees/`. Note `*.html` is ignored globally (relevant if SDMX-ML/HTML outputs are added; `.xml`/`.json` are not ignored).
- `.gitattributes`: `*.csv`, `*.R`, `*.md`, `*.qmd`, `*.sha256`, `metadata/VERSION` → `text eol=lf`; `data_raw/** -text`; `*.gpkg`, `*.xlsx`, `*.png` binary. No rule for `.xml`/`.json` (new SDMX-ML/JSON files would get CRLF under core.autocrlf=true unless a rule is added).

## 11. Inconsistencies

| # | evidence | issue |
|---|---|---|
| 1 | `.docs/data-standard.qmd:122`, `:1003` | Layout lists `pipeline/acceptance/` ("acceptance scripts, one per work package"); the folder does not exist. |
| 2 | `.docs/data-standard.qmd:170`, `:695` | `geo/derived/` described; does not exist. |
| 3 | `.docs/data-standard.qmd:115` | `data_raw/scratch/` listing omits `Messages_SEN.txt2`, which exists (CLAUDE.md lists it). |
| 4 | `.docs/data-standard.qmd:485` vs `:1022` | §Manifest says `dsd_version` equals `metadata/VERSION`; change (s) says it is read from "`DSD_AFW360_HH.csv`'s own `VERSION`" (no such thing exists). |
| 5 | `.docs/data-standard.qmd:1021` | change (r) says "sort by the 18 key columns"; current rule is 19 (`:847`). Historical row, but stale. |
| 6 | `.docs/data-standard.qmd:972-1031` | Decision ids D7, D8, D10 never appear. |
| 7 | `.docs/data-standard.qmd:1002` | D9 text refers to "a `ROUNDED_2DP` legacy file" (0.1.0 manifest `precision`/`source_type` concept removed by D15/D16). |
| 8 | `README.md` (untracked) "What is where" table, "add new data" step 3 | Data file named `AFW360_HH_SEN_2021.csv` / `data/AFW360_HH_<ISO3>_<YEAR>.csv`; actual names carry `_SURVEY` (D17). |
| 9 | `README.md` "Status" | says "Done: standard v0.4"; standard is v0.5 / metadata 0.2.0. README rebuild list also omits `build_docs.R` (pipeline/README.md includes it). |
| 10 | `.gitattributes:3` | cites `.docs/transition/plan.qmd`, which was removed (transition.qmd:103 says it is only in git history at `af378e9`). |
| 11 | `pipeline/R/io.R` header ("COMMON.md section 3"), `R/codes.R` ("COMMON.md section 4"), `R/validate_assets.R`, `R/validate_text.R` ("COMMON.md wave 3"), `R/geo.R` ("WP05.md") | Referenced planning documents no longer exist in the tree. |
| 12 | `pipeline/build_content.R:148` | A live (non-bootstrap) script reads `pipeline/bootstrap/text/figures_text.csv`, although bootstrap is declared frozen (D11). |
| 13 | `pipeline/R/validate_coverage.R:224` | `COVER.FILE_MISSING` builds the expected stem with literal `_SURVEY` (fine per standard :820, but a hard-coded estimation). |
| 14 | `CLAUDE.md` "Layout" | Describes only `data_raw/` inputs; does not mention `data/`, `metadata/`, `geo/`, `content/`, `assets/`, `pipeline/`. |
| 15 | `metadata/structure/DSD_AFW360_HH.csv` row 20, 22 | `SERIES_ID` "codelist" is `SERIES_PLAN` (a plan, not a codelist); `UNIT_MEASURE` codelist `CL_UNIT` but values include `XOF` not in CL_UNIT — matters when mapping to SDMX coded attributes. |
| 16 | `metadata/codelists/CL_INDICATOR.csv` | `unit_time` has value `TBD` on one row (enum DAY/MONTH/YEAR expected); `universe_unit`, `unit_denom` not reference-checked by `vc_meta_reference` (`validate_metadata.R:230-234`). |
| 17 | `metadata/registries/SOURCES.csv` | `run_date=2026-01-01` equals the injected timestamp, not a real run date. |
| 18 | COLUMNS.csv vs files | No mismatch: every declared file exists and every header equals its declared column list in order. |
| 19 | `.docs/generated/` vs includes | No mismatch: 22 fragments, 22 includes, all resolve. |
