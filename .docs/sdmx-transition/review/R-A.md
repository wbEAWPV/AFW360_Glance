# R-A: SDMX-ML 3.1 structural conformance

Reviewer R-A. Scope: plan.md 2.1, 2.4, 2.5, 2.6, 2.8, 2.9 (lines 56-64, 130-229) and all of sdmx-ml-cheatsheet.md.
Primary sources: `sdmx-twg/sdmx-ml` tag `v3.1.0`, `schemas/*.xsd`, fetched with `curl --ssl-no-revoke` from
`https://raw.githubusercontent.com/sdmx-twg/sdmx-ml/v3.1.0/schemas/<file>.xsd` (cited below as `<file>:<line>`; line numbers are of the raw file),
plus the SDMX 3.x technical notes in `sdmx-twg/sdmx-im` (`docs/technical_notes/13_ANNEX_Semantic_Versioning.md`, `7_Maintenance_Agencies_and_Metadata_Providers.md`).
Note: the id, version and URN simple types live in `SDMXCommonReferences.xsd` (included by `SDMXCommon.xsd:8`), not in `SDMXCommon.xsd` itself.

### R-A-1
Severity: major
Where: sdmx-ml-cheatsheet.md section 3, "Version" row, and section 11 last bullet; plan.md section 2.8 (line ~221)
Claim: The rule "a semver artefact may reference only semver artefacts" is IM prose, not in the XSD, and applied literally it flags the plan's own ProvisionAgreement and MetadataProvisionAgreement, which must reference providers in fixed-version (`1.0`, legacy two-part) schemes.
Evidence: Rule text: https://raw.githubusercontent.com/sdmx-twg/sdmx-im/master/docs/technical_notes/13_ANNEX_Semantic_Versioning.md lines 205-206, "Semantically versioned artefacts MUST only reference other semantically versioned artefacts." (section "Dependency Management in SDMX 3.0(.0)", line 180), repeated at lines 436-441 ("non-semantically-versioned artefacts ... should not be referenced by semantically versioned artefacts"). No XSD pattern enforces it (checked the reference types in `SDMXCommonReferences.xsd`). The fixed version is mandated by the XSD: `SDMXCommonReferences.xsd:282` `DataProviderUrnType` pattern `.+\.base\.DataProvider=.+:DATA_PROVIDERS\(1\.0\).+` and `:300` `MetadataProviderUrnType` `...:METADATA_PROVIDERS\(1\.0\).+`; `7_Maintenance_Agencies_and_Metadata_Providers.md` lines 23-24 "cannot be versioned and thus have a fixed version set to '1.0'". The annex has no exemption for organisation schemes (grep for provider/agenc/organisation found none).
Fix: In cheatsheet section 3 replace "a semver artefact may reference only semver artefacts" with "a semver artefact may reference only semver artefacts (IM rule, technical notes Annex 'Semantic Versioning', 'Dependency Management'; not in the XSD). Exception applied by this project: references to items of the fixed-version organisation schemes (`AGENCIES`, `DATA_PROVIDERS`, `METADATA_PROVIDERS`, URN version `(1.0)`) are allowed, because SDMX forbids versioning those schemes." Add the same exception to the `SDMX.URN` check description in cheatsheet section 11 and to plan 2.8: "The PA and MPA reference `DATA_PROVIDERS(1.0)` and `METADATA_PROVIDERS(1.0)`; the semver dependency check exempts these."

