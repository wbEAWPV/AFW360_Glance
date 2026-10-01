"""Overview page for AFW 360 At A Glance.

Reading order, per the panel contract section A: KPI row, key messages, the two
international poverty tables, the ADM1 choropleth.

Three things in here exist to fix a verified defect in the Quarto page:

* Every displayed number goes through `data.fmt()` / `data.fmt_table()`. The old
  page pushed `{:.0%}` over the count rows, so "Number poor (millions)" 6.52
  printed as `650%` (plan section 9.1 #3).
* Country is a filter, not a copy-pasted section. The old Guinea-Bissau panels
  read `Tables_SEN.xlsx` because `file_path` was never reassigned (section 9.1
  #1), so GNB showed Senegal's numbers.
* Known-bad data is flagged in the card, not hidden: the three overlapping
  electricity definitions (`data.DATA_FLAGS`) and Guinea-Bissau's `Capital`
  column, which is a copy of a zone rather than Bissau
  (`data.CAPITAL_FLAG_TEXT`) and inflates the residence split shown in both
  poverty tables by about 14%.
"""

from __future__ import annotations

import json
from pathlib import Path

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from faicons import icon_svg
from shiny import reactive, render, ui
from shinywidgets import output_widget, render_plotly

import data

PREFIX = "ov"

# --------------------------------------------------------------------------
# Indicators this page reads by name
# --------------------------------------------------------------------------

# The en dash (U+2013) in the age range is the workbook's own; an ASCII hyphen
# silently misses the row and the KPI would read as missing.
EMPLOYMENT_INDICATOR = "Employed (activ12m, 15–64)"
ELECTRICITY_INDICATOR = "Access to electricity (grid, SDG 7.1.1)"

# Rows of the two international poverty tables, in display order.
_RATE_ROW = "Poverty rate"
_COUNT_ROW = "Number poor (millions)"

# Header strings are the original `#| title:` values from index.qmd, verbatim.
TABLE_CARDS: dict[str, str] = {
    "300": "International Poverty Rate - $3.00/day PPP 2021",
    "420": "Lower Middle Income Poverty Rate - $4.20/day PPP 2021",
}

# --------------------------------------------------------------------------
# Key messages
# --------------------------------------------------------------------------

# Card headers, verbatim from index.qmd:193, :198, :203 (the `<b>` is theirs).
MESSAGE_HEADERS: tuple[str, str, str] = (
    "<b>Poverty Patterns and Trends</b>",
    "<b>Drivers of Inequality</b>",
    "<b>Constraints to Inclusive Growth</b>",
)

# Senegal's prose, verbatim from index.qmd:195, :200, :205. The `##` are the
# author's own placeholders for numbers that were never filled in -- they are
# left exactly as written rather than guessed at.
MESSAGES_SEN: tuple[str, str, str] = (
    "In 2026, stronger economic activity and easing inflation are expected to "
    "reduce poverty to ## percent, leaving over ## million people below the "
    "$4.20/day (2021 PPP) line. Growth has been driven in part by hydrocarbons, "
    "but employment gains remain limited, as mining and extractives employ few "
    "workers. By contrast, favorable rainfall and sustained agricultural growth "
    "are expected to raise incomes among poorer households.",
    "Persistent spatial disparities between Dakar and other regions and unequal "
    "access to services, economic opportunities, and overlapping deficits in "
    "income and human development shape inequality (Gini: ##). Poverty rates "
    "are higher in rural areas (## percent), where most poor households rely on "
    "agriculture, while in urban areas (## percent), poverty is concentrated in "
    "low-productivity informal services. Despite lower poverty rates, the large "
    "populations in Thiès and Diourbel imply that a substantial share of the "
    "poor resides in urban areas.",
    "Inclusive growth remains constrained by low human capital, infrastructure "
    "gaps, and limited access to productive jobs, keeping many households in "
    "low-productivity agriculture and informal activities. Spatial disparities "
    "and weak market integration further limit participation in growth, "
    "particularly in rural and lagging areas. External pressures—including "
    "climate shocks, regional instability, and youth outmigration—amplify these "
    "constraints and undermine resilience.",
)

# Guinea-Bissau has no key messages at all: index.qmd:727, :732 and :737 each
# hold the literal string "TEXT", and INPUT Text/Messages_GNB.txt holds only the
# three section headings ("1. Poverty", "2. Inequality", "3. Policy"). Senegal's
# prose is Senegal's and is never shown here; the card says so instead.
MESSAGES_MISSING = (
    "Key messages for {country} are not yet drafted.",
    "The source text holds only section headings and the placeholder string "
    "“TEXT”, so there is nothing to report here yet.",
)

