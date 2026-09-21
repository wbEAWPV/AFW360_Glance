#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Build the ADM1 GeoJSON the Shiny app renders, from the source shapefiles.

    dev machine:  INPUT shp/{sen,gnb}_admin1.shp  --[this script, geopandas]-->
                  geo/adm1_{sen,gnb}.json  --[committed]--> the app (stdlib json only)

**This script is DEV-ONLY and is run by hand.** Its output is committed. The app
never runs it and never imports geopandas: `geopandas`/GDAL/GEOS/PROJ must NOT go
into `requirements.txt`. They are not installed on Posit Connect and never will be.
Keeping them out is the whole point of pre-converting, and it is what makes a static
Shinylive build possible. See .docs/shiny-port-plan.md section 6.

Usage (from the repo root, with the project venv)::

    .venv/Scripts/python.exe scripts/build_geojson.py            # build, then verify
    .venv/Scripts/python.exe scripts/build_geojson.py --check    # verify only, no writes
    .venv/Scripts/python.exe scripts/build_geojson.py --country GNB
    .venv/Scripts/python.exe scripts/build_geojson.py --tolerance 750

`--check` needs only pandas + openpyxl (no geopandas), so the join can be re-verified
anywhere. Building is idempotent: the output is canonicalised and sorted, so a re-run
with the same inputs and tolerance rewrites byte-identical files.

Windows note: the console is cp1252 and region names contain 'á'/'ú'/'é'. Run with
``PYTHONIOENCODING=utf-8`` or the script's own stdout reconfiguration (below) will
handle it. Output files are always written as UTF-8.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHP_DIR = ROOT / "INPUT shp"
TABLE_DIR = ROOT / "INPUT Tables"
GEO_DIR = ROOT / "geo"

# Keep the console from dying on Bafatá / Gabú / Kédougou under cp1252.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:  # pragma: no cover - older/odd stream objects
        pass


# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #

# Simplification tolerance in METRES, applied in EPSG:32628 (UTM zone 28N, which
# covers both countries). 500 m was chosen empirically:
#
#   tol     SEN verts / size     GNB verts / size    area error   overlaps  adjacency
#   250 m   3251 / 137 KB*       --                  +0.015%      0         intact
#   500 m   2045 /  44 KB        1360 / 29 KB        +0.06/-0.20% 0         intact
#   750 m   1526 /  33 KB        1095 / 24 KB        +0.04/-0.29% 0         intact
#  1000 m   1274 /  28 KB         924 / 20 KB        +0.06/-0.33% 0         intact
#  1250 m   -- loses a whole SEN polygon --
#
#   (*137 KB was measured before coordinate rounding was applied.)
#
# 500 m is comfortably under the ~1 km/px scale at which these maps are drawn in a
# dashboard card, keeps the coastline and the Gambia enclave recognisable, and still
# lands both files at well under half the 100 KB budget. 1250 m is past the cliff.
DEFAULT_TOLERANCE_M = 500.0

# Projected CRS used for simplification only. Output is always EPSG:4326.
WORK_CRS = "EPSG:32628"
OUT_CRS = "EPSG:4326"

# Coordinate decimals in the written file. 5 dp ~= 1.1 m, i.e. ~500x finer than the
# simplification tolerance, so rounding contributes nothing to the shape error while
# capping the cost of each coordinate at ~9 characters.
COORD_DECIMALS = 5

# The ONLY properties that survive into the output. The shapefiles carry 21 attribute
# columns; the rest are pcodes of other levels, validity dates, areas, and repeated
# name/lang slots that are all None. They bloat the file and nothing reads them.
KEEP_PROPERTIES = ("join_key", "region", "adm1_pcode")

