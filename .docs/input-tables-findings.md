# Input tables: structure, dimensions and data-quality findings

Review of `INPUT Tables/Tables_SEN.xlsx` and `INPUT Tables/Tables_GNB.xlsx`, 2026-09-19.
Every sheet, row and cell was read. No input file was modified.

## 1. File layout

Both workbooks share one skeleton:

- Header in row 1. No rows above it, no blank or section-header rows, no merged cells, no hidden rows, columns or sheets, no formulas, no comments.
- Column A, `indicator`, holds one free-text label per row. It is the only row identifier; there are no indicator codes.
- Every other column is named `estimate<Group>` and holds one value per indicator for that group.
- Values are literal numbers already rounded to 2 decimals, with Excel number format `0.00`.
- Missing values are empty cells. No text, sentinel strings or error values appear in the numeric columns.
- The rows are sorted by label in code-point order (so `COICOP 10` comes before `COICOP 1`, and `≥1 HH member…` is always last). The order carries no thematic meaning.
- Both files were written by a script (`creator = openpyxl` in the file metadata). The 32-character cut-off in some column names matches Stata's variable-name limit, so the tables most likely come from a Stata pipeline exported to Excel, but the file itself only proves the last step.

| Sheet | SEN (rows × groups) | GNB (rows × groups) | Columns hold |
|---|---|---|---|
| `National` | 97 × 13 | 97 × 13 | Population groups |
| `ADM 1` | 97 × 14 | 97 × 9 | Regions |
| `ZAE` | 97 × 6 | 97 × 4 | Agro-ecological zones |
| `Departement` | 82 × 14 | — | Regions (mislabelled; see 6.1) |

The dashboard reads only `National`, `ADM 1` and `ZAE`. `Departement` is never read.

`Tables_SEN_TEST.xlsx` is a scratch file: one sheet (`Sheet1`), 2 indicators (`Poverty rate`, `Number poor (millions)`) and columns `Total, Capital, Other urban, Rural` with no `estimate` prefix. It does not follow the schema above.

## 2. Dimensions

The sheets are not really levels of geography. Each sheet is a set of **one-way breakdowns of the national population**: each cell is one indicator computed over one subgroup. Breakdowns are never crossed (there is no "rural × female head" and no "region × quintile").

| Breakdown | Sheet | Groups (column suffix after `estimate`) |
|---|---|---|
| Total | `National` | `Total` |
| Residence | `National` | `Capital`, `Other_Urban`, `Rural` |
| Sex of household head | `National` | `Female_HH`, `Male_HH` |
| Age of household head | `National` | `Youth_HH`, `Older_HH` |
| Consumption quintile | `National` | `Q1`, `Q2`, `Q3`, `Q4`, `Q5` |
| Region | `ADM 1` | country-specific (see 5) |
| Agro-ecological zone | `ZAE` | country-specific (see 5) |

Notes:

- Residence has three categories. There is no `Urban` column, so "urban" would have to be derived from `Capital` + `Other_Urban`.
- The age cutoff between `Youth_HH` and `Older_HH` is not documented anywhere.
- Counts add up within a breakdown, with one exception. `Number poor $4.20/day (millions)` summed over regions equals the national total (SEN 6.52, GNB 1.09), and summed over zones gives SEN 6.52 and GNB 1.08 (rounding). The same holds for sex, age and quintile in both countries. The exception is GNB's residence split, which overshoots by about 14% (1.24 vs 1.09 at $4.20, and 0.80 vs 0.70 at $3.00); see 6.3.

### Implicit dimensions

These never appear as their own column:

| Dimension | Where it is encoded today |
|---|---|
| Country | File name only |
| Breakdown family | Sheet name, and column-name patterns within `National` |
| Group / geographic unit | Column-name suffix, by name only (no admin codes) |
| Indicator | Free-text label |
| Poverty line | Inside the label (`$3.00/day`, `$4.20/day`) |
| PPP year | Inside the label (`2021 PPP`; `2017 PPP` in `Departement`) |
| Unit | Inside the label for some indicators (`(FCFA)`, `(ha)`, `(millions)`, `(share)`, `(years)`, `(code)`); inferred from magnitude for the rest |
| Classification codes | Inside the label (`COICOP 4:`, `SDG 7.1.1`) |
| Reference period / age band | Inside the label (`activ12m`, `15–64`, `last 7 days`, `past 3 years`) |

