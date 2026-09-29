# pipeline/R/validate_codes.R
#
# Validator module CODES: code-level checks on data files (unknown codes,
# GEO/REF_AREA agreement, ADM0-in-GEO, breakdown/qualifier slot packing and
# ordering, SEX/AGE-vs-stat_unit, breakdown applicability, qualifier
# declaration (INDICATOR_QUALIFIERS.csv) and pairings (QUALIFIER_PAIRS.csv),
# SERIES_ID against SERIES_PLAN.csv, UNIT_MEASURE against the dictionary,
# SOURCE_ID against SOURCES.csv and the manifest, and DRAFT-code usage).
# Depends on pipeline/R/io.R, constants.R, codes.R (slot_sort(),
# fill_slots()) and ctx.R (the ctx_*() accessors).
#
# Every check here first skips a data file whose header does not match the
# DSD (STRUCT.HEADER's job) and, within a file, skips a row that has an
# empty key cell (STRUCT.EMPTY_KEY's job) or an unresolvable code in the
# column it needs (CODES.UNKNOWN's / META.REFERENCE's job), so that one
# malformed cell is reported by exactly one check. SERIES_ID, UNIT_MEASURE
# and SOURCE_ID are coded columns of the DSD too, but each has its own
# check (CODES.SERIES_ID, CODES.UNIT, CODES.SOURCE_ID) that also covers an
# unknown value, so CODES.UNKNOWN leaves them out.

.CODES_BRK_COLS <- paste0("COMP_BREAKDOWN_", 1:5)
.CODES_QUAL_COLS <- paste0("MEASURE_QUAL_", 1:5)
.CODES_OWN_CHECK_COLS <- c("SERIES_ID", "UNIT_MEASURE", "SOURCE_ID")

#' The data file's path relative to the root, forward slashes.
.codes_rel_file <- function(key) {
  paste0("data/", key, ".csv")
}

#' Split a space-separated field into tokens (empty vector for "" or NA).
.codes_tokens <- function(field) {
  field <- trimws(field)
  if (length(field) == 0 || is.na(field) || field == "") return(character(0))
  strsplit(field, "\\s+")[[1]]
}

#' The data files a CODES check looks at: header matching the DSD, with the
#' indices of the rows whose key cells are all filled and their row keys.
#'
#' @return A list of lists with `key`, `file`, `df`, `ok` (row indices) and
#'   `row_keys` (every row's key string).
.codes_files <- function(ctx) {
  expected <- ctx_dsd_columns(ctx)
  key_cols <- ctx_key_columns(ctx)
  res <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (!identical(names(df), expected) || nrow(df) == 0) next
    m <- as.matrix(df[key_cols])
    ok <- which(rowSums(is.na(m) | trimws(m) == "") == 0)
    res[[length(res) + 1]] <- list(
      key = key, file = .codes_rel_file(key), df = df, ok = ok,
      row_keys = ctx_row_keys(ctx, df)
    )
  }
  res
}

#' The codes of the table a DSD `codelist` cell names: its `code` column,
#' or `series_id` for SERIES_PLAN, `source_id` for SOURCES.
.codes_codelist_codes <- function(ctx, cl) {
  tab <- ctx$meta[[cl]]
  if (is.null(tab)) return(NULL)
  if ("code" %in% names(tab)) return(tab$code)
  if (cl == "SERIES_PLAN") return(tab$series_id)
  if (cl == "SOURCES") return(tab$source_id)
  NULL
}

#' The coded DSD columns: id, codelist and sentinel.
.codes_coded_columns <- function(ctx) {
  dsd <- ctx$meta$DSD_AFW360_HH
  if (is.null(dsd)) return(data.frame(id = character(0), codelist = character(0), sentinel = character(0)))
  dsd <- dsd[order(as.integer(dsd$position), method = "radix"), ]
  as.data.frame(dsd[nchar(trimws(dsd$codelist)) > 0, c("id", "codelist", "sentinel")])
}

