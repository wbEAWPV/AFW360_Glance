# R1: Serialising SDMX 3.1 structural metadata (SDMX-JSON 2.1.0 / SDMX-ML 3.1.0)

Compiled on 2026-09-29 from the official `sdmx-twg` GitHub repositories. The key names and element names below were copied from the schema files (XSD and JSON Schema), which are normative. The prose docs were used only for semantics. Where the prose and the schemas disagree, the schema is followed and the disagreement is listed in section 15.

## 0. Sources and citation keys

Some requested refs do not exist:
- `sdmx-im` has no branch `3.1.x`. It has `docs_v3.1`, `master`, `develop` and `draft_v3.2`, and `docs_v3.1` was used.
- `semver` has no `main` branch. Its default branch is `SDMX-3.1`.
- `sdmx-im/docs/information_model/` is organised by chapter (for example `4_Data_Structure_Definition_and_Dataset.md`), not with one page per artefact.

Citation format: `[KEY Lnn]` means line `nn` of that file. For `.md` files, open the file with `?plain=1#Lnn`. For `.xsd` and `.json` files, use `#Lnn`.

| Key | URL |
|---|---|
| JFG | https://github.com/sdmx-twg/sdmx-json/blob/v2.1.0/structure-message/docs/1-sdmx-json-field-guide.md |
| JSCH | https://github.com/sdmx-twg/sdmx-json/blob/v2.1.0/structure-message/tools/schemas/sdmx-json-structure-schema.json |
| JSAMP | https://github.com/sdmx-twg/sdmx-json/blob/v2.1.0/structure-message/samples/constructed-sample.json |
| JMFG | https://github.com/sdmx-twg/sdmx-json/blob/v2.1.0/metadata-message/docs/1-sdmx-json-field-guide.md |
| JMSCH | https://github.com/sdmx-twg/sdmx-json/blob/v2.1.0/metadata-message/tools/schemas/sdmx-json-metadata-schema.json |
| X:<file> | https://github.com/sdmx-twg/sdmx-ml/blob/v3.1.0/schemas/<file> (for example X:SDMXStructureDataStructure.xsd) |
| XS:<path> | https://github.com/sdmx-twg/sdmx-ml/blob/v3.1.0/samples/<path> |
| XDOC2 | https://github.com/sdmx-twg/sdmx-ml/blob/v3.1.0/documentation/SDMX_3-1_SECTION_3A_PART_II_COMMON.md |
| XDOC3 | https://github.com/sdmx-twg/sdmx-ml/blob/v3.1.0/documentation/SDMX_3-1_SECTION_3A_PART_III_STRUCTURE.md |
| IM-ID | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/logical_interfaces/6_Identification_of_SDMX_Objects.md |
| IM-BASE | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/information_model/2_SDMX_Base_Package.md |
| IM-IS | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/information_model/3_Specific_Item_Schemes.md |
| IM-DSD | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/information_model/4_Data_Structure_Definition_and_Dataset.md |
| IM-MSD | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/information_model/6_Metadata_Structure_Definition_and_Metadata_Set.md |
| IM-CON | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/information_model/11_Constraints.md |
| IM-PROV | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/information_model/12_Data_Provisioning.md |
| TN-IMPL | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/technical_notes/3_General_Notes_for_Implementers.md |
| TN-RM | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/technical_notes/4_Reference_Metadata.md |
| TN-CL | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/technical_notes/5_Codelist.md |
| TN-GEO | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/technical_notes/6_Geospatial_information_support.md |
| TN-AG | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/technical_notes/7_Maintenance_Agencies_and_Metadata_Providers.md |
| TN-ROLE | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/technical_notes/8_Concept_Roles.md |
| TN-CONS | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/technical_notes/9_Constraints.md |
| TN-SV | https://github.com/sdmx-twg/sdmx-im/blob/docs_v3.1/docs/technical_notes/13_ANNEX_Semantic_Versioning.md |
| SV | https://github.com/sdmx-twg/semver/blob/SDMX-3.1/Versioning%20in%20SDMX.md |
| SV-ART | https://github.com/sdmx-twg/semver/tree/SDMX-3.1/Artefact%20Specific%20Recommendations |
| CSV-D | https://github.com/sdmx-twg/sdmx-csv/blob/v2.1.0/data-message/docs/sdmx-csv-field-guide.md |
| CSV-M | https://github.com/sdmx-twg/sdmx-csv/blob/v2.1.0/metadata-message/docs/sdmx-csv-field-guide.md |

XML namespace prefixes used in the examples are the ones the official samples use:
- `mes` = `http://www.sdmx.org/resources/sdmxml/schemas/v3_1/message`
- `str` = `.../v3_1/structure`
- `com` = `.../v3_1/common`
- `md` = `.../v3_1/metadata/generic`

Source: [XS:Codelist/codelist - extended.xml L2-L7], [X:SDMXMessage.xsd L6-L12].

---

## 1. Identification rules

### 1.1 IDs (regex copied from the schemas)

| Type | Regex (XSD and JSON are identical) | Used for | Cite |
|---|---|---|---|
| `IDType` | `[A-Za-z0-9_@$\-]+` | Codes (`Code/@id`), `Parent`, Group `id`, Sender/Receiver `id`, header `ID`, DataProvider id | [X:SDMXCommonReferences.xsd L1572], [JSCH L786] |
| `NCNameIDType` | `[A-Za-z][A-Za-z0-9_\-]*` | Codelist, ConceptScheme and CategoryScheme `id`; Concept `id`; Agency `id`; every component `id` (Dimension, Measure, Attribute); `DimensionConstraint/Dimension` in JSON | [X:SDMXCommonReferences.xsd L1581], [JSCH L1676] |
| `NestedIDType` | `[A-Za-z0-9_@$\-]+(\.[A-Za-z0-9_@$\-]+)*` | Hierarchical ids (JSON `metadataAttributeReference`) | [X:SDMXCommonReferences.xsd L1554] |
| `NestedNCNameIDType` | `[A-Za-z][A-Za-z0-9_\-]*(\.[A-Za-z][A-Za-z0-9_\-]*)*` | **`agencyID`**, both in XML (`MaintainableType/@agencyID`) and in JSON | [X:SDMXCommonReferences.xsd L1590], [X:SDMXCommon.xsd L394], [JSCH L940, L1681] |

Consequences for CSV-derived codelists:
- A **code** id may start with a digit and may contain `@`, `$` and `-` (for example `_T`, `01`, `Y15-24`).
- A **codelist, concept scheme, concept or component** id must start with a letter and cannot contain `.`, `@`, `$` or spaces. This applies to all of `CodelistBaseType/@id`, `ConceptBaseType/@id` and the JSON `NCNameIDType` for concepts [X:SDMXStructureCodelist.xsd `CodelistBaseType`], [X:SDMXStructureConcept.xsd L79], [JSCH L3139].
- Maintainables use `MaintainableTypeWithNCNameID` in JSON for codelists and item schemes [JSCH L2599]. The generic XML `MaintainableBaseType/@id` is only `IDType`, but the codelist restricts it to NCName [X:SDMXCommon.xsd].
- A `ValueItem/@id` is plain `xs:string`, so any characters are allowed (the sample uses `$`, `£`, `€`) [X:SDMXStructureCodelist.xsd L338], [XS:Codelist/valuelist.xml].
- Reserved component ids: `TIME_PERIOD` (time dimension only), `REPORTING_PERIOD_START_DAY` and `REPORTING_PERIOD_END_DAY`. A component id must be unique across dimensions, groups, attributes and measures of the DSD, and this includes ids inherited from `conceptIdentity` [JFG L406], [X:SDMXStructureDataStructure.xsd L64-L68 `DataStructureUniqueComponent`].

### 1.2 Agency ids and sub-agencies (`WB.XYZ`)

- Agency ids are hierarchical and dot-separated. `SDMX` is **not** part of the hierarchy: a top-level agency (such as `WB`) is registered in SDMX's `AGENCIES` scheme, and a sub-agency is written `WB.XYZ` [IM-ID L77-L107], [TN-AG L1-L40].
- `agencyID="WB.XYZ"` is valid under `NestedNCNameIDType` in both formats. Each segment must start with a letter [X:SDMXCommonReferences.xsd L1590].
- In the URN the agency is written as-is, for example `urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=TFFS.ABC:EXTERNAL_DEBT(1.0.0)` [IM-ID L339-L345].
- Whether a sub-agency must be declared: yes, by the model rules. Only an agency registered in a scheme can maintain its own single `AgencyScheme`, so `XYZ` has to appear as an `Agency` item in the `AgencyScheme` whose `agencyID="WB"` and `id="AGENCIES"`, and `WB` has to appear in SDMX's scheme [IM-ID L84-L108], [TN-AG L10-L30]. Neither schema checks this cross-reference. It is a registry-level (semantic) rule.

### 1.3 Versions

- **XML** `VersionType` is the union of `LegacyVersionNumberType` (`(0|[1-9]\d*)(\.(0|[1-9]\d*))?`) and `SemanticVersionNumberType` (`(0|[1-9]\d*)(\.(0|[1-9]\d*)){2}(\-(...))?`) [X:SDMXCommonReferences.xsd L1608-L1628]. The JSON `VersionType` has the same two alternatives [JSCH L1903].
- **Semantic form**: `X.Y.Z`, with no leading zeros. The extension is `-` followed by dot-separated identifiers from `[0-9A-Za-z-]`, and numeric identifiers take no leading zeros. The recommended extension is `-draft`. Examples: `1.0.0-draft`, `1.0.0-draft.1`, `1.0.0-0.3.7`. Build metadata (`+exp...`) is **not allowed** [SV L23-L46].
- **Mutability**:
  - `X.0.0-EXT` allows any change.
  - `X.Y.0-EXT` allows only minor changes.
  - `X.Y.Z-EXT` allows only patch changes.
  - A stable `X.Y.Z` is immutable once released [SV L23-L38].
