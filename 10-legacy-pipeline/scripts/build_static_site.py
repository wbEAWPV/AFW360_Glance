"""Build the static (Shinylive) site for GitHub Pages.

Posit Connect is the primary deployment; this is the secondary, static export and
must not drive design decisions (plan section 2). It runs the whole app in the
browser under Pyodide, with no server.

Two things make this more than `shinylive export .`:

* **`INPUT shp/` is 28.6 MB** and the running app never touches it - the ADM1
  geometry was pre-converted to `geo/*.json` precisely so that geopandas/GDAL
  never reach the runtime. Exporting the repo wholesale would ship all of it.
* **Shinylive has no openpyxl**, so the workbooks cannot be *read* in the
  browser. `static_data/` carries the same numbers as CSV and `data.py` falls
  back to it automatically. The `.xlsx` files are still shipped, because the
  download button only serves their bytes and needs no reader.

So this stages exactly what the app needs and exports that.

Usage:
    .venv/Scripts/python.exe scripts/build_static_site.py
    .venv/Scripts/python.exe scripts/build_static_site.py --serve
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "_shinylive"

# Everything the running app opens, and nothing else.
FILES = ["app.py", "data.py", "requirements.txt"]
GLOBS = ["panels_*.py"]
DIRS = ["geo", "static_data", "INPUT Text", "INPUT Figures"]
WORKBOOKS = ["INPUT Tables/Tables_SEN.xlsx", "INPUT Tables/Tables_GNB.xlsx"]


def stage(target: Path) -> list[str]:
    staged: list[str] = []
    for name in FILES:
        shutil.copy2(ROOT / name, target / name)
        staged.append(name)
    for pattern in GLOBS:
        for path in sorted(ROOT.glob(pattern)):
            shutil.copy2(path, target / path.name)
            staged.append(path.name)
    for name in DIRS:
        src = ROOT / name
        if src.exists():
            shutil.copytree(src, target / name)
            staged.append(f"{name}/")
    for rel in WORKBOOKS:
        src = ROOT / rel
        if src.exists():
            (target / Path(rel).parent).mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, target / rel)
            staged.append(rel)
    return staged


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", action="store_true", help="serve the build after export")
    args = parser.parse_args()

    if not (ROOT / "static_data" / "manifest.json").exists():
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
        result = subprocess.run([sys.executable, "-c", code], cwd=ROOT)
        if result.returncode != 0:
            return result.returncode

    total = sum(f.stat().st_size for f in OUT_DIR.rglob("*") if f.is_file())
    print(f"\nexported to {OUT_DIR.relative_to(ROOT)}  ({total / 1e6:.1f} MB)")
    print("The export must be served over HTTP; opening index.html from disk will not work.")
    if args.serve:
        subprocess.run(
            [sys.executable, "-m", "http.server", "8008", "--directory", str(OUT_DIR)],
            cwd=ROOT,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
