#!/usr/bin/env Rscript
# Acceptance checks for WP06 - Breakdowns and qualifiers.
#
#   Rscript pipeline/acceptance/wp06_breakdowns-qualifiers.R --root .

## ---- 1. Root and check() -----------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
i <- which(args == "--root")
root <- normalizePath(if (length(i) == 1) args[i + 1] else ".", mustWork = TRUE)
contract <- file.path(root, ".docs", "transition", "contract")

.failures <- character(0)
check <- function(id, ok, evidence) {
  cat(sprintf("CHECK %s %s %s\n", id, if (isTRUE(ok)) "PASS" else "FAIL", evidence))
  if (!isTRUE(ok)) .failures[[length(.failures) + 1]] <<- id
  invisible(isTRUE(ok))
}
# Wrap a check that may stop(), so one error does not end the script.
try_check <- function(id, expr) {
  r <- tryCatch(expr, error = function(e) check(id, FALSE, paste("error:", conditionMessage(e))))
  invisible(r)
}

## ---- 2. Helpers ---------------------------------------------------------------
# All columns as character, BOM stripped, "" stays "" (never NA).
read_csv_char <- function(path) {
  raw <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(raw)) raw[1] <- sub("^﻿", "", raw[1])
  read.csv(text = paste(raw, collapse = "\n"), colClasses = "character", na.strings = NULL,
           check.names = FALSE, encoding = "UTF-8")
}
# Expected value and tolerance from the contract, by check_id.
expected <- function(check_id) {
  tab <- read_csv_char(file.path(contract, "expected_counts.csv"))
  row <- tab[tab$check_id == check_id, ]
  if (nrow(row) != 1) stop("no unique row in expected_counts.csv for ", check_id)
  list(value = as.numeric(row$expected), tol = as.numeric(row$tolerance))
}
meets <- function(actual, check_id) { e <- expected(check_id); abs(actual - e$value) <= e$tol + 1e-9 }
# The contract's header for one file, in order.
header_of <- function(file) {
  h <- read_csv_char(file.path(contract, "csv_headers.csv")); h <- h[h$file == file, ]
  h$column[order(as.integer(h$position))]
}
# Required ("R") columns for one file.
required_cols_of <- function(file) {
  h <- read_csv_char(file.path(contract, "csv_headers.csv")); h <- h[h$file == file & h$status == "R", ]
  h$column
}
same_file <- function(a, b) file.exists(a) && file.exists(b) && identical(unname(tools::md5sum(a)), unname(tools::md5sum(b)))
# Run a pipeline script; returns its exit status and a log path.
run_script <- function(script, script_args) {
  log <- tempfile(fileext = ".log")
  status <- system2("Rscript", c(shQuote(file.path(root, script)), script_args), stdout = log, stderr = log)
  list(status = status, log = log)
}

## ---- 3. WP06-specific setup ----------------------------------------------------
file_names <- c("CL_BRK_VAR.csv", "CL_COMP_BREAKDOWN.csv", "CL_QUAL_VAR.csv", "CL_QUALIFIER.csv")
file_keys  <- sub("\\.csv$", "", file_names)

codes_all <- read_csv_char(file.path(contract, "codes.csv"))
seeds <- setNames(lapply(file_keys, function(k) codes_all[codes_all$codelist == k, ]), file_keys)

out_path_of <- function(key) file.path(root, "metadata", "codelists", paste0(key, ".csv"))
outs <- setNames(lapply(file_keys, function(k) {
  p <- out_path_of(k)
  if (file.exists(p)) read_csv_char(p) else NULL
}), file_keys)

meta_ids <- c(CL_BRK_VAR = "META.CL_BRK_VAR", CL_COMP_BREAKDOWN = "META.CL_COMP_BREAKDOWN",
              CL_QUAL_VAR = "META.CL_QUAL_VAR", CL_QUALIFIER = "META.CL_QUALIFIER")

