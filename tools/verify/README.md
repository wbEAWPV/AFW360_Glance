# tools/verify: independent SDMX verification

Python tools that check the SDMX outputs of the R pipeline with software that
shares no code with it: pysdmx (BIS) for reading and lxml for XSD validation.
Verifier agents and maintainers run them; the R pipeline does not call them.

## Set up

Needs a Python 3.11 (the version Posit Connect runs). The scripts look for the
base interpreter of the project `.venv`, then `py -3.11`, and create
`tools/verify/.venv` (gitignored) with `requirements.txt`
(`pysdmx[data,xml]==1.20.0`; the `xml` extra brings `lxml`, `xmltodict` and
`sdmxschemas`).

```bash
bash tools/verify/make_venv.sh                                    # Git Bash
powershell -ExecutionPolicy Bypass -File tools/verify/make_venv.ps1  # PowerShell
```

Below, `V=tools/verify/.venv/Scripts/python` (Windows) or
`tools/verify/.venv/bin/python` (Linux, macOS). Run from the repository root.

## Tools

| Command | What it does | Exit |
|---|---|---|
| `$V tools/verify/verify_sdmx.py --root .` | Reads `sdmx/structures/AFW360_structures.xml` with `read_sdmx(validate=True)` and prints artefact counts by type (skipped with a message while absent); reads every `data/*.csv` except `*_manifest.csv` with the pysdmx SDMX-CSV 2.1 reader and prints observations per file; parses every `sdmx/metadata/*.csv` with `csv` and checks the header (`MDSTRUCTURE, MDSTRUCTURE_ID, METADATASET_ID, TARGET_TYPES, TARGET_IDS`, then dotted paths ending in an MSD metadata attribute id), `MDSTRUCTURE = metadataflow` and that `TARGET_IDS` names an artefact of the structure message; prints rows per file. | 1 on any failure |
| `$V tools/verify/xsd_validate.py <xsd> <xml>` | Validates with lxml; prints `valid` or the first error. | 1 if invalid |
| `$V tools/verify/check_urns.py <xml>` | Finds every `urn:sdmx:...=WB.AFW360:ID(VERSION)` reference and checks that an artefact with that id and version is in the same message; prints unresolved URNs and `unresolved: <n>`. | 1 if n > 0 |

Typical use:

```bash
$V tools/verify/verify_sdmx.py --root .
$V tools/verify/xsd_validate.py pipeline/xsd/sdmx-ml-3.1/SDMXMessage.xsd sdmx/structures/AFW360_structures.xml
$V tools/verify/check_urns.py sdmx/structures/AFW360_structures.xml
```

`fixtures/minimal_structure.xml` is a header-only SDMX-ML 3.1 `mes:Structure`
message with an empty `mes:Structures`; it is valid against `SDMXMessage.xsd`
and serves to test `xsd_validate.py` and `check_urns.py`.

## Notes

- pysdmx 1.20.0 has no reader for SDMX-CSV reference metadata, hence the
  plain `csv` checks for `sdmx/metadata/*.csv`. Without the structure message
  those files cannot be fully checked and count as a failure.
- `read_sdmx(validate=True)` validates SDMX-ML against the schemas bundled in
  `sdmxschemas`, not against `pipeline/xsd/`; `xsd_validate.py` covers the
  vendored copy.
- The message header `Sender id` is an XSD `IDType` (`[A-Za-z0-9_@$\-]+`), so
  `WB.AFW360` is not accepted there; the fixture uses `WB`.
