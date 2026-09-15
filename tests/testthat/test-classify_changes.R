test_that("classify_changes labels treatment-assignment changes", {
  old <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Placebo", "Drug A"))
  new <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Drug A", "Drug A"))

  d <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL") |>
    classify_changes()

  expect_s3_class(d, "tdiff_classified")
  expect_true("treatment_assignment_change" %in% d$modified$category)
  expect_true(any(grepl("Treatment variable", d$modified$reason)))
  expect_equal(
    d$register$category[d$register$record_type == "modified"],
    "treatment_assignment_change"
  )
})

test_that("classify_changes distinguishes new subject from new assessment", {
  old <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(1, 2))
  new <- data.frame(USUBJID = c("S1", "S2", "S3"), AVAL = c(1, 2, 3))
  d <- classify_changes(compare_cut(old, new, by = "USUBJID", dataset = "ADSL"))
  expect_equal(d$added$category[d$added$.subject == "S3"], "new_subject")

  old_lb <- data.frame(USUBJID = "S1", PARAMCD = "ALT", AVAL = 1)
  new_lb <- data.frame(
    USUBJID = c("S1", "S1"),
    PARAMCD = c("ALT", "AST"),
    AVAL = c(1, 2)
  )
  d2 <- classify_changes(compare_cut(
    old_lb, new_lb,
    by = c("USUBJID", "PARAMCD"), dataset = "ADLB"
  ))
  expect_equal(d2$added$category, "new_assessment")
})

test_that("classify_changes labels missingness transitions", {
  old <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(NA, 5))
  new <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(3, NA))
  d <- classify_changes(compare_cut(old, new, by = "USUBJID"))
  expect_setequal(
    d$modified$category,
    c("missing_to_value", "value_to_missing")
  )
})

test_that("classify_changes labels derived-variable changes", {
  old <- data.frame(USUBJID = "S1", CHG = 1)
  new <- data.frame(USUBJID = "S1", CHG = 2)
  d <- classify_changes(compare_cut(old, new, by = "USUBJID", dataset = "ADLB"))
  expect_equal(d$modified$category, "derived_variable_change")
})

test_that("classify_changes labels schema changes", {
  old <- data.frame(USUBJID = "S1", X = 1)
  attr(old$X, "label") <- "X label"
  new <- data.frame(USUBJID = "S1", X = 1, Y = 2)
  attr(new$X, "label") <- "New label"
  d <- classify_changes(compare_cut(old, new, by = "USUBJID", dataset = "ADSL"))
  expect_setequal(
    d$schema$category,
    c("label_change", "variable_added")
  )
})

test_that("custom rules can be registered", {
  custom <- td_rule(
    "age_change", "Age change",
    priority = 1L,
    test = function(register, context) {
      register$record_type == "modified" & register$variable == "AGE"
    }
  )
  old <- data.frame(USUBJID = "S1", AGE = 40)
  new <- data.frame(USUBJID = "S1", AGE = 41)
  d <- classify_changes(
    compare_cut(old, new, by = "USUBJID"),
    rules = c(list(custom), td_default_rules())
  )
  expect_equal(d$modified$category, "age_change")
})

test_that("unmatched changes are flagged as unclassified", {
  old <- data.frame(USUBJID = "S1", WEIRD = 1)
  new <- data.frame(USUBJID = "S1", WEIRD = 2)
  d <- classify_changes(
    compare_cut(old, new, by = "USUBJID"),
    rules = list(td_rule("never", "Never", test = function(r, c) rep(FALSE, nrow(r))))
  )
  expect_equal(d$modified$category, "unclassified")
  expect_match(d$modified$reason, "manual review")
})

test_that("classify_changes works on a bare register", {
  reg <- data.frame(
    record_type = "modified",
    variable = "TRT01P",
    old_value = "Placebo",
    new_value = "Drug A",
    change = "value",
    dataset = "ADSL",
    .subject = "S1"
  )
  out <- classify_changes(reg)
  expect_equal(out$category, "treatment_assignment_change")
})

test_that("td_categories is well formed", {
  cats <- td_categories()
  expect_true(all(c("category", "label") %in% names(cats)))
  expect_false(anyDuplicated(cats$category) > 0)
})
