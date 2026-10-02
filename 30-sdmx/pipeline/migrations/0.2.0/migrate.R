#!/usr/bin/env Rscript
# pipeline/migrations/0.2.0/migrate.R
#
# One-off migration of metadata/ from version 0.1.0 to 0.2.0 (standard v0.5,
# decisions D12-D26). Runs once: it refuses to run unless metadata/VERSION is
# 0.1.0. See README.md in this folder for what it changes.
#
# Usage: Rscript pipeline/migrations/0.2.0/migrate.R --root <dir> [--out-root <dir>]
#
# Reads the 0.1.0 files under <root> and writes the 0.2.0 files at the same
# relative paths under <out-root> (default: <root>, that is, in place). Only
# the files the migration creates or rewrites are written. Deterministic: the
# same inputs always give byte-identical outputs.

FROM_VERSION <- "0.1.0"
TO_VERSION <- "0.2.0"
DATAFLOW_ID <- "AFW360_HH"

# ---- locate and load the shared I/O helpers ---------------------------------

.script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0) {
    return(normalizePath(file.path("pipeline", "migrations", "0.2.0"), mustWork = FALSE))
  }
  dirname(normalizePath(sub("^--file=", "", file_arg[1]), mustWork = TRUE))
}

source(file.path(.script_dir(), "..", "..", "R", "io.R"))

args <- commandArgs(trailingOnly = TRUE)
root <- cli_arg(args, "--root", ".")
out_root <- cli_arg(args, "--out-root", root)

fail <- function(...) {
  message("migrate 0.2.0: ", ...)
  quit(save = "no", status = 1)
}

# ---- guard ------------------------------------------------------------------

version_path <- file.path(root, "metadata", "VERSION")
if (!file.exists(version_path)) {
  fail("no metadata/VERSION under ", root)
}
current_version <- trimws(paste(readLines(version_path, warn = FALSE), collapse = ""))
if (!identical(current_version, FROM_VERSION)) {
  fail(
    "metadata/VERSION is '", current_version, "', not ", FROM_VERSION,
    ". This migration runs once, on ", FROM_VERSION, " metadata only; nothing was written."
  )
}

# ---- read the 0.1.0 inputs --------------------------------------------------

mpath <- function(...) file.path(root, "metadata", ...)

cl_indicator <- read_std_csv(mpath("codelists", "CL_INDICATOR.csv"))
cl_qualifier <- read_std_csv(mpath("codelists", "CL_QUALIFIER.csv"))
cl_qual_var <- read_std_csv(mpath("codelists", "CL_QUAL_VAR.csv"))
cl_brk_var <- read_std_csv(mpath("codelists", "CL_BRK_VAR.csv"))
cl_comp_brk <- read_std_csv(mpath("codelists", "CL_COMP_BREAKDOWN.csv"))
cl_obs_status <- read_std_csv(mpath("codelists", "CL_OBS_STATUS.csv"))
cl_area <- read_std_csv(mpath("codelists", "CL_AREA.csv"))
series_plan <- read_std_csv(mpath("plans", "SERIES_PLAN.csv"))
surveys <- read_std_csv(mpath("surveys", "SURVEYS.csv"))
columns <- read_std_csv(mpath("structure", "COLUMNS.csv"))
changelog <- readLines(mpath("CHANGELOG.md"), encoding = "UTF-8", warn = FALSE)

checksums_path <- file.path(root, "data_raw", "CHECKSUMS.sha256")
if (!file.exists(checksums_path)) {
  fail("no data_raw/CHECKSUMS.sha256 under ", root)
}
checksum_lines <- readLines(checksums_path, warn = FALSE)
checksum_lines <- checksum_lines[nzchar(trimws(checksum_lines))]
checksums <- stats::setNames(
  sub("^([0-9a-f]{64})\\s+.*$", "\\1", checksum_lines),
  sub("^[0-9a-f]{64}\\s+(.*)$", "\\1", checksum_lines)
)

need_cols <- function(df, cols, what) {
  miss <- setdiff(cols, names(df))
  if (length(miss) > 0) fail(what, " lacks column(s): ", paste(miss, collapse = ", "))
}
need_cols(cl_indicator, c("code", "status", "short_name_en", "qualifiers", "checks"), "CL_INDICATOR.csv")
need_cols(cl_qualifier, c("code", "status", "var_code", "valid_with", "order"), "CL_QUALIFIER.csv")
need_cols(cl_qual_var, c("code", "slot_order", "requires"), "CL_QUAL_VAR.csv")
need_cols(series_plan, c("series_id", "ref_area", "INDICATOR", "MEASURE_QUALS",
                         "DEFINING_BREAKDOWN", "status", "notes"), "SERIES_PLAN.csv")

