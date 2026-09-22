# pipeline/R/validate_codes.R
#
# WP11 validator module CODES: code-level checks on data files (unknown
# codes, GEO/REF_AREA agreement, ADM0-in-GEO, breakdown/qualifier slot
# packing and ordering, SEX/AGE-vs-stat_unit, breakdown/qualifier
# applicability, qualifier declaration and cross-qualifier validity, and
# DRAFT-code usage). Depends on pipeline/R/io.R, constants.R, codes.R
# (is_valid_code(), slot_sort(), fill_slots()) and ctx.R.
#
# Every check here first skips a data file whose header does not match the
# DSD (STRUCT.HEADER's job) and, within a file, skips a row that has an
# empty key cell (STRUCT.EMPTY_KEY's job) or an unresolvable code in the
# column it needs (CODES.UNKNOWN's / META.REFERENCE's job), so that one
# malformed cell is reported by exactly one check.

.CODES_BRK_COLS <- paste0("COMP_BREAKDOWN_", 1:5)
.CODES_QUAL_COLS <- paste0("MEASURE_QUAL_", 1:5)

#' The data file's path relative to the root, forward slashes.
.codes_rel_file <- function(key) {
  paste0("data/", key, ".csv")
}

#' The DSD's `id` column, ordered by `position`.
.codes_dsd_header <- function(ctx) {
  dsd <- ctx$meta$DSD_AFW360_HH
  dsd <- dsd[order(as.integer(dsd$position)), ]
  dsd$id
}

#' The 18 key values of row `i`, as a character vector.
.codes_key_vals <- function(df, i) {
  as.character(unlist(df[i, KEY_COLUMNS]))
}

#' Parse a `qualifiers`-style field ("VAR:CODE,CODE VAR:*" or "_Z") into a
#' named list, var_code -> character vector of allowed codes, or "*".
.codes_parse_qual_field <- function(field) {
  field <- trimws(field)
  if (is.na(field) || field == "" || field == SENTINEL_NA) return(list())
  entries <- strsplit(field, "\\s+")[[1]]
  res <- list()
  for (e in entries) {
    parts <- strsplit(e, ":", fixed = TRUE)[[1]]
    if (length(parts) != 2) next
    var <- parts[1]
    codes <- parts[2]
    res[[var]] <- if (identical(codes, "*")) "*" else strsplit(codes, ",", fixed = TRUE)[[1]]
  }
  res
}

#' Split a space-separated field into tokens (empty vector for "" or NA).
.codes_tokens <- function(field) {
  field <- trimws(field)
  if (is.na(field) || field == "") return(character(0))
  strsplit(field, "\\s+")[[1]]
}

#' CODES.UNKNOWN: every coded cell is in its codelist, or is a sentinel the
#' DSD allows for that column.
vc_codes_unknown <- function(ctx) {
  out <- list()
  expected <- .codes_dsd_header(ctx)
  dsd <- ctx$meta$DSD_AFW360_HH
  dsd <- dsd[order(as.integer(dsd$position)), ]
  coded <- dsd[nchar(trimws(dsd$codelist)) > 0, c("id", "codelist", "sentinel")]
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    file <- .codes_rel_file(key)
    for (i in seq_len(nrow(df))) {
      key_vals <- .codes_key_vals(df, i)
      if (any(is.na(key_vals) | trimws(key_vals) == "")) next
      bad <- character(0)
      for (r in seq_len(nrow(coded))) {
        col <- coded$id[r]
        cl <- coded$codelist[r]
        sentinels <- .codes_tokens(coded$sentinel[r])
        val <- as.character(df[[col]][i])
        if (val %in% sentinels) next
        codes <- ctx$meta[[cl]]$code
        if (is.null(codes) || !(val %in% codes)) {
          bad <- c(bad, paste0(col, "=", val))
        }
      }
      if (length(bad) > 0) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.UNKNOWN", "ERROR", file, paste(key_vals, collapse = " "),
          paste0("unknown code(s): ", paste(bad, collapse = "; "))
        )
      }
    }
  }
  .vc_bind(out)
}

