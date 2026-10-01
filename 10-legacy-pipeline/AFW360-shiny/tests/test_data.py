"""Acceptance tests for the data layer (plan section 12, Phase 1).

Every assertion here corresponds to a defect verified in the old Quarto page.
The ground-truth numbers were read from the real workbooks; if the code and the
numbers disagree, the code is wrong.

The console this runs on is cp1252, so indicator labels carrying U+2013 or
U+2265 must not be printed without `PYTHONIOENCODING=utf-8`. Comparisons are on
values, not on printed output.
"""

import math
import sys
from pathlib import Path

import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import data  # noqa: E402

# The seven Welfare rows from `indicator_map_Welfare` (index.qmd:69-77), in
# `row_order_Welfare` order. Raw SEN National estimateTotal:
# [0.45, 0.04, 0.38, 0.55, 0.3, 0.25, 0.45].
WELFARE = [
    "Food consumption share",
    "Own-production food share (% total cons.)",
    "Market food share (% total cons.)",
    "Non-food consumption share",
    "Employed in agriculture (% of employed)",
    "Employed in industry (% of employed)",
    "Employed in services (% of employed)",
]


# -- Gate 1: no .round(1) ---------------------------------------------------


def test_welfare_total_formats_without_precision_loss():
    """The old page's .round(1) turned 0.45 into 40%. It must read 45%."""
    df = data.table("SEN", WELFARE, "total")
    assert list(df["Total"]) == [0.45, 0.04, 0.38, 0.55, 0.3, 0.25, 0.45]

    formatted = data.fmt_table(df)
    assert list(formatted["Total"]) == [
        "45%",
        "4%",
        "38%",
        "55%",
        "30%",
        "25%",
        "45%",
    ]


def test_welfare_display_labels_and_row_order_come_from_the_map():
    """A dict argument renames and fixes row order; the source labels survive."""
    labels = {
        "Food consumption share": "Food consumption share",
        "Own-production food share (% total cons.)": "Own-production food consumption",
        "Market food share (% total cons.)": "Market food consumption",
        "Non-food consumption share": "Non-food consumption share",
        "Employed in agriculture (% of employed)": "Share employed in agriculture",
        "Employed in industry (% of employed)": "Share employed in industry",
        "Employed in services (% of employed)": "Share employed in services",
    }
    df = data.table("SEN", labels, "total")
    assert list(df.index) == list(labels.values())
    assert df.index.name == "Indicator"
    assert df.attrs["source_indicators"]["Market food consumption"] == (
        "Market food share (% total cons.)"
    )
    assert list(data.fmt_table(df)["Total"])[0] == "45%"


# -- Gate 2: counts are not percentages -------------------------------------


def test_count_indicator_is_not_formatted_as_a_percentage():
    """`{:.0%}` on 6.52 gave `650%`. It must read `6.52`."""
    assert data.fmt("Number poor $4.20/day (millions)", 6.5200000000000005) == "6.52"


def test_every_level_indicator_has_its_own_unit():
    assert len(data.LEVEL_FORMATS) == 15
    catalogue = data.catalogue()
    levels = catalogue.loc[catalogue["unit"] != "share", "indicator"]
    assert set(levels) == set(data.LEVEL_FORMATS)
    # ... and each of the 15 really is in the workbook, spelled exactly so.
    assert set(data.LEVEL_FORMATS) <= set(data.indicators("SEN"))
    assert set(data.LEVEL_FORMATS) <= set(data.indicators("GNB"))


# -- Gate 3: Guinea-Bissau reads Guinea-Bissau ------------------------------


def test_each_country_reads_its_own_workbook():
    """The old page never reassigned `file_path`, so GNB showed SEN's numbers."""
    assert data.value("GNB", "Poor at $4.20/day (2021 PPP)") == 0.62
    assert data.value("SEN", "Poor at $4.20/day (2021 PPP)") == 0.37
    assert data.value("GNB", "Number poor $4.20/day (millions)") == 1.09
    assert data.value("SEN", "Number poor $4.20/day (millions)") == pytest.approx(6.52)


def test_workbook_shapes_match_the_data_contract():
    assert {k: v.shape for k, v in data.WORKBOOKS["SEN"].items()} == {
        "National": (97, 14),
        "Departement": (82, 15),
        "ZAE": (97, 7),
        "ADM 1": (97, 15),
    }
    assert {k: v.shape for k, v in data.WORKBOOKS["GNB"].items()} == {
        "National": (97, 14),
        "ZAE": (97, 5),
        "ADM 1": (97, 10),
    }
    # Departement is deliberately unreachable: 2017 PPP, region-keyed despite
    # its name, disagrees with ADM 1 on 54 of 60 shared rows (plan 10.3).
    assert "Departement" not in data.GEO_LEVELS.values()