#' CODES.UNKNOWN: every coded cell is in its codelist, or is a sentinel the
#' DSD allows for that column. ESTIMATION is checked against
#' CL_ESTIMATION here like every other key column.
vc_codes_unknown <- function(ctx) {
  out <- list()
  coded <- .codes_coded_columns(ctx)
  coded <- coded[!(coded$id %in% .CODES_OWN_CHECK_COLS), , drop = FALSE]
  for (f in .codes_files(ctx)) {
    df <- f$df
    ok <- f$ok
    if (length(ok) == 0) next
    msgs <- rep("", nrow(df))
    for (r in seq_len(nrow(coded))) {
      col <- coded$id[r]
      sentinels <- .codes_tokens(coded$sentinel[r])
      codes <- .codes_codelist_codes(ctx, coded$codelist[r])
      val <- as.character(df[[col]])
      bad <- !(val %in% sentinels) & !(val %in% codes)
      bad[-ok] <- FALSE
      msgs[bad] <- paste0(msgs[bad], ifelse(msgs[bad] == "", "", "; "), col, "=", val[bad])
    }
    hit <- which(msgs != "")
    if (length(hit) > 0) {
      out[[length(out) + 1]] <- .vc_finding(
        "CODES.UNKNOWN", "ERROR", f$file, f$row_keys[hit],
        paste0("unknown code(s): ", msgs[hit])
      )
    }
  }
  .vc_bind(out)
}

#' CODES.GEO_AREA: GEO is `_T`, or a CL_GEO code of the row's REF_AREA.
#' Skips a GEO value that is not a CL_GEO code at all (CODES.UNKNOWN's job).
vc_codes_geo_area <- function(ctx) {
  out <- list()
  geo <- ctx$meta$CL_GEO
  if (is.null(geo)) return(.vc_empty())
  pairs <- paste(geo$code, geo$ref_area)
  for (f in .codes_files(ctx)) {
    df <- f$df
    g <- df$GEO
    bad <- seq_len(nrow(df)) %in% f$ok & g != SENTINEL_TOTAL & g %in% geo$code &
      !(paste(g, df$REF_AREA) %in% pairs)
    hit <- which(bad)
    if (length(hit) > 0) {
      out[[length(out) + 1]] <- .vc_finding(
        "CODES.GEO_AREA", "ERROR", f$file, f$row_keys[hit],
        paste0("GEO ", g[hit], " is not a CL_GEO code of REF_AREA ", df$REF_AREA[hit])
      )
    }
  }
  .vc_bind(out)
}

#' CODES.GEO_ADM0: a geometry-only ADM0 code is never used in GEO.
vc_codes_geo_adm0 <- function(ctx) {
  out <- list()
  geo <- ctx$meta$CL_GEO
  adm0_codes <- if (is.null(geo)) character(0) else geo$code[geo$scheme == "ADM0"]
  for (f in .codes_files(ctx)) {
    g <- f$df$GEO
    hit <- which(seq_along(g) %in% f$ok & g %in% adm0_codes)
    if (length(hit) > 0) {
      out[[length(out) + 1]] <- .vc_finding(
        "CODES.GEO_ADM0", "ERROR", f$file, f$row_keys[hit],
        paste0("GEO ", g[hit], " is a geometry-only ADM0 code; the whole country is _T")
      )
    }
  }
  .vc_bind(out)
}