# Lookups.
qual_var_of <- stats::setNames(cl_qualifier$var_code, cl_qualifier$code)
qual_name_of <- stats::setNames(cl_qualifier$name_en, cl_qualifier$code)
qual_status_of <- stats::setNames(cl_qualifier$status, cl_qualifier$code)
qvar_slot_of <- stats::setNames(as.integer(cl_qual_var$slot_order), cl_qual_var$code)
qvar_requires_of <- stats::setNames(cl_qual_var$requires, cl_qual_var$code)
brk_var_of <- stats::setNames(cl_comp_brk$var_code, cl_comp_brk$code)
brk_name_of <- stats::setNames(cl_comp_brk$name_en, cl_comp_brk$code)
bvar_name_of <- stats::setNames(cl_brk_var$name_en, cl_brk_var$code)

# C-locale ordering, independent of the machine's locale.
c_order <- function(...) order(..., method = "radix")

split_ws <- function(x) {
  x <- trimws(x)
  if (!nzchar(x)) character(0) else strsplit(x, "[[:space:]]+")[[1]]
}

# ---- 2.1 CL_ESTIMATION.csv (new) ------------------------------------------------

cl_estimation <- data.frame(
  code = c("SURVEY", "MODEL"),
  name_en = c("Survey estimate", "Model-based estimate"),
  definition_en = c(
    "A direct estimate from the survey microdata of the reference year.",
    paste(
      "A model-based value for the reference year: a nowcast, projection or microsimulation",
      "built on an earlier survey or on scenario assumptions. Every filled row of a MODEL file",
      "carries OBS_STATUS E."
    )
  ),
  status = "DRAFT",
  version_added = TO_VERSION,
  replaced_by = "",
  notes = "",
  stringsAsFactors = FALSE
)

# ---- 2.2 CL_OBS_STATUS.csv (three rows appended) --------------------------------

new_obs <- data.frame(
  code = c("U", "D", "Q"),
  name_en = c("Low reliability", "Definition differs", "Suppressed"),
  definition_en = c(
    paste(
      "The value rests on fewer records than RELIABILITY_MIN_NOBS or its coefficient of",
      "variation exceeds RELIABILITY_MAX_CV (RULES.csv). Written by the producer and recomputed",
      "by the validator; the value is published, not hidden."
    ),
    paste(
      "The series is produced for this country under a definition that departs from the",
      "dictionary's; SERIES_PLAN.csv carries the country's row with status DEVIATES and the reason."
    ),
    paste(
      "Reserved: a value withheld under a confidentiality rule. Not used; the database",
      "publishes every estimate."
    )
  ),
  status = "DRAFT",
  version_added = TO_VERSION,
  replaced_by = "",
  notes = "",
  stringsAsFactors = FALSE
)
if (any(new_obs$code %in% cl_obs_status$code)) {
  fail("CL_OBS_STATUS.csv already has one of U, D, Q")
}
new_obs <- new_obs[names(cl_obs_status)]
cl_obs_status_new <- rbind(as.data.frame(cl_obs_status, stringsAsFactors = FALSE), new_obs)

# ---- 2.3 RULES.csv (new, from CL_INDICATOR.checks) -------------------------------

RULE_VOCAB <- c(
  "RANGE_0_1", "RANGE_NONNEG", "AGG_SUM", "AGG_NPOP_MEAN", "AGG_BRACKET",
  "SUM_TO_1_OVER", "SUM_TO_1_OVER_BRK", "MONOTONE_IN",
  "RELIABILITY_MIN_NOBS", "RELIABILITY_MAX_CV"
)
PARAM_RULES <- c("SUM_TO_1_OVER", "MONOTONE_IN")
RETIRED_TOKENS <- c("NONE", "EQUALS_NPOP_RATIO")

