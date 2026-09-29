"""Check that every WB.AFW360 URN referenced in an SDMX-ML message resolves.

Usage: python check_urns.py <xml>
Extracts every `urn:sdmx:...=WB.AFW360:<ID>(<VERSION>)[.<ITEM>...]` reference
found in attribute values and text nodes, and checks that a maintainable (an
element with `id` and `agencyID` WB.AFW360) with that id and version exists in
the same message and, when the URN names an item (`.<ITEM>`, possibly a dotted
path), that each path segment is the `id` of an element inside that
maintainable.

A maintainable without a `version` attribute is registered at version 1.0:
SDMX 3.1 organisation schemes (AgencyScheme, DataProviderScheme,
MetadataProviderScheme, DataConsumerScheme, OrganisationUnitScheme) have the
fixed version 1.0, the XSD forbids a `version` attribute on them, and URNs
that reference them or their items carry `(1.0)`.

Prints each unresolved URN, then `unresolved: <n>`. Exit 0 when n is 0,
1 otherwise.
"""
import re
import sys

from lxml import etree

URN_RE = re.compile(
    r"urn:sdmx:org\.sdmx\.infomodel\.[A-Za-z0-9_.]+=WB\.AFW360:"
    r"(?P<id>[A-Za-z0-9_@$\-]+)\((?P<version>[^)]*)\)"
    r"(?P<item>[^\s\"'<]*)"
)
# version of an organisation scheme, which carries no `version` attribute
FIXED_VERSION = "1.0"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_urns.py <xml>", file=sys.stderr)
        return 2
    try:
        root = etree.parse(argv[1]).getroot()
    except (etree.XMLSyntaxError, OSError) as e:
        print(f"error: cannot parse {argv[1]}: {e}")
        return 1

    # (id, version) of each maintainable -> ids of the elements inside it
    artefacts: dict[tuple[str, str], set[str]] = {}
    refs: set[str] = set()
    for el in root.iter():
        if not isinstance(el.tag, str):
            continue
        if el.get("agencyID") == "WB.AFW360" and el.get("id"):
            key = (el.get("id"), el.get("version") or FIXED_VERSION)
            inner = artefacts.setdefault(key, set())
            for sub in el.iterdescendants():
                if isinstance(sub.tag, str) and sub.get("id"):
                    inner.add(sub.get("id"))
        for value in list(el.attrib.values()) + [el.text or ""]:
            for m in URN_RE.finditer(value):
                refs.add(m.group(0))

    unresolved = []
    for urn in sorted(refs):
        m = URN_RE.match(urn)
        inner = artefacts.get((m.group("id"), m.group("version")))
        item = m.group("item")
        if inner is None:
            unresolved.append(urn)
        elif item and not (item.startswith(".") and all(
                seg in inner for seg in item[1:].split("."))):
            unresolved.append(urn)
    for urn in unresolved:
        print(f"unresolved urn: {urn}")
    print(f"unresolved: {len(unresolved)}")
    return 1 if unresolved else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
