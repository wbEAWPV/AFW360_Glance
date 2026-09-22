root <- find_root()
source(file.path(root, "pipeline", "R", "codes.R"))

test_that("is_valid_code accepts well-formed codes", {
  expect_true(all(is_valid_code(c("SN01", "POV_HC"))))
})

test_that("is_valid_code rejects reserved prefixes, lower case, a leading digit and over-length codes", {
  long33 <- paste0("A", strrep("B", 32))
  expect_equal(nchar(long33), 33)
  bad <- c("_T", "_ZX", "pov_hc", "1A", long33)
  expect_true(all(!is_valid_code(bad)))
})

test_that("is_valid_code treats NA as invalid", {
  expect_false(is_valid_code(NA_character_))
})

test_that("slot_sort orders codes by slot_order, ties broken by var_code", {
  codes <- c("HE_COUNT_0", "QUINT_Q1")
  var_of <- c(HE_COUNT_0 = "HE_COUNT", QUINT_Q1 = "QUINT")
  slot_order_of <- c(HE_COUNT = "50", QUINT = "10")
  expect_equal(slot_sort(codes, var_of, slot_order_of), c("QUINT_Q1", "HE_COUNT_0"))
})

test_that("slot_sort stops on a code var_of does not know", {
  expect_error(slot_sort("X", c(A = "V"), c(V = "1")))
})

test_that("fill_slots pads codes to length n and stops when there are too many", {
  expect_equal(fill_slots("A", 3, "_T"), c("A", "_T", "_T"))
  expect_equal(fill_slots(character(0), 2, "_Z"), c("_Z", "_Z"))
  expect_error(fill_slots(c("A", "B", "C", "D"), 3, "_T"))
})