rule_rows <- list()
for (i in seq_len(nrow(cl_indicator))) {
  ind <- cl_indicator$code[i]
  for (tok in split_ws(cl_indicator$checks[i])) {
    if (tok %in% RETIRED_TOKENS) next
    if (grepl(":", tok, fixed = TRUE)) {
      parts <- strsplit(tok, ":", fixed = TRUE)[[1]]
      if (length(parts) != 2 || !nzchar(parts[2])) {
        fail("CL_INDICATOR ", ind, ": malformed checks token '", tok, "'")
      }
      rule <- parts[1]
      param <- parts[2]
      if (!(rule %in% PARAM_RULES)) {
        fail("CL_INDICATOR ", ind, ": checks token '", tok, "' has a parameter on a rule that takes none")
      }
      if (!(param %in% cl_qual_var$code)) {
        fail("CL_INDICATOR ", ind, ": checks token '", tok, "' names an unknown qualifier variable")
      }
    } else {
      rule <- tok
      param <- ""
      if (rule %in% PARAM_RULES) {
        fail("CL_INDICATOR ", ind, ": checks token '", tok, "' lacks its qualifier-variable parameter")
      }
    }
    if (!(rule %in% RULE_VOCAB) || grepl("^RELIABILITY_", rule)) {
      fail("CL_INDICATOR ", ind, ": unexpected checks token '", tok, "'")
    }
    rule_rows[[length(rule_rows) + 1]] <- data.frame(
      rule_id = paste0(ind, ".", rule, if (nzchar(param)) paste0(".", param) else ""),
      scope = "INDICATOR",
      scope_code = ind,
      rule = rule,
      param = param,
      tolerance = "",
      severity = "ERROR",
      status = cl_indicator$status[i],
      version_added = TO_VERSION,
      notes = "",
      stringsAsFactors = FALSE
    )
  }
}
indicator_rules <- do.call(rbind, rule_rows)
if (anyDuplicated(indicator_rules$rule_id)) {
  fail("CL_INDICATOR.checks repeats a token within one indicator")
}
indicator_rules <- indicator_rules[
  c_order(indicator_rules$scope_code, indicator_rules$rule, indicator_rules$param), ,
  drop = FALSE
]

dataflow_rules <- data.frame(
  rule_id = paste0(DATAFLOW_ID, ".", c("RELIABILITY_MIN_NOBS", "RELIABILITY_MAX_CV")),
  scope = "DATAFLOW",
  scope_code = "",
  rule = c("RELIABILITY_MIN_NOBS", "RELIABILITY_MAX_CV"),
  param = c("30", "0.3"),
  tolerance = "",
  severity = "ERROR",
  status = "DRAFT",
  version_added = TO_VERSION,
  notes = c(
    "Minimum N_OBS below which a row is OBS_STATUS U (D22).",
    "Maximum coefficient of variation STD_ERR / |OBS_VALUE| above which a row is OBS_STATUS U (D22)."
  ),
  stringsAsFactors = FALSE
)

rules <- rbind(dataflow_rules, indicator_rules)
rownames(rules) <- NULL

# ---- 2.4 INDICATOR_QUALIFIERS.csv (new, from CL_INDICATOR.qualifiers) ------------

iq_rows <- list()
for (i in seq_len(nrow(cl_indicator))) {
  ind <- cl_indicator$code[i]
  field <- trimws(cl_indicator$qualifiers[i])
  if (identical(field, "_Z")) next
  if (!nzchar(field)) {
    fail("CL_INDICATOR ", ind, ": qualifiers is empty (0.1.0 writes _Z for none)")
  }
  seen <- character(0)
  for (grp in split_ws(field)) {
    if (!grepl("^[A-Z][A-Z0-9_]*:(\\*|[A-Z][A-Z0-9_]*(,[A-Z][A-Z0-9_]*)*)$", grp)) {
      fail("CL_INDICATOR ", ind, ": qualifiers group '", grp, "' is not VAR:cat1,cat2,... or VAR:*")
    }
    var <- sub(":.*$", "", grp)
    cats_txt <- sub("^[^:]*:", "", grp)
    if (!(var %in% cl_qual_var$code)) {
      fail("CL_INDICATOR ", ind, ": unknown qualifier variable '", var, "'")
    }
    if (var %in% seen) {
      fail("CL_INDICATOR ", ind, ": qualifier variable '", var, "' appears twice")
    }
    seen <- c(seen, var)
    if (identical(cats_txt, "*")) {
      allowed <- "*"
    } else {
      cats <- strsplit(cats_txt, ",", fixed = TRUE)[[1]]
      bad <- cats[!(cats %in% cl_qualifier$code) | qual_var_of[cats] != var]
      if (length(bad) > 0) {
        fail("CL_INDICATOR ", ind, ": '", paste(bad, collapse = ", "),
             "' is not a CL_QUALIFIER category of ", var)
      }
      allowed <- paste(cats, collapse = " ")
    }
    iq_rows[[length(iq_rows) + 1]] <- data.frame(
      indicator = ind,
      qual_var = var,
      allowed = allowed,
      status = cl_indicator$status[i],
      version_added = TO_VERSION,
      notes = "",
      stringsAsFactors = FALSE
    )
  }
}
indicator_qualifiers <- do.call(rbind, iq_rows)
indicator_qualifiers <- indicator_qualifiers[
  c_order(indicator_qualifiers$indicator,
          qvar_slot_of[indicator_qualifiers$qual_var],
          indicator_qualifiers$qual_var), ,
  drop = FALSE
]
rownames(indicator_qualifiers) <- NULL

# ---- 2.5 QUALIFIER_PAIRS.csv (new, from CL_QUALIFIER.valid_with) -----------------

