# pipeline/R/validate_rules.R
#
# Validator module RULE (standard v0.5, "Validation checks" > "Verification
# rules from RULES.csv"): checks that the numbers are internally consistent
# - ranges, aggregations that sum to or bracket their parent, shares that
# close to 1, values that do not fall as a qualifier's order rises - with
# every rule read from metadata/rules/RULES.csv (D18), plus the N_POP
# partition-sum check over population cuts (D19).
#
# A RULES.csv row applies by its scope: DATAFLOW to every row, INDICATOR
# to every series of the indicator (`scope_code`), SERIES to one series.
# Its `severity` is the finding's severity, `param` its argument, and a
# filled `tolerance` replaces the computed bound. DEPRECATED rows are not
# applied; RELIABILITY_MIN_NOBS / RELIABILITY_MAX_CV are read by the VALUE
# module (OBS_STATUS U), not here.
#
# Tolerances: h = PRECISION / 2 for a row with PRECISION filled, 0
# otherwise. A single value (RANGE_*) matches within +-h; a sum of k
# children against its parent (AGG_SUM) within +-(k + 1) h, and a closure
# over k categories (SUM_TO_1_OVER*) within +-k h, both with the largest h
# among the rows compared; AGG_BRACKET widens [min, max] of the children by
# that h; AGG_NPOP_MEAN compares within +-2h (the children's weighted
# mean is off by at most h, the parent by h). Every comparison is
# abs(dev) <= tol + 1e-9. MONOTONE_IN takes no tolerance.
#
# The parent of a row is found through its provenance: the required row of
# the same series in the TOTAL cut (required_rows()'s series_id / cut_id),
# never guessed from the codes. When a group's rows are not all present
# (absent, withheld, or O/M), the group is skipped with a WARN
# RULE.AGG_SKIPPED; when a closure's category set is incomplete in the
# plan, with one INFO RULE.CLOSURE_PARTIAL.
#
# Depends on pipeline/R/constants.R, pipeline/R/plan.R (required_rows(),
# which needs codes.R) and pipeline/R/ctx.R (the ctx_*() accessors) and
# io.R (fmt_num()). Each exported function takes the `ctx` list built by
# build_ctx() and returns a findings data frame with columns check_id,
# severity, file, row_key, message.

# ---------------------------------------------------------------------------
# Small shared utilities
# ---------------------------------------------------------------------------

#' An empty findings data frame.
.vc_empty_result <- function() {
  data.frame(
    check_id = character(0),
    severity = character(0),
    file = character(0),
    row_key = character(0),
    message = character(0),
    stringsAsFactors = FALSE
  )
}

#' Split a space-separated field into tokens.
.vc_tokens <- function(x) {
  x <- if (length(x) == 0) NA_character_ else x[[1]]
  if (is.na(x) || trimws(x) == "") {
    return(character(0))
  }
  strsplit(trimws(x), "\\s+")[[1]]
}

#' Apply the 20-findings-per-(check_id, file) cap.
.vc_cap <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  }
  df <- df[order(df$check_id, df$file, df$row_key, method = "radix"), , drop = FALSE]
  groups <- unique(df[c("check_id", "file")])
  parts <- vector("list", nrow(groups))
  for (i in seq_len(nrow(groups))) {
    sub <- df[df$check_id == groups$check_id[i] & df$file == groups$file[i], , drop = FALSE]
    sub <- sub[order(sub$row_key, method = "radix"), , drop = FALSE]
    if (nrow(sub) > 20) {
      head20 <- sub[1:20, , drop = FALSE]
      summary_row <- data.frame(
        check_id = groups$check_id[i],
        severity = sub$severity[1],
        file = groups$file[i],
        row_key = "",
        message = sprintf("SUMMARY: %d findings in total, 20 shown", nrow(sub)),
        stringsAsFactors = FALSE
      )
      parts[[i]] <- rbind(head20, summary_row)
    } else {
      parts[[i]] <- sub
    }
  }
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

#' Bind a list of findings frames and cap them.
.vc_rule_bind <- function(findings) {
  findings <- findings[vapply(findings, function(x) !is.null(x) && nrow(x) > 0, logical(1))]
  if (length(findings) == 0) {
    return(.vc_empty_result())
  }
  .vc_cap(do.call(rbind, findings))
}