Not present at all: survey name and year, data source, standard errors or confidence intervals, sample sizes, and admin codes for regions and zones.

## 3. Indicator catalogue

The 97 labels are byte-identical, and in the same order, in `National`, `ADM 1` and `ZAE` for both countries. Unit is "share" (0–1) unless stated.

**Monetary poverty (4)**
- `Poor at $3.00/day (2021 PPP)`
- `Poor at $4.20/day (2021 PPP)`
- `Number poor $3.00/day (millions)`: millions of people
- `Number poor $4.20/day (millions)`: millions of people

**Consumption (18)**
- `COICOP 1: food & non-alc. beverages (share)`
- `COICOP 2: alcohol & tobacco (share)`
- `COICOP 3: clothing & footwear (share)`
- `COICOP 4: housing & utilities (share)`
- `COICOP 5: furnishings & equipment (share)`
- `COICOP 6: health (share)`
- `COICOP 7: transport (share)`
- `COICOP 8: information & communication (share)`
- `COICOP 9: recreation & culture (share)`
- `COICOP 10: education (share)`
- `COICOP 11: restaurants & hotels (share)`
- `COICOP 12: insurance & financial (share)`
- `COICOP 13: personal care & effects (share)`
- `Food consumption share` (same values as COICOP 1)
- `Non-food consumption share`
- `Own-production food share (% total cons.)` (stored as a share despite "%")
- `Market food share (% total cons.)` (stored as a share despite "%")
- `Housing & utilities burden (COICOP 4 share of total cons.)` (same values as COICOP 4)

**Jobs (9)**
- `Employed (activ12m, 15–64)`
- `Employed in agriculture (% of employed)`
- `Employed in industry (% of employed)`
- `Employed in services (% of employed)`
- `Wage-employed (% of employed)`
- `Non-wage employed (% of employed)`
- `Share of HH workers in trade/commerce`
- `Share of HH workers in transport`
- `Share of HH workers informally employed`

All "(% of employed)" values are stored as shares.

**Household enterprises (31)**
- Shares (23): `HE buys from firms/state`, `HE sells to firms/state`, `HE has any credit access`, `HE has formal credit access`, `HE has informal credit access`, `HE has electricity`, `HE has water`, `HE has phone`, `HE has tax ID`, `HE has formal premises`, `HE keeps accounts`, `HE operates from home`, `HE pays rent`, `HE has external (non-HH) employees`, `Main HE owner is female`, `Main HE owner is married`, `HH has 0 HE`, `HH has 1 HE`, `HH has 2 HE`, `HH has 3 HE`, `HH has 4+ HE`, `HH has non-agric enterprise owner`, `HH owns a non-agric enterprise`
- Levels (8):
  - `HE age (years)`: years; most likely enterprise age, not owner age
  - `HE capital stock (FCFA)`: FCFA
  - `HE costs (FCFA)`: FCFA
  - `HE profits (FCFA)`: FCFA; can be negative
  - `HE revenue per worker (FCFA)`: FCFA
  - `Number of employees in HE`: mean count
  - `Non-HH employees in HE`: mean count
  - `HH employees in HE`: mean count

**Agriculture (4)**
- `HH cultivates agricultural land (superf > 0)`
- `HH owns any livestock`
- `Tropical Livestock Units (TLU)`: TLU
- `Cultivated area (ha)`: hectares

**Energy (17)**
- `Access to electricity (grid, SDG 7.1.1)`
- `Connected to electricity grid (SDG7.1.1)`
- `Uses grid electricity`
- `Uses solar/generator electricity`
- `Improved lighting (grid or solar)`
- `Informal electricity connection (neighbour/pole)`
- `Prepaid meter (among grid-connected)`
- `Any power outage in last 7 days (grid-connected)`
- `Days with an outage (last 7)`: mean days, 0–7
- `Average outage duration (code)`: mean of an ordinal code, not a time unit
- `Monthly electricity spend (FCFA)`: FCFA
- `Primary cooking fuel biomass (wood/charcoal)`
- `Primary cooking fuel clean (gas/electricity)`
- `Proxy: owns gas/electric cooker (cuisin)`
- `Owns ceiling fan`
- `Owns wall AC/split`
- `Owns water heater`

