# pipeline/R/validate_sdmx.R
#
# Validator module SDMX (plan 2.12, WP5d): the SDMX outputs under sdmx/
# and the SDMX-CSV header of the data files. Five checks:
#
#   SDMX.STALE       every file under sdmx/ (except the hand-written *.md)
#                    equals what pipeline/build_sdmx.R writes from the
#                    current metadata: the outputs are regenerated into a
#                    temp dir and compared byte for byte; a file the build
#                    does not write, or does not find, is also flagged.
#   SDMX.XSD         sdmx/structures/AFW360_structures.xml is valid against
#                    pipeline/xsd/sdmx-ml-3.1/SDMXMessage.xsd (sdmx_validate()).
#   SDMX.URN         every URN referenced in the message (outside
#                    annotations, whose values are not structural references)
#                    resolves to an artefact or item of the same message;
#                    every str:Parent names an item of the same scheme; every
#                    sub-agency (A.B) is declared as agency B in the agency
#                    scheme of A; a semver artefact references only semver
#                    artefacts, except the (1.0) items of the fixed-version
#                    organisation schemes (plan 2.1).
#   SDMX.IDENT       every maintainable has agencyID WB.AFW360 (WB for
#                    AGENCIES), a semver version equal to metadata/VERSION
#                    (no version on AGENCIES, DATA_PROVIDERS,
#                    METADATA_PROVIDERS), an id matching the XSD IDType, and a
#                    non-empty com:Name xml:lang="en".
#   SDMX.CSV_HEADER  each data file's header equals ctx_data_columns() (the
#                    three fixed SDMX-CSV columns and the DSD components, in
#                    order) and every STRUCTURE_ID is structure_id(VERSION).
#
# A root without an sdmx/ folder (a trimmed copy used by a test) gives one
# INFO SDMX.SKIPPED from vc_sdmx_stale; the XSD, URN and IDENT checks then
# return nothing. The regeneration needs pipeline/R/sdmx_xml.R,
# sdmx_structures.R and sdmx_refmeta.R; validate.R sources them, and this
# module sources them from the root when they are missing.

.VSDMX_STRUCT <- "sdmx/structures/AFW360_structures.xml"
.VSDMX_AGENCY <- "WB.AFW360"
.VSDMX_FIXED <- c(
  AgencyScheme = "AGENCIES", DataProviderScheme = "DATA_PROVIDERS",
  MetadataProviderScheme = "METADATA_PROVIDERS"
)
.VSDMX_ORG_CLASSES <- c(
  "AgencyScheme", "DataProviderScheme", "MetadataProviderScheme",
  "Agency", "DataProvider", "MetadataProvider"
)
.VSDMX_SEMVER <- "^[0-9]+[.][0-9]+[.][0-9]+$"
.VSDMX_IDTYPE <- "^[A-Za-z0-9_@$-]+$"
.VSDMX_URN_RE <- paste0(
  "^urn:sdmx:org[.]sdmx[.]infomodel[.]([a-z]+)[.]([A-Za-z]+)=",
  "([A-Za-z0-9_@$.-]+):([A-Za-z0-9_@$-]+)[(]([^()]+)[)](?:[.](.+))?$"
)

.vsdmx_ensure_sources <- function(root) {
  need <- !exists("sdmx_validate", mode = "function") ||
    !exists("sdmx_structures_message", mode = "function") ||
    !exists("sdmx_refmeta_messages", mode = "function")
  if (need) {
    for (f in c("sdmx_xml.R", "sdmx_structures.R", "sdmx_refmeta.R")) {
      source(file.path(root, "pipeline", "R", f))
    }
  }
  invisible(TRUE)
}

.vsdmx_fixed_version <- function() {
  if (exists("SDMX_FIXED_VERSION")) get("SDMX_FIXED_VERSION") else "1.0"
}

#' The structure message of the root, parsed, or NULL when it is absent or
#' not well-formed (SDMX.XSD reports both).
.vsdmx_read <- function(ctx) {
  path <- file.path(ctx$root, .VSDMX_STRUCT)
  if (!file.exists(path)) return(NULL)
  tryCatch(.vsdmx_parse(path), error = function(e) NULL)
}

