# pipeline/R/validate_values.R
#
# Value checks (standard v0.5, "Validation checks" > "Values"): that
# OBS_VALUE and its attributes on every row of a data file are well formed
# - plain-decimal, in the indicator's plausible range, consistent with
# OBS_STATUS, carrying the D9 LEGACY_EMPTY comment where required, with a
# sane PRECISION, STD_ERR / CI / N_OBS / N_POP, the reliability attributes
# present on every row of a PRODUCER source, and an OBS_STATUS that follows
# the rules and precedence M O E D U A (D22). An intentionally missing
# OBS_VALUE is written NaN (SDMX-CSV, D39); N_OBS_NUM, DEFF and DF (D33)
# are checked like N_OBS and N_POP.
#
# The legacy exemptions are a property of a row's source (D16): a row
# whose SOURCE_ID has kind LEGACY_CONVERSION in SOURCES.csv may leave the
# reliability attributes empty and must carry PRECISION; a row of a
# PRODUCER source must carry them. A row whose SOURCE_ID is unknown is
# CODES.SOURCE_ID's finding and is exempt from neither rule here.
#
# Depends on `ctx` built by build_ctx() (pipeline/R/ctx.R, with its ctx_*()
# accessors), which needs pipeline/R/io.R, on pipeline/R/plan.R for
# effective_series_plan(), and on ctx$meta (CL_INDICATOR, CL_STATISTIC,
# SOURCES, SERIES_PLAN, RULES). Callers source those before this file;
# this file does not source anything itself.
#
# Findings format is the same as pipeline/R/validate_coverage.R's checks;
# see that file's header for the column and row_key conventions, and
# .vc_apply_cap() (pipeline/R/validate_common.R, which callers source
# first) for the 20-finding cap.

# A plain decimal number: optional leading '-', digits, optional '.digits'.
# No scientific notation, no leading '+', no thousands separator.
.VC_NUMERIC_RE <- "^-?[0-9]+(\\.[0-9]+)?$"

# The numeric columns of a data file, checked for plain-decimal form.
.VC_NUMERIC_COLS <- c(
  "OBS_VALUE", "PRECISION", "STD_ERR", "CI_LOWER", "CI_UPPER", "N_OBS", "N_POP",
  "N_OBS_NUM", "DEFF", "DF"
)

# The SDMX-CSV spelling of an intentionally missing OBS_VALUE (D39): the
# mandatory measure carries NaN exactly when OBS_STATUS is O or M.
.VC_MISSING <- "NaN"

#' A column as trimmed character ("" for an absent column).
.vc_col <- function(df, nm) {
  if (!(nm %in% names(df))) return(rep("", nrow(df)))
  x <- as.character(df[[nm]])
  x[is.na(x)] <- ""
  trimws(x)
}

#' A column as numeric: `NA` where empty or not a plain decimal.
.vc_num <- function(df, nm) {
  x <- .vc_col(df, nm)
  out <- rep(NA_real_, length(x))
  ok <- grepl(.VC_NUMERIC_RE, x)
  out[ok] <- as.numeric(x[ok])
  out
}

#' One findings frame for rows `idx` of `df`.
.vc_rows_finding <- function(ctx, key, df, idx, check_id, severity, message) {
  data.frame(
    check_id = check_id, severity = severity, file = .vc_file_path(key),
    row_key = ctx_row_keys(ctx, df[idx, , drop = FALSE]),
    message = message,
    stringsAsFactors = FALSE
  )
}

#' Each row's source kind (LEGACY_CONVERSION, PRODUCER, or NA).
.vc_kind <- function(ctx, df) {
  ctx_source_kind(ctx, .vc_col(df, "SOURCE_ID"))
}

#' Whether each row's indicator has a statistic that admits a standard
#' error (CL_STATISTIC.admits_se = Y).
.vc_admits_se <- function(ctx, df) {
  ind <- ctx$meta$CL_INDICATOR
  st <- ctx$meta$CL_STATISTIC
  if (is.null(ind) || is.null(st) || !("admits_se" %in% names(st))) return(rep(FALSE, nrow(df)))
  stat <- ind$statistic[match(.vc_col(df, "INDICATOR"), ind$code)]
  adm <- st$admits_se[match(stat, st$code)]
  !is.na(adm) & adm == "Y"
}