#' Shared engine for CODES.BRK_SLOTS and CODES.QUAL_SLOTS: the slot columns
#' are filled from the left, ascending slot_order (ties by var_code), no
#' variable used twice, unused slots hold `pad`.
.codes_slots_check <- function(ctx, check_id, cols, code_tbl, var_tbl, pad) {
  out <- list()
  if (is.null(code_tbl) || is.null(var_tbl)) return(.vc_empty())
  var_of <- stats::setNames(code_tbl$var_code, code_tbl$code)
  slot_order_of <- stats::setNames(var_tbl$slot_order, var_tbl$code)
  for (f in .codes_files(ctx)) {
    m <- as.matrix(f$df[cols])
    combos <- do.call(paste, c(as.data.frame(m, stringsAsFactors = FALSE), sep = "\r"))
    rows <- f$ok[rowSums(m[f$ok, , drop = FALSE] != pad) > 0]
    verdict <- list()
    for (i in rows) {
      cmb <- combos[i]
      if (is.null(verdict[[cmb]])) {
        actual <- m[i, ]
        used <- actual[actual != pad]
        vars_used <- unname(var_of[used])
        if (any(is.na(vars_used))) {
          verdict[[cmb]] <- "" # unknown code: CODES.UNKNOWN's job
        } else {
          dup_var <- anyDuplicated(vars_used) > 0
          expected_slots <- tryCatch(
            fill_slots(slot_sort(used, var_of, slot_order_of), n = length(cols), pad = pad),
            error = function(e) NULL
          )
          mismatch <- !is.null(expected_slots) && !identical(unname(expected_slots), unname(actual))
          msg <- ""
          if (dup_var || mismatch) {
            msg <- paste0("slots not left-packed in ascending slot_order: found [", paste(actual, collapse = ","), "]")
            if (dup_var) msg <- paste0(msg, "; a variable is used more than once")
          }
          verdict[[cmb]] <- msg
        }
      }
      if (nzchar(verdict[[cmb]])) {
        out[[length(out) + 1]] <- .vc_finding(check_id, "ERROR", f$file, f$row_keys[i], verdict[[cmb]])
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
  ind <- ctx$meta$CL_INDICATOR
  if (is.null(ind)) return(.vc_empty())
  stat_unit_of <- stats::setNames(ind$stat_unit, ind$code)
  for (f in .codes_files(ctx)) {
    df <- f$df
    su <- unname(stat_unit_of[df$INDICATOR])
    want_z <- su != "IND"
    sex_bad <- want_z != (df$SEX == SENTINEL_NA)
    age_bad <- want_z != (df$AGE == SENTINEL_NA)
    bad <- seq_len(nrow(df)) %in% f$ok & !is.na(su) & (sex_bad | age_bad)
    hit <- which(bad)
    if (length(hit) == 0) next
    what <- ifelse(sex_bad[hit] & age_bad[hit], "SEX and AGE", ifelse(sex_bad[hit], "SEX", "AGE"))
    out[[length(out) + 1]] <- .vc_finding(
      "CODES.SEX_AGE_UNIT", "ERROR", f$file, f$row_keys[hit],
      paste0(
        what, ifelse(want_z[hit], " must be _Z", " must not be _Z"),
        " because INDICATOR ", df$INDICATOR[hit], " has stat_unit ", su[hit]
      )
    )
  }
  .vc_bind(out)
}

#' CODES.BRK_UNIT: every breakdown variable used lists the indicator's
#' stat_unit in its applies_to_units.
vc_codes_brk_unit <- function(ctx) {
  out <- list()
  cb <- ctx$meta$CL_COMP_BREAKDOWN
  bv <- ctx$meta$CL_BRK_VAR
  ind <- ctx$meta$CL_INDICATOR
  if (is.null(cb) || is.null(bv) || is.null(ind)) return(.vc_empty())
  var_of <- stats::setNames(cb$var_code, cb$code)
  applies_of <- stats::setNames(bv$applies_to_units, bv$code)
  stat_unit_of <- stats::setNames(ind$stat_unit, ind$code)
  for (f in .codes_files(ctx)) {
    df <- f$df
    m <- as.matrix(df[.CODES_BRK_COLS])
    for (i in f$ok) {
      su <- unname(stat_unit_of[df$INDICATOR[i]])
      if (is.na(su)) next
      used <- m[i, ]
      used <- used[used != SENTINEL_TOTAL]
      if (length(used) == 0) next
      bad <- character(0)
      for (code in used) {
        var <- unname(var_of[code])
        if (is.na(var)) next
        if (!(su %in% .codes_tokens(unname(applies_of[var])))) bad <- c(bad, code)
      }
      if (length(bad) > 0) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.BRK_UNIT", "ERROR", f$file, f$row_keys[i],
          paste0("breakdown code(s) do not apply to stat_unit ", su, ": ", paste(bad, collapse = ", "))
        )
      }
    }
  }
  .vc_bind(out)
}

#' The qualifier variables a row's breakdowns require
#' (CL_BRK_VAR.requires_qual of every breakdown category used).
.codes_required_qual_vars <- function(used_brk, bvar_of, requires_qual_of) {
  req <- character(0)
  for (bc in used_brk) {
    v <- unname(bvar_of[bc])
    if (is.na(v)) next
    req <- c(req, .codes_tokens(unname(requires_qual_of[v])))
  }
  unique(req)
}

#' CODES.QUAL_DECLARED: every qualifier used is declared for the indicator
#' in INDICATOR_QUALIFIERS.csv with its category among `allowed` (`*` for
#' any), or is of a variable required by a breakdown used in the same row.
vc_codes_qual_declared <- function(ctx) {
  out <- list()
  ind <- ctx$meta$CL_INDICATOR
  iq <- ctx$meta$INDICATOR_QUALIFIERS
  cq <- ctx$meta$CL_QUALIFIER
  cb <- ctx$meta$CL_COMP_BREAKDOWN
  bv <- ctx$meta$CL_BRK_VAR
  if (is.null(ind) || is.null(iq) || is.null(cq) || is.null(cb) || is.null(bv)) return(.vc_empty())
  qvar_of <- stats::setNames(cq$var_code, cq$code)
  bvar_of <- stats::setNames(cb$var_code, cb$code)
  requires_qual_of <- stats::setNames(bv$requires_qual, bv$code)
  allowed_of <- stats::setNames(iq$allowed, paste(iq$indicator, iq$qual_var))
  for (f in .codes_files(ctx)) {
    df <- f$df
    mb <- as.matrix(df[.CODES_BRK_COLS])
    mq <- as.matrix(df[.CODES_QUAL_COLS])
    for (i in f$ok) {
      indicator <- df$INDICATOR[i]
      if (!(indicator %in% ind$code)) next # unknown indicator: CODES.UNKNOWN's job
      used_qual <- mq[i, ]
      used_qual <- used_qual[used_qual != SENTINEL_NA]
      if (length(used_qual) == 0) next
      used_brk <- mb[i, ]
      req_vars <- .codes_required_qual_vars(used_brk[used_brk != SENTINEL_TOTAL], bvar_of, requires_qual_of)
      bad <- character(0)
      for (qc in used_qual) {
        var <- unname(qvar_of[qc])
        if (is.na(var)) next # unknown qualifier code: CODES.UNKNOWN's job
        allowed <- unname(allowed_of[paste(indicator, var)])
        ok <- !is.na(allowed) && (identical(trimws(allowed), "*") || qc %in% .codes_tokens(allowed))
        if (!ok && var %in% req_vars) ok <- TRUE
        if (!ok) bad <- c(bad, qc)
      }
      if (length(bad) > 0) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.QUAL_DECLARED", "ERROR", f$file, f$row_keys[i],
          paste0(
            "qualifier(s) not declared for INDICATOR ", indicator,
            " in INDICATOR_QUALIFIERS.csv and not required by a breakdown in this row: ",
            paste(bad, collapse = ", ")
          )
        )
      }
    }
  }
  .vc_bind(out)
}