qp_rows <- list()
for (i in seq_len(nrow(cl_qualifier))) {
  code <- cl_qualifier$code[i]
  vw <- trimws(cl_qualifier$valid_with[i])
  if (!nzchar(vw)) next
  if (identical(vw, "_Z")) {
    with_var <- qvar_requires_of[[cl_qualifier$var_code[i]]]
    if (!nzchar(with_var) || grepl("[[:space:]]", with_var)) {
      fail("CL_QUALIFIER ", code, ": valid_with is _Z but its variable's requires is '",
           with_var, "' (need exactly one qualifier variable)")
    }
    allowed <- "_Z"
  } else if (vw %in% cl_qualifier$code) {
    with_var <- qual_var_of[[vw]]
    allowed <- vw
  } else {
    fail("CL_QUALIFIER ", code, ": valid_with '", vw, "' is neither a CL_QUALIFIER code nor _Z")
  }
  qp_rows[[length(qp_rows) + 1]] <- data.frame(
    qualifier = code,
    with_var = with_var,
    allowed = allowed,
    status = cl_qualifier$status[i],
    version_added = TO_VERSION,
    notes = "",
    stringsAsFactors = FALSE
  )
}
qualifier_pairs <- do.call(rbind, qp_rows)
qualifier_pairs <- qualifier_pairs[
  c_order(qvar_slot_of[qual_var_of[qualifier_pairs$qualifier]],
          as.integer(cl_qualifier$order[match(qualifier_pairs$qualifier, cl_qualifier$code)]),
          qualifier_pairs$qualifier,
          qualifier_pairs$with_var), ,
  drop = FALSE
]
rownames(qualifier_pairs) <- NULL

# ---- 2.6 SOURCES.csv (new) --------------------------------------------------------

source_rows <- list()
for (i in seq_len(nrow(cl_area))) {
  iso3 <- cl_area$code[i]
  input <- paste0("data_raw/tables/Tables_", iso3, ".xlsx")
  if (!(input %in% names(checksums))) {
    fail("data_raw/CHECKSUMS.sha256 has no line for ", input)
  }
  srv <- surveys[surveys$ref_area == iso3, , drop = FALSE]
  if (nrow(srv) != 1) {
    fail("SURVEYS.csv has ", nrow(srv), " rows for ", iso3, "; expected exactly one")
  }
  survey_id <- srv$survey_id
  source_rows[[length(source_rows) + 1]] <- data.frame(
    source_id = paste0(iso3, "_", srv$survey_acronym, srv$time_period, "_LEGACY_v1"),
    kind = "LEGACY_CONVERSION",
    ref_area = iso3,
    survey_id = survey_id,
    program = "pipeline/convert_legacy.R",
    program_version = TO_VERSION,
    producer = "AFW DIP/POV team",
    software = "R 4.5.3",
    run_date = "2026-01-01",
    inputs = input,
    inputs_sha256 = checksums[[input]],
    status = "DRAFT",
    version_added = TO_VERSION,
    notes = paste0(
      "Legacy conversion of the ", cl_area$name_en[i],
      " workbook; values rounded to two decimals, no sample sizes."
    ),
    stringsAsFactors = FALSE
  )
}
sources <- do.call(rbind, source_rows)

# ---- 2.7 SERIES_PLAN.csv (name_en and estimation added) --------------------------

SEP <- " · "
ind_short_of <- stats::setNames(cl_indicator$short_name_en, cl_indicator$code)

compose_name <- function(indicator, quals, defining) {
  if (!(indicator %in% names(ind_short_of)) || !nzchar(ind_short_of[[indicator]])) {
    fail("SERIES_PLAN: indicator '", indicator, "' has no short_name_en")
  }
  parts <- ind_short_of[[indicator]]
  q <- split_ws(quals)
  if (length(q) > 0) {
    unknown <- q[!(q %in% names(qual_var_of))]
    if (length(unknown) > 0) fail("SERIES_PLAN: unknown qualifier(s) ", paste(unknown, collapse = ", "))
    q <- q[c_order(qvar_slot_of[qual_var_of[q]], qual_var_of[q])]
    parts <- c(parts, unname(qual_name_of[q]))
  }
  d <- trimws(defining)
  if (nzchar(d)) {
    if (!(d %in% names(brk_var_of))) fail("SERIES_PLAN: unknown defining category ", d)
    parts <- c(parts, paste0(bvar_name_of[[brk_var_of[[d]]]], " = ", brk_name_of[[d]]))
  }
  paste(parts, collapse = SEP)
}

