# pipeline/tests/testthat/test-validate-rules.R
#
# Tests for pipeline/R/validate_rules.R (WP13.md).
#
# Fixtures are built on a temporary copy of the real metadata
# (make_temp_root(), auto-sourced from helper-temp-root.R) plus
# make_data_fixture() (helper-data-fixture.R), restricted to the series
# WP13.md names: POV_NUM/POV_HC's two POVLINE series, the 13 plain
# CONS_SH.COICOP_* series, and the five POP_HH_SH.HE_COUNT_* series.
#
# TAB_PLAN.csv is trimmed (on the temp copy only, never the real file) to
# just the cuts a test needs, for two reasons found while building this
# fixture (see the implementer report's Questions):
#   - the real TAB_PLAN's AEZ cut has ref_area "ALL", but CL_GEO has no
#     AEZ codes for SEN, so required_rows(meta, "SEN", ...) on the
#     unmodified metadata stops with an error;
#   - AGG_SUM's parent is a single TOTAL-cut row, shared by every other
#     cut. The real TAB_PLAN's non-TOTAL cuts (URB, HHH_SEX, HHH_AGE,
#     QUINT, ADM1, ZONES) have different child counts k, so one parent
#     value cannot satisfy "sum of children" for all of them at once.
#     Each test keeps TOTAL plus exactly one other cut.

root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "codes.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "plan.R"))
source(file.path(root, "pipeline", "R", "ctx.R"))
source(file.path(root, "pipeline", "R", "validate_rules.R"))

ALL_RULE_FNS <- c(
  "vc_rule_range_0_1", "vc_rule_range_nonneg", "vc_rule_agg_sum",
  "vc_rule_agg_bracket", "vc_rule_sum_to_1_qual", "vc_rule_sum_to_1_brk",
  "vc_rule_monotone", "vc_rule_npop_skipped", "vc_rule_unknown_token"
)

run_all_rules <- function(ctx) {
  do.call(rbind, lapply(ALL_RULE_FNS, function(fn) get(fn)(ctx)))
}

BASE_SERIES <- c(
  "POV_NUM.POVLINE_PL300.PPP_2021", "POV_NUM.POVLINE_PL420.PPP_2021",
  "POV_HC.POVLINE_PL300.PPP_2021", "POV_HC.POVLINE_PL420.PPP_2021",
  paste0("CONS_SH.COICOP_CP", sprintf("%02d", 1:13)),
  paste0("POP_HH_SH.HE_COUNT_", c("0", "1", "2", "3", "4P"))
)

#' make_data_fixture() (helper-data-fixture.R) writes its manifest as one
#' row of named columns (dataflow, ..., precision, ...). ctx.R's
#' build_ctx() reads a manifest as key/value pairs (column 1 = key, column
#' 2 = value), matching contract/csv_headers.csv's 2-column schema for
#' `AFW360_HH_<ISO3>_<YEAR>_manifest.csv`. Reading the fixture's wide
#' manifest that way turns its first two column names/values
#' ("dataflow"/"AFW360_HH", "dsd_version"/"TBD") into the only key/value
#' pair, so `ctx$precision` always comes back "EXACT" (the default),
#' never the fixture's "ROUNDED_2DP" (see the implementer report's
#' Questions). Rewritten here, in the test fixture only, into the format
#' build_ctx() and the contract expect.
fix_manifest_format <- function(data_path) {
  manifest_path <- sub("\\.csv$", "_manifest.csv", data_path)
  wide <- read_std_csv(manifest_path)
  long <- data.frame(
    key = names(wide),
    value = as.character(unlist(wide[1, ])),
    stringsAsFactors = FALSE
  )
  write_std_csv(long, manifest_path)
  invisible(long)
}

#' A temp metadata root with TAB_PLAN trimmed to TOTAL plus `cuts`, and a
#' data fixture for `series_ids` under it (WP13.md Steps).
make_rules_root <- function(series_ids = BASE_SERIES, cuts = "URB", ref_area = "SEN") {
  tmp <- make_temp_root(root)
  edit_csv(file.path(tmp, "metadata", "plans", "TAB_PLAN.csv"), function(df) {
    df[df$cut_id %in% c("TOTAL", cuts), , drop = FALSE]
  })
  data_path <- make_data_fixture(tmp, ref_area, "2021", series_ids = series_ids)
  fix_manifest_format(data_path)
  list(root = tmp, data_path = data_path)
}