#' CODES.GEO_AREA: GEO is `_T`, or a CL_GEO code of the row's REF_AREA.
#' Skips a GEO value that is not a CL_GEO code at all (CODES.UNKNOWN's job).
vc_codes_geo_area <- function(ctx) {
  out <- list()
  expected <- .codes_dsd_header(ctx)
  geo <- ctx$meta$CL_GEO
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    file <- .codes_rel_file(key)
    for (i in seq_len(nrow(df))) {
      key_vals <- .codes_key_vals(df, i)
      if (any(is.na(key_vals) | trimws(key_vals) == "")) next
      g <- df$GEO[i]
      ref <- df$REF_AREA[i]
      if (g == SENTINEL_TOTAL) next
      if (is.null(geo) || !(g %in% geo$code)) next
      if (!any(geo$code == g & geo$ref_area == ref)) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.GEO_AREA", "ERROR", file, paste(key_vals, collapse = " "),
          paste0("GEO ", g, " is not a CL_GEO code of REF_AREA ", ref)
        )
      }
    }
  }
  .vc_bind(out)
}

#' CODES.GEO_ADM0: a geometry-only ADM0 code is never used in GEO.
vc_codes_geo_adm0 <- function(ctx) {
  out <- list()
  expected <- .codes_dsd_header(ctx)
  geo <- ctx$meta$CL_GEO
  adm0_codes <- if (is.null(geo)) character(0) else geo$code[geo$scheme == "ADM0"]
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    file <- .codes_rel_file(key)
    for (i in seq_len(nrow(df))) {
      key_vals <- .codes_key_vals(df, i)
      if (any(is.na(key_vals) | trimws(key_vals) == "")) next
      g <- df$GEO[i]
      if (g %in% adm0_codes) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.GEO_ADM0", "ERROR", file, paste(key_vals, collapse = " "),
          paste0("GEO ", g, " is a geometry-only ADM0 code; the whole country is _T")
        )
      }
    }
  }
  .vc_bind(out)
}

#' Shared engine for CODES.BRK_SLOTS and CODES.QUAL_SLOTS: the slot columns
#' are filled from the left, ascending slot_order (ties by var_code), no
#' variable used twice, unused slots hold `pad`.
.codes_slots_check <- function(ctx, check_id, cols, code_tbl, var_tbl, pad) {
  out <- list()
  expected <- .codes_dsd_header(ctx)
  if (is.null(code_tbl) || is.null(var_tbl)) return(.vc_empty())
  var_of <- stats::setNames(code_tbl$var_code, code_tbl$code)
  slot_order_of <- stats::setNames(var_tbl$slot_order, var_tbl$code)
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    file <- .codes_rel_file(key)
    for (i in seq_len(nrow(df))) {
      key_vals <- .codes_key_vals(df, i)
      if (any(is.na(key_vals) | trimws(key_vals) == "")) next
      actual <- as.character(unlist(df[i, cols]))
      used <- actual[actual != pad]
      if (length(used) == 0) next
      vars_used <- unname(var_of[used])
      if (any(is.na(vars_used))) next # unknown code: CODES.UNKNOWN's job
      dup_var <- anyDuplicated(vars_used) > 0
      expected_slots <- tryCatch(
        fill_slots(slot_sort(used, var_of, slot_order_of), n = length(cols), pad = pad),
        error = function(e) NULL
      )
      mismatch <- !is.null(expected_slots) && !identical(expected_slots, actual)
      if (dup_var || mismatch) {
        msg <- paste0("slots not left-packed in ascending slot_order: found [", paste(actual, collapse = ","), "]")
        if (dup_var) msg <- paste0(msg, "; a variable is used more than once")
        out[[length(out) + 1]] <- .vc_finding(
          check_id, "ERROR", file, paste(key_vals, collapse = " "), msg
        )
      }
    }
  }
  .vc_bind(out)
}

