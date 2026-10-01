import math

import geopandas as gpd
import pytest

from afw360 import loader
from afw360.format import format_value

PL420_HC = "POV_HC.POVLINE_PL420.PPP_2021"
PL420_NUM = "POV_NUM.POVLINE_PL420.PPP_2021"


@pytest.fixture(scope="module")
def data():
    return {"SEN": loader.load_data("SEN"), "GNB": loader.load_data("GNB")}


def test_sen_shape(data):
    assert data["SEN"].shape == (3003, 34)
    assert not set(loader.FIXED_COLUMNS) & set(data["SEN"].columns)


def test_gnb_shape(data):
    assert data["GNB"].shape == (2268, 34)


def test_measures_are_float(data):
    for col in loader.NUMERIC_COLUMNS:
        assert data["SEN"][col].dtype == "float64", col


def test_structure_id_mismatch_raises(tmp_path):
    src = loader.data_path("SEN")
    text = src.read_text(encoding="utf-8").replace("AFW360_HH(0.3.0)", "AFW360_HH(9.9.9)")
    bad = tmp_path / src.name
    bad.write_text(text, encoding="utf-8")
    with pytest.raises(ValueError, match="STRUCTURE_ID"):
        loader.load_data("SEN", path=bad)


@pytest.mark.parametrize("iso3", ["SEN", "GNB"])
def test_nan_rows_are_status_o_or_m(data, iso3):
    df = data[iso3]
    assert (df["OBS_VALUE"].isna() == df["OBS_STATUS"].isin(["O", "M"])).all()


def test_gnb_has_omitted_rows(data):
    assert data["GNB"]["OBS_VALUE"].isna().sum() == 39
    assert data["SEN"]["OBS_VALUE"].isna().sum() == 0


@pytest.mark.parametrize("iso3,hc,num", [("SEN", 0.37, 6520000), ("GNB", 0.62, 1090000)])
def test_poverty_series(data, iso3, hc, num):
    df = data[iso3]
    # The plan's call (GEO and SEX only) also returns the URBANISATION and
    # COMP_BREAKDOWN_1 disaggregations; the national total is the all-_T row.
    for sid, expected in [(PL420_HC, hc), (PL420_NUM, num)]:
        r = loader.series(df, sid, GEO="_T", SEX="_T")
        assert len(r) > 1
        total = loader.series(df, sid, GEO="_T", SEX="_T", URBANISATION="_T", COMP_BREAKDOWN_1="_T")
        assert len(total) == 1 and math.isclose(total["OBS_VALUE"].iloc[0], expected)
        assert r["OBS_VALUE"].apply(lambda v: math.isclose(v, expected)).any()


def test_format_value():
    assert format_value(0.373, "PERCENT", 1) == "37.3%"
    assert format_value(6520000, "MILLIONS", 2) == "6.52"
    assert format_value(float("nan"), "PERCENT", 1) == ""


def test_indicator_meta_drives_format(data):
    rule = loader.load_indicator_meta().loc["POV_NUM"]
    v = loader.series(data["SEN"], PL420_NUM, GEO="_T", URBANISATION="_T", COMP_BREAKDOWN_1="_T")["OBS_VALUE"].iloc[0]
    assert format_value(v, rule["display_as"], rule["decimals"]) == "6.52"


def test_boundaries_have_geo():
    gdf = loader.load_boundaries("SEN", "adm1")
    assert isinstance(gdf, gpd.GeoDataFrame)
    assert "GEO" in gdf.columns and len(gdf) > 0


def test_codelist_plan_text_figures():
    assert "code" in loader.load_codelist("GEO").columns
    assert len(loader.load_series_plan()) > 0
    msgs = loader.load_text("SEN", "messages")
    assert list(msgs["order"]) == [1, 2, 3]
    assert loader.load_text("SEN", "about")["body"].iloc[0] != ""
    assert loader.load_figures("SEN")["path"].iloc[0].endswith("SEN_FISCAL_EQUITY.png")