#' Whether each row's MEASURE_QUAL slots hold `code`.
row_has_qual <- function(df, code) {
  Reduce(`|`, lapply(paste0("MEASURE_QUAL_", 1:5), function(cn) df[[cn]] == code))
}

#' Whether each row's COMP_BREAKDOWN slots hold `code`.
row_has_comp <- function(df, code) {
  Reduce(`|`, lapply(paste0("COMP_BREAKDOWN_", 1:5), function(cn) df[[cn]] == code))
}

#' Set OBS_VALUE by rule (WP13.md Steps), not by hand: every POV_NUM child
#' (a non-TOTAL cut row) gets 1000000 and its TOTAL-cut parent
#' 1000000 x k, where k is the number of non-TOTAL cells for that series
#' (the URBANISATION domain "CAP OU R" has 3 cells, so k = 3 by default);
#' every POV_HC row gets 0.2 for PL300 and 0.4 for PL420 (both cuts, so
#' AGG_BRACKET's bracket collapses to a point and is unaffected by k);
#' every CONS_SH row gets fmt_num(1/13) and every POP_HH_SH row
#' fmt_num(1/5) (again independent of k, for the same reason).
set_consistent_values <- function(df, k = 3) {
  is_child <- df$URBANISATION != "_T"
  pov_num_val <- ifelse(is_child, "1000000", fmt_num(1000000 * k))

  df$OBS_VALUE <- ifelse(
    df$INDICATOR == "POV_NUM", pov_num_val,
    ifelse(
      df$INDICATOR == "POV_HC",
      ifelse(row_has_qual(df, "POVLINE_PL300"), "0.2", "0.4"),
      ifelse(
        df$INDICATOR == "CONS_SH", fmt_num(1 / 13),
        ifelse(df$INDICATOR == "POP_HH_SH", fmt_num(1 / 5), df$OBS_VALUE)
      )
    )
  )
  df
}

#' The consistent fixture (WP13.md Steps), built with TOTAL + URB (k = 3).
make_consistent_ctx <- function() {
  fx <- make_rules_root()
  edit_csv(fx$data_path, function(df) set_consistent_values(df, k = 3))
  list(ctx = build_ctx(fx$root, data_files = fx$data_path), root = fx$root, data_path = fx$data_path)
}

#' The series_id -> scale LEGACY_LABELS gives a series, in a temp root
#' (WP13.md "Tolerance"; mirrors .vc_series_scale()).
series_scale <- function(tmp_root, series_id) {
  ll <- read_std_csv(file.path(tmp_root, "metadata", "plans", "LEGACY_LABELS.csv"))
  row <- ll[ll$series_id == series_id, , drop = FALSE][1, ]
  s <- suppressWarnings(as.numeric(row$scale))
  if (length(s) == 0 || is.na(s)) 1 else s
}

# ---------------------------------------------------------------------------
# WP13.A1
# ---------------------------------------------------------------------------

test_that("WP13.A1: the consistent fixture gives 0 ERROR", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))

  res <- run_all_rules(fx$ctx)
  expect_equal(nrow(res[res$severity == "ERROR", , drop = FALSE]), 0)
})

# ---------------------------------------------------------------------------
# WP13.A2
# ---------------------------------------------------------------------------

test_that("WP13.A2: a doubled POV_NUM child gives RULE.AGG_SUM", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))

  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "POV_NUM" & row_has_qual(df, "POVLINE_PL300") & df$URBANISATION == "CAP")
    stopifnot(length(idx) == 1)
    df$OBS_VALUE[idx] <- fmt_num(as.numeric(df$OBS_VALUE[idx]) * 2)
    df
  })

  res <- vc_rule_agg_sum(build_ctx(fx$root, data_files = fx$data_path))
  expect_true("RULE.AGG_SUM" %in% res$check_id)
  expect_true(all(res$check_id[res$severity == "ERROR"] == "RULE.AGG_SUM"))
})

test_that("WP13.A2: a POV_HC parent set far above every child gives RULE.AGG_BRACKET", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))

  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "POV_HC" & row_has_qual(df, "POVLINE_PL300") & df$URBANISATION == "_T")
    stopifnot(length(idx) == 1)
    df$OBS_VALUE[idx] <- "0.9"
    df
  })

  res <- vc_rule_agg_bracket(build_ctx(fx$root, data_files = fx$data_path))
  expect_true("RULE.AGG_BRACKET" %in% res$check_id)
})

