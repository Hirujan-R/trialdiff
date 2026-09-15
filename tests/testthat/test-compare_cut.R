make_adsl <- function() {
  data.frame(
    USUBJID = c("S1", "S2", "S3", "S4"),
    TRT01P = c("Placebo", "Drug A", "Drug B", "Placebo"),
    AGE = c(50, 60, 70, 80),
    SEX = c("F", "M", "F", "M"),
    stringsAsFactors = FALSE
  )
}

test_that("compare_cut detects added, removed and modified observations", {
  old <- make_adsl()
  new <- old[-3, ]
  new$AGE[new$USUBJID == "S1"] <- 51
  new <- rbind(new, data.frame(USUBJID = "S5", TRT01P = "Drug A",
                               AGE = 45, SEX = "F",
                               stringsAsFactors = FALSE))

  d <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL")

  expect_s3_class(d, "tdiff")
  expect_equal(nrow(d$added), 1L)
  expect_equal(nrow(d$removed), 1L)
  expect_equal(nrow(d$modified), 1L)
  expect_equal(d$modified$variable, "AGE")
  expect_equal(d$modified$change, "value")
  expect_equal(d$added$.subject, "S5")
  expect_equal(d$removed$.subject, "S3")
})

test_that("compare_cut distinguishes missingness transitions", {
  old <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(NA, 5))
  new <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(3, NA))

  d <- compare_cut(old, new, by = "USUBJID")
  expect_setequal(d$modified$change, c("missing_to_value", "value_to_missing"))
  expect_equal(d$modified$change[d$modified$.subject == "S1"], "missing_to_value")
  expect_equal(d$modified$change[d$modified$.subject == "S2"], "value_to_missing")
})

test_that("compare_cut reports schema changes", {
  old <- make_adsl()
  attr(old$AGE, "label") <- "Age"
  new <- old
  attr(new$AGE, "label") <- "Age at consent"
  new$REGION <- "EU"
  new$SEX <- as.factor(new$SEX)

  d <- compare_cut(old, new, by = "USUBJID")
  expect_setequal(
    d$schema$change,
    c("label_change", "variable_added", "type_change")
  )
  expect_true("REGION" %in% d$schema$variable[d$schema$change == "variable_added"])
})

test_that("compare_cut honours numeric tolerance", {
  old <- data.frame(USUBJID = "S1", AVAL = 1)
  new <- data.frame(USUBJID = "S1", AVAL = 1 + 1e-12)
  expect_equal(nrow(compare_cut(old, new, by = "USUBJID")$modified), 0L)
  expect_equal(
    nrow(compare_cut(old, new, by = "USUBJID", tolerance = 0)$modified),
    1L
  )
})

test_that("compare_cut validates keys", {
  old <- make_adsl()
  new <- old
  expect_error(
    compare_cut(old, new, by = "NOT_A_COLUMN"),
    class = "trialdiff_error_key"
  )
  dup <- rbind(old, old[1, ])
  expect_error(
    compare_cut(dup, new, by = "USUBJID"),
    class = "trialdiff_error_duplicate_keys"
  )
  expect_error(compare_cut(old, new, by = character()), class = "trialdiff_error")
})

test_that("compare_cut supports a waldo backend when available", {
  skip_if_not_installed("waldo")
  old <- make_adsl()
  new <- old
  new$AGE[1] <- 99
  d <- compare_cut(old, new, by = "USUBJID", backend = "waldo")
  expect_equal(nrow(d$modified), 1L)
})

test_that("compare_cut is empty-safe", {
  old <- make_adsl()
  d <- compare_cut(old, old, by = "USUBJID")
  expect_equal(nrow(d$added), 0L)
  expect_equal(nrow(d$removed), 0L)
  expect_equal(nrow(d$modified), 0L)
  expect_equal(nrow(d$schema), 0L)
})

test_that("as_register produces one row per change", {
  old <- make_adsl()
  new <- old
  new$AGE[1] <- 51
  new$REGION <- "EU"
  d <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  reg <- as_register(d)
  expect_equal(nrow(reg), nrow(d$modified) + nrow(d$schema))
  expect_true(all(c("record_type", "variable", "change", ".change_id") %in%
                    names(reg)))
  expect_false(anyDuplicated(reg$.change_id) > 0)
})
