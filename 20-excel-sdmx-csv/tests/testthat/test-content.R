root <- find_root()
source(file.path(root, "pipeline", "R", "io.R"))
source(file.path(root, "pipeline", "R", "content.R"))

test_that("strip_message_wrappers unwraps a Markdown(<span>...</span>) call", {
  x <- 'Markdown("<span style=\'font-size:16px;\'>Some body text.</span>")'
  expect_equal(strip_message_wrappers(x), "Some body text.")
})

test_that("strip_message_wrappers strips <b> tags from a title", {
  expect_equal(strip_message_wrappers("<b>Poverty Patterns and Trends</b>"), "Poverty Patterns and Trends")
})

test_that("strip_message_wrappers trims leading/trailing whitespace inside the span", {
  x <- 'Markdown("<span style=\'font-size:16px;\'> TEXT</span>")'
  expect_equal(strip_message_wrappers(x), "TEXT")
})

test_that("strip_message_wrappers is a no-op (besides trimming) on already-plain text", {
  expect_equal(strip_message_wrappers("  Plain title  "), "Plain title")
  expect_equal(strip_message_wrappers("1. Poverty"), "1. Poverty")
})

test_that("strip_message_wrappers leaves no <, Markdown( or span behind", {
  x <- 'Markdown("<span style=\'font-size:16px;\'>Body with <b>emphasis</b> inside.</span>")'
  out <- strip_message_wrappers(x)
  expect_false(grepl("<", out, fixed = TRUE))
  expect_false(grepl("Markdown(", out, fixed = TRUE))
})

test_that("parse_message_block extracts 3 title/body pairs in order", {
  lines <- c(
    "## Row Messages {height=10%}",
    "",
    "```{python}",
    "#| title: <b>Poverty Patterns and Trends</b>",
    "Markdown(\"<span style='font-size:16px;'>Body one.</span>\")",
    "```",
    "",
    "```{python}",
    "#| title: <b>Inequality</b>",
    "Markdown(\"<span style='font-size:16px;'>Body two.</span>\")",
    "```",
    "",
    "```{python}",
    "#| title: <b>Constraints</b>",
    "Markdown(\"<span style='font-size:16px;'>Body three.</span>\")",
    "```"
  )
  out <- parse_message_block(lines)
  expect_length(out, 3)
  expect_equal(vapply(out, `[[`, character(1), "title"), c("Poverty Patterns and Trends", "Inequality", "Constraints"))
  expect_equal(vapply(out, `[[`, character(1), "body"), c("Body one.", "Body two.", "Body three."))
})

test_that("parse_message_block stops at n pairs even when more titles follow", {
  lines <- c(
    "#| title: <b>A</b>",
    "Markdown(\"<span>1</span>\")",
    "#| title: <b>B</b>",
    "Markdown(\"<span>2</span>\")",
    "#| title: <b>C</b>",
    "Markdown(\"<span>3</span>\")",
    "#| title: <b>D</b>",
    "Markdown(\"<span>4</span>\")"
  )
  out <- parse_message_block(lines, n = 3)
  expect_length(out, 3)
  expect_equal(vapply(out, `[[`, character(1), "title"), c("A", "B", "C"))
})

test_that("extract_row_messages finds 2 blocks with 3 pairs each, and stays within its window", {
  lines <- c(
    rep("filler", 5),
    "## Row Messages {height=10%}",
    "#| title: <b>SEN 1</b>",
    "Markdown(\"<span>sen body 1</span>\")",
    "#| title: <b>SEN 2</b>",
    "Markdown(\"<span>sen body 2</span>\")",
    "#| title: <b>SEN 3</b>",
    "Markdown(\"<span>sen body 3</span>\")",
    rep("filler", 40),
    "## Row Messages {height=10%}",
    "#| title: <b>GNB 1</b>",
    "Markdown(\"<span>TEXT</span>\")",
    "#| title: <b>GNB 2</b>",
    "Markdown(\"<span>TEXT</span>\")",
    "#| title: <b>GNB 3</b>",
    "Markdown(\"<span>TEXT</span>\")"
  )
  blocks <- extract_row_messages(lines)
  expect_length(blocks, 2)
  expect_length(blocks[[1]], 3)
  expect_equal(blocks[[1]][[1]]$title, "SEN 1")
  expect_length(blocks[[2]], 3)
  expect_equal(blocks[[2]][[1]]$title, "GNB 1")
  expect_equal(blocks[[2]][[1]]$body, "TEXT")
})

test_that("read_about_paragraphs splits on a blank line and trims each paragraph", {
  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp))
  con <- file(tmp, open = "wb")
  writeLines(c("Paragraph one.", "", "Paragraph two."), con, sep = "\n")
  close(con)

  paras <- read_about_paragraphs(tmp)
  expect_equal(paras, c("Paragraph one.", "Paragraph two."))
})

test_that("read_about_paragraphs drops extra blank lines and trims whitespace", {
  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp))
  con <- file(tmp, open = "wb")
  writeLines(c("  Para A.  ", "", "", "   ", "Para B."), con, sep = "\n")
  close(con)

  paras <- read_about_paragraphs(tmp)
  expect_equal(paras, c("Para A.", "Para B."))
})
