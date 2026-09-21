"""Geography page for AFW 360 At A Glance.

Three cards over one indicator, chosen in the map card's own toolbar:

1. an ADM1 choropleth (`px.choropleth` over the pre-built `geo/adm1_<iso>.json`),
2. ranked horizontal bars over the same values, and
3. the values behind them as a grid.

Card 1 is the only one that needs geometry. **There is no agro-ecological zone
geometry for either country and none is coming** -- per the data standard,
boundaries are published for ADM0 and ADM1 only (plan section 6.2). So when the
sidebar's geography filter is on zones the map card says so in words and the
bars and the grid carry the view; at national level there is a single value,
which can be neither mapped nor ranked, and all three cards say that instead of
drawing an empty axis.

Two deliberate departures from the old Quarto page, both from the plan:

* Guinea-Bissau gets a choropleth. It never had one -- `gnb_admin1.shp` sat
  unused in the repo and GNB got a bar chart at a different poverty line than
  Senegal's. The capital joins correctly here because `scripts/build_geojson.py`
  aliased the shapefile's "Bissau" to the workbook's `estimateSAB` (plan 6.1).
* Colour direction follows the indicator's meaning rather than one fixed ramp:
  more poverty is bad, more electricity access is good, and the two must not
  share a palette direction. See `direction()`.

`px.choropleth` (the geo-based renderer) rather than `px.choropleth_map`: the
latter draws through MapLibre and fetches basemap tiles over the network, which
the corporate proxy may block and which a static export cannot do at all.
`fitbounds="locations"` plus `visible=False` draws the polygons alone, with no
tile dependency -- which is all an admin choropleth needs.
"""

from __future__ import annotations

import json

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from faicons import icon_svg
from shiny import reactive, render, ui
from shinywidgets import output_widget, render_plotly

import data

PREFIX = "ge"

# --------------------------------------------------------------------------
# Module-scope data: loaded once per process, never per render
# --------------------------------------------------------------------------

# ~76 KB of simplified ADM1 polygons for both countries. Read here, not in a
# renderer: every session and every re-render would otherwise re-parse them.
_GEOJSON: dict[str, dict] = {
    iso3: json.loads(
        (data.ROOT / "geo" / f"adm1_{iso3.lower()}.json").read_text(encoding="utf-8")
    )
    for iso3 in data.COUNTRIES
}

# join key -> the shapefile's own spelling of the region. Preferred over the
# workbook's column name for every label the user sees: `region_table()` keeps
# the workbook casing, which renders Guinea-Bissau's capital as "SAB" and
# Senegal's regions in block capitals.
_REGION_LABELS: dict[str, dict[str, str]] = {
    iso3: {f["properties"]["join_key"]: f["properties"]["region"] for f in gj["features"]}
    for iso3, gj in _GEOJSON.items()
}

_DEFAULT_INDICATOR = data.POVERTY_LINES["420"].rate_indicator
_POVERTY_RATE_INDICATORS = {p.rate_indicator for p in data.POVERTY_LINES.values()}


def _indicator_choices() -> dict[str, dict[str, str]]:
    """All 97 indicators as `<optgroup>`s, grouped by `data.theme_of`.

    Both workbooks carry the identical 97 labels (verified), so the choices are
    static and the selector needs no country-driven update.
    """
    groups: dict[str, dict[str, str]] = {}
    for label in data.indicators():
        groups.setdefault(data.theme_of(label), {})[label] = label
    # Poverty first -- it is the page's default subject; the rest alphabetically.
    ordered = ["Poverty"] + sorted(k for k in groups if k != "Poverty")
    return {k: groups[k] for k in ordered if k in groups}


_INDICATOR_CHOICES = _indicator_choices()

# --------------------------------------------------------------------------
# Colour direction
# --------------------------------------------------------------------------