#' CODES.QUAL_PAIRS (formerly CODES.VALID_WITH): the qualifier categories
#' of a row pair as QUALIFIER_PAIRS.csv allows, and every variable a used
#' qualifier variable `requires` (CL_QUAL_VAR) is present.
#'
#' For a used category `q` and a QUALIFIER_PAIRS row (`q`, `with_var`,
#' `allowed`): `allowed = _Z` means `with_var` must be absent, and it
#' overrides `with_var` being required; otherwise, when `with_var` is
#' present, its category must be among `allowed`.
vc_codes_qual_pairs <- function(ctx) {
  out <- list()
  cq <- ctx$meta$CL_QUALIFIER
  qv <- ctx$meta$CL_QUAL_VAR
  qp <- ctx$meta$QUALIFIER_PAIRS
  if (is.null(cq) || is.null(qv)) return(.vc_empty())
  if (is.null(qp)) {
    qp <- data.frame(qualifier = character(0), with_var = character(0), allowed = character(0))
  }
  qvar_of <- stats::setNames(cq$var_code, cq$code)
  requires_of <- stats::setNames(qv$requires, qv$code)
  pair_allowed <- stats::setNames(qp$allowed, paste(qp$qualifier, qp$with_var))
  pairs_of <- split(qp$with_var, qp$qualifier)
  for (f in .codes_files(ctx)) {
    mq <- as.matrix(f$df[.CODES_QUAL_COLS])
    combos <- do.call(paste, c(as.data.frame(mq, stringsAsFactors = FALSE), sep = "\r"))
    verdict <- list()
    rows <- f$ok[rowSums(mq[f$ok, , drop = FALSE] != SENTINEL_NA) > 0]
    for (i in rows) {
      cmb <- combos[i]
      if (is.null(verdict[[cmb]])) {
        used <- mq[i, ]
        used <- used[used != SENTINEL_NA]
        present <- character(0)
        for (qc in used) {
          v <- unname(qvar_of[qc])
          if (!is.na(v)) present[v] <- qc
        }
        problems <- character(0)
        for (qc in used) {
          var <- unname(qvar_of[qc])
          if (is.na(var)) next # unknown qualifier code: CODES.UNKNOWN's job
          for (w in unique(pairs_of[[qc]])) {
            allowed <- .codes_tokens(unname(pair_allowed[paste(qc, w)]))
            if (identical(allowed, SENTINEL_NA)) {
              if (w %in% names(present)) {
                problems <- c(problems, paste0(qc, " takes no ", w, " (found ", present[[w]], ")"))
              }
            } else if (w %in% names(present) && !(present[[w]] %in% allowed)) {
              problems <- c(problems, paste0(
                qc, " pairs only with ", paste(allowed, collapse = " "), " (found ", present[[w]], ")"
              ))
            }
          }
          for (rv in .codes_tokens(unname(requires_of[var]))) {
            if (rv %in% names(present)) next
            waived <- identical(.codes_tokens(unname(pair_allowed[paste(qc, rv)])), SENTINEL_NA)
            if (!waived) problems <- c(problems, paste0(qc, " requires a ", rv, " qualifier"))
          }
        }
        verdict[[cmb]] <- paste(unique(problems), collapse = "; ")
      }
      if (nzchar(verdict[[cmb]])) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.QUAL_PAIRS", "ERROR", f$file, f$row_keys[i],
          paste0("qualifier pairing not allowed by QUALIFIER_PAIRS.csv / CL_QUAL_VAR.requires: ", verdict[[cmb]])
        )
      }
    }
  }
  .vc_bind(out)
}

