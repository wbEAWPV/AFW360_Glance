"""AFW 360 At A Glance - poverty and welfare dashboard for World Bank AFW countries.

Replaces the static Quarto page in `index.qmd`, which was written as a Quarto
dashboard and converted to `format: html` in commit 574527a. That conversion left
every piece of dashboard markup inert: the 27 `#| title:` strings stopped rendering,
`## Row ... {height=}` became literal headings, and `### Column {.tabset}` produced no
tabs at all. The layout those markers describe is rebuilt here for real, and their
strings are reused verbatim as card headers.

The structural change is that **country is a filter, not a page**. `index.qmd` carries
two near-identical country sections, and because `file_path` is assigned only at lines
188 and 370 - both pointing at Tables_SEN.xlsx - and never reassigned, all nine of the
Guinea-Bissau panels read Senegal's workbook. One set of panels parameterised by
`input.country()` makes that class of bug unwritable.

Layout: one `page_navbar` with a global sidebar. Panels live one module per page so
that work on one page cannot collide with another; each exposes `panel()` and
`server(input, output, session, shared)`.
"""

from __future__ import annotations

from shiny import App, reactive, render, ui

import data
import panels_about
import panels_explore
import panels_geography
import panels_overview
import panels_profile

# --------------------------------------------------------------------------------
# Theme
# --------------------------------------------------------------------------------
# cosmo, to stay recognisably close to the Quarto page it replaces (`index.qmd:7`).
# Colour and type belong in Sass variables rather than CSS overrides so that every
# component - cards, value boxes, navbar, grids - picks them up coherently.
THEME = (
    ui.Theme("cosmo")
    .add_defaults(
        primary="#1F4E78",  # the deep blue the legacy download button used
        font_size_base="0.95rem",
    )
    .add_rules(
        """
        .card-header { font-weight: 600; }
        /* Value box figures should read as data, not as headlines. */
        .value-box-value { font-size: clamp(1.4rem, 2.5vw, 2rem); }
        /* Keep long region and indicator labels readable in dense grids. */
        .shiny-data-frame { font-size: 0.9rem; }
        """
    )
)

# --------------------------------------------------------------------------------
# Sidebar
# --------------------------------------------------------------------------------
# Global filters only. A control that affects a single card belongs in that card's
# toolbar, not here. `breakdown` and `geo_level` do not apply to every page, so they
# are revealed per page rather than sitting inert - an inert filter reads as broken.
_BREAKDOWN_PAGES = "['Profile', 'Explore'].includes(input.page)"
_GEO_PAGES = "['Geography', 'Explore'].includes(input.page)"
_POVLINE_PAGES = "['Overview', 'Geography'].includes(input.page)"

# User-facing names for the sheets. data.GEO_LEVELS maps these keys to the workbook's
# own sheet names ("ADM 1", "ZAE"), which are not what a reader should see.
GEO_LABELS = {
    "national": "National",
    "adm1": "Region (ADM 1)",
    "zae": "Zone (agro-ecological)",
}

SIDEBAR = ui.sidebar(
    ui.input_select("country", "Country", {k: v for k, v in data.COUNTRIES.items()}),
    ui.panel_conditional(
        _POVLINE_PAGES,
        ui.input_radio_buttons(
            "povline",
            "Poverty line",
            {k: v.label for k, v in data.POVERTY_LINES.items()},
        ),
    ),
    ui.panel_conditional(
        _BREAKDOWN_PAGES,
        ui.input_select(
            "breakdown",
            "Breakdown",
            {k: v.label for k, v in data.BREAKDOWNS.items()},
        ),
    ),
    ui.panel_conditional(
        _GEO_PAGES,
        ui.input_select("geo_level", "Geography", GEO_LABELS),
    ),
    ui.hr(),
    ui.download_button("dl_workbook", "Download summary tables", class_="btn-outline-primary btn-sm"),
    ui.input_dark_mode(id="mode"),
    title="Filters",
    width=280,
)


class Shared:
    """The global filter state, as reactive calcs, handed to every panel module.

    Panels read `shared.iso3()` rather than `input.country()` so that renaming an
    input, or deriving one differently, touches this class alone. It is also the
    seam that keeps the panel modules independent of each other.
    """

    def __init__(self, input):
        @reactive.calc
        def iso3() -> str:
            return input.country()

        @reactive.calc
        def country_label() -> str:
            return data.COUNTRIES[input.country()]

        @reactive.calc
        def povline():
            return data.POVERTY_LINES[input.povline()]

        @reactive.calc
        def breakdown() -> str:
            return input.breakdown()

        @reactive.calc
        def breakdown_obj():
            return data.BREAKDOWNS[input.breakdown()]

        @reactive.calc
        def geo_level() -> str:
            return input.geo_level()

        @reactive.calc
        def dark() -> bool:
            return input.mode() == "dark"

        self.iso3 = iso3
        self.country_label = country_label
        self.povline = povline
        self.breakdown = breakdown
        self.breakdown_obj = breakdown_obj
        self.geo_level = geo_level
        self.dark = dark


app_ui = ui.page_navbar(
    panels_overview.panel(),
    panels_profile.panel(),
    panels_geography.panel(),
    panels_explore.panel(),
    panels_about.panel(),
    title="AFW 360 At A Glance",
    id="page",
    # Per-panel opt-in, not True. These pages are stacked rows taller than a
    # viewport; under a fillable panel the cards get crushed instead of scrolling.
    fillable=False,
    sidebar=SIDEBAR,
    theme=THEME,
)


def server(input, output, session):
    shared = Shared(input)

    panels_overview.server(input, output, session, shared)
    panels_profile.server(input, output, session, shared)
    panels_geography.server(input, output, session, shared)
    panels_explore.server(input, output, session, shared)
    panels_about.server(input, output, session, shared)

    @render.download_button(filename=lambda: f"AFW360_Tables_{input.country()}.xlsx")
    def dl_workbook():
        # Replaces the ~114 KB base64 `data:` URI the legacy page inlined into the
        # HTML for each country (index.qmd:691-714, :1148-1171).
        yield data.workbook_bytes(input.country())


app = App(app_ui, server)