- **Precedence**: `1.0.0-draft < 1.0.0` [SV L37].
- **Wildcards in references** (`VersionReferenceType`) apply to **one** part only, using a `+` suffix: `2+.3.1`, `2.3+.1`, `2.3.1+` [X:SDMXCommonReferences.xsd L1514-L1530].
  - `X+.Y.Z` means the latest version `>= X.Y.Z`.
  - `X.Y+.Z` means the latest backwards-compatible version (for example `2.3+.1` means `>= 2.3.1` and `< 3.0.0`).
  - `X.Y.Z+` means the latest version within the same minor.
  - A wildcard cannot be combined with an extension: `2.3+.1-draft` is invalid [TN-SV L180-L238].
- **`*`** (all versions) is allowed only in `WildcardUrnType` and wildcard references. These are "loose" references, for example `Metadataflow/Target` and `MetadataProvisionAgreement/Target` [X:SDMXCommonReferences.xsd L161-L182], [TN-SV L234-L238], [TN-RM L58-L66].
- **`~`**: nothing in these sources defines `~` as a version wildcard. Neither the XSD nor the JSON Schema allows `~` inside a reference. In SDMX-ML 3.1, `~` is the `NotApplicableType` value in *data*, used for dimensions that are absent because of a `DimensionConstraint` [XDOC2 L857-L864], [TN-CONS L88-L110]. (It is a keyword of the REST API, which is out of scope here and not verified.)
- **Dependency rule (restrictive)**: "Semantically versioned artefacts must only reference other semantically versioned artefacts". Legacy-versioned and non-versioned artefacts may reference anything [TN-IMPL L770-L775], [TN-SV L202-L206], [SV L50]. For example, a `1.0.0` codelist cannot extend a codelist whose version is `2.1` (legacy).

### 1.4 Non-versioned artefacts

- The XML `version` attribute is optional. When it is absent, the "artefact is considered to be un-versioned" [X:SDMXCommon.xsd L357-L360].
- The legacy rule says that an artefact defined without a version is equivalent to version `1.0` [TN-IMPL L658-L664].
- These artefacts are fixed at `1.0` or version-less:

| Artefact | XML | JSON | Cite |
|---|---|---|---|
| `AgencyScheme` (id fixed `AGENCIES`) | `version` **prohibited** | `version` const `"1.0"` | [X:SDMXStructureOrganisation.xsd L19-L31, L95], [JSCH L979, L1917] |
| `DataProviderScheme` (id fixed `DATA_PROVIDERS`) | `version` prohibited | const `"1.0"` | same |
| `MetadataProviderScheme` (id fixed `METADATA_PROVIDERS`) | `version` prohibited | const `"1.0"` | same |
| `DataConsumerScheme` (id fixed `DATA_CONSUMERS`) | `version` prohibited | const `"1.0"` | [IM-ID L484-L485] |
| `Categorisation` | `version` **prohibited** | any `VersionType` (see section 15) | [X:SDMXStructureCategorisation.xsd L19-L32], [SV-ART/Artefacts with Fixed Versions/Categorisation.md] |

- A reference to a non-versioned artefact in the `AGENCY:ID(VERSION)` short form may omit the version: `AGENCY:DF_ID` [CSV-D L337].

### 1.5 URNs and the short `AGENCY:ID(VERSION)` form

- Generic form: `urn:sdmx:org.sdmx.infomodel.{package}.{Class}={agencyID}:{maintainableId}({version})[.{containerId}]*.{objectId}`. All parts are case-sensitive [IM-ID L174-L195].
- The descriptor ids (`DimensionDescriptor` and the others) are **omitted** for dimensions, attributes and measures. For a `MetadataAttribute`, the `MetadataAttributeDescriptor` is omitted and nested parents are included [IM-ID L236-L254, L331-L337].
- Classes accepted by the XSD (`UrnClassesPart`) [X:SDMXCommonReferences.xsd L23-L99]:

| Package | Classes |
|---|---|
| `base` | `Agency`, `AgencyScheme`, `DataProvider`, `DataProviderScheme`, `MetadataProvider`, `MetadataProviderScheme`, `DataConsumer`, `DataConsumerScheme`, `OrganisationUnit`, `OrganisationUnitScheme` |
| `codelist` | `Code`, `Codelist`, `ValueList`, `Hierarchy`, `HierarchyAssociation`, `HierarchicalCode`, `Level` |
| `conceptscheme` | `Concept`, `ConceptScheme` |
| `datastructure` | `DataStructure`, `Dataflow`, `Dimension`, `TimeDimension`, `Measure`, `DataAttribute`, `DimensionDescriptor`, `MeasureDescriptor`, `AttributeDescriptor`, `GroupDimensionDescriptor` |
| `metadatastructure` | `MetadataStructure`, `Metadataflow`, `MetadataAttribute`, `MetadataSet` |
| `registry` | `DataConstraint`, `MetadataConstraint`, `ProvisionAgreement`, `MetadataProvisionAgreement` |
| `categoryscheme` | `Category`, `CategoryScheme`, `Categorisation`, `ReportingTaxonomy`, `ReportingCategory` |

- There is **no** `GeographicCodelist`, `GeoGridCodelist` or `GeoFeatureSetCode` URN class. Geographic codelists use `codelist.Codelist`, and their codes use `codelist.Code` [XS:Geospatial/geospatial_geographiccodelist.xml L17-L21].
- Examples:
  - `urn:sdmx:org.sdmx.infomodel.codelist.Code=ISO:CL_3166A2(1.0.0).AR` [IM-ID L319-L321]
  - `urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=TFFS:EXT_DEBT(1.0.0).FREQ` [IM-ID L490]
  - `...Category=SDMX:SUBJECT_MATTER_DOMAINS(1.0.0-draft).1.2`, where nested categories appear as a dot path [IM-ID L323-L329]
  - `...AgencyScheme=ECB:AGENCIES(1.0)` and `...Agency=ECB:AGENCIES(1.0).AA` [IM-ID L468-L469]
- **All references in both formats are URN strings.** Examples: JSON `conceptIdentity`, `enumeration`, `structure`; XML `<str:ConceptIdentity>`, `<str:Enumeration>`, `<str:Structure>` [JSCH `ConceptReferenceType`], [X:SDMXStructureDataStructure.xsd].
- The short `AGENCY:ID(VERSION)` form (for example `ESTAT:NA_MAIN(1.6.0)`) is used in SDMX-CSV `STRUCTURE_ID`, `MDSTRUCTURE_ID`, `METADATASET_ID` and `TARGET_IDS`, not in structure files [CSV-D L56-L60], [CSV-M L59-L70].
- The first CSV column holds the lowercase type `dataflow`, `datastructure` or `dataprovision` (and `metadataflow` or `metadataprovision` for metadata CSV) [CSV-D L56], [CSV-M L59].

---

## 2. Localised names and descriptions

**JSON.** Each text has two keys:
- a best-match string: `name`, `description`, and for annotations `text`;
- a map from language tag to string: `names`, `descriptions`, `texts`.

Language keys must match the RFC 5646 regex in `localisedText` [JFG L2091-L2124], [JSCH L699].

```json
"name": "Poverty rate", "names": { "en": "Poverty rate" },
"description": "Share of population below the line", "descriptions": { "en": "Share of population below the line" }
```

- `meta.contentLanguages` is recommended [JFG L43-L70].
- `isPartialLanguage: true` marks an artefact that does not carry every language [JFG L253].

**XML.** `com:Name` and `com:Description` are `TextType` (`xs:string` with an `xml:lang` attribute that **defaults to `en`**). Both repeat once per language [X:SDMXCommon.xsd L118-L124].

```xml
<com:Name xml:lang="en">Poverty rate</com:Name>
<com:Description xml:lang="en">Share of population below the line</com:Description>
```

**When a name is required**

| Object | XML | JSON |
|---|---|---|
| Every **Nameable**: all maintainables (Codelist, ConceptScheme, DSD, Dataflow, MSD, Metadataflow, (M)PA, schemes, Categorisation, DataConstraint, MetadataSet) and all items (Code, Concept, Category, Agency, DataProvider, MetadataProvider) | `com:Name` minOccurs = 1 [X:SDMXCommon.xsd L329-L349] | `name` (string) **required**; `names` optional [JSCH L884 `NameableType`, L940 `MaintainableType` required `id`,`agencyID`,`name`] |
| Components (Dimension, TimeDimension, Measure, Attribute, MetadataAttribute, MetadataAttributeUsage), lists and groups | no Name element (Identifiable only; the name comes from the concept) [X:SDMXStructureDataStructure.xsd] | no `name` key [JSCH L4769 `MeasureType`] |
| `ValueItem` | `com:Name` minOccurs = 0 [X:SDMXStructureCodelist.xsd L338-L360] | `name` optional [JSCH L2746] |
| SentinelValue | Name required [X:SDMXStructureBase.xsd `SentinelValueType`] | `name` required [JFG L663-L671] |

---

## 3. Annotations

- Annotations are allowed on every `AnnotableType`: all identifiables and maintainables, plus component lists, `CubeRegion`, `DataKey`, `MetadataAttributeUsage`, `ValueItem`, `AvailabilityConstraint` and reported metadata `Attribute`s [X:SDMXCommon.xsd AnnotableType], [JSCH L1309 `CubeRegionType`], [X:SDMXMetadataGeneric.xsd L78].

**JSON.** `"annotations": [ { "id", "title", "type", "value", "text", "texts", "links" } ]`.
- All fields are optional.
- `id` is a free string, not an `IDType`.
- `links` replaces the XML `AnnotationURL`.
- Unknown keys are rejected; extensions need an `x-` prefix [JFG L296-L327], [JSCH L791], [JFG L2133-L2153].

```json
"annotations": [ { "id": "SRC_1", "type": "AFW_SOURCE", "title": "EHCVM 2021", "value": "EHCVM_2021",
                   "texts": { "en": "Harmonized household survey 2021" } } ]
```

**XML.** `com:Annotations/com:Annotation` has an optional attribute `id` (`xs:string`). Its child elements come **in this order**, all optional:
1. `com:AnnotationTitle`
2. `com:AnnotationType`
3. `com:AnnotationURL`*
4. `com:AnnotationText`* (with `xml:lang`)
5. `com:AnnotationValue`

