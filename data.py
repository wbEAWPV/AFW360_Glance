"""Data layer for the AFW 360 At A Glance Shiny app.

This is the **only** module that reads a workbook. Every panel gets its numbers
from here, so that a later swap to a harmonised (long-format) data source is a
change to one file rather than a hunt through thirty chunks -- see
`.docs/shiny-port-plan.md` section 2.2.

Three rules inherited from the plan, each fixing a verified defect in the old
Quarto page:

* No rounding on the way in. `index.qmd` called `.round(1)` before formatting
  with `{:.0%}`, so 0.45 displayed as `40%` (plan section 9.1 #2). Values are
  stored exactly as the workbook holds them and formatted only at display time
  by `fmt()`.
* Row selection is `.reindex()`, never `.loc[row_order]`. A drifted indicator
  label must produce a blank row, not the `KeyError` that killed the whole
  render (plan section 9.1 #7).
* Empty is not zero. A blank cell means "not computed" or "too few
  observations" and the workbooks do not distinguish the two, so missing values
  render as `EMPTY_DISPLAY`, never as `0` (plan section 5.3).

Indicator labels are matched exactly, including the en dash U+2013 in
`Employed (activ12m, 15-64)` / `Safe drinking water - dry season` and U+2265 in
`>=1 HH member has health coverage ...`. Wherever possible the labels are read
from the `indicator` column rather than typed here.
"""

from __future__ import annotations

import math
import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

ROOT = Path(__file__).parent  # never cwd-relative: Connect and `shiny run` differ

EMPTY_DISPLAY = "–"  # en dash -- shown for every missing / non-numeric cell

COUNTRIES: dict[str, str] = {  # insertion order = sidebar order
    "SEN": "Senegal",
    "GNB": "Guinea-Bissau",
}

# UI key -> workbook sheet name. "Departement" is deliberately absent: it is
# region-keyed despite its name, sits on 2017 PPP and disagrees with `ADM 1` on
# 54 of 60 shared indicators (plan section 10.3). Leave it unread.
GEO_LEVELS: dict[str, str] = {
    "national": "National",
    "adm1": "ADM 1",
    "zae": "ZAE",
}

_WORKBOOK_FILES: dict[str, Path] = {
    "SEN": ROOT / "INPUT Tables" / "Tables_SEN.xlsx",
    "GNB": ROOT / "INPUT Tables" / "Tables_GNB.xlsx",
}

# Both workbooks together are 112 KB, so loading them at import is free and
# replaces the 22 separate `pd.read_excel` calls the old page made (`National`
# alone was read 12 times) -- plan section 5.1.
WORKBOOKS: dict[str, dict[str, pd.DataFrame]] = {
    iso3: pd.read_excel(path, sheet_name=None, engine="openpyxl")
    for iso3, path in _WORKBOOK_FILES.items()
}


@dataclass(frozen=True)
class PovertyLine:
    """One poverty line and the two indicator rows that report it."""

    label: str
    rate_indicator: str
    count_indicator: str


# "420" first: it is the default for both countries under the interim
# assumption in plan section 11.1 (SEN's charts used $4.20, GNB's used $3.00,
# apparently unintentionally).
POVERTY_LINES: dict[str, PovertyLine] = {
    "420": PovertyLine(
        label="$4.20/day (2021 PPP)",
        rate_indicator="Poor at $4.20/day (2021 PPP)",
        count_indicator="Number poor $4.20/day (millions)",
    ),
    "300": PovertyLine(
        label="$3.00/day (2021 PPP)",
        rate_indicator="Poor at $3.00/day (2021 PPP)",
        count_indicator="Number poor $3.00/day (millions)",
    ),
}


@dataclass(frozen=True)
class Breakdown:
    """A group of `estimate*` columns shown side by side."""

    label: str
    columns: dict[str, str] = field(default_factory=dict)  # excel column -> display