#' CODES.SERIES_ID: SERIES_ID is filled, names a SERIES_PLAN row that
#' applies to the row's REF_AREA (the country row over the ALL row), and
#' the row's INDICATOR, qualifier categories and (for a share series)
#' defining category equal the plan row's (D13).
vc_codes_series_id <- function(ctx) {
  out <- list()
  sp <- ctx$meta$SERIES_PLAN
  if (is.null(sp)) return(.vc_empty())
  plans <- list()
  for (f in .codes_files(ctx)) {
    df <- f$df
    mb <- as.matrix(df[.CODES_BRK_COLS])
    mq <- as.matrix(df[.CODES_QUAL_COLS])
    msgs <- rep("", nrow(df))
    for (i in f$ok) {
      sid <- df$SERIES_ID[i]
      ra <- df$REF_AREA[i]
      if (is.na(sid) || trimws(sid) == "") {
        msgs[i] <- "SERIES_ID is empty"
        next
      }
      if (is.null(plans[[ra]])) plans[[ra]] <- effective_series_plan(ctx$meta, ra)
      plan <- plans[[ra]]
      p <- match(sid, plan$series_id)
      if (is.na(p)) {
        msgs[i] <- paste0("SERIES_ID ", sid, " is not in SERIES_PLAN.csv for REF_AREA ", ra)
        next
      }
      problems <- character(0)
      if (!identical(df$INDICATOR[i], plan$INDICATOR[p])) {
        problems <- c(problems, paste0("INDICATOR ", df$INDICATOR[i], " but the plan says ", plan$INDICATOR[p]))
      }
      row_quals <- mq[i, ]
      row_quals <- sort(row_quals[row_quals != SENTINEL_NA], method = "radix")
      plan_quals <- sort(.codes_tokens(plan$MEASURE_QUALS[p]), method = "radix")
      if (!identical(unname(row_quals), plan_quals)) {
        problems <- c(problems, paste0(
          "qualifiers [", paste(row_quals, collapse = " "), "] but the plan says [",
          paste(plan_quals, collapse = " "), "]"
        ))
      }
      def <- trimws(plan$DEFINING_BREAKDOWN[p])
      if (!is.na(def) && def != "" && !(def %in% mb[i, ])) {
        problems <- c(problems, paste0("defining category ", def, " is not among the breakdown slots"))
      }
      if (length(problems) > 0) {
        msgs[i] <- paste0("SERIES_ID ", sid, " disagrees with the row: ", paste(problems, collapse = "; "))
      }
    }
    hit <- which(msgs != "")
    if (length(hit) > 0) {
      out[[length(out) + 1]] <- .vc_finding("CODES.SERIES_ID", "ERROR", f$file, f$row_keys[hit], msgs[hit])
    }
  }
  .vc_bind(out)
}

