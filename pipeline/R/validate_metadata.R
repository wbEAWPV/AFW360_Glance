# pipeline/R/validate_metadata.R
#
# WP11 validator module META: checks of the metadata and content CSVs
# themselves (header shape against metadata/structure/COLUMNS.csv, required
# columns, code syntax, code uniqueness, cross-file references, TBD
# tracking and slot_order ties), and of the metadata 0.2.0 tables RULES.csv,
# INDICATOR_QUALIFIERS.csv, QUALIFIER_PAIRS.csv, SERIES_PLAN.csv (its
# estimation/status/series_id rules) and SOURCES.csv. Depends on
# pipeline/R/io.R (sha256_file()), constants.R,
# codes.R (is_valid_code(), TBD) and ctx.R. ctx$meta is a named list of
# tibbles keyed by file stem (load_metadata()); this module rebuilds the
# stem -> relative-path map itself because build_ctx() does not carry it.

#' stem -> "metadata/.../FILE.csv" or "content/.../FILE.csv", forward
#' slashes, for every CSV under `<root>/metadata` and `<root>/content`.
.meta_all_files_rel <- function(root) {
  out <- character(0)
  for (d in c("metadata", "content")) {
    full_d <- file.path(root, d)
    if (!dir.exists(full_d)) next
    fs <- list.files(full_d, pattern = "\\.csv$", recursive = TRUE, full.names = FALSE)
    if (length(fs) == 0) next
    rels <- gsub("\\\\", "/", file.path(d, fs))
    names(rels) <- tools::file_path_sans_ext(basename(fs))
    out <- c(out, rels)
  }
  out
}

#' The column(s) that identify a row, per file stem; falls back to "code"
#' when present, else the first column.
.META_KEY_MAP <- list(
  SERIES_PLAN = c("series_id", "ref_area"),
  RULES = "rule_id",
  INDICATOR_QUALIFIERS = c("indicator", "qual_var"),
  QUALIFIER_PAIRS = c("qualifier", "with_var"),
  SOURCES = "source_id",
  LEGACY_LABELS = c("legacy_label", "sheet"),
  LEGACY_COLUMNS = c("ref_area", "sheet", "column"),
  LEGACY_OVERRIDES = c("ref_area", "sheet", "column", "legacy_label"),
  TAB_PLAN = c("cut_id", "ref_area"),
  FIGURES = "figure_id",
  GEO_SOURCES = "source_id",
  SURVEYS = "survey_id",
  TEXT = c("slot", "ref_area", "time_period", "order"),
  COLUMNS = c("file", "column"),
  DSD_AFW360_HH = "id",
  CL_GEO_SCHEME = c("ref_area", "code")
)

.meta_key_cols <- function(stem, df) {
  cols <- .META_KEY_MAP[[stem]]
  if (!is.null(cols)) {
    cols <- cols[cols %in% names(df)]
    if (length(cols) > 0) return(cols)
  }
  if ("code" %in% names(df)) return("code")
  names(df)[1]
}

.meta_row_key <- function(stem, df, i) {
  cols <- .meta_key_cols(stem, df)
  vals <- as.character(unlist(df[i, cols]))
  paste(paste0(cols, "=", vals), collapse = " ")
}

#' META.HEADER: each file listed in COLUMNS.csv that exists has exactly
#' those columns, in order.
vc_meta_header <- function(ctx) {
  out <- list()
  cols <- ctx$meta$COLUMNS
  if (is.null(cols)) return(.vc_empty())
  file_map <- .meta_all_files_rel(ctx$root)
  for (f in unique(cols$file)) {
    stem <- tools::file_path_sans_ext(f)
    df <- ctx$meta[[stem]]
    if (is.null(df)) next
    spec <- cols[cols$file == f, ]
    spec <- spec[order(as.integer(spec$position), method = "radix"), ]
    expected <- spec$column
    actual <- names(df)
    if (!identical(actual, expected)) {
      out[[length(out) + 1]] <- .vc_finding(
        "META.HEADER", "ERROR", unname(file_map[stem]), "",
        paste0(
          "header does not match COLUMNS.csv: expected [", paste(expected, collapse = ", "),
          "], found [", paste(actual, collapse = ", "), "]"
        )
      )
    }
  }
  .vc_bind(out)
}

