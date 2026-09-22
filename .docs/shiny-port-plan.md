# Plan: port AFW 360 At A Glance to a Shiny for Python dashboard

**Status:** approved plan, not yet implemented.
**Date:** 2026-09-21.
**Scope:** replace the static Quarto page `index.qmd` with an interactive Shiny for
Python application, deployed to Posit Connect, with a static export kept on GitHub
Pages.

This document is the implementation contract. It records *why* the current page fails,
*what* was decided and by whom, and *how* to build the replacement. Read it in full
before writing code.

---

## 1. Context

`index.qmd` (1,195 lines, 30 Python chunks) renders a poverty and welfare dashboard for
Senegal and Guinea-Bissau from pre-computed Excel tables. It is meant to be a
dashboard. It currently renders as a static, scrolling web page with no interactivity,
no tabs, no panel titles and no filters.

### 1.1 The root cause

The file **was written as `format: dashboard`** and was converted to `format: html` in
commit `574527a` ("Convert to website: add index and site config"). Verified:

```
$ git show 024627e:"AFW 360 Pilot.qmd" | head -5
---
title: "AFW 360 PILOT"
author: "AFW DIP/POV Team"
format: dashboard
scrolling: true
---
```

All the dashboard layout markup survived the conversion but is now inert:

| Markup in the file | What it does under `format: html` |
|---|---|
| `#| title:` on 27 chunks | Dashboard-only cell option, silently dropped. **No panel title renders.** |
| `## Row Messages {height=10%}` | Renders as a literal `<h2>` reading "Row Messages". `{height=}` ignored. |
| `### Column {.tabset}` | Produces **no tabs** — HTML tabsets need `####` children; here the children are code chunks. The five Profile tables stack vertically. |
| `scrolling: true` (line 10) | Sits outside `format:`, inert. |

**Consequence for the port:** the 27 `#| title:` strings and the `## Row …` groupings
are the *intended layout specification*, not decoration. Reuse them verbatim as
`ui.card_header()` text and row groupings.

---

## 2. Decisions taken

Decided by the project owner on 2026-09-21.

| Decision | Choice |
|---|---|
| **Architecture** | **Pure py-shiny `app.py`** (Shiny Core). Not Quarto + `server: shiny`, not Express. `index.qmd` is left in place but unused. |
| **Data layer** | **Keep reading the wide Excel sheets directly.** No converter, no long-format reshape, no `metadata/` subsystem, no adoption of the `AFW360_HH` data standard at this stage. |
| **Scope** | **Curated panels + an "Explore all indicators" tab.** Rebuild today's story interactively, plus one tab exposing the full 97-indicator catalogue. |
| **Deployment** | **Posit Connect is primary.** GitHub Pages keeps a *static* export only, and must not drive design decisions. |

### 2.1 One explicit exception to "wide Excel as-is"

The Explore tab cannot run off the existing `indicator_map_*` dicts — they cover ~20 of
the 97 indicators. And **15 of the 97 are levels, not shares** (FCFA amounts, hectares,
TLU, years, counts, "millions"), which render as nonsense under a blanket `{:.0%}`
(e.g. `9165015%`).

Therefore the app carries **one small dict** marking those indicators and their display
format. This is the same kind of object as the `indicator_map_*` dicts already in
`index.qmd` — not a new data layer, not a metadata subsystem. The exact list of 15 is
in §9.3.

### 2.2 Relationship to the data standard

`.docs/data-standard.qmd` (910 lines) specifies a long-format `AFW360_HH` dataflow with
codelists, `TAB_PLAN.csv` and a `TEXT.csv`. It is a **design document: none of its
files exist in any branch** (verified across every ref including `gh-pages`). Its own
sequencing puts the dashboard switchover last, after metadata → converter → validator.

This port therefore does **not** implement the standard. Two forward-compatibility
notes, cheap to honour now:

- Keep all workbook reading behind a single module (`data.py`) so a later swap to a
  standard-compliant loader is one interface, not a scatter of `pd.read_excel` calls.