#' VALUE.NUMERIC: a filled numeric cell (OBS_VALUE, PRECISION, STD_ERR,
#' CI_LOWER, CI_UPPER, N_OBS, N_POP, N_OBS_NUM, DEFF, DF) is not a plain
#' decimal number. `NaN` in OBS_VALUE is the intentionally missing value
#' (D39) and is not a finding here; VALUE.STATUS_EMPTY ties it to O and M.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_numeric <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0) next
    for (nm in intersect(.VC_NUMERIC_COLS, names(df))) {
      raw <- .vc_col(df, nm)
      bad <- which(raw != "" & !grepl(.VC_NUMERIC_RE, raw) & !(nm == "OBS_VALUE" & raw == .VC_MISSING))
      if (length(bad) > 0) {
        out[[length(out) + 1]] <- .vc_rows_finding(
          ctx, key, df, bad, "VALUE.NUMERIC", "ERROR",
          paste0(nm, " '", raw[bad], "' is not a plain decimal number.")
        )
      }
    }
  }
  .vc_bind(out)
}

#' VALUE.RANGE: OBS_VALUE lies outside the indicator's valid_min/valid_max.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_range <- function(ctx) {
  out <- list()
  cl_indicator <- ctx$meta$CL_INDICATOR
  if (is.null(cl_indicator)) {
    return(.vc_bind(out))
  }

  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0 || !all(c("OBS_VALUE", "INDICATOR") %in% names(df))) next

    val <- .vc_num(df, "OBS_VALUE")
    has_val <- !is.na(val)
    if (!any(has_val)) next

    bounds <- cl_indicator[match(df$INDICATOR, cl_indicator$code), c("valid_min", "valid_max")]
    min_v <- suppressWarnings(as.numeric(trimws(bounds$valid_min)))
    max_v <- suppressWarnings(as.numeric(trimws(bounds$valid_max)))

    below <- has_val & !is.na(min_v) & val < min_v
    above <- has_val & !is.na(max_v) & val > max_v
    bad <- which(below | above)
    if (length(bad) > 0) {
      out[[length(out) + 1]] <- .vc_rows_finding(
        ctx, key, df, bad, "VALUE.RANGE", "ERROR",
        sprintf(
          "OBS_VALUE %s lies outside the indicator's valid range [%s, %s].",
          trimws(df$OBS_VALUE[bad]),
          ifelse(is.na(min_v[bad]), "", as.character(min_v[bad])),
          ifelse(is.na(max_v[bad]), "", as.character(max_v[bad]))
        )
      )
    }
  }
  .vc_bind(out)
}

#' VALUE.STATUS_EMPTY: OBS_VALUE is missing exactly when OBS_STATUS is O
#' or M: NaN or an empty cell under any other status, or a number under O
#' or M, is a finding. Missing is written NaN in SDMX-CSV (D39); an empty
#' cell on an O or M row is still accepted as missing.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_status_empty <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0 || !all(c("OBS_VALUE", "OBS_STATUS") %in% names(df))) next

    raw <- .vc_col(df, "OBS_VALUE")
    nan <- raw == .VC_MISSING
    filled <- raw != "" & !nan
    status <- .vc_col(df, "OBS_STATUS")
    empty_status <- status %in% c("O", "M")

    bad_empty <- !empty_status & status != "" & !filled
    bad_filled <- empty_status & filled
    bad <- which(bad_empty | bad_filled)
    if (length(bad) > 0) {
      msg <- ifelse(
        bad_empty[bad],
        paste0(
          "OBS_STATUS '", status[bad], "' requires OBS_VALUE, but it is ",
          ifelse(nan[bad], "NaN.", "empty.")
        ),
        paste0("OBS_STATUS '", status[bad], "' requires OBS_VALUE to be NaN, but it is filled.")
      )
      out[[length(out) + 1]] <- .vc_rows_finding(ctx, key, df, bad, "VALUE.STATUS_EMPTY", "ERROR", msg)
    }
  }
  .vc_bind(out)
}