# --------------------------------------------------------------------------
# Geometry -- loaded once at import, not once per render (both files are <45 KB)
# --------------------------------------------------------------------------

_GEO_DIR = Path(__file__).parent / "geo"


def _load_geojson() -> dict[str, dict]:
    out: dict[str, dict] = {}
    for iso3 in data.COUNTRIES:
        path = _GEO_DIR / f"adm1_{iso3.lower()}.json"
        if path.exists():
            out[iso3] = json.loads(path.read_text(encoding="utf-8"))
    return out


GEOJSON: dict[str, dict] = _load_geojson()

# join_key -> the shapefile's own spelling. `data.region_table()` keeps the
# workbook's casing, which renders Guinea-Bissau's capital as "SAB" and
# Senegal's regions in block capitals; the GeoJSON carries "Bissau" and
# "Saint-Louis", so hover labels come from here.
GEO_REGION_NAMES: dict[str, dict[str, str]] = {
    iso3: {
        f["properties"]["join_key"]: f["properties"].get(
            "region", f["properties"]["join_key"]
        )
        for f in gj["features"]
    }
    for iso3, gj in GEOJSON.items()
}

# One sequential ramp, dark = worse. Poverty is the only thing mapped on this
# page, so nothing else may borrow this direction (electricity access is a
# "more is better" measure and is a KPI here, not a map).
POVERTY_SCALE = "OrRd"


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------


def _poverty_frame(iso3: str, line_key: str) -> pd.DataFrame:
    """Rate and count for one poverty line, by Total + residence.

    `data.BREAKDOWNS["residence"]` is Capital/Other Urban/Rural only, so Total
    is fetched separately and joined on -- the original table showed all four.
    """
    line = data.POVERTY_LINES[line_key]
    rows = {line.rate_indicator: _RATE_ROW, line.count_indicator: _COUNT_ROW}
    total = data.table(iso3, rows, "total")
    residence = data.table(iso3, rows, "residence")
    out = pd.concat([total, residence], axis=1)
    out.index.name = "Indicator"
    # concat does not promise to carry attrs; fmt_table needs them to tell the
    # share row from the count row.
    out.attrs["source_indicators"] = total.attrs["source_indicators"]
    return out


def _is_blank(frame: pd.DataFrame) -> bool:
    """True when every cell of an already-formatted frame is the empty mark."""
    return bool(frame.size) and bool((frame == data.EMPTY_DISPLAY).to_numpy().all())


def _empty_figure(message: str, dark: bool) -> go.Figure:
    """An annotation-only figure -- never a blank canvas, never fake geometry."""
    fig = go.Figure()
    fig.add_annotation(
        text=message,
        showarrow=False,
        xref="paper",
        yref="paper",
        x=0.5,
        y=0.5,
        font={"size": 14},
    )
    fig.update_xaxes(visible=False)
    fig.update_yaxes(visible=False)
    fig.update_layout(
        template="plotly_dark" if dark else "plotly_white",
        margin={"l": 0, "r": 0, "t": 0, "b": 0},
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
    )
    return fig


def _kpi_box(
    output_id: str,
    title: "str | ui.Tag | ui.TagList",
    icon: str,
) -> ui.Tag:
    """One value box: a name, a formatted value, and a line of context."""
    return ui.value_box(
        title,
        ui.output_text(output_id),
        ui.output_ui(f"{output_id}_note"),
        showcase=icon_svg(icon),
        fill=False,
    )


def _message_card(index: int) -> ui.Tag:
    return ui.card(
        ui.card_header(ui.HTML(MESSAGE_HEADERS[index])),
        ui.output_ui(f"ov_message_{index + 1}"),
        full_screen=True,
        min_height="180px",
    )


def _table_card(line_key: str) -> ui.Tag:
    return ui.card(
        ui.card_header(TABLE_CARDS[line_key]),
        ui.output_ui(f"ov_note_{line_key}"),
        ui.output_data_frame(f"ov_table_{line_key}"),
        full_screen=True,
        min_height="260px",
    )


# --------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------


