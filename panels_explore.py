"""Explore page for AFW 360 At A Glance (Wave 2 Shiny port).

The curated pages cover roughly 20 of the 97 indicators. This one exposes all of
them: theme -> indicator -> the cut chosen in the sidebar, shown as a table and a
chart of the same values, over a searchable catalogue of the whole set.

Two things this page exists to get right.

* **Units.** 15 of the 97 indicators are levels, not shares -- FCFA amounts,
  hectares, TLU, years, counts, "millions" (plan section 9.3). Every number shown
  here is formatted by `data.fmt()`, which keys the format on the workbook
  indicator label. Nothing is formatted locally; there is no `{:.0%}` in this
  file. That is the fix for the old page's `650%`, a count run through a percent
  format.
* **Flags.** Several indicators are known to be broken upstream (plan section
  10). The recorded decision is to publish them with their caveats attached
  rather than hide or silently "correct" them, so a flagged indicator is shown in
  full, with its flag text in a card of its own and its cells marked.

Ids are prefixed `ex_` per the panel contract. Global filters are read through
`shared`, never from `input` directly.
"""

from __future__ import annotations

import textwrap

import pandas as pd
import plotly.graph_objects as go
from shiny import reactive, render, req, ui
from shinywidgets import output_widget, render_plotly

import data

PREFIX = "ex"

# One accent plus neutrals (skill: dashboard-design). The amber is reserved for
# values the data note says are not trustworthy -- it is meaning, not decoration.
# The theme primary (app.py's ui.Theme). Was an unrelated blue, which read as
# a second accent system next to the navbar and buttons.
ACCENT = "#1F4E78"
FLAG_ACCENT = "#c77700"
FLAG_CELL_STYLE = {
    "background-color": "#fff3cd",
    "color": "#663c00",
    "font-weight": "600",
}

WARN = "⚠"  # U+26A0 WARNING SIGN, appended to every flagged cell

# Coarse themes come from `data.theme_of()`; this is only their reading order.
# Anything the data layer adds later falls in at the end rather than disappearing.
_THEME_ORDER: tuple[str, ...] = (
    "Poverty",
    "Consumption",
    "Jobs",
    "Enterprise",
    "Agriculture",
    "Energy",
    "Housing & services",
    "Shocks",
    "Other",
)

# `data.LEVEL_FORMATS` unit -> what to call it in a column header and on an axis.
# The formats themselves stay in data.py; these are only labels.
_UNIT_COLUMN: dict[str, str] = {
    "share": "%",
    "FCFA": "FCFA",
    "years": "years",
    "ha": "ha",
    "TLU": "TLU",
    "code": "code",
    "count": "count",
    "millions": "millions",
}
_UNIT_AXIS: dict[str, str] = {
    "share": "share of the group",
    "FCFA": "FCFA",
    "years": "years",
    "ha": "hectares",
    "TLU": "tropical livestock units",
    "code": "code (see questionnaire)",
    "count": "count",
    "millions": "millions of people",
}

# What the rows of the values table are, per `shared.geo_level()`.
_CUT_LABELS: dict[str, str] = {"national": "Group", "adm1": "Region", "zae": "Zone"}

# Which `data.DATA_FLAGS` entries make the *numbers* untrustworthy, and where.
# The remaining flags -- the three overlapping electricity definitions and the two
# duplicate pairs -- are definition caveats: those values are fine, so they get
# the flag text but no cell marking. That split is a display decision, which is
# why it lives here and not in data.py. `None` means "in both countries".
_SUSPECT_VALUES: dict[str, tuple[str, ...] | None] = {
    "Cultivated area (ha)": ("GNB",),  # plan section 10.2
    "HH has internet access": None,  # plan section 10.4
    "wood_dist [ALL MISSING]": None,  # plan section 10.4
}


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------