**Housing and services (6)**
- `Durable floor materials`
- `Durable roof materials`
- `Durable wall materials`
- `Safe drinking water – dry season`
- `Sanitary toilet facility`
- `HH has internet access`

**Shocks (5)**
- `Covariate economic shock`
- `Covariate natural shock (drought, flood, etc.)`
- `Covariate violence/conflict shock`
- `Idiosyncratic economic shock`
- `Exposed to any shock (past 3 years)`

**Social protection (2)**
- `Has health insurance/coverage (couvmal)`
- `≥1 HH member has health coverage (proxy social protection)`

**Placeholder (1)**
- `wood_dist [ALL MISSING]`: every cell empty in every sheet of both countries

In total, 82 indicators are shares and 15 are levels (millions, FCFA, years, counts, TLU, hectares, days, code). Nothing in the file marks which is which.

## 4. Value conventions

- Shares are stored as 0–1 decimals, never 0–100, including labels that say "%".
- Levels are stored in the same columns as shares, with no unit or type field. A single number format cannot fit every row.
- Values are rounded to 2 decimals at source. Anything below 0.005 is stored as 0.00 and cannot be told apart from a true zero.
- An empty cell can mean either "not computed" (`wood_dist`) or "too few observations in this group" (scattered blanks in small regions). The file does not distinguish the two. Empty must not be read as zero.
- Labels contain non-ASCII characters: en-dash `–` (`15–64`, `Safe drinking water – dry season`) and `≥`. SDG is written both as `SDG 7.1.1` and `SDG7.1.1`. Matching by typed text is fragile.

## 5. Common vs country-specific

### Common to SEN and GNB

- The same 97 indicator labels, in the same order, on `National`, `ADM 1` and `ZAE`.
- The same 13 `National` groups.
- The same storage conventions (sections 1 and 4).
- The same currency (FCFA). This is because both countries are in the West African monetary union (WAEMU); it will not hold for every AFW country.
- The same defects (section 6.2).

### Country-specific

| | SEN | GNB |
|---|---|---|
| Regions (`ADM 1`) | 14, uppercase ASCII | 9, mixed case with accents |
| Region names | `DAKAR`, `DIOURBEL`, `FATICK`, `KAFFRINE`, `KAOLACK`, `KEDOUGOU`, `KOLDA`, `LOUGA`, `MATAM`, `SAINT_LOUIS`, `SEDHIOU`, `TAMBACOUNDA`, `THIES`, `ZIGUINCHOR` | `Bafatá`, `Biombo`, `Bolama_Bijagós` (underscore stands for "/"), `Cacheu`, `Gabú`, `Oio`, `Quinara`, `SAB` (Bissau Autonomous Sector), `Tombali` |
| Zones (`ZAE`) | 6, named by joining region names, so they are groupings of regions | 4, Portuguese agro-ecological names |
| Zone names | `Dakar`, `Kaolack_Fatick_Kaffrine`, `Kedougou`, `Saint_Louis_Matam`, `Thies_Diourbel_Louga`, `Ziguinchor_Tamba_Kolda_S` (truncated) | `Zona_Plana_de_Centro_Bis` (truncated), `Zonas_Costeiras_do_Sul`, `Zonas_Montanhosas_de_Les` (truncated), `Zonas_Planas_de_Norte` |
| Extra sheet | `Departement` (see 6.1) | none |
| Empty cells: `National` / `ADM 1` / `ZAE` | 13 / 18 / 7 | 28 / 45 / 10 |
| Sparsest columns | `FATICK`, `KAFFRINE`, `KEDOUGOU`, `KOLDA` (2 each on `ADM 1`), `Kedougou` (2 on `ZAE`) | `Tombali` (11), `Bafatá` (7), `Q1` (7) |
| `Capital` column | Equals `DAKAR` on all 97 indicators | Equals the `Zonas_Costeiras_do_Sul` zone, not `SAB` (see 6.3) |

GNB's extra missingness is concentrated, not spread evenly:

- `HE revenue per worker (FCFA)` is blank in 7 of 9 regions (all but `Cacheu` and `SAB`), 2 of 4 zones and 5 of 13 national groups, so it is unusable below the national level. It is fully populated in SEN.
- `HE has electricity`, `HE has water` and `HE pays rent` are blank together for the same four regions (`Bafatá`, `Biombo`, `Bolama_Bijagós`, `Tombali`) and for `Q1` on `National`, which looks like suppression of small subsamples.

The file records no sample sizes, so a smaller GNB survey is a plausible but unverifiable explanation.

## 6. Discrepancies and data-quality issues

### 6.1 SEN `Departement` sheet

- It contains the same 14 regions as `ADM 1`, spelled identically. There is no département-level data in the file.
- It is an older or different version of the regional table:
  - Poverty is at 2017 PPP (`Poor at $3.00/day (2017 PPP)`, `Poor at $4.20/day (2017 PPP)`) instead of 2021 PPP.
  - How far its values drift from `ADM 1` varies by indicator. Six of the 60 shared indicators are identical (`Employed (activ12m, 15–64)`, `Employed in agriculture`, `Wage-employed`, `Non-wage employed`, `HH has internet access`, `Has health insurance/coverage (couvmal)`). Most others differ modestly. The household-enterprise money variables differ heavily: up to 94% for `HE revenue per worker`, 68% for `HE capital stock`, 74% for `HE costs`, and 14.7x for `HE profits`.
- Its indicator set does not match: 82 rows, 60 shared with the other sheets, 22 unique and 37 missing.
  - Unique rows include raw variable names: `(max) con_1` … `(max) con_15`, `(max) ext_emp`, `npoor300`, `npoor420`.
  - Also unique: `Access to electricity (grid or off-grid)`, `Energy expenditure burden (share of total cons.)`.
  - Its 15 `con_*` consumption categories do not line up with the 13 COICOP rows elsewhere.
- Some values are impossible:
  - `HE has any credit access` is 1.00 in all 14 regions (0.14–0.59 in `ADM 1`).
  - `HE has formal credit access` is 0.72–0.95 in every region (0.00–0.23 in `ADM 1`). `HE has informal credit access` looks unaffected (0.09–0.37, against 0.09–0.40 in `ADM 1`).
  - `HH has 4+ HE` is 0.80–1.00 in every region, although `HH has 0/1/2/3 HE` already sum to about 1 (at most 0.03 in `ADM 1`).

### 6.2 Issues in both countries

| Issue | Evidence |
|---|---|
| Empty placeholder indicator | `wood_dist [ALL MISSING]` has no values anywhere |
| Indicator with no information | `HH has internet access` is 0.00 or empty in every cell of both countries |
| Duplicate indicators | `Food consumption share` = `COICOP 1…`; `Housing & utilities burden…` = `COICOP 4…` (identical values in every column) |
| Three overlapping electricity indicators | `Access to electricity (grid, SDG 7.1.1)`, `Connected to electricity grid (SDG7.1.1)` and `Uses grid electricity` differ by country: GNB national totals are 0.23 / 0.27 / 0.26, but SEN's are 0.68 / 0.98 / 0.66, a 32-point spread. The definitions need documenting before any of the three is presented as "electricity access" |
| Rows with no variation at 2 decimals | `COICOP 12` is 0.00 in every column of both countries. `COICOP 9` is 0.00 in every column in SEN and on GNB `National`. `COICOP 2` is 0.00 on SEN `National` and `ZAE`, and 0.01 in every column in GNB |
| Truncated column names | Names cut at exactly 32 characters (SEN `Ziguinchor_Tamba_Kolda_S`; GNB `Zona_Plana_de_Centro_Bis`, `Zonas_Montanhosas_de_Les`) |
| No geographic codes | Regions and zones are identified only by spelled names, and spelling conventions differ between countries |
| Ambiguous unit | `Average outage duration (code)` is a mean of an ordinal code, not a duration |

### 6.3 GNB-specific issues

**The `Capital` column does not hold Bissau. It holds a copy of a zone.**