test_that("WP13.A2: one COICOP share raised to a 1.2 cell sum gives RULE.SUM_TO_1_QUAL", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))

  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "CONS_SH" & row_has_qual(df, "COICOP_CP01") & df$URBANISATION == "_T")
    stopifnot(length(idx) == 1)
    df$OBS_VALUE[idx] <- fmt_num(1 / 13 + 0.2)
    df
  })

  res <- vc_rule_sum_to_1_qual(build_ctx(fx$root, data_files = fx$data_path))
  expect_true("RULE.SUM_TO_1_QUAL" %in% res$check_id)
})

test_that("WP13.A2: one HE_COUNT share raised to a 1.2 cell sum gives RULE.SUM_TO_1_BRK", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))

  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "POP_HH_SH" & row_has_comp(df, "HE_COUNT_0") & df$URBANISATION == "_T")
    stopifnot(length(idx) == 1)
    df$OBS_VALUE[idx] <- fmt_num(1 / 5 + 0.2)
    df
  })

  res <- vc_rule_sum_to_1_brk(build_ctx(fx$root, data_files = fx$data_path))
  expect_true("RULE.SUM_TO_1_BRK" %in% res$check_id)
})

test_that("WP13.A2: PL300 set above PL420 in one cell gives RULE.MONOTONE", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))

  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "POV_HC" & row_has_qual(df, "POVLINE_PL300") & df$URBANISATION == "_T")
    stopifnot(length(idx) == 1)
    df$OBS_VALUE[idx] <- "0.5"
    df
  })

  res <- vc_rule_monotone(build_ctx(fx$root, data_files = fx$data_path))
  expect_true("RULE.MONOTONE" %in% res$check_id)
})

test_that("WP13.A2: a share set to 1.3 gives RULE.RANGE_0_1", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))

  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "CONS_SH" & row_has_qual(df, "COICOP_CP01") & df$URBANISATION == "_T")
    stopifnot(length(idx) == 1)
    df$OBS_VALUE[idx] <- "1.3"
    df
  })

  res <- vc_rule_range_0_1(build_ctx(fx$root, data_files = fx$data_path))
  expect_true("RULE.RANGE_0_1" %in% res$check_id)
})

# ---------------------------------------------------------------------------
# WP13.A3
# ---------------------------------------------------------------------------

test_that("WP13.A3: a COICOP cell that sums to 0.97 passes (tolerance 0.065)", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))

  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "CONS_SH" & row_has_qual(df, "COICOP_CP01") & df$URBANISATION == "_T")
    stopifnot(length(idx) == 1)
    df$OBS_VALUE[idx] <- fmt_num(1 / 13 - 0.03) # cell sum: 1 - 0.03 = 0.97
    df
  })

  res <- vc_rule_sum_to_1_qual(build_ctx(fx$root, data_files = fx$data_path))
  expect_false("RULE.SUM_TO_1_QUAL" %in% res$check_id)
})

test_that("WP13.A3: a POV_NUM parent of 3130000 with 6 children summing to 3120000 passes (tolerance 35000)", {
  fx <- make_rules_root(series_ids = "POV_NUM.POVLINE_PL300.PPP_2021", cuts = "ZONES")
  on.exit(unlink(fx$root, recursive = TRUE))

  h <- 0.005 * series_scale(fx$root, "POV_NUM.POVLINE_PL300.PPP_2021")
  k <- 6 # SEN's ZONES scheme has 6 codes
  tol <- (k + 1) * h
  expect_equal(tol, 35000) # confirms the fixture matches WP13.md's worked example

  edit_csv(fx$data_path, function(df) {
    stopifnot(sum(df$GEO == "_T") == 1, sum(df$GEO != "_T") == k)
    df$OBS_VALUE[df$GEO == "_T"] <- "3130000"
    child_idx <- which(df$GEO != "_T")
    df$OBS_VALUE[child_idx] <- fmt_num(3120000 / k)
    df
  })

  res <- vc_rule_agg_sum(build_ctx(fx$root, data_files = fx$data_path))
  expect_false("RULE.AGG_SUM" %in% res$check_id)
})

# ---------------------------------------------------------------------------
# WP13.A4
# ---------------------------------------------------------------------------