`Annotations` is always the **first** child of an artefact, before `Link`, `Name` and `Description` [X:SDMXCommon.xsd L219-L252, L394].

```xml
<com:Annotations><com:Annotation id="SRC_1">
  <com:AnnotationTitle>EHCVM 2021</com:AnnotationTitle><com:AnnotationType>AFW_SOURCE</com:AnnotationType>
  <com:AnnotationText xml:lang="en">Harmonized household survey 2021</com:AnnotationText>
  <com:AnnotationValue>EHCVM_2021</com:AnnotationValue>
</com:Annotation></com:Annotations>
```

**Conventions.** "The types are not enumerated … The definitions and use of annotation types should be documented by their creator" [JFG L302]. Annotation `type` "specifies how the annotation is to be processed"; `id` disambiguates between annotations [IM-BASE L80-L89]. The spec defines no reserved annotation types.

---

## 4. AgencyScheme

**Rules**
- One `AgencyScheme` per agency.
- `id` is fixed to `AGENCIES` and the version is fixed at `1.0`.
- The scheme is a flat list with no hierarchy: the parent of every agency is the agency that owns the scheme.
- A scheme's owner must itself be declared in another (parent) scheme.

Source: [IM-ID L84-L108], [TN-AG L10-L30], [JFG L1170-L1181].

**JSON** (`data.agencySchemes`) [JSCH L1917], [JSAMP]:

```json
{ "id": "AGENCIES", "version": "1.0", "agencyID": "WB", "name": "WB agencies",
  "agencies": [ { "id": "XYZ", "name": "WB XYZ unit", "names": { "en": "WB XYZ unit" } } ] }
```

- `agencies[].id` is `NCNameIDType`.
- `contacts` is optional.

**XML** (`str:AgencySchemes/str:AgencyScheme`). The `version` attribute is prohibited and `id` is fixed [X:SDMXStructureOrganisation.xsd L95-L113]:

```xml
<str:AgencyScheme agencyID="WB" id="AGENCIES">
  <com:Name xml:lang="en">WB agencies</com:Name>
  <str:Agency id="XYZ"><com:Name xml:lang="en">WB XYZ unit</com:Name></str:Agency>
</str:AgencyScheme>
```

With this scheme in place, artefacts can carry `agencyID="WB.XYZ"`.

---

## 5. ConceptScheme and Concept

**JSON** (`data.conceptSchemes`) [JFG L994-L1077], [JSCH L3139]. Concept keys are:
- `id` (NCName)
- `name`, `names`, `description`, `descriptions`
- `parent`: the id of a local concept
- `coreRepresentation`
- `isoConceptReference`: `{conceptAgency, conceptSchemeID, conceptID}`, all three required
- `annotations`, `links`

```json
{ "id": "CS_AFW", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "AFW concepts",
  "concepts": [
    { "id": "REF_AREA", "name": "Reference area",
      "coreRepresentation": { "enumeration": "urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.XYZ:CL_AREA(1.0.0)" } },
    { "id": "OBS_VALUE", "name": "Observation value",
      "coreRepresentation": { "format": { "dataType": "Double", "minValue": 0, "maxValue": 1 } } },
    { "id": "TIME_PERIOD", "name": "Time period" } ] }
```

Core representation (`ConceptRepresentationType`, JSON `oneOf`) takes one of two forms [JSCH L3139], [JFG L1046-L1069]:
- **coded**: `enumeration` (the URN of a `Codelist` **or** `ValueList`) plus an optional `enumerationFormat`;
- **text**: `format`.

Both forms also take `minOccurs` (default 1) and `maxOccurs` (a positive integer or `"unbounded"`, default 1).

Facets in `format` (BasicComponentTextFormatType) [JSCH], [JFG L629-L661]:
- `dataType` (default `"String"`)
- `isSequence`, `interval`, `startValue`, `endValue`, `timeInterval`, `startTime`, `endTime`
- `minLength`, `maxLength`: positive integers
- `minValue`, `maxValue`: inclusive by default
- `decimals`: positive integer, **minimum 1**
- `pattern`: regex
- `isMultiLingual`
- `sentinelValues[] {value, name, names, description, descriptions}`

`enumerationFormat` (CodedTextFormatType) has no `decimals` and uses integer bounds.

**XML** (`str:ConceptSchemes/str:ConceptScheme/str:Concept`). Element order inside `Concept`:
1. `com:Annotations`
2. `com:Link`*
3. `com:Name`+
4. `com:Description`*
5. `str:Parent` (NCName)
6. `str:CoreRepresentation`
7. `str:ISOConceptReference` (`str:ConceptAgency`, `str:ConceptSchemeID`, `str:ConceptID`)

Source: [X:SDMXStructureConcept.xsd L40-L110].

`CoreRepresentation` holds either `str:TextFormat`, or `str:Enumeration` followed by an optional `str:EnumerationFormat`. It also takes the `minOccurs`/`maxOccurs` attributes [X:SDMXStructureBase.xsd `RepresentationType`].

The facet **attribute** names match the JSON keys, **except** that the data type is `textType` (XML) instead of `dataType` (JSON). Facets can also carry child `str:SentinelValue value="…"` elements with a `com:Name` [X:SDMXStructureBase.xsd L244-L330].

```xml
<str:Concept id="OBS_VALUE"><com:Name xml:lang="en">Observation value</com:Name>
  <str:CoreRepresentation><str:TextFormat textType="Double" minValue="0" maxValue="1"/></str:CoreRepresentation>
</str:Concept>
```

---

## 6. Codelist

### 6.1 Minimal codelist with a hierarchy

Hierarchy is expressed with **`parent` on each code, holding the parent code's id**, in a flat list. A code can have only one parent; use `Hierarchy` when codes need several parents [IM-IS L70-L74], [JFG L1086-L1091].

JSON (`data.codelists`) [JSCH L2599]:

```json
{ "id": "CL_AREA", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "Areas",
  "codes": [
    { "id": "SEN", "name": "Senegal" },
    { "id": "SEN_DK", "name": "Dakar", "parent": "SEN" } ] }
```

- The `CodeType` schema does **not** allow nested `codes`. The guide mentions nesting only as an optional convenience for retrieval (see section 15).
- The order of items is significant [JFG L336-L337].

XML: `str:Codelist` contains `str:Code`*, then `str:CodelistExtension`*. `str:Code` has the usual Annotations, Link, Name and Description, then `str:Parent` (IDType) [X:SDMXStructureCodelist.xsd L20-L90].

```xml
<str:Codelist agencyID="WB.XYZ" id="CL_AREA" version="1.0.0"><com:Name xml:lang="en">Areas</com:Name>
  <str:Code id="SEN"><com:Name xml:lang="en">Senegal</com:Name></str:Code>
  <str:Code id="SEN_DK"><com:Name xml:lang="en">Dakar</com:Name><str:Parent>SEN</str:Parent></str:Code>
</str:Codelist>
```

### 6.2 Codelist extension (new in 3.x)

**Semantics** [TN-CL L10-L78]:
- A codelist can extend one or more codelists and import all of their codes by default.
- Later references win conflicts, and local codes win over imported ones.
- `prefix` is prepended to every imported code.
- A selection is **either** inclusive **or** exclusive, never both for the same codelist.
- `%` is the wildcard.
- `cascadeValues` accepts `true`, `false` or `excluderoot`.
- A parent id is dropped when the parent code is not imported.

JSON (`codelistExtensions`) [JSCH L2797, `CodeSelectionType`, `MemberValueType`]:

```json
{ "id": "CL_SEX_AFW", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "Sex (AFW)",
  "codes": [ { "id": "HH", "name": "Household head" } ],
  "codelistExtensions": [ {
      "codelist": "urn:sdmx:org.sdmx.infomodel.codelist.Codelist=SDMX:CL_SEX(<exact version>)",
      "prefix": "",
      "exclusiveCodeSelection": { "memberValues": [ "U", { "value": "N", "cascadeValues": false } ] } } ] }
```

- In `CodeSelectionType`, at least one of `memberValues` or `wildcardedMemberValues` is required.
- A `memberValues` item is an `idType` string or `{ "value", "cascadeValues" }`.
- A `wildcardedMemberValues` item matches `^[A-Za-z0-9_@$-]+%?$`, so `%` is allowed only at the end.
- `codelist` is required. It must be a `Codelist` URN, and wildcarded versions such as `(1.0+.0)` are allowed [JSCH L2797].
- The member values `U` and `N` above are illustrative. Check them against the real codelist.

XML (the element follows all `Code`s) [X:SDMXStructureCodelist.xsd L94-L150], [XS:Codelist/codelist - extended.xml]:

```xml
<str:CodelistExtension prefix="">
  <str:Codelist>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=SDMX:CL_SEX(<exact version>)</str:Codelist>
  <str:ExclusiveCodeSelection><str:MemberValue>U</str:MemberValue>
    <str:MemberValue cascadeValues="false">N</str:MemberValue></str:ExclusiveCodeSelection>
</str:CodelistExtension>
```

- XML has no separate wildcard element: `MemberValue` may contain `%` directly (`WildcardedMemberValueType`).
- **Verified:** the XML pattern rejects `-`, so a `MemberValue` of `Y15-24` fails XSD validation (see section 15, item 11). If the code ids you select contain hyphens, use a `%` wildcard or switch to an exclusive selection.
- **Restriction:** if your codelist is semantically versioned (`1.0.0`), the extended `SDMX:CL_SEX` must also be semantically versioned (section 1.3). Its actual version was not checked in these sources (UNCERTAIN), so look it up in the SDMX Global Registry.
- Versioning guidance:
  - adding an extension is a minor change; removing one or changing its prefix is a major change;
  - major wildcards inside an extension are not recommended.

  Source: [SV-ART/Codelist.md].

### 6.3 GeographicCodelist, GeoGridCodelist and GeoFeatureSetCode

**GeographicCodelist**
- Message containers: XML `str:GeographicCodelists/str:GeographicCodelist`; JSON `data.geographicCodelists[]`.
- `geoType` is required: XML attribute fixed to `GeographicCodelist`; JSON `"geoType": "GeographicCodelist"`.
- Items: XML `str:GeoFeatureSetCode`, with a **required attribute** `value` holding the geo feature set string; JSON `geoFeatureSetCodes[]`, with `value` required.
- `codelistExtensions` / `CodelistExtension` are allowed.

