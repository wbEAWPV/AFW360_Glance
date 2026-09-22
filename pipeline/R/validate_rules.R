# pipeline/R/validate_rules.R
#
# WP13 - Validator: verification rules (.docs/transition/packages/WP13.md).
# Checks that the numbers are internally consistent: aggregations that sum
# to their parent, shares that close to 1, poverty rates that rise with the
# poverty line.
#
# Depends on pipeline/R/constants.R for KEY_COLUMNS, and pipeline/R/plan.R
# for required_rows() (which itself needs pipeline/R/codes.R and
# pipeline/R/io.R's load_metadata()). Callers source those before this file,
# same convention as plan.R. Each exported function takes the `ctx` list
# built by build_ctx() (pipeline/R/ctx.R).
#
# Findings format (word for word the same on cards WP11-WP14, see WP13.md):
#   - a tibble with columns check_id, severity, file, row_key, message;
#   - `file` is the path relative to the root, with forward slashes;
#   - `row_key` is the 18 key values joined by one space for a data row,
#     `<column>=<value>` for a metadata/content row, empty for a
#     whole-file finding;
#   - a check capped at 20 findings per file keeps the first 20 in
#     row_key order and adds one SUMMARY finding.

# ---------------------------------------------------------------------------
# Small shared utilities
# ---------------------------------------------------------------------------

#' An empty findings tibble.
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

#' Split a space-separated field into tokens (COMMON.md / WP13.md: "split on
#' spaces only, and then split a token at its first ':' to get the
#' argument").
.vc_tokens <- function(x) {
  x <- if (length(x) == 0) NA_character_ else x[[1]]
  if (is.na(x) || trimws(x) == "") {
    return(character(0))
  }
  strsplit(trimws(x), "\\s+")[[1]]
}

#' Split one token into its name and argument (argument is "" when absent).
.vc_token_parts <- function(token) {
  i <- regexpr(":", token, fixed = TRUE)
  if (i[[1]] < 0) {
    list(name = token, arg = "")
  } else {
    list(name = substr(token, 1, i[[1]] - 1), arg = substr(token, i[[1]] + 1, nchar(token)))
  }
}

#' Apply the 20-findings-per-(check_id, file) cap (WP13.md "Findings
#' format").
.vc_cap <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  }
  df <- df[order(df$check_id, df$file, df$row_key), , drop = FALSE]
  groups <- unique(df[c("check_id", "file")])
  parts <- vector("list", nrow(groups))
  for (i in seq_len(nrow(groups))) {
    sub <- df[df$check_id == groups$check_id[i] & df$file == groups$file[i], , drop = FALSE]
    sub <- sub[order(sub$row_key), , drop = FALSE]
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

#' The 18 key values of every row, joined by one space.
.vc_key_str <- function(df) {
  do.call(paste, c(as.list(df[KEY_COLUMNS]), list(sep = " ")))
}

#' Blank out one KEY_COLUMNS slot per row before joining into a group key.
#'
#' @param df A data frame with the 18 KEY_COLUMNS.
#' @param exclude_col A character vector, same length as `nrow(df)`, naming
#'   the KEY_COLUMNS entry to blank for that row, or `NA` to blank none.
.vc_group_key <- function(df, exclude_col) {
  parts <- as.data.frame(lapply(df[KEY_COLUMNS], as.character), stringsAsFactors = FALSE)
  names(parts) <- KEY_COLUMNS
  for (col in unique(stats::na.omit(exclude_col))) {
    idx <- which(exclude_col == col)
    parts[idx, col] <- "*"
  }
  do.call(paste, c(as.list(parts), list(sep = " ")))
}

#' Find, for every row, which of `slot_cols` holds a category of
#' `target_var`.
#'
#' @param df A data frame holding `slot_cols`.
#' @param slot_cols The columns to search, in order (first match wins).
#' @param var_of A named character vector, category code to var_code.
#' @param target_var The var_code to look for.
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
    hit <- remaining & !is.na(vv) & vv == target_var
    slot[hit] <- col
    category[hit] <- val[hit]
    remaining[hit] <- FALSE
  }
  list(slot = slot, category = category)
}