`National` `estimateCapital` is identical to `ZAE` `estimateZonas_Costeiras_do_Sul` on all 97 indicators. Against `SAB`, it matches on only 9 of 97, and all nine are rows that are constant everywhere anyway (`wood_dist`, `COICOP 12`, `HE has external (non-HH) employees` and similar). The gap is not confined to poverty:

| Indicator | GNB `Capital` | GNB `SAB` |
|---|---|---|
| `Poor at $4.20/day (2021 PPP)` | 0.79 | 0.21 |
| `Access to electricity (grid, SDG 7.1.1)` | 0.01 | 0.70 |
| `Durable floor materials` | 0.33 | 0.97 |
| `Cultivated area (ha)` | 53,028,771 | 1.30 |

For comparison, SEN `Capital` is identical to `DAKAR` on all 97 indicators, and SEN's single-region zones `Dakar` and `Kedougou` are identical to regions `DAKAR` and `KEDOUGOU` on all 97. So the pattern is specific to GNB and looks like a coding error in the residence variable, not a definitional difference.

Two other findings in this section follow from it: the `Capital` cultivated-area outlier is the zone's value, and the residence breakdown fails to add up (see below).

| Issue | Evidence |
|---|---|
| Residence breakdown does not add up | `Capital` + `Other_Urban` + `Rural` gives 1.24M poor at $4.20 against a national 1.09M, and 0.80M against 0.70M at $3.00, about 14% too high. Every other GNB breakdown adds up. |
| `Cultivated area (ha)` is corrupted | Values in the millions of "ha": `National` Total 9.1M, `Capital` 53.0M, `Rural` 10.8M, `Male_HH` 10.4M, `Older_HH` 10.5M, `Q4` 57.9M; `ZAE` `Zonas_Costeiras_do_Sul` 53.0M; `ADM 1` `Quinara` 148.4M. Other cells are 1–15 ha. Outlier records, probably a unit error in the microdata, inflate every mean they enter. The `Quinara` and `Q4` values are separate from the `Capital` mix-up above. |
| Constant indicators | `HE has external (non-HH) employees` = 1.00 and `HH employees in HE` = 0.00 in every cell; `HE pays rent` = 1.00 in every populated cell (blank for `Q1` and four regions); `HH has 4+ HE` = 0.00 on `National` and `ZAE` |
| Possible definition mismatch | `Number of employees in HE` ranges 0–0.46 in GNB versus 0.33–3.09 in SEN, which suggests a different definition or computation |

### 6.4 SEN-specific notes

- `HE profits (FCFA)` for `TAMBACOUNDA` is the only negative value in either country: −3,460 on `ADM 1` and −50,754 on `Departement`, a factor of 14.7 apart. A loss-making average may be genuine, but it breaks any assumption that levels are non-negative, and the two tables disagree on its size.

## 7. Consistency checks that hold

Checked across every cell of both countries, and correct:

- `Poor at $3.00/day` never exceeds `Poor at $4.20/day`.
- Poverty falls monotonically from Q1 to Q5.
- Regional values bracket the national value.
- COICOP 1–13 sum to 0.96–1.02, which is what rounding 13 two-decimal shares produces.
- Agriculture + industry + services, and food + non-food, sum to about 1; wage + non-wage sums to exactly 1.00.
- `HH has 0/1/2/3/4+ HE` sums to about 1, except on SEN `Departement`.
- `HE has any credit access` is at least as large as its formal and informal components, except on SEN `Departement`.

Two notes for anyone re-running these checks:

- Scanning for identical columns or rows produces false positives. Some indicator pairs match only because both are near zero everywhere (for example GNB `Owns wall AC/split` and `≥1 HH member has health coverage`). Require the values to vary before calling a pair a duplicate.
- The duplicates in 6.2 pass that test: they track each other across the full range.

## 8. What harmonization will need

- A long table with one row per country × breakdown × group × indicator, holding the value.
- An indicator dictionary: stable code, label, theme, unit / value type, display format, poverty line, PPP year, source variable.
- A geography lookup: admin code, level and display name for every region and zone, replacing name-based matching.
- A way to mark missing values that separates "not computed" from "suppressed (small sample)".
- Fixes in the upstream pipeline, not the dashboard, for 6.1, the GNB `Cultivated area (ha)` outliers, the GNB `Capital` coding, and the constant or duplicate indicators.
