"""In-memory server tests for the Shiny app (plan section 12, Phase 6).

`tests/test_data.py` proves the data layer. This file proves the *app*: that the
reactive chain wires the sidebar to the panels, that every number the user sees
went through `data.fmt()`, and that each defect catalogued in
`.docs/shiny-port-plan.md` section 9.1 stays fixed. Every assertion below maps to
one of them:

* #1 Guinea-Bissau displayed Senegal's numbers -- `file_path` was assigned twice
  in `index.qmd` and never reassigned, so all nine GNB panels read
  `Tables_SEN.xlsx`. Gate 1 pins GNB's own figures on all five pages.
* #2 `.round(1)` before `{:.0%}` turned 0.45 into `40%`. Gate 2.
* #3 `{:.0%}` over a count turned 6.52 into `650%`. Gate 2, and swept over all
  15 level indicators in Gate 7.
* #4 Fiscal Equity could never show data; #5 the About text never rendered;
  #8 GNB had no choropleth; #11 GNB showed Senegal's figure. Gates 1 and 4.

The ground-truth numbers come from the real workbooks. If the code and the
numbers disagree, the code is wrong.

Running: the console here is cp1252 and these tests carry U+2013 and U+26A0, so
run with `PYTHONIOENCODING=utf-8`. The three `test_sweep_*` tests account for
about 80 of the suite's 140 seconds; deselect them with `-k "not sweep"`.
"""

import sys
from pathlib import Path

import pytest
from shiny import reactive
from shiny.testserver import test_server

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import data  # noqa: E402

APP = Path(__file__).resolve().parents[1] / "app.py"

RATE_420 = data.POVERTY_LINES["420"].rate_indicator

# The five nav values, exactly as `ui.nav_panel()` registers them in app.py.
PAGES = ("Overview", "Profile", "Geography", "Explore", "About")

# A headless session sends no initial input values at all -- not the sidebar's
# selects and not the card-local ones -- so every input a test depends on has to
# be set explicitly. This is the state every test starts from.
BASELINE = {
    "country": "SEN",
    "povline": "420",
    "breakdown": "total",
    "geo_level": "national",
    "mode": "light",
    "ge_indicator": RATE_420,  # the Geography card's own toolbar select
    "ex_theme": "Poverty",  # the Explore card's own selects
    "ex_indicator": RATE_420,
}


# --------------------------------------------------------------------------
# Fixtures and helpers
# --------------------------------------------------------------------------


def _reset(session):
    """Put a session back on the baseline: nav panel first, then the filters.

    Two calls, not one: the nav panel settles on the *following* flush, so a
    test that reads an output in the same flush that switched pages could read
    a stale value.

    Only ids that have drifted are re-sent. `set_inputs()` re-sends every id it
    is given with `force=True` -- an unchanged value still invalidates
    everything downstream of it -- so resetting all eight would redraw four
    Plotly widgets before every test.
    """
    current = {name: value.value for name, value in session.to_values().inputs.items()}
    if current.get("page") != "Overview":
        session.set_inputs(page="Overview")
    stale = {key: value for key, value in BASELINE.items() if current.get(key) != value}
    if stale:
        session.set_inputs(**stale)


@pytest.fixture(scope="module")
def _app_session():
    """One warmed session for the whole module.

    Starting a session costs ~4s (importing the app, parsing the GeoJSON and
    rendering four Plotly widgets), which over thirty tests would be two
    minutes of pure startup. `_reset()` between tests is a real reset rather
    than a hope: an id that is re-sent invalidates everything downstream of it
    whatever its value, so every output that reads a filter recomputes. Tests
    that could take the session down with them -- the NaN regression and the
    sweeps -- take `fresh_ts` instead.
    """
    with test_server(APP, timeout_secs=60) as session:
        _reset(session)
        yield session


@pytest.fixture
def ts(_app_session):
    """The shared session, reset to `BASELINE`."""
    _reset(_app_session)
    return _app_session


@pytest.fixture
def fresh_ts():
    """A session of this test's own, reset to `BASELINE`."""
    with test_server(APP, timeout_secs=60) as session:
        _reset(session)
        yield session


def show(session, page, **filters):
    """Switch nav panel, then apply filters -- in that order, in two flushes."""
    assert page in PAGES
    session.set_inputs(page=page)
    if filters:
        session.set_inputs(**filters)


