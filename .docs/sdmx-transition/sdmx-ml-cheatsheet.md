# SDMX-ML 3.1 serialisation cheat-sheet

Distilled from the official XSDs of `sdmx-twg/sdmx-ml` tag `v3.1.0` and the SDMX-CSV 2.1.0 field guides, with the line citations in `research/R1_sdmx31_structures.md`. Where prose documentation and schemas disagree, the schemas win. Everything here was validated against the XSDs on 2026-09-29 and re-checked clause by clause at review round 1 (2026-09-29); nothing is marked UNCERTAIN any more.

## 1. Namespaces (3.1)

```
mes = http://www.sdmx.org/resources/sdmxml/schemas/v3_1/message
str = http://www.sdmx.org/resources/sdmxml/schemas/v3_1/structure
com = http://www.sdmx.org/resources/sdmxml/schemas/v3_1/common
md  = http://www.sdmx.org/resources/sdmxml/schemas/v3_1/metadata/generic
xsi:schemaLocation="http://www.sdmx.org/resources/sdmxml/schemas/v3_1/message https://xml.sdmx.org/3.1/SDMXMessage.xsd"
```

The 3.0 profile (FMR contingency) uses the same names with `v3_0`.

## 2. Structure message envelope

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mes:Structure xmlns:mes="..." xmlns:str="..." xmlns:com="..." xmlns:xsi="...">
  <mes:Header>
    <mes:ID>AFW360_STRUCTURES</mes:ID>          <!-- IDType: no dots -->
    <mes:Test>false</mes:Test>                 <!-- element required -->
    <mes:Prepared>2026-01-01T00:00:00Z</mes:Prepared>
    <mes:Sender id="WB_AFW360"><com:Name xml:lang="en">AFW DIP/POV team</com:Name></mes:Sender>
  </mes:Header>
  <mes:Structures>
    <!-- containers in any order (xs:all): -->
    <str:AgencySchemes/> <str:DataProviderSchemes/> <str:MetadataProviderSchemes/>
    <str:ConceptSchemes/> <str:Codelists/> <str:DataStructures/> <str:Dataflows/>
    <str:MetadataStructures/> <str:Metadataflows/>
    <str:ProvisionAgreements/> <str:MetadataProvisionAgreements/>
  </mes:Structures>
</mes:Structure>
```

Header child order: `ID`, `Test`, `Prepared`, `Sender`, `Receiver`*, `Name`*, `Source`*.

## 3. Identifiers, versions, URNs

| Thing | Rule |
|---|---|
| Code id | `[A-Za-z0-9_@$\-]+` (may start with `_` or a digit) |
| Codelist, concept scheme, concept, agency, component, metadata attribute id | NCName: `[A-Za-z][A-Za-z0-9_\-]*` (no dot) |
| `agencyID` | dotted NCNames allowed: `WB.AFW360`; each segment starts with a letter |
| Header `ID`, Sender `id` | plain IDType, no dot |
| Version | semver `X.Y.Z` (`0.3.0` ok, no leading zeros); extension `-draft`; a released `X.Y.Z` is immutable; a semver artefact may reference only semver artefacts (IM technical notes, Annex "Semantic Versioning", "Dependency Management"; not enforced by the XSD). Exception applied by this project: references to items of the fixed-version organisation schemes (`AGENCIES`, `DATA_PROVIDERS`, `METADATA_PROVIDERS`, URN version `(1.0)`) are allowed, because the XSD patterns `DataProviderUrnType` and `MetadataProviderUrnType` require exactly that version |
| Fixed-version artefacts | `AgencyScheme` (id `AGENCIES`), `DataProviderScheme` (`DATA_PROVIDERS`), `MetadataProviderScheme` (`METADATA_PROVIDERS`): **omit the `version` attribute in XML**; `Categorisation` likewise (not used) |
| URN | `urn:sdmx:org.sdmx.infomodel.<package>.<Class>=<agency>:<id>(<version>)[.<item>]` |
| Packages and classes | `base.AgencyScheme|Agency|DataProviderScheme|DataProvider|MetadataProviderScheme|MetadataProvider`; `codelist.Codelist|Code`; `conceptscheme.ConceptScheme|Concept`; `datastructure.DataStructure|Dataflow|Dimension|TimeDimension|Measure|DataAttribute`; `metadatastructure.MetadataStructure|Metadataflow|MetadataAttribute|MetadataSet`; `registry.ProvisionAgreement|MetadataProvisionAgreement|DataConstraint` |
| Fixed-version item URN | `...base.Agency=WB:AGENCIES(1.0).AFW360`, `...base.DataProvider=WB.AFW360:DATA_PROVIDERS(1.0).AFW_POV` |
| Short form (CSV messages only) | `WB.AFW360:AFW360_HH(0.3.0)`; version may be omitted for non-versioned artefacts |
| Reserved component ids | `TIME_PERIOD` (time dimension only), `REPORTING_YEAR_START_DAY` |

## 4. Common child order

Every artefact and item: `com:Annotations`?, `com:Link`*, `com:Name`+, `com:Description`*, then type-specific children. **Annotations always come first.** Every Nameable (maintainables and items) requires at least one `Name`. Components (Dimension, Measure, Attribute, MetadataAttribute) have no Name.

```xml
<com:Annotations>
  <com:Annotation id="AFW_STATUS">
    <com:AnnotationType>AFW_STATUS</com:AnnotationType>   <!-- order: Title?, Type?, URL*, Text*, Value? -->
    <com:AnnotationValue>DRAFT</com:AnnotationValue>
  </com:Annotation>