Source: [X:SDMXStructureCodelist.xsd L208-L245], [JSCH L2634].

The `value` syntax is WKT-like: `"CRS, PRECISION: {(POLYGON ((x y, ...)), POINT (x y)): GEO_DESCRIPTION}"`. It uses the geometry types `POINT`, `LINESTRING` and `POLYGON` (with an optional `Z`). The CRS defaults to EPSG:4326 [TN-GEO L70-L236].

```json
{ "id": "CL_ADM1_SEN", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "Senegal ADM1", "geoType": "GeographicCodelist",
  "geoFeatureSetCodes": [ { "id": "SN01", "name": "Dakar", "value": "EPSG:4326: {(POINT (-17.44 14.69)): Dakar}" } ] }
```

The `value` example is illustrative: the prose grammar is loose (UNCERTAIN).

**GeoGridCodelist**
- Containers: XML `str:GeoGridCodelists/str:GeoGridCodelist geoType="GeoGridCodelist"`; JSON `data.geoGridCodelists[]`.
- Grid definition: XML `str:GridDefinition` (**required**, placed **after** the codes and extensions); JSON `gridDefinition`.
- Items: XML `str:GeoGridCode`, each with a **required** child `str:GeoCell`; JSON `geoGridCodes[]` with `geoCell`.

Source: [X:SDMXStructureCodelist.xsd L250-L325], [JSCH L2687], [XS:Geospatial/geospatial_geogridcodelist.xml L42-L44].

Formats:
- `GridDefinition`: `"CRS:REFERENCE_CORNER; X, Y; CELL_WIDTH, CELL_HEIGHT: GEO_STD"`
- `GeoCell`: `"GEO_COL, GEO_ROW: GEO_TAG"`

Source: [TN-GEO L237-L330].

A component that carries coordinates should use `textType`/`dataType` `GeospatialInformation` and the concept role `GEO_FEATURE_SET` [TN-GEO L70-L90], [TN-ROLE].

### 6.4 Partial codelists

- Set `isPartial: true` (XML attribute `isPartial="true"`, default `false`) on any item scheme [X:SDMXStructureBase.xsd L17-L30], [JFG L335].
- A partial scheme keeps the **same** agency, id and version as the full one, and must not add items or change their content. It exists only for exchange, for example as a constraint-filtered result [IM-BASE L214-L236].
- A dataflow-specific subset is normally expressed as a **DataConstraint** (section 10), not as a separate codelist.

### 6.5 ValueList

- Containers: XML `str:ValueLists/str:ValueList`; JSON `data.valueLists[]`.
- Items: XML `str:ValueItem id="…"` (`xs:string`) with an optional Name and Description; JSON `valueItems[]` with `id` required.
- ValueItems have no `parent` and no extensions.
- Measures, attributes and concepts may reference a `ValueList` (`AnyCodelistReferenceType`). **Dimensions and metadata attributes may not**: they accept only `Codelist` references (`SimpleDataStructureRepresentationType`, `MetadataAttributeRepresentationType`).

Source: [X:SDMXStructureCodelist.xsd L338-L362], [JSCH L2746], [X:SDMXStructureDataStructure.xsd], [JFG L571].

```json
{ "id": "VL_UNIT_MULT", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "Unit multiplier",
  "valueItems": [ { "id": "0", "name": "Units" }, { "id": "6", "name": "Millions" } ] }
```

---

## 7. DataStructure (DSD)

### 7.1 Key names

| Concept | JSON key | XML element or attribute |
|---|---|---|
| components | `dataStructureComponents` | `str:DataStructureComponents` |
| dimensions | `dimensionList {id:"DimensionDescriptor", dimensions[], timeDimension}` | `str:DimensionList` > `str:Dimension`+ then `str:TimeDimension`? |
| groups | `groups[] {id, groupDimensions[]}` | `str:Group id` > `str:GroupDimension/str:DimensionReference`+ |
| attributes | `attributeList {id:"AttributeDescriptor", attributes[], metadataAttributeUsages[]}` | `str:AttributeList` > (`str:Attribute` \| `str:MetadataAttributeUsage`)+ |
| measures | `measureList {id:"MeasureDescriptor", measures[]}` | `str:MeasureList` > `str:Measure`+ |
| MSD link | `metadata` (MSD URN) | `str:Metadata` (after `DataStructureComponents`) |
| evolving | `evolvingStructure` (boolean) | attribute `evolvingStructure` (default `false`) |

Source: [JSCH L3583], [JFG L400-L860], [X:SDMXStructureDataStructure.xsd L20-L120, L314-L560].

- XML child order inside `DataStructureComponents`: `DimensionList`, then `Group`*, then `AttributeList`?, then `MeasureList`? [X:SDMXStructureDataStructure.xsd `DataStructureComponentsType`].
- JSON requires `dimensionList`; `attributeList`, `measureList` and `groups` are optional [JSCH `DataStructureComponentsType`].

### 7.2 Dimensions

- **Order**: key order is the order of declaration. The time dimension is not part of the ordered key [JFG L705-L712].
- **`position`**: optional and must match the declared order. It starts at **0** in JSON [JFG L736] (the JSON sample uses 1, see section 15). The XML attribute `position` is `xs:int` and is prohibited on `TimeDimension`.
- **Frequency**: a DSD with a time dimension *should* declare a frequency dimension, conventionally first [JFG L707].
- **Concept identity**: `conceptIdentity` (JSON, required) / `str:ConceptIdentity` (XML, required) is a Concept URN [JSCH `DimensionType`], [X:SDMXStructureDataStructure.xsd L340-L370].
- **Local vs concept representation**: `localRepresentation` / `str:LocalRepresentation` overrides the concept's `coreRepresentation`. When it is absent, the core representation applies [IM-DSD L186-L197], [JFG L731].
- **Dimension representation**:
  - Codelist only (no ValueList).
  - `minOccurs`/`maxOccurs` are prohibited, because a dimension has exactly one value.
  - `isMultiLingual` is prohibited.
  - `XHTML` is not allowed.

  Source: [X:SDMXStructureDataStructure.xsd `SimpleDataStructureRepresentationType`], [JFG L739].
- **TimeDimension**:
  - id fixed to `TIME_PERIOD`.
  - Text format only; the time types restrict `textType` to `TimeDataType` (default `ObservationalTimePeriod`).
  - Only the facets `startTime`/`endTime` are allowed.
  - No `ConceptRole`.
  - In XML, `str:LocalRepresentation` is **required** on `TimeDimension` [X:SDMXStructureDataStructure.xsd L396-L412, `TimeDimensionRepresentationType`]. JSON says it may be omitted [JFG L763] (see section 15).

### 7.3 Measures (several allowed in 3.x)

- One or more `Measure`s are allowed [IM-DSD L218-L226].
- Each measure takes:
  - `conceptIdentity` (required);
  - `conceptRoles[]`;
  - `localRepresentation`: a Codelist or ValueList `enumeration`, or a `format`, plus `minOccurs` and `maxOccurs`. Values other than 1 make the measure an array [IM-DSD L218-L226];
  - `usage`: `"mandatory"` or `"optional"`, default **`optional`**. It states whether a value must be present for an existing observation.

  Source: [JSCH L4769], [X:SDMXStructureDataStructure.xsd L533-L560].
- XML `str:Measure` takes the attribute `usage`. Its child order is Annotations, Link, `ConceptIdentity`, `LocalRepresentation`?, `ConceptRole`*.
- An attribute can be tied to specific measures with JSON `measureRelationship: ["OBS_VALUE"]` or XML `str:MeasureRelationship/str:Measure`+. When absent, the attribute applies to all measures [JFG L487], [X:SDMXStructureDataStructure.xsd L175-L190].

### 7.4 Attributes

- `usage`: `mandatory` or `optional` (default `optional`) [JSCH `AttributeType`], [X:SDMXStructureDataStructure.xsd L160-L185].
- `attributeRelationship` is **required**. Exactly one form is used [JSCH L2179 `oneOf`], [X:SDMXStructureDataStructure.xsd L192-L225], [IM-DSD L270-L283]:

| Level | JSON | XML |
|---|---|---|
| Dataflow (constant across the dataflow) | `{"dataflow": {}}` | `<str:Dataflow/>` |
| Some dimensions (series or group level) | `{"dimensions": ["REF_AREA","INDICATOR"], "areDimensionsOptional": [false,true]}` | `<str:Dimension>REF_AREA</str:Dimension><str:Dimension optional="true">INDICATOR</str:Dimension>` |
| Group (convenience) | `{"group": "GRP_ID"}` | `<str:Group>GRP_ID</str:Group>` |
| Observation | `{"observation": {}}` | `<str:Observation/>` |

- Attribute `localRepresentation` takes Codelist, ValueList or format, plus `minOccurs` and `maxOccurs` for arrays.
- XML child order: Annotations, Link, `ConceptIdentity`, `LocalRepresentation`?, `ConceptRole`*, `AttributeRelationship`, `MeasureRelationship`?

### 7.5 Metadata attributes used in a DSD ("data-related reference metadata")

The DSD points to **one** MSD. JSON uses `metadata`; XML uses `<str:Metadata>` and the URN [JSCH L3583], [X:SDMXStructureDataStructure.xsd L44-L50]. After that, any metadata attribute of that MSD may be reported in the data **at any level by default** [JFG L407].

To restrict the level, add a usage [JSCH L2148], [X:SDMXStructureDataStructure.xsd L266-L285]:
- JSON: `attributeList.metadataAttributeUsages[]`, each `{ "metadataAttributeReference": "<id>", "attributeRelationship": {...} }`.
- XML: `<str:MetadataAttributeUsage><str:MetadataAttributeReference>ID</str:MetadataAttributeReference><str:AttributeRelationship>…</str:AttributeRelationship></str:MetadataAttributeUsage>`.