#' META.REQUIRED: every R column is filled.
vc_meta_required <- function(ctx) {
  out <- list()
  cols <- ctx$meta$COLUMNS
  if (is.null(cols)) return(.vc_empty())
  file_map <- .meta_all_files_rel(ctx$root)
  for (f in unique(cols$file)) {
    stem <- tools::file_path_sans_ext(f)
    df <- ctx$meta[[stem]]
    if (is.null(df)) next
    spec <- cols[cols$file == f, ]
    req_cols <- spec$column[spec$status == "R"]
    req_cols <- req_cols[req_cols %in% names(df)]
    if (length(req_cols) == 0 || nrow(df) == 0) next
    rel <- unname(file_map[stem])
    for (i in seq_len(nrow(df))) {
      vals <- as.character(unlist(df[i, req_cols]))
      missing_cols <- req_cols[is.na(vals) | trimws(vals) == ""]
      if (length(missing_cols) > 0) {
        out[[length(out) + 1]] <- .vc_finding(
          "META.REQUIRED", "ERROR", rel, .meta_row_key(stem, df, i),
          paste0("required column(s) empty: ", paste(missing_cols, collapse = ", "))
        )
      }
    }
  }
  .vc_bind(out)
}

#' META.CODE_SYNTAX: the code column of every CL_* file passes the code
#' pattern, and no code starts with `_` (D21: `_T`, `_Z`, `_U`, `_O` and
#' `_X` are the only values that do; is_valid_code() enforces both, since a
#' code must start with a letter).
vc_meta_code_syntax <- function(ctx) {
  out <- list()
  file_map <- .meta_all_files_rel(ctx$root)
  for (stem in names(ctx$meta)) {
    if (!grepl("^CL_", stem)) next
    df <- ctx$meta[[stem]]
    if (!("code" %in% names(df)) || nrow(df) == 0) next
    rel <- unname(file_map[stem])
    bad_idx <- which(!is_valid_code(df$code))
    for (i in bad_idx) {
      out[[length(out) + 1]] <- .vc_finding(
        "META.CODE_SYNTAX", "ERROR", rel, .meta_row_key(stem, df, i),
        if (!is.na(df$code[i]) && startsWith(df$code[i], "_")) {
          paste0("code '", df$code[i], "' starts with '_', which is reserved for the sentinels _T _Z _U _O _X")
        } else {
          paste0("code '", df$code[i], "' fails the code pattern")
        }
      )
    }
  }
  .vc_bind(out)
}

#' META.CODE_UNIQUE: codes are unique within a file. CL_GEO_SCHEME is
#' unique on ref_area plus code.
vc_meta_code_unique <- function(ctx) {
  out <- list()
  file_map <- .meta_all_files_rel(ctx$root)
  for (stem in names(ctx$meta)) {
    if (!grepl("^CL_", stem)) next
    df <- ctx$meta[[stem]]
    if (!("code" %in% names(df)) || nrow(df) == 0) next
    rel <- unname(file_map[stem])
    if (stem == "CL_GEO_SCHEME" && "ref_area" %in% names(df)) {
      key_cols <- c("ref_area", "code")
      keys <- paste(df$ref_area, df$code)
    } else {
      key_cols <- "code"
      keys <- df$code
    }
    dup <- duplicated(keys) | duplicated(keys, fromLast = TRUE)
    seen <- character(0)
    for (i in which(dup)) {
      rk <- paste(paste0(key_cols, "=", as.character(unlist(df[i, key_cols]))), collapse = " ")
      if (rk %in% seen) next
      seen <- c(seen, rk)
      out[[length(out) + 1]] <- .vc_finding(
        "META.CODE_UNIQUE", "ERROR", rel, rk, "duplicate code within file"
      )
    }
  }
  .vc_bind(out)
}