def _themes(cat: pd.DataFrame) -> list[str]:
    """Themes present in the catalogue, in reading order."""
    present = list(dict.fromkeys(cat["theme"]))
    ordered = [t for t in _THEME_ORDER if t in present]
    return ordered + [t for t in present if t not in ordered]


def _indicator_choices(cat: pd.DataFrame, theme: str) -> list[str]:
    """Workbook labels for one theme, in workbook order."""
    return list(cat.loc[cat["theme"] == theme, "indicator"])


def _unit_of(indicator: str) -> str:
    return data.LEVEL_FORMATS.get(indicator, "share")


def _values_suspect(indicator: str, iso3: str) -> bool:
    """True when the data note says these numbers cannot be trusted here."""
    if indicator not in _SUSPECT_VALUES:
        return False
    countries = _SUSPECT_VALUES[indicator]
    return countries is None or iso3.upper() in countries


def _alert(title: str, body: str, kind: str = "warning") -> ui.Tag:
    """A Bootstrap alert. Flags are visible text in the card, never hover-only."""
    return ui.div(
        ui.tags.strong(title),
        ui.br(),
        body,
        class_=f"alert alert-{kind} mb-2",
        role="alert",
    )


def _message_figure(message: str, template: str) -> go.Figure:
    """An annotation-only figure: the designed state for "nothing to plot"."""
    fig = go.Figure()
    fig.add_annotation(
        text="<br>".join(textwrap.wrap(message, 58)),
        showarrow=False,
        x=0.5,
        y=0.5,
        xref="paper",
        yref="paper",
        align="center",
        font={"size": 14},
    )
    fig.update_layout(
        template=template,
        # Transparent, so the chart takes the card's colour instead of
        # plotly_dark's #111 showing as a black block inside a grey card.
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        xaxis={"visible": False},
        yaxis={"visible": False},
        margin={"l": 20, "r": 20, "t": 20, "b": 20},
    )
    return fig


# --------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------


def panel():
    """The Explore nav panel. Built once, before any country is known."""
    # Both workbooks carry the same 97 labels in the same order (plan section
    # 9.2), so the initial choices can be built from either; the server
    # repopulates them from `shared.iso3()` on every flush anyway.
    cat = data.catalogue()
    themes = _themes(cat)
    first_theme = themes[0]
    first_choices = _indicator_choices(cat, first_theme)
    # Land on the headline poverty rate rather than on whatever the workbook
    # happens to list first inside the theme.
    landing = data.POVERTY_LINES["420"].rate_indicator
    if landing not in first_choices:
        landing = first_choices[0] if first_choices else None

    return ui.nav_panel(
        "Explore",
        ui.layout_columns(
            ui.card(
                ui.card_header("Choose an indicator"),
                ui.input_select(
                    "ex_theme", "Theme", choices=themes, selected=first_theme
                ),
                ui.input_select(
                    "ex_indicator",
                    "Indicator",
                    choices=first_choices,
                    selected=landing,
                ),
                ui.output_ui("ex_context"),
            ),
            ui.card(
                ui.card_header("Data notes for this indicator"),
                ui.output_ui("ex_flags"),
            ),
            col_widths={"sm": (12,), "lg": (5, 7)},
        ),
        ui.layout_columns(
            ui.card(
                ui.card_header(ui.output_ui("ex_values_title")),
                ui.output_ui("ex_values_note"),
                ui.output_data_frame("ex_values"),
                full_screen=True,
                min_height="360px",
            ),
            ui.card(
                ui.card_header(ui.output_ui("ex_chart_title")),
                output_widget("ex_chart"),
                full_screen=True,
                min_height="360px",
            ),
            col_widths={"sm": (12,), "lg": (5, 7)},
        ),
        ui.card(
            ui.card_header(
                "All 97 indicators",
                ui.tags.small(
                    " — filter or sort to find one, then click its row to "
                    "load it above.",
                    class_="text-muted",
                ),
            ),
            ui.output_data_frame("ex_catalogue"),
            full_screen=True,
            min_height="320px",
        ),
    )


