"""Check that every WB.AFW360 URN referenced in an SDMX-ML message resolves.

Usage: python check_urns.py <xml>
Extracts every `urn:sdmx:...=WB.AFW360:<ID>(<VERSION>)...` reference found in
attribute values and text nodes, and checks that an artefact (an element with
`id`, `agencyID` WB.AFW360 and `version`) with that id and version exists in
the same message. Prints each unresolved URN, then `unresolved: <n>`.
Exit 0 when n is 0, 1 otherwise.
"""
import re
import sys

from lxml import etree

URN_RE = re.compile(
    r"urn:sdmx:org\.sdmx\.infomodel\.[A-Za-z0-9_.]+=WB\.AFW360:"
    r"(?P<id>[A-Za-z0-9_@$\-]+)\((?P<version>[^)]*)\)[^\s\"'<]*"
)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_urns.py <xml>", file=sys.stderr)
        return 2
    try:
        root = etree.parse(argv[1]).getroot()
    except (etree.XMLSyntaxError, OSError) as e:
        print(f"error: cannot parse {argv[1]}: {e}")
        return 1

    artefacts: set[tuple[str, str]] = set()
    refs: set[str] = set()
    for el in root.iter():
        if not isinstance(el.tag, str):
            continue
        if el.get("agencyID") == "WB.AFW360" and el.get("id"):
            artefacts.add((el.get("id"), el.get("version", "")))
        for value in list(el.attrib.values()) + [el.text or ""]:
            for m in URN_RE.finditer(value):
                refs.add(m.group(0))

    unresolved = []
    for urn in sorted(refs):
        m = URN_RE.match(urn)
        if (m.group("id"), m.group("version")) not in artefacts:
            unresolved.append(urn)
    for urn in unresolved:
        print(f"unresolved urn: {urn}")
    print(f"unresolved: {len(unresolved)}")
    return 1 if unresolved else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