</com:Annotations>
<com:Name xml:lang="en">Poverty headcount</com:Name>
<com:Description xml:lang="en">Share of ...</com:Description>
```

## 5. Agency and provider schemes

```xml
<str:AgencyScheme agencyID="WB" id="AGENCIES">           <!-- no version -->
  <com:Name xml:lang="en">World Bank agencies</com:Name>
  <str:Agency id="AFW360"><com:Name xml:lang="en">West Africa Micro Data 360</com:Name></str:Agency>
</str:AgencyScheme>
<str:DataProviderScheme agencyID="WB.AFW360" id="DATA_PROVIDERS">
  <com:Name xml:lang="en">AFW 360 data providers</com:Name>
  <str:DataProvider id="AFW_POV"><com:Name xml:lang="en">AFW DIP/POV team</com:Name></str:DataProvider>
</str:DataProviderScheme>
<str:MetadataProviderScheme agencyID="WB.AFW360" id="METADATA_PROVIDERS"> ... <str:MetadataProvider id="AFW_POV"> ... </str:MetadataProviderScheme>
```

## 6. Concept scheme

```xml
<str:ConceptScheme agencyID="WB.AFW360" id="CS_AFW360" version="0.3.0">
  <com:Name xml:lang="en">AFW 360 concepts</com:Name>
  <str:Concept id="REF_AREA">
    <com:Annotations>...</com:Annotations>
    <com:Name xml:lang="en">Reference area</com:Name>
    <com:Description xml:lang="en">...</com:Description>
    <str:CoreRepresentation>
      <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.AFW360:CL_AREA(0.3.0)</str:Enumeration>
    </str:CoreRepresentation>
  </str:Concept>
  <str:Concept id="OBS_VALUE"><com:Name xml:lang="en">Observation value</com:Name>
    <str:CoreRepresentation><str:TextFormat textType="Double"/></str:CoreRepresentation></str:Concept>
</str:ConceptScheme>
```

Concept child order: Annotations, Link, Name+, Description*, `Parent`?, `CoreRepresentation`?, `ISOConceptReference`?. `CoreRepresentation` holds either `TextFormat` or `Enumeration` (+ `EnumerationFormat`?). Facet attributes: `textType` (String, Double, Integer, GregorianYear, ObservationalTimePeriod, ...), `minValue`, `maxValue`, `minLength`, `maxLength`, `pattern`, `decimals` (must be at least 1; use Integer for "no decimals"), `isMultiLingual`.

## 7. Codelist

```xml
<str:Codelist agencyID="WB.AFW360" id="CL_SEX" version="0.3.0">
  <com:Annotations>
    <com:Annotation id="AFW_SOURCE_FILE"><com:AnnotationType>AFW_SOURCE_FILE</com:AnnotationType>
      <com:AnnotationValue>metadata/codelists/CL_SEX.csv</com:AnnotationValue></com:Annotation>
  </com:Annotations>
  <com:Name xml:lang="en">Sex</com:Name>
  <str:Code id="F"><com:Annotations>...</com:Annotations>
    <com:Name xml:lang="en">Female</com:Name><com:Description xml:lang="en">...</com:Description></str:Code>
  <str:Code id="OU"><com:Name xml:lang="en">Other urban</com:Name><str:Parent>U</str:Parent></str:Code>
  <str:Code id="_T"><com:Name xml:lang="en">Total</com:Name></str:Code>