# The "29+" label for `estimateOlder_HH` comes from `col_order_Profile` in
# index.qmd:71. It overlaps "Youth" semantically and is almost certainly wrong,
# but the head-of-household age cutoff is undocumented (plan section 11.3), so
# it is kept verbatim and defined once, here, ready for a one-line change.
BREAKDOWNS: dict[str, Breakdown] = {
    "total": Breakdown("Total", {"estimateTotal": "Total"}),
    "residence": Breakdown(
        "Residence",
        {
            "estimateCapital": "Capital",
            "estimateOther_Urban": "Other Urban",
            "estimateRural": "Rural",
        },
    ),
    "sex": Breakdown(
        "Head sex",
        {"estimateFemale_HH": "Female", "estimateMale_HH": "Male"},
    ),
    "age": Breakdown(
        "Head age",
        {"estimateYouth_HH": "Youth", "estimateOlder_HH": "29+"},
    ),
    "quintile": Breakdown(
        "Quintile",
        {f"estimateQ{i}": f"Q{i}" for i in range(1, 6)},
    ),
}

# The 15 indicators that are levels, not shares. Everything else in the 97 is a
# fraction in [0,1] -- these are FCFA amounts, hectares, TLU, years, counts and
# "millions", which a blanket `{:.0%}` turns into nonsense such as `9165015%`
# (plan sections 2.1 and 9.3). The value is the unit, which is also the key into
# `_FORMAT_SPECS`.
LEVEL_FORMATS: dict[str, str] = {
    "HE capital stock (FCFA)": "FCFA",
    "HE costs (FCFA)": "FCFA",
    "HE profits (FCFA)": "FCFA",
    "HE revenue per worker (FCFA)": "FCFA",
    "Monthly electricity spend (FCFA)": "FCFA",
    "HE age (years)": "years",
    "Cultivated area (ha)": "ha",
    "Tropical Livestock Units (TLU)": "TLU",
    "Average outage duration (code)": "code",
    "Days with an outage (last 7)": "count",
    "Number of employees in HE": "count",
    "Non-HH employees in HE": "count",
    "HH employees in HE": "count",
    "Number poor $3.00/day (millions)": "millions",
    "Number poor $4.20/day (millions)": "millions",
}

# unit -> format spec. The share spec is `.0%` and not `.1%`: the workbooks are
# rounded to 2 decimals at source (plan section 9.2), so a tenth of a percentage
# point is precision the data does not have. `,.0f` on FCFA keeps the minus sign
# -- `HE profits (FCFA)` is genuinely negative in SEN TAMBACOUNDA (-3,460).
_FORMAT_SPECS: dict[str, str] = {
    "share": ".0%",
    "FCFA": ",.0f",
    "years": ",.1f",
    "ha": ",.1f",
    "TLU": ",.1f",
    "code": ",.0f",
    "count": ",.1f",
    "millions": ",.2f",
}

# Producer-side defects (plan section 10). The dashboard shows them with a flag
# rather than hiding or "fixing" them, following the data standard's recorded
# decision that every estimate is published with its caveats attached.
DATA_FLAGS: dict[str, str] = {
    "Cultivated area (ha)": (
        "Guinea-Bissau only: corrupt. Isolated cells in the tens of millions of "
        "hectares (National total 9.09M, Quinara 148.4M) where the rest of the "
        "row is 1-15 ha. Senegal's values are clean."
    ),
    "HH has internet access": (
        "0.00 or empty in every cell of both countries; carries no information."
    ),
    "wood_dist [ALL MISSING]": "Entirely empty in both countries.",
    "Access to electricity (grid, SDG 7.1.1)": (
        "One of three overlapping electricity definitions (with 'Connected to "
        "electricity grid' and 'Uses grid electricity') spanning a 32-point "
        "spread in Senegal. The definitions are undocumented."
    ),
    "Connected to electricity grid (SDG7.1.1)": (
        "One of three overlapping electricity definitions (with 'Access to "
        "electricity (grid, SDG 7.1.1)' and 'Uses grid electricity') spanning a "
        "32-point spread in Senegal. The definitions are undocumented."
    ),
    "Uses grid electricity": (
        "One of three overlapping electricity definitions (with 'Access to "
        "electricity (grid, SDG 7.1.1)' and 'Connected to electricity grid') "
        "spanning a 32-point spread in Senegal. The definitions are undocumented."
    ),
    "Food consumption share": (
        "Exact duplicate of 'COICOP 1: food & non-alc. beverages (share)'. Show "
        "one, not both."
    ),
    "COICOP 1: food & non-alc. beverages (share)": (
        "Exact duplicate of 'Food consumption share'. Show one, not both."
    ),
    "Housing & utilities burden (COICOP 4 share of total cons.)": (
        "Exact duplicate of 'COICOP 4: housing & utilities (share)'. Show one, "
        "not both."
    ),
    "COICOP 4: housing & utilities (share)": (
        "Exact duplicate of 'Housing & utilities burden (COICOP 4 share of "
        "total cons.)'. Show one, not both."
    ),
}