A usage has **no** `id`, `ConceptIdentity` or `LocalRepresentation`. The representation comes from the MSD [IM-DSD L186-L197].

### 7.6 Concept roles

- JSON uses `conceptRoles: [<Concept URN>]` and XML uses `str:ConceptRole`*, on Dimension, Measure and Attribute. They are not allowed on TimeDimension [TN-ROLE L14-L20], [X:SDMXStructureDataStructure.xsd].
- The standard roles live in the concept scheme `SDMX:CONCEPT_ROLES(1.0.0)`: `COMMENT`, `ENTITY`, `FLAG`, `FREQ`, `GEO`, `OPERATION`, `VARIABLE`, `MEASURE`, `GEO_FEATURE_SET`, `PRIMARY`.
- Using a concept from that scheme as the `conceptIdentity` implies the role [TN-ROLE L22-L140].

### 7.7 `evolvingStructure` (3.1)

- `true` means dimensions may be added in a **minor** version.
- Setting it to `true` requires a major version (`x.0.0`).
- A dataflow that references such a DSD with a minor wildcard **must** carry a `dimensionConstraint`.

Source: [JFG L408], [TN-CONS L42-L110], [IM-DSD L312-L315].

### 7.8 Full minimal DSD example (JSON)

The example has three dimensions including `TIME_PERIOD`, two measures, three attributes (one at dataflow level, one at series/dimension level, one at observation level) and one metadata attribute usage.

```json
{
  "id": "DSD_AFW", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "AFW poverty indicators",
  "evolvingStructure": false,
  "metadata": "urn:sdmx:org.sdmx.infomodel.metadatastructure.MetadataStructure=WB.XYZ:MSD_AFW(1.0.0)",
  "dataStructureComponents": {
    "dimensionList": {
      "id": "DimensionDescriptor",
      "dimensions": [
        { "id": "REF_AREA", "position": 0,
          "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).REF_AREA",
          "localRepresentation": { "enumeration": "urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.XYZ:CL_AREA(1.0.0)" } },
        { "id": "INDICATOR", "position": 1,
          "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).INDICATOR",
          "localRepresentation": { "enumeration": "urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.XYZ:CL_INDICATOR(1.0.0)" } } ],
      "timeDimension": { "id": "TIME_PERIOD",
          "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).TIME_PERIOD",
          "localRepresentation": { "format": { "dataType": "GregorianYear" } } } },
    "measureList": {
      "id": "MeasureDescriptor",
      "measures": [
        { "id": "OBS_VALUE", "usage": "mandatory",
          "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).OBS_VALUE",
          "localRepresentation": { "format": { "dataType": "Double" } } },
        { "id": "SE", "usage": "optional",
          "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).SE",
          "localRepresentation": { "format": { "dataType": "Double", "minValue": 0 } } } ] },
    "attributeList": {
      "id": "AttributeDescriptor",
      "attributes": [
        { "id": "SOURCE_SURVEY", "usage": "mandatory", "attributeRelationship": { "dataflow": {} },
          "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).SOURCE_SURVEY",
          "localRepresentation": { "format": { "dataType": "String", "maxLength": 200 } } },
        { "id": "UNIT_MEASURE", "usage": "mandatory", "attributeRelationship": { "dimensions": [ "INDICATOR" ] },
          "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).UNIT_MEASURE",
          "localRepresentation": { "enumeration": "urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.XYZ:CL_UNIT(1.0.0)" } },
        { "id": "OBS_STATUS", "usage": "optional", "attributeRelationship": { "observation": {} },
          "measureRelationship": [ "OBS_VALUE" ],
          "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).OBS_STATUS",
          "localRepresentation": { "enumeration": "urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.XYZ:CL_OBS_STATUS(1.0.0)" } } ],
      "metadataAttributeUsages": [
        { "metadataAttributeReference": "METHODOLOGY", "attributeRelationship": { "dimensions": [ "INDICATOR" ] } } ] } } }
```

The XML equivalent of the attribute part follows the rules in 7.4 and 7.5. The time dimension looks like this:

```xml
<str:TimeDimension id="TIME_PERIOD"><str:ConceptIdentity>urn:…Concept=WB.XYZ:CS_AFW(1.0.0).TIME_PERIOD</str:ConceptIdentity>
  <str:LocalRepresentation><str:TextFormat textType="GregorianYear"/></str:LocalRepresentation></str:TimeDimension>
```

Reference XML DSD samples: [XS:Data Structure Definition/ECB_EXR.xml], [XS:Data - Complex Data Attributes/ECB_EXR_CA_DSD.xml].

---

## 8. Dataflow

The link to the DSD is JSON `structure` or XML `str:Structure` (a DSD URN, which may be wildcarded). The optional 3.1 `dimensionConstraint` lists **dimension ids** and never `TIME_PERIOD` [JFG L1264-L1296], [JSCH L3610], [X:SDMXStructureDataflow.xsd L20-L60], [XS:Dataflow/dataflow_dimensionconstraint.xml].

```json
{ "id": "DF_AFW_POV", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "AFW poverty",
  "structure": "urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=WB.XYZ:DSD_AFW(1.0.0)" }
```

```xml
<str:Dataflow agencyID="WB.XYZ" id="DF_AFW_POV" version="1.0.0"><com:Name xml:lang="en">AFW poverty</com:Name>
  <str:Structure>urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=WB.XYZ:DSD_AFW(1.0.0)</str:Structure>
  <str:DimensionConstraint><str:Dimension>REF_AREA</str:Dimension><str:Dimension>INDICATOR</str:Dimension></str:DimensionConstraint>
</str:Dataflow>
```

**Rules for `dimensionConstraint`**
- It is required when the DSD is evolving and the dataflow binds to the latest minor version.
- It may list only dimensions of that DSD.
- Changing it requires a major version of the dataflow.
- In a DSD-level export, the dimensions left out of it are written as `~`.

Source: [TN-CONS L65-L110], [SV-ART/Dataflow.md].

---

## 9. Reference metadata: MSD, Metadataflow, MetadataProvisionAgreement, MetadataProviderScheme, Metadataset

### 9.1 MetadataStructure (MSD)

- In 3.x the MSD has **no targets**. It contains only one `MetadataAttributeList`, and targets move to the Metadataflow and the MPA [TN-RM L3-L20].
- JSON (`data.metadataStructures[]`): `metadataStructureComponents.metadataAttributeList {id:"MetadataAttributeDescriptor", metadataAttributes[]}`, where `metadataAttributes` is required and non-empty [JSCH L4633], [JFG L862-L947].
- Each `metadataAttribute` [JSCH L4574], [X:SDMXStructureMetadataStructure.xsd L126-L175]:
  - `id`, `conceptIdentity` (required);
  - `localRepresentation`: a **Codelist only** `enumeration`, or a `format`. `minOccurs`/`maxOccurs` are **prohibited inside** `localRepresentation`;
  - `minOccurs` (default 1) and `maxOccurs` (default 1, or `"unbounded"`) **on the attribute itself**. They count occurrences under the parent;
  - `isPresentational` (default false): the attribute only groups children and holds no value;
  - nested `metadataAttributes[]` for children.
- XML: `str:MetadataStructure` > `str:MetadataStructureComponents` > `str:MetadataAttributeList` > `str:MetadataAttribute`+. Nested `str:MetadataAttribute` elements come after `LocalRepresentation`. The attributes are `minOccurs`, `maxOccurs` and `isPresentational` [X:SDMXStructureMetadataStructure.xsd L20-L175].
- Representation options (via `format`/`TextFormat`):
  - text: `String`;
  - XHTML: `"XHTML"`;
  - multilingual: `isMultiLingual: true` / `isMultiLingual="true"`;
  - coded: `enumeration`.

  Source: [X:SDMXStructureBase.xsd L244-L270], [JSCH `BasicComponentTextFormatType`].

```json
{ "id": "MSD_AFW", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "AFW reference metadata",
  "metadataStructureComponents": { "metadataAttributeList": { "id": "MetadataAttributeDescriptor",
    "metadataAttributes": [
      { "id": "METHODOLOGY", "minOccurs": 0,
        "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).METHODOLOGY",
        "localRepresentation": { "format": { "dataType": "XHTML", "isMultiLingual": true } } },
      { "id": "CONTACT", "isPresentational": true, "minOccurs": 0, "maxOccurs": "unbounded",
        "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).CONTACT",
        "metadataAttributes": [ { "id": "CONTACT_EMAIL",
          "conceptIdentity": "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.XYZ:CS_AFW(1.0.0).CONTACT_EMAIL",
          "localRepresentation": { "format": { "dataType": "String" } } } ] } ] } } }
```

A metadata attribute that a DSD references should be a **top-level, non-nested** attribute. XML types `MetadataAttributeReference` as `NCNameIDType` (no dots), and the XSD prose says nested attributes are not supported in data. Other sources disagree (see section 15).

### 9.2 Metadataflow

- JSON keys: `structure` (MSD URN) and `targets[]` (wildcardable URNs, `WildcardObjectReferenceType`) [JSCH L4652].
- XML: `str:Metadataflow` > `str:Structure`, then `str:Target`+. **At least one `Target` is required** in XML [X:SDMXStructureMetadataflow.xsd L20-L55].
- Wildcards use `*`, for example `urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=WB.XYZ:*(*)` [TN-RM L58-L66].

```json
{ "id": "MDF_AFW", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "AFW metadata flow",
  "structure": "urn:sdmx:org.sdmx.infomodel.metadatastructure.MetadataStructure=WB.XYZ:MSD_AFW(1.0.0)",
  "targets": [ "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=WB.XYZ:*(*)" ] }
```

### 9.3 MetadataProviderScheme and MetadataProvisionAgreement

- **Provider scheme.** JSON: `metadataProviderSchemes[] {id:"METADATA_PROVIDERS", version:"1.0", agencyID, name, metadataProviders[]}`. XML: `str:MetadataProviderScheme id="METADATA_PROVIDERS"` (no version attribute) > `str:MetadataProvider id` [JSCH `MetadataProviderSchemeType`], [X:SDMXStructureOrganisation.xsd].
- **MPA.** JSON: `metadataflow`, `metadataProvider` (a MetadataProvider URN, for example `urn:sdmx:org.sdmx.infomodel.base.MetadataProvider=WB.XYZ:METADATA_PROVIDERS(1.0).AFW_TEAM`) and `targets[]` [JSCH L4909]. XML: `str:Metadataflow`, `str:MetadataProvider`, then optional `str:Target`* [X:SDMXStructureProvisionAgreement.xsd L74-L95].

