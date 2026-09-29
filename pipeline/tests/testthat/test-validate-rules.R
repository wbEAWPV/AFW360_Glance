# pipeline/tests/testthat/test-validate-rules.R
#
# Tests for pipeline/R/validate_rules.R (WP13.md; since standard v0.5 every
# rule is a row of metadata/rules/RULES.csv and tolerances follow each
# row's PRECISION).
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
#   - (historical) the AEZ cut once had ref_area "ALL", which CL_GEO could
#     not satisfy for SEN;
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
source(file.path(root, "pipeline", "R", "manifest.R"))
source(file.path(root, "pipeline", "R", "validate_rules.R"))

ALL_RULE_FNS <- c(
  "vc_rule_range_0_1", "vc_rule_range_nonneg", "vc_rule_agg_sum",
  "vc_rule_agg_bracket", "vc_rule_sum_to_1_qual", "vc_rule_sum_to_1_brk",
  "vc_rule_monotone", "vc_rule_agg_npop_mean", "vc_rule_npop_partition"
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

#' A temp metadata root with TAB_PLAN trimmed to TOTAL plus `cuts`, and a
#' data fixture for `series_ids` under it (WP13.md Steps).
#'
#' make_data_fixture() (helper-data-fixture.R) writes its manifest in the
#' contract's long key/value form (one `key`, `value` row per key), which
#' ctx.R's build_ctx() reads directly (column 1 = key, column 2 = value),
#' matching seeds/csv_headers.csv's 2-column schema for
#' `AFW360_HH_<ISO3>_<YEAR>_manifest.csv`. No rewrite is needed here.
make_rules_root <- function(series_ids = BASE_SERIES, cuts = "URB", ref_area = "SEN") {
  tmp <- make_temp_root(root)
  edit_csv(file.path(tmp, "metadata", "plans", "TAB_PLAN.csv"), function(df) {
    df[df$cut_id %in% c("TOTAL", cuts), , drop = FALSE]
  })
  data_path <- make_data_fixture(tmp, ref_area, "2021", series_ids = series_ids)
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

#' The series_id -> scale LEGACY_LABELS gives a series, in a temp root. The
#' fixture writes PRECISION = 0.01 x scale on every row of a series, so the
#' validator's h = PRECISION / 2 = 0.005 x scale.
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

test_that("a data file with more than one series' scale gives each row its own h, not the first row's", {
  # Regression for the patch-p1 finding (WP13.A3): .vc_build_rows() computes
  # h from a per-file scalar `precision` and a per-row `scale` vector
  # (pipeline/R/validate_rules.R ~L251-252). ifelse()'s result takes the
  # shape of its `test` argument, so a naive `ifelse(precision == ...,
  # 0.005 * scale, 0)` silently collapses to length 1 (0.005 * scale[1],
  # recycled over every row) instead of multiplying each row's own scale.
  # WP13.A3's own unit test above does not catch this: make_rules_root()
  # restricts SERIES_PLAN to one series (POV_NUM), so scale[1] happens to
  # be that series' own scale. The acceptance script's fixture (no
  # restriction, WP13.md's real multi-series SERIES_PLAN) put a
  # zero-scale series ahead of POV_NUM in required_rows(), so h collapsed
  # to 0.005 * 1 for every row -- 1,000,000x too small. This test keeps two
  # series with different scales (POV_NUM, scale 1000000; CONS_SH, scale 1)
  # in the same fixture and checks POV_NUM's own tolerance is used.
  fx <- make_rules_root(
    series_ids = c("POV_NUM.POVLINE_PL300.PPP_2021", "CONS_SH.COICOP_CP01"),
    cuts = "ZONES"
  )
  on.exit(unlink(fx$root, recursive = TRUE))

  h <- 0.005 * series_scale(fx$root, "POV_NUM.POVLINE_PL300.PPP_2021")
  expect_equal(h, 5000) # POV_NUM's own scale (1000000), not CONS_SH's (1)
  k <- 6 # SEN's ZONES scheme has 6 codes
  tol <- (k + 1) * h

  edit_csv(fx$data_path, function(df) {
    stopifnot(sum(df$INDICATOR == "POV_NUM" & df$GEO == "_T") == 1)
    stopifnot(sum(df$INDICATOR == "POV_NUM" & df$GEO != "_T") == k)
    is_povnum <- df$INDICATOR == "POV_NUM"
    df$OBS_VALUE[is_povnum & df$GEO == "_T"] <- "3130000"
    child_idx <- which(is_povnum & df$GEO != "_T")
    df$OBS_VALUE[child_idx] <- fmt_num(3120000 / k) # sum 3120000, deviation 10000 <= tol 35000
    df$OBS_VALUE[!is_povnum] <- fmt_num(1 / 13)
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
# Standard v0.5 (WP-C): rules from RULES.csv, per-row PRECISION tolerances
# ---------------------------------------------------------------------------

#' Edit the temp root's RULES.csv.
edit_rules <- function(tmp_root, fn) {
  edit_csv(file.path(tmp_root, "metadata", "rules", "RULES.csv"), fn)
}

#' Append one RULES.csv row.
add_rule <- function(tmp_root, scope, scope_code, rule, param = "", tolerance = "", severity = "ERROR") {
  edit_rules(tmp_root, function(df) {
    prefix <- if (scope == "DATAFLOW") "AFW360_HH" else scope_code
    new <- df[1, ]
    new$rule_id <- paste0(prefix, ".", rule, if (nzchar(param)) paste0(".", param) else "")
    new$scope <- scope
    new$scope_code <- scope_code
    new$rule <- rule
    new$param <- param
    new$tolerance <- tolerance
    new$severity <- severity
    new$notes <- ""
    rbind(df, new)
  })
}

test_that("PRECISION drives the tolerance: a legacy share 0.005 above 1 passes, an exact share 0.001 above fails", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))

  cp01 <- function(df) which(df$INDICATOR == "CONS_SH" & row_has_qual(df, "COICOP_CP01") & df$URBANISATION == "_T")
  edit_csv(fx$data_path, function(df) {
    idx <- cp01(df)
    expect_equal(df$PRECISION[idx], "0.01") # a legacy row: h = 0.005
    df$OBS_VALUE[idx] <- "1.005"
    df
  })
  res <- vc_rule_range_0_1(build_ctx(fx$root, data_files = fx$data_path))
  expect_false("RULE.RANGE_0_1" %in% res$check_id)

  edit_csv(fx$data_path, function(df) {
    idx <- cp01(df)
    df$PRECISION[idx] <- "" # an exact value: h = 0
    df$OBS_VALUE[idx] <- "1.001"
    df
  })
  res <- vc_rule_range_0_1(build_ctx(fx$root, data_files = fx$data_path))
  expect_equal(sum(res$check_id == "RULE.RANGE_0_1"), 1L)
  expect_match(res$message[res$check_id == "RULE.RANGE_0_1"], "rule=CONS_SH.RANGE_0_1", fixed = TRUE)
})

test_that("an exact AGG_SUM child off by 0.001 fails; the largest h among the rows compared widens it", {
  fx <- make_rules_root(series_ids = "POV_NUM.POVLINE_PL300.PPP_2021", cuts = "URB")
  on.exit(unlink(fx$root, recursive = TRUE))

  edit_csv(fx$data_path, function(df) {
    df$PRECISION <- ""
    df$OBS_VALUE[df$URBANISATION == "_T"] <- "3000000"
    df$OBS_VALUE[df$URBANISATION != "_T"] <- "1000000"
    df$OBS_VALUE[df$URBANISATION == "CAP"] <- "1000000.001"
    df
  })
  res <- vc_rule_agg_sum(build_ctx(fx$root, data_files = fx$data_path))
  expect_true("RULE.AGG_SUM" %in% res$check_id)

  # One legacy child (PRECISION 10000, h 5000) makes the bound (k + 1) x 5000.
  edit_csv(fx$data_path, function(df) {
    df$PRECISION[df$URBANISATION == "R"] <- "10000"
    df$OBS_VALUE[df$URBANISATION == "CAP"] <- "1019999"
    df
  })
  res <- vc_rule_agg_sum(build_ctx(fx$root, data_files = fx$data_path))
  expect_false("RULE.AGG_SUM" %in% res$check_id)
})

test_that("a filled RULES.csv tolerance replaces the computed bound", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))
  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "CONS_SH" & row_has_qual(df, "COICOP_CP01") & df$URBANISATION == "_T")
    df$PRECISION[idx] <- ""
    df$OBS_VALUE[idx] <- "1.001"
    df
  })
  edit_rules(fx$root, function(df) {
    df$tolerance[df$rule_id == "CONS_SH.RANGE_0_1"] <- "0.01"
    df
  })
  res <- vc_rule_range_0_1(build_ctx(fx$root, data_files = fx$data_path))
  expect_false("RULE.RANGE_0_1" %in% res$check_id)
})