#' Series-level scale from LEGACY_LABELS (first non-missing `scale` per
#' `series_id`; WP13.md tolerance section, default 1 when absent).
.vc_series_scale <- function(legacy_labels) {
  if (is.null(legacy_labels) || nrow(legacy_labels) == 0) {
    return(stats::setNames(numeric(0), character(0)))
  }
  ll <- legacy_labels[!is.na(legacy_labels$series_id) & legacy_labels$series_id != "", , drop = FALSE]
  if (nrow(ll) == 0) {
    return(stats::setNames(numeric(0), character(0)))
  }
  scale_num <- suppressWarnings(as.numeric(ll$scale))
  keep <- !is.na(scale_num)
  ll <- ll[keep, , drop = FALSE]
  scale_num <- scale_num[keep]
  if (length(scale_num) == 0) {
    return(stats::setNames(numeric(0), character(0)))
  }
  first <- !duplicated(ll$series_id)
  stats::setNames(scale_num[first], ll$series_id[first])
}

.vc_scale_for <- function(scale_map, series_id) {
  s <- unname(scale_map[series_id])
  s[is.na(s)] <- 1
  s
}

#' The rounding unit h (WP13.md "Tolerance"): 0.005 x scale for a
#' ROUNDED_2DP file, 0 for an EXACT file.
#'
#' `precision` is a single value (one file has one precision) while `scale`
#' is per-row (one value per series). `ifelse()`'s result takes the shape
#' of its `test` argument, so passing the scalar `precision == "ROUNDED_2DP"`
#' straight in would silently collapse the result to length 1 (recycled
#' across every row instead of multiplying each row's own scale) -- recycle
#' the test to `scale`'s length first so every row's `h` uses its own scale.
.vc_h_for <- function(precision, scale) {
  is_rounded <- rep_len(precision == "ROUNDED_2DP", length(scale))
  ifelse(is_rounded, 0.005 * scale, 0)
}

#' The sum tolerance for `k` items (children of AGG_SUM, or a closure over
#' `k` categories): (k + 1) x h / k x h for ROUNDED_2DP, or
#' 1e-6 x max(1, |target|) for EXACT (WP13.md "Tolerance").
.vc_sum_tolerance <- function(precision, h, k, target) {
  ifelse(
    precision == "ROUNDED_2DP",
    k * h,
    1e-6 * pmax(1, abs(target))
  )
}

# ---------------------------------------------------------------------------
# The joined rows: every required row, with its value, presence, scale and
# tolerance unit (WP13.md Steps: "a small helper that returns the joined
# rows with their numeric value, scale and tolerance").
# ---------------------------------------------------------------------------

.vc_META_NEEDED <- c(
  "SERIES_PLAN", "TAB_PLAN", "CL_INDICATOR", "CL_BRK_VAR",
  "CL_COMP_BREAKDOWN", "CL_QUAL_VAR", "CL_QUALIFIER", "CL_GEO"
)

#' Every required row across every loaded data file, joined to its value.
#'
#' Joins `ctx$data` to `required_rows()` on the 18 key columns (WP13.md
#' "Rules you need / Provenance"). Rows that do not join are ignored (the
#' coverage check, WP12, reports them). Returns zero rows when `ctx$data`
#' is empty or the metadata `required_rows()` needs is missing.
#'
#' @return A data frame: the 18 KEY_COLUMNS, `series_id`, `cut_id`,
#'   `.file` (the data file's path relative to the root), `.value`
#'   (numeric, `NA` when absent/non-numeric), `.obs_status`, `.present`
#'   (TRUE when `.value` is not `NA` and `.obs_status` is not `O`/`M`),
#'   `.scale`, `.precision`, `.h` and `.row_key`.
.vc_build_rows <- function(ctx) {
  empty <- .vc_empty_joined()
  if (length(ctx$data) == 0) {
    return(empty)
  }
  meta <- ctx$meta
  if (length(setdiff(.vc_META_NEEDED, names(meta))) > 0) {
    return(empty)
  }

  scale_map <- .vc_series_scale(meta$LEGACY_LABELS)
  parts <- list()

  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (is.null(df) || nrow(df) == 0) {
      next
    }
    file_path <- paste0("data/", key, ".csv")
    precision <- ctx$precision[[key]]
    if (is.null(precision) || is.na(precision) || precision == "") {
      precision <- "EXACT"
    }

    combos <- unique(df[c("REF_AREA", "TIME_PERIOD")])
    for (ci in seq_len(nrow(combos))) {
      ref_area <- combos$REF_AREA[ci]
      time_period <- combos$TIME_PERIOD[ci]
      sub <- df[df$REF_AREA == ref_area & df$TIME_PERIOD == time_period, , drop = FALSE]

      rr <- tryCatch(required_rows(meta, ref_area, time_period), error = function(e) NULL)
      if (is.null(rr) || nrow(rr) == 0) {
        next
      }

      rr_key <- .vc_key_str(rr)
      sub_key <- .vc_key_str(sub)
      m <- match(rr_key, sub_key)

      val_chr <- ifelse(is.na(m), NA_character_, sub$OBS_VALUE[m])
      obs_status <- ifelse(is.na(m), NA_character_, sub$OBS_STATUS[m])
      value <- suppressWarnings(as.numeric(val_chr))
      present <- !is.na(m) & !is.na(value) & !(obs_status %in% c("O", "M"))

      scale <- .vc_scale_for(scale_map, rr$series_id)
      h <- .vc_h_for(precision, scale)

      rr$.file <- file_path
      rr$.value <- value
      rr$.obs_status <- obs_status
      rr$.present <- present
      rr$.scale <- scale
      rr$.precision <- precision
      rr$.h <- h
      rr$.row_key <- rr_key

      parts[[length(parts) + 1]] <- rr
    }
  }

  if (length(parts) == 0) {
    return(empty)
  }
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