- Where the standard names a fix that costs nothing to adopt now, adopt it: per-indicator
  display formatting (its `display_as` / `decimals`), and joining maps on codes rather
  than folded names.

---

## 3. The one structural change that fixes the most

**Country becomes a sidebar filter, not a top-level tab.**

Today `# Senegal` (lines 184–715) and `# Guinea Bissau` (lines 720–1172) are two
near-identical sections. Because `file_path` is assigned only at line 188 and line 370
(both pointing at `Tables_SEN.xlsx`) and is **never reassigned in the Guinea-Bissau
section**, all nine data-driven GNB panels read Senegal's workbook. The Guinea-Bissau
tab currently displays Senegal's numbers, labelled with Senegal's region names.

Making country an input means there is one set of panels, parameterised by
`input.country()`. The duplication disappears and this class of bug becomes impossible
to write. This is item 4 on the TODO list at the top of `index.qmd`.

---

## 4. Target UI

```python
ui.page_navbar(
    title="AFW 360 At A Glance",
    id="page",
    fillable=True,
    theme=<cosmo-based ui.Theme>,
    sidebar=ui.sidebar(                    # global, shared by every page
        ui.input_select("country",   "Country",        {...}),
        ui.input_radio_buttons("povline", "Poverty line", {...}),
        ui.input_select("breakdown", "Breakdown",      {...}),
        ui.input_select("geo_level", "Geography",      {...}),
        ui.input_dark_mode(id="mode"),
        ui.download_button("dl_workbook", "Download summary tables"),
        title="Filters",
    ),
    ui.nav_panel("Overview",  ...),   # KPI row, key messages, international poverty, ADM1 map
    ui.nav_panel("Profile",   ...),   # navset_card_underline: Consumption|Jobs|Agriculture|Energy|Fiscal
    ui.nav_panel("Geography", ...),   # choropleth + ranked bars + ADM1/ZAE table
    ui.nav_panel("Explore",   ...),   # theme -> indicator -> cut, across all 97 indicators
    ui.nav_panel("About",     ...),   # methodology, survey source, downloads
)
```

### 4.1 Sidebar control values

| Input | Choices | Maps to |
|---|---|---|
| `country` | Senegal, Guinea-Bissau | workbook selection (`SEN` / `GNB`) |
| `povline` | `$3.00/day (2021 PPP)`, `$4.20/day (2021 PPP)` | indicator row pair (`Poor at …`, `Number poor …`) |
| `breakdown` | Total; Residence; Head sex; Head age; Quintile | `estimate*` column group, see §5.2 |
| `geo_level` | National; Region (ADM1); Zone (ZAE) | sheet selection |

### 4.2 Requirements the current page does not meet

Each of these is called for by the `shiny-for-python` skill's dashboard-design
reference and is absent today.

- **A KPI row.** Four `ui.value_box()`es reading the selected country and poverty line:
  poverty rate, number poor, employment rate, electricity access. Format every value in
  its renderer; never show a raw float.
- **Real tabs.** `ui.navset_card_underline()` for the Profile group.
- **Every output in a titled card.** `ui.card(ui.card_header(<the original #| title:>),
  ..., full_screen=True)`.
- **Interactive tables.** `@render.data_frame` returning
  `render.DataGrid(df, filters=True)` — sortable and filterable. Do not hand-build HTML
  tables and do not ship pandas `Styler` output.
- **Deliberate empty states.** Render an explicit message inside the card, never a
  spinner or a grid of blanks. Fiscal Equity has no data in either workbook (§9.2) and
  must say so.
- **Card-local controls in card headers** (`ui.toolbar` + `toolbar_input_*`), global
  filters in the sidebar only.

---

## 5. Data layer (`data.py`)

### 5.1 Loading

```python
ROOT = Path(__file__).parent
WORKBOOKS = {                      # module scope: loaded once, shared across sessions
    "SEN": pd.read_excel(ROOT / "INPUT Tables" / "Tables_SEN.xlsx", sheet_name=None),
    "GNB": pd.read_excel(ROOT / "INPUT Tables" / "Tables_GNB.xlsx", sheet_name=None),
}
```

