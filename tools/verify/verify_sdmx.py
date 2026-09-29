"""Independent reader for the AFW360 SDMX outputs (pysdmx 1.20.0).

Usage: python verify_sdmx.py --root <dir>

1. Reads <root>/sdmx/structures/AFW360_structures.xml with pysdmx
   (validate=True, i.e. XSD validation) and prints artefact counts by type.
   Skipped with a message while the file does not exist.
2. Reads every <root>/data/*.csv except *_manifest.csv with the pysdmx
   SDMX-CSV 2.1 reader and prints the observation count per file.
3. Parses every <root>/sdmx/metadata/*.csv with the csv module (pysdmx 1.20.0
   has no SDMX-CSV reference-metadata reader) and checks the header: first five
   cells MDSTRUCTURE, MDSTRUCTURE_ID, METADATASET_ID, TARGET_TYPES, TARGET_IDS;
   MDSTRUCTURE is `metadataflow` on every row; TARGET_IDS names an artefact of
   the structure message; every other header cell is a dotted path whose last
   segment is a metadata attribute id of an MSD in the structure message.
   Prints the row count per file.

Exit 1 on any failure, 0 otherwise. Not part of the R pipeline.
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import Counter
from pathlib import Path

from pysdmx.io import read_sdmx
from pysdmx.io.csv.sdmx21.reader import read as read_csv21

STRUCTURE_REL = Path("sdmx") / "structures" / "AFW360_structures.xml"
MD_HEADER = ["MDSTRUCTURE", "MDSTRUCTURE_ID", "METADATASET_ID",
             "TARGET_TYPES", "TARGET_IDS"]
# id and optional version of a maintainable, from a URN or `AGENCY:ID(VER)`
REF_RE = re.compile(r"(?:=|^)(?:[A-Za-z0-9_.@$\-]+:)?"
                    r"(?P<id>[A-Za-z0-9_@$\-]+)(?:\((?P<version>[^)]*)\))?")


class Report:
    def __init__(self) -> None:
        self.failures = 0

    def fail(self, msg: str) -> None:
        self.failures += 1
        print(f"FAIL {msg}")


def check_structures(root: Path, rep: Report):
    path = root / STRUCTURE_REL
    if not path.exists():
        print(f"structures: {STRUCTURE_REL.as_posix()} not found, skipped")
        return None
    try:
        msg = read_sdmx(str(path), validate=True)
    except Exception as e:  # pysdmx raises Invalid and others
        rep.fail(f"structures: {STRUCTURE_REL.as_posix()}: "
                 f"{type(e).__name__}: {e}")
        return None
    counts = Counter(type(a).__name__ for a in (msg.structures or []))
    print(f"structures: {STRUCTURE_REL.as_posix()}: "
          f"{sum(counts.values())} artefacts")
    for name, n in sorted(counts.items()):
        print(f"  {name}: {n}")
    return msg


def check_data(root: Path, rep: Report) -> None:
    files = sorted(p for p in (root / "data").glob("*.csv")
                   if not p.name.endswith("_manifest.csv"))
    if not files:
        rep.fail("data: no data/*.csv files found")
    for p in files:
        try:
            datasets = read_csv21(p.read_text(encoding="utf-8"))
        except Exception as e:
            rep.fail(f"data: {p.name}: {type(e).__name__}: {e}")
            continue
        if not datasets:
            rep.fail(f"data: {p.name}: no dataset read")
            continue
        n = sum(len(ds.data) for ds in datasets)
        structs = ", ".join(sorted({str(ds.short_urn) for ds in datasets}))
        print(f"data: {p.name}: {n} observations ({structs})")


def _msd_attribute_ids(msg) -> set[str]:
    ids: set[str] = set()

    def walk(components) -> None:
        for c in components or ():
            if getattr(c, "id", None):
                ids.add(c.id)
            walk(getattr(c, "components", None))

    for msd in msg.get_metadata_structures():
        walk(msd.components)
    return ids


def _artefact_keys(msg) -> set[tuple[str, str]]:
    keys = set()
    for a in msg.structures or []:
        if getattr(a, "id", None):
            keys.add((a.id, str(getattr(a, "version", ""))))
    return keys


def _target_resolves(target: str, keys: set[tuple[str, str]]) -> bool:
    m = REF_RE.search(target.strip())
    if not m:
        return False
    aid, ver = m.group("id"), m.group("version")
    return any(k[0] == aid and (ver is None or k[1] == ver) for k in keys)


def check_metadata(root: Path, msg, rep: Report) -> None:
    files = sorted((root / "sdmx" / "metadata").glob("*.csv"))
    if not files:
        print("metadata: no sdmx/metadata/*.csv files, skipped")
        return
    keys = _artefact_keys(msg) if msg is not None else set()
    attr_ids = _msd_attribute_ids(msg) if msg is not None else set()
    for p in files:
        name = f"metadata: {p.name}"
        try:
            with p.open(encoding="utf-8", newline="") as fh:
                rows = list(csv.reader(fh))
        except Exception as e:
            rep.fail(f"{name}: {type(e).__name__}: {e}")
            continue
        if not rows:
            rep.fail(f"{name}: empty file")
            continue
        header, body = rows[0], rows[1:]
        before = rep.failures
        if header[:5] != MD_HEADER:
            rep.fail(f"{name}: first header cells {header[:5]} != {MD_HEADER}")
        if msg is None:
            rep.fail(f"{name}: structure message unavailable, cannot check "
                     "TARGET_IDS and metadata attribute ids")
        else:
            for col in header[5:]:
                if col.split(".")[-1] not in attr_ids:
                    rep.fail(f"{name}: header {col!r} is not a metadata "
                             "attribute of an MSD in the structure message")
        for i, row in enumerate(body, start=2):
            if len(row) != len(header):
                rep.fail(f"{name}: line {i}: {len(row)} cells, "
                         f"header has {len(header)}")
                continue
            if row[0] != "metadataflow":
                rep.fail(f"{name}: line {i}: MDSTRUCTURE {row[0]!r} "
                         "!= 'metadataflow'")
            if msg is not None:
                targets = [t for t in re.split(r"[;\s]+", row[4]) if t]
                if not targets or not all(_target_resolves(t, keys)
                                          for t in targets):
                    rep.fail(f"{name}: line {i}: TARGET_IDS {row[4]!r} "
                             "names no artefact of the structure message")
        status = "" if rep.failures == before else " (with failures)"
        print(f"{name}: {len(body)} rows{status}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".", help="repository root")
    root = Path(ap.parse_args().root)
    rep = Report()
    msg = check_structures(root, rep)
    check_data(root, rep)
    check_metadata(root, msg, rep)
    print(f"failures: {rep.failures}")
    return 1 if rep.failures else 0


if __name__ == "__main__":
    sys.exit(main())