.vc_empty_joined <- function() {
  out <- as.data.frame(
    matrix(character(0), nrow = 0, ncol = length(KEY_COLUMNS) + 2),
    stringsAsFactors = FALSE
  )
  names(out) <- c(KEY_COLUMNS, "series_id", "cut_id")
  out$.file <- character(0)
  out$.value <- numeric(0)
  out$.obs_status <- character(0)
  out$.present <- logical(0)
  out$.scale <- numeric(0)
  out$.precision <- character(0)
  out$.h <- numeric(0)
  out$.row_key <- character(0)
  out
}

# ---------------------------------------------------------------------------
# RANGE_0_1 / RANGE_NONNEG
# ---------------------------------------------------------------------------

.vc_range_check <- function(ctx, token_name, check_id, lower, upper) {
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  ci <- ctx$meta$CL_INDICATOR
  inds <- ci$code[vapply(ci$checks, function(x) token_name %in% .vc_tokens(x), logical(1))]
  sub <- rows[rows$INDICATOR %in% inds & rows$.present, , drop = FALSE]
  if (nrow(sub) == 0) {
    return(.vc_empty_result())
  }
  bad <- rep(FALSE, nrow(sub))
  if (!is.null(lower)) {
    bad <- bad | (sub$.value < lower - 1e-9)
  }
  if (!is.null(upper)) {
    bad <- bad | (sub$.value > upper + 1e-9)
  }
  sub <- sub[bad, , drop = FALSE]
  if (nrow(sub) == 0) {
    return(.vc_empty_result())
  }
  out <- data.frame(
    check_id = check_id,
    severity = "ERROR",
    file = sub$.file,
    row_key = sub$.row_key,
    message = sprintf("value=%s out of range", fmt_num(sub$.value)),
    stringsAsFactors = FALSE
  )
  .vc_cap(out)
}

#' RULE.RANGE_0_1: the value lies between 0 and 1.
vc_rule_range_0_1 <- function(ctx) {
  .vc_range_check(ctx, "RANGE_0_1", "RULE.RANGE_0_1", 0, 1)
}

#' RULE.RANGE_NONNEG: the value is at least 0.
vc_rule_range_nonneg <- function(ctx) {
  .vc_range_check(ctx, "RANGE_NONNEG", "RULE.RANGE_NONNEG", 0, NULL)
}

# ---------------------------------------------------------------------------
# AGG_SUM / AGG_BRACKET (shared parent/children logic)
# ---------------------------------------------------------------------------