# --------------------------------------------------------------------------
# Server
# --------------------------------------------------------------------------


def server(input, output, session, shared) -> None:
    # Set by the catalogue grid so the theme -> indicator cascade can honour a
    # jump to an indicator in another theme, which needs two client round trips.
    pending = reactive.value(None)

    @reactive.calc
    def catalogue() -> pd.DataFrame:
        return data.catalogue(shared.iso3())

    @reactive.calc
    def indicator() -> str:
        return str(input.ex_indicator() or "")

    @reactive.calc
    def unit() -> str:
        return _unit_of(indicator())

    @reactive.calc
    def suspect() -> bool:
        return _values_suspect(indicator(), shared.iso3())

    @reactive.calc
    def cut_label() -> str:
        return _CUT_LABELS.get(shared.geo_level(), "Group")

    @reactive.calc
    def values() -> pd.DataFrame:
        """The current cut as `category` / `value`, raw and unrounded.

        At ADM 1 and ZAE the sheet is keyed by place, not by breakdown group, so
        the sidebar breakdown has nothing to select there -- `ex_context` says so
        rather than leaving the control looking broken.
        """
        ind, iso, level = indicator(), shared.iso3(), shared.geo_level()
        if not ind:
            return pd.DataFrame({"category": [], "value": []})
        if level == "adm1":
            out = data.region_table(iso, ind)[["region", "value"]]
            return out.rename(columns={"region": "category"})
        if level == "zae":
            return data.zone_table(iso, ind).rename(columns={"region": "category"})
        wide = data.table(iso, [ind], shared.breakdown(), "national")
        row = wide.iloc[0]
        return pd.DataFrame(
            {"category": list(wide.columns), "value": [row[c] for c in wide.columns]}
        )

    @reactive.calc
    def finite() -> pd.DataFrame:
        v = values()
        if v.empty:
            return v
        return v[pd.to_numeric(v["value"], errors="coerce").notna()]

    @reactive.calc
    def display_frame() -> pd.DataFrame:
        """The values table: two columns of strings, every cell via `data.fmt()`."""
        v, ind = values(), indicator()
        cells = [data.fmt(ind, x) for x in v["value"]]
        if suspect():
            # A flagged number is still shown -- it is just never shown as a
            # plain value (plan section 10, Phase 4 gate).
            cells = [c if c == data.EMPTY_DISPLAY else f"{c} {WARN}" for c in cells]
        return pd.DataFrame(
            {
                cut_label(): [str(c) for c in v["category"]],
                f"Value ({_UNIT_COLUMN[unit()]})": cells,
            }
        )

    @reactive.calc
    def flag_alerts() -> list[ui.Tag]:
        ind, iso = indicator(), shared.iso3()
        alerts: list[ui.Tag] = []

        note = data.DATA_FLAGS.get(ind)
        if note:
            bad = suspect()
            alerts.append(
                _alert(
                    f"{WARN} Known issue with “{ind}”",
                    note,
                    kind="danger" if bad else "warning",
                )
            )
            f = finite()
            # Naming the largest cell is what makes an implausible number
            # impossible to read as an ordinary one. It says nothing when the
            # whole row is zero (`HH has internet access`), so skip it there.
            if bad and not f.empty and float(pd.to_numeric(f["value"]).max()) > 0:
                top = f.loc[pd.to_numeric(f["value"]).idxmax()]
                alerts.append(
                    _alert(
                        "Largest value in the view below",
                        f"{top['category']}: {data.fmt(ind, top['value'])} "
                        f"{_UNIT_AXIS[unit()]}. Flagged, shown unaltered, "
                        "not corrected.",
                        kind="danger",
                    )
                )

        # A breakdown-level flag, not an indicator-level one: it applies to every
        # indicator, but only to the residence columns of one country.
        if (
            iso == data.CAPITAL_FLAG_ISO3
            and shared.breakdown() == "residence"
            and shared.geo_level() == "national"
        ):
            alerts.append(
                _alert(
                    f"{WARN} Residence breakdown caveat ({shared.country_label()})",
                    data.CAPITAL_FLAG_TEXT,
                    kind="warning",
                )
            )
        return alerts

    # ---- theme -> indicator cascade ---------------------------------------

    @reactive.effect
    def _cascade():
        """Repopulate the indicator select from the theme (and the country)."""
        cat = catalogue()
        choices = _indicator_choices(cat, str(input.ex_theme()))
        with reactive.isolate():
            wanted = pending() or str(input.ex_indicator() or "")
            if pending() is not None:
                pending.set(None)
        # Never leave a stale selection: if the previous indicator is not in the
        # new theme, fall back to that theme's first indicator.
        selected = wanted if wanted in choices else (choices[0] if choices else None)
        ui.update_select("ex_indicator", choices=choices, selected=selected)

    @reactive.effect
    @reactive.event(input.ex_catalogue_cell_selection)
    def _jump_from_catalogue():
        """Clicking a catalogue row loads that indicator into the selects."""
        selection = input.ex_catalogue_cell_selection() or {}
        rows = tuple(selection.get("rows") or ())
        if not rows:
            return
        with reactive.isolate():
            view = ex_catalogue.data_view()
        if rows[0] >= len(view):
            return
        chosen = str(view.iloc[rows[0]]["Indicator"])
        pending.set(chosen)  # honoured by `_cascade` once the theme catches up
        ui.update_select("ex_theme", selected=data.theme_of(chosen))
        ui.update_select("ex_indicator", selected=chosen)

    # ---- outputs -----------------------------------------------------------

    @render.ui
    def ex_context():
        level = shared.geo_level()
        bits = [
            shared.country_label(),
            {
                "national": "national sheet",
                "adm1": "ADM 1 sheet",
                "zae": "agro-ecological zones",
            }.get(level, level),
            f"unit: {_UNIT_AXIS[unit()]}",
        ]
        if level == "national":
            bits.insert(1, f"{shared.breakdown_obj().label} breakdown")
        line = ui.tags.small(" · ".join(bits), class_="text-muted")
        if level == "national":
            return line
        return ui.TagList(
            line,
            ui.br(),
            ui.tags.small(
                "The sidebar breakdown does not apply at this level: the sheet is "
                "keyed by place, so every place is shown instead.",
                class_="text-muted",
            ),
        )

    @render.ui
    def ex_flags():
        alerts = flag_alerts()
        if alerts:
            return ui.TagList(*alerts)
        return ui.p(
            "No data-quality issue is recorded for this indicator. Values are "
            "shown exactly as the workbook holds them.",
            class_="text-muted mb-0",
        )

    @render.ui
    def ex_values_title():
        return ui.TagList(
            ui.tags.b(indicator() or "No indicator selected"),
            ui.tags.span(
                f" — {shared.country_label()}, by {cut_label().lower()}",
                class_="text-muted",
            ),
        )

    @render.ui
    def ex_chart_title():
        return ui.TagList(
            ui.tags.b(indicator() or "No indicator selected"),
            ui.tags.span(f" — {_UNIT_AXIS[unit()]}", class_="text-muted"),
        )

    @render.ui
    def ex_values_note():
        v, f = values(), finite()
        if v.empty:
            return ui.TagList()
        if f.empty:
            return ui.p(
                f"No values are recorded for “{indicator()}” in "
                f"{shared.country_label()} at this cut, so there is nothing to "
                "tabulate. A blank workbook cell means “not computed” or "
                "“too few observations”; it is not a zero.",
                class_="text-muted mb-0",
            )
        missing = len(v) - len(f)
        if missing:
            return ui.p(
                f"No value is recorded for {missing} of {len(v)} "
                f"{cut_label().lower()}s; they show {data.EMPTY_DISPLAY}.",
                class_="text-muted mb-0",
            )
        return ui.TagList()

    @render.data_frame
    def ex_values():
        # Silenced, not blank: when every cell is empty `ex_values_note` carries
        # the card and an all-dashes grid would say nothing.
        req(not finite().empty)
        styles = (
            [{"cols": [1], "style": FLAG_CELL_STYLE, "class": "ex-flagged"}]
            if suspect()
            else []
        )
        return render.DataGrid(display_frame(), filters=True, width="100%", styles=styles)

    @render_plotly
    def ex_chart():
        template = "plotly_dark" if shared.dark() else "plotly_white"
        ind, v, f = indicator(), values(), finite()

        if not ind or v.empty:
            return _message_figure("Choose an indicator to see its values.", template)
        if f.empty:
            return _message_figure(
                "No values are recorded for this indicator in "
                f"{shared.country_label()} at this cut, so there is nothing to "
                "plot. See the data note for this indicator.",
                template,
            )
        numeric = pd.to_numeric(f["value"])
        if bool((numeric == 0).all()):
            return _message_figure(
                "Every value in this view is exactly 0.00, so there is nothing "
                "to plot. See the data note for this indicator.",
                template,
            )

        frame = values().copy()
        frame["value"] = pd.to_numeric(frame["value"], errors="coerce")
        if shared.geo_level() in ("adm1", "zae"):
            # Places have no natural order, so rank them; breakdown groups do
            # (Q1..Q5, Capital/Other Urban/Rural) and keep the sheet's order.
            frame = frame.sort_values("value", na_position="first")
            order = list(frame["category"])
        else:
            order = list(reversed(list(frame["category"])))  # first group on top

        # Bar labels and hover text are `data.fmt()` output, not raw floats.
        labels = [data.fmt(ind, x) for x in frame["value"]]
        # shinywidgets serialises the widget with `allow_nan=False`, so a NaN
        # anywhere in the trace kills the session ("Out of range float values are
        # not JSON compliant"). `None` is JSON null: plotly draws no bar and
        # keeps the category, which is what a missing value should look like.
        xs = [None if pd.isna(v) else float(v) for v in frame["value"]]
        colour = FLAG_ACCENT if suspect() else ACCENT
        suffix = f" {WARN} flagged" if suspect() else ""

        fig = go.Figure(
            go.Bar(
                x=xs,
                y=[str(c) for c in frame["category"]],
                orientation="h",
                marker_color=colour,
                text=labels,
                textposition="outside",
                cliponaxis=False,
                customdata=[[t] for t in labels],
                hovertemplate="<b>%{y}</b><br>%{customdata[0]}"
                + suffix
                + "<extra></extra>",
            )
        )
        fig.update_layout(
            template=template,
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            showlegend=False,
            margin={"l": 10, "r": 40, "t": 10, "b": 40},
            xaxis_title=_UNIT_AXIS[unit()],
            yaxis_title=None,
            # No zero floor and no abs(): `HE profits (FCFA)` is genuinely
            # negative in SEN TAMBACOUNDA (plan section 9.3).
            xaxis={"tickformat": ".0%" if unit() == "share" else ","},
            yaxis={"categoryorder": "array", "categoryarray": order},
            uniformtext={"mode": "hide", "minsize": 9},
        )
        return fig

    @render.data_frame
    def ex_catalogue():
        cat = catalogue().copy()
        cat["unit"] = [
            "share (%)" if u == "share" else _UNIT_AXIS[u] for u in cat["unit"]
        ]
        cat["flag"] = [f"{WARN} {t}" if t else "" for t in cat["flag"]]
        cat = cat.rename(
            columns={
                "indicator": "Indicator",
                "theme": "Theme",
                "unit": "Unit",
                "flag": "Data note",
            }
        )
        return render.DataGrid(cat, filters=True, width="100%", selection_mode="row", height="340px")