#' One findings frame.
.vc_rule_finding <- function(check_id, severity, file, row_key, message) {
  data.frame(
    check_id = check_id, severity = severity, file = file,
    row_key = row_key, message = message, stringsAsFactors = FALSE
  )
}

#' Blank out one key column per row before joining into a group key.
#'
#' @param df A data frame with the key columns.
#' @param key_cols The key columns.
#' @param exclude_col A character vector, same length as `nrow(df)`, naming
#'   the key column to blank for that row, or `NA` to blank none.
.vc_group_key <- function(df, key_cols, exclude_col) {
  parts <- as.data.frame(lapply(df[key_cols], as.character), stringsAsFactors = FALSE)
  names(parts) <- key_cols
  for (col in unique(stats::na.omit(exclude_col))) {
    idx <- which(exclude_col == col)
    parts[idx, col] <- "*"
  }
  do.call(paste, c(as.list(parts), list(sep = " ")))
}

#' Find, for every row, which of `slot_cols` holds a category of
#' `target_var` (one value, or one per row).
#'
#' @return A list with `slot` (the matching column name, or `NA`) and
#'   `category` (the matching value, or `NA`), one entry per row.
.vc_slot_holding_var <- function(df, slot_cols, var_of, target_var) {
  n <- nrow(df)
  slot <- rep(NA_character_, n)
  category <- rep(NA_character_, n)
  remaining <- rep(TRUE, n)
  for (col in slot_cols) {
    if (!any(remaining)) {
      break
    }
    val <- df[[col]]
    vv <- unname(var_of[val])
    hit <- remaining & !is.na(vv) & !is.na(target_var) & vv == target_var
    slot[hit] <- col
    category[hit] <- val[hit]
    remaining[hit] <- FALSE
  }
  list(slot = slot, category = category)
}

#' The comparison tolerance: the rule's `tolerance` when filled, else the
#' computed bound.
.vc_tol <- function(rule_tol, computed) {
  if (!is.na(rule_tol)) rule_tol else computed
}

# ---------------------------------------------------------------------------
# The joined rows: every required row, with its value, presence, PRECISION
# and tolerance unit h.
# ---------------------------------------------------------------------------

.vc_META_NEEDED <- c(
  "SERIES_PLAN", "TAB_PLAN", "CL_INDICATOR", "CL_BRK_VAR",
  "CL_COMP_BREAKDOWN", "CL_QUAL_VAR", "CL_QUALIFIER", "CL_GEO"
)

# Memo of .vc_build_rows(), keyed on a hash of the metadata and data, so
# the rule functions of one validator run build the joined rows once.
.vc_rows_cache <- new.env(parent = emptyenv())