# Join-key aliases, keyed by ISO3 then by the NORMALISED shapefile region name.
#
# GNB: the `ADM 1` sheet labels the capital `estimateSAB` -- Setor Autónomo de Bissau
# -- while gnb_admin1.shp calls the polygon `Bissau`. Normalising both gives `SAB` and
# `BISSAU`, which do not join: 8 of 9 regions match and the capital silently renders
# as a grey polygon annotated `nan%` (plan section 6.1 / 9.4). Aliasing the geometry
# side to the workbook's key fixes it for every indicator at once. `region` is left
# alone, so hover still reads "Bissau".
#
# SEN needs no aliases: 14/14 join as-is.
JOIN_ALIASES: dict[str, dict[str, str]] = {
    "SEN": {},
    "GNB": {"BISSAU": "SAB"},
}

# Per-country config. NOTE the two attribute-table divergences recorded in plan
# section 9.4 -- the shapefiles are NOT schema-identical across countries:
#   * version field: SEN `version` ("v02") vs GNB `cod_versio` ("V_01")
#   * `lang`:        SEN "fr" vs GNB "en"
# Only `adm1_name` and `adm1_pcode` are read, so neither divergence affects the build;
# `version_field` exists so the provenance line printed below is correct per country.
COUNTRIES: dict[str, dict] = {
    "SEN": {
        "name": "Senegal",
        "shapefile": SHP_DIR / "sen_admin1.shp",
        "workbook": TABLE_DIR / "Tables_SEN.xlsx",
        "output": GEO_DIR / "adm1_sen.json",
        "expected_features": 14,
        "version_field": "version",
        # Generous envelope for the sanity check; the real bbox sits inside it.
        "lon_range": (-17.6, -11.3),
        "lat_range": (12.3, 16.7),
    },
    "GNB": {
        "name": "Guinea-Bissau",
        "shapefile": SHP_DIR / "gnb_admin1.shp",
        "workbook": TABLE_DIR / "Tables_GNB.xlsx",
        "output": GEO_DIR / "adm1_gnb.json",
        "expected_features": 9,
        "version_field": "cod_versio",
        "lon_range": (-16.8, -13.6),
        "lat_range": (10.8, 12.7),
    },
}

ADM1_SHEET = "ADM 1"
SIZE_BUDGET_BYTES = 100 * 1024


# --------------------------------------------------------------------------- #
# The join key -- ONE implementation, shared with data.py
# --------------------------------------------------------------------------- #

def _fallback_normalise_region(name) -> str:
    """Local copy of `data.normalise_region`. Used ONLY if data.py cannot be imported.

    Strip a leading "estimate", ASCII-fold accents, uppercase, collapse every run of
    non-alphanumerics to a single "_", and trim leading/trailing "_".

        estimateBolama_Bijagós -> BOLAMA_BIJAGOS      Bolama/Bijagos -> BOLAMA_BIJAGOS
        estimateSAINT_LOUIS    -> SAINT_LOUIS         Saint-Louis    -> SAINT_LOUIS
        estimateGabú           -> GABU                Gabu           -> GABU

    This differs deliberately from `clean_region_name()` in index.qmd:365, which maps
    separators to SPACES ("BOLAMA BIJAGOS"). Underscores are the documented contract
    (see the geo contract) and match the workbook's own `estimateSAINT_LOUIS` spelling.
    """
    s = str(name)
    if s.startswith("estimate"):
        s = s[len("estimate"):]
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")
    s = s.upper()
    s = re.sub(r"[^A-Z0-9]+", "_", s)
    return s.strip("_")


def load_normalise_region(wait_seconds: float = 0.0):
    """Import `normalise_region` from data.py; fall back to the local copy.

    The Excel side and the geometry side MUST normalise identically or the choropleth
    joins by luck. data.py owns the function; this script borrows it. `wait_seconds`
    lets a parallel build poll for data.py to land before giving up.
    """
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))
    deadline = time.monotonic() + max(0.0, wait_seconds)
    last_err: Exception | None = None
    while True:
        try:
            import data  # noqa: PLC0415  (deliberately late/optional)
            fn = getattr(data, "normalise_region", None)
            if callable(fn):
                return fn, "data.normalise_region"
            last_err = AttributeError("data.py has no callable normalise_region")
        except Exception as exc:  # data.py absent, or mid-write and unimportable
            last_err = exc
        if time.monotonic() >= deadline:
            break
        time.sleep(1.0)
    print(
        "!! WARNING: could not import normalise_region from data.py "
        f"({type(last_err).__name__}: {last_err}).\n"
        "!! Falling back to the LOCAL copy in this script. The Excel side and the\n"
        "!! geometry side are now two implementations of one contract. Re-run this\n"
        "!! script once data.py exists and confirm the join is still 14/14 and 9/9.",
        file=sys.stderr,
    )
    return _fallback_normalise_region, "LOCAL FALLBACK (data.py unavailable)"


