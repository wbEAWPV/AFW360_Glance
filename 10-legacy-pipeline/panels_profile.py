"""Profile page for AFW 360 At A Glance.

Five real tabs -- `Consumption and Income`, `Jobs`, `Agriculture`, `Energy`,
`Fiscal Equity` -- in one `ui.navset_card_underline(id="pr_tabs")`. The old
Quarto page grouped these five chunks under `### Column {.tabset}` inside a
plain `format: html` document, which renders no tabs at all: the five tables
simply stacked down the page (plan section 4.2).

Rows are the original `indicator_map_*` display labels from `index.qmd:66-129`,
reused verbatim. Columns are `shared.breakdown_obj().columns`, so the sidebar
breakdown re-columns every data tab -- where the old page hard-coded all
thirteen `estimate*` columns side by side in `col_order_Profile`.

Three defects from `index.qmd` are deliberately not carried over:

* `.round(1)` before `{:.0%}` (plan section 9.1 #2). Senegal's consumption
  column is `[0.45, 0.04, 0.38, 0.55, 0.30, 0.25, 0.45]`; rounded first it
  displayed as `40% 0% 40% 60% 30% 20% 40%`. Every number here goes through
  `data.fmt_table()` unrounded.
* `.loc[row_order_*]`, which raised `KeyError` and killed the whole render on
  any label drift (plan section 9.1 #7). `data.table()` uses `.reindex()`, so a
  label that is absent from the workbook yields a blank row -- which is exactly
  what the Agriculture and Energy placeholders below depend on.
* Fiscal Equity's five rows being overwritten with `pd.NA` after the filter
  (`index.qmd:639-643`), so the table could never show data even if the
  workbook were fixed. None of its five indicators exists in either workbook,
  so this tab renders a deliberate empty state naming them instead of a grid of
  blanks.
"""

from __future__ import annotations

from typing import Callable

import pandas as pd

from shiny import reactive, render, ui

import data

PREFIX = "pr"

# --------------------------------------------------------------------------
# Row definitions -- workbook label -> display label, in display order
#
# Taken verbatim from the `indicator_map_*` / `row_order_*` dicts at
# index.qmd:66-129. Dict order is the row order, so `row_order_*` needs no
# separate existence here; `data.table()` reindexes in exactly this order.
# The en dash (U+2013) in "Employed (activ12m, 15-64)" and in the Fiscal
# labels is the real character from the workbook / the old page -- an ASCII
# hyphen there would silently blank the row.
# --------------------------------------------------------------------------

WELFARE_ROWS: dict[str, str] = {
    "Food consumption share": "Food consumption share",
    "Own-production food share (% total cons.)": "Own-production food consumption",
    "Market food share (% total cons.)": "Market food consumption",
    "Non-food consumption share": "Non-food consumption share",
    "Employed in agriculture (% of employed)": "Share employed in agriculture",
    "Employed in industry (% of employed)": "Share employed in industry",
    "Employed in services (% of employed)": "Share employed in services",
}

JOBS_ROWS: dict[str, str] = {
    "Employed (activ12m, 15–64)": "Employment rate",
    "Wage-employed (% of employed)": "Wage employment rate",
    "Share of HH workers informally employed": "Informal wage employment (% of wage)",
    "Non-wage employed (% of employed)": "Non-wage employment rate",
    "HH owns a non-agric enterprise": "Non-agric. enterprise ownership rate",
    "Exposed to any shock (past 3 years)": "Shock exposure rate (any shock, 3 yrs)",
}

# Only the first row exists in the workbooks. The other four are named in
# `row_order_Agri` (index.qmd:110-116) but exist in no sheet of either country
# -- they are code-only placeholders for indicators the survey does not carry.
# They are kept as rows, mapped to themselves so `.reindex()` blanks them, and
# called out in `AGRI_PLACEHOLDERS` below. Dropping them would hide the gap;
# filling them would be fabrication.
AGRI_ROWS: dict[str, str] = {
    "HH cultivates agricultural land (superf > 0)": "Agricultural participation rate",
    "Improved seed use rate": "Improved seed use rate",
    "Fertilizer use rate": "Fertilizer use rate",
    "Market orientation rate": "Market orientation rate",
    "Agricultural mechanisation index": "Agricultural mechanisation index",
}
AGRI_PLACEHOLDERS: tuple[str, ...] = (
    "Improved seed use rate",
    "Fertilizer use rate",
    "Market orientation rate",
    "Agricultural mechanisation index",
)