# -- Gate 4: all 97 labels, read from the workbook ---------------------------


def test_ninety_seven_indicators_in_both_countries_in_the_same_order():
    sen = data.indicators("SEN")
    gnb = data.indicators("GNB")
    assert len(sen) == 97
    assert sen == gnb
    assert len(set(sen)) == 97


@pytest.mark.parametrize(
    "label",
    [
        "Employed (activ12m, 15–64)",  # en dash U+2013
        "Safe drinking water – dry season",  # en dash U+2013
        "≥1 HH member has health coverage (proxy social protection)",  # U+2265
    ],
)
def test_exact_unicode_labels_match(label):
    """Exact string matching, including en dash and >=."""
    assert label in data.indicators("SEN")
    assert label in data.indicators("GNB")


def test_catalogue_covers_every_indicator_once():
    catalogue = data.catalogue()
    assert list(catalogue["indicator"]) == data.indicators("SEN")
    assert set(catalogue.columns) == {"indicator", "theme", "unit", "flag"}
    # Only `wood_dist [ALL MISSING]` falls outside the coarse themes.
    assert list(catalogue.loc[catalogue["theme"] == "Other", "indicator"]) == [
        "wood_dist [ALL MISSING]"
    ]
    flagged = set(catalogue.loc[catalogue["flag"] != "", "indicator"])
    assert flagged == set(data.DATA_FLAGS)


# -- Gate 5: the ADM1 join ---------------------------------------------------


def test_region_table_shapes_and_join_keys():
    gnb = data.region_table("GNB", "Poor at $4.20/day (2021 PPP)")
    assert len(gnb) == 9
    assert "SAB" in set(gnb["join_key"])
    assert set(gnb["join_key"]) == {
        "BAFATA",
        "BIOMBO",
        "BOLAMA_BIJAGOS",
        "CACHEU",
        "GABU",
        "OIO",
        "QUINARA",
        "SAB",
        "TOMBALI",
    }

    sen = data.region_table("SEN", "Poor at $4.20/day (2021 PPP)")
    assert len(sen) == 14
    assert "DAKAR" in set(sen["join_key"])
    assert "SAINT_LOUIS" in set(sen["join_key"])
    assert list(sen.columns) == ["join_key", "region", "value"]
    assert sen["value"].notna().all()


def test_normalise_region_folds_both_sides_of_the_join_identically():
    # Workbook column, shapefile spelling and a spaced variant must agree.
    assert (
        data.normalise_region("estimateBolama_Bijagós")
        == data.normalise_region("Bolama/Bijagós")
        == data.normalise_region("Bolama Bijagos")
        == "BOLAMA_BIJAGOS"
    )
    assert (
        data.normalise_region("estimateSAINT_LOUIS")
        == data.normalise_region("Saint-Louis")
        == "SAINT_LOUIS"
    )
    assert data.normalise_region("estimateGabú") == "GABU"
    assert data.normalise_region("estimateSAB") == "SAB"
    # The shapefile calls GNB's capital Bissau; the alias lives in the GeoJSON
    # build, not here, so folding alone does not reconcile them.
    assert data.normalise_region("Bissau") == "BISSAU"


def test_zone_table_presents_truncated_zone_names_as_they_are():
    sen = data.zone_table("SEN", "Poor at $4.20/day (2021 PPP)")
    assert len(sen) == 6
    assert list(sen.columns) == ["region", "value"]
    assert "Ziguinchor Tamba Kolda S" in list(sen["region"])  # truncated at source
    assert len(data.zone_table("GNB", "Poor at $4.20/day (2021 PPP)")) == 4


# -- Gate 6: empty is not zero, and fmt() never raises -----------------------


@pytest.mark.parametrize(
    "v", [None, float("nan"), pd.NA, "n/a", "", float("inf"), float("-inf")]
)
def test_fmt_returns_the_en_dash_for_anything_unusable(v):
    assert data.fmt("Food consumption share", v) == data.EMPTY_DISPLAY
    assert data.EMPTY_DISPLAY == "–"


@pytest.mark.parametrize(
    "v", [None, [1, 2], {"a": 1}, object(), pd.Series([1.0, 2.0]), b"x"]
)
def test_fmt_never_raises(v):
    assert isinstance(data.fmt("Cultivated area (ha)", v), str)
    assert isinstance(data.fmt("no such indicator", v), str)