#' VALUE.LEGACY_EMPTY: an O row of a LEGACY_CONVERSION source whose
#' OBS_COMMENT does not start with `"LEGACY_EMPTY:"` (decision D9).
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_legacy_empty <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0) next
    if (!all(c("OBS_STATUS", "OBS_COMMENT") %in% names(df))) next

    legacy <- .vc_kind(ctx, df) %in% "LEGACY_CONVERSION"
    is_o <- .vc_col(df, "OBS_STATUS") == "O"
    comment <- ifelse(is.na(df$OBS_COMMENT), "", df$OBS_COMMENT)
    has_prefix <- substr(comment, 1, 13) == "LEGACY_EMPTY:"
    bad <- which(legacy & is_o & !has_prefix)
    if (length(bad) > 0) {
      out[[length(out) + 1]] <- .vc_rows_finding(
        ctx, key, df, bad, "VALUE.LEGACY_EMPTY", "ERROR",
        "OBS_COMMENT on an O row of a LEGACY_CONVERSION source does not start with 'LEGACY_EMPTY:' (D9)."
      )
    }
  }
  .vc_bind(out)
}

#' VALUE.SE_CI: STD_ERR < 0, CI_LOWER > CI_UPPER, or OBS_VALUE outside
#' CI_LOWER to CI_UPPER, where these are filled.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_se_ci <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0 || !all(c("OBS_VALUE", "STD_ERR", "CI_LOWER", "CI_UPPER") %in% names(df))) next

    se <- .vc_num(df, "STD_ERR")
    val <- .vc_num(df, "OBS_VALUE")
    lo <- .vc_num(df, "CI_LOWER")
    hi <- .vc_num(df, "CI_UPPER")

    bad_se <- !is.na(se) & se < 0
    bad_order <- !is.na(lo) & !is.na(hi) & lo > hi
    bad_ci <- !is.na(val) & !is.na(lo) & !is.na(hi) & (val < lo | val > hi)
    bad <- which(bad_se | bad_order | bad_ci)
    if (length(bad) > 0) {
      msg <- vapply(bad, function(i) {
        p <- character(0)
        if (bad_se[i]) p <- c(p, "STD_ERR is negative")
        if (bad_order[i]) p <- c(p, "CI_LOWER exceeds CI_UPPER")
        if (bad_ci[i]) p <- c(p, "OBS_VALUE lies outside CI_LOWER to CI_UPPER")
        paste0(paste(p, collapse = " and "), ".")
      }, character(1))
      out[[length(out) + 1]] <- .vc_rows_finding(ctx, key, df, bad, "VALUE.SE_CI", "ERROR", msg)
    }
  }
  .vc_bind(out)
}

#' VALUE.N: N_OBS, N_OBS_NUM and DF are non-negative integers and N_POP and
#' DEFF non-negative where filled; N_OBS_NUM <= N_OBS where both are filled;
#' N_OBS and N_POP are present on every row of a PRODUCER source; N_OBS = 0
#' implies OBS_STATUS = O. A file with rows of a LEGACY_CONVERSION source
#' that leave them empty gets one INFO finding noting the exemption.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_n <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0) next
    if (!all(c("N_OBS", "N_POP", "OBS_STATUS") %in% names(df))) next

    kind <- .vc_kind(ctx, df)
    producer <- kind %in% "PRODUCER"
    legacy <- kind %in% "LEGACY_CONVERSION"

    n_obs_raw <- .vc_col(df, "N_OBS")
    n_obs <- .vc_num(df, "N_OBS")
    n_pop_raw <- .vc_col(df, "N_POP")
    n_pop <- .vc_num(df, "N_POP")

    bad_obs <- which(
      (producer & n_obs_raw == "") |
        (!is.na(n_obs) & (n_obs < 0 | n_obs != floor(n_obs)))
    )
    bad_pop <- which((producer & n_pop_raw == "") | (!is.na(n_pop) & n_pop < 0))
    zero_not_o <- which(!is.na(n_obs) & n_obs == 0 & .vc_col(df, "OBS_STATUS") != "O")

    # The three measures of D33: N_OBS_NUM and DF non-negative integers,
    # DEFF non-negative, and N_OBS_NUM <= N_OBS where both are filled.
    n_num <- .vc_num(df, "N_OBS_NUM")
    deff <- .vc_num(df, "DEFF")
    dfree <- .vc_num(df, "DF")
    not_int <- function(x) !is.na(x) & (x < 0 | x != floor(x))
    new_msgs <- rep("", nrow(df))
    addm <- function(hit, m) {
      new_msgs[hit] <<- paste0(new_msgs[hit], ifelse(new_msgs[hit] == "", "", " "), m)
    }
    addm(not_int(n_num), "N_OBS_NUM is not a non-negative integer.")
    addm(!is.na(deff) & deff < 0, "DEFF is negative.")
    addm(not_int(dfree), "DF is not a non-negative integer.")
    addm(!is.na(n_num) & !is.na(n_obs) & n_num > n_obs, "N_OBS_NUM exceeds N_OBS.")
    bad_new <- which(new_msgs != "")
    if (length(bad_new) > 0) {
      out[[length(out) + 1]] <- .vc_rows_finding(ctx, key, df, bad_new, "VALUE.N", "ERROR", new_msgs[bad_new])
    }

    if (length(bad_obs) > 0) {
      out[[length(out) + 1]] <- .vc_rows_finding(
        ctx, key, df, bad_obs, "VALUE.N", "ERROR",
        ifelse(
          n_obs_raw[bad_obs] == "",
          "N_OBS is missing on a row of a PRODUCER source.",
          "N_OBS is not a non-negative integer."
        )
      )
    }
    if (length(bad_pop) > 0) {
      out[[length(out) + 1]] <- .vc_rows_finding(
        ctx, key, df, bad_pop, "VALUE.N", "ERROR",
        ifelse(
          n_pop_raw[bad_pop] == "",
          "N_POP is missing on a row of a PRODUCER source.",
          "N_POP is negative."
        )
      )
    }
    if (length(zero_not_o) > 0) {
      out[[length(out) + 1]] <- .vc_rows_finding(
        ctx, key, df, zero_not_o, "VALUE.N", "ERROR", "N_OBS = 0 requires OBS_STATUS = O."
      )
    }

    exempt <- sum(legacy & (n_obs_raw == "" | n_pop_raw == ""))
    if (exempt > 0) {
      out[[length(out) + 1]] <- data.frame(
        check_id = "VALUE.N", severity = "INFO", file = .vc_file_path(key), row_key = "",
        message = sprintf(
          "N_OBS, N_POP, STD_ERR and CI are exempt on the %d row(s) of a LEGACY_CONVERSION source that leave them empty.",
          exempt
        ),
        stringsAsFactors = FALSE
      )
    }
  }
  .vc_bind(out)
}