### R-A-2
Severity: major
Where: sdmx-ml-cheatsheet.md section 10 (Target line and "wildcard syntax ... (UNCERTAIN)"); plan.md section 2.7 Metadataflow bullet (the open item)
Claim: The open item is resolved: `Metadataflow/Target` is `common:WildcardUrnType`, at least one is required, and both the wildcard `urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.AFW360:*(*)` and explicit artefact URNs are schema-valid; explicit URNs should be used.
Evidence: `SDMXStructureMetadataflow.xsd` `MetadataflowType`: `<xs:element name="Target" type="common:WildcardUrnType" maxOccurs="unbounded">` (no minOccurs, so minOccurs=1). `WildcardUrnType` (`SDMXCommonReferences.xsd:193`) derives through `WildcardUrnVersionPart` (`:161`, adds `.+\(\*\).*`), `WildcardUrnMaintainableIdPart` (`:128`, adds `.+:\*\([0-9A-Za-z\-\.\+\*]+\)[^(\(\))]*`), `WildcardUrnAgencyPart` (`:109`, agency NestedNCName or `*`), `UrnClassesPart` (`:23`, includes `.+\.codelist\.Codelist=.+` and `.+\.datastructure\.Dataflow=.+`) and `UrnPrefixPart` (`:14`); final facet `.+\)(\.[A-Za-z0-9_@$\-]+(\.[A-Za-z0-9_@$\-]+)*)?` or `.+\)(\.\*(\.\*)*)?`. I evaluated every level's patterns in Python (`re.fullmatch`; one pattern per level must match, levels ANDed as XSD derivation requires) and got True for `...Codelist=WB.AFW360:*(*)`, `...Codelist=WB.AFW360:CL_SURVEY(0.3.0)`, `...Dataflow=WB.AFW360:AFW360_HH(0.3.0)` and `...Code=WB.AFW360:CL_SURVEY(0.3.0).*`. `MetadataProvisionAgreement/Target` has the same type with `minOccurs="0"` (`SDMXStructureProvisionAgreement.xsd`, `MetadataProvisionAgreementType`).
Fix: Replace the cheatsheet Target line with:
```xml
  <str:Target>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.AFW360:CL_SURVEY(0.3.0)</str:Target>
  <str:Target>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.AFW360:CL_SOURCE(0.3.0)</str:Target>
  <str:Target>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.AFW360:CL_FIGURE(0.3.0)</str:Target>
  <str:Target>urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=WB.AFW360:AFW360_HH(0.3.0)</str:Target>
  <!-- Target: common:WildcardUrnType, 1..n (SDMXStructureMetadataflow.xsd). Wildcards such as Codelist=WB.AFW360:*(*) are also schema-valid but not used. -->
```
If `MDS_TEXT` keeps targeting `CL_AREA` rather than the dataflow, add `<str:Target>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=WB.AFW360:CL_AREA(0.3.0)</str:Target>`. In plan 2.7 replace "(wildcard URNs; the implementer confirms the exact wildcard syntax against the XSD `WildcardUrnType` and records it)" with "(explicit URNs, one per targeted artefact: codelists `CL_SURVEY`, `CL_SOURCE`, `CL_FIGURE` and dataflow `AFW360_HH`, all `(0.3.0)`; `Target` is `common:WildcardUrnType` with at least one required; wildcards are schema-valid but not used)". The generator must rewrite these versions on each release, like every other reference.

### R-A-3
Severity: major
Where: plan.md section 2.7, MSD bullet (line ~197; adjacent to my scope, raised under check 5)
Claim: The plan states `minOccurs=0` only for the child attributes; the four presentational parents also need `minOccurs="0"`, because the default is 1 and each metadataset fills only one of the four parents.
Evidence: `SDMXStructureMetadataStructure.xsd`, `MetadataAttributeType`: `<xs:attribute name="minOccurs" type="xs:nonNegativeInteger" default="1">`, `maxOccurs` `common:OccurenceType` `default="1"`, `isPresentational` `default="false"`. The cheatsheet example (section 10) already sets `minOccurs="0"` on `SURVEY`, so plan and cheatsheet disagree.
Fix: In plan 2.7 replace "with four presentational parent attributes, each with one child per source column (minus the id and `status` columns), all `String`, `minOccurs=0`:" with "with four presentational parent attributes (`isPresentational="true"`, `minOccurs="0"`, `maxOccurs="1"`, no `LocalRepresentation`), each with one child per source column (minus the id and `status` columns); children have `TextFormat textType="String"`, `minOccurs="0"`, `maxOccurs="1"`:".

### R-A-4
Severity: minor
Where: plan.md section 2.4, table lead-in "Components, in data-file order" (line ~132); cheatsheet section 13 "component ids in DSD order"
Claim: The table order (dimensions, time, measures, attributes) is not the XML order, because `DataStructureComponents` requires `AttributeList` before `MeasureList`, so "DSD order" is ambiguous between the XML serialisation and the CSV column order.
Evidence: `SDMXStructureDataStructure.xsd`, `DataStructureComponentsType`: sequence `DimensionList`, `Group` 0..n, `AttributeList` 0..1, `MeasureList` 0..1.
Fix: In plan 2.4, after the table, add: "In SDMX-ML the writer emits `DimensionList` (rows 1-19), then `AttributeList` (rows 29-34), then `MeasureList` (rows 20-28), as the XSD requires; the Pos column is the CSV column order only." In cheatsheet section 13 replace "`<component ids in DSD order>`" with "`<component ids in the order of the plan 2.4 Pos column (dimensions, time, measures, attributes)>`".

### R-A-5
Severity: minor
Where: plan.md section 2.6, last sentence (line ~187)
Claim: The core-representation rule does not cover `TIME_PERIOD`, which is neither coded, numeric nor text.
Evidence: `SDMXStructureConcept.xsd` `ConceptRepresentation` allows a `TextFormat` of `BasicComponentTextFormatType`, whose `textType` enumeration (`common:BasicComponentDataType`, `SDMXCommon.xsd`) includes `GregorianYear`.
Fix: Append: "`TIME_PERIOD` carries `TextFormat textType="GregorianYear"`, the same as its time-dimension local representation."