#' META.REFERENCE: every reference listed on the card resolves.
vc_meta_reference <- function(ctx) {
  out <- list()
  file_map <- .meta_all_files_rel(ctx$root)
  meta <- ctx$meta

  check_field <- function(src_stem, src_col, tgt_stem, tgt_col, multi = FALSE, skip = c("_T", "_Z")) {
    df <- meta[[src_stem]]
    tgt <- meta[[tgt_stem]]
    if (is.null(df) || is.null(tgt)) return(invisible())
    if (!(src_col %in% names(df)) || !(tgt_col %in% names(tgt))) return(invisible())
    if (nrow(df) == 0) return(invisible())
    target_codes <- tgt[[tgt_col]]
    rel <- unname(file_map[src_stem])
    for (i in seq_len(nrow(df))) {
      val <- trimws(df[[src_col]][i])
      if (is.na(val) || val == "") next
      toks <- if (multi) strsplit(val, "\\s+")[[1]] else val
      toks <- setdiff(toks, skip)
      bad <- toks[!(toks %in% target_codes)]
      if (length(bad) > 0) {
        out[[length(out) + 1]] <<- .vc_finding(
          "META.REFERENCE", "ERROR", rel, .meta_row_key(src_stem, df, i),
          paste0(
            src_col, " references unknown ", tgt_stem, ".", tgt_col, ": ",
            paste(bad, collapse = ", ")
          )
        )
      }
    }
  }

  # Self-references: replaced_by and parent, generic over every file that
  # has a "code" column.
  for (stem in names(meta)) {
    df <- meta[[stem]]
    if (!("code" %in% names(df))) next
    if ("replaced_by" %in% names(df)) check_field(stem, "replaced_by", stem, "code")
    if ("parent" %in% names(df)) check_field(stem, "parent", stem, "code")
  }

  check_field("CL_COMP_BREAKDOWN", "var_code", "CL_BRK_VAR", "code")
  check_field("CL_QUALIFIER", "var_code", "CL_QUAL_VAR", "code")
  check_field("CL_GEO", "source_id", "GEO_SOURCES", "source_id")
  check_field("CL_GEO", "scheme", "CL_GEO_SCHEME", "code")
  check_field("CL_GEO_SCHEME", "nests_in", "CL_GEO_SCHEME", "code")
  check_field("CL_QUAL_VAR", "requires", "CL_QUAL_VAR", "code", multi = TRUE)
  check_field("CL_BRK_VAR", "requires_qual", "CL_QUAL_VAR", "code", multi = TRUE)
  check_field("CL_INDICATOR", "theme", "CL_THEME", "code")
  check_field("CL_INDICATOR", "stat_unit", "CL_STAT_UNIT", "code")
  check_field("CL_INDICATOR", "statistic", "CL_STATISTIC", "code")
  check_field("CL_INDICATOR", "weight", "CL_WEIGHT", "code")
  check_field("CL_INDICATOR", "unit_measure", "CL_UNIT", "code")
  check_field("SERIES_PLAN", "INDICATOR", "CL_INDICATOR", "code")
  check_field("SERIES_PLAN", "MEASURE_QUALS", "CL_QUALIFIER", "code", multi = TRUE)
  check_field("SERIES_PLAN", "DEFINING_BREAKDOWN", "CL_COMP_BREAKDOWN", "code")
  check_field("SERIES_PLAN", "ref_area", "CL_AREA", "code", skip = c("ALL"))
  check_field("INDICATOR_QUALIFIERS", "indicator", "CL_INDICATOR", "code")
  check_field("INDICATOR_QUALIFIERS", "qual_var", "CL_QUAL_VAR", "code")
  check_field("QUALIFIER_PAIRS", "qualifier", "CL_QUALIFIER", "code")
  check_field("QUALIFIER_PAIRS", "with_var", "CL_QUAL_VAR", "code")
  check_field("SOURCES", "ref_area", "CL_AREA", "code")
  check_field("SOURCES", "survey_id", "SURVEYS", "survey_id")
  check_field("SURVEYS", "ref_area", "CL_AREA", "code")
  check_field("LEGACY_LABELS", "series_id", "SERIES_PLAN", "series_id")
  check_field("LEGACY_COLUMNS", "GEO", "CL_GEO", "code")
  check_field("LEGACY_COLUMNS", "URBANISATION", "CL_URBANISATION", "code")
  check_field("LEGACY_COLUMNS", "COMP_BREAKDOWN", "CL_COMP_BREAKDOWN", "code")
  check_field("LEGACY_COLUMNS", "cut_id", "TAB_PLAN", "cut_id")

  .vc_bind(out)
}