# A breakdown-level flag, not an indicator-level one (plan section 10.1): GNB's
# `estimateCapital` is a copy of the Zonas Costeiras do Sul zone rather than
# Bissau, so the residence split does not add up.
CAPITAL_FLAG_ISO3 = "GNB"
CAPITAL_FLAG_TEXT = (
    "Guinea-Bissau's 'Capital' column is a copy of a zone, not Bissau: it is "
    "identical to the Zonas Costeiras do Sul zone on all 97 indicators. The "
    "residence breakdown therefore does not add up -- it gives about 14% more "
    "poor than the national total. Reported upstream; shown unaltered."
)

# Coarse themes for the Explore tab: a navigation aid, not a taxonomy. Ordered
# substring rules, first match wins -- so Enterprise ("HE ") is tested before
# Jobs, and Jobs before Agriculture, to keep "Employed in agriculture" out of
# the agriculture bucket and "HH owns a non-agric enterprise" out of both.
_THEME_RULES: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("Poverty", ("Poor at $", "Number poor $")),
    (
        "Consumption",
        ("COICOP", "consumption share", "food share", "utilities burden"),
    ),
    ("Shocks", ("shock", "Shock")),
    ("Enterprise", ("HE ", " HE", "non-agric enterprise")),
    (
        "Jobs",
        ("Employed", "employed", "Wage-employed", "Share of HH workers"),
    ),
    (
        "Agriculture",
        ("agricultural land", "Cultivated area", "livestock", "Livestock Units"),
    ),
    (
        "Energy",
        (
            "electricity",
            "outage",
            "cooking fuel",
            "lighting",
            "Prepaid meter",
            "cooker",
            "ceiling fan",
            "wall AC",
            "water heater",
        ),
    ),
    (
        "Housing & services",
        (
            "Durable ",
            "drinking water",
            "toilet",
            "internet",
            "health insurance",
            "health coverage",
        ),
    ),
)


# --------------------------------------------------------------------------
# Sheet access
# --------------------------------------------------------------------------

_SHEET_CACHE: dict[tuple[str, str], pd.DataFrame] = {}


def sheet(iso3: str, level: str) -> pd.DataFrame:
    """One wide sheet, indexed by `indicator`.

    `level` is a `GEO_LEVELS` key ("national" / "adm1" / "zae"), not a raw sheet
    name. The indexed frame is cached; a copy is returned so callers cannot
    mutate the shared object.
    """
    key = (iso3.upper(), level)
    if key not in _SHEET_CACHE:
        _SHEET_CACHE[key] = (
            WORKBOOKS[key[0]][GEO_LEVELS[level]].set_index("indicator")
        )
    return _SHEET_CACHE[key].copy()


def indicators(iso3: str = "SEN") -> list[str]:
    """The 97 indicator labels, in workbook order, read from the sheet itself."""
    return list(sheet(iso3, "national").index)