#' Every required row across every loaded data file, joined to its value.
#'
#' Joins `ctx$data` to `required_rows()` (for each file's REF_AREA,
#' TIME_PERIOD and ESTIMATION) on the key columns. Rows that do not join
#' are ignored (the coverage checks report them). Returns zero rows when
#' `ctx$data` is empty or the metadata `required_rows()` needs is missing.
#'
#' @return A data frame: the key columns, `series_id`, `cut_id`,
#'   `defining_breakdown`, `.file`, `.value` (numeric, `NA` when
#'   absent/non-numeric), `.obs_status`, `.present` (TRUE when `.value` is
#'   not `NA` and `.obs_status` is not O/M), `.precision` (numeric, `NA`
#'   when empty), `.h`, `.n_pop` and `.row_key`.
.vc_build_rows <- function(ctx) {
  if (length(ctx$data) == 0) {
    return(.vc_empty_joined(ctx))
  }
  meta <- ctx$meta
  if (length(setdiff(.vc_META_NEEDED, names(meta))) > 0) {
    return(.vc_empty_joined(ctx))
  }
  cache_key <- digest::digest(list(ctx$meta, ctx$data, ctx$manifests))
  if (exists(cache_key, envir = .vc_rows_cache, inherits = FALSE)) {
    return(get(cache_key, envir = .vc_rows_cache))
  }

  key_cols <- ctx_key_columns(ctx)
  parts <- list()
  num <- function(x) suppressWarnings(as.numeric(x))

  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (is.null(df) || nrow(df) == 0 || !all(key_cols %in% names(df))) {
      next
    }
    file_path <- paste0("data/", key, ".csv")
    est_col <- if ("ESTIMATION" %in% names(df)) df$ESTIMATION else rep(ctx_file_estimation(ctx, key), nrow(df))
    combos <- unique(data.frame(
      REF_AREA = df$REF_AREA, TIME_PERIOD = df$TIME_PERIOD, ESTIMATION = est_col,
      stringsAsFactors = FALSE
    ))
    sub_key_all <- ctx_row_keys(ctx, df)
    for (ci in seq_len(nrow(combos))) {
      rr <- tryCatch(
        required_rows(meta, combos$REF_AREA[ci], combos$TIME_PERIOD[ci], combos$ESTIMATION[ci]),
        error = function(e) NULL
      )
      if (is.null(rr) || nrow(rr) == 0) {
        next
      }
      rr_key <- ctx_row_keys(ctx, rr)
      m <- match(rr_key, sub_key_all)

      pick <- function(col) {
        if (!(col %in% names(df))) return(rep(NA_character_, length(m)))
        ifelse(is.na(m), NA_character_, df[[col]][m])
      }
      value <- num(pick("OBS_VALUE"))
      value[is.nan(value)] <- NA_real_ # NaN: intentionally missing (D39)
      obs_status <- pick("OBS_STATUS")
      precision <- num(pick("PRECISION"))

      rr$.file <- file_path
      rr$.value <- value
      rr$.obs_status <- obs_status
      rr$.present <- !is.na(m) & !is.na(value) & !(obs_status %in% c("O", "M"))
      rr$.precision <- precision
      rr$.h <- ifelse(is.na(precision), 0, precision / 2)
      rr$.n_pop <- num(pick("N_POP"))
      rr$.row_key <- rr_key

      parts[[length(parts) + 1]] <- rr
    }
  }

  out <- if (length(parts) == 0) .vc_empty_joined(ctx) else do.call(rbind, parts)
  rownames(out) <- NULL
  assign(cache_key, out, envir = .vc_rows_cache)
  out
}

.vc_empty_joined <- function(ctx) {
  key_cols <- ctx_key_columns(ctx)
  out <- as.data.frame(
    matrix(character(0), nrow = 0, ncol = length(key_cols) + 3),
    stringsAsFactors = FALSE
  )
  names(out) <- c(key_cols, "series_id", "cut_id", "defining_breakdown")
  out$.file <- character(0)
  out$.value <- numeric(0)
  out$.obs_status <- character(0)
  out$.present <- logical(0)
  out$.precision <- numeric(0)
  out$.h <- numeric(0)
  out$.n_pop <- numeric(0)
  out$.row_key <- character(0)
  out
}

#' The RULES.csv rows of one rule, each with the joined rows it selects.
#'
#' @param ctx The list from [build_ctx()].
#' @param rows The joined rows from [.vc_build_rows()].
#' @param rule_name The rule, e.g. `"AGG_SUM"`.
#' @return A list of lists: `rule_id`, `param`, `severity`, `tolerance`
#'   (numeric, `NA` when empty) and `rows` (the selected joined rows).
.vc_rule_applications <- function(ctx, rows, rule_name) {
  rules <- ctx_rules(ctx)
  rules <- rules[rules$rule == rule_name, , drop = FALSE]
  res <- list()
  for (i in seq_len(nrow(rules))) {
    r <- rules[i, ]
    sel <- switch(r$scope,
      DATAFLOW = rep(TRUE, nrow(rows)),
      INDICATOR = rows$INDICATOR == r$scope_code,
      SERIES = rows$series_id == r$scope_code,
      rep(FALSE, nrow(rows))
    )
    sev <- if (r$severity %in% c("ERROR", "WARN")) r$severity else "ERROR"
    res[[length(res) + 1]] <- list(
      rule_id = r$rule_id,
      param = if (is.na(r$param)) "" else trimws(r$param),
      severity = sev,
      tolerance = suppressWarnings(as.numeric(r$tolerance)),
      rows = rows[sel, , drop = FALSE]
    )
  }
  res
}

# ---------------------------------------------------------------------------
# RANGE_0_1 / RANGE_NONNEG
# ---------------------------------------------------------------------------