#' META.TBD: `TBD` gives WARN on a DRAFT row, ERROR on any other row.
#' Applies only to files that carry a `status` column.
vc_meta_tbd <- function(ctx) {
  out <- list()
  cols <- ctx$meta$COLUMNS
  if (is.null(cols)) return(.vc_empty())
  file_map <- .meta_all_files_rel(ctx$root)
  for (f in unique(cols$file)) {
    stem <- tools::file_path_sans_ext(f)
    df <- ctx$meta[[stem]]
    if (is.null(df) || !("status" %in% names(df)) || nrow(df) == 0) next
    rel <- unname(file_map[stem])
    check_cols <- names(df)
    for (i in seq_len(nrow(df))) {
      vals <- as.character(unlist(df[i, check_cols]))
      tbd_cols <- check_cols[!is.na(vals) & vals == TBD]
      if (length(tbd_cols) == 0) next
      sev <- if (!is.na(df$status[i]) && df$status[i] == "DRAFT") "WARN" else "ERROR"
      out[[length(out) + 1]] <- .vc_finding(
        "META.TBD", sev, rel, .meta_row_key(stem, df, i),
        paste0("TBD in column(s): ", paste(tbd_cols, collapse = ", "))
      )
    }
  }
  .vc_bind(out)
}

#' META.SLOT_ORDER_TIE: a repeated slot_order gives WARN.
vc_meta_slot_order_tie <- function(ctx) {
  out <- list()
  file_map <- .meta_all_files_rel(ctx$root)
  for (stem in names(ctx$meta)) {
    df <- ctx$meta[[stem]]
    if (!("slot_order" %in% names(df)) || nrow(df) == 0) next
    rel <- unname(file_map[stem])
    dup <- duplicated(df$slot_order) | duplicated(df$slot_order, fromLast = TRUE)
    seen <- character(0)
    for (v in unique(df$slot_order[dup])) {
      if (v %in% seen) next
      seen <- c(seen, v)
      out[[length(out) + 1]] <- .vc_finding(
        "META.SLOT_ORDER_TIE", "WARN", rel, paste0("slot_order=", v), "repeated slot_order"
      )
    }
  }
  .vc_bind(out)
}

# ---- metadata 0.2.0 tables: RULES, relations, SERIES_PLAN, SOURCES -------

# The rule vocabulary of RULES.csv (standard, "Verification rules").
.META_RULE_VOCAB <- c(
  "RANGE_0_1", "RANGE_NONNEG", "AGG_SUM", "AGG_NPOP_MEAN", "AGG_BRACKET",
  "SUM_TO_1_OVER", "SUM_TO_1_OVER_BRK", "MONOTONE_IN",
  "RELIABILITY_MIN_NOBS", "RELIABILITY_MAX_CV"
)
.META_RULES_QUAL_PARAM <- c("SUM_TO_1_OVER", "MONOTONE_IN")
.META_RULES_THRESHOLDS <- c("RELIABILITY_MIN_NOBS", "RELIABILITY_MAX_CV")

#' Split a space-separated cell into tokens.
.meta_tokens <- function(x) {
  x <- trimws(x)
  if (length(x) == 0 || is.na(x) || x == "") return(character(0))
  strsplit(x, "\\s+")[[1]]
}

#' An empty-or-NA cell.
.meta_blank <- function(x) is.na(x) | trimws(x) == ""

#' A plain non-negative decimal number.
.meta_is_nonneg_number <- function(x) grepl("^[0-9]+(\\.[0-9]+)?$", trimws(x))

#' The file path of a metadata stem, relative to the root.
.meta_rel <- function(ctx, stem, fallback) {
  rel <- unname(.meta_all_files_rel(ctx$root)[stem])
  if (length(rel) == 0 || is.na(rel)) fallback else rel
}