#' Shared parent/children walk for AGG_SUM and AGG_BRACKET.
#'
#' For every series of an indicator carrying `token_name`, and every cut
#' other than TOTAL, compares the children (the cut's required rows for
#' that series) against the parent (the series' TOTAL-cut row). Missing
#' children or parent (withheld, OBS_STATUS O/M, or absent from the file)
#' skip that parent/cut with one WARN RULE.AGG_SKIPPED finding.
#'
#' @param compare A function(children_values, parent_value, k, h,
#'   precision) returning `NULL` when it passes, or a message string when
#'   it fails.
.vc_agg_walk <- function(ctx, token_name, check_id, compare) {
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  ci <- ctx$meta$CL_INDICATOR
  inds <- ci$code[vapply(ci$checks, function(x) token_name %in% .vc_tokens(x), logical(1))]
  sub <- rows[rows$INDICATOR %in% inds & rows$cut_id != "TOTAL", , drop = FALSE]
  if (nrow(sub) == 0) {
    return(.vc_empty_result())
  }

  parents <- rows[rows$INDICATOR %in% inds & rows$cut_id == "TOTAL", , drop = FALSE]
  parent_idx <- stats::setNames(seq_len(nrow(parents)), paste(parents$series_id, parents$.file))

  grp <- paste(sub$series_id, sub$cut_id, sub$.file)
  ord <- order(grp)
  sub <- sub[ord, , drop = FALSE]
  grp <- grp[ord]

  findings <- list()
  for (g in unique(grp)) {
    children <- sub[grp == g, , drop = FALSE]
    series_id <- children$series_id[1]
    file <- children$.file[1]
    pi <- parent_idx[[paste(series_id, file)]]
    if (is.null(pi) || is.na(pi)) {
      next
    }
    parent <- parents[pi, ]

    if (!parent$.present || !all(children$.present)) {
      findings[[length(findings) + 1]] <- data.frame(
        check_id = "RULE.AGG_SKIPPED",
        severity = "WARN",
        file = file,
        row_key = parent$.row_key,
        message = sprintf(
          "series=%s cut=%s skipped: %d/%d children present, parent present=%s",
          series_id, children$cut_id[1], sum(children$.present), nrow(children),
          parent$.present
        ),
        stringsAsFactors = FALSE
      )
      next
    }

    k <- nrow(children)
    msg <- compare(children$.value, parent$.value, k, parent$.h, parent$.precision)
    if (!is.null(msg)) {
      findings[[length(findings) + 1]] <- data.frame(
        check_id = check_id,
        severity = "ERROR",
        file = file,
        row_key = parent$.row_key,
        message = msg,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(findings) == 0) {
    return(.vc_empty_result())
  }
  .vc_cap(do.call(rbind, findings))
}

#' RULE.AGG_SUM: children sum to the parent within (k + 1) x h.
vc_rule_agg_sum <- function(ctx) {
  .vc_agg_walk(ctx, "AGG_SUM", "RULE.AGG_SUM", function(values, parent, k, h, precision) {
    s <- sum(values)
    tol <- .vc_sum_tolerance(precision, h, k + 1, parent)
    dev <- abs(s - parent)
    if (dev > tol + 1e-9) {
      sprintf("sum=%s parent=%s deviation=%s tolerance=%s", fmt_num(s), fmt_num(parent), fmt_num(dev), fmt_num(tol))
    } else {
      NULL
    }
  })
}

#' RULE.AGG_BRACKET: the parent lies within [min child - h, max child + h].
vc_rule_agg_bracket <- function(ctx) {
  .vc_agg_walk(ctx, "AGG_BRACKET", "RULE.AGG_BRACKET", function(values, parent, k, h, precision) {
    lower <- min(values) - h
    upper <- max(values) + h
    if (parent < lower - 1e-9 || parent > upper + 1e-9) {
      sprintf(
        "parent=%s outside [%s, %s] (min child=%s max child=%s h=%s)",
        fmt_num(parent), fmt_num(lower), fmt_num(upper), fmt_num(min(values)), fmt_num(max(values)), fmt_num(h)
      )
    } else {
      NULL
    }
  })
}

# ---------------------------------------------------------------------------
# SUM_TO_1_OVER:<QUAL_VAR> / SUM_TO_1_OVER_BRK (shared closure logic)
# ---------------------------------------------------------------------------

#' Shared closure walk for SUM_TO_1_OVER:<QUAL_VAR> and SUM_TO_1_OVER_BRK.
#'
#' Groups the indicator's required rows by every key column with the slot
#' holding a category of the target variable taken out (plus the target
#' variable itself, so two different variables never merge into the same
#' group). A group whose required rows do not cover every category of the
#' variable (n_total, from the relevant codelist) is partial: it is
#' skipped, and its (indicator, variable) pair is recorded for a single
#' RULE.CLOSURE_PARTIAL finding. A complete group missing an actual value
#' skips with RULE.AGG_SKIPPED. A complete, fully-present group is checked
#' with `compare`.
#'
#' @param row_target_var A function(rows) returning the target var_code for
#'   each row (may differ row to row, as for SUM_TO_1_OVER_BRK).
#' @param slot_cols The KEY_COLUMNS slots to search for the target
#'   variable's category (MEASURE_QUAL_1..5 or COMP_BREAKDOWN_1..5).
#' @param var_of A named character vector, category code to var_code, for
#'   `slot_cols`.
#' @param n_total_of A function(var) returning that variable's full
#'   category-domain size.
.vc_closure_walk <- function(ctx, token_matches, check_id, row_target_var, slot_cols, var_of, n_total_of) {
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  ci <- ctx$meta$CL_INDICATOR
  ind_tokens <- stats::setNames(lapply(ci$checks, .vc_tokens), ci$code)
  inds <- ci$code[vapply(ind_tokens, function(toks) any(vapply(toks, token_matches, logical(1))), logical(1))]
  sub <- rows[rows$INDICATOR %in% inds, , drop = FALSE]
  if (nrow(sub) == 0) {
    return(.vc_empty_result())
  }

  target_var <- row_target_var(sub)
  hit <- .vc_slot_holding_var(sub, slot_cols, var_of, target_var)
  # row_target_var may return one var per row (SUM_TO_1_OVER_BRK); keep only
  # rows where a slot for their own target var was actually found.
  keep <- !is.na(hit$slot)
  sub <- sub[keep, , drop = FALSE]
  target_var <- target_var[keep]
  slot <- hit$slot[keep]
  category <- hit$category[keep]
  if (nrow(sub) == 0) {
    return(.vc_empty_result())
  }

  group_key <- paste(target_var, .vc_group_key(sub, slot))
  ord <- order(group_key)
  sub <- sub[ord, , drop = FALSE]
  target_var <- target_var[ord]
  category <- category[ord]
  group_key <- group_key[ord]

  partial_pairs <- character(0)
  findings <- list()

  for (g in unique(group_key)) {
    idx <- which(group_key == g)
    grp_rows <- sub[idx, , drop = FALSE]
    var <- target_var[idx[1]]
    n_total <- n_total_of(var)
    k <- length(unique(category[idx]))

    if (n_total <= 0 || k < n_total) {
      ind <- grp_rows$INDICATOR[1]
      partial_pairs <- c(partial_pairs, paste(ind, var))
      next
    }

    if (!all(grp_rows$.present)) {
      findings[[length(findings) + 1]] <- data.frame(
        check_id = "RULE.AGG_SKIPPED",
        severity = "WARN",
        file = grp_rows$.file[1],
        row_key = min(grp_rows$.row_key),
        message = sprintf(
          "var=%s skipped: %d/%d categories present",
          var, sum(grp_rows$.present), nrow(grp_rows)
        ),
        stringsAsFactors = FALSE
      )
      next
    }

    s <- sum(grp_rows$.value)
    scale <- grp_rows$.scale[1]
    h <- grp_rows$.h[1]
    precision <- grp_rows$.precision[1]
    tol <- .vc_sum_tolerance(precision, h, k, scale)
    dev <- abs(s - scale)
    if (dev > tol + 1e-9) {
      findings[[length(findings) + 1]] <- data.frame(
        check_id = check_id,
        severity = "ERROR",
        file = grp_rows$.file[1],
        row_key = min(grp_rows$.row_key),
        message = sprintf(
          "var=%s sum=%s target=%s deviation=%s tolerance=%s",
          var, fmt_num(s), fmt_num(scale), fmt_num(dev), fmt_num(tol)
        ),
        stringsAsFactors = FALSE
      )
    }
  }

  for (pair in unique(partial_pairs)) {
    parts <- strsplit(pair, " ", fixed = TRUE)[[1]]
    findings[[length(findings) + 1]] <- data.frame(
      check_id = "RULE.CLOSURE_PARTIAL",
      severity = "INFO",
      file = "metadata/plans/SERIES_PLAN.csv",
      row_key = sprintf("indicator=%s var=%s", parts[1], paste(parts[-1], collapse = " ")),
      message = "closure's categories are not all present in the plan",
      stringsAsFactors = FALSE
    )
  }

  if (length(findings) == 0) {
    return(.vc_empty_result())
  }
  .vc_cap(do.call(rbind, findings))
}

#' RULE.SUM_TO_1_QUAL: SUM_TO_1_OVER:<QUAL_VAR> closures.
vc_rule_sum_to_1_qual <- function(ctx) {
  meta <- ctx$meta
  if (length(setdiff(.vc_META_NEEDED, names(meta))) > 0 || length(ctx$data) == 0) {
    return(.vc_empty_result())
  }
  qual_var_of <- stats::setNames(meta$CL_QUALIFIER$var_code, meta$CL_QUALIFIER$code)
  qual_slots <- paste0("MEASURE_QUAL_", 1:5)
  n_total_of <- function(var) sum(meta$CL_QUALIFIER$var_code == var, na.rm = TRUE)

  # One indicator can carry several SUM_TO_1_OVER:<VAR> tokens (with
  # different <VAR> arguments); walk each argument value separately so a
  # row is only matched against the variable named by its own token.
  ci <- meta$CL_INDICATOR
  args <- character(0)
  for (checks in ci$checks) {
    for (tok in .vc_tokens(checks)) {
      parts <- .vc_token_parts(tok)
      if (parts$name == "SUM_TO_1_OVER" && parts$arg != "") {
        args <- c(args, parts$arg)
      }
    }
  }
  args <- unique(args)
  if (length(args) == 0) {
    return(.vc_empty_result())
  }

  out <- list()
  for (var in args) {
    matches_fn <- local({
      v <- var
      function(tok) {
        parts <- .vc_token_parts(tok)
        parts$name == "SUM_TO_1_OVER" && parts$arg == v
      }
    })
    row_target_var <- local({
      v <- var
      function(rows) rep(v, nrow(rows))
    })
    out[[length(out) + 1]] <- .vc_closure_walk(
      ctx, matches_fn, "RULE.SUM_TO_1_QUAL", row_target_var, qual_slots, qual_var_of, n_total_of
    )
  }
  res <- do.call(rbind, out)
  if (is.null(res) || nrow(res) == 0) {
    return(.vc_empty_result())
  }
  .vc_cap(res)
}

#' RULE.SUM_TO_1_BRK: SUM_TO_1_OVER_BRK closures.
vc_rule_sum_to_1_brk <- function(ctx) {
  meta <- ctx$meta
  if (length(setdiff(.vc_META_NEEDED, names(meta))) > 0 || length(ctx$data) == 0) {
    return(.vc_empty_result())
  }
  comp_var_of <- stats::setNames(meta$CL_COMP_BREAKDOWN$var_code, meta$CL_COMP_BREAKDOWN$code)
  comp_slots <- paste0("COMP_BREAKDOWN_", 1:5)
  n_total_of <- function(var) sum(meta$CL_COMP_BREAKDOWN$var_code == var, na.rm = TRUE)

  sp <- meta$SERIES_PLAN
  defining_var_of_series <- stats::setNames(
    unname(comp_var_of[sp$DEFINING_BREAKDOWN]),
    sp$series_id
  )

  matches_fn <- function(tok) identical(.vc_token_parts(tok)$name, "SUM_TO_1_OVER_BRK")
  row_target_var <- function(rows) unname(defining_var_of_series[rows$series_id])

  res <- .vc_closure_walk(
    ctx, matches_fn, "RULE.SUM_TO_1_BRK", row_target_var, comp_slots, comp_var_of, n_total_of
  )
  res
}

# ---------------------------------------------------------------------------
# MONOTONE_IN:POVLINE
# ---------------------------------------------------------------------------

#' RULE.MONOTONE: among rows differing only in their POVLINE_* qualifier,
#' the value does not fall as the line's CL_QUALIFIER.value rises. Rows
#' without a value are skipped (no tolerance).
vc_rule_monotone <- function(ctx) {
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  meta <- ctx$meta
  if (is.null(meta$CL_QUALIFIER)) {
    return(.vc_empty_result())
  }

  ci <- meta$CL_INDICATOR
  inds <- ci$code[vapply(ci$checks, function(x) {
    any(vapply(.vc_tokens(x), function(tok) {
      parts <- .vc_token_parts(tok)
      parts$name == "MONOTONE_IN" && parts$arg == "POVLINE"
    }, logical(1)))
  }, logical(1))]
  sub <- rows[rows$INDICATOR %in% inds & rows$.present, , drop = FALSE]
  if (nrow(sub) == 0) {
    return(.vc_empty_result())
  }

  qual_var_of <- stats::setNames(meta$CL_QUALIFIER$var_code, meta$CL_QUALIFIER$code)
  qual_value_of <- stats::setNames(
    suppressWarnings(as.numeric(meta$CL_QUALIFIER$value)),
    meta$CL_QUALIFIER$code
  )
  qual_slots <- paste0("MEASURE_QUAL_", 1:5)

  hit <- .vc_slot_holding_var(sub, qual_slots, qual_var_of, "POVLINE")
  keep <- !is.na(hit$slot)
  sub <- sub[keep, , drop = FALSE]
  slot <- hit$slot[keep]
  category <- hit$category[keep]
  if (nrow(sub) == 0) {
    return(.vc_empty_result())
  }

  group_key <- .vc_group_key(sub, slot)
  povline_value <- unname(qual_value_of[category])

  ord_grp <- order(group_key)
  sub <- sub[ord_grp, , drop = FALSE]
  group_key <- group_key[ord_grp]
  povline_value <- povline_value[ord_grp]

  findings <- list()
  for (g in unique(group_key)) {
    idx <- which(group_key == g)
    if (length(idx) < 2) {
      next
    }
    grp <- sub[idx, , drop = FALSE]
    pv <- povline_value[idx]
    o <- order(pv)
    grp <- grp[o, , drop = FALSE]
    pv <- pv[o]
    if (any(is.na(pv))) {
      next
    }
    for (i in 2:nrow(grp)) {
      if (grp$.value[i] < grp$.value[i - 1] - 1e-9) {
        findings[[length(findings) + 1]] <- data.frame(
          check_id = "RULE.MONOTONE",
          severity = "ERROR",
          file = grp$.file[i],
          row_key = grp$.row_key[i],
          message = sprintf(
            "value=%s at line value=%s below value=%s at line value=%s",
            fmt_num(grp$.value[i]), fmt_num(pv[i]), fmt_num(grp$.value[i - 1]), fmt_num(pv[i - 1])
          ),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(findings) == 0) {
    return(.vc_empty_result())
  }
  .vc_cap(do.call(rbind, findings))
}

# ---------------------------------------------------------------------------
# AGG_NPOP_MEAN / EQUALS_NPOP_RATIO
# ---------------------------------------------------------------------------

#' RULE.NPOP_SKIPPED: AGG_NPOP_MEAN and EQUALS_NPOP_RATIO need N_POP. One
#' INFO finding per file and token when N_POP is empty; otherwise the
#' weighted mean (AGG_NPOP_MEAN) or the value-equals-N_OBS/N_POP ratio
#' (EQUALS_NPOP_RATIO) is checked within the sum tolerance.
#'
#' No indicator in CL_INDICATOR currently carries either token (see the
#' implementer report); this function is exercised only by its own unit
#' tests.
vc_rule_npop_skipped <- function(ctx) {
  rows <- .vc_build_rows(ctx)
  if (nrow(rows) == 0) {
    return(.vc_empty_result())
  }
  ci <- ctx$meta$CL_INDICATOR
  ind_tokens <- stats::setNames(lapply(ci$checks, .vc_tokens), ci$code)

  findings <- list()
  for (token_name in c("AGG_NPOP_MEAN", "EQUALS_NPOP_RATIO")) {
    inds <- ci$code[vapply(ind_tokens, function(toks) token_name %in% toks, logical(1))]
    if (length(inds) == 0) {
      next
    }
    sub <- rows[rows$INDICATOR %in% inds, , drop = FALSE]
    if (nrow(sub) == 0) {
      next
    }

    for (file in unique(sub$.file)) {
      f_rows <- sub[sub$.file == file, , drop = FALSE]
      n_pop <- suppressWarnings(as.numeric(f_rows$N_POP))
      if (all(is.na(n_pop) | f_rows$N_POP == "")) {
        findings[[length(findings) + 1]] <- data.frame(
          check_id = "RULE.NPOP_SKIPPED",
          severity = "INFO",
          file = file,
          row_key = "",
          message = sprintf("%s skipped: N_POP is empty", token_name),
          stringsAsFactors = FALSE
        )
        next
      }

      if (identical(token_name, "EQUALS_NPOP_RATIO")) {
        f_rows$.n_pop <- n_pop
        n_obs <- suppressWarnings(as.numeric(f_rows$N_OBS))
        usable <- f_rows$.present & !is.na(n_pop) & n_pop != 0 & !is.na(n_obs)
        f_rows <- f_rows[usable, , drop = FALSE]
        n_obs <- n_obs[usable]
        n_pop_u <- f_rows$.n_pop
        if (nrow(f_rows) == 0) {
          next
        }
        ratio <- n_obs / n_pop_u
        dev <- abs(f_rows$.value - ratio)
        tol <- .vc_sum_tolerance(f_rows$.precision, f_rows$.h, 1, f_rows$.value)
        bad <- dev > tol + 1e-9
        if (any(bad)) {
          bad_rows <- f_rows[bad, , drop = FALSE]
          findings[[length(findings) + 1]] <- data.frame(
            check_id = "RULE.NPOP_SKIPPED",
            severity = "ERROR",
            file = file,
            row_key = bad_rows$.row_key,
            message = sprintf(
              "value=%s != N_OBS/N_POP=%s", fmt_num(bad_rows$.value), fmt_num(ratio[bad])
            ),
            stringsAsFactors = FALSE
          )
        }
      }
      # AGG_NPOP_MEAN, when N_POP is filled: a weighted-mean parent/child
      # check like vc_rule_agg_bracket's, weighted by N_POP. No indicator
      # uses this token today (see the implementer report), so it is left
      # to a future package once real data exercises it.
    }
  }

  if (length(findings) == 0) {
    return(.vc_empty_result())
  }
  .vc_cap(do.call(rbind, findings))
}

# ---------------------------------------------------------------------------
# UNKNOWN_TOKEN
# ---------------------------------------------------------------------------

.vc_KNOWN_CHECK_NAMES <- c(
  "RANGE_0_1", "RANGE_NONNEG", "AGG_SUM", "AGG_BRACKET", "SUM_TO_1_OVER",
  "SUM_TO_1_OVER_BRK", "MONOTONE_IN", "AGG_NPOP_MEAN", "EQUALS_NPOP_RATIO", "NONE"
)

#' A token valid per WP13.md's check table.
.vc_token_is_known <- function(token) {
  parts <- .vc_token_parts(token)
  if (!(parts$name %in% .vc_KNOWN_CHECK_NAMES)) {
    return(FALSE)
  }
  needs_arg <- parts$name %in% c("SUM_TO_1_OVER", "MONOTONE_IN")
  if (needs_arg && parts$arg == "") {
    return(FALSE)
  }
  if (!needs_arg && parts$arg != "") {
    return(FALSE)
  }
  if (identical(parts$name, "MONOTONE_IN") && !identical(parts$arg, "POVLINE")) {
    return(FALSE)
  }
  TRUE
}

#' RULE.UNKNOWN_TOKEN: a token not in WP13.md's check table gives one ERROR
#' finding per indicator. Independent of ctx$data (CL_INDICATOR.checks is
#' metadata), but gated by ctx$data like every other function here
#' (WP13.md: "With no data in ctx, every function returns zero rows").
vc_rule_unknown_token <- function(ctx) {
  if (length(ctx$data) == 0) {
    return(.vc_empty_result())
  }
  ci <- ctx$meta$CL_INDICATOR
  if (is.null(ci) || nrow(ci) == 0) {
    return(.vc_empty_result())
  }

  findings <- list()
  for (i in seq_len(nrow(ci))) {
    toks <- .vc_tokens(ci$checks[i])
    bad <- Filter(function(t) !.vc_token_is_known(t), toks)
    if (length(bad) > 0) {
      findings[[length(findings) + 1]] <- data.frame(
        check_id = "RULE.UNKNOWN_TOKEN",
        severity = "ERROR",
        file = "metadata/codelists/CL_INDICATOR.csv",
        row_key = sprintf("code=%s", ci$code[i]),
        message = sprintf("unknown check token(s): %s", paste(bad, collapse = " ")),
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(findings) == 0) {
    return(.vc_empty_result())
  }
  .vc_cap(do.call(rbind, findings))
}