ENERGY_ROWS: dict[str, str] = {
    "Access to electricity (grid, SDG 7.1.1)": "Access to electricity (grid or off-grid)",
    "Primary cooking fuel clean (gas/electricity)": "Clean cooking fuel access rate",
    "Primary cooking fuel biomass (wood/charcoal)": "Solid biomass dependency rate",
    "Energy expenditure burden": "Energy expenditure burden",
}
ENERGY_PLACEHOLDERS: tuple[str, ...] = ("Energy expenditure burden",)

# index.qmd:607-621. Zero of the five exist in any sheet of either workbook
# (plan section 9.2), so there is no table to build -- see `_fiscal_panel()`.
FISCAL_INDICATORS: tuple[str, ...] = (
    "Aggregate impact of fiscal policy (Gini change)",
    "Absolute incidence – subsidies",
    "Absolute incidence – social spending",
    "Absolute incidence – direct taxes",
    "Absolute incidence – indirect taxes",
)

FISCAL_FIGURE = data.ROOT / "INPUT Figures" / "Fiscal Equity SEN.png"
FISCAL_FIGURE_ISO3 = "SEN"  # the only country the figure was produced for

# The four data tabs: output id -> (tab title, rows, placeholder display labels).
# The tab title is the original `#| title:` string from index.qmd and doubles
# as the card header, per the panel contract.
TAB_SPECS: tuple[tuple[str, str, dict[str, str], tuple[str, ...]], ...] = (
    ("pr_welfare", "Consumption and Income", WELFARE_ROWS, ()),
    ("pr_jobs", "Jobs", JOBS_ROWS, ()),
    ("pr_agri", "Agriculture", AGRI_ROWS, AGRI_PLACEHOLDERS),
    ("pr_energy", "Energy", ENERGY_ROWS, ENERGY_PLACEHOLDERS),
)


# --------------------------------------------------------------------------
# UI helpers
# --------------------------------------------------------------------------


def _note(*children, kind: str = "muted") -> ui.Tag:
    """A small explanatory paragraph under a table.

    `kind="muted"` for context, `kind="warn"` for a data flag that the reader
    has to see before believing the numbers above it.
    """
    if kind == "warn":
        return ui.div(*children, class_="alert alert-warning py-2 px-3 mb-2 small")
    return ui.div(*children, class_="text-muted small mt-2")


def _placeholder_note(labels: tuple[str, ...]) -> ui.Tag | None:
    """Explain the rows that are deliberately blank."""
    if not labels:
        return None
    listed = ", ".join(labels[:-1]) + (" and " if len(labels) > 1 else "") + labels[-1]
    verb = "are" if len(labels) > 1 else "is"
    return _note(
        ui.tags.strong("Not yet collected: "),
        f"{listed} {verb} part of the intended table layout but {verb} not in "
        "either country's summary tables. The row is kept empty rather than "
        "dropped or filled, so the gap stays visible.",
    )


def _flag_notes(rows: dict[str, str]) -> list[ui.Tag]:
    """Surface `data.DATA_FLAGS` for any indicator shown on this tab."""
    out: list[ui.Tag] = []
    for source, display in rows.items():
        flag = data.DATA_FLAGS.get(source)
        if flag:
            out.append(
                _note(ui.tags.strong(f"{display}: "), flag, kind="warn")
            )
    return out


def _table_panel(
    output_id: str,
    title: str,
    rows: dict[str, str],
    placeholders: tuple[str, ...],
) -> ui.NavPanel:
    """One data tab: the grid, then any flags, then the placeholder note."""
    children: list = [ui.output_data_frame(output_id)]
    children.extend(_flag_notes(rows))
    note = _placeholder_note(placeholders)
    if note is not None:
        children.append(note)
    return ui.nav_panel(title, *children)


def _fiscal_panel() -> ui.NavPanel:
    """The Fiscal Equity tab: an empty state, not a grid of blanks.

    Zero of the five indicators exists in either workbook, so there is nothing
    to re-column by breakdown and nothing to format. Naming the five intended
    indicators is the only honest content. The Senegal figure is shown for
    Senegal only -- the old page embedded it twice in the Guinea-Bissau
    section under two different captions (index.qmd:1115, :1122).
    """
    return ui.nav_panel(
        "Fiscal Equity",
        ui.output_ui("pr_fiscal_state"),
        ui.tags.ul(*[ui.tags.li(name) for name in FISCAL_INDICATORS]),
        _note(
            "They would come from CEQ/GamSim fiscal incidence simulations, "
            "which are not part of the EHCVM summary workbooks this dashboard "
            "reads. Nothing is estimated or substituted here."
        ),
        ui.card(
            ui.card_header("Fiscal Equity I - Who pays & Who receives"),
            # height="auto": the default 400px container would crop a wide
            # figure scaled to 100% width.
            ui.output_image("pr_fiscal_figure", width="100%", height="auto", fill=False),
            ui.output_ui("pr_fiscal_figure_note"),
            full_screen=True,
            class_="mt-3",
        ),
    )