series_plan_new <- as.data.frame(series_plan, stringsAsFactors = FALSE)
series_plan_new$name_en <- vapply(
  seq_len(nrow(series_plan_new)),
  function(i) compose_name(series_plan_new$INDICATOR[i],
                           series_plan_new$MEASURE_QUALS[i],
                           series_plan_new$DEFINING_BREAKDOWN[i]),
  character(1)
)
series_plan_new$estimation <- "SURVEY"
series_plan_new <- series_plan_new[c(
  "series_id", "ref_area", "INDICATOR", "MEASURE_QUALS", "DEFINING_BREAKDOWN",
  "name_en", "estimation", "status", "notes"
)]

# ---- 2.8 columns removed -------------------------------------------------------

cl_indicator_new <- as.data.frame(cl_indicator, stringsAsFactors = FALSE)
cl_indicator_new <- cl_indicator_new[setdiff(names(cl_indicator_new), c("qualifiers", "checks"))]
cl_qualifier_new <- as.data.frame(cl_qualifier, stringsAsFactors = FALSE)
cl_qualifier_new <- cl_qualifier_new[setdiff(names(cl_qualifier_new), "valid_with")]

# ---- 2.10 DSD_AFW360_HH.csv ------------------------------------------------------

dsd_row <- function(id, role, codelist, required, sentinel, description) {
  data.frame(id = id, role = role, codelist = codelist, required = required,
             sentinel = sentinel, description = description, stringsAsFactors = FALSE)
}
slot_rows <- function(prefix, role, codelist, sentinel) {
  do.call(rbind, lapply(1:5, function(n) {
    dsd_row(paste0(prefix, n), role, codelist, "R", sentinel,
            paste0("slot ", n, " of 5, filled left to right in slot_order."))
  }))
}
dsd <- rbind(
  dsd_row("DATAFLOW", "constant", "", "R", "", "Constant AFW360_HH."),
  dsd_row("REF_AREA", "breakdown", "CL_AREA", "R", "", "CL_AREA (ISO 3166-1 alpha-3)."),
  dsd_row("GEO", "breakdown", "CL_GEO", "R", "_T", "CL_GEO, or _T for the whole country."),
  dsd_row("TIME_PERIOD", "reference", "", "R", "", "4-digit year the estimate refers to."),
  dsd_row("ESTIMATION", "reference", "CL_ESTIMATION", "R", "",
          "How the value was produced: SURVEY or MODEL (D17)."),
  dsd_row("INDICATOR", "qualifier", "CL_INDICATOR", "R", "", "CL_INDICATOR."),
  dsd_row("SEX", "breakdown", "CL_SEX", "R", "_T _Z", "CL_SEX, _T, or _Z."),
  dsd_row("AGE", "breakdown", "CL_AGE", "R", "_T _Z", "CL_AGE, _T, or _Z."),
  dsd_row("URBANISATION", "breakdown", "CL_URBANISATION", "R", "_T", "CL_URBANISATION or _T."),
  slot_rows("COMP_BREAKDOWN_", "breakdown", "CL_COMP_BREAKDOWN", "_T"),
  slot_rows("MEASURE_QUAL_", "qualifier", "CL_QUALIFIER", "_Z"),
  dsd_row("SERIES_ID", "attribute", "SERIES_PLAN", "R", "",
          "SERIES_PLAN.series_id; agrees with INDICATOR, qualifiers and defining category (D13)."),
  dsd_row("OBS_VALUE", "measure", "", "C", "",
          "Number, unrounded, base units; required unless OBS_STATUS is O or M."),
  dsd_row("UNIT_MEASURE", "attribute", "CL_UNIT", "R", "",
          paste("CL_UNIT code, or an ISO 4217 code from CL_AREA.currency where the indicator's",
                "unit_measure is LCU (D14).")),
  dsd_row("PRECISION", "attribute", "", "C", "",
          paste("Rounding unit of OBS_VALUE in base units; empty when exact; required on rows of a",
                "LEGACY_CONVERSION source (D15).")),
  dsd_row("OBS_STATUS", "attribute", "CL_OBS_STATUS", "R", "",
          "CL_OBS_STATUS; one code per row, precedence M O E D U A (D22)."),
  dsd_row("STD_ERR", "attribute", "", "C", "",
          "Number >= 0; required on PRODUCER-source rows where CL_STATISTIC.admits_se = Y."),
  dsd_row("CI_LOWER", "attribute", "", "C", "", "Number, 95%; required where STD_ERR is."),
  dsd_row("CI_UPPER", "attribute", "", "C", "", "Number, 95%; required where STD_ERR is."),
  dsd_row("N_OBS", "attribute", "", "C", "",
          paste("Integer >= 0; required on PRODUCER-source rows; on a share row, the denominator's",
                "records (D19).")),
  dsd_row("N_POP", "attribute", "", "C", "",
          paste("Number >= 0; required on PRODUCER-source rows; on a share row, the denominator's",
                "population (D19).")),
  dsd_row("SOURCE_ID", "attribute", "SOURCES", "R", "",
          "SOURCES.source_id, the program run that produced the row (D16)."),
  dsd_row("OBS_COMMENT", "attribute", "", "O", "",
          paste("Free text, English; LEGACY_EMPTY: prefix required on O rows of a LEGACY_CONVERSION",
                "source (D9)."))
)
dsd <- cbind(position = as.character(seq_len(nrow(dsd))), dsd, stringsAsFactors = FALSE)
if (nrow(dsd) != 31) fail("internal: DSD has ", nrow(dsd), " rows, expected 31")