.vc_range_check <- function(ctx, rule_name, check_id, lower, upper) {
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  findings <- list()
  for (app in .vc_rule_applications(ctx, rows, rule_name)) {
    sub <- app$rows[app$rows$.present, , drop = FALSE]
    if (nrow(sub) == 0) next
    tol <- if (!is.na(app$tolerance)) rep(app$tolerance, nrow(sub)) else sub$.h
    bad <- rep(FALSE, nrow(sub))
    if (!is.null(lower)) bad <- bad | (lower - sub$.value > tol + 1e-9)
    if (!is.null(upper)) bad <- bad | (sub$.value - upper > tol + 1e-9)
    sub <- sub[bad, , drop = FALSE]
    if (nrow(sub) == 0) next
    findings[[length(findings) + 1]] <- .vc_rule_finding(
      check_id, app$severity, sub$.file, sub$.row_key,
      sprintf("rule=%s value=%s out of range (tolerance %s)", app$rule_id, fmt_num(sub$.value), fmt_num(tol[bad]))
    )
  }
  .vc_rule_bind(findings)
}

#' RULE.RANGE_0_1: the value lies between 0 and 1 (within +-h).
vc_rule_range_0_1 <- function(ctx) {
  .vc_range_check(ctx, "RANGE_0_1", "RULE.RANGE_0_1", 0, 1)
}

#' RULE.RANGE_NONNEG: the value is at least 0 (within h).
vc_rule_range_nonneg <- function(ctx) {
  .vc_range_check(ctx, "RANGE_NONNEG", "RULE.RANGE_NONNEG", 0, NULL)
}

# ---------------------------------------------------------------------------
# AGG_SUM / AGG_BRACKET / AGG_NPOP_MEAN (shared parent/children logic)
# ---------------------------------------------------------------------------

#' Shared parent/children walk.
#'
#' For every series a rule applies to and every cut other than TOTAL,
#' compares the children (the cut's required rows for that series) with
#' the parent (the series' TOTAL-cut row, found through the provenance).
#' Missing children or parent (withheld, OBS_STATUS O/M, or absent from
#' the file) skip that parent/cut with one WARN RULE.AGG_SKIPPED.
#'
#' @param compare A function(children, parent, app) returning `NULL` when
#'   it passes, a message string when it fails, or `list(skip = <msg>)` to
#'   skip the group with an INFO RULE.NPOP_SKIPPED.
.vc_agg_walk <- function(ctx, rule_name, check_id, compare) {
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  findings <- list()
  npop_skipped <- character(0)
  for (app in .vc_rule_applications(ctx, rows, rule_name)) {
    sel <- app$rows
    sub <- sel[sel$cut_id != "TOTAL", , drop = FALSE]
    parents <- sel[sel$cut_id == "TOTAL", , drop = FALSE]
    if (nrow(sub) == 0 || nrow(parents) == 0) next
    parent_idx <- stats::setNames(seq_len(nrow(parents)), paste(parents$series_id, parents$.file))

    grp <- paste(sub$series_id, sub$cut_id, sub$.file)
    for (g in sort(unique(grp), method = "radix")) {
      children <- sub[grp == g, , drop = FALSE]
      series_id <- children$series_id[1]
      file <- children$.file[1]
      pi <- unname(parent_idx[paste(series_id, file)])
      if (length(pi) == 0 || is.na(pi)) next
      parent <- parents[pi, ]

      if (!parent$.present || !all(children$.present)) {
        findings[[length(findings) + 1]] <- .vc_rule_finding(
          "RULE.AGG_SKIPPED", "WARN", file, parent$.row_key,
          sprintf(
            "rule=%s series=%s cut=%s skipped: %d/%d children present, parent present=%s",
            app$rule_id, series_id, children$cut_id[1], sum(children$.present), nrow(children),
            parent$.present
          )
        )
        next
      }

      res <- compare(children, parent, app)
      if (is.list(res)) {
        npop_skipped <- c(npop_skipped, paste(file, app$rule_id, sep = "\r"))
      } else if (!is.null(res)) {
        findings[[length(findings) + 1]] <- .vc_rule_finding(
          check_id, app$severity, file, parent$.row_key,
          sprintf("rule=%s cut=%s %s", app$rule_id, children$cut_id[1], res)
        )
      }
    }
  }
  for (s in unique(npop_skipped)) {
    parts <- strsplit(s, "\r", fixed = TRUE)[[1]]
    findings[[length(findings) + 1]] <- .vc_rule_finding(
      "RULE.NPOP_SKIPPED", "INFO", parts[1], "",
      sprintf("rule=%s skipped: N_POP is empty", parts[2])
    )
  }
  .vc_rule_bind(findings)
}