def test_missing_values_render_as_the_en_dash_not_zero():
    """`wood_dist [ALL MISSING]` is empty everywhere; it must not show 0%."""
    assert data.value("SEN", "wood_dist [ALL MISSING]") is None
    df = data.table("SEN", ["wood_dist [ALL MISSING]"], "quintile")
    assert df.isna().all().all()
    assert set(data.fmt_table(df).to_numpy().ravel()) == {data.EMPTY_DISPLAY}


def test_a_drifted_label_gives_a_blank_row_not_a_keyerror():
    """`.loc[row_order]` used to abort the entire render (plan 9.1 #7)."""
    df = data.table(
        "SEN",
        {"Food consumption share": "Food", "Renamed upstream": "Missing row"},
        "total",
    )
    assert list(df.index) == ["Food", "Missing row"]
    assert df.at["Food", "Total"] == 0.45
    assert math.isnan(df.at["Missing row", "Total"])
    assert list(data.fmt_table(df)["Total"]) == ["45%", data.EMPTY_DISPLAY]


# -- Gate 7: negative levels keep their sign ---------------------------------


def test_negative_fcfa_keeps_its_sign_and_thousands_separator():
    """SEN TAMBACOUNDA `HE profits (FCFA)` is -3,460.34. Not an absolute value."""
    v = data.value("SEN", "HE profits (FCFA)", "estimateTAMBACOUNDA", level="adm1")
    assert v == pytest.approx(-3460.34)
    assert data.fmt("HE profits (FCFA)", v) == "-3,460"


@pytest.mark.parametrize(
    ("indicator", "value_in", "expected"),
    [
        ("HE capital stock (FCFA)", 9165015.0, "9,165,015"),
        ("HE age (years)", 12.34, "12.3"),
        ("Cultivated area (ha)", 148_400_000.0, "148,400,000.0"),
        ("Tropical Livestock Units (TLU)", 2.5, "2.5"),
        ("Average outage duration (code)", 3.0, "3"),
        ("Days with an outage (last 7)", 2.25, "2.2"),
        ("Number poor $3.00/day (millions)", 1.0, "1.00"),
        ("Poor at $4.20/day (2021 PPP)", 0.37, "37%"),
    ],
)
def test_unit_formats(indicator, value_in, expected):
    assert data.fmt(indicator, value_in) == expected


# -- Supporting contract checks ---------------------------------------------


def test_constants_match_the_interface_contract():
    assert list(data.COUNTRIES) == ["SEN", "GNB"]
    assert list(data.GEO_LEVELS) == ["national", "adm1", "zae"]
    assert list(data.POVERTY_LINES) == ["420", "300"]  # $4.20 is the default
    assert data.POVERTY_LINES["420"].rate_indicator in data.indicators("SEN")
    assert data.POVERTY_LINES["300"].count_indicator in data.indicators("GNB")
    assert list(data.BREAKDOWNS) == ["total", "residence", "sex", "age", "quintile"]
    assert data.BREAKDOWNS["age"].columns["estimateOlder_HH"] == "29+"  # plan 11.3


def test_every_breakdown_column_exists_in_both_national_sheets():
    for iso3 in data.COUNTRIES:
        columns = set(data.sheet(iso3, "national").columns)
        for breakdown in data.BREAKDOWNS.values():
            assert set(breakdown.columns) <= columns


def test_sheet_returns_a_copy_so_callers_cannot_poison_the_cache():
    first = data.sheet("SEN", "national")
    first.loc[:, "estimateTotal"] = 0.0
    assert data.value("SEN", "Poor at $4.20/day (2021 PPP)") == 0.37


def test_capital_flag_is_country_level_not_indicator_level():
    assert data.CAPITAL_FLAG_ISO3 == "GNB"
    assert data.CAPITAL_FLAG_TEXT
    assert "estimateCapital" not in data.DATA_FLAGS


def test_about_text_reads_the_country_file_and_does_not_invent_prose():
    assert "EHCVM" in data.about_text("SEN")
    assert data.about_text("GNB") == "TEXT"  # stub upstream (plan 11.2)
    assert data.about_text("XXX") == ""


def test_workbook_bytes_are_a_real_xlsx():
    for iso3 in data.COUNTRIES:
        raw = data.workbook_bytes(iso3)
        assert raw[:2] == b"PK"  # xlsx is a zip container
        assert len(raw) > 10_000