# Direction is decided from the indicator *label*, never from the numbers: a
# ramp that flipped because this country happened to score high would be a lie
# about the measure. Ordered substring rules, first match wins, deprivations
# tested before achievements so "Informal electricity connection" cannot be read
# as electricity access.
#
#   "worse"   a higher value is a worse outcome (poverty, shocks, outages,
#             informality, biomass cooking, a cost burden) -> warm red ramp.
#   "better"  a higher value is a better outcome (access, ownership, durable
#             housing, coverage, wage employment, enterprise capability)
#             -> cool teal ramp. Teal, not green: red/green is the one pairing
#             a deuteranope cannot separate, and these two ramps are the pair
#             the page switches between.
#   "neutral" a magnitude with no welfare direction (hectares, TLU, an outage
#             *code*, consumption composition, employment composition) -> a
#             violet ramp that reads as neither good nor bad.
#
# Anything unmatched is "neutral". Inventing a direction for a label that does
# not state one would be a claim the data does not support.
_WORSE_NEEDLES: tuple[str, ...] = (
    "Poor at $",
    "Number poor $",
    "shock",
    "Shock",
    "outage",
    "Informal electricity connection",
    "informally employed",
    "cooking fuel biomass",
    "burden",
)
_BETTER_NEEDLES: tuple[str, ...] = (
    "Access to electricity",
    "Connected to electricity grid",
    "Uses grid electricity",
    "Improved lighting",
    "cooking fuel clean",
    "Durable ",
    "drinking water",
    "Sanitary toilet",
    "health insurance",
    "health coverage",
    "internet access",
    "Employed (activ12m",
    "Wage-employed (%",
    "HE has ",
    "HE keeps accounts",
    "HE profits",
    "HE revenue per worker",
    "Owns ",
    "owns ",
    "cooker",
)

_SCALES: dict[str, str] = {"worse": "Reds", "better": "Teal", "neutral": "Purples"}
_ACCENTS: dict[str, str] = {
    "worse": "#b03a2e",
    "better": "#11726f",
    "neutral": "#6a51a3",
}
_DIRECTION_NOTE: dict[str, str] = {
    "worse": "Darker and longer means a higher value, which is a worse outcome.",
    "better": "Darker and longer means a higher value, which is a better outcome.",
    "neutral": (
        "Darker and longer means a higher value. This indicator has no "
        "better-or-worse direction, so the colour carries none."
    ),
}


def direction(indicator: str) -> str:
    """`"worse"` / `"better"` / `"neutral"` for one workbook indicator label."""
    if any(needle in indicator for needle in _WORSE_NEEDLES):
        return "worse"
    if any(needle in indicator for needle in _BETTER_NEEDLES):
        return "better"
    return "neutral"


# --------------------------------------------------------------------------
# Units and titles
# --------------------------------------------------------------------------

# Axis / colourbar tick formats, keyed by the same units as `data.LEVEL_FORMATS`.
# The specs are d3-format, which is what Plotly's `tickformat` takes, and they
# match `data._FORMAT_SPECS` so a tick and a cell never disagree.
_TICKFORMATS: dict[str, str] = {
    "share": ".0%",
    "FCFA": ",.0f",
    "years": ",.1f",
    "ha": ",.1f",
    "TLU": ",.1f",
    "code": ",.0f",
    "count": ",.1f",
    "millions": ",.2f",
}
_UNIT_LABELS: dict[str, str] = {
    "share": "Share",
    "FCFA": "FCFA",
    "years": "Years",
    "ha": "Hectares",
    "TLU": "TLU",
    "code": "Code",
    "count": "Count",
    "millions": "Millions",
}

_LEVEL_NOUN: dict[str, str] = {
    "adm1": "Region",
    "zae": "Agro-Ecological Zone",
    "national": "National",
}


def _unit(indicator: str) -> str:
    return data.LEVEL_FORMATS.get(indicator, "share")


def place_values(iso3: str, indicator: str, level: str) -> pd.DataFrame:
    """Label + raw value + formatted value, one row per place.

    Columns: `label` (what the user sees), `value` (raw, may be NaN), `display`
    (through `data.fmt`), and for ADM1 also `join_key`, which is what the
    GeoJSON joins on. Every card on this page reads this one frame.

    Module level rather than a closure inside `server()` so that a test can
    build exactly what the renderers draw without going through a session.
    """
    if level == "adm1":
        df = data.region_table(iso3, indicator)
        labels = _REGION_LABELS[iso3]
        # The GeoJSON spelling, not the workbook's: "Bissau", not "SAB".
        df["label"] = [
            labels.get(key, region) for key, region in zip(df["join_key"], df["region"])
        ]
    elif level == "zae":
        df = data.zone_table(iso3, indicator)
        # Zone names are truncated at 32 characters in the workbook. Shown as
        # stored -- guessing at the full name would be inventing data.
        df["label"] = df["region"]
    else:
        df = pd.DataFrame(
            {
                "region": ["National total"],
                "label": ["National total"],
                "value": [data.value(iso3, indicator)],
            }
        )
    df["display"] = [data.fmt(indicator, v) for v in df["value"]]
    return df