def panel():
    """The Overview nav panel. Called once, at UI construction."""
    electricity_title = ui.tags.span(
        "Electricity access",
        " ",
        ui.tooltip(
            icon_svg(
                "circle-info",
                title="How electricity access is defined",
                a11y="sem",
            ),
            data.DATA_FLAGS[ELECTRICITY_INDICATOR],
            placement="top",
        ),
    )

    return ui.nav_panel(
        "Overview",
        ui.div(
            ui.output_ui("ov_scope"),
            ui.layout_column_wrap(
                _kpi_box("ov_kpi_rate", "Poverty rate", "chart-line"),
                _kpi_box("ov_kpi_count", "Number poor (millions)", "people-group"),
                _kpi_box("ov_kpi_employment", "Employment rate", "briefcase"),
                _kpi_box("ov_kpi_electricity", electricity_title, "bolt"),
                width="240px",
                fill=False,
            ),
            ui.layout_columns(
                _message_card(0),
                _message_card(1),
                _message_card(2),
                col_widths={"sm": (12,), "lg": (4, 4, 4)},
            ),
            ui.layout_columns(
                _table_card("300"),
                _table_card("420"),
                col_widths={"sm": (12,), "lg": (6, 6)},
            ),
            ui.card(
                ui.card_header(ui.output_text("ov_map_header", inline=True)),
                output_widget("ov_map"),
                ui.card_footer(ui.output_ui("ov_map_note")),
                full_screen=True,
                min_height="460px",
            ),
            # The page is taller than one viewport. Scrolling here keeps it
            # readable whether or not app.py marks this panel `fillable`.
            class_="d-flex flex-column gap-3 overflow-auto",
        ),
    )


# --------------------------------------------------------------------------
# Server
# --------------------------------------------------------------------------


