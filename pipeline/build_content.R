#!/usr/bin/env Rscript
# pipeline/build_content.R
#
# WP10 (Text, figures and surveys): builds content/TEXT.csv,
# content/text/SEN/about.md, assets/figures/SEN/SEN_FISCAL_EQUITY.png and
# metadata/registries/FIGURES.csv from the legacy dashboard prose (About_SEN.txt,
# the "## Row Messages" blocks of index.qmd) and the fiscal-equity figure.
# See .docs/transition.qmd.
#
# Usage: Rscript pipeline/build_content.R [--root <dir>] [--out-root <dir>]

args <- commandArgs(trailingOnly = TRUE)

.arg <- function(args, flag, default) {
  idx <- which(args == flag)
  if (length(idx) == 0 || idx[1] >= length(args)) {
    return(default)
  }
  args[idx[1] + 1]
}

root <- .arg(args, "--root", ".")
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "constants.R"))
source(file.path(root, "pipeline", "R", "content.R"))
out_root <- cli_arg(args, "--out-root", root)

# The user's answer to gate G0's question T1 (card WP10, "Read" section):
# where the key-message titles and bodies come from. Fixed by decision, not
# a run-time flag.
MESSAGES_SOURCE <- "dashboard"

# The date the legacy text was frozen (card WP10, "Rules you need").
UPDATED_ON <- "2026-09-21"

TIME_PERIOD <- "2021"

# ---- about.md --------------------------------------------------------------

about_src <- repo_path(root, "data_raw", "text", "About_SEN.txt")
paras <- read_about_paragraphs(about_src)
if (length(paras) != 2) {
  stop(
    "build_content: expected 2 paragraphs in About_SEN.txt, found ", length(paras),
    call. = FALSE
  )
}
about_md <- paste(paras, collapse = "\n\n")

about_out <- repo_path(out_root, "content", "text", "SEN", "about.md")
dir.create(dirname(about_out), recursive = TRUE, showWarnings = FALSE)
con <- file(about_out, open = "wb")
writeLines(about_md, con, sep = "\n")
close(con)

# ---- key messages ------------------------------------------------------

qmd_lines <- readLines(repo_path(root, "index.qmd"), warn = FALSE, encoding = "UTF-8")

get_messages <- function(source) {
  if (identical(source, "dashboard")) {
    blocks <- extract_row_messages(qmd_lines)
    if (length(blocks) < 2) {
      stop(
        "build_content: expected 2 '## Row Messages' blocks in index.qmd, found ",
        length(blocks),
        call. = FALSE
      )
    }
    list(SEN = blocks[[1]], GNB = blocks[[2]])
  } else if (identical(source, "files")) {
    sen_lines <- readLines(
      repo_path(root, "data_raw", "text", "Messages_SEN.txt"),
      warn = FALSE, encoding = "UTF-8"
    )
    gnb_lines <- readLines(
      repo_path(root, "data_raw", "text", "Messages_GNB.txt"),
      warn = FALSE, encoding = "UTF-8"
    )
    list(SEN = parse_message_block(sen_lines), GNB = parse_message_block(gnb_lines))
  } else {
    stop("build_content: unknown MESSAGES_SOURCE '", source, "'", call. = FALSE)
  }
}

messages <- get_messages(MESSAGES_SOURCE)

# Guinea-Bissau's bodies are still the "TEXT" placeholder (card WP10, step 1):
# it becomes TBD rather than being kept as literal placeholder prose.
messages$GNB <- lapply(messages$GNB, function(m) {
  if (identical(m$body, "TEXT")) {
    m$body <- TBD
  }
  m
})

for (cc in c("SEN", "GNB")) {
  if (length(messages[[cc]]) != 3) {
    stop(
      "build_content: expected 3 key messages for ", cc, ", found ",
      length(messages[[cc]]), call. = FALSE
    )
  }
}

# ---- TEXT.csv ------------------------------------------------------------

msg_rows <- function(cc, msgs) {
  do.call(rbind, lapply(seq_along(msgs), function(i) {
    data.frame(
      slot = "messages", ref_area = cc, time_period = TIME_PERIOD, order = as.character(i),
      title = msgs[[i]]$title, body = msgs[[i]]$body, file = "",
      status = "DRAFT", updated_on = UPDATED_ON,
      stringsAsFactors = FALSE
    )
  }))
}

text_rows <- rbind(
  data.frame(
    slot = "about", ref_area = "SEN", time_period = TIME_PERIOD, order = "1",
    title = "", body = "", file = "SEN/about.md",
    status = "DRAFT", updated_on = UPDATED_ON, stringsAsFactors = FALSE
  ),
  msg_rows("SEN", messages$SEN),
  data.frame(
    slot = "about", ref_area = "GNB", time_period = TIME_PERIOD, order = "1",
    title = "", body = TBD, file = "",
    status = "DRAFT", updated_on = UPDATED_ON, stringsAsFactors = FALSE
  ),
  msg_rows("GNB", messages$GNB)
)

write_std_csv(text_rows, repo_path(out_root, "content", "TEXT.csv"))

# ---- figure ---------------------------------------------------------------

fig_src <- repo_path(root, "data_raw", "figures", "Fiscal Equity SEN.png")
fig_out <- repo_path(out_root, "assets", "figures", "SEN", "SEN_FISCAL_EQUITY.png")
dir.create(dirname(fig_out), recursive = TRUE, showWarnings = FALSE)
ok <- file.copy(fig_src, fig_out, overwrite = TRUE)
if (!ok) {
  stop("build_content: failed to copy the fiscal-equity figure", call. = FALSE)
}

fig_sha <- sha256_file(fig_src)

fig_text <- read_std_csv(repo_path(root, "pipeline", "bootstrap", "text", "figures_text.csv"))
if (nrow(fig_text) != 1) {
  stop(
    "build_content: expected 1 row in figures_text.csv, found ", nrow(fig_text),
    call. = FALSE
  )
}

figures_row <- data.frame(
  figure_id = fig_text$figure_id, ref_area = fig_text$ref_area,
  time_period = fig_text$time_period, theme = fig_text$theme,
  title_en = fig_text$title_en, caption_en = fig_text$caption_en,
  alt_text_en = fig_text$alt_text_en, indicators = "",
  source = TBD, producer = TBD, program = "", licence = TBD,
  file = "SEN/SEN_FISCAL_EQUITY.png", sha256 = fig_sha,
  status = "DRAFT", version_added = "0.1.0", notes = "",
  stringsAsFactors = FALSE
)

write_std_csv(figures_row, repo_path(out_root, "metadata", "registries", "FIGURES.csv"))

cat(
  "build_content: wrote content/TEXT.csv, content/text/SEN/about.md, ",
  "assets/figures/SEN/SEN_FISCAL_EQUITY.png, metadata/registries/FIGURES.csv\n",
  sep = ""
)
