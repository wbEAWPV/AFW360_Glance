# pipeline/R/plan.R
#
# The required-row generator (WP08): turns SERIES_PLAN and TAB_PLAN into the
# exact set of rows a country's data file must contain
# (.docs/transition/packages/WP08.md). Does not subtract withheld cells;
# that is the coverage check's job (WP12).
#
# Depends on pipeline/R/codes.R for slot_sort() and fill_slots(), and
# pipeline/R/constants.R for SENTINEL_TOTAL, SENTINEL_NA, DATAFLOW_ID and
# KEY_COLUMNS. Callers source those (and pipeline/R/io.R, for building
# `meta` with load_metadata()) before this file.

#' Split a space-separated field into tokens.
#'
#' @param x A single string, possibly `""` or `NA`.
#' @return A character vector, possibly empty.
.plan_tokens <- function(x) {
  x <- if (length(x) == 0) NA_character_ else x[[1]]
  if (is.na(x) || x == "") {
    return(character(0))
  }
  strsplit(x, "\\s+")[[1]]
}

#' The exact set of rows a country's data file must contain.
#'
#' Crosses every series of `meta$SERIES_PLAN` with every cut of
#' `meta$TAB_PLAN` that applies to it, and every cell of that cut, following
#' WP08.md's "Required rows" rule:
#'   1. Keep the `SERIES_PLAN` and `TAB_PLAN` rows whose `ref_area` is `ALL`
#'      or `ref_area`.
#'   2. A cut applies to a series when every variable in its
#'      `comp_breakdowns` lists the indicator's `stat_unit` in
#'      `CL_BRK_VAR.applies_to_units`, none of those variables is the
#'      variable of the series' defining breakdown, the cut's `themes` is
#'      `ALL` or contains the indicator's `theme`, and the cut's `sex`/`age`
#'      are both `_T` or the indicator's `stat_unit` is `IND`.
#'   3. A cut's cells are the cross product of its `GEO`, `URBANISATION`,
#'      `SEX`, `AGE` and `comp_breakdowns` category domains.
#'   4. Cells that use a variable or category listed in the indicator's
#'      `excluded_breakdowns` are dropped.
#'   5. Each row carries the 18 key columns, with `SEX`/`AGE` becoming `_Z`
#'      in place of `_T` when the indicator's `stat_unit` is not `IND`,
#'      `COMP_BREAKDOWN_1..5` holding the cut's categories plus the defining
#'      breakdown (ordered by [slot_sort()], padded with `_T`), and
#'      `MEASURE_QUAL_1..5` holding the series' qualifiers (ordered by
#'      qualifier `slot_order`, padded with `_Z`).
#'   6. Rows carry `series_id` and `cut_id`, and are sorted by the key
#'      columns; the function stops if the key is not unique.
#'
#' @param meta A named list from [load_metadata()], holding at least
#'   `SERIES_PLAN`, `TAB_PLAN`, `CL_INDICATOR` (`code`, `stat_unit`,
#'   `theme`, `excluded_breakdowns`), `CL_BRK_VAR`, `CL_COMP_BREAKDOWN`,
#'   `CL_QUAL_VAR`, `CL_QUALIFIER` and `CL_GEO`.
#' @param ref_area A country code, e.g. `"SEN"`.
#' @param time_period A time period string, e.g. `"2021"`.
#' @return A data frame of the 18 `KEY_COLUMNS` plus `series_id` and
#'   `cut_id`, one row per required cell, sorted by the key columns.
required_rows <- function(meta, ref_area, time_period) {
  needed <- c(
    "SERIES_PLAN", "TAB_PLAN", "CL_INDICATOR", "CL_BRK_VAR",
    "CL_COMP_BREAKDOWN", "CL_QUAL_VAR", "CL_QUALIFIER", "CL_GEO"
  )
  missing <- setdiff(needed, names(meta))
  if (length(missing) > 0) {
    stop(
      "required_rows: meta is missing: ", paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  series_plan <- as.data.frame(meta$SERIES_PLAN, stringsAsFactors = FALSE)
  tab_plan <- as.data.frame(meta$TAB_PLAN, stringsAsFactors = FALSE)
  cl_indicator <- as.data.frame(meta$CL_INDICATOR, stringsAsFactors = FALSE)
  cl_brk_var <- as.data.frame(meta$CL_BRK_VAR, stringsAsFactors = FALSE)
  cl_comp_breakdown <- as.data.frame(meta$CL_COMP_BREAKDOWN, stringsAsFactors = FALSE)
  cl_qual_var <- as.data.frame(meta$CL_QUAL_VAR, stringsAsFactors = FALSE)
  cl_qualifier <- as.data.frame(meta$CL_QUALIFIER, stringsAsFactors = FALSE)
  cl_geo <- as.data.frame(meta$CL_GEO, stringsAsFactors = FALSE)

  series_plan <- series_plan[series_plan$ref_area %in% c("ALL", ref_area), , drop = FALSE]
  tab_plan <- tab_plan[tab_plan$ref_area %in% c("ALL", ref_area), , drop = FALSE]

  ind_stat_unit <- setNames(cl_indicator$stat_unit, cl_indicator$code)
  ind_theme <- setNames(cl_indicator$theme, cl_indicator$code)
  ind_excluded <- setNames(cl_indicator$excluded_breakdowns, cl_indicator$code)

  brk_applies_units <- setNames(
    lapply(cl_brk_var$applies_to_units, .plan_tokens),
    cl_brk_var$code
  )
  brk_slot_order_of <- setNames(cl_brk_var$slot_order, cl_brk_var$code)

  comp_var_of <- setNames(cl_comp_breakdown$var_code, cl_comp_breakdown$code)
  comp_cats_of_var <- split(cl_comp_breakdown$code, cl_comp_breakdown$var_code)

  qual_var_of <- setNames(cl_qualifier$var_code, cl_qualifier$code)
  qual_slot_order_of <- setNames(cl_qual_var$slot_order, cl_qual_var$code)

  geo_codes_of <- split(cl_geo$code, paste(cl_geo$ref_area, cl_geo$scheme))

  out_rows <- vector("list", 0)

  for (si in seq_len(nrow(series_plan))) {
    srow <- series_plan[si, ]
    series_id <- srow$series_id
    indicator <- srow$INDICATOR

    if (!(indicator %in% names(ind_stat_unit))) {
      stop(
        "required_rows: indicator not found in CL_INDICATOR: ", indicator,
        call. = FALSE
      )
    }
    stat_unit <- unname(ind_stat_unit[[indicator]])
    theme <- unname(ind_theme[[indicator]])
    excluded_tokens <- .plan_tokens(ind_excluded[[indicator]])

    qual_tokens <- .plan_tokens(srow$MEASURE_QUALS)
    if (length(qual_tokens) > 0) {
      qual_tokens <- slot_sort(qual_tokens, qual_var_of, qual_slot_order_of)
    }
    qual_slots <- fill_slots(qual_tokens, n = 5, pad = SENTINEL_NA)

    defining_brk <- srow$DEFINING_BREAKDOWN
    if (length(defining_brk) == 0 || is.na(defining_brk)) {
      defining_brk <- ""
    }
    defining_var <- NA_character_
    if (defining_brk != "") {
      if (!(defining_brk %in% names(comp_var_of))) {
        stop(
          "required_rows: defining breakdown not found in CL_COMP_BREAKDOWN: ",
          defining_brk, call. = FALSE
        )
      }
      defining_var <- unname(comp_var_of[[defining_brk]])
    }

    for (ti in seq_len(nrow(tab_plan))) {
      trow <- tab_plan[ti, ]
      cut_id <- trow$cut_id
      comp_vars <- .plan_tokens(trow$comp_breakdowns)

      ok <- TRUE
      for (v in comp_vars) {
        units <- brk_applies_units[[v]]
        if (is.null(units) || !(stat_unit %in% units)) {
          ok <- FALSE
          break
        }
      }
      if (ok && !is.na(defining_var) && defining_var %in% comp_vars) {
        ok <- FALSE
      }
      if (ok) {
        cut_themes <- trow$themes
        ok <- identical(cut_themes, "ALL") || (theme %in% .plan_tokens(cut_themes))
      }
      if (ok) {
        ok <- (identical(trow$sex, SENTINEL_TOTAL) && identical(trow$age, SENTINEL_TOTAL)) ||
          identical(stat_unit, "IND")
      }
      if (!ok) {
        next
      }

      if (identical(trow$geo_scheme, SENTINEL_TOTAL)) {
        geo_cells <- SENTINEL_TOTAL
      } else {
        geo_cells <- geo_codes_of[[paste(ref_area, trow$geo_scheme)]]
        if (is.null(geo_cells) || length(geo_cells) == 0) {
          stop(
            "required_rows: no CL_GEO codes for ref_area=", ref_area,
            " scheme=", trow$geo_scheme, call. = FALSE
          )
        }
      }

      urb_cells <- if (identical(trow$urbanisation, SENTINEL_TOTAL)) {
        SENTINEL_TOTAL
      } else {
        .plan_tokens(trow$urbanisation)
      }
      sex_cells <- if (identical(trow$sex, SENTINEL_TOTAL)) {
        SENTINEL_TOTAL
      } else {
        .plan_tokens(trow$sex)
      }
      age_cells <- if (identical(trow$age, SENTINEL_TOTAL)) {
        SENTINEL_TOTAL
      } else {
        .plan_tokens(trow$age)
      }

      if (!identical(stat_unit, "IND")) {
        sex_cells <- ifelse(sex_cells == SENTINEL_TOTAL, SENTINEL_NA, sex_cells)
        age_cells <- ifelse(age_cells == SENTINEL_TOTAL, SENTINEL_NA, age_cells)
      }

      comp_cat_lists <- lapply(comp_vars, function(v) {
        cats <- comp_cats_of_var[[v]]
        if (is.null(cats)) character(0) else cats
      })

      if (length(comp_cat_lists) == 0) {
        combos <- list(character(0))
      } else {
        grid <- expand.grid(comp_cat_lists, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
        combos <- lapply(
          seq_len(nrow(grid)),
          function(i) as.character(unlist(grid[i, , drop = FALSE]))
        )
      }

      for (combo in combos) {
        if (length(excluded_tokens) > 0 && length(combo) > 0) {
          combo_vars <- unname(comp_var_of[combo])
          if (any(combo %in% excluded_tokens) || any(combo_vars %in% excluded_tokens)) {
            next
          }
        }

        comp_all <- combo
        if (defining_brk != "") {
          comp_all <- c(comp_all, defining_brk)
        }
        if (length(comp_all) > 0) {
          comp_all <- slot_sort(comp_all, comp_var_of, brk_slot_order_of)
        }
        comp_slots <- fill_slots(comp_all, n = 5, pad = SENTINEL_TOTAL)

        for (geo in geo_cells) {
          for (urb in urb_cells) {
            for (sx in sex_cells) {
              for (ag in age_cells) {
                out_rows[[length(out_rows) + 1]] <- c(
                  DATAFLOW = DATAFLOW_ID,
                  REF_AREA = ref_area,
                  GEO = geo,
                  TIME_PERIOD = time_period,
                  INDICATOR = indicator,
                  SEX = sx,
                  AGE = ag,
                  URBANISATION = urb,
                  COMP_BREAKDOWN_1 = comp_slots[1],
                  COMP_BREAKDOWN_2 = comp_slots[2],
                  COMP_BREAKDOWN_3 = comp_slots[3],
                  COMP_BREAKDOWN_4 = comp_slots[4],
                  COMP_BREAKDOWN_5 = comp_slots[5],
                  MEASURE_QUAL_1 = qual_slots[1],
                  MEASURE_QUAL_2 = qual_slots[2],
                  MEASURE_QUAL_3 = qual_slots[3],
                  MEASURE_QUAL_4 = qual_slots[4],
                  MEASURE_QUAL_5 = qual_slots[5],
                  series_id = series_id,
                  cut_id = cut_id
                )
              }
            }
          }
        }
      }
    }
  }

  out_names <- c(KEY_COLUMNS, "series_id", "cut_id")

  if (length(out_rows) == 0) {
    out <- as.data.frame(
      matrix(character(0), nrow = 0, ncol = length(out_names)),
      stringsAsFactors = FALSE
    )
    names(out) <- out_names
    return(out)
  }

  out <- as.data.frame(do.call(rbind, out_rows), stringsAsFactors = FALSE)
  names(out) <- out_names
  rownames(out) <- NULL

  ord <- do.call(order, c(as.list(out[KEY_COLUMNS]), list(method = "radix")))
  out <- out[ord, , drop = FALSE]
  rownames(out) <- NULL

  key <- do.call(paste, c(as.list(out[KEY_COLUMNS]), list(sep = "")))
  if (any(duplicated(key))) {
    stop(
      "required_rows: duplicate key produced: ", key[duplicated(key)][1],
      call. = FALSE
    )
  }

  out
}
