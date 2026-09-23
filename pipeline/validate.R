#!/usr/bin/env Rscript
# pipeline/validate.R
#
# WP11: the AFW360 validator's entry point. Sources io.R, constants.R,
# codes.R, ctx.R, plan.R and every pipeline/R/validate_*.R module present
# (STRUCT/CODES/META from WP11, plus WP12/13/14's modules once they exist),
# builds the shared ctx (build_ctx()), discovers every vc_* check function
# and runs them in alphabetical order, writes one findings CSV, and exits
# 0 (no ERROR), 1 (at least one ERROR) or 2 (a check crashed).
#
# Usage:
#   Rscript pipeline/validate.R --root . [--metadata-only] [--data <file> ...] --out <findings.csv>
#
# --root defaults to "."; --data may repeat and is interpreted relative to
# --root. Without --data (and without --metadata-only) every
# data/AFW360_HH_*.csv that is not a manifest is validated.

args <- commandArgs(trailingOnly = TRUE)

.cli_root <- function(args, default = ".") {
  idx <- which(args == "--root")
  if (length(idx) == 0 || idx[1] == length(args)) return(default)
  args[idx[1] + 1]
}

root <- .cli_root(args, ".")

source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "codes.R"))
source(file.path(root, "pipeline", "R", "ctx.R"))
source(file.path(root, "pipeline", "R", "plan.R"))

module_files <- sort(Sys.glob(file.path(root, "pipeline", "R", "validate_*.R")))
for (f in module_files) source(f)

metadata_only <- cli_flag(args, "--metadata-only")
data_arg <- cli_args(args, "--data")
out_path <- cli_arg(args, "--out")
if (is.null(out_path)) stop("validate.R: --out <findings.csv> is required")

if (metadata_only) {
  data_files_rel <- character(0)
} else if (length(data_arg) > 0) {
  data_files_rel <- gsub("\\\\", "/", data_arg)
} else {
  data_dir <- file.path(root, "data")
  if (dir.exists(data_dir)) {
    fs <- list.files(data_dir, pattern = "^AFW360_HH_.*\\.csv$", full.names = FALSE)
    fs <- fs[!grepl("_manifest\\.csv$", fs)]
    data_files_rel <- paste0("data/", fs)
  } else {
    data_files_rel <- character(0)
  }
}
data_files_abs <- if (length(data_files_rel) == 0) character(0) else file.path(root, data_files_rel)

ctx <- build_ctx(root, data_files = data_files_abs, opts = list())

check_names <- sort(ls(pattern = "^vc_", envir = .GlobalEnv))

all_findings <- list()
crashed <- FALSE

for (fn_name in check_names) {
  fn <- get(fn_name, envir = .GlobalEnv)
  res <- tryCatch(fn(ctx), error = function(e) e)
  if (inherits(res, "error")) {
    crashed <- TRUE
    module <- toupper(strsplit(sub("^vc_", "", fn_name), "_")[[1]][1])
    all_findings[[length(all_findings) + 1]] <- tibble::tibble(
      check_id = paste0(module, ".CRASH"),
      severity = "ERROR",
      file = "",
      row_key = "",
      message = paste0(fn_name, ": ", conditionMessage(res))
    )
  } else {
    all_findings[[length(all_findings) + 1]] <- res
  }
}

empty_findings <- tibble::tibble(
  check_id = character(0), severity = character(0),
  file = character(0), row_key = character(0), message = character(0)
)
findings <- if (length(all_findings) == 0) empty_findings else dplyr::bind_rows(all_findings)

# The cap: when one check has more than 20 findings for one file, keep the
# first 20 in row_key order, and add one SUMMARY finding.
#
# A group may arrive here already capped by the module that produced it. The
# modules are sourced into one environment, so a module whose file sorts later
# can replace a same-named private binder that an earlier module's checks call,
# and those checks then cap before returning. Capping such a group a second
# time would add another SUMMARY row for the same check_id and file and drop a
# real row: the SUMMARY's empty row_key sorts first, so it survives the re-cap
# and displaces the twentieth finding. A group that already carries a SUMMARY
# row is therefore left exactly as it stands. Its message holds the true total,
# which cannot be recovered here, since the rows behind it are already gone.
.has_summary_row <- function(sub) {
  any(!is.na(sub$message) & grepl("^SUMMARY: ", sub$message))
}
if (nrow(findings) > 0) {
  findings <- findings[order(findings$check_id, findings$file, findings$row_key), ]
  groups <- split(seq_len(nrow(findings)), list(findings$check_id, findings$file), drop = TRUE)
  capped <- list()
  for (g in groups) {
    sub <- findings[g, , drop = FALSE]
    sub <- sub[order(sub$row_key), ]
    if (.has_summary_row(sub)) {
      capped[[length(capped) + 1]] <- sub
    } else if (nrow(sub) > 20) {
      capped[[length(capped) + 1]] <- sub[seq_len(20), ]
      capped[[length(capped) + 1]] <- tibble::tibble(
        check_id = sub$check_id[1], severity = sub$severity[1], file = sub$file[1],
        row_key = "", message = paste0("SUMMARY: ", nrow(sub), " findings in total, 20 shown")
      )
    } else {
      capped[[length(capped) + 1]] <- sub
    }
  }
  findings <- dplyr::bind_rows(capped)
}

findings <- findings[order(findings$check_id, findings$file, findings$row_key), ]

write_std_csv(findings, out_path)

for (sev in c("ERROR", "WARN", "INFO")) {
  cat(sev, ": ", sum(findings$severity == sev), "\n", sep = "")
}

if (crashed) {
  quit(save = "no", status = 2)
} else if (any(findings$severity == "ERROR")) {
  quit(save = "no", status = 1)
} else {
  quit(save = "no", status = 0)
}