test_that("a rule's severity comes from its RULES.csv row, and a SERIES rule applies to its series only", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))
  edit_csv(fx$data_path, function(df) {
    for (q in c("POVLINE_PL300", "POVLINE_PL420")) {
      idx <- which(df$INDICATOR == "POV_HC" & row_has_qual(df, q) & df$URBANISATION == "_T")
      df$PRECISION[idx] <- ""
      df$OBS_VALUE[idx] <- "1.2"
    }
    df
  })
  edit_rules(fx$root, function(df) df[df$rule_id != "POV_HC.RANGE_0_1", ])
  add_rule(fx$root, "SERIES", "POV_HC.POVLINE_PL420.PPP_2021", "RANGE_0_1", severity = "WARN")
  res <- vc_rule_range_0_1(build_ctx(fx$root, data_files = fx$data_path))
  hit <- res[res$check_id == "RULE.RANGE_0_1", ]
  expect_equal(nrow(hit), 1L)
  expect_equal(hit$severity, "WARN")
  expect_match(hit$row_key, "POVLINE_PL420", fixed = TRUE)
  expect_match(hit$message, "rule=POV_HC.POVLINE_PL420.PPP_2021.RANGE_0_1", fixed = TRUE)
})

test_that("MONOTONE_IN takes its variable from param and orders categories by CL_QUALIFIER.order", {
  fx <- make_consistent_ctx()
  on.exit(unlink(fx$root, recursive = TRUE))
  # With the rule removed, the PL300 > PL420 inversion is not checked.
  edit_rules(fx$root, function(df) df[df$rule != "MONOTONE_IN", ])
  edit_csv(fx$data_path, function(df) {
    idx <- which(df$INDICATOR == "POV_HC" & row_has_qual(df, "POVLINE_PL300") & df$URBANISATION == "_T")
    df$OBS_VALUE[idx] <- "0.5"
    df
  })
  res <- vc_rule_monotone(build_ctx(fx$root, data_files = fx$data_path))
  expect_equal(nrow(res), 0L)

  add_rule(fx$root, "INDICATOR", "POV_HC", "MONOTONE_IN", param = "POVLINE")
  res <- vc_rule_monotone(build_ctx(fx$root, data_files = fx$data_path))
  expect_equal(sum(res$check_id == "RULE.MONOTONE"), 1L)
  expect_match(res$message, "POVLINE order 5", fixed = TRUE) # PL420's order, above PL300's 4
})