def card_title(indicator: str, level: str, povline: data.PovertyLine) -> str:
    """The card header for one indicator at one geography level.

    When the indicator is the poverty rate for the line selected in the sidebar
    this reproduces the original `#| title:` strings from `index.qmd` verbatim
    -- `Poverty by Region - $4.20/day (2021 PPP)` and
    `Poverty by Agro-Ecological Zone ($4.20/day (2021 PPP))` -- because those
    strings are the intended layout spec. Any other indicator names itself.
    """
    if indicator == povline.rate_indicator:
        if level == "zae":
            return f"Poverty by Agro-Ecological Zone ({povline.label})"
        if level == "adm1":
            return f"Poverty by Region - {povline.label}"
        return f"Poverty - {povline.label}, national total"
    if level == "zae":
        return f"{indicator} by Agro-Ecological Zone"
    if level == "adm1":
        return f"{indicator} by Region"
    return f"{indicator} - national total"


# --------------------------------------------------------------------------
# Figures -- plain functions, so a test can build and inspect them directly
# --------------------------------------------------------------------------


def _layout(fig: go.Figure, dark: bool) -> go.Figure:
    """The house Plotly layout: card-transparent background, no wasted margin."""
    fig.update_layout(
        template="plotly_dark" if dark else "plotly_white",
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        margin=dict(l=8, r=8, t=8, b=8),
    )
    return fig


def message_figure(text: str, dark: bool = False) -> go.Figure:
    """An annotation-only figure: the designed empty state for a widget slot.

    Never a blank canvas and never invented geometry -- the sentence says why
    there is nothing to draw.
    """
    fig = go.Figure()
    fig.add_annotation(
        text=text,
        showarrow=False,
        xref="paper",
        yref="paper",
        x=0.5,
        y=0.5,
        font=dict(size=14, color="#9aa0a6" if dark else "#5f6368"),
    )
    fig.update_xaxes(visible=False)
    fig.update_yaxes(visible=False)
    return _layout(fig, dark)


def choropleth_figure(
    iso3: str,
    indicator: str,
    frame: pd.DataFrame,
    dark: bool = False,
) -> go.Figure:
    """ADM1 choropleth for one indicator.

    `frame` is `data.region_table()` plus the `label` and `display` columns added
    by the page (see `_frame()`). Regions whose value is missing are dropped from
    the trace rather than drawn as zero; the card footer counts them.
    """
    plot = frame.dropna(subset=["value"])
    if plot.empty:
        return message_figure("No values for this indicator", dark)

    unit = _unit(indicator)
    fig = px.choropleth(
        plot,
        geojson=_GEOJSON[iso3],
        locations="join_key",
        featureidkey="properties.join_key",
        color="value",
        hover_name="label",
        custom_data=["display"],
        color_continuous_scale=_SCALES[direction(indicator)],
        labels={"value": _UNIT_LABELS[unit]},
    )
    fig.update_traces(
        marker_line_color="#ffffff" if not dark else "#2b2b2b",
        marker_line_width=0.6,
        hovertemplate=f"<b>%{{hovertext}}</b><br>{indicator}: %{{customdata[0]}}"
        "<extra></extra>",
    )
    # No basemap, no graticule, no network: just the polygons, zoomed to them.
    fig.update_geos(fitbounds="locations", visible=False, bgcolor="rgba(0,0,0,0)")
    fig.update_coloraxes(
        colorbar_title_text=_UNIT_LABELS[unit],
        colorbar_tickformat=_TICKFORMATS[unit],
        colorbar_thickness=12,
        colorbar_len=0.85,
    )
    _layout(fig, dark)
    fig.update_layout(margin=dict(l=0, r=0, t=0, b=0))
    return fig


