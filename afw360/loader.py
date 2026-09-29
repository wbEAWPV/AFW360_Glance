"""Single data-access layer for the dashboard.

Every input the dashboard shows (observations, codelists, the series plan,
indicator display rules, text, figures, boundaries) is read here, so a later
change of data source touches this module only. Uses pandas and geopandas.

The observation files are SDMX-CSV 2.1 (``data/AFW360_HH_<ISO3>_<YEAR>_<EST>.csv``).
Every column is read as text first (``keep_default_na=False``) so that codes
such as ``NA`` stay codes; numeric columns are then parsed explicitly, where the
literal ``NaN`` (intentionally missing, OBS_STATUS O or M) and an empty cell
(optional measure not available) become missing floats.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import pandas as pd

ROOT = Path(os.environ.get("AFW360_ROOT", Path(__file__).resolve().parents[1]))

FIXED_COLUMNS = ["STRUCTURE", "STRUCTURE_ID", "ACTION"]
DATAFLOW = "WB.AFW360:AFW360_HH"
NUMERIC_COLUMNS = [
    "OBS_VALUE", "STD_ERR", "CI_LOWER", "CI_UPPER", "N_OBS", "N_POP",
    "N_OBS_NUM", "DEFF", "DF", "PRECISION",
]
MISSING_STATUSES = ("O", "M")


def _root(root=None) -> Path:
    return Path(root) if root is not None else ROOT


def _read_text_csv(path: Path) -> pd.DataFrame:
    return pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8")


def _to_float(col: pd.Series, name: str) -> pd.Series:
    """Parse a text column to float: '' and 'NaN' are missing, anything else must be a number."""
    s = col.str.strip()
    missing = s.isin(["", "NaN"])
    out = pd.to_numeric(s.where(~missing), errors="coerce").astype("float64")
    bad = out.isna() & ~missing
    if bad.any():
        raise ValueError(f"{name}: non-numeric values {sorted(s[bad].unique())[:5]}")
    return out


def expected_structure_id(root=None) -> str:
    """``WB.AFW360:AFW360_HH(<metadata/VERSION>)``."""
    version = (_root(root) / "metadata" / "VERSION").read_text(encoding="utf-8").strip()
    return f"{DATAFLOW}({version})"


def data_path(iso3: str, year=None, estimation: str = "SURVEY", root=None) -> Path:
    """Path of the observation file; ``year=None`` picks the latest year available."""
    iso3 = iso3.upper()
    folder = _root(root) / "data"
    if year is not None:
        path = folder / f"AFW360_HH_{iso3}_{year}_{estimation}.csv"
        if not path.exists():
            raise FileNotFoundError(path)
        return path
    pat = re.compile(rf"AFW360_HH_{iso3}_(\d{{4}})_{re.escape(estimation)}\.csv$")
    found = []
    for p in folder.glob(f"AFW360_HH_{iso3}_*_{estimation}.csv"):
        m = pat.match(p.name)
        if m:
            found.append((m.group(1), p))
    if not found:
        raise FileNotFoundError(f"no data file for {iso3} / {estimation} in {folder}")
    return sorted(found)[-1][1]


def load_data(iso3: str, year=None, estimation: str = "SURVEY", root=None, path=None) -> pd.DataFrame:
    """Observations of one country as a DataFrame (34 columns).

    Checks every row's ``STRUCTURE_ID`` against ``metadata/VERSION`` and raises
    ``ValueError`` on a mismatch; drops the three SDMX-CSV fixed columns;
    returns the measures and ``PRECISION`` as floats, everything else as text.
    ``path`` overrides the file location (used by tests).
    """
    path = Path(path) if path is not None else data_path(iso3, year, estimation, root)
    df = _read_text_csv(path)
    needed = FIXED_COLUMNS + ["OBS_VALUE", "OBS_STATUS", "SERIES_ID"]
    missing_cols = [c for c in needed if c not in df]
    if missing_cols:
        raise ValueError(f"{path.name}: missing columns {missing_cols}")
    expected = expected_structure_id(root)
    wrong = sorted(set(df["STRUCTURE_ID"]) - {expected})
    if wrong:
        raise ValueError(
            f"{path.name}: STRUCTURE_ID {wrong} does not match {expected} (metadata/VERSION)"
        )
    df = df.drop(columns=FIXED_COLUMNS)
    for col in NUMERIC_COLUMNS:
        if col in df:
            df[col] = _to_float(df[col], col)
    return df.reset_index(drop=True)


def series(df: pd.DataFrame, series_id: str, **dims) -> pd.DataFrame:
    """Rows of ``series_id`` whose dimension columns equal the given codes.

    Example: ``series(df, "POV_HC.POVLINE_PL420.PPP_2021", GEO="_T", SEX="_T")``.
    A list, tuple or set value selects any of several codes.
    """
    mask = df["SERIES_ID"] == series_id
    for dim, code in dims.items():
        if dim not in df:
            raise KeyError(f"unknown dimension {dim!r}")
        if isinstance(code, (list, tuple, set)):
            mask &= df[dim].isin([str(c) for c in code])
        else:
            mask &= df[dim] == str(code)
    return df.loc[mask].reset_index(drop=True)


def load_codelist(name: str, root=None) -> pd.DataFrame:
    """A codelist from ``metadata/codelists``; ``name`` is ``CL_GEO`` or ``GEO``."""
    name = name.upper()
    if not name.startswith("CL_"):
        name = f"CL_{name}"
    return _read_text_csv(_root(root) / "metadata" / "codelists" / f"{name}.csv")


def load_series_plan(root=None) -> pd.DataFrame:
    """``metadata/plans/SERIES_PLAN.csv`` (one row per series id)."""
    return _read_text_csv(_root(root) / "metadata" / "plans" / "SERIES_PLAN.csv")


def load_indicator_meta(root=None) -> pd.DataFrame:
    """Display rules indexed by indicator code.

    Columns: ``display_as``, ``decimals`` (int), ``higher_is``, ``short_name_en``,
    ``name_en``, ``unit_measure``.
    """
    cl = load_codelist("CL_INDICATOR", root)
    cols = ["code", "display_as", "decimals", "higher_is", "short_name_en", "name_en", "unit_measure"]
    meta = cl[cols].copy()
    meta["decimals"] = pd.to_numeric(meta["decimals"].replace("", "0")).astype(int)
    return meta.set_index("code")


def load_text(iso3: str, slot: str, time_period=None, root=None) -> pd.DataFrame:
    """Text blocks of one country and slot (``about``, ``messages``) in display order.

    Columns include ``title`` and ``body``; when a row names a ``file``
    (relative to ``content/text``), ``body`` holds that file's content.
    """
    base = _root(root) / "content"
    text = _read_text_csv(base / "TEXT.csv")
    rows = text[(text["ref_area"] == iso3.upper()) & (text["slot"] == slot)].copy()
    if time_period is not None:
        rows = rows[rows["time_period"] == str(time_period)]
    rows["order"] = pd.to_numeric(rows["order"])
    rows = rows.sort_values("order").reset_index(drop=True)
    for i, f in rows["file"].items():
        if f:
            rows.at[i, "body"] = (base / "text" / f).read_text(encoding="utf-8")
    return rows


def load_figures(iso3: str, root=None) -> pd.DataFrame:
    """Figure registry rows of one country, with ``path`` resolved under ``assets/figures``."""
    root = _root(root)
    reg = _read_text_csv(root / "metadata" / "registries" / "FIGURES.csv")
    rows = reg[reg["ref_area"] == iso3.upper()].reset_index(drop=True)
    rows["path"] = [str(root / "assets" / "figures" / f) if f else "" for f in rows["file"]]
    return rows


def load_boundaries(iso3: str, layer: str = "adm1", root=None):
    """Boundary layer (``adm0``, ``adm1``) of ``geo/boundaries/<ISO3>_CODAB_*.gpkg``.

    Returns a GeoDataFrame whose ``GEO`` column holds CL_GEO codes (the
    GeoPackage's ``geo_code``), ready to join on the data's ``GEO``.
    """
    import geopandas as gpd

    folder = _root(root) / "geo" / "boundaries"
    files = sorted(folder.glob(f"{iso3.upper()}_CODAB_*.gpkg"))
    if not files:
        raise FileNotFoundError(f"no GeoPackage for {iso3} in {folder}")
    gdf = gpd.read_file(files[-1], layer=layer)
    if "GEO" not in gdf.columns and "geo_code" in gdf.columns:
        gdf = gdf.rename(columns={"geo_code": "GEO"})
    return gdf