def join_key_for(iso3: str, shapefile_name: str, normalise) -> str:
    """Normalised join key for one shapefile region, after the alias table."""
    key = normalise(shapefile_name)
    return JOIN_ALIASES.get(iso3, {}).get(key, key)


# --------------------------------------------------------------------------- #
# Workbook side (pandas only -- no geopandas, so --check runs anywhere)
# --------------------------------------------------------------------------- #

def workbook_region_keys(iso3: str, normalise) -> list[str]:
    """The normalised region keys implied by the `ADM 1` sheet's estimate* columns.

    Reads the header row directly rather than going through data.py: this script must
    keep working while data.py is being written, and it needs no values, only names.
    """
    import pandas as pd  # noqa: PLC0415

    cfg = COUNTRIES[iso3]
    header = pd.read_excel(cfg["workbook"], sheet_name=ADM1_SHEET, engine="openpyxl", nrows=0)
    return [normalise(c) for c in header.columns if str(c).startswith("estimate")]


# --------------------------------------------------------------------------- #
# Geometry side (geopandas -- dev only)
# --------------------------------------------------------------------------- #

def _require_geopandas():
    try:
        import geopandas as gpd  # noqa: PLC0415
        import shapely  # noqa: PLC0415, F401
        return gpd
    except ImportError as exc:
        raise SystemExit(
            "geopandas is required to BUILD the GeoJSON, and is a dev-only dependency.\n"
            f"  ({exc})\n"
            "  Install it into the project venv:  .venv/Scripts/python.exe -m pip install geopandas\n"
            "  It must NOT be added to requirements.txt -- the deployed app reads the\n"
            "  committed geo/*.json with plain json and never imports geopandas.\n"
            "  If you only need to re-verify the join, run with --check (pandas only)."
        ) from exc


def _count_vertices(geom) -> int:
    if geom is None or geom.is_empty:
        return 0
    if geom.geom_type == "Polygon":
        return len(geom.exterior.coords) + sum(len(r.coords) for r in geom.interiors)
    if hasattr(geom, "geoms"):
        return sum(_count_vertices(g) for g in geom.geoms)
    return len(geom.coords)


def topology_preserving_simplify(geoms, tolerance):
    """Simplify a set of adjacent polygons WITHOUT tearing their shared boundaries.

    Plain `GeoSeries.simplify()` runs Douglas-Peucker on each polygon independently.
    Two neighbours then simplify the boundary they share along slightly different
    vertex subsets, and the coverage develops slivers and overlaps along every
    internal border -- visible as hairline cracks in a filled choropleth.

    This is the TopoJSON approach, done with shapely directly (the `topojson` package
    is not installed and is not worth a dependency for 23 polygons):

      1. union all polygon boundaries -> fully noded lines (shared edges collapse to
         one line, and everything is split at every intersection);
      2. `linemerge` those fragments back into maximal arcs, which stops at junction
         nodes -- so each arc separates exactly one pair of faces;
      3. simplify each arc ONCE. Douglas-Peucker always keeps an arc's endpoints, so
         junctions stay welded and both neighbours inherit the same simplified edge;
      4. `polygonize` the arcs into faces and re-attach each face to the original
         polygon that contains it.

    Step 2 matters: without it the union leaves ~44k two-point fragments for SEN and
    nothing can be simplified at all (158,395 -> 88,294 vertices even at a 1 km
    tolerance). With it, 55 arcs, and 500 m gives 2,045 vertices.
    """
    from shapely.ops import linemerge, polygonize, unary_union  # noqa: PLC0415

    noded = unary_union([g.boundary for g in geoms])
    merged = linemerge(list(noded.geoms) if hasattr(noded, "geoms") else [noded])
    arcs = list(merged.geoms) if hasattr(merged, "geoms") else [merged]
    simplified_arcs = [a.simplify(tolerance, preserve_topology=True) for a in arcs]
    faces = list(polygonize(simplified_arcs))

    buckets: list[list] = [[] for _ in geoms]
    orphan_faces = []
    for face in faces:
        point = face.representative_point()
        hit = next((i for i, g in enumerate(geoms) if g.contains(point)), None)
        if hit is None:
            # A face the simplification nudged across a border, or a sliver sitting in
            # a gap in the source coverage. Give it to whichever region owns most of
            # it rather than leaving a hole; drop it only if nobody really owns it.
            overlaps = [face.intersection(g).area for g in geoms]
            best = max(range(len(geoms)), key=overlaps.__getitem__)
            if overlaps[best] > 0.5 * face.area:
                hit = best
        if hit is None:
            orphan_faces.append(face)
        else:
            buckets[hit].append(face)

    out = [unary_union(b) if b else None for b in buckets]
    return out, len(faces), orphan_faces