def panel():
    """The `ui.nav_panel()` for the Profile page."""
    return ui.nav_panel(
        "Profile",
        ui.navset_card_underline(
            *[_table_panel(*spec) for spec in TAB_SPECS],
            _fiscal_panel(),
            id="pr_tabs",
            header=ui.TagList(
                ui.output_ui("pr_scope"),
                ui.output_ui("pr_capital_flag"),
            ),
            full_screen=True,
        ),
    )


# --------------------------------------------------------------------------
# Server
# --------------------------------------------------------------------------


def server(input, output, session, shared) -> None:
    """Register the Profile page's outputs."""

    def _grid(rows: dict[str, str]) -> Callable[[], pd.DataFrame]:
        """A `@reactive.calc` giving one tab's display-ready frame.

        National level throughout: the `estimate*` breakdown columns only exist
        on the `National` and `ZAE` sheets, and the Profile page is the
        national picture. The regional cut lives on the Geography page.
        """

        @reactive.calc
        def _calc() -> pd.DataFrame:
            raw = data.table(shared.iso3(), rows, shared.breakdown())
            return data.fmt_table(raw).reset_index()

        return _calc

    welfare_data = _grid(WELFARE_ROWS)
    jobs_data = _grid(JOBS_ROWS)
    agri_data = _grid(AGRI_ROWS)
    energy_data = _grid(ENERGY_ROWS)

    @render.data_frame
    def pr_welfare():
        return render.DataGrid(welfare_data(), filters=True, width="100%")

    @render.data_frame
    def pr_jobs():
        return render.DataGrid(jobs_data(), filters=True, width="100%")

    @render.data_frame
    def pr_agri():
        return render.DataGrid(agri_data(), filters=True, width="100%")

    @render.data_frame
    def pr_energy():
        return render.DataGrid(energy_data(), filters=True, width="100%")

    @render.ui
    def pr_scope():
        return ui.div(
            f"{shared.country_label()} | national estimates | "
            f"{shared.breakdown_obj().label} breakdown | "
            f"blank cells ({data.EMPTY_DISPLAY}) mean not collected, not zero",
            class_="text-muted small mb-2",
        )

    @render.ui
    def pr_capital_flag():
        """GNB's residence split is not what its column headers claim."""
        if (
            shared.iso3() == data.CAPITAL_FLAG_ISO3
            and shared.breakdown() == "residence"
        ):
            return _note(
                ui.tags.strong("Residence breakdown flag: "),
                data.CAPITAL_FLAG_TEXT,
                kind="warn",
            )
        return None

    @render.ui
    def pr_fiscal_state():
        """The Fiscal Equity empty state, named for the current selection.

        There is no table here on purpose: with zero of the five indicators
        present there is nothing to re-column, and a grid of blanks reads as a
        loading failure rather than as a known gap (plan section 4.2).
        """
        cols = ", ".join(shared.breakdown_obj().columns.values())
        return ui.p(
            f"No fiscal incidence data is available for "
            f"{shared.country_label()}. None of the five intended indicators "
            f"appears in either country's summary tables, so there is nothing "
            f"to report for the {shared.breakdown_obj().label} breakdown "
            f"({cols}) or for any other cut:",
            class_="mb-2",
        )

    @render.image
    def pr_fiscal_figure():
        """The Senegal fiscal incidence figure -- Senegal only."""
        if shared.iso3() != FISCAL_FIGURE_ISO3 or not FISCAL_FIGURE.exists():
            return None
        return {
            "src": str(FISCAL_FIGURE),
            "width": "100%",
            "alt": (
                "Incidence of taxes, transfers and subsidies across the "
                "welfare distribution, Senegal"
            ),
        }

    @render.ui
    def pr_fiscal_figure_note():
        if shared.iso3() == FISCAL_FIGURE_ISO3:
            return _note(
                "The figure shows the relative incidence of taxes, transfers "
                "and subsidies across the welfare distribution. Source: "
                "CEQ/GamSim simulations based on EHCVM. It is a static image, "
                "not driven by the filters above."
            )
        return _note(
            f"No fiscal incidence figure has been produced for "
            f"{shared.country_label()}. The only figure in the repository is "
            "Senegal's, and it is not shown here."
        )