def grid(session, output_id):
    """(columns, rows) of a `render.data_frame` payload."""
    value = session.get_output(output_id)
    assert value.status == "ok", f"{output_id} is {value.status}: {value.error}"
    payload = value.value["payload"]
    return payload["columns"], payload["data"]


def grid_row(session, output_id, label):
    """One row of a grid as {column: cell}, found by its first-column label."""
    columns, rows = grid(session, output_id)
    matches = [row for row in rows if row[0] == label]
    assert matches, f"{output_id} has no row {label!r}: {[r[0] for r in rows]}"
    return dict(zip(columns, matches[0]))


def grid_column(session, output_id, name):
    columns, rows = grid(session, output_id)
    assert name in columns, f"{output_id} has no column {name!r}: {columns}"
    return [row[columns.index(name)] for row in rows]


def html(session, output_id):
    """The HTML a `render.ui` output produced -- "" when it produced nothing."""
    value = session.get_output(output_id)
    assert value.status == "ok", f"{output_id} is {value.status}: {value.error}"
    rendered = value.value
    return "" if rendered is None else rendered["html"]


def text(session, output_id):
    """The string a `render.text` output produced."""
    value = session.get_output(output_id)
    assert value.status == "ok", f"{output_id} is {value.status}: {value.error}"
    return value.value


def download(session, output_id):
    """(filename, bytes) for a download handler.

    A download control is an output whose *value* is only a URL; the bytes are
    served separately from `session._downloads`, and there is no public
    accessor for it, so the registry is read directly. Both the filename
    callable and the handler read reactive values, hence `isolate()`.
    """
    registry = session._async_session._session._downloads
    assert output_id in registry, f"no download {output_id!r}: {list(registry)}"
    info = registry[output_id]
    with reactive.isolate():
        filename = info.filename() if callable(info.filename) else info.filename
        payload = b"".join(info.handler())
    return filename, payload


# --------------------------------------------------------------------------
# Gate 1: Guinea-Bissau is Guinea-Bissau (plan 9.1 #1, the worst of them)
# --------------------------------------------------------------------------


def test_guinea_bissau_kpis_are_its_own_and_not_senegals():
    """The headline numbers the old page got wrong on all nine GNB panels."""
    with test_server(APP, timeout_secs=60) as session:
        _reset(session)
        # Senegal first, so the comparison is against what GNB used to show.
        assert text(session, "ov_kpi_rate") == "37%"
        assert text(session, "ov_kpi_count") == "6.52"

        session.set_inputs(country="GNB")
        assert text(session, "ov_kpi_rate") == "62%"
        assert text(session, "ov_kpi_count") == "1.09"


def test_the_country_filter_reaches_every_page_not_only_the_overview(ts):
    """One filter, five pages: Overview, Profile, Geography and Explore move.

    `index.qmd` duplicated the whole page per country and the duplicate read the
    wrong workbook. Here the panels are shared, so the test is that each page's
    numbers actually change when the country does.
    """
    senegal = {
        "kpi": text(ts, "ov_kpi_rate"),
        "profile": grid_column(ts, "pr_welfare", "Total"),
        "geography": grid(ts, "ge_table")[1],
        "explore": grid(ts, "ex_values")[1],
        "about": html(ts, "ab_methodology"),
    }

    ts.set_inputs(country="GNB")
    bissau = {
        "kpi": text(ts, "ov_kpi_rate"),
        "profile": grid_column(ts, "pr_welfare", "Total"),
        "geography": grid(ts, "ge_table")[1],
        "explore": grid(ts, "ex_values")[1],
        "about": html(ts, "ab_methodology"),
    }

    for page, senegal_value in senegal.items():
        assert senegal_value != bissau[page], f"{page} did not follow the country"

    # ... and the new values are Guinea-Bissau's, not merely different.
    assert bissau["kpi"] == "62%"
    assert bissau["geography"] == [["National total", "62%"]]
    assert bissau["explore"] == [["Total", "62%"]]


def test_key_messages_are_never_borrowed_from_another_country(ts):
    """GNB's three message chunks are the literal string "TEXT" upstream.

    Senegal's prose describes Senegal's regions by name (Dakar, Thies,
    Diourbel); showing it under Guinea-Bissau would be fabrication, so the card
    says the text is not drafted instead.
    """
    assert "In 2026" in html(ts, "ov_message_1")
    assert "Dakar" in html(ts, "ov_message_2")

    ts.set_inputs(country="GNB")
    for output_id in ("ov_message_1", "ov_message_2", "ov_message_3"):
        rendered = html(ts, output_id)
        assert "not yet drafted" in rendered
        assert "Dakar" not in rendered