#' META.RULES: every RULES.csv row has a known `rule`, a `scope` of
#' DATAFLOW / INDICATOR / SERIES with a `scope_code` that is empty for
#' DATAFLOW and resolves to an indicator or a series otherwise, a `param`
#' exactly where the rule takes one (a CL_QUAL_VAR code for SUM_TO_1_OVER
#' and MONOTONE_IN, a number for the two thresholds), a `tolerance` that is
#' empty or a non-negative number, a `severity` of ERROR or WARN, and a
#' unique `rule_id` equal to `<scope_code or AFW360_HH>.<rule>[.<param>]`
#' (a threshold's id may leave out the number). The two reliability
#' thresholds exist exactly once each, with scope DATAFLOW.
vc_meta_rules <- function(ctx) {
  out <- list()
  rules <- ctx$meta$RULES
  if (is.null(rules)) return(.vc_empty())
  rel <- .meta_rel(ctx, "RULES", "metadata/rules/RULES.csv")
  add <- function(row_key, msg) {
    out[[length(out) + 1]] <<- .vc_finding("META.RULES", "ERROR", rel, row_key, msg)
  }
  ind_codes <- ctx$meta$CL_INDICATOR$code
  series_ids <- ctx$meta$SERIES_PLAN$series_id
  qual_vars <- ctx$meta$CL_QUAL_VAR$code
  col <- function(nm) if (nm %in% names(rules)) as.character(rules[[nm]]) else rep("", nrow(rules))
  rule_id <- col("rule_id")
  scope <- col("scope")
  scope_code <- col("scope_code")
  rule <- col("rule")
  param <- col("param")
  tolerance <- col("tolerance")
  severity <- col("severity")

  for (i in seq_len(nrow(rules))) {
    rk <- paste0("rule_id=", rule_id[i])
    p <- character(0)
    if (!(rule[i] %in% .META_RULE_VOCAB)) p <- c(p, paste0("unknown rule '", rule[i], "'"))
    if (!(scope[i] %in% c("DATAFLOW", "INDICATOR", "SERIES"))) {
      p <- c(p, paste0("scope '", scope[i], "' is not DATAFLOW, INDICATOR or SERIES"))
    } else if (scope[i] == "DATAFLOW" && !.meta_blank(scope_code[i])) {
      p <- c(p, "scope_code must be empty for scope DATAFLOW")
    } else if (scope[i] == "INDICATOR" && !(scope_code[i] %in% ind_codes)) {
      p <- c(p, paste0("scope_code '", scope_code[i], "' is not a CL_INDICATOR code"))
    } else if (scope[i] == "SERIES" && !(scope_code[i] %in% series_ids)) {
      p <- c(p, paste0("scope_code '", scope_code[i], "' is not a SERIES_PLAN series_id"))
    }
    if (rule[i] %in% .META_RULES_QUAL_PARAM) {
      if (!(param[i] %in% qual_vars)) p <- c(p, paste0("param '", param[i], "' is not a CL_QUAL_VAR code"))
    } else if (rule[i] %in% .META_RULES_THRESHOLDS) {
      if (scope[i] != "DATAFLOW") p <- c(p, paste0(rule[i], " must have scope DATAFLOW"))
      ok_num <- .meta_is_nonneg_number(param[i])
      if (ok_num && rule[i] == "RELIABILITY_MIN_NOBS") ok_num <- grepl("^[0-9]+$", trimws(param[i]))
      if (ok_num && rule[i] == "RELIABILITY_MAX_CV") ok_num <- as.numeric(param[i]) > 0
      if (!ok_num) {
        p <- c(p, paste0(
          "param '", param[i], "' is not a ",
          if (rule[i] == "RELIABILITY_MIN_NOBS") "non-negative integer" else "positive number"
        ))
      }
    } else if (rule[i] %in% .META_RULE_VOCAB && !.meta_blank(param[i])) {
      p <- c(p, paste0("rule ", rule[i], " takes no param, found '", param[i], "'"))
    }
    if (!.meta_blank(tolerance[i]) && !.meta_is_nonneg_number(tolerance[i])) {
      p <- c(p, paste0("tolerance '", tolerance[i], "' is not a non-negative number"))
    }
    if (!(severity[i] %in% c("ERROR", "WARN"))) {
      p <- c(p, paste0("severity '", severity[i], "' is not ERROR or WARN"))
    }
    prefix <- if (scope[i] == "DATAFLOW") DATAFLOW_ID else scope_code[i]
    accepted <- paste0(prefix, ".", rule[i], if (!.meta_blank(param[i])) paste0(".", param[i]) else "")
    if (rule[i] %in% .META_RULES_THRESHOLDS) accepted <- c(paste0(prefix, ".", rule[i]), accepted)
    if (!(rule_id[i] %in% accepted)) {
      p <- c(p, paste0("rule_id should be '", accepted[1], "'"))
    }
    if (length(p) > 0) add(rk, paste(p, collapse = "; "))
  }

  for (d in unique(rule_id[duplicated(rule_id)])) add(paste0("rule_id=", d), "duplicate rule_id")
  for (th in .META_RULES_THRESHOLDS) {
    n <- sum(rule == th & scope == "DATAFLOW")
    if (n != 1) add("", paste0(th, " must exist exactly once with scope DATAFLOW; found ", n))
  }
  .vc_bind(out)
}

