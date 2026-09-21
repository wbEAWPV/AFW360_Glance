"""About page: methodology, survey provenance, downloads, and known data limitations.

Three things the legacy page got wrong are fixed here.

* The About text never rendered at all. `index.qmd:672-715` emits two `HTML()`
  objects from one chunk and Jupyter displays only the last, so the methodology
  box was silently dropped and only the download button survived.
* The workbook was inlined as a ~114 KB base64 `data:` URI. It is now a real
  `@render.download_button`, so the page no longer carries the workbook.
* Guinea-Bissau inherited Senegal's text. `INPUT Text/About_GNB.txt` contains the
  literal string "TEXT", and `INPUT Text/About.txt` is byte-identical to
  `About_SEN.txt` - so the "shared" About file is in fact Senegal's methodology.
  Neither is a truthful source for Guinea-Bissau, so GNB gets an explicit
  "not yet written" state rather than another country's methodology.

The limitations card is deliberate, not defensive. Plan section 10 records the
decision that the dashboard shows upstream defects with a flag rather than hiding
or silently correcting them; this is where the dataset-wide ones are stated.
"""

from __future__ import annotations

from shiny import render, ui

import data

PREFIX = "ab"

# Survey provenance, per country.
#
# Senegal's is taken from INPUT Text/About_SEN.txt, which is a real methodology
# note. Guinea-Bissau has none: its About file is a stub and plan section 11.2
# records the survey year as an open question. Inventing a plausible source line
# would be fabricating provenance, which is worse than admitting the gap, so the
# GNB entry is None and the card says so.
SURVEY_SOURCE: dict[str, str | None] = {
    "SEN": (
        "Enquête Harmonisée sur les Conditions de Vie des Ménages (EHCVM 2021), "
        "conducted by the Agence Nationale de la Statistique et de la Démographie "
        "(ANSD) between November 2021 and September 2022. Nationally representative, "
        "7,100 households. Welfare measure: consumption per capita. Poverty lines are "
        "2021 PPP."
    ),
    "GNB": None,
}

# Limitations that apply to a whole country or the whole dataset, rather than to
# one indicator. Per-indicator flags live in data.DATA_FLAGS and are surfaced on
# the pages that draw the indicator.
DATASET_LIMITATIONS: list[tuple[str, str]] = [
    (
        "Fiscal Equity has no underlying data",
        "None of its five indicators exists in either workbook. The tab states this "
        "rather than showing empty cells that look like zeros.",
    ),
    (
        "Some profile rows are not yet collected",
        "Four Agriculture rows (improved seed use, fertiliser use, market orientation, "
        "mechanisation) and one Energy row (energy expenditure burden) are placeholders "
        "carried over from the original layout. They are shown as empty with a note, "
        "not dropped and not filled in.",
    ),
    (
        "Blank is not zero",
        "A blank cell means either 'not computed' or 'too few observations'; the "
        "workbooks do not distinguish the two. Blanks render as –, never as 0.",
    ),
    (
        "Senegal's Departement sheet is not used",
        "It is region-keyed despite its name, uses 2017 PPP where every other sheet "
        "uses 2021 PPP, and disagrees with the ADM 1 sheet on 54 of 60 shared "
        "indicators. It is left unread pending clarification from the producers.",
    ),
    (
        "Agro-ecological zones have no geometry",
        "No shapefile exists for the zones of either country, so zone views are "
        "charts and tables only. This is by design, not a missing file.",
    ),
]

_BOX = (
    "border:1px solid var(--bs-border-color);border-radius:8px;padding:1rem;"
    "background-color:var(--bs-secondary-bg);"
)


def panel():
    """The About nav panel."""
    return ui.nav_panel(
        "About",
        ui.layout_columns(
            ui.card(
                # The original `#| title:` string from index.qmd:673, verbatim.
                ui.card_header("Data and Methodology"),
                ui.output_ui("ab_methodology"),
                full_screen=True,
            ),
            ui.div(
                ui.card(
                    ui.card_header("Survey source"),
                    ui.output_ui("ab_source"),
                ),
                ui.card(
                    ui.card_header("Downloads"),
                    ui.output_ui("ab_download_note"),
                    ui.download_button(
                        "ab_dl_workbook", "Download summary tables (.xlsx)", class_="btn-primary"
                    ),
                ),
                class_="d-flex flex-column gap-3",
            ),
            col_widths={"sm": (12, 12), "lg": (7, 5)},
        ),
        ui.card(
            ui.card_header("Known data limitations"),
            ui.output_ui("ab_limitations"),
            full_screen=True,
        ),
    )


def server(input, output, session, shared) -> None:
    """Register the About page's outputs."""

    @render.ui
    def ab_methodology():
        iso3 = shared.iso3()
        text = data.about_text(iso3)
        # About_GNB.txt is the literal placeholder "TEXT". Treat any stub as absent
        # rather than rendering it, and never fall back to another country's file.
        if len(text.strip()) < 40:
            return ui.div(
                ui.p(
                    ui.strong("No methodology note has been written for "),
                    ui.strong(shared.country_label()),
                    ".",
                ),
                ui.p(
                    f"INPUT Text/About_{iso3}.txt is still a placeholder. Senegal's "
                    "methodology is not shown here because it describes a different "
                    "survey, a different statistical agency and a different sample.",
                    class_="text-muted mb-0",
                ),
                style=_BOX,
            )
        paragraphs = [p.strip() for p in text.split("\n") if p.strip()]
        return ui.div(*[ui.p(p) for p in paragraphs], style=_BOX)

    @render.ui
    def ab_source():
        source = SURVEY_SOURCE.get(shared.iso3())
        if source is None:
            return ui.p(
                "The survey behind Guinea-Bissau's figures is not documented in the "
                "inputs, so no source line is shown. The survey year is an open "
                "question with the data producers.",
                class_="text-muted mb-0",
            )
        return ui.p(source, class_="mb-0")

    @render.ui
    def ab_download_note():
        return ui.p(
            f"The full indicator workbook for {shared.country_label()}: all 97 "
            "indicators across the National, ADM 1 and zone sheets, exactly as "
            "supplied by the data producers.",
            class_="text-muted",
        )

    @render.ui
    def ab_limitations():
        items = list(DATASET_LIMITATIONS)
        # Country-specific caveat: GNB's Capital column is a copy of a zone.
        if shared.iso3() == data.CAPITAL_FLAG_ISO3:
            items.insert(
                0,
                (
                    "Guinea-Bissau's 'Capital' column is not Bissau",
                    data.CAPITAL_FLAG_TEXT,
                ),
            )
        return ui.div(
            ui.p(
                "These are defects in the source data, reported upstream. The "
                "dashboard shows the affected numbers unaltered and flags them "
                "where they appear; it does not correct or suppress them.",
                class_="text-muted",
            ),
            ui.tags.dl(
                *[
                    x
                    for title, body in items
                    for x in (ui.tags.dt(title), ui.tags.dd(body, class_="text-muted"))
                ]
            ),
            style=_BOX,
        )

    @render.download_button(
        filename=lambda: f"AFW360_Tables_{shared.iso3()}.xlsx",
    )
    def ab_dl_workbook():
        yield data.workbook_bytes(shared.iso3())