def test_the_about_text_renders_and_is_not_senegals_for_guinea_bissau(ts):
    """Plan 9.1 #5: both About chunks emitted two HTML objects and Jupyter kept
    only the last, so the methodology box never appeared at all."""
    senegal = html(ts, "ab_methodology")
    assert "EHCVM" in senegal
    assert "ANSD" in html(ts, "ab_source")

    ts.set_inputs(country="GNB")
    bissau = html(ts, "ab_methodology")
    assert "No methodology note has been written" in bissau
    assert "EHCVM" not in bissau
    assert "not documented" in html(ts, "ab_source")


def test_guinea_bissau_gets_its_own_region_map(ts):
    """Plan 9.1 #8: GNB never had a choropleth, only a bar chart at $3.00/day
    where Senegal's used $4.20. Both countries now map all their regions."""
    assert ts.get_output("ov_map").status == "ok"
    assert "14 of 14 regions have an estimate" in html(ts, "ov_map_note")

    ts.set_inputs(country="GNB")
    assert ts.get_output("ov_map").status == "ok"
    # 9 of 9, not 8: the GeoJSON build aliases the shapefile's "Bissau" to the
    # workbook's `estimateSAB` (plan 6.1), so the capital joins.
    assert "9 of 9 regions have an estimate" in html(ts, "ov_map_note")
    assert "$4.20/day (2021 PPP)" in text(ts, "ov_map_header")


def test_the_senegal_fiscal_figure_is_shown_for_senegal_only(ts):
    """Plan 9.1 #11: `INPUT Figures/Fiscal Equity SEN.png` was embedded in the
    Guinea-Bissau section twice, under two different captions."""
    senegal = ts.get_output("pr_fiscal_figure")
    assert senegal.status == "ok"
    assert senegal.value["src"].startswith("data:image/png;base64,")
    assert "Source: CEQ/GamSim" in html(ts, "pr_fiscal_figure_note")

    ts.set_inputs(country="GNB")
    assert ts.get_output("pr_fiscal_figure").value is None
    note = html(ts, "pr_fiscal_figure_note")
    assert "No fiscal incidence figure has been produced" in note
    assert "Guinea-Bissau" in note


# --------------------------------------------------------------------------
# Gate 2: display formatting (plan 9.1 #2 and #3)
# --------------------------------------------------------------------------


def test_consumption_column_is_not_rounded_before_it_is_formatted(ts):
    """The Profile Consumption tab, Senegal, Total.

    Raw: [0.45, 0.04, 0.38, 0.55, 0.30, 0.25, 0.45]. `.round(1)` first -- what
    index.qmd:494 did -- gives ['40%','0%','40%','60%','30%','20%','40%'].
    """
    assert grid_column(ts, "pr_welfare", "Total") == [
        "45%",
        "4%",
        "38%",
        "55%",
        "30%",
        "25%",
        "45%",
    ]


def test_number_poor_is_a_count_not_a_percentage(ts):
    """`{:.0%}` over 6.52 gave `650%` (plan 9.1 #3, `style_table` called 14x)."""
    row = grid_row(ts, "ov_table_420", "Number poor (millions)")
    assert row["Total"] == "6.52"
    assert row["Capital"] == "0.13"
    assert row["Rural"] == "5.20"
    assert "%" not in "".join(str(cell) for cell in row.values())

    # The rate row directly above it is a share, and does carry the percent.
    assert grid_row(ts, "ov_table_420", "Poverty rate")["Total"] == "37%"

    # The same two rows at the other line, and for the other country.
    assert grid_row(ts, "ov_table_300", "Number poor (millions)")["Total"] == "3.13"
    ts.set_inputs(country="GNB")
    assert grid_row(ts, "ov_table_420", "Number poor (millions)")["Total"] == "1.09"
    assert grid_row(ts, "ov_table_300", "Number poor (millions)")["Total"] == "0.70"


def test_the_kpi_row_formats_each_indicator_in_its_own_unit(ts):
    """Two shares and one count side by side in the same row of value boxes."""
    assert text(ts, "ov_kpi_rate") == "37%"
    assert text(ts, "ov_kpi_count") == "6.52"  # millions, never `650%`
    assert text(ts, "ov_kpi_employment") == "57%"
    assert text(ts, "ov_kpi_electricity") == "68%"