#' CODES.UNIT: UNIT_MEASURE equals the indicator's unit_measure or, where
#' that is LCU, the currency of the row's REF_AREA in CL_AREA (D14).
vc_codes_unit <- function(ctx) {
  out <- list()
  ind <- ctx$meta$CL_INDICATOR
  area <- ctx$meta$CL_AREA
  if (is.null(ind) || !("unit_measure" %in% names(ind))) return(.vc_empty())
  unit_of <- stats::setNames(ind$unit_measure, ind$code)
  currency_of <- if (is.null(area)) character(0) else stats::setNames(area$currency, area$code)
  for (f in .codes_files(ctx)) {
    df <- f$df
    expected <- unname(unit_of[df$INDICATOR])
    lcu <- !is.na(expected) & expected == "LCU"
    expected[lcu] <- unname(currency_of[df$REF_AREA[lcu]])
    actual <- as.character(df$UNIT_MEASURE)
    known_ind <- df$INDICATOR %in% ind$code
    bad <- seq_len(nrow(df)) %in% f$ok & known_ind & (is.na(expected) | actual != expected)
    hit <- which(bad)
    if (length(hit) == 0) next
    out[[length(out) + 1]] <- .vc_finding(
      "CODES.UNIT", "ERROR", f$file, f$row_keys[hit],
      ifelse(
        is.na(expected[hit]),
        paste0(
          "UNIT_MEASURE '", actual[hit], "' cannot be checked: INDICATOR ", df$INDICATOR[hit],
          " has unit LCU and REF_AREA ", df$REF_AREA[hit], " has no CL_AREA currency"
        ),
        paste0(
          "UNIT_MEASURE '", actual[hit], "' differs from '", expected[hit], "' (INDICATOR ",
          df$INDICATOR[hit], ", unit_measure ", unname(unit_of[df$INDICATOR[hit]]), ")"
        )
      )
    )
  }
  .vc_bind(out)
}

