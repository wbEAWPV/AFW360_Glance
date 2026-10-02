#!/usr/bin/env Rscript
# pipeline/bootstrap/build_plans.R
#
# Builds metadata/plans/SERIES_PLAN.csv and metadata/plans/TAB_PLAN.csv
# (WP08) from the contract's label triage and cut list:
#   - SERIES_PLAN.csv: one row per MAP row of
#     pipeline/bootstrap/seeds/label_triage.csv.
#   - TAB_PLAN.csv: pipeline/bootstrap/seeds/tab_plan.csv, in order, plus
#     status = DRAFT.
#
# Usage: Rscript pipeline/bootstrap/build_plans.R [--root <repo root>] [--out-root <dir>]
#
# Reads inputs under --root (default "."), writes outputs under --out-root
# (default: --root) at the same relative paths (.docs/data-standard.qmd).

.get_flag <- function(args, flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) == 0 || idx[1] >= length(args)) {
    return(default)
  }
  args[idx[1] + 1]
}

args <- commandArgs(trailingOnly = TRUE)
root <- .get_flag(args, "--root", ".")

source(file.path(root, "pipeline", "R", "io.R"))

out_root <- cli_arg(args, "--out-root", root)

triage <- read_std_csv(repo_path(root, "pipeline", "bootstrap", "seeds", "label_triage.csv"))
tab_plan_src <- read_std_csv(repo_path(root, "pipeline", "bootstrap", "seeds", "tab_plan.csv"))

map_rows <- triage[triage$action == "MAP", , drop = FALSE]

series_plan <- data.frame(
  series_id = map_rows$series_id,
  ref_area = "ALL",
  INDICATOR = map_rows$INDICATOR,
  MEASURE_QUALS = map_rows$MEASURE_QUALS,
  DEFINING_BREAKDOWN = map_rows$DEFINING_BREAKDOWN,
  status = "DRAFT",
  notes = map_rows$hard_case,
  stringsAsFactors = FALSE
)
series_plan <- series_plan[order(series_plan$series_id, method = "radix"), , drop = FALSE]
rownames(series_plan) <- NULL

tab_plan <- as.data.frame(tab_plan_src, stringsAsFactors = FALSE)
tab_plan$status <- "DRAFT"

write_std_csv(series_plan, repo_path(out_root, "metadata", "plans", "SERIES_PLAN.csv"))
write_std_csv(tab_plan, repo_path(out_root, "metadata", "plans", "TAB_PLAN.csv"))