#' RULE.AGG_SUM: children sum to the parent within (k + 1) h, h the
#' largest among the rows compared.
vc_rule_agg_sum <- function(ctx) {
  .vc_agg_walk(ctx, "AGG_SUM", "RULE.AGG_SUM", function(children, parent, app) {
    k <- nrow(children)
    h <- max(c(children$.h, parent$.h))
    tol <- .vc_tol(app$tolerance, (k + 1) * h)
    s <- sum(children$.value)
    dev <- abs(s - parent$.value)
    if (dev > tol + 1e-9) {
      sprintf(
        "sum=%s parent=%s deviation=%s tolerance=%s",
        fmt_num(s), fmt_num(parent$.value), fmt_num(dev), fmt_num(tol)
      )
    } else {
      NULL
    }
  })
}

#' RULE.AGG_BRACKET: the parent lies within [min child - h, max child + h],
#' h the largest among the rows compared.
vc_rule_agg_bracket <- function(ctx) {
  .vc_agg_walk(ctx, "AGG_BRACKET", "RULE.AGG_BRACKET", function(children, parent, app) {
    h <- .vc_tol(app$tolerance, max(c(children$.h, parent$.h)))
    lower <- min(children$.value) - h
    upper <- max(children$.value) + h
    if (lower - parent$.value > 1e-9 || parent$.value - upper > 1e-9) {
      sprintf(
        "parent=%s outside [%s, %s] (min child=%s max child=%s h=%s)",
        fmt_num(parent$.value), fmt_num(lower), fmt_num(upper),
        fmt_num(min(children$.value)), fmt_num(max(children$.value)), fmt_num(h)
      )
    } else {
      NULL
    }
  })
}

#' RULE.AGG_NPOP_MEAN: the N_POP-weighted mean of the children equals the
#' parent within 2h. Needs every child's N_POP; where one is empty the
#' group is skipped, with one INFO RULE.NPOP_SKIPPED per file and rule.
vc_rule_agg_npop_mean <- function(ctx) {
  .vc_agg_walk(ctx, "AGG_NPOP_MEAN", "RULE.AGG_NPOP_MEAN", function(children, parent, app) {
    w <- children$.n_pop
    if (any(is.na(w)) || sum(w) <= 0) {
      return(list(skip = "N_POP"))
    }
    mean_w <- sum(children$.value * w) / sum(w)
    h <- max(c(children$.h, parent$.h))
    tol <- .vc_tol(app$tolerance, 2 * h)
    dev <- abs(mean_w - parent$.value)
    if (dev > tol + 1e-9) {
      sprintf(
        "weighted mean=%s parent=%s deviation=%s tolerance=%s",
        fmt_num(mean_w), fmt_num(parent$.value), fmt_num(dev), fmt_num(tol)
      )
    } else {
      NULL
    }
  })
}

# ---------------------------------------------------------------------------
# SUM_TO_1_OVER (param = qualifier variable) / SUM_TO_1_OVER_BRK
# ---------------------------------------------------------------------------