```json
{ "id": "MPA_AFW", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "AFW team metadata",
  "metadataflow": "urn:sdmx:org.sdmx.infomodel.metadatastructure.Metadataflow=WB.XYZ:MDF_AFW(1.0.0)",
  "metadataProvider": "urn:sdmx:org.sdmx.infomodel.base.MetadataProvider=WB.XYZ:METADATA_PROVIDERS(1.0).AFW_TEAM" }
```

### 9.4 Metadataset (the 3.x referential metadata report)

- A metadataset is maintainable and is owned by a **metadata provider** [TN-RM L12-L16], [TN-AG L3-L9].
- JSON message: `data.metadataSets[]` [JMFG], [JMSCH L568, L679]. Keys:
  - required: `id`, `agencyID`, `name`, **either** `metadataflow` **or** `metadataProvisionAgreement` (URN), `targets[]`, `attributes[]`;
  - optional: `version` (when absent the set is non-versioned), `isExternalReference`, `validFrom`, `validTo`, `reportingBegin`, `reportingEnd`, `publicationYear`, `publicationPeriod`, `isPartialLanguage`, `annotations`, `links`, `description`/`descriptions`.
- `targets` are URNs of **any identifiable** object: a dataflow, a code, a DSD and so on [JMFG L241].
- An attribute is `{ "id", "value", "attributes": [...] }`, where child attributes are nested recursively. `value` is a string, number, integer, boolean, `null`, or a localised object `{ "en": "<p>…</p>" }`, and it may contain HTML. `"#N/A"` or `"NaN"` mark intentionally missing values [JMFG L295-L333, L477-L486].

```json
{ "id": "MDS_SEN_POV", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "Senegal poverty methodology",
  "metadataProvisionAgreement": "urn:sdmx:org.sdmx.infomodel.registry.MetadataProvisionAgreement=WB.XYZ:MPA_AFW(1.0.0)",
  "targets": [ "urn:sdmx:org.sdmx.infomodel.codelist.Code=WB.XYZ:CL_AREA(1.0.0).SEN" ],
  "attributes": [ { "id": "METHODOLOGY", "value": { "en": "<p>EHCVM 2021, consumption aggregate…</p>" } },
                  { "id": "CONTACT", "attributes": [ { "id": "CONTACT_EMAIL", "value": "pov@example.org" } ] } ] }
```

XML (`mes:GenericMetadata` > `mes:MetadataSet`; content in the namespace `.../v3_1/metadata/generic`) [X:SDMXMetadataGeneric.xsd L33-L100], [X:SDMXMessage.xsd L100-L108]:
- `MetadataSetType` has the maintainable attributes (`agencyID`, `id`, `version`) plus `action`, `reportingBeginDate`, `reportingEndDate`, `publicationYear` and `publicationPeriod` [X:SDMXCommon.xsd `SetAttributeGroup`].
- Children, in order:
  1. `com:Name`+
  2. `md:MetadataProvisionAgreement` **or** `md:Metadataflow`
  3. `md:Target`+
  4. `md:Attribute`+
- `md:Attribute id="…"` holds **one** of `md:Value`, `com:Text`+ (per `xml:lang`) or `com:StructuredText`+ (XHTML), followed by child `md:Attribute`*.

```xml
<mes:MetadataSet agencyID="WB.XYZ" id="MDS_SEN_POV" version="1.0.0">
  <com:Name xml:lang="en">Senegal poverty methodology</com:Name>
  <md:MetadataProvisionAgreement>urn:sdmx:org.sdmx.infomodel.registry.MetadataProvisionAgreement=WB.XYZ:MPA_AFW(1.0.0)</md:MetadataProvisionAgreement>
  <md:Target>urn:sdmx:org.sdmx.infomodel.codelist.Code=WB.XYZ:CL_AREA(1.0.0).SEN</md:Target>
  <md:Attribute id="METHODOLOGY"><com:StructuredText xml:lang="en"><p xmlns="http://www.w3.org/1999/xhtml">EHCVM 2021…</p></com:StructuredText></md:Attribute>
</mes:MetadataSet>
```

The prefix of `MetadataSet` is `mes:`, because the element is declared in the message schema. `md:` is the generic-metadata namespace.

**Message header requirement (verified with the XSD).** A `mes:GenericMetadata` header must contain at least one `mes:Structure structureID="…"` after `mes:Sender`. Its child is exactly one of `com:ProvisionAgreement`, `com:StructureUsage` (a Metadataflow URN) or `com:Structure` (an MSD URN) [X:SDMXMessage.xsd `GenericMetadataHeaderType`], [X:SDMXCommon.xsd `GenericMetadataStructureType`, `PayloadStructureType`]:

```xml
<mes:Structure structureID="MDF_AFW"><com:StructureUsage>urn:sdmx:org.sdmx.infomodel.metadatastructure.Metadataflow=WB.XYZ:MDF_AFW(1.0.0)</com:StructureUsage></mes:Structure>
```

**XHTML values.** `com:StructuredText` uses `xs:any namespace="http://www.w3.org/1999/xhtml" processContents="strict"`, and the SDMX XSDs do not ship an XHTML schema. A strict XSD validator therefore rejects the `<p>` element unless you add an XHTML schema to it. With `com:Text` the set validates [X:SDMXCommon.xsd L1046-L1052].

---

## 10. DataConstraint

JSON (`data.dataConstraints[]`) [JSCH L3294, L3186, L3418, L1309], [JFG L1420-L1900]. Keys:
- `constraintAttachment`: exactly one of `dataProvider` (a single URN), `dataStructures[]`, `dataflows[]` or `provisionAgreements[]`;
- `cubeRegions[]`: **at most 2**, each `{ include (default true), keyValues[], components[] }`;
- `dataKeySets[]`: each `{ isIncluded (required), keys[] }`;
- `keyValues` items: `{id, include, removePrefix, values[] | timeRange}`, where a value is a string or `{value, cascadeValues, validFrom, validTo}`;
- `components` items: attributes, measures or metadata attributes, where `lang` is allowed on values;
- `keys[]` items: `{ keyValues:[{id, values[]}], components[], validFrom, validTo }`, where a key value's `include` is fixed to true.

XML [X:SDMXStructureConstraint.xsd L71-L140, L385-L420]:
- `str:DataConstraint` > `str:ConstraintAttachment` > (`str:DataProvider` \| `str:DataStructure`+ \| `str:Dataflow`+ \| `str:ProvisionAgreement`+).
- Then `str:DataKeySet isIncluded`* (each > `str:Key`+ > `str:KeyValue id` > `str:Value`+).
- Then `str:CubeRegion include`{0,2} (each > `str:KeyValue id include` > `str:Value`+ or `str:TimeRange`; `str:Component id` > …).

Cube region example (JSON):

```json
{ "id": "CN_DF_AFW_POV", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "Allowed content for DF_AFW_POV",
  "constraintAttachment": { "dataflows": [ "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=WB.XYZ:DF_AFW_POV(1.0.0)" ] },
  "cubeRegions": [ { "include": true, "keyValues": [ { "id": "REF_AREA", "values": [ "SEN", "GNB" ] } ] } ],
  "dataKeySets": [ { "isIncluded": true, "keys": [
      { "keyValues": [ { "id": "REF_AREA", "values": [ "SEN" ] }, { "id": "INDICATOR", "values": [ "POV_215", "POV_365" ] } ] } ] } ] }
```

Key set example (XML) [XS:Constraint/data_constraint_datakeyset.xml]:

```xml
<str:DataKeySet isIncluded="true"><str:Key>
  <str:KeyValue id="REF_AREA"><str:Value>SEN</str:Value></str:KeyValue>
  <str:KeyValue id="INDICATOR"><str:Value>POV_215</str:Value></str:KeyValue></str:Key></str:DataKeySet>
```

**The "role" (Allowed/Actual) is gone in 3.1.**
- Neither the 3.1 XSD nor the JSON schema has a `role` attribute.
- "Allowed" content is a `DataConstraint`, which is a reporting constraint.
- "Actual" content is an `AvailabilityConstraint`. It is "generated dynamically as a response to the availability REST API" and is **not maintained**. In XML it has no id or version (it extends `AnnotableType`), and it takes exactly one attachment and one `CubeRegion`.

Source: [TN-CONS L3-L40], [X:SDMXStructureConstraint.xsd L240-L260].

Older docs still show `role`/`type="Allowed"` (see section 15).

**Attachment and inheritance**
- A constraint can attach at three levels: DSD, then Dataflow, then ProvisionAgreement. It can also attach to a DataProvider.
- A lower level can only narrow a higher one.
- For versioned constraints, the latest version is applied.
- `%` wildcards and `removePrefix` are allowed. `validFrom`/`validTo` can be set per value.

Source: [TN-CONS L112-L372].

**Can a constraint say "these combinations must exist"? No.**
- A DataConstraint defines what is *allowed* (or disallowed). An included `DataKeySet` lists permitted keys, and "Any dimension not stated … is assumed to be wild carded" [JFG L1800], [TN-CONS L230-L245].
- Nothing in 3.1 expresses a required minimum or complete coverage.
- Measure and attribute `usage="mandatory"` only requires a value when an observation or series is present [JSCH `MeasureType`].
- The AvailabilityConstraint only *reports* what exists.

Completeness ("every country × indicator must have data") has to be checked by your own validator.

---

## 11. DataProviderScheme and ProvisionAgreement