#' META.INDICATOR_QUALIFIERS: every row's `allowed` is `*` or a list of
#' CL_QUALIFIER categories of that row's `qual_var`, and an indicator lists
#' a qualifier variable at most once. (That `indicator` and `qual_var`
#' exist is META.REFERENCE's job.)
vc_meta_indicator_qualifiers <- function(ctx) {
  out <- list()
  iq <- ctx$meta$INDICATOR_QUALIFIERS
  cq <- ctx$meta$CL_QUALIFIER
  if (is.null(iq) || is.null(cq)) return(.vc_empty())
  rel <- .meta_rel(ctx, "INDICATOR_QUALIFIERS", "metadata/structure/INDICATOR_QUALIFIERS.csv")
  var_of <- stats::setNames(cq$var_code, cq$code)
  for (i in seq_len(nrow(iq))) {
    toks <- .meta_tokens(iq$allowed[i])
    if (identical(toks, "*") || length(toks) == 0) next # empty: META.REQUIRED's job
    bad <- toks[is.na(var_of[toks]) | var_of[toks] != iq$qual_var[i]]
    if (length(bad) > 0) {
      out[[length(out) + 1]] <- .vc_finding(
        "META.INDICATOR_QUALIFIERS", "ERROR", rel, .meta_row_key("INDICATOR_QUALIFIERS", iq, i),
        paste0("allowed lists code(s) that are not ", iq$qual_var[i], " categories: ", paste(bad, collapse = ", "))
      )
    }
  }
  keys <- paste(iq$indicator, iq$qual_var)
  for (i in which(duplicated(keys))) {
    out[[length(out) + 1]] <- .vc_finding(
      "META.INDICATOR_QUALIFIERS", "ERROR", rel, .meta_row_key("INDICATOR_QUALIFIERS", iq, i),
      "duplicate indicator and qual_var"
    )
  }
  .vc_bind(out)
}

#' META.QUALIFIER_PAIRS: every row's `allowed` is `_Z` alone or a list of
#' CL_QUALIFIER categories of `with_var`; `with_var` is not the qualifier's
#' own variable; a qualifier names a partner variable at most once. (That
#' `qualifier` and `with_var` exist is META.REFERENCE's job.)
vc_meta_qualifier_pairs <- function(ctx) {
  out <- list()
  qp <- ctx$meta$QUALIFIER_PAIRS
  cq <- ctx$meta$CL_QUALIFIER
  if (is.null(qp) || is.null(cq)) return(.vc_empty())
  rel <- .meta_rel(ctx, "QUALIFIER_PAIRS", "metadata/structure/QUALIFIER_PAIRS.csv")
  var_of <- stats::setNames(cq$var_code, cq$code)
  for (i in seq_len(nrow(qp))) {
    p <- character(0)
    toks <- .meta_tokens(qp$allowed[i])
    if (length(toks) > 0 && !identical(toks, SENTINEL_NA)) {
      if (SENTINEL_NA %in% toks) p <- c(p, "_Z must stand alone in allowed")
      toks <- setdiff(toks, SENTINEL_NA)
      bad <- toks[is.na(var_of[toks]) | var_of[toks] != qp$with_var[i]]
      if (length(bad) > 0) {
        p <- c(p, paste0(
          "allowed lists code(s) that are not ", qp$with_var[i], " categories: ", paste(bad, collapse = ", ")
        ))
      }
    }
    own <- unname(var_of[qp$qualifier[i]])
    if (!is.na(own) && identical(own, qp$with_var[i])) p <- c(p, "with_var is the qualifier's own variable")
    if (length(p) > 0) {
      out[[length(out) + 1]] <- .vc_finding(
        "META.QUALIFIER_PAIRS", "ERROR", rel, .meta_row_key("QUALIFIER_PAIRS", qp, i), paste(p, collapse = "; ")
      )
    }
  }
  keys <- paste(qp$qualifier, qp$with_var)
  for (i in which(duplicated(keys))) {
    out[[length(out) + 1]] <- .vc_finding(
      "META.QUALIFIER_PAIRS", "ERROR", rel, .meta_row_key("QUALIFIER_PAIRS", qp, i),
      "duplicate qualifier and with_var"
    )
  }
  .vc_bind(out)
}