### R-A-6
Severity: minor
Where: plan.md section 2.5, Sentinels bullet (line ~169)
Claim: `GLOBAL_CODE` for sentinels is given in the short form `SDMX:CL_SEX(2.1)._T`, while every other `global_urn` (for example the plan 2.9 CL_AREA row) is a full URN.
Evidence: plan.md 2.9 CL_AREA row: `urn:sdmx:org.sdmx.infomodel.codelist.Code=WB:CL_REF_AREA_WDI(1.0).SEN`.
Fix: Replace "pointing at `SDMX:CL_SEX(2.1)._T` or `._Z`" with "with value `urn:sdmx:org.sdmx.infomodel.codelist.Code=SDMX:CL_SEX(2.1)._T` (or `._Z`)".

### R-A-7
Severity: minor
Where: plan.md section 2.1, first bullet (line 58); cheatsheet section 5
Claim: Uncertain: shipping an `AgencyScheme agencyID="WB" id="AGENCIES"` asserts WB's single agency scheme; if WB (for example a Data360 FMR) publishes its own `WB:AGENCIES`, the two collide, because an agency may maintain only one `AgencyScheme`.
Evidence: `7_Maintenance_Agencies_and_Metadata_Providers.md` lines 25-26: "There can be only one `AgencyScheme` maintained by any one Agency. It has a fixed Id of 'AGENCIES'." Lines 15-16: the scheme's maintainer must itself be declared in another scheme; WB is in `SDMX:AGENCIES` (`https://registry.sdmx.org/sdmx/v2/structure/agencyscheme/SDMX/AGENCIES/~/WB` returned `"id":"WB","name":"World Bank (WB)"`), and `.../agencyscheme/WB/AGENCIES/~` returned 404 on the global registry, so there is no conflict there today. Schema-wise the element is correct: `SDMXStructureOrganisation.xsd` `AgencySchemeType` `id` fixed `AGENCIES`, `version` prohibited; `Agency/@id` is `NCNameIDType`; `agencyID` is `NestedNCNameIDType` `[A-Za-z][A-Za-z0-9_\-]*(\.[A-Za-z][A-Za-z0-9_\-]*)*`, so `WB.AFW360` is legal; the Agency URN `urn:sdmx:org.sdmx.infomodel.base.Agency=WB:AGENCIES(1.0).AFW360` matches `AgencyUrnType` (`SDMXCommonReferences.xsd:246`).
Fix: Add to plan 2.1: "The `WB:AGENCIES` scheme is a local declaration for self-contained validation. Before loading into any WB registry, check whether WB already maintains `WB:AGENCIES`; if it does, have `AFW360` added there and drop our copy."

## Verified OK

Check 1 (element names, order, cardinality), all against the v3.1.0 XSDs:
- `mes:Structure` = `Header` (`StructureHeaderType`), `Structures` 0..1, `Footer` 0..1 (`SDMXMessage.xsd` `StructureType`). Header order `ID`, `Test` (required, xs:boolean), `Prepared`, `Sender`, `Receiver`*, `Name`*, `Source`*. Sender `id` is `IDType`, required; its `Name` is 0..n.
- `Structures` is an `xs:all` of optional containers (`SDMXStructure.xsd:42`), so container order is free.
- Common order Annotations?, Link*, Name+, Description* on maintainables (`SDMXCommon.xsd` `MaintainableBaseType`) and items; components have no Name.
- Annotation child order `AnnotationTitle`?, `AnnotationType`? (xs:string, free text), `AnnotationURL`*, `AnnotationText`*, `AnnotationValue`? (xs:string); `Annotation/@id` is optional xs:string. `AnnotationValue` also exists in v3.0.0 (`SDMXCommon.xsd:240` at tag v3.0.0), so the 3.0 contingency is unaffected. The plan 2.5 annotation form is conformant.
- Codelist `id` is `NCNameIDType`; `Code/@id` is `IDType` (`_T`, `_Z` and `SEN_ADM1` are legal); Code children Annotations, Link, Name+, Description*, `Parent`? (`IDType`); `CodelistExtension` comes after the codes.
- Concept: `id` NCName; then Parent? (NCName), `CoreRepresentation`? (`TextFormat`, or `Enumeration` plus optional `EnumerationFormat`), `ISOConceptReference`?.
- DSD: `DataStructureComponents` = DimensionList, Group*, AttributeList?, MeasureList?; DimensionList = `Dimension`+ then `TimeDimension`?; list ids are fixed (`DimensionDescriptor`, `AttributeDescriptor`, `MeasureDescriptor`) and optional.
- Dataflow: `Structure` (`DataStructureReferenceType`, URN as element text) 0..1, then `DimensionConstraint`?. ProvisionAgreement: `Dataflow`, `DataProvider` (URN text, not a `Ref` child). MPA: `Metadataflow`, `MetadataProvider`, `Target`*. Both are ordinary maintainables with `version` allowed.
- Organisation schemes: `version` prohibited on `AgencyScheme`, `DataProviderScheme` and `MetadataProviderScheme`; ids fixed to `AGENCIES`, `DATA_PROVIDERS`, `METADATA_PROVIDERS`; item URNs must carry `(1.0)`.