def value(
    iso3: str,
    indicator: str,
    column: str = "estimateTotal",
    level: str = "national",
) -> float | None:
    """A single cell, or None when the row, the column or the value is missing.

    None rather than 0 or NaN: a blank cell is "not computed" or "too few
    observations", and callers must be able to tell that apart from a real zero.
    """
    df = sheet(iso3, level)
    if indicator not in df.index or column not in df.columns:
        return None
    v = df.at[indicator, column]
    if pd.isna(v):
        return None
    return float(v)


def table(
    iso3: str,
    indicators: list[str] | dict[str, str],
    breakdown: str,
    level: str = "national",
) -> pd.DataFrame:
    """Rows = indicators, columns = the breakdown's display labels.

    `indicators` as a list keeps the workbook labels; as a dict it maps workbook
    label -> display label and fixes row order. Rows and columns are selected
    with `.reindex()`, so an absent or renamed label yields a blank row instead
    of raising. Values are raw: no rounding, no formatting -- `fmt_table()` does
    that.

    The index is named "Indicator" and carries the display labels; the original
    workbook labels survive in `df.attrs["source_indicators"]` as
    {display label: workbook label} so `fmt_table()` can pick the right format.
    """
    source_to_display = (
        dict(indicators)
        if isinstance(indicators, dict)
        else {name: name for name in indicators}
    )
    columns = BREAKDOWNS[breakdown].columns

    out = (
        sheet(iso3, level)
        .reindex(index=list(source_to_display), columns=list(columns))
        .rename(index=source_to_display, columns=dict(columns))
    )
    out.index.name = "Indicator"
    out.attrs["source_indicators"] = {
        display: source for source, display in source_to_display.items()
    }
    return out


# --------------------------------------------------------------------------
# Display formatting
# --------------------------------------------------------------------------


def fmt(indicator: str, v) -> str:
    """Format one value for display, keyed on the workbook indicator label.

    Missing, non-numeric and non-finite input returns `EMPTY_DISPLAY` -- never
    "0", never "nan". A level indicator uses its unit's spec from
    `LEVEL_FORMATS`; everything else is a share stored as a fraction. This is
    the fix for the old page's `650%` bug, where `{:.0%}` was applied to a count.

    Never raises, whatever it is handed.
    """
    try:
        if v is None or isinstance(v, str) or pd.isna(v):
            return EMPTY_DISPLAY
        x = float(v)
    except (TypeError, ValueError):
        return EMPTY_DISPLAY
    if not math.isfinite(x):
        return EMPTY_DISPLAY
    spec = _FORMAT_SPECS[LEVEL_FORMATS.get(indicator, "share")]
    try:
        return format(x, spec)
    except (TypeError, ValueError, OverflowError):
        return EMPTY_DISPLAY


def fmt_table(df: pd.DataFrame) -> pd.DataFrame:
    """Apply `fmt()` cell by cell, each row formatted by its own indicator.

    Returns a frame of strings ready for `render.DataGrid`.
    """
    source = df.attrs.get("source_indicators", {})
    # Positional, not label-based: a caller may legitimately hand us a frame
    # whose display labels repeat, and `.at[label, col]` would then return a
    # Series rather than a cell.
    rows = [
        [fmt(source.get(label, label), v) for v in values]
        for label, values in zip(df.index, df.to_numpy(dtype=object))
    ]
    out = pd.DataFrame(rows, index=df.index, columns=df.columns, dtype=object)
    out.attrs["source_indicators"] = source
    return out


# --------------------------------------------------------------------------
# Geography
# --------------------------------------------------------------------------