test_that("WP13.A4: a deviation of exactly the tolerance passes, and tolerance + 0.001 x scale fails", {
  fx <- make_rules_root(series_ids = "POV_NUM.POVLINE_PL300.PPP_2021", cuts = "ZONES")
  on.exit(unlink(fx$root, recursive = TRUE))

  scale <- series_scale(fx$root, "POV_NUM.POVLINE_PL300.PPP_2021")
  h <- 0.005 * scale
  k <- 6
  tol <- (k + 1) * h
  parent <- 6000000

  set_children_sum <- function(df, target_sum) {
    child_idx <- which(df$GEO != "_T")
    stopifnot(length(child_idx) == k)
    df$OBS_VALUE[child_idx[1]] <- fmt_num(target_sum - 1000000 * (k - 1))
    df$OBS_VALUE[child_idx[-1]] <- "1000000"
    df
  }

  edit_csv(fx$data_path, function(df) {
    df$OBS_VALUE[df$GEO == "_T"] <- fmt_num(parent)
    set_children_sum(df, parent - tol) # deviation == tol, exactly at the boundary
  })
  res_pass <- vc_rule_agg_sum(build_ctx(fx$root, data_files = fx$data_path))
  expect_false("RULE.AGG_SUM" %in% res_pass$check_id)

  edit_csv(fx$data_path, function(df) {
    set_children_sum(df, parent - tol - 0.001 * scale)
  })
  res_fail <- vc_rule_agg_sum(build_ctx(fx$root, data_files = fx$data_path))
  expect_true("RULE.AGG_SUM" %in% res_fail$check_id)
})

# ---------------------------------------------------------------------------
# WP13.A5
# ---------------------------------------------------------------------------

test_that("WP13.A5: a deleted child gives WARN RULE.AGG_SKIPPED and no ERROR for that parent and cut", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))

  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "POV_NUM" & row_has_qual(df, "POVLINE_PL300") & df$URBANISATION == "CAP")
    stopifnot(length(idx) == 1)
    df[-idx, , drop = FALSE]
  })

  res <- vc_rule_agg_sum(build_ctx(fx$root, data_files = fx$data_path))
  expect_true("RULE.AGG_SKIPPED" %in% res$check_id)
  expect_equal(unique(res$severity[res$check_id == "RULE.AGG_SKIPPED"]), "WARN")
  expect_equal(nrow(res[res$severity == "ERROR", , drop = FALSE]), 0)
})

test_that("WP13.A5: the partial variable EMP_STATUS gives INFO RULE.CLOSURE_PARTIAL and no ERROR", {
  fx <- make_rules_root(series_ids = "POP_SH.EMP_STATUS_EMPLOYED", cuts = "URB")
  on.exit(unlink(fx$root, recursive = TRUE))

  res <- vc_rule_sum_to_1_brk(build_ctx(fx$root, data_files = fx$data_path))
  expect_true("RULE.CLOSURE_PARTIAL" %in% res$check_id)
  info <- res[res$check_id == "RULE.CLOSURE_PARTIAL", , drop = FALSE]
  expect_equal(unique(info$severity), "INFO")
  expect_true(any(grepl("EMP_STATUS", info$row_key)))
  expect_equal(nrow(res[res$severity == "ERROR", , drop = FALSE]), 0)
})

# ---------------------------------------------------------------------------
# WP13.A6
# ---------------------------------------------------------------------------

test_that("WP13.A6: with ctx$data empty, every function returns zero rows", {
  tmp <- make_temp_root(root)
  on.exit(unlink(tmp, recursive = TRUE))
  ctx <- build_ctx(tmp)
  expect_equal(length(ctx$data), 0)

  for (fn in ALL_RULE_FNS) {
    res <- get(fn)(ctx)
    expect_equal(nrow(res), 0, info = fn)
    expect_equal(names(res), c("check_id", "severity", "file", "row_key", "message"), info = fn)
  }
})

# ---------------------------------------------------------------------------
# RULE.UNKNOWN_TOKEN (WP13.md check table; not one of WP13.A1-A6, but part
# of the interface's "one function per check").
# ---------------------------------------------------------------------------

test_that("an unrecognised token gives one RULE.UNKNOWN_TOKEN finding per indicator", {
  fx <- make_rules_root(series_ids = "CONS_SH.COICOP_CP01", cuts = "URB")
  on.exit(unlink(fx$root, recursive = TRUE))

  edit_csv(file.path(fx$root, "metadata", "codelists", "CL_INDICATOR.csv"), function(df) {
    df$checks[df$code == "CONS_SH"] <- paste(df$checks[df$code == "CONS_SH"], "BOGUS_TOKEN")
    df
  })

  res <- vc_rule_unknown_token(build_ctx(fx$root, data_files = fx$data_path))
  hit <- res[res$check_id == "RULE.UNKNOWN_TOKEN" & res$row_key == "code=CONS_SH", , drop = FALSE]
  expect_equal(nrow(hit), 1)
  expect_equal(hit$severity, "ERROR")
})
