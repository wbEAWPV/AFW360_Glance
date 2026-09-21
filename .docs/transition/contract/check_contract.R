#!/usr/bin/env Rscript
# Contract self-check for the AFW 360 transition.
#
# Checks that the contract seed files agree with each other and with the raw
# workbooks, and recomputes every count in expected_counts.csv that can be
# derived from them. It reads only; it writes nothing.
#
#   Rscript .docs/transition/contract/check_contract.R --root .
#
# Prints one line per check, "CHECK <id> PASS|FAIL <evidence>", and exits 0
# only if every check passes. Run it after any change to contract/*.csv
# (WP99 and its verifier must), and before gate G1 freezes the contract.

suppressWarnings(suppressMessages(library(readxl)))

args <- commandArgs(trailingOnly = TRUE)
i <- which(args == "--root")
root <- normalizePath(if (length(i) == 1) args[i + 1] else ".", mustWork = TRUE)
cdir <- file.path(root, ".docs", "transition", "contract")

.fail <- character(0)
check <- function(id, ok, evidence) {
  cat(sprintf("CHECK %s %s %s\n", id, if (isTRUE(ok)) "PASS" else "FAIL", evidence))
  if (!isTRUE(ok)) .fail[[length(.fail) + 1]] <<- id
  invisible(isTRUE(ok))
}
rd <- function(name) {
  x <- read.csv(file.path(cdir, name), colClasses = "character", na.strings = NULL,
                check.names = FALSE, encoding = "UTF-8", fileEncoding = "UTF-8")
  x
}
words <- function(x) if (is.na(x) || x == "") character(0) else strsplit(x, " +")[[1]]
show <- function(x, n = 5) paste(utils::head(x, n), collapse = " | ")

codes <- rd("codes.csv"); tri <- rd("label_triage.csv"); geo <- rd("geo_codes.csv")
plan <- rd("tab_plan.csv"); natc <- rd("legacy_national_columns.csv")
ovr <- rd("legacy_overrides.csv"); exp <- rd("expected_counts.csv"); hdr <- rd("csv_headers.csv")
own <- rd("output_ownership.csv")
cl <- function(name) codes[codes$codelist == name, ]

tables_dir <- if (dir.exists(file.path(root, "data_raw", "tables"))) file.path(root, "data_raw", "tables") else file.path(root, "INPUT Tables")
wb <- function(iso, sheet) as.data.frame(read_excel(file.path(tables_dir, sprintf("Tables_%s.xlsx", iso)), sheet, col_types = "text"), check.names = FALSE)
SHEETS <- c("National", "ADM 1", "ZAE")

## ---- codes.csv -------------------------------------------------------------
key <- paste(codes$codelist, codes$code)
check("CODES.UNIQUE", !anyDuplicated(key), sprintf("%d rows, %d duplicated keys", nrow(codes), sum(duplicated(key))))
bad <- codes$code[!grepl("^[A-Z][A-Z0-9_]{0,31}$", codes$code)]
check("CODES.SYNTAX", length(bad) == 0, sprintf("%d codes break ^[A-Z][A-Z0-9_]{0,31}$ %s", length(bad), show(bad)))
cat_rows <- codes[codes$codelist %in% c("CL_COMP_BREAKDOWN", "CL_QUALIFIER"), ]
var_of <- ifelse(cat_rows$codelist == "CL_COMP_BREAKDOWN", "CL_BRK_VAR", "CL_QUAL_VAR")
ok_var <- mapply(function(v, l) v %in% cl(l)$code, cat_rows$var_code, var_of)
ok_pre <- startsWith(cat_rows$code, paste0(cat_rows$var_code, "_"))
check("CODES.VAR_CODE", all(ok_var) && all(ok_pre), sprintf("%d categories; %d unknown var_code; %d without the var_code prefix", nrow(cat_rows), sum(!ok_var), sum(!ok_pre)))
par <- codes[codes$parent != "", ]
ok_par <- mapply(function(p, l) p %in% cl(l)$code, par$parent, par$codelist)
check("CODES.PARENT", all(ok_par), sprintf("%d parents, %d unresolved", nrow(par), sum(!ok_par)))
req <- unique(unlist(lapply(codes$requires, words)))
vw <- setdiff(unique(unlist(lapply(codes$valid_with, words))), "_Z")
check("CODES.REQUIRES", all(req %in% cl("CL_QUAL_VAR")$code) && all(vw %in% cl("CL_QUALIFIER")$code),
      sprintf("requires: %s; valid_with: %s", show(req), show(vw)))
