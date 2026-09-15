test_that("conditions carry trialdiff classes", {
  expect_error(trialdiff:::td_abort("boom"), class = "trialdiff_error")
  expect_error(
    trialdiff:::td_abort("boom", class = "trialdiff_error_custom"),
    class = "trialdiff_error_custom"
  )
  expect_warning(trialdiff:::td_warn("careful"), class = "trialdiff_warning")
  expect_message(trialdiff:::td_inform("hello"))
})

test_that("internal value helpers behave", {
  expect_equal(trialdiff:::td_format_value(c(1, 2)), "1, 2")
  expect_equal(trialdiff:::td_format_value(NA_real_), "<NA>")
  expect_equal(trialdiff:::td_format_value(character()), NA_character_)
  expect_equal(trialdiff:::td_type(1L), "integer")
  expect_equal(trialdiff:::td_type(structure(1, class = "foo")), "foo")
  expect_equal(trialdiff:::td_var_label(structure(1, label = "X")), "X")
  expect_true(is.na(trialdiff:::td_var_label(1)))
  expect_true(all(trialdiff:::td_values_equal(c(1, NA), c(1, NA))))
  expect_false(any(trialdiff:::td_values_equal(1:2, 1:3)))
  expect_true(trialdiff:::td_has_package("cli"))
  expect_false(trialdiff:::td_has_package("not_a_real_package_xyz"))
})

test_that("key helpers handle missing values and subjects", {
  d <- data.frame(a = c("x", NA), stringsAsFactors = FALSE)
  key <- trialdiff:::td_make_key(d, "a")
  expect_equal(key[2], "<NA>")
  expect_equal(
    trialdiff:::td_subject_of(d, subject_var = NULL, by = "a")[1],
    "x"
  )
})

test_that("compare_cut handles Date and POSIXct columns", {
  old <- data.frame(
    USUBJID = c("S1", "S2"),
    DTHDT = as.Date(c("2020-01-01", NA)),
    TRTSDTM = as.POSIXct(c("2020-01-01 10:00:00", "2020-01-02 09:00:00"),
                         tz = "UTC")
  )
  new <- old
  new$DTHDT[1] <- as.Date("2020-02-02")
  new$TRTSDTM[2] <- as.POSIXct("2020-01-03 09:00:00", tz = "UTC")

  d <- compare_cut(old, new, by = "USUBJID")
  expect_equal(nrow(d$modified), 2L)
  expect_setequal(d$modified$variable, c("DTHDT", "TRTSDTM"))
})

test_that("compare_cut handles NaN and NA as missing", {
  old <- data.frame(USUBJID = "S1", AVAL = NaN)
  new <- data.frame(USUBJID = "S1", AVAL = NA_real_)
  expect_equal(nrow(compare_cut(old, new, by = "USUBJID")$modified), 0L)
})

test_that("compare_cut handles empty cuts", {
  empty <- data.frame(USUBJID = character(), AVAL = numeric(),
                      stringsAsFactors = FALSE)
  old <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(1, 2))
  new <- data.frame(USUBJID = "S3", AVAL = 3)

  all_added <- compare_cut(empty, old, by = "USUBJID")
  expect_equal(nrow(all_added$added), 2L)
  expect_equal(nrow(all_added$removed), 0L)

  all_removed <- compare_cut(old, empty, by = "USUBJID")
  expect_equal(nrow(all_removed$removed), 2L)
  expect_equal(nrow(all_removed$added), 0L)

  both_empty <- compare_cut(empty, empty, by = "USUBJID")
  expect_equal(nrow(both_empty$added), 0L)
  expect_equal(nrow(as_register(both_empty)), 0L)
})

test_that("compare_cut supports multiple keys and ignore_vars", {
  old <- data.frame(
    USUBJID = c("S1", "S1"),
    PARAMCD = c("ALT", "AST"),
    AVAL = c(1, 2),
    AUDIT = c("a", "b"),
    stringsAsFactors = FALSE
  )
  new <- old
  new$AVAL[2] <- 3
  new$AUDIT <- c("z", "z")
  d <- compare_cut(old, new, by = c("USUBJID", "PARAMCD"),
                   ignore_vars = "AUDIT")
  expect_equal(nrow(d$modified), 1L)
  expect_equal(d$modified$variable, "AVAL")
})

test_that("compare_cut reports type and label changes only when asked", {
  old <- data.frame(USUBJID = "S1", X = 1)
  attr(old$X, "label") <- "Old"
  new <- data.frame(USUBJID = "S1", X = "1", stringsAsFactors = FALSE)
  attr(new$X, "label") <- "New"

  full <- compare_cut(old, new, by = "USUBJID")
  expect_setequal(full$schema$change, c("type_change", "label_change"))

  no_meta <- compare_cut(old, new, by = "USUBJID",
                         compare_labels = FALSE, compare_types = FALSE)
  expect_equal(nrow(no_meta$schema), 0L)
})