def server(input, output, session, shared) -> None:
    """Register the Overview outputs. Called once from app.py's server()."""

    # ---- one shared derivation, read by every renderer on the page ----------

    @reactive.calc
    def scope() -> tuple[str, str, data.PovertyLine]:
        return shared.iso3(), shared.country_label(), shared.povline()

    @reactive.calc
    def kpi_values() -> dict[str, tuple[str, float | None]]:
        """indicator label -> (formatted value, raw value) for the four KPIs."""
        iso3, _, line = scope()
        wanted = {
            "rate": line.rate_indicator,
            "count": line.count_indicator,
            "employment": EMPLOYMENT_INDICATOR,
            "electricity": ELECTRICITY_INDICATOR,
        }
        out = {}
        for key, indicator in wanted.items():
            raw = data.value(iso3, indicator)
            out[key] = (data.fmt(indicator, raw), raw)
        return out

    def _kpi_note(text: str) -> ui.Tag:
        return ui.tags.span(text, class_="small")

    def _missing_suffix(key: str) -> str:
        return "" if kpi_values()[key][1] is not None else " — not reported"

    # ---- scope line --------------------------------------------------------

    @render.ui
    def ov_scope():
        _, country, line = scope()
        return ui.tags.p(
            ui.tags.strong(country),
            f" · poverty line {line.label} · household survey estimates, "
            "shares of population unless stated",
            class_="text-muted small mb-0",
        )

    # ---- KPI row -----------------------------------------------------------

    @render.text
    def ov_kpi_rate():
        return kpi_values()["rate"][0]

    @render.ui
    def ov_kpi_rate_note():
        _, country, line = scope()
        return _kpi_note(f"{country}, {line.label}{_missing_suffix('rate')}")

    @render.text
    def ov_kpi_count():
        return kpi_values()["count"][0]

    @render.ui
    def ov_kpi_count_note():
        _, country, line = scope()
        return _kpi_note(
            f"{country}, millions below {line.label}{_missing_suffix('count')}"
        )

    @render.text
    def ov_kpi_employment():
        return kpi_values()["employment"][0]

    @render.ui
    def ov_kpi_employment_note():
        _, country, _line = scope()
        # Deliberately not labelled with the poverty line: employment does not
        # vary with it, and saying otherwise would misattribute the measure.
        return _kpi_note(
            f"{country}, {EMPLOYMENT_INDICATOR}{_missing_suffix('employment')}"
        )

    @render.text
    def ov_kpi_electricity():
        return kpi_values()["electricity"][0]

    @render.ui
    def ov_kpi_electricity_note():
        _, country, _line = scope()
        return _kpi_note(
            f"{country}, {ELECTRICITY_INDICATOR}{_missing_suffix('electricity')}"
        )

    # ---- key messages ------------------------------------------------------

    def _message(index: int):
        iso3, country, _line = scope()
        if iso3 == "SEN":
            # The `##` are the author's unfilled placeholders. Guinea-Bissau's
            # missing text is explained on screen, so Senegal's gaps need the
            # same courtesy -- otherwise they read as broken copy rather than
            # as numbers still to come.
            body = ui.tags.p(MESSAGES_SEN[index], class_="mb-0")
            if "##" in MESSAGES_SEN[index]:
                return ui.TagList(
                    body,
                    ui.tags.p(
                        "“##” marks a figure the authors have not filled in yet.",
                        class_="text-muted small mb-0 mt-2",
                    ),
                )
            return body
        return ui.TagList(
            ui.tags.p(
                ui.tags.em(MESSAGES_MISSING[0].format(country=country)),
                class_="mb-1",
            ),
            ui.tags.p(MESSAGES_MISSING[1], class_="text-muted small mb-0"),
        )

    @render.ui
    def ov_message_1():
        return _message(0)

    @render.ui
    def ov_message_2():
        return _message(1)

    @render.ui
    def ov_message_3():
        return _message(2)

    # ---- international poverty tables --------------------------------------

    @reactive.calc
    def poverty_tables() -> dict[str, pd.DataFrame]:
        iso3 = shared.iso3()
        return {
            key: data.fmt_table(_poverty_frame(iso3, key)) for key in TABLE_CARDS
        }

    def _table_grid(line_key: str) -> render.DataGrid:
        frame = poverty_tables()[line_key].reset_index()
        return render.DataGrid(frame, filters=True, width="100%")

    def _table_note(line_key: str):
        iso3, country, _line = scope()
        parts: list = []
        if _is_blank(poverty_tables()[line_key]):
            parts.append(
                ui.tags.div(
                    f"No {data.POVERTY_LINES[line_key].label} estimates are "
                    f"published for {country} in this workbook.",
                    class_="alert alert-secondary py-2 px-3 small mb-2",
                )
            )
        if iso3 == data.CAPITAL_FLAG_ISO3:
            parts.append(
                ui.tags.div(
                    ui.tags.strong("Capital column is not Bissau. "),
                    data.CAPITAL_FLAG_TEXT,
                    class_="alert alert-warning py-2 px-3 small mb-2",
                    role="note",
                )
            )
        parts.append(
            ui.tags.p(
                "Poverty rate is a share of the population; Number poor is in "
                "millions of people.",
                class_="text-muted small mb-2",
            )
        )
        return ui.TagList(*parts)

    @render.data_frame
    def ov_table_300():
        return _table_grid("300")

    @render.ui
    def ov_note_300():
        return _table_note("300")

    @render.data_frame
    def ov_table_420():
        return _table_grid("420")

    @render.ui
    def ov_note_420():
        return _table_note("420")

    # ---- ADM1 choropleth ---------------------------------------------------

    @reactive.calc
    def map_frame() -> pd.DataFrame:
        iso3, _, line = scope()
        frame = data.region_table(iso3, line.rate_indicator)
        names = GEO_REGION_NAMES.get(iso3, {})
        frame["region"] = [
            names.get(key, fallback)
            for key, fallback in zip(frame["join_key"], frame["region"])
        ]
        return frame.dropna(subset=["value"])

    @render.text
    def ov_map_header():
        # Original title string with the sidebar's line substituted in.
        return f"Poverty by Region - {scope()[2].label}"

    @render.ui
    def ov_map_note():
        iso3, country, line = scope()
        shown = len(map_frame())
        total = len(GEO_REGION_NAMES.get(iso3, {}))
        missing = total - shown
        text = (
            f"Share of the population below {line.label}, by region. "
            f"{shown} of {total} regions have an estimate."
        )
        if missing > 0:
            text += (
                f" {missing} region(s) are left unshaded because the workbook "
                "has no value for them."
            )
        return ui.tags.span(text, class_="text-muted small")

    @render_plotly
    def ov_map():
        iso3, country, line = scope()
        dark = bool(shared.dark())
        if iso3 not in GEOJSON:
            return _empty_figure(
                f"No region geometry is available for {country}.", dark
            )
        frame = map_frame()
        if frame.empty:
            return _empty_figure(
                f"No regional estimates of {line.rate_indicator} for {country}.",
                dark,
            )

        fig = px.choropleth(
            frame,
            geojson=GEOJSON[iso3],
            locations="join_key",
            featureidkey="properties.join_key",
            color="value",
            hover_name="region",
            color_continuous_scale=POVERTY_SCALE,
            range_color=(0, 1),
            labels={"value": "Poverty rate"},
        )
        # Geometry only: no basemap tiles, so nothing is fetched over the
        # network (a corporate proxy or the static export would break on that).
        fig.update_geos(fitbounds="locations", visible=False)
        fig.update_traces(
            marker_line_color="rgba(255,255,255,0.7)",
            marker_line_width=0.6,
            hovertemplate=(
                "<b>%{hovertext}</b><br>"
                f"Poor at {line.label}: " + "%{z:.0%}<extra></extra>"
            ),
        )
        fig.update_layout(
            template="plotly_dark" if dark else "plotly_white",
            margin={"l": 0, "r": 0, "t": 0, "b": 0},
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            coloraxis_colorbar={
                "title": {"text": "Share"},
                "tickformat": ".0%",
                "thickness": 12,
            },
        )
        fig.update_geos(bgcolor="rgba(0,0,0,0)")
        return fig
