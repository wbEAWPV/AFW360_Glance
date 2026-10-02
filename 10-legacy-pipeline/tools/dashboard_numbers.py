"""Extract the numeric table cells of one dashboard section, or compare two extractions.

Usage:
    python tools/dashboard_numbers.py <html> <out.csv> [--section "Senegal"]
    python tools/dashboard_numbers.py --compare a.csv b.csv

Extraction walks the rendered HTML with the standard library's ``html.parser``.
A section starts at the ``<h1>`` whose text equals ``--section`` and ends at the
next ``<h1>`` (no ``--section``: the whole page). Every ``<td>``/``<th>`` of every
``<table>`` in the section whose text is a finite number (after stripping ``%``,
``M`` and thousands separators) is written as one row:
``table,row,col,text,value``. ``table`` is the table's ordinal in the section,
``row`` the row's first header cell (or its ordinal), ``col`` the column header
(or its ordinal).

Comparison joins the two files on ``table,row,col`` and prints
``differences: <n>``: cells present in one file only, plus cells whose values
differ as floats (tolerance 1e-9). Exit code 0 when n is 0, else 1.
``--legacy-display`` first maps every cell of the second file through the old
page's display rule (pandas ``.round(1)`` then ``{:.0%}``; ``{:.0%}`` alone in
tables whose placeholder rows made ``.round`` a no-op) and compares with
tolerance 1e-6; use it to compare a pre-loader page with a corrected one.
"""

from __future__ import annotations

import argparse
import csv
import math
import sys
from html.parser import HTMLParser


def parse_number(text: str):
    """Float of a displayed cell, or None when it is not a finite number."""
    s = text.strip().replace(",", "").replace(" ", "").replace(" ", "")
    s = s.rstrip("%").rstrip("M")
    if not s:
        return None
    try:
        v = float(s)
    except ValueError:
        return None
    return v if math.isfinite(v) else None


class _Extractor(HTMLParser):
    def __init__(self, section):
        super().__init__(convert_charrefs=True)
        self.section = section
        self.active = section is None
        self.in_h1 = False
        self.h1_text = []
        self.tables = []      # list of tables; a table is a list of rows (list of (tag, text))
        self.depth = 0        # nesting depth of <table>
        self.row = None
        self.cell = None
        self.cell_tag = None

    def handle_starttag(self, tag, attrs):
        if tag == "h1":
            self.in_h1 = True
            self.h1_text = []
        if not self.active:
            return
        if tag == "table":
            self.depth += 1
            if self.depth == 1:
                self.tables.append([])
        elif self.depth == 1 and tag == "tr":
            self.row = []
        elif self.depth == 1 and tag in ("td", "th") and self.row is not None:
            self.cell = []
            self.cell_tag = tag

    def handle_endtag(self, tag):
        if tag == "h1" and self.in_h1:
            self.in_h1 = False
            title = " ".join("".join(self.h1_text).split())
            if self.section is not None:
                self.active = title == self.section
        if not self.active:
            return
        if tag == "table" and self.depth:
            self.depth -= 1
        elif self.depth == 1 and tag in ("td", "th") and self.cell is not None:
            self.row.append((self.cell_tag, " ".join("".join(self.cell).split())))
            self.cell = None
        elif self.depth == 1 and tag == "tr" and self.row is not None:
            self.tables[-1].append(self.row)
            self.row = None

    def handle_data(self, data):
        if self.in_h1:
            self.h1_text.append(data)
        if self.active and self.cell is not None:
            self.cell.append(data)


def extract(html_path: str, section=None):
    with open(html_path, encoding="utf-8") as f:
        p = _Extractor(section)
        p.feed(f.read())
        p.close()
    out = []
    for t, rows in enumerate(p.tables, start=1):
        header = None
        for r, cells in enumerate(rows, start=1):
            if header is None and cells and all(tag == "th" for tag, _ in cells):
                header = [text for _, text in cells]
                continue
            label = cells[0][1] if cells and cells[0][0] == "th" and cells[0][1] else str(r)
            for c, (tag, text) in enumerate(cells):
                value = parse_number(text)
                if value is None:
                    continue
                col = header[c] if header and c < len(header) and header[c] else str(c)
                out.append({"table": t, "row": label, "col": col, "text": text, "value": repr(value)})
    return out


def legacy_display(value: float, text: str) -> tuple[float, float]:
    """The numbers the pre-loader dashboard could have shown for a new cell.

    The old page applied pandas ``.round(1)`` and then ``{:.0%}`` to every cell.
    ``raw`` is the share (text ends with ``%``) or the displayed number; the
    built-in ``round`` is half-to-even on the binary value, like pandas.
    Tables into which the old code inserted ``pd.NA`` placeholder rows had
    object columns, on which ``.round(1)`` does nothing, so the unrounded
    ``{:.0%}`` form is also returned.
    """
    raw = value / 100 if text.strip().endswith("%") else value
    rounded = round(raw * 10) / 10 * 100
    unrounded = float(f"{raw:.0%}".rstrip("%"))
    return rounded, unrounded


def compare(a_path: str, b_path: str, legacy: bool = False) -> int:
    def load(path):
        with open(path, encoding="utf-8", newline="") as f:
            return {(r["table"], r["row"], r["col"]): (float(r["value"]), r["text"]) for r in csv.DictReader(f)}

    a, b = load(a_path), load(b_path)
    tol = 1e-6 if legacy else 1e-9
    diffs = []
    for key in sorted(set(a) | set(b)):
        if key not in a or key not in b:
            diffs.append((key, a.get(key, (None,))[0], b.get(key, (None,))[0]))
            continue
        x = a[key][0]
        ys = legacy_display(*b[key]) if legacy else (b[key][0],)
        if not any(math.isclose(x, y, rel_tol=tol, abs_tol=tol) for y in ys):
            diffs.append((key, x, b[key][1]))
    for key, x, y in diffs:
        print(f"  {'|'.join(key)}: {x} -> {y}")
    print(f"differences: {len(diffs)}")
    return 0 if not diffs else 1


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--section", default=None)
    ap.add_argument("--compare", nargs=2, metavar=("A", "B"))
    ap.add_argument("--legacy-display", action="store_true",
                    help="with --compare: apply the old display rule to B before comparing")
    args = ap.parse_args(argv)
    if args.compare:
        return compare(*args.compare, legacy=args.legacy_display)
    if len(args.paths) != 2:
        ap.error("need <html> <out.csv>")
    rows = extract(args.paths[0], args.section)
    with open(args.paths[1], "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["table", "row", "col", "text", "value"])
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} numeric cells -> {args.paths[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