#' CODES.BRK_SLOTS: the breakdown slots (COMP_BREAKDOWN_1..5).
vc_codes_brk_slots <- function(ctx) {
  .codes_slots_check(
    ctx, "CODES.BRK_SLOTS", .CODES_BRK_COLS,
    ctx$meta$CL_COMP_BREAKDOWN, ctx$meta$CL_BRK_VAR, SENTINEL_TOTAL
  )
}

#' CODES.QUAL_SLOTS: the qualifier slots (MEASURE_QUAL_1..5).
vc_codes_qual_slots <- function(ctx) {
  .codes_slots_check(
    ctx, "CODES.QUAL_SLOTS", .CODES_QUAL_COLS,
    ctx$meta$CL_QUALIFIER, ctx$meta$CL_QUAL_VAR, SENTINEL_NA
  )
}

#' CODES.SEX_AGE_UNIT: SEX and AGE are `_Z` exactly when the indicator's
#' stat_unit is not IND.
vc_codes_sex_age_unit <- function(ctx) {
  out <- list()
  expected <- .codes_dsd_header(ctx)
  ind <- ctx$meta$CL_INDICATOR
  if (is.null(ind)) return(.vc_empty())
  stat_unit_of <- stats::setNames(ind$stat_unit, ind$code)
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    file <- .codes_rel_file(key)
    for (i in seq_len(nrow(df))) {
      key_vals <- .codes_key_vals(df, i)
      if (any(is.na(key_vals) | trimws(key_vals) == "")) next
      su <- unname(stat_unit_of[df$INDICATOR[i]])
      if (is.na(su)) next # unknown indicator: CODES.UNKNOWN's job
      want_z <- su != "IND"
      bad <- character(0)
      sex_is_z <- df$SEX[i] == SENTINEL_NA
      age_is_z <- df$AGE[i] == SENTINEL_NA
      if (want_z != sex_is_z) bad <- c(bad, "SEX")
      if (want_z != age_is_z) bad <- c(bad, "AGE")
      if (length(bad) > 0) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.SEX_AGE_UNIT", "ERROR", file, paste(key_vals, collapse = " "),
          paste0(
            paste(bad, collapse = " and "),
            if (want_z) " must be _Z" else " must not be _Z",
            " because INDICATOR ", df$INDICATOR[i], " has stat_unit ", su
          )
        )
      }
    }
  }
  .vc_bind(out)
}

#' CODES.BRK_UNIT: every breakdown variable used lists the indicator's
#' stat_unit in its applies_to_units.
vc_codes_brk_unit <- function(ctx) {
  out <- list()
  expected <- .codes_dsd_header(ctx)
  cb <- ctx$meta$CL_COMP_BREAKDOWN
  bv <- ctx$meta$CL_BRK_VAR
  ind <- ctx$meta$CL_INDICATOR
  if (is.null(cb) || is.null(bv) || is.null(ind)) return(.vc_empty())
  var_of <- stats::setNames(cb$var_code, cb$code)
  applies_of <- stats::setNames(bv$applies_to_units, bv$code)
  stat_unit_of <- stats::setNames(ind$stat_unit, ind$code)
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    file <- .codes_rel_file(key)
    for (i in seq_len(nrow(df))) {
      key_vals <- .codes_key_vals(df, i)
      if (any(is.na(key_vals) | trimws(key_vals) == "")) next
      su <- unname(stat_unit_of[df$INDICATOR[i]])
      if (is.na(su)) next
      used <- as.character(unlist(df[i, .CODES_BRK_COLS]))
      used <- used[used != SENTINEL_TOTAL]
      bad <- character(0)
      for (code in used) {
        var <- unname(var_of[code])
        if (is.na(var)) next
        units <- .codes_tokens(unname(applies_of[var]))
        if (!(su %in% units)) bad <- c(bad, code)
      }
      if (length(bad) > 0) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.BRK_UNIT", "ERROR", file, paste(key_vals, collapse = " "),
          paste0(
            "breakdown code(s) do not apply to stat_unit ", su, ": ",
            paste(bad, collapse = ", ")
          )
        )
      }
    }
  }
  .vc_bind(out)
}