- Both workbooks total 112 KB; loading both at import is free and replaces the current
  **22 separate `pd.read_excel` calls** (`National` alone is read 12 times).
- Resolve paths from `Path(__file__).parent`, never cwd-relative. Connect does use the
  bundle directory as its working directory, but this also survives `shiny run` from
  another directory.
- Then one `@reactive.calc` per derived frame; every output reads those calcs rather
  than repeating the selection logic.

### 5.2 Breakdown groups

Taken from `group_map_Profile` / `col_order_Profile` in `index.qmd` (lines 59–71):

| Breakdown | `estimate*` columns | Display labels |
|---|---|---|
| Total | `estimateTotal` | Total |
| Residence | `estimateCapital`, `estimateOther_Urban`, `estimateRural` | Capital, Other Urban, Rural |
| Head sex | `estimateFemale_HH`, `estimateMale_HH` | Female, Male |
| Head age | `estimateYouth_HH`, `estimateOlder_HH` | Youth, `29+` — **label is suspect, see §10** |
| Quintile | `estimateQ1`…`estimateQ5` | Q1…Q5 |

### 5.3 Rules

- **Drop `.round(1)` entirely.** Today it snaps fractions to the nearest 0.1 *before*
  `{:.0%}` formats them, so 0.45 displays as `40%`. Store unrounded, format at display.
- **Use `.reindex()`, never `.loc[row_order]`.** A drifted label currently raises
  `KeyError` and kills the whole render; `.reindex()` yields a blank row.
- **One `fmt(indicator, value)` helper** driven by the format dict (§9.3): shares →
  `{:.1%}`, FCFA → thousands separator, hectares/TLU/years/counts → fixed decimals,
  "millions" → as stored. This is the fix for the `650%` bug.
- **Empty is not zero.** A blank cell means either "not computed" or "too few
  observations"; the workbooks do not distinguish them. Render as "–" or "no
  observations", never as `0`.
- Match indicator strings exactly, including **en-dash U+2013** in
  `Employed (activ12m, 15–64)` and `Safe drinking water – dry season`, and **U+2265** in
  `≥1 HH member has health coverage …`.

---

## 6. Maps

**Pre-convert offline, once, and commit the result.** `scripts/build_geojson.py` turns
`INPUT shp/sen_admin1.shp` and `INPUT shp/gnb_admin1.shp` into simplified GeoJSON at
`geo/adm1_sen.json` and `geo/adm1_gnb.json`, carrying `adm1_pcode` and a normalised
join key as properties. Render with Plotly through `shinywidgets` (`output_widget` +
`@render_plotly`).

Rationale:

- `sen_admin1.shp` is **2.44 MB / 158,395 vertices for 14 polygons**. Simplified, 14
  ADM1 polygons land well under 100 KB.
- Removes geopandas/GDAL/PROJ from the runtime. That is the single genuinely
  undocumented risk on Posit Connect — Posit states only that system libraries are an
  administrator's responsibility, and nothing in their docs mentions GDAL, GEOS or PROJ.
- **Unblocks `quarto render`**, which currently dies at `index.qmd:365`
  (`import geopandas as gpd`, geopandas not installed).
- Makes the static shinylive build practical.
- Gives Guinea-Bissau a choropleth, which it has never had despite `gnb_admin1.shp`
  being in the repo (GNB currently gets a bar chart instead).

`geopandas` is needed **only** to run `scripts/build_geojson.py` locally, as a dev
dependency. It must not appear in the app's `requirements.txt`.

### 6.1 Two fixes to bake into the conversion

- **`SAB` → `Bissau` alias.** The GNB `ADM 1` sheet calls the capital `estimateSAB`
  (Setor Autónomo de Bissau); the shapefile calls it `Bissau`. Under the existing
  `clean_region_name()` fold these produce `SAB` and `BISSAU` and do not join — 8 of 9
  regions match and **the capital drops out** as a grey polygon annotated `nan%`. SEN
  joins 14/14 and is unaffected.