#' Shared closure walk.
#'
#' Groups the selected rows by every key column with the slot holding a
#' category of the target variable taken out (plus the variable itself). A
#' group whose required rows do not cover every category of the variable
#' (`n_total_of(var)`) is partial: skipped, with one INFO
#' RULE.CLOSURE_PARTIAL per (indicator, variable). A complete group missing
#' a value skips with WARN RULE.AGG_SKIPPED. A complete, fully-present
#' group must sum to 1 within k h (h the largest in the group) or the
#' rule's tolerance.
#'
#' @param row_target_var A function(rows) returning the target var_code for
#'   each row.
#' @param slot_cols The key slots to search for the target variable's
#'   category (MEASURE_QUAL_1..5 or COMP_BREAKDOWN_1..5).
#' @param var_of A named character vector, category code to var_code.
#' @param n_total_of A function(var) returning the variable's full
#'   category-domain size.
.vc_closure_walk <- function(ctx, app, check_id, row_target_var, slot_cols, var_of, n_total_of) {
  sub <- app$rows
  if (nrow(sub) == 0) {
    return(list(findings = list(), partial = character(0)))
  }
  key_cols <- ctx_key_columns(ctx)
  target_var <- row_target_var(sub)
  hit <- .vc_slot_holding_var(sub, slot_cols, var_of, target_var)
  keep <- !is.na(hit$slot)
  sub <- sub[keep, , drop = FALSE]
  target_var <- target_var[keep]
  slot <- hit$slot[keep]
  category <- hit$category[keep]
  if (nrow(sub) == 0) {
    return(list(findings = list(), partial = character(0)))
  }

  group_key <- paste(target_var, .vc_group_key(sub, key_cols, slot))
  ord <- order(group_key, method = "radix")
  sub <- sub[ord, , drop = FALSE]
  target_var <- target_var[ord]
  category <- category[ord]
  group_key <- group_key[ord]

  partial <- character(0)
  findings <- list()
  for (g in unique(group_key)) {
    idx <- which(group_key == g)
    grp_rows <- sub[idx, , drop = FALSE]
    var <- target_var[idx[1]]
    n_total <- n_total_of(var)
    k <- length(unique(category[idx]))

    if (n_total <= 0 || k < n_total) {
      partial <- c(partial, paste(grp_rows$INDICATOR[1], var))
      next
    }
    if (!all(grp_rows$.present)) {
      findings[[length(findings) + 1]] <- .vc_rule_finding(
        "RULE.AGG_SKIPPED", "WARN", grp_rows$.file[1], sort(grp_rows$.row_key, method = "radix")[1],
        sprintf(
          "rule=%s var=%s skipped: %d/%d categories present",
          app$rule_id, var, sum(grp_rows$.present), nrow(grp_rows)
        )
      )
      next
    }
    s <- sum(grp_rows$.value)
    tol <- .vc_tol(app$tolerance, k * max(grp_rows$.h))
    dev <- abs(s - 1)
    if (dev > tol + 1e-9) {
      findings[[length(findings) + 1]] <- .vc_rule_finding(
        check_id, app$severity, grp_rows$.file[1], sort(grp_rows$.row_key, method = "radix")[1],
        sprintf(
          "rule=%s var=%s sum=%s target=1 deviation=%s tolerance=%s",
          app$rule_id, var, fmt_num(s), fmt_num(dev), fmt_num(tol)
        )
      )
    }
  }
  list(findings = findings, partial = partial)
}

#' The INFO findings for partial closures.
.vc_partial_findings <- function(partial) {
  lapply(unique(partial), function(pair) {
    parts <- strsplit(pair, " ", fixed = TRUE)[[1]]
    .vc_rule_finding(
      "RULE.CLOSURE_PARTIAL", "INFO", "metadata/plans/SERIES_PLAN.csv",
      sprintf("indicator=%s var=%s", parts[1], paste(parts[-1], collapse = " ")),
      "closure's categories are not all present in the plan"
    )
  })
}

#' RULE.SUM_TO_1_QUAL: SUM_TO_1_OVER closures over the qualifier variable
#' named by the rule's `param`.
vc_rule_sum_to_1_qual <- function(ctx) {
  meta <- ctx$meta
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  qual_var_of <- stats::setNames(meta$CL_QUALIFIER$var_code, meta$CL_QUALIFIER$code)
  qual_slots <- paste0("MEASURE_QUAL_", 1:5)
  n_total_of <- function(var) sum(meta$CL_QUALIFIER$var_code == var, na.rm = TRUE)

  findings <- list()
  partial <- character(0)
  for (app in .vc_rule_applications(ctx, rows, "SUM_TO_1_OVER")) {
    if (app$param == "") next # META.RULES reports the missing param
    v <- app$param
    res <- .vc_closure_walk(
      ctx, app, "RULE.SUM_TO_1_QUAL", function(r) rep(v, nrow(r)), qual_slots, qual_var_of, n_total_of
    )
    findings <- c(findings, res$findings)
    partial <- c(partial, res$partial)
  }
  .vc_rule_bind(c(findings, .vc_partial_findings(partial)))
}