#' CODES.QUAL_DECLARED: every qualifier used is allowed by the indicator's
#' `qualifiers` field, or required by a breakdown used in the same row.
vc_codes_qual_declared <- function(ctx) {
  out <- list()
  expected <- .codes_dsd_header(ctx)
  ind <- ctx$meta$CL_INDICATOR
  cq <- ctx$meta$CL_QUALIFIER
  cb <- ctx$meta$CL_COMP_BREAKDOWN
  bv <- ctx$meta$CL_BRK_VAR
  if (is.null(ind) || is.null(cq) || is.null(cb) || is.null(bv)) return(.vc_empty())
  qualifiers_of <- stats::setNames(ind$qualifiers, ind$code)
  qvar_of <- stats::setNames(cq$var_code, cq$code)
  bvar_of <- stats::setNames(cb$var_code, cb$code)
  requires_qual_of <- stats::setNames(bv$requires_qual, bv$code)
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    file <- .codes_rel_file(key)
    for (i in seq_len(nrow(df))) {
      key_vals <- .codes_key_vals(df, i)
      if (any(is.na(key_vals) | trimws(key_vals) == "")) next
      qfield <- unname(qualifiers_of[df$INDICATOR[i]])
      if (is.na(qfield)) next # unknown indicator: CODES.UNKNOWN's job
      declared <- .codes_parse_qual_field(qfield)

      used_brk <- as.character(unlist(df[i, .CODES_BRK_COLS]))
      used_brk <- used_brk[used_brk != SENTINEL_TOTAL]
      req_vars <- character(0)
      for (bc in used_brk) {
        bvv <- unname(bvar_of[bc])
        if (is.na(bvv)) next
        req_vars <- c(req_vars, .codes_tokens(unname(requires_qual_of[bvv])))
      }

      used_qual <- as.character(unlist(df[i, .CODES_QUAL_COLS]))
      used_qual <- used_qual[used_qual != SENTINEL_NA]
      bad <- character(0)
      for (qc in used_qual) {
        var <- unname(qvar_of[qc])
        if (is.na(var)) next # unknown qualifier code: CODES.UNKNOWN's job
        allowed <- FALSE
        if (!is.null(declared[[var]])) {
          if (identical(declared[[var]], "*") || qc %in% declared[[var]]) allowed <- TRUE
        }
        if (!allowed && var %in% req_vars) allowed <- TRUE
        if (!allowed) bad <- c(bad, qc)
      }
      if (length(bad) > 0) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.QUAL_DECLARED", "ERROR", file, paste(key_vals, collapse = " "),
          paste0(
            "qualifier(s) not declared for INDICATOR ", df$INDICATOR[i],
            " and not required by a breakdown in this row: ", paste(bad, collapse = ", ")
          )
        )
      }
    }
  }
  .vc_bind(out)
}