- **Colour direction per indicator.** Poverty and electricity access must not share a
  palette direction.

### 6.2 Zones stay table-only

**No zone geometry exists for either country.** SEN's `ZAE` sheet has 6 zones,
Guinea-Bissau's has 4, and there is no shapefile for either. Per the data standard this
is by design (`has_geometry = Y` for ADM0 and ADM1 only), not a gap to fill. Zone panels
are charts and tables.

---

## 7. File layout

```
app.py                        # ui + server; assembles the pages
data.py                       # workbook loading, breakdown groups, format dict, fmt()
panels_overview.py            # card builders for Overview
panels_profile.py             # card builders for Profile
panels_geography.py           # card builders for Geography
panels_explore.py             # card builders for Explore
panels_about.py               # card builders for About
requirements.txt              # shiny, shinywidgets, plotly, pandas, openpyxl, faicons
.python-version               # pinned to a Connect-available minor  <- needs §8.2 answer
scripts/build_geojson.py      # dev-only; needs geopandas locally, not at runtime
geo/adm1_sen.json
geo/adm1_gnb.json
tests/test_data.py            # test_server / pure-function tests
INPUT Tables/ INPUT shp/ INPUT Text/ INPUT Figures/    # unchanged
index.qmd                     # left in place, unused by the app
```

Panels live in separate modules per page so that parallel implementation does not
produce concurrent edits to one file.

---

## 8. Deployment

### 8.1 Posit Connect (primary)

Three servers are already registered R-side at
`%APPDATA%\R\config\R\rsconnect\`; `datanalytics-int.worldbank.org` was verified to be
genuine Connect (`/__ping__` → 200, `/__api__/me` → Connect's error shape):

| Nickname | API URL |
|---|---|
| `datanalytics-int.worldbank.org` | `https://datanalytics-int.worldbank.org/__api__` |
| `w0lxdshyprd1c01.worldbank.org` | `https://w0lxdshyprd1c01.worldbank.org/__api__` |
| `w0lxdrconn01.worldbank.org` | `https://w0lxdrconn01.worldbank.org/__api__` |

`rsconnect-python` is **not** installed and has no config — the existing registrations
are R-side only and do not carry over.

```bash
pip install rsconnect-python                       # >= 1.10.0 for `deploy shiny`
rsconnect add --api-key <KEY> --server <URL> --name wb-connect
rsconnect deploy shiny -n wb-connect .             # app.py at bundle root
rsconnect write-manifest shiny .                   # only for git-backed / CI publishing
```

- `app.py` must be at the bundle root. `--entrypoint` is unnecessary when `app.py`
  defines `app`.
- Data files and subdirectories ship with the bundle. `../` paths are forbidden.
- The bundle is effectively read-only at runtime: "deploying a new bundle removes any
  files written to the working directory."
- Connect exposes `session.user` / `session.groups`, so SSO identity can drive access
  control later without building auth.

### 8.2 Three questions for the Connect administrator

All three gate Phase 0 and none can be answered from documentation.

1. **Connect's exact version.** Treat ≥ 2024.01.0 as safe; below it there is a
   documented `starlette >= 0.35.0` incompatibility.
2. **Is `Python.Enabled = true`, and which Python minor versions are installed?**
   Connect's `Python.VersionMatching` defaults to `major-minor` and **fails the
   deployment** when no match exists. The local interpreter is **3.13.7**, very likely
   newer than the server's. Pin `.python-version` to a version Connect actually has, or
   pass `--override-python-version`.
3. **Is the package index PyPI or an internal mirror?** Connect ignores pip
   configuration shipped in the bundle. An sdist-only mirror would also change the
   dependency calculus.

Self-serve check with an API key:

```bash
curl -H "Authorization: Key $KEY" https://<server>/__api__/server_settings/python
```

### 8.3 GitHub Pages (secondary, static)