#' VALUE.SE_REQUIRED: on a row of a PRODUCER source whose indicator's
#' statistic admits a standard error (CL_STATISTIC.admits_se = Y) and whose
#' OBS_VALUE is filled, STD_ERR, CI_LOWER and CI_UPPER are filled; and on
#' any row, the interval is filled wherever STD_ERR is.
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_se_required <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0 || !all(c("STD_ERR", "CI_LOWER", "CI_UPPER", "OBS_VALUE") %in% names(df))) next
    producer <- .vc_kind(ctx, df) %in% "PRODUCER"
    admits <- .vc_admits_se(ctx, df)
    filled <- !(.vc_col(df, "OBS_VALUE") %in% c("", .VC_MISSING))
    se <- .vc_col(df, "STD_ERR") != ""
    lo <- .vc_col(df, "CI_LOWER") != ""
    hi <- .vc_col(df, "CI_UPPER") != ""

    need_se <- producer & admits & filled
    miss_se <- need_se & !(se & lo & hi)
    miss_ci <- !miss_se & se & !(lo & hi)
    bad <- which(miss_se | miss_ci)
    if (length(bad) > 0) {
      msg <- ifelse(
        miss_se[bad],
        paste0(
          "STD_ERR, CI_LOWER and CI_UPPER are required on a PRODUCER-source row whose statistic admits a ",
          "standard error; missing: ",
          vapply(bad, function(i) paste(c("STD_ERR", "CI_LOWER", "CI_UPPER")[!c(se[i], lo[i], hi[i])], collapse = ", "), character(1))
        ),
        "CI_LOWER and CI_UPPER are required where STD_ERR is filled."
      )
      out[[length(out) + 1]] <- .vc_rows_finding(ctx, key, df, bad, "VALUE.SE_REQUIRED", "ERROR", msg)
    }
  }
  .vc_bind(out)
}