def normalise_region(name: str) -> str:
    """Fold a region name to the join key shared by the workbook and the GeoJSON.

    Strips a leading "estimate", decomposes accents and drops the combining
    marks (ASCII fold), replaces every run of non-alphanumeric characters with a
    single underscore, trims leading/trailing underscores and uppercases. So
    "estimateBolama_Bijagos" (with the accent), "Bolama/Bijagos" and
    "Bolama Bijagos" all become "BOLAMA_BIJAGOS", and "estimateSAINT_LOUIS"
    matches the shapefile's "Saint-Louis" as "SAINT_LOUIS".

    `scripts/build_geojson.py` imports this rather than reimplementing it: the
    two sides of the join must fold identically or regions silently drop out of
    the map as grey polygons (plan section 9.4). Guinea-Bissau's capital is the
    one case folding cannot reconcile -- the workbook calls it `estimateSAB`
    and the shapefile calls it "Bissau" -- so the GeoJSON build aliases
    "Bissau" to "SAB" before calling this (plan section 6.1).
    """
    s = str(name).removeprefix("estimate")
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").upper()


def _display_region(column: str) -> str:
    """Human-readable label for an `estimate<REGION>` column.

    Casing is left exactly as the workbook has it -- SEN's ADM1 columns are
    uppercase, GNB's are accented title case -- because inventing a casing would
    mean inventing names. Map hover labels should prefer the GeoJSON's `region`
    property, which carries the shapefile's own spelling.
    """
    return str(column).removeprefix("estimate").replace("_", " ")


def _long(iso3: str, indicator: str, level: str) -> pd.DataFrame:
    """One indicator across every column of a sheet, one row per column."""
    df = sheet(iso3, level)
    row = df.reindex([indicator]).iloc[0]  # reindex: a missing label gives NaNs
    return pd.DataFrame(
        {
            "region": [_display_region(c) for c in df.columns],
            "value": [row[c] for c in df.columns],
        }
    )


def region_table(iso3: str, indicator: str) -> pd.DataFrame:
    """ADM1 values for the map and the ranked bars.

    Columns: `join_key` (matching the GeoJSON property of the same name),
    `region` (human-readable), `value` (raw numeric, may be NaN). One row per
    ADM1 column in the sheet -- 14 for Senegal, 9 for Guinea-Bissau.
    """
    out = _long(iso3, indicator, "adm1")
    out.insert(0, "join_key", [normalise_region(r) for r in out["region"]])
    return out


def zone_table(iso3: str, indicator: str) -> pd.DataFrame:
    """ZAE values -- same shape as `region_table` minus `join_key`.

    Zone names are truncated at 32 characters in the workbook and are presented
    as they come. There is no zone geometry for either country (plan section
    6.2), so zones are charts and tables only and need no join key.
    """
    return _long(iso3, indicator, "zae")


# --------------------------------------------------------------------------
# Catalogue, text and downloads
# --------------------------------------------------------------------------


def theme_of(indicator: str) -> str:
    """The coarse Explore-tab bucket an indicator falls in."""
    for theme, needles in _THEME_RULES:
        if any(needle in indicator for needle in needles):
            return theme
    return "Other"


def catalogue(iso3: str = "SEN") -> pd.DataFrame:
    """The Explore tab's backing frame: one row per indicator.

    Columns: `indicator` (the workbook label), `theme`, `unit` ("share" or the
    level unit) and `flag` (the `DATA_FLAGS` text, or "").
    """
    labels = indicators(iso3)
    return pd.DataFrame(
        {
            "indicator": labels,
            "theme": [theme_of(i) for i in labels],
            "unit": [LEVEL_FORMATS.get(i, "share") for i in labels],
            "flag": [DATA_FLAGS.get(i, "") for i in labels],
        }
    )


def about_text(iso3: str) -> str:
    """Contents of `INPUT Text/About_<ISO3>.txt`, or "" if absent or blank.

    GNB's file holds the literal string "TEXT" (plan section 11.2). It is
    returned as-is; the caller decides what to do about it. Do not invent
    replacement prose.
    """
    path = ROOT / "INPUT Text" / f"About_{iso3.upper()}.txt"
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8").strip()


def workbook_bytes(iso3: str) -> bytes:
    """Raw .xlsx bytes, for the download handler.

    Read from disk on demand rather than inlined as base64, which is what made
    the old page carry ~114 KB of data URIs (plan section 9.1 #10).
    """
    return _WORKBOOK_FILES[iso3.upper()].read_bytes()