test_that("AGG_NPOP_MEAN checks the N_POP-weighted mean, and is skipped with INFO where N_POP is empty", {
  fx <- make_rules_root(series_ids = "POV_HC.POVLINE_PL300.PPP_2021", cuts = "URB")
  on.exit(unlink(fx$root, recursive = TRUE))
  add_rule(fx$root, "INDICATOR", "POV_HC", "AGG_NPOP_MEAN")

  res <- vc_rule_agg_npop_mean(build_ctx(fx$root, data_files = fx$data_path))
  expect_equal(res$check_id, "RULE.NPOP_SKIPPED")
  expect_equal(res$severity, "INFO")

  edit_csv(fx$data_path, function(df) {
    df$PRECISION <- ""
    child <- df$URBANISATION != "_T"
    df$OBS_VALUE[child] <- c("0.1", "0.2", "0.6")
    df$N_POP[child] <- c("100", "300", "600")
    df$OBS_VALUE[!child] <- "0.43" # (10 + 60 + 360) / 1000
    df$N_POP[!child] <- "1000"
    df
  })
  res <- vc_rule_agg_npop_mean(build_ctx(fx$root, data_files = fx$data_path))
  expect_equal(nrow(res), 0L)

  edit_csv(fx$data_path, function(df) {
    df$OBS_VALUE[df$URBANISATION == "_T"] <- "0.431"
    df
  })
  res <- vc_rule_agg_npop_mean(build_ctx(fx$root, data_files = fx$data_path))
  expect_equal(res$check_id, "RULE.AGG_NPOP_MEAN")
})

