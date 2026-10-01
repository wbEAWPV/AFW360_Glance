"""Convert the Excel workbooks to CSV for the Shinylive (static) build.

Why this exists: **openpyxl is not available in Shinylive's Pyodide runtime**, and
every workbook read needs it. (`xlrd` is bundled but reads only legacy `.xls`.) So the
static GitHub Pages build ships the same numbers as CSV, which pandas can read in
Pyodide with no extra wheel.

CSV rather than Parquet deliberately: Parquet would need `pyarrow`, another large
wheel to pull into the browser, and these sheets are tiny - 97 rows by at most 15
columns.

`data.py` prefers `static_data/` when it is present and falls back to the workbooks,
so the same `data.py` serves both the Connect deployment (Excel, authoritative) and
the static export (CSV, generated). The CSVs are a build product of the workbooks and
must never be hand-edited; regenerate them instead.

Usage:
    .venv/Scripts/python.exe scripts/build_static_data.py
    .venv/Scripts/python.exe scripts/build_static_data.py --check
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
WORKBOOK_DIR = ROOT / "INPUT Tables"
OUT_DIR = ROOT / "static_data"
COUNTRIES = {"SEN": "Tables_SEN.xlsx", "GNB": "Tables_GNB.xlsx"}


def read_workbooks() -> dict[str, dict[str, pd.DataFrame]]:
    books: dict[str, dict[str, pd.DataFrame]] = {}
    for iso3, name in COUNTRIES.items():
        path = WORKBOOK_DIR / name
        if not path.exists():
            raise SystemExit(f"missing workbook: {path}")
        books[iso3] = pd.read_excel(path, sheet_name=None, engine="openpyxl")
    return books


def write_csvs(books: dict[str, dict[str, pd.DataFrame]]) -> dict[str, list[str]]:
    manifest: dict[str, list[str]] = {}
    for iso3, sheets in books.items():
        target = OUT_DIR / iso3
        target.mkdir(parents=True, exist_ok=True)
        for sheet_name, frame in sheets.items():
            # Sheet names carry spaces ("ADM 1"); keep them verbatim so the manifest
            # round-trips to the same key data.py asks for.
            out = target / f"{sheet_name}.csv"
            # UTF-8 with BOM would break pandas' header parse in Pyodide; plain UTF-8.
            #
            # float_format="%.17g" is load-bearing, not tidiness. pandas' default
            # CSV float output is lossy here: it turns Excel's 0.9500000000000001
            # into 0.95, and those are not the same number at display time --
            # "%.1f" gives "1.0" for the first and "0.9" for the second, because
            # 0.95 lands exactly on a rounding boundary and rounds to even. Five
            # cells across the seven sheets flip that way. Without this the static
            # GitHub Pages build would quietly disagree with the Connect build.
            # 17 significant digits is the width at which every float64 round-trips.
            frame.to_csv(out, index=False, encoding="utf-8", float_format="%.17g")
        manifest[iso3] = sorted(sheets)
    (OUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return manifest


def read_static_csv(path: Path) -> pd.DataFrame:
    """Read a generated CSV back exactly.

    `float_precision="round_trip"` is required, not optional. pandas' default CSV
    float parser is fast rather than exact and drifts by up to ~1e-10 here, which is
    enough to move a value across a rounding boundary and change what the user reads.
    **data.py must use this same argument** when it loads the static CSVs, or the
    Shinylive build will disagree with the Connect build.
    """
    return pd.read_csv(path, encoding="utf-8", float_precision="round_trip")


def verify(books: dict[str, dict[str, pd.DataFrame]]) -> int:
    """Round-trip every sheet and confirm the CSVs carry identical numbers."""
    problems = 0
    for iso3, sheets in books.items():
        for sheet_name, original in sheets.items():
            path = OUT_DIR / iso3 / f"{sheet_name}.csv"
            if not path.exists():
                print(f"  FAIL {iso3}/{sheet_name}: {path.name} missing")
                problems += 1
                continue
            back = read_static_csv(path)
            if list(back.columns) != list(original.columns):
                print(f"  FAIL {iso3}/{sheet_name}: columns differ")
                problems += 1
                continue
            if len(back) != len(original):
                print(f"  FAIL {iso3}/{sheet_name}: {len(back)} rows vs {len(original)}")
                problems += 1
                continue
            num = original.select_dtypes("number").columns
            # Exact equality, not a tolerance. A 1e-16 drift is invisible until a
            # value sits on a rounding boundary, and then it changes what the user
            # reads -- see the float_format note in write_csvs().
            same = original[num].reset_index(drop=True).equals(back[num].reset_index(drop=True))
            labels_same = (
                original["indicator"].reset_index(drop=True).equals(
                    back["indicator"].reset_index(drop=True)
                )
                if "indicator" in original.columns
                else True
            )
            status = "PASS" if same and labels_same else "FAIL"
            problems += status == "FAIL"
            print(
                f"  {status} {iso3}/{sheet_name}: {len(back)} rows x {len(back.columns)} cols"
                f"{'' if same else '  <- numeric values differ'}"
                f"{'' if labels_same else '  <- indicator labels differ'}"
            )
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the existing CSVs against the workbooks without rewriting",
    )
    args = parser.parse_args()

    books = read_workbooks()
    if not args.check:
        manifest = write_csvs(books)
        for iso3, sheets in manifest.items():
            print(f"wrote static_data/{iso3}/: {', '.join(sheets)}")
    print("verifying CSV round-trip against the workbooks:")
    problems = verify(books)
    total = sum(len(s) for s in books.values())
    print(f"\n{total - problems}/{total} sheets match." if problems else f"\nall {total} sheets match.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