# seed column name -> output column name, per file's structural columns (card "Rules you need" table).
struct_cols <- list(
  CL_BRK_VAR        = c(describes = "describes", applies_to_units = "applies_to_units",
                         partition = "partition", requires = "requires_qual", slot_order = "slot_order"),
  CL_COMP_BREAKDOWN = c(var_code = "var_code", parent = "parent", order = "order"),
  CL_QUAL_VAR       = c(slot_order = "slot_order", requires = "requires"),
  CL_QUALIFIER      = c(var_code = "var_code", value = "value", valid_with = "valid_with", order = "order")
)

# Compare one output file's code set and structural columns against the seed.
# value and slot_order are compared as numbers (empty == empty); everything else as text.
compare_structural <- function(key, seed_df, out_df, cols_map, meta_id) {
  ev <- character(0); ok <- TRUE
  if (is.null(out_df)) return(list(ok = FALSE, evidence = sprintf("%s: output file missing", key)))
  seed_codes <- sort(seed_df$code); out_codes <- sort(out_df$code)
  if (!identical(seed_codes, out_codes)) {
    ok <- FALSE
    ev <- c(ev, sprintf("%s code set mismatch (seed %d, out %d)", key, length(seed_codes), length(out_codes)))
  }
  if (!meets(nrow(out_df), meta_id)) {
    ok <- FALSE
    ev <- c(ev, sprintf("%s row count %d != expected_counts.csv %s", key, nrow(out_df), meta_id))
  }
  common <- intersect(seed_df$code, out_df$code)
  s <- seed_df[match(common, seed_df$code), , drop = FALSE]
  o <- out_df[match(common, out_df$code), , drop = FALSE]
  for (seed_col in names(cols_map)) {
    out_col <- cols_map[[seed_col]]
    if (!(out_col %in% names(o))) { ok <- FALSE; ev <- c(ev, sprintf("%s missing column %s", key, out_col)); next }
    sv <- s[[seed_col]]; ov <- o[[out_col]]
    if (seed_col %in% c("value", "slot_order")) {
      snum <- suppressWarnings(as.numeric(sv)); onum <- suppressWarnings(as.numeric(ov))
      eqs <- (sv == "" & ov == "") | (!is.na(snum) & !is.na(onum) & snum == onum)
    } else {
      eqs <- sv == ov
    }
    if (!all(eqs)) {
      ok <- FALSE
      ev <- c(ev, sprintf("%s.%s mismatch at %s", key, seed_col, paste(head(common[!eqs], 3), collapse = ",")))
    }
  }
  list(ok = ok, evidence = if (length(ev)) paste(ev, collapse = "; ")
                            else sprintf("%s: %d codes, structural cols match seed", key, length(common)))
}

# Space-separated tokens of a column that fail to resolve against a reference code vector.
unresolved_refs <- function(df, col, ref_codes, exclude = character(0)) {
  if (!(col %in% names(df))) return(character(0))
  bad <- character(0)
  for (i in seq_len(nrow(df))) {
    v <- df[[col]][i]
    if (is.na(v) || v == "") next
    toks <- setdiff(strsplit(v, "\\s+")[[1]], exclude)
    unresolved <- setdiff(toks, ref_codes)
    if (length(unresolved)) bad <- c(bad, sprintf("%s->%s", df$code[i], paste(unresolved, collapse = ",")))
  }
  bad
}

## ---- 4. Checks ------------------------------------------------------------------

# WP06.A1: code set and structural columns equal the seed's, for each of the four files.
try_check("WP06.A1", {
  res1 <- lapply(file_keys, function(k) compare_structural(k, seeds[[k]], outs[[k]], struct_cols[[k]], meta_ids[[k]]))
  ok1 <- all(vapply(res1, `[[`, logical(1), "ok"))
  ev1 <- paste(vapply(res1, `[[`, character(1), "evidence"), collapse = " | ")
  check("WP06.A1", ok1, ev1)
})