units <- unique(unlist(lapply(cl("CL_BRK_VAR")$applies_to_units, words)))
check("CODES.UNITS", all(units %in% cl("CL_STAT_UNIT")$code), sprintf("applies_to_units uses %s", show(units)))
so <- function(l) as.integer(cl(l)$slot_order)
check("CODES.SLOT_ORDER", !anyDuplicated(so("CL_BRK_VAR")) && !anyDuplicated(so("CL_QUAL_VAR")) && !anyNA(c(so("CL_BRK_VAR"), so("CL_QUAL_VAR"))),
      "slot_order is an integer, unique within CL_BRK_VAR and within CL_QUAL_VAR")

## ---- label_triage.csv -------------------------------------------------------
star <- tri[tri$sheet == "*", ]; dep <- tri[tri$sheet == "Departement", ]; map <- star[star$action == "MAP", ]
check("TRIAGE.ACTIONS", all(tri$action %in% c("MAP", "DUPLICATE_OF", "DERIVED", "SKIP")) && all(dep$action == "SKIP"),
      sprintf("%d rows: %s", nrow(tri), paste(names(table(tri$action)), table(tri$action), collapse = ", ")))
qvar <- setNames(cl("CL_QUALIFIER")$var_code, cl("CL_QUALIFIER")$code)
qslot <- setNames(as.integer(cl("CL_QUAL_VAR")$slot_order), cl("CL_QUAL_VAR")$code)
bvar <- setNames(cl("CL_COMP_BREAKDOWN")$var_code, cl("CL_COMP_BREAKDOWN")$code)
sid <- vapply(seq_len(nrow(map)), function(k) {
  q <- words(map$MEASURE_QUALS[k]); q <- q[order(qslot[qvar[q]], q)]
  paste(c(map$INDICATOR[k], q, words(map$DEFINING_BREAKDOWN[k])), collapse = ".")
}, "")
check("TRIAGE.SERIES_ID", identical(sid, map$series_id) && !anyDuplicated(map$series_id),
      sprintf("%d MAP rows; %d break the series-ID rule; %d duplicated %s", nrow(map), sum(sid != map$series_id), sum(duplicated(map$series_id)), show(map$series_id[sid != map$series_id])))
uq <- unique(unlist(lapply(map$MEASURE_QUALS, words))); ub <- unique(unlist(lapply(map$DEFINING_BREAKDOWN, words)))
check("TRIAGE.CODES_EXIST", all(uq %in% names(qvar)) && all(ub %in% names(bvar)),
      sprintf("unknown qualifiers: %s; unknown breakdowns: %s", show(setdiff(uq, names(qvar))), show(setdiff(ub, names(bvar)))))
in_cl <- function(col, l) all(setdiff(unique(map[[col]]), "") %in% cl(l)$code)
check("TRIAGE.ATTR_CODES", in_cl("stat_unit", "CL_STAT_UNIT") && in_cl("statistic", "CL_STATISTIC") && in_cl("weight", "CL_WEIGHT") &&
        in_cl("unit_measure", "CL_UNIT") && in_cl("unit_denom", "CL_UNIT") && all(map$stat_unit != ""),
      "stat_unit, statistic, weight, unit_measure and unit_denom use registered codes")