#' CODES.SOURCE_ID: SOURCE_ID is filled, exists in SOURCES.csv with the
#' row's REF_AREA, and is listed in the manifest's `sources` (D16). An
#' unknown or wrong-country id is reported per row; an id missing from the
#' manifest once per file (row_key `SOURCE_ID=<id>`).
vc_codes_source_id <- function(ctx) {
  out <- list()
  src <- ctx$meta$SOURCES
  src_area <- if (is.null(src)) character(0) else stats::setNames(src$ref_area, src$source_id)
  for (f in .codes_files(ctx)) {
    df <- f$df
    sid <- as.character(df$SOURCE_ID)
    in_ok <- seq_len(nrow(df)) %in% f$ok
    empty <- in_ok & (is.na(sid) | trimws(sid) == "")
    unknown <- in_ok & !empty & !(sid %in% names(src_area))
    wrong_area <- in_ok & !empty & !unknown & unname(src_area[sid]) != df$REF_AREA
    msgs <- rep("", nrow(df))
    msgs[empty] <- "SOURCE_ID is empty"
    msgs[unknown] <- paste0("SOURCE_ID ", sid[unknown], " is not in SOURCES.csv")
    msgs[wrong_area] <- paste0(
      "SOURCE_ID ", sid[wrong_area], " belongs to ref_area ", unname(src_area[sid[wrong_area]]),
      ", not ", df$REF_AREA[wrong_area]
    )
    hit <- which(msgs != "")
    if (length(hit) > 0) {
      out[[length(out) + 1]] <- .vc_finding("CODES.SOURCE_ID", "ERROR", f$file, f$row_keys[hit], msgs[hit])
    }
    man <- ctx$manifests[[f$key]]
    if (!is.null(man) && "sources" %in% names(man)) {
      listed <- .codes_tokens(man[["sources"]])
      used <- sort(unique(sid[in_ok & !empty]), method = "radix")
      for (s in setdiff(used, listed)) {
        out[[length(out) + 1]] <- .vc_finding(
          "CODES.SOURCE_ID", "ERROR", f$file, paste0("SOURCE_ID=", s),
          paste0("SOURCE_ID ", s, " is used in the file but not listed in the manifest's sources")
        )
      }
    }
  }
  .vc_bind(out)
}

#' CODES.DRAFT: a DRAFT code used in a data file gives WARN when the file's
#' manifest has status = DRAFT, and ERROR otherwise. One finding per file
#' and code. Covers every coded DSD column, SERIES_ID (SERIES_PLAN status)
#' and SOURCE_ID (SOURCES status) included.
vc_codes_draft <- function(ctx) {
  out <- list()
  coded <- .codes_coded_columns(ctx)
  for (f in .codes_files(ctx)) {
    df <- f$df
    manifest_status <- unname(ctx$manifests[[f$key]]["status"])
    sev <- if (!is.na(manifest_status) && manifest_status == "DRAFT") "WARN" else "ERROR"
    draft_codes <- character(0)
    for (r in seq_len(nrow(coded))) {
      cl <- coded$codelist[r]
      cltab <- ctx$meta[[cl]]
      codes <- .codes_codelist_codes(ctx, cl)
      if (is.null(cltab) || is.null(codes) || !("status" %in% names(cltab))) next
      vals <- unique(as.character(df[[coded$id[r]]][f$ok]))
      vals <- setdiff(vals, SENTINELS)
      st <- cltab$status[match(vals, codes)]
      draft_codes <- c(draft_codes, vals[!is.na(st) & st == "DRAFT"])
    }
    draft_codes <- unique(draft_codes)
    for (dc in draft_codes) {
      out[[length(out) + 1]] <- .vc_finding(
        "CODES.DRAFT", sev, f$file, paste0("code=", dc),
        paste0(
          "DRAFT code used in data file (manifest status ",
          if (is.na(manifest_status)) "unknown" else manifest_status, ")"
        )
      )
    }
  }
  .vc_bind(out)
}