# --------------------------------------------------------------------------
# Gate 3: the reactive chain -- dependent outputs change, not merely exist
# --------------------------------------------------------------------------


def test_the_poverty_line_propagates_to_the_kpis_and_the_map(ts):
    before = (
        text(ts, "ov_kpi_rate"),
        text(ts, "ov_kpi_count"),
        text(ts, "ov_map_header"),
        html(ts, "ov_kpi_rate_note"),
    )
    assert before[:3] == ("37%", "6.52", "Poverty by Region - $4.20/day (2021 PPP)")

    ts.set_inputs(povline="300")
    after = (
        text(ts, "ov_kpi_rate"),
        text(ts, "ov_kpi_count"),
        text(ts, "ov_map_header"),
        html(ts, "ov_kpi_rate_note"),
    )
    assert after[:3] == ("18%", "3.13", "Poverty by Region - $3.00/day (2021 PPP)")
    assert "$3.00/day (2021 PPP)" in after[3]
    assert all(a != b for a, b in zip(before, after))


@pytest.mark.parametrize(
    ("breakdown", "columns"),
    [
        ("total", ["Total"]),
        ("residence", ["Capital", "Other Urban", "Rural"]),
        ("sex", ["Female", "Male"]),
        ("age", ["Youth", "29+"]),  # "29+" is index.qmd's own label (plan 11.3)
        ("quintile", ["Q1", "Q2", "Q3", "Q4", "Q5"]),
    ],
)
def test_the_breakdown_recolumns_every_profile_table(ts, breakdown, columns):
    """index.qmd hard-coded all thirteen `estimate*` columns side by side; the
    sidebar breakdown now decides the columns of all four data tabs."""
    ts.set_inputs(breakdown=breakdown)
    for output_id in ("pr_welfare", "pr_jobs", "pr_agri", "pr_energy"):
        assert grid(ts, output_id)[0] == ["Indicator"] + columns
    assert data.BREAKDOWNS[breakdown].label in html(ts, "pr_scope")

    # The Explore values table rows by the same groups at national level.
    assert grid_column(ts, "ex_values", "Group") == columns


def test_the_breakdown_changes_the_numbers_and_not_only_the_headers(ts):
    """A re-columned table that kept Total's numbers would pass a shape check."""
    total = grid_column(ts, "pr_welfare", "Total")
    ts.set_inputs(breakdown="quintile")
    poorest = grid_column(ts, "pr_welfare", "Q1")
    richest = grid_column(ts, "pr_welfare", "Q5")
    assert poorest != total
    assert poorest != richest
    # Food is a bigger share of the poorest quintile's basket than the richest's.
    assert poorest[0] == "53%"
    assert richest[0] == "35%"


@pytest.mark.parametrize(
    ("level", "noun", "places"),
    [
        ("national", "National", 1),
        ("adm1", "Region", 14),  # Senegal's 14 ADM 1 regions (plan 9.2)
        ("zae", "Agro-Ecological Zone", 6),  # and its 6 zones
    ],
)
def test_the_geography_filter_changes_the_places_in_the_table(ts, level, noun, places):
    show(ts, "Geography", geo_level=level)
    columns, rows = grid(ts, "ge_table")
    assert columns == [noun, "Value (%)"]
    assert len(rows) == places


def test_the_geography_cards_all_read_the_indicator_chosen_in_the_map_toolbar(ts):
    """The card-local select drives the map, the bars and the grid together."""
    show(ts, "Geography", geo_level="adm1")
    assert "Poverty by Region" in html(ts, "ge_map_title")
    poverty = grid(ts, "ge_table")[1]

    ts.set_inputs(ge_indicator="Access to electricity (grid, SDG 7.1.1)")
    assert "Access to electricity (grid, SDG 7.1.1) by Region" in html(ts, "ge_map_title")
    assert grid(ts, "ge_table")[1] != poverty
    assert ts.get_output("ge_map").status == "ok"
    assert ts.get_output("ge_bars").status == "ok"


# --------------------------------------------------------------------------
# Gate 4: the empty states are reached deliberately, and say why
# --------------------------------------------------------------------------


