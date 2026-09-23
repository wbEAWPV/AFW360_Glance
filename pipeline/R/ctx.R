# pipeline/R/ctx.R
#
# Builds the shared context object that every validator check receives.
# Depends on pipeline/R/io.R for read_std_csv() and load_metadata().

#' Build the shared pipeline context.
#'
#' @param root Repo root.
#' @param data_files Character vector of paths to standard data CSVs to
#'   load. Defaults to none.
#' @param opts A list of extra options, carried through unchanged.
#' @return A list with:
#'   \describe{
#'     \item{root}{`root`.}
#'     \item{meta}{`load_metadata(root)`.}
#'     \item{data}{A named list of tibbles from [read_std_csv()], keyed by
#'       each data file's base name (without extension).}
#'     \item{manifests}{A named list with the same keys, each a named
#'       character vector (key to value) read from the `<stem>_manifest.csv`
#'       file beside the data file, or an empty character vector when the
#'       manifest is missing.}
#'     \item{precision}{A named character vector taken from each manifest's
#'       `precision` entry, defaulting to `"EXACT"` when absent.}
#'     \item{opts}{`opts`.}
#'   }
build_ctx <- function(root, data_files = character(0), opts = list()) {
  meta <- load_metadata(root)

  data <- list()
  manifests <- list()
  precision <- character(0)

  for (f in data_files) {
    key <- tools::file_path_sans_ext(basename(f))
    data[[key]] <- read_std_csv(f)

    manifest_path <- file.path(dirname(f), paste0(key, "_manifest.csv"))
    if (file.exists(manifest_path)) {
      man_df <- read_std_csv(manifest_path)
      if (ncol(man_df) >= 2) {
        man_vec <- stats::setNames(
          as.character(man_df[[2]]),
          as.character(man_df[[1]])
        )
      } else {
        man_vec <- character(0)
      }
    } else {
      man_vec <- character(0)
    }
    manifests[[key]] <- man_vec

    if ("precision" %in% names(man_vec)) {
      precision[key] <- unname(man_vec[["precision"]])
    } else {
      precision[key] <- "EXACT"
    }
  }

  list(
    root = root,
    meta = meta,
    data = data,
    manifests = manifests,
    precision = precision,
    opts = opts
  )
}
