test_that("diffdf backend reproduces the built-in comparison", {
  skip_if_not_installed("diffdf")
  old <- data.frame(
    USUBJID = c("S1", "S2", "S3"),
    TRT01P = c("Placebo", "Drug A", "Drug B"),
    AGE = c(50, 60, 70),
    stringsAsFactors = FALSE
  )
  new <- data.frame(
    USUBJID = c("S1", "S2", "S4"),
    TRT01P = c("Drug A", "Drug A", "Placebo"),
    AGE = c(50, 61, 45),
    stringsAsFactors = FALSE
  )

  base <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  dd <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL",
                    backend = "diffdf")

  expect_s3_class(dd, "tdiff")
  expect_equal(sort(dd$added$USUBJID), sort(base$added$USUBJID))
  expect_equal(sort(dd$removed$USUBJID), sort(base$removed$USUBJID))
  expect_setequal(dd$modified$variable, base$modified$variable)
  expect_equal(nrow(dd$modified), nrow(base$modified))
  expect_equal(dd$schema, base$schema)
})

test_that("diffdf backend output classifies and assesses unchanged", {
  skip_if_not_installed("diffdf")
  old <- data.frame(USUBJID = c("S1", "S2"),
                    TRT01P = c("Placebo", "Drug A"),
                    stringsAsFactors = FALSE)
  new <- data.frame(USUBJID = c("S1", "S2"),
                    TRT01P = c("Drug A", "Drug A"),
                    stringsAsFactors = FALSE)

  dd <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL",
                    backend = "diffdf")
  classified <- classify_changes(dd)
  expect_true("treatment_assignment_change" %in% classified$modified$category)

  lin <- define_lineage(lineage_edge("ADSL.TRT01P", "MMRM",
                                     relationship = "models"))
  impact <- assess_impact(classified, lin)
  expect_true("MMRM" %in% impact$impacts$node)
})

test_that("diffdf backend detects missingness transitions", {
  skip_if_not_installed("diffdf")
  old <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(NA, 5))
  new <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(3, NA))
  dd <- compare_cut(old, new, by = "USUBJID", backend = "diffdf")
  expect_setequal(
    dd$modified$change,
    c("missing_to_value", "value_to_missing")
  )
})

test_that("diffdf backend honours ignore_vars", {
  skip_if_not_installed("diffdf")
  old <- data.frame(USUBJID = "S1", A = 1, AUDIT = "x",
                    stringsAsFactors = FALSE)
  new <- data.frame(USUBJID = "S1", A = 2, AUDIT = "y",
                    stringsAsFactors = FALSE)
  dd <- compare_cut(old, new, by = "USUBJID", ignore_vars = "AUDIT",
                    backend = "diffdf")
  expect_equal(dd$modified$variable, "A")
})

test_that("diffdf backend handles no differences", {
  skip_if_not_installed("diffdf")
  old <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(1, 2))
  dd <- compare_cut(old, old, by = "USUBJID", backend = "diffdf")
  expect_equal(nrow(dd$added), 0L)
  expect_equal(nrow(dd$removed), 0L)
  expect_equal(nrow(dd$modified), 0L)
})

test_that("diffdf backend errors clearly when diffdf is missing", {
  skip_if(requireNamespace("diffdf", quietly = TRUE))
  expect_error(
    compare_cut(
      data.frame(USUBJID = "S1"),
      data.frame(USUBJID = "S1"),
      by = "USUBJID",
      backend = "diffdf"
    ),
    class = "trialdiff_error_backend"
  )
})