- **Provider scheme.** JSON: `dataProviderSchemes[] {id:"DATA_PROVIDERS", version:"1.0", agencyID, name, dataProviders[] {id, name, contacts[]}}` [JSCH L3442]. XML: `str:DataProviderScheme agencyID id="DATA_PROVIDERS"` (version prohibited) > `str:DataProvider id` [X:SDMXStructureOrganisation.xsd].
- **ProvisionAgreement.** JSON: `provisionAgreements[] {…, dataflow, dataProvider}` [JSCH L4886]. XML: `str:ProvisionAgreement` > `str:Dataflow`, then `str:DataProvider`. Both elements are **required** in XML [X:SDMXStructureProvisionAgreement.xsd L35-L50], [IM-PROV L28-L32, L86].

```json
{ "dataProviderSchemes": [ { "id": "DATA_PROVIDERS", "version": "1.0", "agencyID": "WB.XYZ", "name": "AFW data providers",
      "dataProviders": [ { "id": "AFW_POV", "name": "AFW Poverty team" } ] } ],
  "provisionAgreements": [ { "id": "PA_AFW_POV", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "AFW poverty provision",
      "dataflow": "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=WB.XYZ:DF_AFW_POV(1.0.0)",
      "dataProvider": "urn:sdmx:org.sdmx.infomodel.base.DataProvider=WB.XYZ:DATA_PROVIDERS(1.0).AFW_POV" } ] }
```

---

## 12. CategoryScheme and Categorisation

**CategoryScheme**
- JSON: `categorySchemes[]`, where categories nest through a **recursive `categories` array**. There is no `parent` key [JSCH L2417], [JFG L950-L991].
- XML: `str:CategoryScheme` > `str:Category` > nested `str:Category` [X:SDMXStructureCategory.xsd L54-L75].

**Categorisation**
- JSON: `categorisations[] {…, source: <URN of the dataflow>, target: <Category URN>}` [JSCH L2364], [JFG L1386-L1418].
- XML: `str:Categorisation` > `str:Source`, then `str:Target`. The `version` attribute is **prohibited** [X:SDMXStructureCategorisation.xsd L19-L50].
- The category URN is `…categoryscheme.Category=AG:SCHEME(ver).PARENT.CHILD` [IM-ID L323-L329].

```json
{ "categorySchemes": [ { "id": "CS_THEMES", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "Themes",
      "categories": [ { "id": "POVERTY", "name": "Poverty", "categories": [ { "id": "MONETARY", "name": "Monetary poverty" } ] } ] } ],
  "categorisations": [ { "id": "CAT_DF_AFW_POV", "agencyID": "WB.XYZ", "version": "1.0", "name": "DF_AFW_POV in Poverty/Monetary",
      "source": "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=WB.XYZ:DF_AFW_POV(1.0.0)",
      "target": "urn:sdmx:org.sdmx.infomodel.categoryscheme.Category=WB.XYZ:CS_THEMES(1.0.0).POVERTY.MONETARY" } ] }
```

- In JSON the version above is `"1.0"`, which matches the fixed 1.0 in [SV-ART Categorisation]. In XML, omit `version`.
- Minor wildcards are acceptable in the source reference; major wildcards in the target reference are not recommended [SV-ART/Artefacts with Fixed Versions/Categorisation.md].

---

## 13. Structure message envelope