The published site is **currently a 404**: `origin/gh-pages` contains only `.nojekyll`
and a `CNAME`, because the publishing workflow was deleted in commit `7b542f9` and no
render was ever pushed afterwards. The `CNAME` holds `afw360-glance.github.io`, which
cannot be a custom domain and is inert — delete it.

`shinylive export` produces a fully static build. Two constraints:

- **`openpyxl` is not available in Shinylive** (Pyodide 0.27.7), and every workbook read
  needs it. The static build therefore converts the workbooks to CSV or Parquet at build
  time. (`xlrd` is bundled but reads only legacy `.xls`.)
- `geopandas`, `shapely`, `fiona`, `plotly` and `matplotlib` *are* available in
  Shinylive — but the app will not need them at runtime anyway, per §6.
- The export must be served over HTTP; opening the files from disk does not work.

---

## 9. Evidence: defects in the current page

All verified against the real workbooks. Fix these in the port.

### 9.1 Correctness

| # | Defect | Location |
|---|---|---|
| 1 | **Guinea-Bissau displays Senegal's numbers.** `file_path` never reassigned in the GNB section; all 9 data-driven GNB panels read `Tables_SEN.xlsx`. | assigns at `:188`, `:370`; reads at `:747`, `:804`, `:864`, `:895`, `:932`, `:961`, `:989`, `:1028`, `:1056` |
| 2 | **`.round(1)` destroys precision** before `{:.0%}`. Raw `[0.45, 0.04, 0.38, 0.55]` displays as `['40%','0%','40%','60%']`. Affects Consumption, Jobs and every poverty-rate row. | `:494`, `:522`, `:263`, `:321` + GNB twins |
| 3 | **`{:.0%}` applied to count rows.** "Number poor (millions)" 6.52 displays as `650%`. | `style_table` at `:132`, called 14× |
| 4 | **Fiscal Equity can never show data.** The five rows are unconditionally overwritten with `pd.NA` after the filter, so even a future workbook fix stays invisible. Separately, 0 of its 5 indicator strings exist in either workbook. | `:639`–`:643`, `:1096`–`:1100` |
| 5 | **The About text never renders.** Both "Data and Methodology" chunks emit two `HTML()` objects; Jupyter shows only the last, so the `About_*.txt` box is dropped and only the download button appears. | `:672`–`:715`, `:1129`–`:1172` |
| 6 | **`quarto render` fails outright.** Unconditional `import geopandas as gpd`; geopandas is not installed. | `:365` |
| 7 | **`.loc[row_order_*]` raises `KeyError`** on any label drift, aborting the whole render. | every Profile chunk |
| 8 | **GNB has no choropleth**, only a bar chart, despite `gnb_admin1.shp` existing. Its threshold is also `$3.00` where SEN uses `$4.20`. | `:861`–`:890` |
| 9 | **Dead code.** `download_figure()` / `download_table()` call `st.download_button` — Streamlit, never imported. A commented-out bar chart occupies `:327`–`:356`. `numpy` imported, never used. `matplotlib.pyplot` imported twice. | `:156`–`:179`, `:327`–`:356`, `:43`/`:53` |
| 10 | **~114 KB of base64.** Both workbooks are inlined into the HTML as `data:` URIs. Replace with `@render.download_button`. | `:691`–`:714`, `:1148`–`:1171` |
| 11 | **The GNB tab shows Senegal's figure** — `INPUT Figures/Fiscal Equity SEN.png` is embedded in the Guinea-Bissau section, twice, under two different captions. | `:1115`, `:1122` |

### 9.2 Data contract

```
Tables_SEN.xlsx  sheets: National, Departement, ZAE, ADM 1
  National     97 x 14   indicator + estimateTotal, Capital, Other_Urban, Rural,
                         Female_HH, Male_HH, Youth_HH, Older_HH, Q1..Q5
  ZAE          97 x  7   6 zones (names truncated at 32 chars)
  ADM 1        97 x 15   14 regions, UPPERCASE
  Departement  82 x 15   region-keyed despite the name; 2017 PPP; see below

Tables_GNB.xlsx  sheets: National, ZAE, ADM 1        (no Departement)
  National     97 x 14   identical column set to SEN
  ZAE          97 x  5   4 zones
  ADM 1        97 x 10   9 regions, accented (estimateBafatá, estimateGabú, estimateSAB)
```