# WP06.A2: every category's var_code exists in its variable file, and the category code
# starts with "<var_code>_".
try_check("WP06.A2", {
  check_prefixes <- function(cat_df, var_df, cat_name, var_name) {
    ev <- character(0); ok <- TRUE
    missing_var <- setdiff(unique(cat_df$var_code), var_df$code)
    if (length(missing_var)) { ok <- FALSE; ev <- c(ev, sprintf("%s var_code not in %s: %s", cat_name, var_name, paste(missing_var, collapse = ","))) }
    has_prefix <- mapply(function(cd, vc) startsWith(cd, paste0(vc, "_")), cat_df$code, cat_df$var_code)
    bad_prefix <- cat_df$code[!has_prefix]
    if (length(bad_prefix)) { ok <- FALSE; ev <- c(ev, sprintf("%s codes without <var_code>_ prefix: %s", cat_name, paste(bad_prefix, collapse = ","))) }
    list(ok = ok, evidence = if (length(ev)) paste(ev, collapse = "; ") else sprintf("%s: %d rows ok", cat_name, nrow(cat_df)))
  }
  r_comp <- check_prefixes(outs$CL_COMP_BREAKDOWN, outs$CL_BRK_VAR, "CL_COMP_BREAKDOWN", "CL_BRK_VAR")
  r_qual <- check_prefixes(outs$CL_QUALIFIER, outs$CL_QUAL_VAR, "CL_QUALIFIER", "CL_QUAL_VAR")
  check("WP06.A2", r_comp$ok && r_qual$ok, paste(r_comp$evidence, r_qual$evidence, sep = " | "))
})

# WP06.A3: slot_order is unique within CL_BRK_VAR and within CL_QUAL_VAR.
try_check("WP06.A3", {
  so_brk <- outs$CL_BRK_VAR$slot_order
  so_qual <- outs$CL_QUAL_VAR$slot_order
  dup_brk <- anyDuplicated(so_brk) > 0
  dup_qual <- anyDuplicated(so_qual) > 0
  check("WP06.A3", !dup_brk && !dup_qual,
        sprintf("CL_BRK_VAR slot_order duplicated=%s; CL_QUAL_VAR slot_order duplicated=%s", dup_brk, dup_qual))
})

# WP06.A4: every requires, requires_qual, valid_with (other than _Z) and parent value
# resolves to a code of the right file.
try_check("WP06.A4", {
  bad <- character(0)
  bad <- c(bad, unresolved_refs(outs$CL_BRK_VAR, "requires_qual", outs$CL_QUAL_VAR$code))
  bad <- c(bad, unresolved_refs(outs$CL_QUAL_VAR, "requires", outs$CL_QUAL_VAR$code))
  bad <- c(bad, unresolved_refs(outs$CL_QUALIFIER, "valid_with", outs$CL_QUALIFIER$code, exclude = "_Z"))
  bad <- c(bad, unresolved_refs(outs$CL_COMP_BREAKDOWN, "parent", outs$CL_COMP_BREAKDOWN$code))
  check("WP06.A4", length(bad) == 0,
        if (length(bad)) paste("unresolved:", paste(head(bad, 8), collapse = "; ")) else "all references resolve")
})

# WP06.A5: every applies_to_units value is one of IND, HH, HE, PLOT.
try_check("WP06.A5", {
  atu <- outs$CL_BRK_VAR$applies_to_units
  toks <- unique(unlist(strsplit(atu[atu != ""], "\\s+")))
  bad <- setdiff(toks, c("IND", "HH", "HE", "PLOT"))
  check("WP06.A5", length(bad) == 0,
        if (length(bad)) paste("bad tokens:", paste(bad, collapse = ",")) else sprintf("tokens used: %s", paste(sort(toks), collapse = ",")))
})

# WP06.A6: every code has at most 32 characters and passes the code pattern.
try_check("WP06.A6", {
  all_codes <- unlist(lapply(outs, function(d) if (is.null(d)) character(0) else d$code))
  pattern <- "^[A-Z][A-Z0-9_]{0,31}$"
  bad <- all_codes[!grepl(pattern, all_codes) | nchar(all_codes) > 32]
  check("WP06.A6", length(bad) == 0,
        if (length(bad)) paste("bad codes:", paste(head(bad, 8), collapse = ",")) else sprintf("%d codes ok", length(all_codes)))
})