</str:Codelist>
```

Code child order: Annotations, Link, Name+, Description*, `Parent`?. `Parent` is the id of a code in the same codelist. Flat list; hierarchy only through `Parent`. Codelist extension exists (`str:CodelistExtension` after the codes) but is not used: global lists are legacy-versioned.

## 8. Data structure definition

```xml
<str:DataStructure agencyID="WB.AFW360" id="DSD_AFW360_HH" version="0.3.0">
  <com:Name xml:lang="en">AFW 360 household survey indicators</com:Name>
  <str:DataStructureComponents>
    <str:DimensionList id="DimensionDescriptor">
      <str:Dimension id="FREQ">
        <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=WB.AFW360:CS_AFW360(0.3.0).FREQ</str:ConceptIdentity>
        <str:LocalRepresentation>
          <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.AFW360:CL_FREQ(0.3.0)</str:Enumeration>
        </str:LocalRepresentation>
      </str:Dimension>
      <!-- ... 17 more dimensions in key order; omit the position attribute ... -->
      <str:TimeDimension id="TIME_PERIOD">
        <str:ConceptIdentity>urn:...Concept=WB.AFW360:CS_AFW360(0.3.0).TIME_PERIOD</str:ConceptIdentity>
        <str:LocalRepresentation><str:TextFormat textType="GregorianYear"/></str:LocalRepresentation>  <!-- REQUIRED in XML -->
      </str:TimeDimension>
    </str:DimensionList>
    <str:AttributeList id="AttributeDescriptor">
      <str:Attribute id="SERIES_ID" usage="mandatory">
        <str:ConceptIdentity>urn:...Concept=WB.AFW360:CS_AFW360(0.3.0).SERIES_ID</str:ConceptIdentity>
        <str:LocalRepresentation><str:Enumeration>urn:...Codelist=WB.AFW360:CL_SERIES(0.3.0)</str:Enumeration></str:LocalRepresentation>
        <str:AttributeRelationship>
          <str:Dimension>INDICATOR</str:Dimension><str:Dimension>COMP_BREAKDOWN_1</str:Dimension> <!-- ... -->
        </str:AttributeRelationship>
      </str:Attribute>
      <str:Attribute id="OBS_STATUS" usage="mandatory">
        <str:ConceptIdentity>...</str:ConceptIdentity>
        <str:LocalRepresentation><str:Enumeration>...CL_OBS_STATUS(0.3.0)</str:Enumeration></str:LocalRepresentation>
        <str:AttributeRelationship><str:Observation/></str:AttributeRelationship>
        <str:MeasureRelationship><str:Measure>OBS_VALUE</str:Measure></str:MeasureRelationship>
      </str:Attribute>
      <str:Attribute id="PRECISION" usage="optional">
        <str:ConceptIdentity>...</str:ConceptIdentity>
        <str:LocalRepresentation><str:TextFormat textType="Double" minValue="0"/></str:LocalRepresentation>
        <str:AttributeRelationship><str:Observation/></str:AttributeRelationship>
      </str:Attribute>
    </str:AttributeList>
    <str:MeasureList id="MeasureDescriptor">
      <str:Measure id="OBS_VALUE" usage="mandatory">
        <str:ConceptIdentity>...</str:ConceptIdentity>
        <str:LocalRepresentation><str:TextFormat textType="Double"/></str:LocalRepresentation>
      </str:Measure>
      <str:Measure id="N_OBS" usage="optional"> ... <str:TextFormat textType="Integer" minValue="0"/> ... </str:Measure>
    </str:MeasureList>
  </str:DataStructureComponents>