The same **97 indicator labels in the same order** appear in all six 97-row sheets. No
merged cells, no spacer rows, `indicator` always column A and 100% non-null. Percentages
are stored as **fractions in [0,1]**, including labels that say "%". Values are rounded
to 2 decimals at source.

- **Fiscal Equity: 0 of 5 indicators exist** in any sheet of either workbook.
- Welfare 7/7, Jobs 6/6, Agriculture 1/1, Energy 3/3 and all four poverty rows are
  present in both workbooks. The Agriculture table's other 4 rows and Energy's 4th row
  are code-only placeholders.
- `Tables_SEN_TEST.xlsx` is a dead scratch file with a different schema.

### 9.3 The 15 level indicators

Everything else in the 97 is a share in [0,1]. These are **not**, and need explicit
display formatting:

```
HE capital stock (FCFA)              HE costs (FCFA)
HE profits (FCFA)                    HE revenue per worker (FCFA)
Monthly electricity spend (FCFA)     HE age (years)
Cultivated area (ha)                 Tropical Livestock Units (TLU)
Average outage duration (code)       Days with an outage (last 7)
Number of employees in HE            Non-HH employees in HE
HH employees in HE
Number poor $3.00/day (millions)     Number poor $4.20/day (millions)
```

`HE profits (FCFA)` **can be negative** (SEN TAMBACOUNDA: −3,460 on `ADM 1`). Do not
apply a non-negative assumption or a zero-floored axis to it.

### 9.4 Geography join

`clean_region_name()` (`:374`) strips `estimate`, folds to ASCII and uppercases.

- **SEN `ADM 1` ↔ `sen_admin1.shp`: 14/14 match**, zero orphans.
- **GNB `ADM 1` ↔ `gnb_admin1.shp`: 8/9** — `estimateSAB` vs `Bissau` (see §6.1).
- **SEN `Departement` ↔ `sen_admin2.shp`: 14/46** — confirms the sheet is region-keyed.

Shapefiles already carry P-codes (`adm1_pcode`: `SN01`…`SN14`, `GW01`…`GW09`). All 22
sets are complete (`.shp/.shx/.dbf/.prj/.cpg`), all EPSG:4326-equivalent, `INPUT shp/`
totals **28.6 MB**, of which only `sen_admin1` is used today. Note two cross-country
schema divergences: the version field is `version` for SEN but `cod_versio` for GNB, and
`lang` is `fr` vs `en`.

---

## 10. Upstream data defects — do NOT fix in the dashboard

These are producer-side problems. The dashboard **shows them with a flag rather than
hiding them**, following the data standard's recorded decision ("Suppression: None.
Every estimate is published, with its sample size and confidence interval attached").
Report them upstream.

1. **GNB `estimateCapital` is a copy of a zone, not Bissau.** It is identical to
   `ZAE estimateZonas_Costeiras_do_Sul` on all 97 indicators and matches `SAB` on only 9
   (all of them constant-everywhere rows). Examples: `Poor at $4.20/day` Capital 0.79 vs
   SAB 0.21; `Access to electricity` 0.01 vs 0.70; `Durable floor materials` 0.33 vs
   0.97. Downstream, GNB's residence breakdown does not add up —
   Capital + Other_Urban + Rural gives 1.24M poor at \$4.20 against a national 1.09M,
   about **14% too high**. Every other GNB breakdown adds up. SEN `Capital` is identical
   to `DAKAR` on all 97 indicators, so this is GNB-specific and looks like a coding error
   in the residence variable.
