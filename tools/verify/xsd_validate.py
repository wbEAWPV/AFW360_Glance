"""Validate an XML file against an XSD with lxml.

Usage: python xsd_validate.py <xsd> <xml>
Prints `valid` and exits 0, or prints the first error and exits 1.
Independent of the R pipeline (which validates with xml2).
"""
import sys

from lxml import etree


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: xsd_validate.py <xsd> <xml>", file=sys.stderr)
        return 2
    xsd_path, xml_path = argv[1], argv[2]
    try:
        schema = etree.XMLSchema(etree.parse(xsd_path))
    except (etree.XMLSchemaParseError, etree.XMLSyntaxError, OSError) as e:
        print(f"error: cannot load schema {xsd_path}: {e}")
        return 1
    try:
        doc = etree.parse(xml_path)
    except (etree.XMLSyntaxError, OSError) as e:
        print(f"error: cannot parse {xml_path}: {e}")
        return 1
    if schema.validate(doc):
        print("valid")
        return 0
    err = schema.error_log[0] if len(schema.error_log) else None
    if err is None:
        print("error: invalid (no message)")
    else:
        print(f"error: {err.filename}:{err.line}:{err.column}: {err.message}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