#' RULE.SUM_TO_1_BRK: SUM_TO_1_OVER_BRK closures over each series' defining
#' breakdown variable (taken from the row's provenance).
vc_rule_sum_to_1_brk <- function(ctx) {
  meta <- ctx$meta
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  comp_var_of <- stats::setNames(meta$CL_COMP_BREAKDOWN$var_code, meta$CL_COMP_BREAKDOWN$code)
  comp_slots <- paste0("COMP_BREAKDOWN_", 1:5)
  n_total_of <- function(var) sum(meta$CL_COMP_BREAKDOWN$var_code == var, na.rm = TRUE)
  row_target_var <- function(r) unname(comp_var_of[r$defining_breakdown])

  findings <- list()
  partial <- character(0)
  for (app in .vc_rule_applications(ctx, rows, "SUM_TO_1_OVER_BRK")) {
    res <- .vc_closure_walk(ctx, app, "RULE.SUM_TO_1_BRK", row_target_var, comp_slots, comp_var_of, n_total_of)
    findings <- c(findings, res$findings)
    partial <- c(partial, res$partial)
  }
  .vc_rule_bind(c(findings, .vc_partial_findings(partial)))
}

# ---------------------------------------------------------------------------
# MONOTONE_IN (param = qualifier variable)
# ---------------------------------------------------------------------------

#' RULE.MONOTONE: among rows differing only in their category of the
#' rule's qualifier variable, the value does not fall as the category's
#' CL_QUALIFIER `order` rises. Rows without a value are skipped; no
#' tolerance applies.
vc_rule_monotone <- function(ctx) {
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  meta <- ctx$meta
  key_cols <- ctx_key_columns(ctx)
  qual_var_of <- stats::setNames(meta$CL_QUALIFIER$var_code, meta$CL_QUALIFIER$code)
  qual_order_of <- stats::setNames(
    suppressWarnings(as.numeric(meta$CL_QUALIFIER$order)),
    meta$CL_QUALIFIER$code
  )
  qual_slots <- paste0("MEASURE_QUAL_", 1:5)

  findings <- list()
  for (app in .vc_rule_applications(ctx, rows, "MONOTONE_IN")) {
    if (app$param == "") next
    sub <- app$rows[app$rows$.present, , drop = FALSE]
    if (nrow(sub) == 0) next
    hit <- .vc_slot_holding_var(sub, qual_slots, qual_var_of, app$param)
    keep <- !is.na(hit$slot)
    sub <- sub[keep, , drop = FALSE]
    if (nrow(sub) == 0) next
    group_key <- .vc_group_key(sub, key_cols, hit$slot[keep])
    ord_value <- unname(qual_order_of[hit$category[keep]])

    for (g in sort(unique(group_key), method = "radix")) {
      idx <- which(group_key == g)
      if (length(idx) < 2) next
      grp <- sub[idx, , drop = FALSE]
      pv <- ord_value[idx]
      if (any(is.na(pv))) next
      o <- order(pv, method = "radix")
      grp <- grp[o, , drop = FALSE]
      pv <- pv[o]
      for (i in 2:nrow(grp)) {
        if (grp$.value[i - 1] - grp$.value[i] > 1e-9) {
          findings[[length(findings) + 1]] <- .vc_rule_finding(
            "RULE.MONOTONE", app$severity, grp$.file[i], grp$.row_key[i],
            sprintf(
              "rule=%s value=%s at %s order %s below value=%s at order %s",
              app$rule_id, fmt_num(grp$.value[i]), app$param, fmt_num(pv[i]),
              fmt_num(grp$.value[i - 1]), fmt_num(pv[i - 1])
            )
          )
        }
      }
    }
  }
  .vc_rule_bind(findings)
}

# ---------------------------------------------------------------------------
# N_POP partition sums over population cuts (D19)
# ---------------------------------------------------------------------------

#' The leaf codes of a codelist (codes that are no other code's `parent`).
.vc_leaf_codes <- function(tab) {
  if (is.null(tab) || !("code" %in% names(tab))) return(character(0))
  parents <- if ("parent" %in% names(tab)) tab$parent[!is.na(tab$parent) & tab$parent != ""] else character(0)
  setdiff(tab$code, parents)
}