def ranked_bar_figure(
    indicator: str,
    frame: pd.DataFrame,
    level: str,
    dark: bool = False,
) -> go.Figure:
    """Sorted horizontal bars over the same values as the map.

    Usually the clearer read of the two for comparing named places, so it is a
    first-class view rather than a decoration: every label is shown in full
    (`automargin`), the value is printed at the end of its bar, and the axis is
    never floored at zero -- `HE profits (FCFA)` is genuinely negative in
    Tambacounda.
    """
    plot = frame.dropna(subset=["value"]).sort_values("value")
    if plot.empty:
        return message_figure("No values for this indicator", dark)

    unit = _unit(indicator)
    fig = px.bar(
        plot,
        x="value",
        y="label",
        orientation="h",
        text="display",
        color_discrete_sequence=[_ACCENTS[direction(indicator)]],
    )
    fig.update_traces(
        textposition="outside",
        cliponaxis=False,
        hovertemplate=f"<b>%{{y}}</b><br>{indicator}: %{{text}}<extra></extra>",
    )
    fig.update_yaxes(
        title_text=None,
        categoryorder="total ascending",  # largest at the top
        automargin=True,  # never truncate a region or zone name
        ticksuffix="  ",
    )
    fig.update_xaxes(
        title_text=_UNIT_LABELS[unit],
        tickformat=_TICKFORMATS[unit],
        showgrid=True,
        zeroline=True,
    )
    _layout(fig, dark)
    fig.update_layout(showlegend=False, margin=dict(l=8, r=48, t=8, b=8))
    fig.update_layout(
        uniformtext=dict(minsize=9, mode="hide"),
        bargap=0.25 if level == "adm1" else 0.4,
    )
    return fig


# --------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------


def panel():
    """The Geography nav panel. Called once, at UI construction."""
    return ui.nav_panel(
        "Geography",
        ui.output_ui("ge_flag"),
        ui.layout_columns(
            ui.card(
                ui.card_header(
                    ui.output_ui("ge_map_title", inline=True),
                    ui.toolbar(
                        ui.toolbar_input_select(
                            "ge_indicator",
                            "Indicator mapped",
                            choices=_INDICATOR_CHOICES,
                            selected=_DEFAULT_INDICATOR,
                            icon=icon_svg("layer-group"),
                        ),
                        align="right",
                    ),
                ),
                ui.output_ui("ge_map_note"),
                output_widget("ge_map"),
                ui.card_footer(ui.output_ui("ge_map_footer")),
                full_screen=True,
                min_height="440px",
            ),
            ui.card(
                ui.card_header(ui.output_ui("ge_bars_title", inline=True)),
                output_widget("ge_bars"),
                full_screen=True,
                min_height="440px",
            ),
            col_widths={"sm": (12, 12), "lg": (6, 6)},
        ),
        ui.card(
            ui.card_header(ui.output_ui("ge_table_title", inline=True)),
            ui.output_data_frame("ge_table"),
            ui.card_footer(ui.output_ui("ge_table_footer")),
            full_screen=True,
        ),
    )


def _muted(*children) -> ui.Tag:
    return ui.div(*children, class_="text-muted small")


# --------------------------------------------------------------------------
# Server
# --------------------------------------------------------------------------