# WP06.A7: the headers equal csv_headers.csv. Every R column is filled. TBD appears only
# in universe.
try_check("WP06.A7", {
  ok <- TRUE; ev <- character(0)
  for (fn in file_names) {
    key <- sub("\\.csv$", "", fn)
    df <- outs[[key]]
    if (is.null(df)) { ok <- FALSE; ev <- c(ev, sprintf("%s missing", fn)); next }
    exp_header <- header_of(fn)
    if (!identical(names(df), exp_header)) { ok <- FALSE; ev <- c(ev, sprintf("%s header mismatch: %s", fn, paste(names(df), collapse = ","))) }
    for (rc in required_cols_of(fn)) {
      if (rc %in% names(df)) {
        n_empty <- sum(df[[rc]] == "" | is.na(df[[rc]]))
        if (n_empty > 0) { ok <- FALSE; ev <- c(ev, sprintf("%s.%s has %d empty required cells", fn, rc, n_empty)) }
      }
    }
    for (col in names(df)) {
      if (col == "universe") next
      if (any(grepl("\\bTBD\\b", df[[col]]))) { ok <- FALSE; ev <- c(ev, sprintf("%s.%s contains TBD outside universe", fn, col)) }
    }
  }
  check("WP06.A7", ok, if (length(ev)) paste(ev, collapse = "; ") else "headers, required fill and TBD-only-in-universe ok")
})

# WP06.A8: the six international poverty lines carry the right value/PPP round; PL300 is
# valid with PPP_2021 only.
try_check("WP06.A8", {
  qual <- outs$CL_QUALIFIER
  exp_map <- list(
    POVLINE_PL215 = list(value = "2.15", vw = "PPP_2017"),
    POVLINE_PL365 = list(value = "3.65", vw = "PPP_2017"),
    POVLINE_PL685 = list(value = "6.85", vw = "PPP_2017"),
    POVLINE_PL300 = list(value = "3.00", vw = "PPP_2021"),
    POVLINE_PL420 = list(value = "4.20", vw = "PPP_2021"),
    POVLINE_PL830 = list(value = "8.30", vw = "PPP_2021")
  )
  ok <- TRUE; ev <- character(0)
  for (code in names(exp_map)) {
    row <- qual[qual$code == code, ]
    if (nrow(row) != 1) { ok <- FALSE; ev <- c(ev, sprintf("%s: not exactly one row (%d)", code, nrow(row))); next }
    v_ok <- isTRUE(all.equal(suppressWarnings(as.numeric(row$value)), as.numeric(exp_map[[code]]$value)))
    vw_toks <- strsplit(row$valid_with, "\\s+")[[1]]
    vw_ok <- identical(vw_toks, strsplit(exp_map[[code]]$vw, "\\s+")[[1]])
    if (!v_ok || !vw_ok) { ok <- FALSE; ev <- c(ev, sprintf("%s: value=%s valid_with=%s", code, row$value, row$valid_with)) }
  }
  check("WP06.A8", ok, if (length(ev)) paste(ev, collapse = "; ") else "6 poverty lines and PL300 valid_with ok")
})

# WP06.A9: --out-root <tempdir> reproduces the four files byte for byte.
try_check("WP06.A9", {
  tmp9 <- tempfile("wp06_out_")
  dir.create(tmp9, recursive = TRUE)
  res9 <- run_script(file.path("pipeline", "bootstrap", "build_breakdowns_qualifiers.R"),
                      c("--root", shQuote(root), "--out-root", shQuote(tmp9)))
  if (res9$status != 0) {
    log_txt <- paste(tail(readLines(res9$log, warn = FALSE), 10), collapse = " | ")
    check("WP06.A9", FALSE, sprintf("build script exit %s; log tail: %s", res9$status, log_txt))
  } else {
    mismatches <- Filter(function(fn) !same_file(out_path_of(sub("\\.csv$", "", fn)),
                                                   file.path(tmp9, "metadata", "codelists", fn)),
                          file_names)
    check("WP06.A9", length(mismatches) == 0,
          if (length(mismatches)) paste("byte diff:", paste(mismatches, collapse = ",")) else "byte-identical reproduction in temp out-root")
  }
})

## ---- 5. Exit ----------------------------------------------------------------------
cat(if (length(.failures)) sprintf("\n%d check(s) failed: %s\n", length(.failures), paste(.failures, collapse = ", ")) else "\nAll checks passed.\n")
quit(status = if (length(.failures)) 1L else 0L, save = "no")