**JSON** [JFG L15-L238], [JSCH L1-L60, L13 `meta`]:
- Root keys: `$schema` (recommended: `https://json.sdmx.org/2.1/sdmx-json-structure-schema.json`), `meta` (**required**), `data`, `errors`.
- `meta` requires `id` (IDType pattern), `prepared` (ISO date-time) and `sender {id}`. It optionally takes `test`, `contentLanguages`, `name`/`names`, `receivers[]` and `links[]`.
- `data` holds one **plural** array per artefact type, each with at least one item: `dataStructures`, `metadataStructures`, `categorySchemes`, `conceptSchemes`, `codelists`, `geographicCodelists`, `geoGridCodelists`, `valueLists`, `hierarchies`, `hierarchyAssociations`, `agencySchemes`, `dataProviderSchemes`, `dataConsumerSchemes`, `metadataProviderSchemes`, `organisationUnitSchemes`, `dataflows`, `metadataflows`, `reportingTaxonomies`, `provisionAgreements`, `metadataProvisionAgreements`, `structureMaps`, `representationMaps`, `conceptSchemeMaps`, `categorySchemeMaps`, `organisationSchemeMaps`, `reportingTaxonomyMaps`, `processes`, `categorisations`, `dataConstraints`, `availabilityConstraints`, `metadataConstraints`, `customTypeSchemes`, `vtlMappingSchemes`, `namePersonalisationSchemes`, `rulesetSchemes`, `transformationSchemes`, `userDefinedOperatorSchemes` (copied from the schema's `data.properties`).
- Every object is closed (`unevaluatedProperties: false`). Custom keys must start with `x-` [JFG L2133-L2153].

```json
{ "$schema": "https://json.sdmx.org/2.1/sdmx-json-structure-schema.json",
  "meta": { "id": "AFW_STRUCT_20260929", "prepared": "2026-09-29T10:00:00Z", "test": false,
            "contentLanguages": [ "en" ], "sender": { "id": "WB" } },
  "data": {
    "codelists": [ { "id": "CL_AREA", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "Areas", "names": { "en": "Areas" },
        "codes": [ { "id": "SEN", "name": "Senegal", "names": { "en": "Senegal" } } ] } ],
    "conceptSchemes": [ { "id": "CS_AFW", "agencyID": "WB.XYZ", "version": "1.0.0", "name": "AFW concepts", "names": { "en": "AFW concepts" },
        "concepts": [ { "id": "REF_AREA", "name": "Reference area", "names": { "en": "Reference area" },
            "coreRepresentation": { "enumeration": "urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.XYZ:CL_AREA(1.0.0)" } } ] } ] } }
```

**XML** [X:SDMXMessage.xsd L45, L343-L360], [X:SDMXStructure.xsd L38]:
- The root is `mes:Structure`. Its children are `mes:Header`, then `mes:Structures`?, then `footer:Footer`?.
- The header sequence is:
  1. `mes:ID` (IDType)
  2. `mes:Test` (boolean; the **element is required**)
  3. `mes:Prepared`
  4. `mes:Sender id` (with optional `com:Name`, `mes:Contact` and `mes:Timezone`)
  5. `mes:Receiver`*
  6. `com:Name`*
  7. `mes:Source`*
- `mes:Structures` uses `xs:all`, so containers may appear in **any order**: `str:AgencySchemes`, `str:Categorisations`, `str:CategorySchemes`, `str:Codelists`, `str:ConceptSchemes`, `str:DataConstraints`, `str:Dataflows`, `str:DataProviderSchemes`, `str:DataStructures`, `str:GeographicCodelists`, `str:GeoGridCodelists`, `str:MetadataProviderSchemes`, `str:MetadataProvisionAgreements`, `str:MetadataStructures`, `str:Metadataflows`, `str:ProvisionAgreements`, `str:ValueLists`, …

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mes:Structure xmlns:mes="http://www.sdmx.org/resources/sdmxml/schemas/v3_1/message"
    xmlns:str="http://www.sdmx.org/resources/sdmxml/schemas/v3_1/structure"
    xmlns:com="http://www.sdmx.org/resources/sdmxml/schemas/v3_1/common"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sdmx.org/resources/sdmxml/schemas/v3_1/message https://xml.sdmx.org/3.1/SDMXMessage.xsd">
  <mes:Header>
    <mes:ID>AFW_STRUCT_20260929</mes:ID><mes:Test>false</mes:Test>
    <mes:Prepared>2026-09-29T10:00:00Z</mes:Prepared><mes:Sender id="WB"/>
  </mes:Header>
  <mes:Structures>
    <str:Codelists>
      <str:Codelist agencyID="WB.XYZ" id="CL_AREA" version="1.0.0"><com:Name xml:lang="en">Areas</com:Name>
        <str:Code id="SEN"><com:Name xml:lang="en">Senegal</com:Name></str:Code></str:Codelist>
    </str:Codelists>
    <str:ConceptSchemes>
      <str:ConceptScheme agencyID="WB.XYZ" id="CS_AFW" version="1.0.0"><com:Name xml:lang="en">AFW concepts</com:Name>
        <str:Concept id="REF_AREA"><com:Name xml:lang="en">Reference area</com:Name>
          <str:CoreRepresentation><str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.XYZ:CL_AREA(1.0.0)</str:Enumeration></str:CoreRepresentation>
        </str:Concept></str:ConceptScheme>
    </str:ConceptSchemes>
  </mes:Structures>
</mes:Structure>
```

The `schemaLocation` value is the one used in the official samples [XS:Codelist/codelist.xml L7].

---

## 14. Validation

**SDMX-ML 3.1 XSDs.** All of them live in `sdmx-twg/sdmx-ml`, tag `v3.1.0`, folder **`schemas/`**: https://github.com/sdmx-twg/sdmx-ml/tree/v3.1.0/schemas. For a structure message, validate against `schemas/SDMXMessage.xsd`, which imports the others:
- `SDMXCommon.xsd`, `SDMXCommonReferences.xsd`
- `SDMXStructure.xsd`, `SDMXStructureBase.xsd`
- `SDMXStructureCodelist.xsd`, `SDMXStructureConcept.xsd`
- `SDMXStructureDataStructure.xsd`, `SDMXStructureDataflow.xsd`
- `SDMXStructureMetadataStructure.xsd`, `SDMXStructureMetadataflow.xsd`
- `SDMXStructureConstraint.xsd`, `SDMXStructureProvisionAgreement.xsd`
- `SDMXStructureOrganisation.xsd`, `SDMXStructureCategory.xsd`, `SDMXStructureCategorisation.xsd`
- `SDMXStructureHierarchicalCodelist.xsd`, `SDMXStructureStructureMappings.xsd`, `SDMXStructureTransformation.xsd`, `SDMXStructureProcess.xsd`, `SDMXStructureReportingTaxonomy.xsd`
- `SDMXMetadataGeneric.xsd`, `SDMXDataStructureSpecific.xsd`
- `SDMXMessageFooter.xsd`, `SDMXRegistry*.xsd`, `xml.xsd`

The samples point at `https://xml.sdmx.org/3.1/SDMXMessage.xsd`.

**SDMX-JSON 2.1 JSON Schema.** A schema exists:
- `sdmx-twg/sdmx-json`, tag `v2.1.0`, **`structure-message/tools/schemas/sdmx-json-structure-schema.json`**. Its `$id` is `https://json.sdmx.org/2.1/sdmx-json-structure-schema.json` and it uses draft 2019-09 [JSCH L1-L4].
- Metadata sets use `metadata-message/tools/schemas/sdmx-json-metadata-schema.json`, and data uses `data-message/tools/schemas/sdmx-json-data-schema.json`.

**Verification of this document (2026-09-29).**

JSON:
- Every complete JSON example in sections 5–13 was assembled into one structure message and validated with Python `jsonschema` 4.26 (`Draft201909Validator`) against the v2.1.0 structure schema, with **format assertion on**. It passed with 0 errors.
- The metadataset example passed the metadata-message schema.
- **Gotcha:** without format assertion, `meta.prepared` fails, because its `oneOf` of `format: date` and `format: date-time` matches both branches. Enable the format checker.
- Negative tests confirmed three restrictions:
  - `isMultilingual` (lowercase `l`) is rejected;
  - nested `codes` are rejected;
  - an AgencyScheme with `"version": "1.0.0"` is rejected.

XML (validated with `lxml` against the v3.1.0 XSDs, entry point `SDMXMessage.xsd`):
- These pass: the section 13 message, and the annotation, agency scheme, concept, codelist, codelist extension, dataflow, data constraint (DataKeySet plus CubeRegion) and metadataflow fragments, each wrapped in a message. An XML DSD equivalent of section 7.8 also passes; it covers `Dataflow`, `Dimension optional="true"`, `Observation`, `MeasureRelationship`, `MetadataAttributeUsage` and `str:Metadata`.
- These fail, as predicted:
  - a `TimeDimension` without `LocalRepresentation`;
  - a `Categorisation` with `version`;
  - `MemberValue` `Y15-24`;
  - a metadataset containing XHTML (no XHTML schema is available).

**What the schemas do not check** (a validator has to):
- Cross-references resolve (URNs point to existing artefacts; `parent` codes exist).
- Uniqueness of inherited component ids [JFG L406].
- Sub-agency declaration.
- The semver dependency rule.
- Dimension-constraint consistency.

---

## 15. Inconsistencies and unclear points (UNCERTAIN)

1. **UNCERTAIN: Constraint `role`.** The 3.1 XSD and JSON Schema have no `role` on DataConstraint; "actual" content is AvailabilityConstraint [X:SDMXStructureConstraint.xsd]. Other sources still show the 3.0 model:
   - IM `11_Constraints.md` still lists `role` and `ConstraintRoleType` (`allowableContent`/`actualContent`) [IM-CON L205-L213].
   - The TN examples use `type="Allowed"`, which the XSD rejects, and write `com:KeyValue` where it should be `str:KeyValue` [TN-CONS L449-L505].
   - The SDMX-ML Markdown `PART_III_STRUCTURE.md` documents `role` and `SimpleDataSource`/`QueryableDataSource` attachments that are not in the 3.1 XSD, and says nothing about `evolvingStructure` or `DimensionConstraint` [XDOC3 L2421-L2690].

   **Treat the XSDs as authoritative; the Markdown "documentation/" folder appears stale.**
2. **UNCERTAIN: AvailabilityConstraint identity.** The TN says it is not identifiable ("no URN"), and the XSD matches (it extends `AnnotableType`) [TN-CONS L13-L17]. The JSON guide and schema, however, give it `id`, `version`, `agencyID` and a `registry.AvailabilityConstraint` URN [JFG L1468-L1508].
3. **UNCERTAIN: nested metadata attributes in a DSD.**
   - The XSD `Metadata` doc and the JSON guide say the referenced MSD "cannot contain nested metadata attributes" [X:SDMXStructureDataStructure.xsd L48], [JFG L407].
   - The JSON schema description says "referenced metadata can also contain nested metadata attributes" [JSCH L3583], and the TN says "The hierarchy … must be respected" [TN-RM L189-L205].
   - XML `MetadataAttributeReference` is an `NCNameIDType` (no dots), while JSON is `NestedIDType` and its example is `"ATTR1.ATTR1-1"`.

   Safest choice: reference only top-level, non-nested metadata attributes.
4. **UNCERTAIN: TimeDimension `LocalRepresentation`.** It is required in XML [X:SDMXStructureDataStructure.xsd L396-L412] but "may be omitted" in JSON [JFG L763], [JSCH L5727]. Always emit it.
5. **UNCERTAIN: Categorisation version.** It is prohibited in XML and fixed to 1.0 in semver guidance, but the JSON schema allows any `VersionType` and the JSON example uses `"1.0.0"` [JFG L1400-L1413].
6. **UNCERTAIN: AgencyScheme version in JSON.** The schema forces `"1.0"` (`MaintainableWithoutVersionType`) [JSCH L979], but the field-guide example uses `"version": "1.0.0"` [JFG L1185-L1188]. The example would fail validation.
7. **UNCERTAIN: `isMultiLingual` spelling.** The schema key is `isMultiLingual`, while the guide examples write `"isMultilingual"` [JFG L364, L657]. With `unevaluatedProperties: false`, the example spelling fails. Use `isMultiLingual`.
8. **UNCERTAIN: guide typos and prose that disagree with the schema.**
   - `"evolvingStructure" false` is missing a colon, and `"metadadataStructureComponents"` is misspelled.
   - The MSD URN is shown as `metadatastructuredefinition.MetadataStructureDefinition`; the correct form is `metadatastructure.MetadataStructure`.
   - `agencyId` is used in the conceptScheme example [JFG L420, L877, L1016].
   - The guide lists `agencyID` as optional, while the schema requires it [JFG L245] vs [JSCH L940].
   - Line 406 of the guide names `REPORTING_PERIOD_START_DAY`, but other passages and the schema use `REPORTING_YEAR_START_DAY` [JFG L406, L485-L488].
9. **UNCERTAIN: nested `codes` in JSON.** The field guide allows recursive `codes` "for retrieval use cases" [JFG L1086], but `CodeType` is closed and has no `codes` property [JSCH `CodeType`]. Use a flat list with `parent`.
10. **UNCERTAIN: dimension `position` base.** It is 0-based per the guide [JFG L736]; the constructed JSON sample gives the first dimension `position: 1` [JSAMP]. Better omit `position`.
11. **CONFIRMED (likely a spec bug): XML `WildcardedMemberValueType` pattern** `[A-Za-z0-9_@$-%]+`. In XSD regex, `$-%` is a character *range*, so a literal `-` is not allowed in XML member values, although it is allowed in code IDs. lxml rejects `Y15-24` [X:SDMXStructureCodelist.xsd L134-L141]. JSON allows `-` and permits `%` only at the end.
12. **UNCERTAIN: URN class coverage differs.**
    - The XSD lacks `AvailabilityConstraint` but has `MetadataSet`.
    - The JSON structure `urn` pattern has `AvailabilityConstraint` but lacks `MetadataSet`.
    - The JSON *metadata* schema spells `Valuelist` with a lowercase `l` [JMSCH `urn`].
    - The IM table omits the geo codelists, which are written as `codelist.Codelist`.
    - The IM prose has typos: `DataStucture`, `urn:sdmx.org.sdmx…`, and `:` in Category examples [IM-ID L313, L463, L471].
13. **UNCERTAIN: Metadataset owner.** The IM says it is maintained by a *metadata provider*, with URN `metadataProviderId:metadataSetId(version)` [IM-ID L505], [TN-AG L3-L9]. Both schemas, however, use an `agencyID` field (XML `MaintainableType/@agencyID`; JSON `agencyID` "ID of the agency maintaining this metadata set") [X:SDMXMetadataGeneric.xsd L20-L30], [JMFG L228]. What to put there (provider id or agency id) is unclear.
14. **UNCERTAIN: stale TN reference-metadata examples.** They use 3.0-era element names that do not exist in the 3.1 XSD: `str:MetadataAttributeDescriptor`, `str:Targets`, `str:StructureUsage`, `str:MetadataProvision`, `md:AttributeSet`/`md:ReportedAttribute` and `@metadataProviderID` [TN-RM L40-L140]. Use the XSD names given in section 9.
15. **UNCERTAIN: Metadataflow `Target` cardinality.** It is required (1..n) in XML but optional in JSON [X:SDMXStructureMetadataflow.xsd L41-L50] vs [JSCH L4652]. The JSON metadata guide also says "One of … value, values, text or structuredText" is required, but only `value` exists in its schema [JMFG L305].
16. **UNCERTAIN: ReportingYearStartDay.** The JSON schema allows a `ReportingYearStartOrEndDayType` attribute, while the 3.1 XSD `AttributeList` has only `Attribute` and `MetadataAttributeUsage` (its unique-key selector still names `ReportingYearStartDay`) [JSCH `AttributeListType`], [X:SDMXStructureDataStructure.xsd L64-L110].
17. **UNCERTAIN: `decimals` minimum.** It is a positive integer (≥1) in both schemas, so "0 decimals" cannot be stated. Use `Integer`.
18. **UNCERTAIN: version of `SDMX:CL_SEX` and registration of `WB`.** Neither is in these repos. Before extending `SDMX:CL_SEX`, check whether its current version is semantic, because of the semver-only dependency rule.
19. **UNCERTAIN: `~` as a latest-version wildcard.** It is not defined in any of these sources for structure references (it may belong to the REST API; not verified). Inside structure files, use `+` wildcards only.
20. **UNCERTAIN: `GenericMetadataStructureType/ProvisionAgreement` type.** It is typed as a *data* `ProvisionAgreementReferenceType`, not as a MetadataProvisionAgreement reference [X:SDMXCommon.xsd `GenericMetadataStructureType`]. Use `StructureUsage` (the Metadataflow URN) in the metadata header.
21. **UNCERTAIN: semver guidance status.** The semver repo states that its guidance "differs from the existing annex … These guidelines will likely supersede the annex as part of the SDMX 3.2.0 release" [SV L6]. For 3.1 the two agree on syntax but differ in detail.