#' Whether a TAB_PLAN cut is a partition of its population for a country:
#' every dimension it splits on is exhaustive and exclusive - a geography
#' scheme with CL_GEO_SCHEME.partition = Y, an urbanisation, sex or age set
#' equal to its codelist's leaf codes, and breakdown variables with
#' CL_BRK_VAR.partition = Y.
.vc_cut_is_partition <- function(ctx, cut_row, ref_area) {
  meta <- ctx$meta
  ok <- TRUE
  if (!identical(cut_row$geo_scheme, "_T")) {
    gs <- meta$CL_GEO_SCHEME
    p <- if (is.null(gs)) NA else gs$partition[gs$ref_area == ref_area & gs$code == cut_row$geo_scheme][1]
    ok <- ok && !is.na(p) && p == "Y"
  }
  set_is_leaves <- function(field, tab) {
    if (identical(field, "_T")) return(TRUE)
    setequal(.vc_tokens(field), .vc_leaf_codes(tab))
  }
  ok <- ok && set_is_leaves(cut_row$urbanisation, meta$CL_URBANISATION)
  ok <- ok && set_is_leaves(cut_row$sex, meta$CL_SEX)
  ok <- ok && set_is_leaves(cut_row$age, meta$CL_AGE)
  bv <- meta$CL_BRK_VAR
  for (v in .vc_tokens(cut_row$comp_breakdowns)) {
    p <- if (is.null(bv) || !("partition" %in% names(bv))) NA else bv$partition[bv$code == v][1]
    ok <- ok && !is.na(p) && p == "Y"
  }
  ok
}

#' RULE.NPOP_PARTITION: over every population cut that is a partition
#' (.vc_cut_is_partition()), the children's N_POP sums to the parent's
#' (the series' TOTAL-cut row). The children of one series share its
#' defining category, so the check never runs over a defining breakdown,
#' where every child's N_POP is the same denominator (D19). A group whose
#' rows all leave N_POP empty (a legacy conversion) is not checked; one
#' where only some do, or a row is absent, is skipped with a WARN
#' RULE.AGG_SKIPPED. N_POP is a sum of weights, not rounded, so the
#' tolerance is floating-point noise only: 1e-9 x |parent| (+ 1e-9).
vc_rule_npop_partition <- function(ctx) {
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  tab_plan <- ctx$meta$TAB_PLAN
  findings <- list()
  sub <- rows[rows$cut_id != "TOTAL", , drop = FALSE]
  parents <- rows[rows$cut_id == "TOTAL", , drop = FALSE]
  if (nrow(sub) == 0 || nrow(parents) == 0) {
    return(.vc_empty_result())
  }
  parent_idx <- stats::setNames(seq_len(nrow(parents)), paste(parents$series_id, parents$.file))
  partition_memo <- list()

  grp <- paste(sub$series_id, sub$cut_id, sub$.file)
  for (g in sort(unique(grp), method = "radix")) {
    children <- sub[grp == g, , drop = FALSE]
    pi <- unname(parent_idx[paste(children$series_id[1], children$.file[1])])
    if (length(pi) == 0 || is.na(pi)) next
    parent <- parents[pi, ]
    all_rows <- rbind(children, parent)
    if (all(is.na(all_rows$.n_pop))) next

    ra <- children$REF_AREA[1]
    cut <- children$cut_id[1]
    memo_key <- paste(ra, cut)
    if (is.null(partition_memo[[memo_key]])) {
      cr <- tab_plan[tab_plan$cut_id == cut & tab_plan$ref_area %in% c("ALL", ra), , drop = FALSE]
      partition_memo[[memo_key]] <- nrow(cr) > 0 && .vc_cut_is_partition(ctx, cr[1, ], ra)
    }
    if (!partition_memo[[memo_key]]) next

    if (any(is.na(all_rows$.n_pop)) || any(is.na(all_rows$.obs_status))) {
      findings[[length(findings) + 1]] <- .vc_rule_finding(
        "RULE.AGG_SKIPPED", "WARN", parent$.file, parent$.row_key,
        sprintf(
          "N_POP partition series=%s cut=%s skipped: %d/%d children carry N_POP, parent carries N_POP=%s",
          parent$series_id, cut, sum(!is.na(children$.n_pop)), nrow(children), !is.na(parent$.n_pop)
        )
      )
      next
    }
    s <- sum(children$.n_pop)
    dev <- abs(s - parent$.n_pop)
    tol <- 1e-9 * abs(parent$.n_pop)
    if (dev > tol + 1e-9) {
      findings[[length(findings) + 1]] <- .vc_rule_finding(
        "RULE.NPOP_PARTITION", "ERROR", parent$.file, parent$.row_key,
        sprintf(
          "series=%s cut=%s children's N_POP sum=%s parent N_POP=%s deviation=%s",
          parent$series_id, cut, fmt_num(s), fmt_num(parent$.n_pop), fmt_num(dev)
        )
      )
    }
  }
  .vc_rule_bind(findings)
}