def test_fiscal_equity_states_the_gap_for_both_countries(ts):
    """Plan 9.1 #4: the five rows were overwritten with `pd.NA` after the
    filter, so the tab could never show data even if the workbook were fixed --
    and 0 of its 5 indicator strings exist in either workbook."""
    for iso3, country in data.COUNTRIES.items():
        ts.set_inputs(country=iso3)
        state = html(ts, "pr_fiscal_state")
        assert "No fiscal incidence data is available" in state
        assert country in state
        # The empty state, not a grid of blanks: there is no table output here.
        with pytest.raises(KeyError):
            ts.get_output("pr_fiscal")


def test_zone_level_says_there_is_no_zone_geometry(ts):
    """Plan 6.2: boundaries are published for ADM0 and ADM1 only, for both
    countries and permanently. The map card says so; the bars and grid carry
    the view."""
    show(ts, "Geography", geo_level="zae")
    note = html(ts, "ge_map_note")
    assert "No map at this level" in note
    assert "no agro-ecological zone geometry for Senegal" in note

    # An annotation-only figure, not a blank canvas and not invented geometry.
    assert ts.get_output("ge_map").status == "ok"
    assert ts.get_output("ge_bars").status == "ok"
    assert len(grid(ts, "ge_table")[1]) == 6
    assert "truncated at 32 characters" in html(ts, "ge_table_footer")


def test_national_level_can_be_neither_mapped_nor_ranked(ts):
    show(ts, "Geography", geo_level="national")
    note = html(ts, "ge_map_note")
    assert "'National' is a single value for Senegal" in note
    assert ts.get_output("ge_map").status == "ok"
    assert ts.get_output("ge_bars").status == "ok"
    assert grid(ts, "ge_table")[1] == [["National total", "37%"]]
    assert "Only the national total exists at this level" in html(
        ts, "ge_table_footer"
    )


def test_an_all_missing_indicator_silences_the_grid_and_explains_why(ts):
    """`wood_dist [ALL MISSING]` is empty in every cell of both countries. An
    all-dashes grid would read as a loading failure, so the grid is silenced
    (`req()`) and the note carries the card."""
    show(ts, "Explore", ex_indicator="wood_dist [ALL MISSING]")
    assert ts.get_output("ex_values").status == "silent"

    note = html(ts, "ex_values_note")
    assert "No values are recorded" in note
    assert "it is not a zero" in note
    # The chart renders its own message rather than an empty axis.
    assert ts.get_output("ex_chart").status == "ok"
    assert ts.is_ok


def test_agriculture_and_energy_placeholders_stay_visible_as_blanks(ts):
    """Four Agriculture rows and one Energy row are named in index.qmd's
    `row_order_*` but exist in no sheet. `.loc[row_order]` raised a KeyError
    and killed the render (plan 9.1 #7); `.reindex()` blanks the row instead."""
    agriculture = dict(zip(*[grid_column(ts, "pr_agri", c) for c in ("Indicator", "Total")]))
    assert agriculture["Agricultural participation rate"] == "41%"
    for label in (
        "Improved seed use rate",
        "Fertilizer use rate",
        "Market orientation rate",
        "Agricultural mechanisation index",
    ):
        assert agriculture[label] == data.EMPTY_DISPLAY  # an en dash, never "0%"

    energy = dict(zip(*[grid_column(ts, "pr_energy", c) for c in ("Indicator", "Total")]))
    assert energy["Energy expenditure burden"] == data.EMPTY_DISPLAY
    assert energy["Access to electricity (grid or off-grid)"] == "68%"


# --------------------------------------------------------------------------
# Gate 5: known-bad data is flagged where it is drawn (plan section 10)
# --------------------------------------------------------------------------


def test_cultivated_area_is_flagged_for_guinea_bissau(ts):
    """Phase 4's gate: GNB Quinara is 148.4M hectares where the rest of the row
    is 1-15 ha. Shown unaltered, named, and impossible to read as ordinary."""
    show(ts, "Explore", country="GNB", geo_level="adm1",
         ex_indicator="Cultivated area (ha)")
    flags = html(ts, "ex_flags")
    assert "Known issue" in flags
    assert "Cultivated area (ha)" in flags
    assert "Quinara: 148,439,533.9 hectares" in flags
    assert "shown unaltered, not corrected" in flags

    # The number is still published, and every cell of it is marked.
    cells = grid_column(ts, "ex_values", "Value (ha)")
    assert "148,439,533.9 ⚠" in cells
    assert all(cell.endswith("⚠") for cell in cells)

    # Senegal's values are clean, so Senegal gets the definition note only.
    ts.set_inputs(country="SEN")
    senegal = html(ts, "ex_flags")
    assert "Known issue" in senegal
    assert "Largest value in the view below" not in senegal
    assert not any(
        cell.endswith("⚠") for cell in grid_column(ts, "ex_values", "Value (ha)")
    )