</str:DataStructure>
```

Rules: `DataStructureComponents` child order is `DimensionList`, `Group`*, `AttributeList`?, `MeasureList`?. Dimension child order: Annotations, Link, `ConceptIdentity`, `LocalRepresentation`?, `ConceptRole`*. Attribute: Annotations, Link, `ConceptIdentity`, `LocalRepresentation`?, `ConceptRole`*, `AttributeRelationship` (exactly one of `Dataflow/`, `Dimension`+ with optional attribute `optional="true"`, `Group`, `Observation/`), `MeasureRelationship`?. Measure: attribute `usage` (`mandatory|optional`, default optional); children `ConceptIdentity`, `LocalRepresentation`?, `ConceptRole`*. Dimensions may reference a `Codelist` only (never a ValueList). `usage` default is `optional`. Component ids must be unique across dimensions, measures and attributes.

## 9. Dataflow and provision agreement

```xml
<str:Dataflow agencyID="WB.AFW360" id="AFW360_HH" version="0.3.0">
  <com:Name xml:lang="en">AFW 360 household survey indicators</com:Name>
  <str:Structure>urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=WB.AFW360:DSD_AFW360_HH(0.3.0)</str:Structure>
</str:Dataflow>
<str:ProvisionAgreement agencyID="WB.AFW360" id="PA_AFW360_HH" version="0.3.0">
  <com:Name xml:lang="en">AFW 360 household data provision</com:Name>
  <str:Dataflow>urn:...Dataflow=WB.AFW360:AFW360_HH(0.3.0)</str:Dataflow>
  <str:DataProvider>urn:sdmx:org.sdmx.infomodel.base.DataProvider=WB.AFW360:DATA_PROVIDERS(1.0).AFW_POV</str:DataProvider>
</str:ProvisionAgreement>
```

No `DimensionConstraint` and no `evolvingStructure` (both 3.1 features, not used).

## 10. Metadata structure, metadataflow, metadata provision agreement

```xml
<str:MetadataStructure agencyID="WB.AFW360" id="MSD_AFW360" version="0.3.0">
  <com:Name xml:lang="en">AFW 360 reference metadata</com:Name>
  <str:MetadataStructureComponents>
    <str:MetadataAttributeList id="MetadataAttributeDescriptor">
      <str:MetadataAttribute id="SURVEY" minOccurs="0" maxOccurs="1" isPresentational="true">
        <str:ConceptIdentity>urn:...Concept=WB.AFW360:CS_AFW360(0.3.0).SURVEY</str:ConceptIdentity>
        <str:MetadataAttribute id="SURVEY_NAME" minOccurs="0">
          <str:ConceptIdentity>urn:...Concept=WB.AFW360:CS_AFW360(0.3.0).SURVEY_NAME</str:ConceptIdentity>
          <str:LocalRepresentation><str:TextFormat textType="String"/></str:LocalRepresentation>
        </str:MetadataAttribute>
      </str:MetadataAttribute>
    </str:MetadataAttributeList>
  </str:MetadataStructureComponents>
</str:MetadataStructure>
<str:Metadataflow agencyID="WB.AFW360" id="MDF_AFW360" version="0.3.0">
  <com:Name xml:lang="en">AFW 360 reference metadata flow</com:Name>
  <str:Structure>urn:...MetadataStructure=WB.AFW360:MSD_AFW360(0.3.0)</str:Structure>
  <str:Target>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.AFW360:CL_SURVEY(0.3.0)</str:Target>
  <str:Target>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.AFW360:CL_SOURCE(0.3.0)</str:Target>
  <str:Target>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.AFW360:CL_FIGURE(0.3.0)</str:Target>
  <str:Target>urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=WB.AFW360:AFW360_HH(0.3.0)</str:Target>
  <!-- Target: common:WildcardUrnType, 1..n (SDMXStructureMetadataflow.xsd). Wildcards such as Codelist=WB.AFW360:*(*) are also schema-valid but not used. -->
</str:Metadataflow>
<str:MetadataProvisionAgreement agencyID="WB.AFW360" id="MPA_AFW360" version="0.3.0">
  <com:Name xml:lang="en">AFW 360 metadata provision</com:Name>
  <str:Metadataflow>urn:...Metadataflow=WB.AFW360:MDF_AFW360(0.3.0)</str:Metadataflow>
  <str:MetadataProvider>urn:sdmx:org.sdmx.infomodel.base.MetadataProvider=WB.AFW360:METADATA_PROVIDERS(1.0).AFW_POV</str:MetadataProvider>