#' VALUE.PRECISION: PRECISION is empty or a positive number, and is filled
#' on every row of a LEGACY_CONVERSION source (D15). (A PRECISION that is
#' not a plain decimal is VALUE.NUMERIC's finding.)
#'
#' @param ctx The list from [build_ctx()].
#' @return A findings tibble.
vc_value_precision <- function(ctx) {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0 || !("PRECISION" %in% names(df))) next
    raw <- .vc_col(df, "PRECISION")
    p <- .vc_num(df, "PRECISION")
    legacy <- .vc_kind(ctx, df) %in% "LEGACY_CONVERSION"
    not_pos <- !is.na(p) & p <= 0
    missing <- legacy & raw == ""
    bad <- which(not_pos | missing)
    if (length(bad) > 0) {
      msg <- ifelse(
        not_pos[bad],
        paste0("PRECISION ", raw[bad], " is not a positive number."),
        "PRECISION is required on a row of a LEGACY_CONVERSION source (D15)."
      )
      out[[length(out) + 1]] <- .vc_rows_finding(ctx, key, df, bad, "VALUE.PRECISION", "ERROR", msg)
    }
  }
  .vc_bind(out)
}

# ---- OBS_STATUS rules (D22, D23) -------------------------------------------

#' The OBS_STATUS every row should carry, and why.
#'
#' For a row whose OBS_STATUS is not O or M (those are about the value
#' being empty, VALUE.STATUS_EMPTY's concern), the expected code is the
#' first that applies of: E (a MODEL row), D (a series whose status for
#' the row's country is DEVIATES in SERIES_PLAN.csv), U (N_OBS below
#' RELIABILITY_MIN_NOBS, or STD_ERR / |OBS_VALUE| above RELIABILITY_MAX_CV
#' for a statistic that admits a standard error and a non-zero value; never
#' on a row with neither N_OBS nor STD_ERR), A.
#'
#' @return A data frame per row: `actual`, `expected` (`NA` where the row
#'   is not evaluated: O, M, empty or an unknown ESTIMATION), `u_nobs`,
#'   `u_cv`, `model`, `deviates`.
.vc_status_eval <- function(ctx, df) {
  actual <- .vc_col(df, "OBS_STATUS")
  est <- .vc_col(df, "ESTIMATION")
  model <- est == "MODEL"

  deviates <- rep(FALSE, nrow(df))
  sid <- .vc_col(df, "SERIES_ID")
  ra <- .vc_col(df, "REF_AREA")
  if (!is.null(ctx$meta$SERIES_PLAN) && "status" %in% names(ctx$meta$SERIES_PLAN)) {
    for (a in unique(ra)) {
      plan <- effective_series_plan(ctx$meta, a)
      dev_ids <- plan$series_id[plan$status %in% "DEVIATES"]
      idx <- ra == a
      deviates[idx] <- sid[idx] %in% dev_ids
    }
  }

  min_nobs <- ctx_dataflow_threshold(ctx, "RELIABILITY_MIN_NOBS")$value
  max_cv <- ctx_dataflow_threshold(ctx, "RELIABILITY_MAX_CV")$value
  n_obs <- .vc_num(df, "N_OBS")
  se <- .vc_num(df, "STD_ERR")
  val <- .vc_num(df, "OBS_VALUE")
  admits <- .vc_admits_se(ctx, df)
  u_nobs <- !is.na(min_nobs) & !is.na(n_obs) & n_obs < min_nobs
  u_cv <- !is.na(max_cv) & admits & !is.na(se) & !is.na(val) & val != 0 & se / abs(val) > max_cv

  expected <- ifelse(model, "E", ifelse(deviates, "D", ifelse(u_nobs | u_cv, "U", "A")))
  evaluated <- !(actual %in% c("O", "M", "")) & est %in% c("SURVEY", "MODEL")
  expected[!evaluated] <- NA_character_
  data.frame(
    actual = actual, expected = expected, u_nobs = u_nobs, u_cv = u_cv,
    model = model, deviates = deviates, stringsAsFactors = FALSE
  )
}

#' Shared walk for the four OBS_STATUS checks: `select(ev)` picks the rows
#' of one check, `message(ev, idx)` words them, `severity` is a string or a
#' function of (ev, idx).
.vc_status_check <- function(ctx, check_id, select, message, severity = "ERROR") {
  out <- list()
  for (key in names(ctx$data)) {
    df <- ctx$data[[key]]
    if (nrow(df) == 0 || !("OBS_STATUS" %in% names(df))) next
    ev <- .vc_status_eval(ctx, df)
    bad <- which(select(ev))
    if (length(bad) == 0) next
    sev <- if (is.function(severity)) severity(ev, bad) else severity
    out[[length(out) + 1]] <- .vc_rows_finding(ctx, key, df, bad, check_id, sev, message(ev, bad))
  }
  .vc_bind(out)
}