def test_the_same_flag_reaches_the_geography_page(ts):
    show(ts, "Geography", country="GNB", geo_level="adm1",
         ge_indicator="Cultivated area (ha)")
    assert "Data quality warning" in html(ts, "ge_flag")
    assert "carries a data quality warning" in html(ts, "ge_map_footer")

    ts.set_inputs(ge_indicator=RATE_420)
    assert html(ts, "ge_flag") == ""  # no flag invented for a clean indicator


def test_the_capital_caveat_surfaces_only_for_guinea_bissaus_residence_split(ts):
    """A breakdown-level flag, not an indicator-level one (plan 10.1): GNB's
    `estimateCapital` is a copy of the Zonas Costeiras do Sul zone."""
    assert html(ts, "pr_capital_flag") == ""  # SEN, total

    ts.set_inputs(breakdown="residence")
    assert html(ts, "pr_capital_flag") == ""  # SEN, residence

    ts.set_inputs(country="GNB", breakdown="total")
    assert html(ts, "pr_capital_flag") == ""  # GNB, but not the residence cut

    ts.set_inputs(breakdown="residence")
    flag = html(ts, "pr_capital_flag")
    assert "Residence breakdown flag" in flag
    assert "copy of a zone, not Bissau" in flag

    # ... and on Explore, where the same columns are drawn.
    show(ts, "Explore")
    assert "Residence breakdown caveat (Guinea-Bissau)" in html(ts, "ex_flags")


def test_the_poverty_tables_always_carry_the_capital_caveat_for_guinea_bissau(ts):
    """Both international poverty tables show the residence split unconditionally,
    so both carry the note whatever the sidebar breakdown says."""
    assert "Capital column is not Bissau" not in html(ts, "ov_note_420")
    ts.set_inputs(country="GNB")
    for output_id in ("ov_note_300", "ov_note_420"):
        assert "Capital column is not Bissau" in html(ts, output_id)


# --------------------------------------------------------------------------
# Gate 6: levels are not shares (plan 9.3, the 15 level indicators)
# --------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("indicator", "column", "cell"),
    [
        # FCFA: thousands separator, no decimals, no percent sign.
        ("Monthly electricity spend (FCFA)", "Value (FCFA)", "14,599"),
        # A count of people in a household enterprise, one decimal.
        ("Number of employees in HE", "Value (count)", "1.3"),
        # "millions" keeps two decimals -- this is the `650%` row.
        ("Number poor $4.20/day (millions)", "Value (millions)", "6.52"),
        # Hectares, and a share for contrast.
        ("Cultivated area (ha)", "Value (ha)", "3.9"),
        ("Tropical Livestock Units (TLU)", "Value (TLU)", "2.8"),
        (RATE_420, "Value (%)", "37%"),
    ],
)
def test_explore_shows_each_indicator_in_its_own_unit(ts, indicator, column, cell):
    show(ts, "Explore", ex_indicator=indicator)
    columns, rows = grid(ts, "ex_values")
    assert columns == ["Group", column]
    assert rows == [["Total", cell]]
    assert data.unit_label(indicator) in column


def test_he_profits_keeps_its_negative_sign(ts):
    """Senegal TAMBACOUNDA is -3,460.34 FCFA (plan 9.3). Not an absolute value,
    and not a zero-floored axis."""
    show(ts, "Explore", geo_level="adm1", ex_indicator="HE profits (FCFA)")
    cells = dict(grid(ts, "ex_values")[1])
    assert cells["Tambacounda"] == "-3,460"
    assert cells["Dakar"] == "128,498"

    # Geography formats through data.fmt() too, so both pages agree.
    show(ts, "Geography", ge_indicator="HE profits (FCFA)")
    values = dict(grid(ts, "ge_table")[1])
    assert values["Tambacounda"] == "-3,460"