test_that("compare_cut infers the dataset and subject variable", {
  old <- data.frame(SUBJID = c("1", "2"), AVAL = c(1, 2),
                    stringsAsFactors = FALSE)
  new <- old
  new$AVAL[1] <- 9
  d <- compare_cut(old, new, by = "SUBJID")
  expect_equal(d$meta$subject_var, "SUBJID")
})

test_that("classification covers visit, record and schema categories", {
  old <- data.frame(USUBJID = "S1", VISIT = "V1", stringsAsFactors = FALSE)
  new <- data.frame(USUBJID = c("S1", "S1"), VISIT = c("V1", "V2"),
                    stringsAsFactors = FALSE)
  d <- classify_changes(compare_cut(old, new, by = c("USUBJID", "VISIT"),
                                    dataset = "ADVS"))
  expect_equal(d$added$category, "new_visit")
})

test_that("classification covers subject removal and record removal", {
  old <- data.frame(USUBJID = c("S1", "S2", "S2"), X = 1:3,
                    stringsAsFactors = FALSE)
  new <- data.frame(USUBJID = c("S1", "S2"), X = c(1, 2),
                    stringsAsFactors = FALSE)
  d <- classify_changes(compare_cut(old, new, by = c("USUBJID", "X"),
                                    dataset = "ADSL"))
  expect_true("record_removed" %in% d$removed$category)
})

test_that("classification covers variable removal and type change", {
  old <- data.frame(USUBJID = "S1", X = 1, Y = "a",
                    stringsAsFactors = FALSE)
  new <- data.frame(USUBJID = "S1", X = "1", stringsAsFactors = FALSE)
  d <- classify_changes(compare_cut(old, new, by = "USUBJID", dataset = "ADSL"))
  expect_true("variable_removed" %in% d$schema$category)
  expect_true("type_change" %in% d$schema$category)
})

test_that("classification retains all matching rules", {
  old <- data.frame(USUBJID = "S1", TRT01P = NA_character_)
  new <- data.frame(USUBJID = "S1", TRT01P = "Drug A")
  d <- classify_changes(compare_cut(old, new, by = "USUBJID", dataset = "ADSL"))
  expect_equal(d$modified$category, "treatment_assignment_change")
  expect_match(d$register$category_all, "missing_to_value")
})

test_that("classification context can be overridden", {
  old <- data.frame(USUBJID = "S1", X = 1)
  new <- data.frame(USUBJID = c("S1", "S1"), X = 1:2)
  d <- classify_changes(
    compare_cut(old, new, by = c("USUBJID", "X"), dataset = "CUSTOM"),
    context = list(has_paramcd = TRUE)
  )
  expect_equal(d$added$category, "new_assessment")
})

test_that("rules print and default rules are ordered", {
  expect_no_error(suppressMessages(capture.output(print(td_default_rules()[[1]]))))
  priorities <- vapply(td_default_rules(), function(r) r$priority, integer(1))
  expect_false(is.unsorted(priorities))
})

test_that("lineage accepts explicit node metadata and de-duplicates edges", {
  lin <- define_lineage(
    lineage_edge("A", "B"),
    lineage_edge("A", "B"),
    nodes = data.frame(
      node = c("A", "B"),
      type = c("dataset", "output"),
      label = c("Aye", "Bee"),
      stringsAsFactors = FALSE
    )
  )
  expect_equal(nrow(lin$edges), 1L)
  expect_equal(lin$nodes$type[lin$nodes$node == "B"], "output")
  expect_equal(lin$nodes$label[lin$nodes$node == "A"], "Aye")
})

test_that("lineage_edge recycles and validates", {
  e <- lineage_edge("A.V", c("B.V", "C.V"))
  expect_equal(nrow(e), 2L)
  expect_error(
    lineage_edge(c("A.V", "B.V"), c("C.V", "D.V", "E.V")),
    class = "trialdiff_error"
  )
})

test_that("define_lineage validates its inputs", {
  expect_error(define_lineage(), class = "trialdiff_error")
  expect_error(
    define_lineage(edges = data.frame(x = 1, y = 2)),
    class = "trialdiff_error"
  )
})

test_that("lineage print and summary work", {
  lin <- define_lineage(lineage_edge("ADSL.TRT01P", "MMRM"))
  expect_no_error(suppressMessages(capture.output(print(lin))))
  expect_no_error(suppressMessages(capture.output(summary(lin))))
})

test_that("as_igraph errors clearly without igraph", {
  lin <- define_lineage(lineage_edge("ADSL.TRT01P", "MMRM"))
  if (!requireNamespace("igraph", quietly = TRUE)) {
    expect_error(as_igraph(lin), class = "trialdiff_error")
  } else {
    expect_s3_class(as_igraph(lin), "igraph")
  }
})