attrs <- c("stat_unit", "statistic", "weight", "unit_measure", "unit_denom", "unit_time", "price_basis", "display_as", "decimals", "ref_period", "valid_min", "valid_max")
incons <- names(which(vapply(split(map[attrs], map$INDICATOR), function(d) nrow(unique(d)) > 1, NA)))
check("TRIAGE.INDICATOR_CONSISTENT", length(incons) == 0, sprintf("%d indicators carry conflicting attributes across their labels %s", length(incons), show(incons)))
pair_ok <- vapply(seq_len(nrow(map)), function(k) {
  q <- words(map$MEASURE_QUALS[k]); v <- qvar[q]
  all(vapply(q, function(code) {
    allow <- words(cl("CL_QUALIFIER")$valid_with[cl("CL_QUALIFIER")$code == code])
    need <- words(cl("CL_QUAL_VAR")$requires[cl("CL_QUAL_VAR")$code == qvar[[code]]])
    if (length(allow) == 0) return(all(need %in% v))
    if (identical(allow, "_Z")) return(!any(need %in% v))
    all(need %in% v) && all(q[v %in% need] %in% allow)
  }, NA))
}, NA)
check("TRIAGE.QUAL_PAIRS", all(pair_ok), sprintf("%d series break requires/valid_with %s", sum(!pair_ok), show(map$series_id[!pair_ok])))
bu <- setNames(cl("CL_BRK_VAR")$applies_to_units, cl("CL_BRK_VAR")$code)
def_ok <- map$DEFINING_BREAKDOWN == "" | mapply(function(b, u) u %in% words(bu[[bvar[[b]]]]), ifelse(map$DEFINING_BREAKDOWN == "", names(bvar)[1], map$DEFINING_BREAKDOWN), map$stat_unit)
check("TRIAGE.DEFINING_UNIT", all(def_ok), sprintf("%d series use a defining breakdown that does not apply to their stat_unit", sum(!def_ok)))
ref <- star[star$action %in% c("DUPLICATE_OF", "DERIVED"), ]
rule_target <- sub("^(EQUALS|ONE_MINUS):(L[0-9]+).*$", "\\2", ref$assert_rule)
check("TRIAGE.ASSERT_REFS", all(ref$duplicate_of %in% map$row_id) && all(rule_target %in% map$row_id) && all(grepl("^(EQUALS|ONE_MINUS):L[0-9]+( tol=[0-9.]+)?$", ref$assert_rule)),
      sprintf("%d DUPLICATE_OF/DERIVED rows point at MAP rows: %s", nrow(ref), show(ref$assert_rule)))

## ---- workbooks against the triage, geo_codes and the column map ---------------
cells <- list(); labels_ok <- TRUE
for (iso in c("SEN", "GNB")) for (s in SHEETS) {
  d <- wb(iso, s); cells[[paste(iso, s)]] <- d
  labels_ok <- labels_ok && identical(d$indicator, star$legacy_label)
}
depw <- wb("SEN", "Departement")
check("LABELS.SHARED", labels_ok, sprintf("%d labels, identical and in triage order on National/ADM 1/ZAE of both workbooks", nrow(star)))
check("LABELS.DEPARTEMENT", identical(depw$indicator, dep$legacy_label), sprintf("%d Departement labels match the triage", nrow(dep)))
col_ok <- TRUE; miss <- character(0)
for (iso in c("SEN", "GNB")) {
  col_ok <- col_ok && setequal(names(cells[[paste(iso, "National")]])[-1], natc$column)
  for (s in c("ADM 1", "ZAE")) {
    g <- geo$legacy_column[geo$ref_area == iso & geo$legacy_sheet == s]; w <- names(cells[[paste(iso, s)]])[-1]
    if (!setequal(g, w) || anyDuplicated(g)) { col_ok <- FALSE; miss <- c(miss, setdiff(w, g), setdiff(g, w)) }
  }
}
check("COLUMNS.MAPPED", col_ok, sprintf("every workbook column maps to exactly one seed row %s", show(miss)))
check("COLUMNS.NATIONAL_CODES", all(setdiff(natc$URBANISATION, "") %in% cl("CL_URBANISATION")$code) && all(setdiff(natc$COMP_BREAKDOWN, "") %in% names(bvar)) && all(natc$cut_id %in% plan$cut_id),
      "legacy_national_columns.csv uses registered codes and cut_ids")
schemes <- unique(geo[c("ref_area", "scheme")])
plan_ok <- all(unlist(lapply(plan$comp_breakdowns, words)) %in% cl("CL_BRK_VAR")$code) &&
  all(setdiff(unlist(lapply(plan$urbanisation, words)), "_T") %in% cl("CL_URBANISATION")$code) &&
  all(vapply(seq_len(nrow(plan)), function(k) plan$geo_scheme[k] == "_T" || any(schemes$scheme == plan$geo_scheme[k] & (plan$ref_area[k] == "ALL" | schemes$ref_area == plan$ref_area[k])), NA))
check("PLAN.CODES", plan_ok, sprintf("%d cuts use registered variables, residence codes and schemes", nrow(plan)))