def test_a_region_cut_full_of_holes_does_not_kill_the_session(fresh_ts):
    """13 ADM1 cuts carry NaN, and shinywidgets serialises a widget with
    `allow_nan=False` -- a NaN reaching a Plotly trace ends the *session*, not
    just the output. `HE revenue per worker (FCFA)` is missing for 7 of Guinea-
    Bissau's 9 regions, the worst of the 13. In its own session so that a
    regression here cannot be mistaken for a failure of the tests after it.
    """
    indicator = "HE revenue per worker (FCFA)"
    show(fresh_ts, "Explore", country="GNB", geo_level="adm1",
         ex_indicator=indicator, ge_indicator=indicator)

    assert fresh_ts.is_ok, fresh_ts.error
    assert fresh_ts.get_output("ex_chart").status == "ok"
    assert fresh_ts.get_output("ge_bars").status == "ok"
    assert fresh_ts.get_output("ge_map").status == "ok"

    cells = dict(grid(fresh_ts, "ex_values")[1])
    assert cells["Cacheu"] == "650,000"
    assert cells["Bafatá"] == data.EMPTY_DISPLAY  # missing, not 0
    assert "No value is recorded for 7 of 9 regions" in html(fresh_ts, "ex_values_note")

    # The session is still usable afterwards -- the NaN did not poison it.
    fresh_ts.set_inputs(ex_indicator=RATE_420)
    assert fresh_ts.get_output("ex_values").status == "ok"


# --------------------------------------------------------------------------
# Gate 7: sweeps. Slow (~80s together); deselect with -k "not sweep".
# --------------------------------------------------------------------------


def test_sweep_every_country_line_breakdown_and_geography_renders(fresh_ts):
    """2 countries x 2 poverty lines x 3 geography levels x 5 breakdowns.

    Every widget on every page is live, so this is also the broad regression
    test for a NaN reaching a Plotly trace. Only the input that changes is
    re-sent: `set_inputs` forces a re-render of everything downstream of every
    id it is given, so re-sending all four would make each step a full redraw.
    """
    combinations = 0
    for country in data.COUNTRIES:
        fresh_ts.set_inputs(country=country)
        for line in data.POVERTY_LINES:
            fresh_ts.set_inputs(povline=line)
            for level in data.GEO_LEVELS:
                fresh_ts.set_inputs(geo_level=level)
                for breakdown in data.BREAKDOWNS:
                    fresh_ts.set_inputs(breakdown=breakdown)
                    combinations += 1
                    assert fresh_ts.is_ok, (
                        f"{country}/{line}/{level}/{breakdown}: {fresh_ts.error}"
                    )
    assert combinations == 60


def _cuts_with_missing_values():
    """Every (country, level, indicator) whose place-level cut carries a NaN.

    Computed from the workbooks rather than listed, so a workbook that grows a
    new hole is swept too. 13 ADM 1 cuts and 6 ZAE cuts today.
    """
    readers = {"adm1": data.region_table, "zae": data.zone_table}
    return [
        (iso3, level, indicator)
        for iso3 in data.COUNTRIES
        for level, reader in readers.items()
        for indicator in data.indicators(iso3)
        if reader(iso3, indicator)["value"].isna().any()
    ]


def test_sweep_every_cut_with_a_missing_value_survives_the_serialiser(fresh_ts):
    """The NaN regression, over every cut that can trigger it.

    shinywidgets serialises a widget with `allow_nan=False`, so one NaN in a
    trace ends the session rather than erroring one output. The panels pass
    `None` (JSON null) instead, which draws no bar and keeps the category.
    """
    cuts = _cuts_with_missing_values()
    assert len(cuts) == 19, "the workbooks' missing cells moved; re-read the sweep"

    previous = (None, None)
    for iso3, level, indicator in sorted(cuts, key=lambda cut: (cut[1], cut[0])):
        # One flush per cut, carrying only what changed: re-sending an
        # unchanged country would redraw the Overview map for nothing.
        step = {"ex_indicator": indicator, "ge_indicator": indicator}
        if (iso3, level) != previous:
            step.update(country=iso3, geo_level=level)
            previous = (iso3, level)
        fresh_ts.set_inputs(**step)
        where = f"{iso3}/{level}/{indicator}"
        assert fresh_ts.is_ok, f"{where}: {fresh_ts.error}"
        assert fresh_ts.get_output("ex_chart").status == "ok", where
        assert fresh_ts.get_output("ge_bars").status == "ok", where
        if level == "adm1":
            assert fresh_ts.get_output("ge_map").status == "ok", where