def _canonical(geom):
    """Deterministic, RFC 7946-friendly form: 2D, CCW exterior rings, stable part order."""
    from shapely.geometry import MultiPolygon, Polygon  # noqa: PLC0415
    from shapely.geometry.polygon import orient  # noqa: PLC0415

    if isinstance(geom, Polygon):
        return orient(geom, sign=1.0)
    if isinstance(geom, MultiPolygon):
        parts = sorted(geom.geoms, key=lambda p: (-p.area, p.bounds[0], p.bounds[1]))
        return MultiPolygon([orient(p, sign=1.0) for p in parts])
    raise TypeError(f"unexpected geometry type after simplification: {geom.geom_type}")


def _round_coords(node, decimals: int):
    if isinstance(node, dict):
        return {k: (_round_coords(v, decimals) if k == "coordinates" else v)
                for k, v in node.items()}
    if isinstance(node, (list, tuple)):
        if len(node) >= 2 and isinstance(node[0], float):
            return [round(node[0], decimals), round(node[1], decimals)]
        return [_round_coords(x, decimals) for x in node]
    return node


def build_country(iso3: str, tolerance: float, normalise, dry_run: bool = False) -> dict:
    """Read one shapefile, simplify it, and write the GeoJSON. Returns a stats dict."""
    gpd = _require_geopandas()
    from shapely.geometry import mapping  # noqa: PLC0415

    cfg = COUNTRIES[iso3]
    if not cfg["shapefile"].exists():
        raise SystemExit(f"missing shapefile: {cfg['shapefile']}")

    gdf = gpd.read_file(cfg["shapefile"])
    missing = {"adm1_name", "adm1_pcode"} - set(gdf.columns)
    if missing:
        raise SystemExit(f"{cfg['shapefile'].name}: missing column(s) {sorted(missing)}")

    # Sort by pcode so feature order is stable run to run and country to country.
    gdf = gdf.sort_values("adm1_pcode", kind="stable").reset_index(drop=True)

    version_field = cfg["version_field"]
    version = str(gdf[version_field].iloc[0]) if version_field in gdf.columns else "?"
    lang = str(gdf["lang"].iloc[0]) if "lang" in gdf.columns else "?"

    projected = gdf.to_crs(WORK_CRS)
    source_geoms = list(projected.geometry)
    source_vertices = sum(_count_vertices(g) for g in source_geoms)
    source_area = sum(g.area for g in source_geoms)

    simplified, n_faces, orphans = topology_preserving_simplify(source_geoms, tolerance)
    lost = [n for n, g in zip(gdf["adm1_name"], simplified) if g is None]
    if lost:
        raise SystemExit(
            f"{iso3}: tolerance {tolerance} m erased {len(lost)} polygon(s): {lost}. "
            "Lower --tolerance."
        )

    # --- topology checks, in the projected CRS where areas are in m^2 ---------
    invalid = [n for n, g in zip(gdf["adm1_name"], simplified) if not g.is_valid]
    overlap_area = 0.0
    for i in range(len(simplified)):
        for j in range(i + 1, len(simplified)):
            overlap_area += simplified[i].intersection(simplified[j]).area
    adj_before = {
        (i, j) for i in range(len(source_geoms)) for j in range(i + 1, len(source_geoms))
        if source_geoms[i].buffer(1).intersects(source_geoms[j].buffer(1))
    }
    adj_after = {
        (i, j) for i in range(len(simplified)) for j in range(i + 1, len(simplified))
        if simplified[i].buffer(1).intersects(simplified[j].buffer(1))
    }
    new_area = sum(g.area for g in simplified)

    out_geoms = gpd.GeoSeries(simplified, crs=WORK_CRS).to_crs(OUT_CRS)

    features = []
    for (_, row), geom in zip(gdf.iterrows(), out_geoms):
        region = str(row["adm1_name"])
        key = join_key_for(iso3, region, normalise)
        features.append({
            "type": "Feature",
            # Feature-level `id` is deliberately the join key, not the pcode: Plotly's
            # `featureidkey` defaults to "id", so a choropleth that forgets to set
            # featureidkey="properties.join_key" still joins instead of rendering grey.
            "id": key,
            "properties": {
                "join_key": key,
                "region": region,
                "adm1_pcode": str(row["adm1_pcode"]),
            },
            "geometry": _round_coords(mapping(_canonical(geom)), COORD_DECIMALS),
        })

    collection = {
        "type": "FeatureCollection",
        "name": f"adm1_{iso3.lower()}",
        "crs": {"type": "name", "properties": {"name": "urn:ogc:def:crs:OGC:1.3:CRS84"}},
        "features": features,
    }
    text = json.dumps(collection, ensure_ascii=False, separators=(",", ":")) + "\n"
    payload = text.encode("utf-8")

    stats = {
        "iso3": iso3,
        "features": len(features),
        "source_vertices": source_vertices,
        "vertices": sum(_count_vertices(g) for g in out_geoms),
        "faces": n_faces,
        "orphan_faces": len(orphans),
        "orphan_area_pct": 100 * sum(f.area for f in orphans) / source_area,
        "area_error_pct": 100 * (new_area - source_area) / source_area,
        "overlap_pct": 100 * overlap_area / source_area,
        "invalid": invalid,
        "adjacency_lost": sorted(adj_before - adj_after),
        "adjacency_gained": sorted(adj_after - adj_before),
        "bytes": len(payload),
        "shp_version": version,
        "shp_lang": lang,
        "written": False,
        "path": cfg["output"],
    }

    if dry_run:
        return stats

    cfg["output"].parent.mkdir(parents=True, exist_ok=True)
    previous = cfg["output"].read_bytes() if cfg["output"].exists() else None
    if previous == payload:
        stats["written"] = False
        stats["unchanged"] = True
    else:
        cfg["output"].write_bytes(payload)
        stats["written"] = True
        stats["unchanged"] = False
    return stats