test_that("assess_impact validates its inputs", {
  lin <- define_lineage(lineage_edge("ADSL.TRT01P", "MMRM"))
  changes <- classify_changes(
    compare_cut(
      data.frame(USUBJID = "S1", TRT01P = "Placebo"),
      data.frame(USUBJID = "S1", TRT01P = "Drug A"),
      by = "USUBJID", dataset = "ADSL"
    )
  )
  expect_error(assess_impact(changes, list()), class = "trialdiff_error")
  expect_error(assess_impact("nope", lin), class = "trialdiff_error")
})

test_that("assess_impact warns on an unclassified register", {
  lin <- define_lineage(lineage_edge("ADSL.TRT01P", "MMRM"))
  reg <- data.frame(
    record_type = "modified", variable = "TRT01P",
    old_value = "Placebo", new_value = "Drug A", change = "value",
    dataset = "ADSL", .subject = "S1", stringsAsFactors = FALSE
  )
  expect_warning(
    assess_impact(reg, lin),
    class = "trialdiff_warning_unclassified"
  )
})

test_that("assess_impact grades schema changes", {
  old <- data.frame(USUBJID = "S1", TRT01P = "Placebo")
  new <- data.frame(USUBJID = "S1", TRT01P = "Placebo", REGION = "EU")
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  )
  lin <- define_lineage(
    lineage_edge("ADSL.REGION", "Region_Summary", relationship = "groups_by"),
    lineage_edge("Region_Summary", "Table_1", relationship = "reports")
  )
  imp <- assess_impact(changes, lin)
  expect_true("Region_Summary" %in% imp$impacts$node)
  expect_true(all(imp$impacts$level %in% c("definitely_affected",
                                          "potentially_affected", "unlikely")))
})

test_that("impact policy and impact print/summary work", {
  expect_no_error(suppressMessages(capture.output(print(impact_policy()))))
  old <- data.frame(USUBJID = "S1", AVAL = 1)
  changes <- classify_changes(
    compare_cut(old, old, by = "USUBJID", dataset = "ADLB")
  )
  lin <- define_lineage(lineage_edge("ADLB.AVAL", "MMRM"))
  imp <- assess_impact(changes, lin)
  expect_no_error(suppressMessages(capture.output(print(imp))))
  expect_no_error(suppressMessages(capture.output(summary(imp))))
})

test_that("report_diff writes Quarto and list outputs", {
  old <- data.frame(USUBJID = "S1", AVAL = 1)
  new <- data.frame(USUBJID = "S1", AVAL = 2)
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADLB")
  )
  qmd <- withr::local_tempfile(fileext = ".qmd")
  report_diff(changes, output = qmd)
  expect_true(file.exists(qmd))
  expect_match(paste(readLines(qmd), collapse = "\n"), "trialdiff")

  rds <- withr::local_tempfile(fileext = ".rds")
  report_diff(changes, output = rds)
  expect_true(file.exists(rds))
})

test_that("report_diff handles no changes and disclaimer options", {
  old <- data.frame(USUBJID = "S1", AVAL = 1)
  changes <- classify_changes(
    compare_cut(old, old, by = "USUBJID", dataset = "ADLB")
  )
  rep <- report_diff(changes, include_disclaimer = FALSE)
  expect_match(rep$html, "No rows")
  expect_false(grepl("Disclaimer", rep$html, fixed = TRUE))
})

test_that("report_diff supports title, truncation and classified input", {
  old <- data.frame(USUBJID = sprintf("S%02d", 1:30), X = 1:30)
  new <- old
  new$X <- new$X + 1
  diff <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  classified <- classify_changes(diff)
  rep <- report_diff(diff, classified = classified, title = "Custom",
                     max_rows = 5L)
  expect_match(rep$html, "Custom")
  expect_match(rep$html, "Showing")
})

test_that("report printing and JSON work for every object", {
  old <- data.frame(USUBJID = "S1", AVAL = 1)
  new <- data.frame(USUBJID = "S1", AVAL = 2)
  diff <- compare_cut(old, new, by = "USUBJID", dataset = "ADLB")
  changes <- classify_changes(diff)
  lin <- define_lineage(lineage_edge("ADLB.AVAL", "MMRM"))
  imp <- assess_impact(changes, lin)

  expect_match(as_json(diff), "summary")
  expect_match(as_json(imp), "impacts")

  rep <- report_diff(changes, output = "list")
  expect_match(as_json(rep), "register")
  expect_no_error(suppressMessages(capture.output(print(report_diff(changes)))))
})

test_that("json helpers handle dates, lists and NULL", {
  expect_equal(trialdiff:::td_json_safe(as.Date("2020-01-01")), "2020-01-01")
  expect_equal(trialdiff:::td_json_safe(list(a = 1)), list(a = 1))
  expect_null(trialdiff:::td_json_safe(NULL))
})

test_that("format inference handles extensions", {
  expect_equal(trialdiff:::td_format_from_path("x.htm"), "html")
  expect_equal(trialdiff:::td_format_from_path("x.qmd"), "quarto")
  expect_equal(trialdiff:::td_format_from_path("x.json"), "json")
  expect_equal(trialdiff:::td_format_from_path("x.unknown"), "html")
})
