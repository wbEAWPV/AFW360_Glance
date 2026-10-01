"""Build the static (Shinylive) site for GitHub Pages.

Posit Connect is the primary deployment; this is the secondary, static export and
must not drive design decisions (plan section 2). It runs the whole app in the
browser under Pyodide, with no server.

Two things make this more than `shinylive export .`:

* **`data_raw/shp/` is 28.6 MB** and the running app never touches it - the ADM1
  geometry was pre-converted to `geo/*.json` precisely so that geopandas/GDAL
  never reach the runtime. Exporting the repo wholesale would ship all of it.
* **Shinylive has no openpyxl**, so the workbooks cannot be *read* in the
  browser. `static_data/` carries the same numbers as CSV and `data.py` falls
  back to it automatically. The `.xlsx` files are still shipped, because the
  download button only serves their bytes and needs no reader.

So this stages exactly what the app needs and exports that.

Usage:
    .venv/Scripts/python.exe AFW360-shiny/scripts/build_static_site.py
    .venv/Scripts/python.exe AFW360-shiny/scripts/build_static_site.py --serve
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # AFW360-shiny/
LEGACY = ROOT.parent  # 10-legacy-pipeline/: the launcher, data_raw/, data_dashboard/
OUT_DIR = LEGACY / "_shinylive"

# Everything the running app opens, and nothing else, as paths under LEGACY.
# The staged copy keeps the same layout, so data.py finds data_raw/ and
# data_dashboard/ next to AFW360-shiny/ as it does on Connect.
FILES = [
    "app.py",
    "requirements.txt",
    "AFW360-shiny/dashboard.py",
    "AFW360-shiny/data.py",
    "data_raw/tables/Tables_SEN.xlsx",
    "data_raw/tables/Tables_GNB.xlsx",
]
GLOBS = ["AFW360-shiny/panels_*.py"]
DIRS = ["data_dashboard/geo", "data_dashboard/static_data", "data_raw/text", "data_raw/figures"]


def stage(target: Path) -> list[str]:
    rels = list(FILES)
    for pattern in GLOBS:
        rels += sorted(p.relative_to(LEGACY).as_posix() for p in LEGACY.glob(pattern))
    staged: list[str] = []
    for rel in rels:
        (target / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(LEGACY / rel, target / rel)
        staged.append(rel)
    for rel in DIRS:
        shutil.copytree(LEGACY / rel, target / rel)
        staged.append(f"{rel}/")
    return staged


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", action="store_true", help="serve the build after export")
    args = parser.parse_args()

    if not (LEGACY / "data_dashboard" / "static_data" / "manifest.json").exists():
        raise SystemExit(
            "static_data/ is missing. Run scripts/build_static_data.py first - "
            "Shinylive cannot read the .xlsx workbooks."
        )

    try:
        from shinylive import _main  # noqa: F401
    except ImportError:
        raise SystemExit(
            "shinylive is not installed. It is a dev dependency: "
            "uv pip install -r requirements-dev.txt"
        ) from None

    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "app"
        target.mkdir()
        staged = stage(target)
        print(f"staged {len(staged)} entries: {', '.join(staged)}")

        if OUT_DIR.exists():
            shutil.rmtree(OUT_DIR)
        # Invoked in-process: this machine's Application Control policy blocks the
        # pip-generated console-script .exe wrappers in .venv/Scripts.
        code = (
            "import sys; from shinylive._main import main; "
            f"sys.argv = ['shinylive', 'export', {str(target)!r}, {str(OUT_DIR)!r}]; main()"
        )
        result = subprocess.run([sys.executable, "-c", code], cwd=LEGACY)
        if result.returncode != 0:
            return result.returncode

    total = sum(f.stat().st_size for f in OUT_DIR.rglob("*") if f.is_file())
    print(f"\nexported to {OUT_DIR.relative_to(LEGACY)}  ({total / 1e6:.1f} MB)")
    print("The export must be served over HTTP; opening index.html from disk will not work.")
    if args.serve:
        subprocess.run(
            [sys.executable, "-m", "http.server", "8008", "--directory", str(OUT_DIR)],
            cwd=LEGACY,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
