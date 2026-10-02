# 30-sdmx/pipeline/tests/testthat.R
#
# Run from 30-sdmx/:
#   Rscript pipeline/tests/testthat.R
# or:
#   Rscript -e "testthat::test_dir('pipeline/tests/testthat', stop_on_failure = TRUE)"

testthat::test_dir("pipeline/tests/testthat")