## ---- counts derived from the plan, and from the workbooks ----------------------
n_groups <- function(iso, unit) {
  sum(vapply(seq_len(nrow(plan)), function(k) {
    if (!plan$ref_area[k] %in% c("ALL", iso)) return(0L)
    v <- words(plan$comp_breakdowns[k])
    if (length(v) && !all(vapply(v, function(x) unit %in% words(bu[[x]]), NA))) return(0L)
    n_geo <- if (plan$geo_scheme[k] == "_T") 1L else sum(geo$ref_area == iso & geo$scheme == plan$geo_scheme[k])
    n_urb <- if (plan$urbanisation[k] == "_T") 1L else length(words(plan$urbanisation[k]))
    as.integer(n_geo * n_urb * prod(vapply(v, function(x) sum(bvar == x), 1L)))
  }, 1L))
}
plan_rows <- function(iso) sum(vapply(map$stat_unit, function(u) n_groups(iso, u), 1L))
is_empty <- function(x) is.na(x) | trimws(x) == ""
withheld <- function(iso, s, col, label) any(ovr$action == "WITHHOLD" & ovr$ref_area == iso & ovr$sheet %in% c(s, "*") & ovr$column %in% c(col, "*") & ovr$legacy_label %in% c(label, "*"))
tally <- function(iso) {
  out <- c(mapped = 0L, withheld = 0L, A = 0L, O = 0L)
  for (s in SHEETS) { d <- cells[[paste(iso, s)]]; d <- d[d$indicator %in% map$legacy_label, ]
    for (col in names(d)[-1]) for (r in seq_len(nrow(d))) {
      out["mapped"] <- out["mapped"] + 1L
      if (withheld(iso, s, col, d$indicator[r])) out["withheld"] <- out["withheld"] + 1L
      else if (is_empty(d[[col]][r])) out["O"] <- out["O"] + 1L else out["A"] <- out["A"] + 1L
    } }
  out
}
ts <- tally("SEN"); tg <- tally("GNB")
check("PLAN.EQUALS_WORKBOOK", plan_rows("SEN") == ts[["mapped"]] && plan_rows("GNB") == tg[["mapped"]],
      sprintf("SERIES x TAB_PLAN gives SEN %d / GNB %d keys; mapped workbook cells are SEN %d / GNB %d", plan_rows("SEN"), plan_rows("GNB"), ts[["mapped"]], tg[["mapped"]]))
ov_hit <- vapply(seq_len(nrow(ovr)), function(k) {
  any(vapply(if (ovr$sheet[k] == "*") SHEETS else ovr$sheet[k], function(s) {
    d <- cells[[paste(ovr$ref_area[k], s)]]
    (ovr$column[k] == "*" || ovr$column[k] %in% names(d)) && (ovr$legacy_label[k] == "*" || ovr$legacy_label[k] %in% d$indicator)
  }, NA))
}, NA)
check("OVERRIDES.TARGETS", all(ov_hit) && all(ovr$action %in% c("WITHHOLD", "COMMENT")), sprintf("%d override rows, %d without a target cell", nrow(ovr), sum(!ov_hit)))

num <- function(iso, s, label, col) as.numeric(cells[[paste(iso, s)]][[col]][cells[[paste(iso, s)]]$indicator == label])
dev_max <- 0; rule_ok <- TRUE
for (k in seq_len(nrow(ref))) {
  tol <- if (grepl("tol=", ref$assert_rule[k])) as.numeric(sub(".*tol=", "", ref$assert_rule[k])) else 0
  tgt <- map$legacy_label[map$row_id == rule_target[k]]; one_minus <- startsWith(ref$assert_rule[k], "ONE_MINUS")
  for (iso in c("SEN", "GNB")) for (s in SHEETS) for (col in names(cells[[paste(iso, s)]])[-1]) {
    a <- num(iso, s, ref$legacy_label[k], col); b <- num(iso, s, tgt, col)
    if (is.na(a) || is.na(b)) next
    dv <- abs(a - (if (one_minus) 1 - b else b)); dev_max <- max(dev_max, dv - tol)
    if (dv > tol + 1e-9) rule_ok <- FALSE
  }
}
check("TRIAGE.ASSERT_RULES_HOLD", rule_ok, sprintf("every EQUALS/ONE_MINUS rule holds on the raw cells of both countries (largest excess over tolerance %.4f)", dev_max))