# ---- 2.9 COLUMNS.csv -------------------------------------------------------------

columns_new <- as.data.frame(columns, stringsAsFactors = FALSE)

drop_column <- function(cols, file, column) {
  hit <- cols$file == file & cols$column == column
  if (sum(hit) != 1) fail("COLUMNS.csv: expected one row for ", file, " / ", column)
  cols[!hit, , drop = FALSE]
}
columns_new <- drop_column(columns_new, "CL_INDICATOR.csv", "qualifiers")
columns_new <- drop_column(columns_new, "CL_INDICATOR.csv", "checks")
columns_new <- drop_column(columns_new, "CL_QUALIFIER.csv", "valid_with")

set_desc <- function(cols, file, column, description) {
  hit <- cols$file == file & cols$column == column
  if (sum(hit) != 1) fail("COLUMNS.csv: expected one row for ", file, " / ", column)
  cols$description[hit] <- description
  cols
}
columns_new <- set_desc(columns_new, "DSD_AFW360_HH.csv", "position", "1-31, the data file's column order.")
columns_new <- set_desc(
  columns_new, "SERIES_PLAN.csv", "status",
  paste("DRAFT, ACTIVE, NOT_PRODUCED or DEVIATES; the last two only on a row for a specific",
        "ref_area, with notes, overriding the ALL row for the same series_id.")
)

# SERIES_PLAN: insert name_en and estimation before status.
sp_block <- columns_new[columns_new$file == "SERIES_PLAN.csv", , drop = FALSE]
sp_extra <- data.frame(
  file = "SERIES_PLAN.csv",
  position = "",
  column = c("name_en", "estimation"),
  status = "R",
  description = c(
    paste("Display name of the series for charts and reports, composed from the indicator's",
          "short_name_en and the qualifier and category names; a human may overwrite it."),
    paste("File kinds in which the series is expected: SURVEY, MODEL, or both, space-separated",
          "(CL_ESTIMATION).")
  ),
  stringsAsFactors = FALSE
)
at <- which(sp_block$column == "status")
sp_block <- rbind(sp_block[seq_len(at - 1), , drop = FALSE], sp_extra,
                  sp_block[at:nrow(sp_block), , drop = FALSE])

codelist_common <- columns_new[columns_new$file == "CL_OBS_STATUS.csv", , drop = FALSE][1:7, ]
if (!identical(codelist_common$column,
               c("code", "name_en", "definition_en", "status", "version_added", "replaced_by", "notes"))) {
  fail("COLUMNS.csv: CL_OBS_STATUS.csv does not start with the seven common codelist columns")
}
cl_estimation_block <- codelist_common
cl_estimation_block$file <- "CL_ESTIMATION.csv"