#' VALUE.STATUS_MODEL: every filled row of a MODEL file carries OBS_STATUS
#' E, and no row of a SURVEY file does (precedence M O E D U A).
vc_value_status_model <- function(ctx) {
  .vc_status_check(
    ctx, "VALUE.STATUS_MODEL",
    function(ev) !is.na(ev$expected) & ev$actual != "Q" & ((ev$expected == "E") != (ev$actual == "E")),
    function(ev, i) ifelse(
      ev$model[i],
      paste0("OBS_STATUS '", ev$actual[i], "' on a filled row of a MODEL file; expected E."),
      "OBS_STATUS E on a row of a SURVEY file; E is reserved for model-based values."
    )
  )
}

#' VALUE.STATUS_DEVIATES: OBS_STATUS D is on every filled row of a series
#' whose status for the row's country is DEVIATES in SERIES_PLAN.csv, and
#' on no other row, unless a higher code (E) applies (D23).
vc_value_status_deviates <- function(ctx) {
  .vc_status_check(
    ctx, "VALUE.STATUS_DEVIATES",
    function(ev) {
      !is.na(ev$expected) & ev$actual != "Q" & ((ev$expected == "E") == (ev$actual == "E")) &
        ((ev$expected == "D") != (ev$actual == "D"))
    },
    function(ev, i) ifelse(
      ev$expected[i] == "D",
      paste0("OBS_STATUS '", ev$actual[i], "' on a row of a series the country produces with status DEVIATES; expected D."),
      "OBS_STATUS D on a row of a series that is not DEVIATES for this country in SERIES_PLAN.csv."
    )
  )
}

#' VALUE.STATUS_RELIABILITY: OBS_STATUS U is on exactly the rows that
#' breach RELIABILITY_MIN_NOBS or RELIABILITY_MAX_CV (RULES.csv) and to
#' which no higher code (E, D) applies; never on a row with neither N_OBS
#' nor STD_ERR. The severity is the breached (or, for a U that should not
#' be there, the stricter) threshold rule's.
vc_value_status_reliability <- function(ctx) {
  sev_nobs <- ctx_dataflow_threshold(ctx, "RELIABILITY_MIN_NOBS")$severity
  sev_cv <- ctx_dataflow_threshold(ctx, "RELIABILITY_MAX_CV")$severity
  min_nobs <- ctx_dataflow_threshold(ctx, "RELIABILITY_MIN_NOBS")$value
  max_cv <- ctx_dataflow_threshold(ctx, "RELIABILITY_MAX_CV")$value
  .vc_status_check(
    ctx, "VALUE.STATUS_RELIABILITY",
    function(ev) {
      !is.na(ev$expected) & ev$actual != "Q" &
        ((ev$expected == "E") == (ev$actual == "E")) &
        ((ev$expected == "D") == (ev$actual == "D")) &
        ((ev$expected == "U") != (ev$actual == "U"))
    },
    function(ev, i) ifelse(
      ev$expected[i] == "U",
      paste0(
        "OBS_STATUS '", ev$actual[i], "' but the row is of low reliability (",
        ifelse(ev$u_nobs[i], paste0("N_OBS below ", min_nobs), ""),
        ifelse(ev$u_nobs[i] & ev$u_cv[i], " and ", ""),
        ifelse(ev$u_cv[i], paste0("CV above ", max_cv), ""),
        "); expected U."
      ),
      paste0(
        "OBS_STATUS U but the row breaches neither RELIABILITY_MIN_NOBS (", min_nobs,
        ") nor RELIABILITY_MAX_CV (", max_cv, ")."
      )
    ),
    severity = function(ev, i) {
      sev <- ifelse(
        ev$expected[i] == "U",
        ifelse((ev$u_nobs[i] & sev_nobs == "ERROR") | (ev$u_cv[i] & sev_cv == "ERROR"), "ERROR", "WARN"),
        if (sev_nobs == "ERROR" || sev_cv == "ERROR") "ERROR" else "WARN"
      )
      sev
    }
  )
}

#' VALUE.STATUS_Q: OBS_STATUS Q (suppressed) is used nowhere; the database
#' publishes every estimate.
vc_value_status_q <- function(ctx) {
  .vc_status_check(
    ctx, "VALUE.STATUS_Q",
    function(ev) ev$actual == "Q",
    function(ev, i) rep("OBS_STATUS Q is reserved and not used: every estimate is published.", length(i))
  )
}