#' The series id composed from a plan row: the indicator, its qualifier
#' categories in slot order, then its defining category, joined by `.`
#' (standard, "Code rules"). `NA` when a qualifier is unknown.
.meta_compose_series_id <- function(indicator, measure_quals, defining, var_of, slot_order_of) {
  quals <- .meta_tokens(measure_quals)
  if (length(quals) > 0) {
    if (any(!(quals %in% names(var_of)))) return(NA_character_)
    quals <- slot_sort(quals, var_of, slot_order_of)
  }
  parts <- c(indicator, quals)
  if (!.meta_blank(defining)) parts <- c(parts, trimws(defining))
  paste(parts, collapse = ".")
}

#' META.SERIES_PLAN: every row has an `estimation` of CL_ESTIMATION codes
#' (SURVEY, MODEL or both), a `status` among DRAFT, ACTIVE, NOT_PRODUCED
#' and DEVIATES, the last two only on a country row with `notes`; every
#' country row has an ALL row with the same series_id; (series_id,
#' ref_area) is unique; and series_id equals the id composed from the
#' row's INDICATOR, MEASURE_QUALS (slot order) and DEFINING_BREAKDOWN.
#' `name_en` must be filled; that is reported here only when COLUMNS.csv
#' does not already make it an R column (META.REQUIRED checks those). Its
#' wording is not checked: a human may overwrite the composed name.
vc_meta_series_plan <- function(ctx) {
  out <- list()
  sp <- ctx$meta$SERIES_PLAN
  if (is.null(sp) || nrow(sp) == 0) return(.vc_empty())
  rel <- .meta_rel(ctx, "SERIES_PLAN", "metadata/plans/SERIES_PLAN.csv")
  cq <- ctx$meta$CL_QUALIFIER
  qv <- ctx$meta$CL_QUAL_VAR
  var_of <- if (is.null(cq)) character(0) else stats::setNames(cq$var_code, cq$code)
  slot_order_of <- if (is.null(qv)) character(0) else stats::setNames(qv$slot_order, qv$code)
  est_codes <- ctx$meta$CL_ESTIMATION$code
  if (is.null(est_codes)) est_codes <- c("SURVEY", "MODEL")
  cols <- ctx$meta$COLUMNS
  name_is_r <- !is.null(cols) &&
    any(cols$file == "SERIES_PLAN.csv" & cols$column == "name_en" & cols$status == "R")
  col <- function(nm) if (nm %in% names(sp)) as.character(sp[[nm]]) else rep(NA_character_, nrow(sp))
  name_en <- col("name_en")
  estimation <- col("estimation")
  status <- col("status")
  notes <- col("notes")
  all_ids <- sp$series_id[sp$ref_area == "ALL"]

  for (i in seq_len(nrow(sp))) {
    p <- character(0)
    if (!name_is_r && .meta_blank(name_en[i])) p <- c(p, "name_en is empty")
    est <- .meta_tokens(estimation[i])
    if (length(est) == 0) {
      if (!("estimation" %in% names(sp))) p <- c(p, "the estimation column is missing")
    } else {
      bad <- setdiff(est, est_codes)
      if (length(bad) > 0) p <- c(p, paste0("estimation has unknown code(s): ", paste(bad, collapse = ", ")))
      if (anyDuplicated(est) > 0) p <- c(p, "estimation repeats a code")
    }
    st <- status[i]
    if (!(st %in% c("DRAFT", "ACTIVE", "NOT_PRODUCED", "DEVIATES"))) {
      p <- c(p, paste0("status '", st, "' is not DRAFT, ACTIVE, NOT_PRODUCED or DEVIATES"))
    }
    if (st %in% c("NOT_PRODUCED", "DEVIATES")) {
      if (sp$ref_area[i] == "ALL") {
        p <- c(p, paste0("status ", st, " is allowed only on a row for a specific ref_area"))
      }
      if (.meta_blank(notes[i])) p <- c(p, paste0("status ", st, " requires notes"))
    }
    if (sp$ref_area[i] != "ALL" && !(sp$series_id[i] %in% all_ids)) {
      p <- c(p, "country row has no ALL row with the same series_id")
    }
    composed <- .meta_compose_series_id(
      sp$INDICATOR[i], sp$MEASURE_QUALS[i], sp$DEFINING_BREAKDOWN[i], var_of, slot_order_of
    )
    if (!is.na(composed) && !identical(composed, sp$series_id[i])) {
      p <- c(p, paste0("series_id should be '", composed, "' (indicator, qualifiers in slot order, defining category)"))
    }
    if (length(p) > 0) {
      out[[length(out) + 1]] <- .vc_finding(
        "META.SERIES_PLAN", "ERROR", rel, .meta_row_key("SERIES_PLAN", sp, i), paste(p, collapse = "; ")
      )
    }
  }
  keys <- paste(sp$series_id, sp$ref_area)
  for (i in which(duplicated(keys))) {
    out[[length(out) + 1]] <- .vc_finding(
      "META.SERIES_PLAN", "ERROR", rel, .meta_row_key("SERIES_PLAN", sp, i),
      "duplicate series_id and ref_area"
    )
  }
  .vc_bind(out)
}

