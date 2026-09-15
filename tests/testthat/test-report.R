test_that("report_diff produces HTML", {
  old <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Placebo", "Drug A"))
  new <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Drug A", "Drug A"))
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  )
  rep <- report_diff(changes, output = "html")
  expect_s3_class(rep, "td_report")
  expect_match(rep$html, "<html>")
  expect_match(rep$html, "Data-cut change review")
  expect_match(rep$html, "Disclaimer")
})

test_that("report_diff writes an HTML file and infers format from extension", {
  skip_if_not_installed("htmltools")
  old <- data.frame(USUBJID = "S1", AVAL = 1)
  new <- data.frame(USUBJID = "S1", AVAL = 2)
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADLB")
  )
  path <- withr::local_tempfile(fileext = ".html")
  rep <- report_diff(changes, output = path)
  expect_true(file.exists(path))
  expect_equal(rep$format, "html")
  expect_true(file.info(path)$size > 0)
})

test_that("report_diff writes JSON", {
  old <- data.frame(USUBJID = "S1", AVAL = 1)
  new <- data.frame(USUBJID = "S1", AVAL = 2)
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADLB")
  )
  path <- withr::local_tempfile(fileext = ".json")
  report_diff(changes, output = path)
  expect_true(file.exists(path))
  parsed <- jsonlite::fromJSON(path)
  expect_true("register" %in% names(parsed))
})

test_that("report_diff includes impact when supplied", {
  old <- data.frame(USUBJID = "S1", TRT01P = "Placebo")
  new <- data.frame(USUBJID = "S1", TRT01P = "Drug A")
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  )
  lin <- define_lineage(
    lineage_edge("ADSL.TRT01P", "MMRM", relationship = "models"),
    lineage_edge("MMRM", "Table_1", relationship = "reports")
  )
  imp <- assess_impact(changes, lin)
  rep <- report_diff(changes, impact = imp)
  expect_match(rep$html, "Downstream impact")
  expect_true(nrow(rep$data$review_items) > 0L)
})

test_that("as_json works for tdiff and impact", {
  old <- data.frame(USUBJID = "S1", AVAL = 1)
  new <- data.frame(USUBJID = "S1", AVAL = 2)
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADLB")
  )
  expect_match(as_json(changes), "register")
  lin <- define_lineage(lineage_edge("ADLB.AVAL", "MMRM"))
  imp <- assess_impact(changes, lin)
  expect_match(as_json(imp), "impacts")
})

test_that("report_diff validates input", {
  expect_error(report_diff("not a tdiff"), class = "trialdiff_error")
})