test_that("RULE.NPOP_PARTITION sums N_POP over population cuts, never over a defining breakdown", {
  he <- paste0("POP_HH_SH.HE_COUNT_", c("0", "1", "2", "3", "4P"))
  fx <- make_rules_root(series_ids = he, cuts = "URB")
  on.exit(unlink(fx$root, recursive = TRUE))

  # Every HE_COUNT series is a share of the same households, so each
  # series' N_POP is the same denominator: 1000 in total, 300 + 300 + 400 by
  # residence. Summing over the defining breakdown (5 x 1000) would fail.
  edit_csv(fx$data_path, function(df) {
    df$OBS_VALUE <- "0.2"
    df$N_POP <- ifelse(df$URBANISATION == "_T", "1000", ifelse(df$URBANISATION == "R", "400", "300"))
    df
  })
  res <- vc_rule_npop_partition(build_ctx(fx$root, data_files = fx$data_path))
  expect_equal(nrow(res), 0L)

  edit_csv(fx$data_path, function(df) {
    idx <- which(df$SERIES_ID == "POP_HH_SH.HE_COUNT_1" & df$URBANISATION == "R")
    df$N_POP[idx] <- "401"
    df
  })
  res <- vc_rule_npop_partition(build_ctx(fx$root, data_files = fx$data_path))
  expect_equal(res$check_id, "RULE.NPOP_PARTITION")
  expect_match(res$message, "series=POP_HH_SH.HE_COUNT_1 cut=URB", fixed = TRUE)

  # A cut some of whose rows carry no N_POP is skipped with a WARN.
  edit_csv(fx$data_path, function(df) {
    idx <- which(df$SERIES_ID == "POP_HH_SH.HE_COUNT_1" & df$URBANISATION == "R")
    df$N_POP[idx] <- ""
    df
  })
  res <- vc_rule_npop_partition(build_ctx(fx$root, data_files = fx$data_path))
  expect_equal(res$check_id, "RULE.AGG_SKIPPED")
  expect_equal(res$severity, "WARN")
})

test_that("the retired EQUALS_NPOP_RATIO rule is unknown to META.RULES", {
  source(file.path(root, "pipeline", "R", "validate_structure.R"))
  source(file.path(root, "pipeline", "R", "validate_metadata.R"))
  tmp <- make_temp_root(root)
  on.exit(unlink(tmp, recursive = TRUE))
  add_rule(tmp, "INDICATOR", "POP_SH", "EQUALS_NPOP_RATIO")
  res <- vc_meta_rules(build_ctx(tmp))
  expect_equal(nrow(res), 1L)
  expect_match(res$message, "unknown rule 'EQUALS_NPOP_RATIO'", fixed = TRUE)
})

# ---------------------------------------------------------------------------
# WP4b: NaN is the SDMX-CSV spelling of an intentionally missing OBS_VALUE
# ---------------------------------------------------------------------------

test_that("a NaN OBS_VALUE on an O row is absent, not a number, to the rules", {
  fx <- make_rules_root()
  on.exit(unlink(fx$root, recursive = TRUE))
  edit_csv(fx$data_path, function(df) {
    df <- set_consistent_values(df, k = 3)
    df$OBS_VALUE[1] <- "NaN"
    df$OBS_STATUS[1] <- "O"
    df
  })
  ctx <- build_ctx(fx$root, data_files = fx$data_path)
  rows <- .vc_build_rows(ctx)
  hit <- rows[rows$.obs_status %in% "O", , drop = FALSE]
  expect_equal(nrow(hit), 1L)
  expect_true(is.na(hit$.value) && !is.nan(hit$.value))
  expect_false(hit$.present)
  res <- run_all_rules(ctx)
  expect_false(any(grepl("NaN", res$message)))
})