#' One row per maintainable: node, class, agency, id, version (NA when the
#' attribute is absent), key (Class=agency:id(version), absent version as
#' the fixed version).
.vsdmx_maintainables <- function(doc) {
  nodes <- xml2::xml_find_all(doc, "//*[local-name()='Structures']/*/*")
  cls <- xml2::xml_name(nodes)
  ag <- xml2::xml_attr(nodes, "agencyID")
  id <- xml2::xml_attr(nodes, "id")
  ver <- xml2::xml_attr(nodes, "version")
  keyver <- ifelse(is.na(ver), .vsdmx_fixed_version(), ver)
  list(
    nodes = nodes, class = cls, agency = ag, id = id, version = ver,
    key = paste0(cls, "=", ag, ":", id, "(", keyver, ")")
  )
}

.vsdmx_empty <- function() dplyr::as_tibble(.vc_empty())

# Parse from the bytes, not from the path: on Windows libxml2 keeps a file
# handle open after a failed parse of a path, which then blocks deleting it.
.vsdmx_parse <- function(path) xml2::read_xml(readBin(path, "raw", file.info(path)$size))

#' The SDMX.STALE findings (and SDMX.SKIPPED when there is no sdmx/).
vc_sdmx_stale <- function(ctx) {
  root <- ctx$root
  if (!dir.exists(file.path(root, "sdmx"))) {
    return(.vc_finding(
      "SDMX.SKIPPED", "INFO", "sdmx/", "",
      "the root has no sdmx/ folder; the SDMX outputs were not checked"
    ))
  }
  tmp <- tempfile("vsdmx_")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  err <- tryCatch({
    .vsdmx_ensure_sources(root)
    doc <- sdmx_structures_message(root, SDMX_DEFAULT_TIMESTAMP)
    sdmx_write(doc, file.path(tmp, .VSDMX_STRUCT))
    sdmx_refmeta_write(sdmx_refmeta_messages(root), file.path(tmp, "sdmx", "metadata"))
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(err)) {
    return(.vc_finding(
      "SDMX.STALE", "ERROR", "sdmx/", "",
      paste0("could not regenerate the SDMX outputs from the metadata: ", err)
    ))
  }
  expected <- list.files(file.path(tmp, "sdmx"), recursive = TRUE)
  actual <- list.files(file.path(root, "sdmx"), recursive = TRUE)
  actual <- actual[!grepl("[.]md$", actual)]
  rebuild <- "; run Rscript pipeline/build_sdmx.R --root ."
  parts <- list()
  for (p in sort(union(expected, actual), method = "radix")) {
    rel <- paste0("sdmx/", p)
    a <- file.path(root, "sdmx", p)
    e <- file.path(tmp, "sdmx", p)
    if (!p %in% expected) {
      parts[[length(parts) + 1]] <- .vc_finding(
        "SDMX.STALE", "ERROR", rel, "", "build_sdmx.R does not write this file; remove it or add it to the build"
      )
    } else if (!p %in% actual) {
      parts[[length(parts) + 1]] <- .vc_finding(
        "SDMX.STALE", "ERROR", rel, "", paste0("the file is missing", rebuild)
      )
    } else {
      ra <- readBin(a, "raw", file.info(a)$size)
      re <- readBin(e, "raw", file.info(e)$size)
      if (!identical(ra, re)) {
        la <- readLines(a, warn = FALSE, encoding = "UTF-8")
        le <- readLines(e, warn = FALSE, encoding = "UTF-8")
        n <- min(length(la), length(le))
        d <- which(la[seq_len(n)] != le[seq_len(n)])
        at <- if (length(d) > 0) d[1] else n + 1
        parts[[length(parts) + 1]] <- .vc_finding(
          "SDMX.STALE", "ERROR", rel, sprintf("line %d", at),
          paste0("differs from what build_sdmx.R writes from the current metadata (first difference at line ", at, ")", rebuild)
        )
      }
    }
  }
  .vc_bind(parts)
}

#' The SDMX.XSD findings.
vc_sdmx_xsd <- function(ctx) {
  root <- ctx$root
  if (!dir.exists(file.path(root, "sdmx"))) return(.vsdmx_empty())
  path <- file.path(root, .VSDMX_STRUCT)
  if (!file.exists(path)) {
    return(.vc_finding("SDMX.XSD", "ERROR", .VSDMX_STRUCT, "", "the structure message is missing"))
  }
  doc <- tryCatch(.vsdmx_parse(path), error = function(e) e)
  if (inherits(doc, "error")) {
    return(.vc_finding("SDMX.XSD", "ERROR", .VSDMX_STRUCT, "",
                       paste0("the structure message is not well-formed XML: ", conditionMessage(doc))))
  }
  .vsdmx_ensure_sources(root)
  ok <- sdmx_validate(doc, root)
  if (isTRUE(ok)) return(.vsdmx_empty())
  errs <- attr(ok, "errors")
  if (length(errs) == 0) errs <- "not valid against SDMXMessage.xsd"
  .vc_bind(list(.vc_finding(
    "SDMX.XSD", "ERROR", .VSDMX_STRUCT, sprintf("error %03d", seq_along(errs)),
    paste0("not valid against pipeline/xsd/sdmx-ml-3.1/SDMXMessage.xsd: ", errs)
  )))
}

#' The SDMX.URN findings.
vc_sdmx_urn <- function(ctx) {
  doc <- .vsdmx_read(ctx)
  if (is.null(doc)) return(.vsdmx_empty())
  m <- .vsdmx_maintainables(doc)
  items <- character(0)
  item_ids <- vector("list", length(m$nodes))
  for (i in seq_along(m$nodes)) {
    kids <- xml2::xml_find_all(m$nodes[[i]], "./*[@id]")
    ids <- xml2::xml_attr(kids, "id")
    item_ids[[i]] <- ids
    if (length(kids) > 0) {
      keyver <- if (is.na(m$version[i])) .vsdmx_fixed_version() else m$version[i]
      items <- c(items, paste0(xml2::xml_name(kids), "=", m$agency[i], ":", m$id[i], "(", keyver, ").", ids))
    }
  }
  out <- list()
  add <- function(row_key, message) {
    out[[length(out) + 1]] <<- .vc_finding("SDMX.URN", "ERROR", .VSDMX_STRUCT, row_key, message)
  }
  agencies_used <- m$agency
  xp_text <- ".//text()[starts-with(normalize-space(.), 'urn:sdmx:')][not(ancestor::*[local-name()='Annotation'])]"
  xp_attr <- ".//@*[starts-with(., 'urn:sdmx:')]"
  for (i in seq_along(m$nodes)) {
    node <- m$nodes[[i]]
    src <- m$key[i]
    src_semver <- !is.na(m$version[i]) && grepl(.VSDMX_SEMVER, m$version[i])
    refs <- c(
      trimws(xml2::xml_text(xml2::xml_find_all(node, xp_text))),
      xml2::xml_text(xml2::xml_find_all(node, xp_attr))
    )
    for (u in unique(refs)) {
      mm <- regmatches(u, regexec(.VSDMX_URN_RE, u, perl = TRUE))[[1]]
      if (length(mm) == 0) {
        add(u, paste0("in ", src, ": not a well-formed SDMX URN"))
        next
      }
      cls <- mm[3]; ag <- mm[4]; id <- mm[5]; ver <- mm[6]; item <- mm[7]
      agencies_used <- c(agencies_used, ag)
      key <- paste0(cls, "=", ag, ":", id, "(", ver, ")")
      found <- if (is.na(item) || item == "") key %in% m$key else paste0(key, ".", item) %in% items
      if (!found) {
        add(u, paste0("in ", src, ": the URN does not resolve to an artefact of this message"))
      }
      if (src_semver && !grepl(.VSDMX_SEMVER, ver) &&
          !(ver == .vsdmx_fixed_version() && cls %in% .VSDMX_ORG_CLASSES)) {
        add(u, paste0("in ", src, ": a semver artefact references the non-semver version (", ver, ")"))
      }
    }
    parents <- xml2::xml_find_all(node, ".//*[local-name()='Parent']")
    for (p in trimws(xml2::xml_text(parents))) {
      if (startsWith(p, "urn:sdmx:")) next
      if (!p %in% item_ids[[i]]) {
        add(paste0(src, " Parent ", p), paste0("in ", src, ": Parent '", p, "' is not an item of the same scheme"))
      }
    }
  }
  for (ag in sort(unique(agencies_used[!is.na(agencies_used) & grepl("[.]", agencies_used)]))) {
    parent <- sub("[.][^.]*$", "", ag)
    child <- sub("^.*[.]", "", ag)
    hit <- which(m$class == "AgencyScheme" & m$agency == parent)
    declared <- any(vapply(hit, function(j) child %in% item_ids[[j]], logical(1)))
    if (!declared) {
      add(ag, paste0("the sub-agency ", ag, " is not declared as Agency '", child,
                     "' in an agency scheme of ", parent, " in this message"))
    }
  }
  .vc_bind(out)
}

#' The SDMX.IDENT findings.
vc_sdmx_ident <- function(ctx) {
  doc <- .vsdmx_read(ctx)
  if (is.null(doc)) return(.vsdmx_empty())
  m <- .vsdmx_maintainables(doc)
  out <- list()
  add <- function(row_key, message) {
    out[[length(out) + 1]] <<- .vc_finding("SDMX.IDENT", "ERROR", .VSDMX_STRUCT, row_key, message)
  }
  for (i in seq_along(m$nodes)) {
    cls <- m$class[i]; id <- m$id[i]; ag <- m$agency[i]; ver <- m$version[i]
    rk <- paste0(cls, " ", ifelse(is.na(id), "", id))
    fixed <- cls %in% names(.VSDMX_FIXED) && identical(unname(.VSDMX_FIXED[cls]), id)
    want_ag <- if (cls == "AgencyScheme" && identical(id, "AGENCIES")) "WB" else .VSDMX_AGENCY
    if (is.na(ag) || ag != want_ag) {
      add(rk, sprintf("agencyID is '%s', expected '%s'", ifelse(is.na(ag), "", ag), want_ag))
    }
    if (fixed) {
      if (!is.na(ver)) add(rk, sprintf("the fixed-version scheme %s carries version '%s'; it must have none", id, ver))
    } else if (is.na(ver)) {
      add(rk, "the version attribute is missing")
    } else if (!grepl(.VSDMX_SEMVER, ver)) {
      add(rk, sprintf("version '%s' is not semver (major.minor.patch)", ver))
    } else if (!is.na(ctx$version) && ver != ctx$version) {
      add(rk, sprintf("version '%s' differs from metadata/VERSION '%s'", ver, ctx$version))
    }
    if (is.na(id) || !grepl(.VSDMX_IDTYPE, id)) {
      add(rk, sprintf("id '%s' does not match the XSD IDType [A-Za-z0-9_@$-]+", ifelse(is.na(id), "", id)))
    }
    nm <- xml2::xml_find_all(m$nodes[[i]], "./*[local-name()='Name'][@xml:lang='en']")
    if (length(nm) == 0 || !any(nzchar(trimws(xml2::xml_text(nm))))) {
      add(rk, "no non-empty com:Name xml:lang=\"en\"")
    }
  }
  .vc_bind(out)
}

#' The SDMX.CSV_HEADER findings.
vc_sdmx_csv_header <- function(ctx) {
  if (length(ctx$data) == 0) return(.vsdmx_empty())
  expected <- tryCatch(ctx_data_columns(ctx), error = function(e) NULL)
  if (is.null(expected)) return(.vsdmx_empty())
  want_sid <- if (is.na(ctx$version)) NA_character_ else structure_id(ctx$version)
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    file <- .vc_file_path(key)
    hdr <- names(df)
    if (!identical(hdr, expected)) {
      miss <- setdiff(expected, hdr)
      extra <- setdiff(hdr, expected)
      msg <- paste0(
        "the header is not the ", length(expected), " columns STRUCTURE, STRUCTURE_ID, ACTION and the DSD components in order",
        if (length(miss) > 0) paste0("; missing: ", paste(miss, collapse = ", ")) else "",
        if (length(extra) > 0) paste0("; not in the DSD: ", paste(extra, collapse = ", ")) else "",
        if (length(miss) == 0 && length(extra) == 0) "; the columns are out of order" else ""
      )
      out[[length(out) + 1]] <- .vc_finding("SDMX.CSV_HEADER", "ERROR", file, "header", msg)
    }
    if ("STRUCTURE_ID" %in% hdr && !is.na(want_sid)) {
      sids <- unique(as.character(df$STRUCTURE_ID))
      for (s in sids[is.na(sids) | sids != want_sid]) {
        v <- if (is.na(s)) "" else sub("^.*[(]([^()]*)[)]$", "\\1", s)
        out[[length(out) + 1]] <- .vc_finding(
          "SDMX.CSV_HEADER", "ERROR", file, paste0("STRUCTURE_ID ", ifelse(is.na(s), "", s)),
          sprintf("STRUCTURE_ID '%s' (version '%s') is not '%s' (metadata/VERSION %s)",
                  ifelse(is.na(s), "", s), v, want_sid, ctx$version)
        )
      }
    }
  }
  .vc_bind(out)
}