</str:MetadataProvisionAgreement>
```

MetadataAttribute: attributes `id`, `minOccurs` (default 1), `maxOccurs` (default 1 or `unbounded`), `isPresentational` (default false); children Annotations, Link, `ConceptIdentity`, `LocalRepresentation`? (Codelist enumeration or `TextFormat`; no min/maxOccurs inside), nested `MetadataAttribute`*. Presentational parents need `minOccurs="0"` explicitly (the default is 1). An MSD has no targets in 3.x; targets live on the Metadataflow and the MPA.

## 11. Validation

- XSDs: `sdmx-twg/sdmx-ml` tag `v3.1.0`, folder `schemas/`, entry `SDMXMessage.xsd` (imports the rest; keep the whole folder together, including `xml.xsd`).
- R: `xml2::xml_validate(doc, xml2::read_xml("pipeline/xsd/sdmx-ml-3.1/SDMXMessage.xsd"))`.
- Python: `lxml.etree.XMLSchema(etree.parse(".../SDMXMessage.xsd")).assertValid(doc)`.
- Schemas do not check: URN resolution, `Parent` existence, sub-agency declaration, component-id uniqueness across inherited concept ids, the semver dependency rule. The project's `SDMX.URN` check covers these (exempting the `(1.0)` organisation-scheme items, section 3), and `SDMX.IDENT` checks agency, semver version, `IDType` id and English name on every maintainable.

## 12. Pitfalls verified against the XSDs

1. `TimeDimension` without `LocalRepresentation` fails.
2. `version` on `AgencyScheme`, `DataProviderScheme`, `MetadataProviderScheme`, `Categorisation` fails.
3. `Annotations` must precede `Name`; `Name` must precede `Description`.
4. Codelist extension `MemberValue` rejects `-` (schema bug); not relevant (no extensions).
5. XHTML inside `com:StructuredText` fails strict validation because no XHTML schema ships; use `com:Text` or keep text out of XML (we keep reference metadata in CSV).
6. `decimals` facet minimum is 1.
7. `mes:Test` element is required in the header.
8. Header `ID` and `Sender/@id` cannot contain dots.

## 13. SDMX-CSV 2.1 data message (for the writer and the validator)

- Header: `STRUCTURE,STRUCTURE_ID,ACTION,<dimensions in DSD order, TIME_PERIOD last>,<measures in DSD order>,<attributes in DSD order>` (the guide's recommended order for responses; any order is valid on upload; the XML order AttributeList-before-MeasureList is not the CSV order). `STRUCTURE[;]` is required only when multi-valued or multi-language measure or attribute values occur (none here).
- Row: `dataflow,WB.AFW360:AFW360_HH(0.3.0),R,...`.
- Actions: `M` merge, `R` replace, `D` delete; `I` and `A` deprecated (treated as merge). Project: `R`.
- Intentionally missing: `NaN` for float or double measures, `#N/A` for other types. Empty cell means omitted.
- Separator: comma; decimal point; RFC 4180 quoting; fields with commas, quotes or newlines are quoted, inner quotes doubled.
- Rows for attributes attached to partial keys may carry only the key subset (not used: every row is an observation).

## 14. SDMX-CSV 2.1 metadata message

- Header: `MDSTRUCTURE,MDSTRUCTURE_ID,METADATASET_ID,[IS_PARTIAL_LANGUAGE,]TARGET_TYPES,TARGET_IDS,<attribute columns>`; nested attribute columns are dotted: `SURVEY.SURVEY_NAME`; multi-instance attributes get `[]`; multilingual ones `[en;fr]` (none here); `MDSTRUCTURE[;]` only when sub-fields are needed.
- Row: `"metadataflow","WB.AFW360:MDF_AFW360(0.3.0)","WB.AFW360:MDS_SURVEY_SEN_EHCVM_2021","codelist","WB.AFW360:CL_SURVEY(0.3.0)",...` (every textual value quoted).
- The `ACTION` column is deprecated (omit). Metadataset ids without a version are non-versioned.
- `TARGET_TYPES` uses REST resource names (`dataflow`, `codelist`, ...); `TARGET_IDS` is `AGENCY:ID(VERSION)`; multiple targets separated by the sub-field separator. Targets are whole artefacts only; SDMX-CSV 2.1 has no item-level (single code) target form. Presentational parent attributes have no column; only `PARENT.CHILD` columns appear.
- Textual values should always be quoted (the guide's recommendation; the writer uses `readr::write_csv(quote = "all", na = "")`); quotes doubled; line breaks allowed inside quoted fields.
