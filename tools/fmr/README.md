# FMR spike: install and usage notes (WP8a — no software installed)

Status: research only. Nothing was installed or downloaded here beyond fetching
web pages to confirm facts. This file is what WP8b (the real install, on the
data lead's machine, after Gate 2 approval) should follow. See plan section
2.13 for the documented workflow this feeds into.

Machine this spike ran on: Windows 11, no administrator rights, no Docker.
`java -version` → `openjdk version "21.0.12.1"` / `OpenJDK Runtime Environment
Zulu21.52+203-CA` (Azul Zulu, LTS). `curl` needs `--ssl-no-revoke` here; no
proxy is configured.

## 1. Artefacts to download

### Apache Tomcat 10.1.x (Java web application server)

FMR 12 "requires a Java web application server that implements the Servlet
6.0, Jakarta EE 10, and JSP 3.1 specifications... In practice this means
Apache Tomcat 10.1", and FMR 12 is tested against Apache Tomcat 10.1 and
JBoss Web Server 6.x
([InstallApacheTomcat](https://fmrwiki.sdmx.io/latest/admin/installation/InstallApacheTomcat/)).

Current release: **10.1.60**. Windows zip (no installer, no admin rights
needed — extract and run):
[apache-tomcat-10.1.60.zip](https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.60/bin/apache-tomcat-10.1.60.zip),
listed on the
[Tomcat 10 download page](https://tomcat.apache.org/download-10.cgi).

Surfaced point: the vendor's own
[FMR download page](https://www.sdmx.io/software/fmr/download/) still says
"Apache Tomcat 9.0 is recommended" and its version table stops at FMR
12.4.0. This is stale — trust the wiki (Java 21 / Tomcat 10.1, updated with
each release) over that page's system-requirements blurb.

### FMR 12.4.x WAR

Current release: **12.4.2**, published 2026-09-19 (confirmed via the GitHub
Releases API, `tag_name: "v12.4.2"`, asset `fmr-12.4.2.war`, `size:
129151617` bytes ≈ 123 MB). Direct download:
[fmr-12.4.2.war](https://github.com/bis-med-it/fmr-public/releases/download/v12.4.2/fmr-12.4.2.war),
release notes at
[the v12.4.2 tag](https://github.com/bis-med-it/fmr-public/releases/tag/v12.4.2).
The public index page
([www.sdmx.io/software/fmr/download](https://www.sdmx.io/software/fmr/download/))
only lists up to 12.4.0 — two patch releases behind; use the GitHub tag
directly.

### Database

The FMR wiki documents three supported database products: MySQL 8.0,
Microsoft SQL Server and Oracle
([InstallDatabase](https://fmrwiki.sdmx.io/latest/admin/installation/InstallDatabase/),
[MySql](https://fmrwiki.sdmx.io/latest/admin/installation/MySql/)).
**MariaDB is not named anywhere on the install/database wiki pages as a
supported database product — unverified/undocumented for use as the FMR
database server itself.** The plan's "MySQL 8 or MariaDB" wording should be
read as MySQL 8 (documented) with MariaDB as an unverified fallback, not two
equally-supported options.

Nuance: FMR's own example `fmr.properties` ships
`database.driver=org.mariadb.jdbc.Driver`
([RegistryPropertiesFile](https://fmrwiki.sdmx.io/latest/admin/configuration/RegistryPropertiesFile/))
— i.e. the MariaDB Connector/J *driver class*, which is wire-compatible with
MySQL. That is a JDBC driver choice in the shipped example, not evidence
that a MariaDB *server* is a supported target; still unverified.

MySQL 8.0 has an official "noinstall ZIP Archive" method for Windows that
needs no administrator rights (extract, `mysqld --initialize`, run
`mysqld` as the current user), per Oracle's own reference manual:
[Installing MySQL on Microsoft Windows Using a noinstall ZIP Archive](https://dev.mysql.com/doc/refman/8.0/en/windows-install-archive.html).
This is the path to use here.

FMR does not bundle the MySQL JDBC driver since release 11.4.0; download
MySQL Connector/J (a single jar, e.g. `mysql-connector-java-9.6.0.jar`)
separately and copy it into the deployed WAR's `WEB-INF/lib`, or a directory
added to `CLASSPATH` — a plain file copy, no admin rights needed
([MySql](https://fmrwiki.sdmx.io/latest/admin/installation/MySql/)).

## 2. Disk and port needs

- Tomcat 10.1.60 zip: small download, unpacks to roughly 60–70 MB.
- FMR WAR: 123 MB; unpacks to a populated webapp directory of similar order
  (the wiki's own worked example shows a 125,841,965-byte `ROOT.war`
  unpacking into a multi-directory `ROOT/` tree —
  [InstallFusionMetadataRegistry](https://fmrwiki.sdmx.io/latest/admin/installation/InstallFusionMetadataRegistry/)).
- MySQL 8.0 noinstall zip: not sized here — unverified, confirm at WP8b time.
- RAM: the download page's stated minimum is 4 GB, 2-core CPU
  ([download page](https://www.sdmx.io/software/fmr/download/)), but the
  wiki's own Tomcat setup step recommends `-Xmx16G` (16 GB Java heap)
  ([InstallApacheTomcat](https://fmrwiki.sdmx.io/latest/admin/installation/InstallApacheTomcat/)).
  Surfaced point for WP8b: confirm how much RAM the data lead's machine can
  spare before installing; 4 GB and 16 GB are very different asks and the
  wiki does not document a documented floor below 16 GB.
- Ports: Tomcat serves FMR on **8080** by default, changed via `Connector
  port` in `tomcat/conf/server.xml`
  ([InstallApacheTomcat](https://fmrwiki.sdmx.io/latest/admin/installation/InstallApacheTomcat/)).
  MySQL defaults to 3306 (used in the wiki's own JNDI example, see below).
- Everything below lives under one user-writable folder tree; nothing
  installs to Program Files or as a Windows service.

## 3. Install procedure (writes nothing outside `tools/fmr/runtime/` or a user-chosen folder)

Documented for WP8b; **not executed in this spike**.

1. `mkdir tools/fmr/runtime` (gitignored) — or any folder outside the repo.
2. Download and extract the Tomcat zip into `tools/fmr/runtime/tomcat`.
3. Set the Java heap: create `tools/fmr/runtime/tomcat/bin/setenv.bat` with
   `set "JAVA_OPTS=-Xmx16G"` (lower it if RAM-constrained; no documented
   minimum was found — unverified how low it can go).
4. Copy `fmr-12.4.2.war` to
   `tools/fmr/runtime/tomcat/webapps/ROOT.war` (deploys FMR on the site
   root, port 8080 by default) or `fmr.war` (deploys it under the `/fmr`
   path instead)
   ([InstallFusionMetadataRegistry](https://fmrwiki.sdmx.io/latest/admin/installation/InstallFusionMetadataRegistry/)).
5. Download and extract the MySQL 8.0 noinstall zip into
   `tools/fmr/runtime/mysql`; initialize with `mysqld --initialize --console`,
   then start with `mysqld --console` — both run as the current user, no
   service install
   ([MySQL noinstall guide](https://dev.mysql.com/doc/refman/8.0/en/windows-install-archive.html)).
6. Create the database and user (`mysql -u root -p`):
   ```
   CREATE DATABASE fmr;
   CREATE USER 'fmruser'@'%' IDENTIFIED BY '<password>';
   GRANT ALL ON fmr.* TO 'fmruser'@'%';
   ```
   ([MySql](https://fmrwiki.sdmx.io/latest/admin/installation/MySql/)).
7. Download MySQL Connector/J and copy the jar into
   `tools/fmr/runtime/tomcat/webapps/ROOT/WEB-INF/lib` (after the WAR has
   unpacked once) or a CLASSPATH directory
   ([MySql](https://fmrwiki.sdmx.io/latest/admin/installation/MySql/)).
8. Add a JNDI `<Resource>` for the DB connection to
   `tools/fmr/runtime/tomcat/conf/context.xml` (section 4 below).
9. Start Tomcat: `tools/fmr/runtime/tomcat/bin/startup.bat` — Tomcat's own
   scripts run as the current user, no admin rights needed.
10. Open the deployed FMR address in a browser (port 8080 by default) and
    complete the first-run setup wizard,
    which sets the Root superuser account's username (traditionally `root`)
    and password
    ([InstallFusionMetadataRegistry](https://fmrwiki.sdmx.io/latest/admin/installation/InstallFusionMetadataRegistry/)).

Nothing above writes outside `tools/fmr/runtime/` or a folder the installer
chooses outside the repo.

## 4. FMR properties needed

### `fmr.properties`

Auto-generated on first run. In FMR 12 the default location is
`<user home>\SDMX_IO\FMR\fmr.properties`; it can be redirected with
`-DRegistryProperties=file:///c:/dir/AFile.txt` in `JAVA_OPTS`
([RegistryPropertiesFile](https://fmrwiki.sdmx.io/latest/admin/configuration/RegistryPropertiesFile/)).
Example keys from the wiki's own sample (values illustrative/generated):

```
database.driver=org.mariadb.jdbc.Driver
database.jndicontext=java\:/comp/env
database.jndiname=database
encrypt.password=<generated>
encrypt.salt=<generated>
registry.url=http\://localhost\:8080
security.password=<bcrypt hash>
security.username=root
```

`security.username`/`security.password` hold the Root superuser account
(bcrypt-hashed, set via the first-run wizard); `encrypt.*` are used to
AES-256-encrypt other secrets FMR stores.

### Tomcat JNDI `<Resource>` (the actual DB connection)

The real JDBC URL, username and password go in Tomcat's `conf/context.xml`,
not in `fmr.properties`
([Jndi](https://fmrwiki.sdmx.io/latest/admin/installation/Jndi/)):

```xml
<Resource driverClassName="com.mysql.cj.jdbc.Driver"
          url="jdbc:mysql://localhost:3306/fmr"
          username="fmruser"
          password="<password>" />
```

The full attribute set (`name`, `type`, pool sizing) on that page was not
fully captured in this spike — confirm the complete `<Resource>` block
against the Jndi page at WP8b time.

## 5. REST calls

### Structure import

`POST /ws/secure/sdmxapi/rest/`, HTTP Basic auth, secure/agency-and-admin
only. Accepts SDMX-ML, SDMX-JSON or SDMX-EDI structure messages (zipped
files supported). The `ACTION` header controls the import mode (`APPEND`,
`REPLACE` [default], `MERGE`, `FULLREPLACE`, `DELETE`)
([SubmitStructuresWebService](https://fmrwiki.sdmx.io/latest/rest-api/structural-metadata/SubmitStructuresWebService/)).

```sh
# FMR_BASE = the running FMR's address, e.g. its local host and port 8080
curl --ssl-no-revoke -u root:<password> \
  -H "ACTION: REPLACE" \
  -F "uploadFile=@sdmx/structures/AFW360_structures.xml" \
  "$FMR_BASE/ws/secure/sdmxapi/rest/"
```

### Data validation

`POST /ws/public/data/validate` (public by default, configurable to
private). Accepts CSV, XLSX, SDMX-ML, SDMX-EDI; responds `application/json`.
Useful optional headers: `Data-Format: csv;delimiter=[comma|tab|semicolon|space]`,
`Structure: <Dataflow/DSD/Provision-Agreement URN>`, `Inc-Metrics`,
`Inc-Valid`, `Inc-Invalid`
([DataValidationWebService](https://fmrwiki.sdmx.io/latest/rest-api/data-processing/DataValidationWebService/)).

```sh
# FMR_BASE = the running FMR's address, e.g. its local host and port 8080
curl --ssl-no-revoke \
  -H "Data-Format: csv;delimiter=comma" \
  -H "Structure: urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=WB:AFW360_HH(1.0)" \
  -F "uploadFile=@data/AFW360_HH_SEN_SURVEY.csv" \
  "$FMR_BASE/ws/public/data/validate"
```

Both commands are built from the documented parameters; no FMR server was
available to run them against, so their exact response bodies are
unverified.

## 6. SDMX-ML `v3_1` and SDMX-CSV 2.1 — evidence

**SDMX-ML structures**: FMR's own SDMX-ML Structure format page documents
SDMX-ML 3.0 (namespace path `.../resources/sdmxml/schemas/v3_0/...`)
alongside 2.1, and names no `v3_1` namespace anywhere on that page
([SdmxMlStructure](https://fmrwiki.sdmx.io/latest/formats/structure/SdmxMlStructure/)).
The 12.4.0, 12.4.1 and 12.4.2 changelog entries contain no SDMX 3.1-related
changes
([ChangelogFMR](https://fmrwiki.sdmx.io/latest/reference/changelogs/ChangelogFMR)).
Together this matches the plan's contingency: FMR 12.4.x's documented
structure-message ceiling is SDMX-ML 3.0, not 3.1. No forum thread or
changelog line says "3.1 is rejected" in so many words, so this is
**evidenced by absence across two current-version sources, not by an
explicit vendor statement — treat the "no 3.1" conclusion as unverified in
the strict sense, though well supported.**

**SDMX-CSV**: the SDMX-CSV Data format page documents only version 1.0.0
and the newer 2.0.0 (recommending 2.0.0); it does not mention 2.1 anywhere
([SdmxCsvData](https://fmrwiki.sdmx.io/latest/formats/data/SdmxCsvData/)).
Same caveat: evidenced by absence, not a direct denial statement.

No SDMX/BIS forum search was done (out of this spike's context budget); if
the above is not conclusive enough, that search is left for WP8b.

## Sources

- https://fmrwiki.sdmx.io/
- https://fmrwiki.sdmx.io/latest/admin/installation/InstallApacheTomcat/
- https://fmrwiki.sdmx.io/latest/admin/installation/InstallDatabase/
- https://fmrwiki.sdmx.io/latest/admin/installation/MySql/
- https://fmrwiki.sdmx.io/latest/admin/installation/InstallFusionMetadataRegistry/
- https://fmrwiki.sdmx.io/latest/admin/installation/InstallJavaRuntimeEnvironment/
- https://fmrwiki.sdmx.io/latest/admin/installation/Jndi/
- https://fmrwiki.sdmx.io/latest/admin/configuration/RegistryPropertiesFile/
- https://fmrwiki.sdmx.io/latest/rest-api/structural-metadata/SubmitStructuresWebService/
- https://fmrwiki.sdmx.io/latest/rest-api/data-processing/DataValidationWebService/
- https://fmrwiki.sdmx.io/latest/formats/structure/SdmxMlStructure/
- https://fmrwiki.sdmx.io/latest/formats/data/SdmxCsvData/
- https://fmrwiki.sdmx.io/latest/reference/changelogs/ChangelogFMR
- https://www.sdmx.io/software/fmr/download/
- https://tomcat.apache.org/download-10.cgi
- https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.60/bin/apache-tomcat-10.1.60.zip
- https://github.com/bis-med-it/fmr-public/releases/tag/v12.4.2
- https://github.com/bis-med-it/fmr-public/releases/download/v12.4.2/fmr-12.4.2.war
- https://dev.mysql.com/doc/refman/8.0/en/windows-install-archive.html