2. **GNB `Cultivated area (ha)` is corrupt.** Isolated cells in the tens of millions
   where the rest of the row is 1–15 ha: National Total 9.09M, Capital 53.0M, Q4 57.9M;
   `ADM 1` Quinara **148.4M**. SEN's equivalent row is clean (0.66–5.95).
3. **SEN `Departement` sheet.** Region-keyed despite its name, on **2017 PPP** where
   every other sheet is 2021 PPP, 82 rows against 97, 22 unique rows including raw
   variable names (`(max) con_1`…`con_15`, `npoor300`, `npoor420`), and it disagrees with
   `ADM 1` on **54 of 60** shared indicators (`HE profits` by a factor of 14.7). It also
   carries impossible values (`HE has any credit access` = 1.00 in all 14 regions).
   **Leave it unread, as today.**
4. **`HH has internet access`** is 0.00 or empty in every cell of both countries.
   **`wood_dist [ALL MISSING]`** is entirely empty. Neither carries information.
5. **Three overlapping electricity indicators** (`Access to electricity (grid, SDG
   7.1.1)`, `Connected to electricity grid (SDG7.1.1)`, `Uses grid electricity`) span
   0.68 / 0.98 / 0.66 in SEN — a 32-point spread. Their definitions need documenting
   before any one is labelled "electricity access".
6. **Duplicate indicators.** `Food consumption share` is identical to
   `COICOP 1: food & non-alc. beverages (share)`; `Housing & utilities burden` is
   identical to `COICOP 4`. Show one, not both.

---

## 11. Open questions — do not decide these unilaterally

1. **Which poverty line is the headline?** SEN's charts use \$4.20, GNB's use \$3.00.
   Probably unintended. Interim assumption: default both to **\$4.20**, with the line as
   a sidebar filter.
2. **Guinea-Bissau's survey year is unknown.** `About_GNB.txt` contains the literal
   string `TEXT`, so there is nothing truthful to put in a source line for GNB.
3. **`estimateOlder_HH` is labelled `"29+"`** in `col_order_Profile` (`:71`), which
   overlaps "Youth" semantically and appears to be wrong. The underlying head-of-household
   age cutoff is undocumented.
4. **Should Guinea-Bissau ship publicly at all**, given §10.1 and the stub text?
5. **Does an ADM2 / Departement cut exist?** Depends on resolving §10.3.

---

## 12. Build sequence

Each phase has an acceptance test **and ends in a commit**. Do not start a phase before
its predecessor's test passes and its work is committed.

### 12.0 Branch and commit discipline — mandatory

**All implementation happens on a new branch, `dev/app`.** Create it from the current
`dev/eb` before Phase 0 and never commit implementation work to `dev/eb` or `master`:

```bash
git switch -c dev/app
```

**Commit at the end of every phase, and at every point where something works.** A phase
is not complete until its work is committed. Rules:

- One commit per logical unit of work, with a message that says what changed and why.
  Do not bundle six phases into one commit, and do not leave a phase's output uncommitted
  while starting the next.
- **Commit immediately after each phase gate passes** — the commit is part of the
  acceptance criteria, not an afterthought.
- When subagents run in parallel, the orchestrator commits their combined output once the
  wave's gate passes. Subagents do not commit; they write files and report.
- Never commit the virtual environment, `_site/`, `__pycache__/`, or rendered output. Add
  `.venv/` and `__pycache__/` to `.gitignore` in Phase 0 if not already excluded.
- `geo/adm1_sen.json` and `geo/adm1_gnb.json` **are** committed — they are build products
  that the app needs at runtime and that must not require geopandas to regenerate.
- Do not push, open a pull request, or merge into `dev/eb` or `master` without asking
  first. Committing locally on `dev/app` needs no permission; anything that leaves the
  machine or touches another branch does.
- Do not use `--no-verify`, `--amend` on an already-shared commit, or force-push.

### Phase 0 — environment and a Connect smoke test