# --------------------------------------------------------------------------- #
# Verification (stdlib json + pandas; no geopandas)
# --------------------------------------------------------------------------- #

def _iter_positions(coords):
    if coords and isinstance(coords[0], (int, float)):
        yield coords
        return
    for c in coords:
        yield from _iter_positions(c)


def check_country(iso3: str, normalise) -> bool:
    """Verify one committed GeoJSON: shape, properties, ranges, size, and the join."""
    cfg = COUNTRIES[iso3]
    path = cfg["output"]
    ok = True
    print(f"\n--- {iso3} ({cfg['name']}) -> {path.relative_to(ROOT)}")

    if not path.exists():
        print(f"    FAIL  file does not exist: {path}")
        return False

    raw = path.read_bytes()
    try:
        fc = json.loads(raw.decode("utf-8"))
    except Exception as exc:
        print(f"    FAIL  not valid UTF-8 JSON: {exc}")
        return False
    print(f"    PASS  loads with plain json.load (no geopandas), UTF-8")

    if fc.get("type") != "FeatureCollection":
        print(f"    FAIL  type is {fc.get('type')!r}, expected 'FeatureCollection'")
        ok = False
    crs_name = (fc.get("crs") or {}).get("properties", {}).get("name", "")
    if "CRS84" not in crs_name and "4326" not in crs_name:
        print(f"    FAIL  crs is {crs_name!r}; expected CRS84/EPSG:4326")
        ok = False
    else:
        print(f"    PASS  crs {crs_name} (EPSG:4326 / CRS84)")

    feats = fc.get("features", [])
    want = cfg["expected_features"]
    if len(feats) == want:
        print(f"    PASS  {len(feats)} features (expected {want})")
    else:
        print(f"    FAIL  {len(feats)} features, expected {want}")
        ok = False

    # properties: exactly the three contract keys, all non-empty, all unique
    keys_seen, pcodes = [], []
    for f in feats:
        props = f.get("properties", {})
        if tuple(props.keys()) != KEEP_PROPERTIES:
            print(f"    FAIL  properties are {list(props.keys())}, expected {list(KEEP_PROPERTIES)}")
            ok = False
            break
        if f.get("id") != props["join_key"]:
            print(f"    FAIL  feature id {f.get('id')!r} != join_key {props['join_key']!r}")
            ok = False
            break
        keys_seen.append(props["join_key"])
        pcodes.append(props["adm1_pcode"])
    else:
        print(f"    PASS  every feature carries exactly {list(KEEP_PROPERTIES)}, "
              f"and feature id == join_key")
    if len(set(keys_seen)) != len(keys_seen):
        dup = sorted({k for k in keys_seen if keys_seen.count(k) > 1})
        print(f"    FAIL  duplicate join_key(s): {dup}")
        ok = False
    if len(set(pcodes)) != len(pcodes):
        print(f"    FAIL  duplicate adm1_pcode(s)")
        ok = False

    # geometry types + coordinate ranges
    bad_types = {f["geometry"]["type"] for f in feats} - {"Polygon", "MultiPolygon"}
    if bad_types:
        print(f"    FAIL  unexpected geometry type(s): {sorted(bad_types)}")
        ok = False
    lons, lats = [], []
    for f in feats:
        for lon, lat in _iter_positions(f["geometry"]["coordinates"]):
            lons.append(lon)
            lats.append(lat)
    lo, hi = cfg["lon_range"]
    la, lb = cfg["lat_range"]
    bbox = (min(lons), min(lats), max(lons), max(lats))
    if lo <= bbox[0] and bbox[2] <= hi and la <= bbox[1] and bbox[3] <= lb:
        print(f"    PASS  bbox lon {bbox[0]:.4f}..{bbox[2]:.4f}, lat {bbox[1]:.4f}..{bbox[3]:.4f} "
              f"inside lon {lo}..{hi}, lat {la}..{lb}")
    else:
        print(f"    FAIL  bbox {bbox} outside lon {lo}..{hi} / lat {la}..{lb}")
        ok = False

    size_kb = len(raw) / 1024
    if len(raw) < SIZE_BUDGET_BYTES:
        print(f"    PASS  {size_kb:.1f} KB ({len(raw):,} bytes), budget 100 KB")
    else:
        print(f"    FAIL  {size_kb:.1f} KB exceeds the 100 KB budget")
        ok = False

    # --- the join, both directions ------------------------------------------
    geo_keys = set(keys_seen)
    try:
        xls_keys = set(workbook_region_keys(iso3, normalise))
    except Exception as exc:
        print(f"    SKIP  could not read {cfg['workbook'].name}: {exc}")
        return ok

    only_geo = sorted(geo_keys - xls_keys)
    only_xls = sorted(xls_keys - geo_keys)
    matched = sorted(geo_keys & xls_keys)
    print(f"    join  geojson keys ({len(geo_keys)}): {sorted(geo_keys)}")
    print(f"    join  workbook keys ({len(xls_keys)}): {sorted(xls_keys)}")
    print(f"    join  matched {len(matched)}/{want}: {matched}")
    print(f"    join  orphans in geojson (no Excel column): {only_geo or 'NONE'}")
    print(f"    join  orphans in Excel (no polygon):        {only_xls or 'NONE'}")
    if only_geo or only_xls or len(matched) != want:
        print(f"    FAIL  join is {len(matched)}/{want}")
        ok = False
    else:
        print(f"    PASS  join is {len(matched)}/{want}, zero orphans in both directions")

    aliases = JOIN_ALIASES.get(iso3, {})
    if aliases:
        for src, dst in aliases.items():
            hit = next((f for f in feats if f["properties"]["join_key"] == dst), None)
            if hit is None:
                print(f"    FAIL  alias {src} -> {dst} produced no feature")
                ok = False
            else:
                print(f"    PASS  alias {src} -> join_key {dst!r}, region stays "
                      f"{hit['properties']['region']!r}")
    return ok


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__.split("\n\n")[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--check", action="store_true",
                    help="verify the committed geo/*.json without rewriting them "
                         "(does not need geopandas)")
    ap.add_argument("--country", choices=sorted(COUNTRIES), action="append",
                    help="limit to one country (repeatable); default: all")
    ap.add_argument("--tolerance", type=float, default=DEFAULT_TOLERANCE_M,
                    help=f"simplification tolerance in metres (default {DEFAULT_TOLERANCE_M:g})")
    ap.add_argument("--dry-run", action="store_true",
                    help="build and report, but write nothing")
    ap.add_argument("--wait-for-data-py", type=float, default=0.0, metavar="SECONDS",
                    help="poll this long for data.normalise_region before falling back "
                         "to the local copy")
    args = ap.parse_args(argv)

    isos = args.country or list(COUNTRIES)
    normalise, source = load_normalise_region(args.wait_for_data_py)
    print(f"normalise_region source: {source}")

    if not args.check:
        print(f"tolerance: {args.tolerance:g} m in {WORK_CRS}; "
              f"output {OUT_CRS}; coords rounded to {COORD_DECIMALS} dp")
        for iso3 in isos:
            s = build_country(iso3, args.tolerance, normalise, dry_run=args.dry_run)
            state = ("dry-run" if args.dry_run
                     else "written" if s["written"] else "unchanged")
            print(
                f"\n=== {iso3} {COUNTRIES[iso3]['name']} [{state}] {s['path'].name}\n"
                f"    shapefile {COUNTRIES[iso3]['shapefile'].name} "
                f"({COUNTRIES[iso3]['version_field']}={s['shp_version']}, lang={s['shp_lang']})\n"
                f"    features       {s['features']}\n"
                f"    vertices       {s['source_vertices']:,} -> {s['vertices']:,} "
                f"({100 * s['vertices'] / s['source_vertices']:.1f}% kept)\n"
                f"    size           {s['bytes'] / 1024:.1f} KB ({s['bytes']:,} bytes)\n"
                f"    area error     {s['area_error_pct']:+.4f}%\n"
                f"    self-overlap   {s['overlap_pct']:.6f}% of total area\n"
                f"    invalid rings  {s['invalid'] or 'none'}\n"
                f"    adjacency      lost {len(s['adjacency_lost'])}, "
                f"spurious {len(s['adjacency_gained'])}\n"
                f"    orphan slivers {s['orphan_faces']} ({s['orphan_area_pct']:.5f}% of area)"
            )
            if s["invalid"] or s["adjacency_lost"] or s["adjacency_gained"] or s["overlap_pct"] > 1e-6:
                print("    !! topology degraded -- lower --tolerance")

    if args.dry_run:
        print("\n(dry run: nothing written, skipping the file checks)")
        return 0

    print("\n" + "=" * 70 + "\nVERIFY\n" + "=" * 70)
    results = {iso3: check_country(iso3, normalise) for iso3 in isos}
    print("\n" + "=" * 70)
    for iso3, good in results.items():
        print(f"{iso3}: {'PASS' if good else 'FAIL'}")
    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