def server(input, output, session, shared) -> None:
    """Register the Geography page's outputs."""

    # ---- one pipeline, read by all three cards ---------------------------

    @reactive.calc
    def indicator() -> str:
        """The indicator chosen in the map card's toolbar."""
        return input.ge_indicator()

    @reactive.effect
    def _follow_poverty_line():
        """Re-point a mapped poverty rate at the sidebar's line.

        Only while a poverty rate is the thing being mapped: switching the
        sidebar line must not silently throw away a user's choice of, say,
        electricity access.
        """
        line = shared.povline()
        with reactive.isolate():
            current = input.ge_indicator()
        if current in _POVERTY_RATE_INDICATORS and current != line.rate_indicator:
            ui.update_toolbar_input_select(
                "ge_indicator", selected=line.rate_indicator
            )

    @reactive.calc
    def frame() -> pd.DataFrame:
        """The one frame every card on this page reads."""
        return place_values(shared.iso3(), indicator(), shared.geo_level())

    @reactive.calc
    def missing_count() -> int:
        return int(frame()["value"].isna().sum())

    # ---- flag ------------------------------------------------------------

    @render.ui
    def ge_flag():
        """Known-bad data, named and shown -- never quietly drawn as a value."""
        ind = indicator()
        text = data.DATA_FLAGS.get(ind)
        if not text:
            return None
        return ui.div(
            icon_svg("triangle-exclamation", title="Data quality warning", a11y="sem"),
            ui.tags.b(f" Data quality warning — {ind}. "),
            text,
            class_="alert alert-warning py-2 mb-3",
            role="alert",
        )

    # ---- map card --------------------------------------------------------

    @render.ui
    def ge_map_title():
        return card_title(indicator(), shared.geo_level(), shared.povline())

    @render.ui
    def ge_map_note():
        """Why there is no map, when there is no map."""
        level = shared.geo_level()
        country = shared.country_label()
        if level == "zae":
            n = len(frame())
            return _muted(
                f"No map at this level. There is no agro-ecological zone geometry "
                f"for {country} and none is planned: the data standard publishes "
                f"boundaries for the country and its regions only. The ranked bars "
                f"and the table show all {n} zones."
            )
        if level == "national":
            return _muted(
                f"No map at this level. 'National' is a single value for {country}. "
                "Switch the geography filter to Region for the map, or to "
                "Agro-Ecological Zone for the zone comparison."
            )
        return None

    @render_plotly
    def ge_map():
        level = shared.geo_level()
        dark = shared.dark()
        if level == "zae":
            return message_figure("No zone geometry — see the note above", dark)
        if level == "national":
            return message_figure("Nothing to map at national level", dark)
        return choropleth_figure(shared.iso3(), indicator(), frame(), dark)

    @render.ui
    def ge_map_footer():
        ind = indicator()
        level = shared.geo_level()
        parts: list[str] = []
        if level in ("adm1", "zae"):
            parts.append(_DIRECTION_NOTE[direction(ind)])
        if level == "adm1":
            missing = missing_count()
            total = len(frame())
            if missing:
                parts.append(
                    f"{missing} of {total} regions have no value for this "
                    "indicator and are left uncoloured."
                )
            if shared.iso3() == "GNB":
                parts.append(
                    "The workbook labels the capital 'SAB' (Setor Autónomo de "
                    "Bissau); it is shown here under the boundary file's name, "
                    "Bissau."
                )
        if ind in data.DATA_FLAGS:
            parts.append("This indicator carries a data quality warning, shown above.")
        if not parts:
            return None
        return _muted(" ".join(parts))

    # ---- ranked bars card ------------------------------------------------

    @render.ui
    def ge_bars_title():
        title = card_title(indicator(), shared.geo_level(), shared.povline())
        if shared.geo_level() == "adm1":
            return f"{title}, ranked"
        return title

    @render_plotly
    def ge_bars():
        level = shared.geo_level()
        dark = shared.dark()
        if level == "national":
            return message_figure(
                "A single national value cannot be ranked", dark
            )
        return ranked_bar_figure(indicator(), frame(), level, dark)

    # ---- values table ----------------------------------------------------

    @render.ui
    def ge_table_title():
        return f"{card_title(indicator(), shared.geo_level(), shared.povline())} — values"

    @render.data_frame
    def ge_table():
        level = shared.geo_level()
        df = frame().sort_values("value", ascending=False, na_position="last")
        # Numbers, not formatted strings, with the unit in the header. Every row
        # here is the same indicator, so the unit factors out of the cells - and a
        # string column would sort lexically when the user clicks the header,
        # putting "9%" above "71%". data.numeric_for_display() rounds to exactly
        # the precision data.fmt() shows, so the two cannot disagree.
        ind = indicator()
        out = pd.DataFrame(
            {
                _LEVEL_NOUN[level]: list(df["label"]),
                f"Value ({data.unit_label(ind)})": [
                    data.numeric_for_display(ind, v) for v in df["value"]
                ],
            }
        )
        return render.DataGrid(out, filters=True)

    @render.ui
    def ge_table_footer():
        ind = indicator()
        level = shared.geo_level()
        parts: list[str] = []
        if level == "national":
            parts.append(
                "Only the national total exists at this level. Switch the "
                "geography filter to Region or Agro-Ecological Zone to compare "
                "places."
            )
        else:
            parts.append("Sorted from the highest value down.")
        if missing_count() == len(frame()):
            parts.append(
                f"No values are recorded for '{ind}' at this level in this "
                "workbook; the rows are shown so the places are not hidden."
            )
        if level == "zae":
            parts.append(
                "Zone names are truncated at 32 characters in the workbook and "
                "are shown exactly as stored."
            )
        if level == "adm1" and shared.iso3() == "GNB":
            parts.append(
                "The capital is stored as 'SAB' in the workbook and shown here "
                "as Bissau."
            )
        return _muted(" ".join(parts))