0. `git switch -c dev/app` (see §12.0). All later work lands here.
1. `uv venv` in the project (do **not** install into the shared `C:\WBG\Python313`).
2. Install `shiny shinywidgets plotly pandas openpyxl faicons` + dev extras
   (`pytest`, `geopandas` for the GeoJSON script only).
3. Write `requirements.txt` (runtime only — no geopandas, no pytest) and
   `.python-version`.
4. **Deploy a five-line `app.py` to Connect before building anything.** This answers in
   minutes what documentation cannot: Python enabled, version matching, and whether the
   corporate proxy passes Shiny's WebSocket traffic. (Diagnostic in a running app:
   Ctrl+Alt+Shift+A opens a transport selector.)

**Accept when:** the stub app is reachable on Connect and serves a live reactive value.

### Phase 1 — data layer

`data.py`: workbook loading, the five breakdown groups, the format dict (§9.3),
`fmt()`, and the indicator catalogue read from the `indicator` column.
`scripts/build_geojson.py` + `geo/*.json` can proceed in parallel.

**Accept when:** `pytest` shows the Welfare `Total` column formatting as
`['45%','4%','38%','55%','30%','25%','45%']` (not `['40%','0%',…]`), "Number poor"
formatting as `6.52` (not `650%`), GNB reading GNB's workbook, and the GNB ADM1 join
matching 9/9.

### Phase 2 — Overview page

KPI value boxes, key messages, both international poverty tables, the ADM1 choropleth.

**Accept when:** switching country and poverty line updates every output on the page,
and Guinea-Bissau shows Guinea-Bissau's numbers and its own map.

### Phase 3 — Profile and Geography pages

Profile: five real tabs (Consumption, Jobs, Agriculture, Energy, Fiscal) reusing the
original `#| title:` strings. Fiscal renders its empty state. Geography: choropleth,
ranked horizontal bars, ADM1/ZAE table.

**Accept when:** all five tabs switch, the breakdown selector re-columns every table,
and Fiscal shows its message rather than blanks.

### Phase 4 — Explore tab

Theme → indicator → cut, across all 97 indicators, with level indicators formatted
correctly and known-bad indicators (§10) flagged in the UI.

**Accept when:** an FCFA indicator and a count indicator both render with correct units,
and `Cultivated area (ha)` for GNB Quinara is visibly flagged rather than silently shown.

### Phase 5 — About, downloads, theming

`About` page fed from `INPUT Text/`. `@render.download_button` for the workbook,
replacing the base64 blocks. `ui.Theme` derived from cosmo. Note `Messages_SEN.txt` is
Quarto chunk source, not HTML — use its prose, not the file.

### Phase 6 — tests, QA, static export, cleanup

- `test_server` tests for the reactive chain; pure-function tests for `fmt()`.
- Browser QA pass: every page at desktop and narrow width, every filter, an empty
  result, full-screen cards, console clean, labels and units checked.
- `shinylive export` for GitHub Pages, with workbooks pre-converted to CSV/Parquet.
- Delete the inert `CNAME`, `map_test.png`, `dsf.qqqww`, `Tables_SEN_TEST.xlsx`,
  `INPUT Text/Messages_SEN.txt2`.

---

## 13. Repository notes

- **Implementation branch is `dev/app`**, cut from `dev/eb`. See §12.0. `dev/eb` keeps
  the docs and the legacy `index.qmd`; `master` is the default branch and is not touched.
- **Local `dev/eb` is 7 commits behind `origin/dev/eb`.** Pull before starting.
- **`git pull` will refuse:** the local `CLAUDE.md` is untracked and differs from the one
  committed at `e3281df`. Resolve deliberately (move the local copy aside, pull, then
  reconcile) rather than discarding either version.
- `.gitignore` excludes `_site/`, `*.html`, `*_files/`, `.quarto/`. `_site/` is never
  committed on the working branch.
- Both `.docs/data-standard.qmd` and `.docs/input-tables-findings.qmd` live on
  `origin/dev/eb` only. On Windows, Git Bash mangles `rev:path` arguments — export
  `MSYS_NO_PATHCONV=1` and single-quote them.