#' META.SOURCES: every SOURCES.csv row has a `kind` of LEGACY_CONVERSION or
#' PRODUCER, a unique `source_id` following the code rules, a `ref_area`
#' equal to its survey's, a `run_date` in ISO 8601 form, and, where an
#' `inputs` entry is a file under the root, a matching SHA-256 at the same
#' position of `inputs_sha256`. An input that is not a file under the root
#' (a dataset name, or a root copied without the raw inputs) is not
#' checksummed. That `survey_id` resolves is META.REFERENCE's job, and
#' that `program` and `program_version` are filled META.REQUIRED's.
vc_meta_sources <- function(ctx) {
  out <- list()
  src <- ctx$meta$SOURCES
  if (is.null(src) || nrow(src) == 0) return(.vc_empty())
  rel <- .meta_rel(ctx, "SOURCES", "metadata/registries/SOURCES.csv")
  surveys <- ctx$meta$SURVEYS
  survey_area <- if (is.null(surveys)) character(0) else stats::setNames(surveys$ref_area, surveys$survey_id)
  for (i in seq_len(nrow(src))) {
    p <- character(0)
    if (!(src$kind[i] %in% c("LEGACY_CONVERSION", "PRODUCER"))) {
      p <- c(p, paste0("kind '", src$kind[i], "' is not LEGACY_CONVERSION or PRODUCER"))
    }
    # The code rules allow uppercase only, but the standard's own pattern
    # <ISO3>_<SURVEY>_<PROGRAM>_v<N> ends in a lowercase v, so that suffix
    # is accepted (reported as a contradiction in the standard).
    sid <- src$source_id[i]
    if (is.na(sid) || nchar(sid) > 32 || !grepl("^[A-Z][A-Z0-9_]*?(_v[0-9]+)?$", sid, perl = TRUE)) {
      p <- c(p, "source_id fails the code rules (uppercase letters, digits and _, at most 32 characters, optional _v<N> suffix)")
    }
    sa <- unname(survey_area[src$survey_id[i]])
    if (length(sa) == 1 && !is.na(sa) && !identical(sa, src$ref_area[i])) {
      p <- c(p, paste0("ref_area ", src$ref_area[i], " differs from survey ", src$survey_id[i], "'s ", sa))
    }
    if ("run_date" %in% names(src) && !.meta_blank(src$run_date[i]) &&
        !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", src$run_date[i])) {
      p <- c(p, paste0("run_date '", src$run_date[i], "' is not an ISO 8601 date"))
    }
    inputs <- .meta_tokens(src$inputs[i])
    shas <- .meta_tokens(if ("inputs_sha256" %in% names(src)) src$inputs_sha256[i] else "")
    for (j in seq_along(inputs)) {
      path <- file.path(ctx$root, inputs[j])
      if (!file.exists(path) || dir.exists(path)) next
      want <- if (j <= length(shas)) tolower(shas[j]) else NA_character_
      if (is.na(want)) {
        p <- c(p, paste0("input ", inputs[j], " is a repository file but has no inputs_sha256 entry"))
      } else if (!identical(sha256_file(path), want)) {
        p <- c(p, paste0("inputs_sha256 of ", inputs[j], " does not match the file"))
      }
    }
    if (length(p) > 0) {
      out[[length(out) + 1]] <- .vc_finding(
        "META.SOURCES", "ERROR", rel, .meta_row_key("SOURCES", src, i), paste(p, collapse = "; ")
      )
    }
  }
  for (d in unique(src$source_id[duplicated(src$source_id)])) {
    out[[length(out) + 1]] <- .vc_finding(
      "META.SOURCES", "ERROR", rel, paste0("source_id=", d), "duplicate source_id"
    )
  }
  .vc_bind(out)
}