block <- function(file, spec) {
  data.frame(file = file, position = "", column = spec[, 1], status = spec[, 2],
             description = spec[, 3], stringsAsFactors = FALSE)
}
rules_block <- block("RULES.csv", rbind(
  c("rule_id", "R", "Unique id of the rule: <scope_code or AFW360_HH>.<rule>[.<param>], e.g. POV_HC.MONOTONE_IN.POVLINE."),
  c("scope", "R", "What the rule applies to: DATAFLOW (every row), INDICATOR (every series of one indicator) or SERIES (one series)."),
  c("scope_code", "C", "The indicator code or series_id the rule applies to; empty when scope is DATAFLOW."),
  c("rule", "R", "The rule from the vocabulary: RANGE_0_1, RANGE_NONNEG, AGG_SUM, AGG_NPOP_MEAN, AGG_BRACKET, SUM_TO_1_OVER, SUM_TO_1_OVER_BRK, MONOTONE_IN, RELIABILITY_MIN_NOBS or RELIABILITY_MAX_CV."),
  c("param", "C", "The rule's argument: the qualifier variable for SUM_TO_1_OVER and MONOTONE_IN, the threshold for the two RELIABILITY rules; empty otherwise."),
  c("tolerance", "O", "Absolute tolerance that overrides the validator's default, computed from each row's PRECISION; empty to use the default."),
  c("severity", "R", "ERROR (the file fails validation) or WARN (reported only)."),
  c("status", "R", "DRAFT, ACTIVE or DEPRECATED."),
  c("version_added", "R", "metadata/VERSION value at which the row was added."),
  c("notes", "O", "Free text.")
))
iq_block <- block("INDICATOR_QUALIFIERS.csv", rbind(
  c("indicator", "R", "CL_INDICATOR code of the indicator that takes the qualifier variable."),
  c("qual_var", "R", "CL_QUAL_VAR code of the qualifier variable the indicator takes; one row per indicator and variable."),
  c("allowed", "R", "* for any category of the variable, or the space-separated CL_QUALIFIER categories the indicator may use."),
  c("status", "R", "DRAFT, ACTIVE or DEPRECATED."),
  c("version_added", "R", "metadata/VERSION value at which the row was added."),
  c("notes", "O", "Free text.")
))
qp_block <- block("QUALIFIER_PAIRS.csv", rbind(
  c("qualifier", "R", "CL_QUALIFIER category whose partners are restricted, e.g. POVLINE_PL300."),
  c("with_var", "R", "CL_QUAL_VAR code of the partner qualifier variable, e.g. PPP."),
  c("allowed", "R", "Space-separated categories of with_var that may appear with the qualifier, or _Z when it takes none, which overrides with_var being required."),
  c("status", "R", "DRAFT, ACTIVE or DEPRECATED."),
  c("version_added", "R", "metadata/VERSION value at which the row was added."),
  c("notes", "O", "Free text.")
))
sources_block <- block("SOURCES.csv", rbind(
  c("source_id", "R", "Unique id of the program run, following the code rules, e.g. SEN_EHCVM2021_LEGACY_v1; a new run gets a higher _v<N>."),
  c("kind", "R", "LEGACY_CONVERSION for a converter run over a legacy workbook, PRODUCER for a producer's own estimation program."),
  c("ref_area", "R", "CL_AREA code of the country whose rows the run produced."),
  c("survey_id", "R", "SURVEYS.survey_id of the survey the run is based on, also for a model-based run."),
  c("program", "R", "The program that produced the rows: a repository path or the producer's program name."),
  c("program_version", "R", "Git commit or release of the program at the run."),
  c("producer", "R", "Team or agency that ran the program."),
  c("software", "R", "Software and version the program ran on, e.g. R 4.5.3 or Stata 18."),
  c("run_date", "R", "ISO 8601 date the program ran."),
  c("inputs", "R", "Space-separated files or datasets the run read."),
  c("inputs_sha256", "C", "Space-separated SHA-256 checksums of the inputs, in the same order, where they are files in this repository."),
  c("status", "R", "DRAFT, ACTIVE or DEPRECATED."),
  c("version_added", "R", "metadata/VERSION value at which the row was added."),
  c("notes", "O", "Free text.")
))

insert_after_file <- function(cols, anchor, new_block) {
  idx <- which(cols$file == anchor)
  if (length(idx) == 0) fail("COLUMNS.csv: no rows for ", anchor)
  last <- max(idx)
  rbind(cols[seq_len(last), , drop = FALSE], new_block,
        cols[seq.int(last + 1, length.out = nrow(cols) - last), , drop = FALSE])
}
replace_file_block <- function(cols, file, new_block) {
  idx <- which(cols$file == file)
  if (length(idx) == 0 || !identical(idx, seq.int(min(idx), max(idx)))) {
    fail("COLUMNS.csv: rows for ", file, " are missing or not contiguous")
  }
  rbind(cols[seq_len(min(idx) - 1), , drop = FALSE], new_block,
        cols[seq.int(max(idx) + 1, length.out = nrow(cols) - max(idx)), , drop = FALSE])
}

new_files <- c("CL_ESTIMATION.csv", "RULES.csv", "INDICATOR_QUALIFIERS.csv",
               "QUALIFIER_PAIRS.csv", "SOURCES.csv")
if (any(new_files %in% columns_new$file)) {
  fail("COLUMNS.csv already registers one of ", paste(new_files, collapse = ", "))
}
columns_new <- replace_file_block(columns_new, "SERIES_PLAN.csv", sp_block)
columns_new <- insert_after_file(columns_new, "CL_OBS_STATUS.csv", cl_estimation_block)
columns_new <- insert_after_file(columns_new, "CL_INDICATOR.csv", rbind(rules_block, iq_block, qp_block))
columns_new <- insert_after_file(columns_new, "SURVEYS.csv", sources_block)

# Renumber positions within each file, keeping row order.
for (f in unique(columns_new$file)) {
  hit <- columns_new$file == f
  columns_new$position[hit] <- as.character(seq_len(sum(hit)))
}
rownames(columns_new) <- NULL

