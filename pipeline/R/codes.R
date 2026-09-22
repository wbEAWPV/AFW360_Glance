# pipeline/R/codes.R
#
# Code validation and ordering helpers shared by the pipeline and its
# validators (COMMON.md section 4).

#' Whether each element is a well-formed code.
#'
#' A valid code is uppercase ASCII letters, digits and `_`, starts with a
#' letter, has at most 32 characters, and does not start with the reserved
#' `_T` or `_Z` sentinel prefixes.
#'
#' @param x A character vector.
#' @return A logical vector, the same length as `x`.
is_valid_code <- function(x) {
  x <- as.character(x)
  ok <- grepl("^[A-Z][A-Z0-9_]{0,31}$", x, perl = TRUE)
  ok <- ok & !grepl("^(_T|_Z)", x, perl = TRUE)
  ok[is.na(x)] <- FALSE
  ok
}

#' Order category codes by their variable's slot order.
#'
#' @param codes A character vector of category codes.
#' @param var_of A named character vector mapping each category code to its
#'   `var_code`.
#' @param slot_order_of A named vector mapping each `var_code` to its
#'   `slot_order` (coerced to integer).
#' @return `codes`, ordered by slot order, ties broken by `var_code`.
slot_sort <- function(codes, var_of, slot_order_of) {
  missing <- setdiff(codes, names(var_of))
  if (length(missing) > 0) {
    stop(
      "slot_sort: unknown code(s): ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  vars <- unname(var_of[codes])
  orders <- suppressWarnings(as.integer(slot_order_of[vars]))
  codes[order(orders, vars)]
}

#' Pad a vector of codes to a fixed length.
#'
#' @param codes A character vector of codes.
#' @param n Target length (default 5).
#' @param pad The padding value used to fill the remaining slots.
#' @return `codes`, followed by `pad` repeated to length `n`.
fill_slots <- function(codes, n = 5, pad) {
  if (length(codes) > n) {
    stop(
      "fill_slots: ", length(codes), " codes exceed the maximum of ", n,
      call. = FALSE
    )
  }
  c(codes, rep(pad, n - length(codes)))
}