def test_sweep_every_indicator_on_explore_carries_the_right_unit(fresh_ts):
    """All 97 indicators (plan 9.2) for both countries, on the page where the
    units bite: the column header names the unit and no level indicator is ever
    shown as a percentage."""
    show(fresh_ts, "Explore")
    checked = 0
    for country in data.COUNTRIES:
        fresh_ts.set_inputs(country=country)
        for indicator in data.indicators(country):
            fresh_ts.set_inputs(ex_indicator=indicator)
            checked += 1
            assert fresh_ts.is_ok, f"{country}/{indicator}: {fresh_ts.error}"
            assert fresh_ts.get_output("ex_chart").status == "ok"

            values = fresh_ts.get_output("ex_values")
            # "silent" is `wood_dist [ALL MISSING]`, which has nothing to show.
            assert values.status in {"ok", "silent"}, f"{country}/{indicator}"
            if values.status != "ok":
                continue
            payload = values.value["payload"]
            assert payload["columns"][1] == f"Value ({data.unit_label(indicator)})"
            if indicator in data.LEVEL_FORMATS:
                cells = [row[1] for row in payload["data"]]
                assert not any("%" in cell for cell in cells), (
                    f"{country}/{indicator} formatted a level as a share: {cells}"
                )
    assert checked == 2 * 97


# --------------------------------------------------------------------------
# Gate 8: downloads (plan 9.1 #10 -- ~114 KB of base64 per country, inlined)
# --------------------------------------------------------------------------


def test_the_download_handlers_serve_the_selected_countrys_workbook(ts):
    senegal = {name: download(ts, name) for name in ("dl_workbook", "ab_dl_workbook")}
    ts.set_inputs(country="GNB")
    bissau = {name: download(ts, name) for name in ("dl_workbook", "ab_dl_workbook")}

    for name in ("dl_workbook", "ab_dl_workbook"):
        sen_filename, sen_bytes = senegal[name]
        gnb_filename, gnb_bytes = bissau[name]
        assert sen_filename == "AFW360_Tables_SEN.xlsx"
        assert gnb_filename == "AFW360_Tables_GNB.xlsx"
        for payload in (sen_bytes, gnb_bytes):
            assert payload[:2] == b"PK"  # xlsx is a zip container
            assert len(payload) > 10_000
        assert sen_bytes != gnb_bytes  # the defect this whole file is about
        assert sen_bytes == data.workbook_bytes("SEN")
        assert gnb_bytes == data.workbook_bytes("GNB")


# --------------------------------------------------------------------------
# Gate 9: one name per place, on every page
# --------------------------------------------------------------------------


def test_every_page_calls_a_region_by_the_same_name():
    """A region must not be `DAKAR` on one tab and `Dakar` on the next.

    There are two candidate spellings and neither source wins outright: the
    workbook column shouts Senegal's names and calls the capital `SAB`, while
    the shapefile is properly cased and carries Senegal's accents but drops
    Guinea-Bissau's. `data.region_labels()` resolves the two, and every page
    reads its labels from there.
    """
    import panels_geography as geography

    rate = data.POVERTY_LINES["420"].rate_indicator
    for iso3 in ("SEN", "GNB"):
        resolved = data.region_labels(iso3)
        from_data = list(data.region_table(iso3, rate)["region"])
        from_geography = list(geography.place_values(iso3, rate, "adm1")["label"])
        assert from_data == from_geography, f"{iso3}: Geography disagrees with data.py"
        assert set(from_data) == set(resolved.values())

    senegal = data.region_labels("SEN")
    assert senegal["DAKAR"] == "Dakar"  # not the workbook's block capitals
    assert senegal["KEDOUGOU"] == "Kédougou"  # the shapefile keeps the accent
    assert senegal["SAINT_LOUIS"] == "Saint-Louis"

    bissau = data.region_labels("GNB")
    assert bissau["SAB"] == "Bissau"  # plan 6.1: never the raw column name
    assert bissau["BAFATA"] == "Bafatá"  # the workbook keeps this accent
    assert bissau["GABU"] == "Gabú"

    # No page may ever show the raw workbook spellings again.
    for iso3 in ("SEN", "GNB"):
        shown = set(data.region_labels(iso3).values())
        assert "SAB" not in shown
        assert not any(name.isupper() and len(name) > 3 for name in shown)