#' CODES.VALID_WITH: a qualifier whose `valid_with` is filled appears only
#' with those categories of the variable its `var_code` requires; `_Z`
#' means that variable must be absent; when `valid_with` is blank,
#' CL_QUAL_VAR.requires alone (presence of the required variable) holds.
vc_codes_valid_with <- function(ctx) {
  out <- list()
  expected <- .codes_dsd_header(ctx)
  cq <- ctx$meta$CL_QUALIFIER
  qv <- ctx$meta$CL_QUAL_VAR
  if (is.null(cq) || is.null(qv)) return(.vc_empty())
  qvar_of <- stats::setNames(cq$var_code, cq$code)
  valid_with_of <- stats::setNames(cq$valid_with, cq$code)
  requires_of <- stats::setNames(qv$requires, qv$code)
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    file <- .codes_rel_file(key)
    for (i in seq_len(nrow(df))) {
      key_vals <- .codes_key_vals(df, i)
      if (any(is.na(key_vals) | trimws(key_vals) == "")) next
      used_qual <- as.character(unlist(df[i, .CODES_QUAL_COLS]))
      used_qual <- used_qual[used_qual != SENTINEL_NA]

      present_var_code <- character(0)
      for (qc in used_qual) {
        v <- unname(qvar_of[qc])
        if (!is.na(v)) present_var_code[v] <- qc
      }

      bad <- character(0)
      for (qc in used_qual) {
        var <- unname(qvar_of[qc])
        if (is.na(var)) next # unknown qualifier code: CODES.UNKNOWN's job
        req_vars <- .codes_tokens(unname(requires_of[var]))
        if (length(req_vars) == 0) next
        vw <- trimws(unname(valid_with_of[qc]))
        vw_filled <- !is.na(vw) && vw != ""
        for (rv in req_vars) {
          has_req <- rv %in% names(present_var_code)
          if (vw_filled) {
            if (identical(vw, SENTINEL_NA)) {
              if (has_req) bad <- c(bad, qc)
            } else {
              allowed_codes <- .codes_tokens(vw)
              if (!has_req || !(present_var_code[[rv]] %in% allowed_codes)) bad <- c(bad, qc)
            }
          } else {
            if (!has_req) bad <- c(bad, qc)
          }
        }
      }
      bad <- unique(bad)
      if (length(bad) > 0) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.VALID_WITH", "ERROR", file, paste(key_vals, collapse = " "),
          paste0("qualifier(s) violate valid_with/requires: ", paste(bad, collapse = ", "))
        )
      }
    }
  }
  .vc_bind(out)
}

#' CODES.DRAFT: a DRAFT code used in a data file gives WARN when the file's
#' manifest has status = DRAFT, and ERROR otherwise. One finding per file
#' and code.
vc_codes_draft <- function(ctx) {
  out <- list()
  expected <- .codes_dsd_header(ctx)
  dsd <- ctx$meta$DSD_AFW360_HH
  dsd <- dsd[order(as.integer(dsd$position)), ]
  coded <- dsd[nchar(trimws(dsd$codelist)) > 0, c("id", "codelist")]
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected)) next
    file <- .codes_rel_file(key)
    manifest_status <- unname(ctx$manifests[[key]]["status"])
    sev <- if (!is.na(manifest_status) && manifest_status == "DRAFT") "WARN" else "ERROR"
    draft_codes <- character(0)
    for (i in seq_len(nrow(df))) {
      key_vals <- .codes_key_vals(df, i)
      if (any(is.na(key_vals) | trimws(key_vals) == "")) next
      for (r in seq_len(nrow(coded))) {
        col <- coded$id[r]
        cl <- coded$codelist[r]
        val <- as.character(df[[col]][i])
        if (val %in% c(SENTINEL_TOTAL, SENTINEL_NA)) next
        cltab <- ctx$meta[[cl]]
        if (is.null(cltab)) next
        st <- cltab$status[match(val, cltab$code)]
        if (length(st) == 1 && !is.na(st) && st == "DRAFT") {
          draft_codes <- c(draft_codes, val)
        }
      }
    }
    draft_codes <- unique(draft_codes)
    for (dc in draft_codes) {
      out[[length(out) + 1]] <- .vc_finding(
        "CODES.DRAFT", sev, file, paste0("code=", dc),
        paste0(
          "DRAFT code used in data file (manifest status ",
          if (is.na(manifest_status)) "unknown" else manifest_status, ")"
        )
      )
    }
  }
  .vc_bind(out)
}