actual <- list(
  SERIES.COUNT = nrow(map), INDICATOR.CODES = length(unique(map$INDICATOR)),
  LABELS.SHARED = nrow(star), LABELS.DEPARTEMENT = nrow(dep), LABELS.TOTAL = nrow(tri),
  DATA.SEN.ROWS = ts[["A"]] + ts[["O"]], DATA.SEN.ROWS.A = ts[["A"]],
  GNB.MAPPED_CELLS = tg[["mapped"]], GNB.WITHHELD_CELLS = tg[["withheld"]],
  GNB.DATA.ROWS = tg[["A"]] + tg[["O"]], GNB.DATA.ROWS.A = tg[["A"]], GNB.DATA.ROWS.O = tg[["O"]],
  DEPARTEMENT.SKIPPED = nrow(depw) * (ncol(depw) - 1),
  META.CL_INDICATOR = length(unique(map$INDICATOR)), META.SERIES_PLAN = nrow(map), META.TAB_PLAN = nrow(plan),
  META.CL_BRK_VAR = nrow(cl("CL_BRK_VAR")), META.CL_COMP_BREAKDOWN = nrow(cl("CL_COMP_BREAKDOWN")),
  META.CL_QUAL_VAR = nrow(cl("CL_QUAL_VAR")), META.CL_QUALIFIER = nrow(cl("CL_QUALIFIER")),
  META.CL_GEO = nrow(geo), META.CL_GEO_SCHEME = nrow(schemes), META.CL_AREA = nrow(cl("CL_AREA")),
  META.LEGACY_LABELS = nrow(tri), META.LEGACY_OVERRIDES = nrow(ovr),
  META.LEGACY_COLUMNS = sum(vapply(c("SEN", "GNB"), function(iso) sum(vapply(SHEETS, function(s) ncol(cells[[paste(iso, s)]]) - 1L, 1L)), 1L)) + ncol(depw) - 1L
)
for (iso in c("SEN", "GNB")) for (s in c(SHEETS, if (iso == "SEN") "Departement")) {
  d <- if (s == "Departement") depw else cells[[paste(iso, s)]]; m <- as.matrix(d[-1]); id <- sprintf("CELLS.%s_%s", iso, gsub(" ", "", s))
  actual[[id]] <- length(m); actual[[paste0(id, ".NONEMPTY")]] <- sum(!is_empty(m)); actual[[paste0(id, ".EMPTY")]] <- sum(is_empty(m))
}
for (iso in c("SEN", "GNB")) for (pl in c("300", "420")) {
  lab <- map$legacy_label[map$series_id == sprintf("POV_NUM.POVLINE_PL%s.PPP_2021", pl)]
  if (length(lab) == 1) actual[[sprintf("POVNUM.%s.PL%s", iso, pl)]] <- num(iso, "National", lab, "estimateTotal")
}
bad_counts <- character(0)
for (id in names(actual)) {
  e <- exp[exp$check_id == id, ]
  if (nrow(e) != 1) { bad_counts <- c(bad_counts, sprintf("%s missing from expected_counts.csv", id)); next }
  if (abs(actual[[id]] - as.numeric(e$expected)) > as.numeric(e$tolerance) + 1e-9) bad_counts <- c(bad_counts, sprintf("%s expected %s, recomputed %s", id, e$expected, actual[[id]]))
}
check("EXPECTED.RECOMPUTED", length(bad_counts) == 0, sprintf("%d counts recomputed from the seeds and workbooks; %d disagree %s", length(actual), length(bad_counts), show(bad_counts, 10)))

## ---- headers and ownership ------------------------------------------------------
pos_ok <- all(vapply(split(as.integer(hdr$position), hdr$file), function(p) identical(sort(p), seq_along(p)), NA))
check("HEADERS.POSITIONS", pos_ok && !anyDuplicated(paste(hdr$file, hdr$column)), sprintf("%d files, positions 1..n without gaps, no repeated column", length(unique(hdr$file))))
dup_own <- own$path[duplicated(own$path)]
check("OWNERSHIP.UNIQUE", length(dup_own) == 0, sprintf("%d paths, %d owned twice %s", nrow(own), length(dup_own), show(dup_own)))

cat(if (length(.fail)) sprintf("\n%d check(s) failed: %s\n", length(.fail), paste(.fail, collapse = ", ")) else "\nAll contract checks passed.\n")
quit(status = if (length(.fail)) 1L else 0L, save = "no")