Check 2: `IDType` `[A-Za-z0-9_@$\-]+`; `NCNameIDType` `[A-Za-z][A-Za-z0-9_\-]*`; `NestedNCNameIDType` as above. Maintainable `id` is generally `IDType` (NCName only for Codelist and ConceptScheme), so the plan 2.1 NCName rule is a stricter project rule and fine. Semver pattern (`SemanticVersionNumberType`): `0.3.0` and `0.3.0-draft` are valid, `00.3.0` is invalid. Header `ID` and `Sender/@id` are `IDType`, so no dots: `WB_AFW360` and `AFW360_STRUCTURES` are right. Sub-agency semantics match technical note 7 (agency `AFW360` in `WB:AGENCIES`, referred to as `WB.AFW360`).

Check 3: `Dimension/@position` is optional (xs:int), so omitting it is fine. `TimeDimension` `LocalRepresentation` is required, with `TextFormat` required inside; `textType` is `TimeDataType` (default `ObservationalTimePeriod`) and `GregorianYear` is a member; `position` is prohibited; id is fixed to `TIME_PERIOD`. Measure and Attribute `usage` are `mandatory|optional`, default `optional`. `AttributeRelationship` is a choice of `Dataflow`, `Dimension`+ (NCName, with an `optional` flag), `Group` or `Observation`; `MeasureRelationship` = `Measure`+ (NCName). `minValue` (xs:decimal) is allowed on `BasicComponentTextFormatType`, which measures, attributes and concepts use, so `Double`/`Integer` with `minValue="0"` are legal; it is prohibited only on the time dimension. Dimension enumerations must be a `Codelist` (not a ValueList). 18 dimensions + time + 9 measures + 6 attributes: all lists are unbounded.

Check 4: see R-A-1 (IM annex prose only; not in the XSD).

Check 5: an MSD has no target elements (`MetadataStructureComponents` = `MetadataAttributeList` only); `MetadataAttribute` nests `MetadataAttribute`*; its `minOccurs` defaults to 1, `maxOccurs` to 1 and `isPresentational` to false; `LocalRepresentation` prohibits min/maxOccurs. Cheatsheet section 10 is correct on these points.

Check 6: see R-A-2.

Check 7 (PA/MPA) and check 8 (annotations): see the check 1 notes above.

Check 9, cheatsheet section 12 pitfalls: (1) confirmed, `TimeDimensionType` `LocalRepresentation` has no minOccurs=0; (2) confirmed, `version` is prohibited on the three organisation schemes (`SDMXStructureOrganisation.xsd:29`) and on `Categorisation` (`SDMXStructureCategorisation.xsd:32`); (3) confirmed; (4) confirmed, `WildcardedMemberValueType` pattern is `[A-Za-z0-9_@$-%]+` (`$-%` is a character range, so `-` is excluded); (5) confirmed, `XHTMLType` is `xs:any namespace="http://www.w3.org/1999/xhtml" processContents="strict"` and no XHTML schema ships in the folder; `com:Text` exists (`SDMXCommon.xsd:145`); (6) confirmed, `decimals` is `xs:positiveInteger`; (7) confirmed; (8) confirmed.

Check 10: `SDMXMessage.xsd:17-23` imports footer, common, structure (`SDMXStructure.xsd`, which includes every structure module at lines 9-25), registry, structure-specific data, generic metadata and `xml.xsd`; `xml.xsd` is present in `schemas/` (GitHub contents listing at tag v3.1.0). Keeping the whole folder together is correct.

Plan 2.9: annotation-only references to legacy global lists (`global_urn`, `SDMX_CROSS_DOMAIN_CONCEPT`) are not structural references, so they do not break the semver rule.

## Not checked

- Cheatsheet section 1 `xsi:schemaLocation` URL `https://xml.sdmx.org/3.1/SDMXMessage.xsd` (not fetched).
- Whether `SDMX:CL_SEX(2.1)` actually contains `_T` and `_Z`, and the global list versions in plan 2.9 (outside structural conformance).
- Cheatsheet sections 13-14 (SDMX-CSV) beyond the ordering remark in R-A-4. Research R1 was not needed, because every point was checked against the primary XSDs.
- No complete instance document was validated against the XSDs, because no generator output exists yet.