# ---- 2.11 VERSION and CHANGELOG --------------------------------------------------

changelog_entry <- c(
  "## 0.2.0 (unreleased)",
  "",
  "Data standard v0.5; migrated from 0.1.0 by `pipeline/migrations/0.2.0/migrate.R`.",
  "",
  "- D12: structural changes are made by a one-off script under `pipeline/migrations/<version>/`; this is the first.",
  "- D13: `SERIES_ID` added to the data file; `SERIES_PLAN.csv` gains `name_en`, the display name.",
  "- D14: `UNIT_MEASURE` added to every data row, with `LCU` resolved to the country's ISO 4217 currency.",
  "- D15: `PRECISION` added to every data row; the manifest's `precision` key is removed.",
  "- D16: `SOURCE_ID` added to every data row; new `registries/SOURCES.csv`; manifest `source_type` replaced by `sources`.",
  "- D17: `ESTIMATION` added as a key dimension; new `CL_ESTIMATION.csv`; `SERIES_PLAN.csv` gains `estimation`.",
  "- D18: `CL_INDICATOR.checks`, `CL_INDICATOR.qualifiers` and `CL_QUALIFIER.valid_with` become `rules/RULES.csv`, `structure/INDICATOR_QUALIFIERS.csv` and `structure/QUALIFIER_PAIRS.csv`; the three columns are removed.",
  "- D19: on a share row `N_OBS` and `N_POP` are the denominator; `EQUALS_NPOP_RATIO` is retired.",
  "- D20: tables listing metadata contents are generated by `pipeline/build_docs.R` into `.docs/generated/`.",
  "- D21: `_U`, `_O` and `_X` reserved as sentinels; no code may start with `_`.",
  "- D22: `CL_OBS_STATUS` gains `U`, `D` and `Q` (reserved); `U` is set by the two `RELIABILITY_*` rules in `RULES.csv`.",
  "- D23: `SERIES_PLAN.csv` country rows may carry `NOT_PRODUCED` or `DEVIATES`, overriding the `ALL` row.",
  "- D24: version 0.x is pre-release; structural changes are minor bumps batched per release.",
  "- D25: `slot_order` is immutable once a breakdown or qualifier variable is `ACTIVE`.",
  "- D26: the data file has 31 columns and a 19-column key (`DSD_AFW360_HH.csv` rewritten).",
  ""
)
first_section <- grep("^## ", changelog)[1]
if (is.na(first_section)) fail("CHANGELOG.md has no '## ' section")
if (any(grepl("^## 0\\.2\\.0", changelog))) fail("CHANGELOG.md already has a 0.2.0 entry")
changelog_new <- c(changelog[seq_len(first_section - 1)], changelog_entry,
                   changelog[first_section:length(changelog)])

# ---- write -------------------------------------------------------------------------

opath <- function(...) file.path(out_root, "metadata", ...)

outputs <- list(
  list(file.path("codelists", "CL_ESTIMATION.csv"), cl_estimation),
  list(file.path("codelists", "CL_OBS_STATUS.csv"), cl_obs_status_new),
  list(file.path("codelists", "CL_INDICATOR.csv"), cl_indicator_new),
  list(file.path("codelists", "CL_QUALIFIER.csv"), cl_qualifier_new),
  list(file.path("rules", "RULES.csv"), rules),
  list(file.path("structure", "INDICATOR_QUALIFIERS.csv"), indicator_qualifiers),
  list(file.path("structure", "QUALIFIER_PAIRS.csv"), qualifier_pairs),
  list(file.path("structure", "DSD_AFW360_HH.csv"), dsd),
  list(file.path("structure", "COLUMNS.csv"), columns_new),
  list(file.path("registries", "SOURCES.csv"), sources),
  list(file.path("plans", "SERIES_PLAN.csv"), series_plan_new)
)

# Check every output's header against the new COLUMNS.csv before writing anything.
for (o in outputs) {
  fname <- basename(o[[1]])
  expected <- columns_new$column[columns_new$file == fname]
  if (!identical(names(o[[2]]), expected)) {
    fail("internal: header of ", fname, " does not match COLUMNS.csv")
  }
}

write_text_lf <- function(lines, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n"))), con)
}

for (o in outputs) {
  write_std_csv(o[[2]], opath(o[[1]]))
}
write_text_lf(changelog_new, opath("CHANGELOG.md"))
write_text_lf(TO_VERSION, opath("VERSION"))

message(
  "migrate 0.2.0: wrote ", length(outputs) + 2, " files under ",
  file.path(out_root, "metadata"), " (", nrow(rules), " rules, ",
  nrow(indicator_qualifiers), " indicator qualifiers, ", nrow(qualifier_pairs),
  " qualifier pairs, ", nrow(sources), " sources)."
)
