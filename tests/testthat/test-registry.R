test_that("td_output validates and sets defaults", {
  a <- td_output("MMRM", depends_on = "ADLB.AVAL")
  expect_equal(a$relationship, "models")
  expect_equal(a$to_type, "analysis")
  o <- td_output("Table_1", depends_on = "MMRM", type = "output")
  expect_equal(o$relationship, "reports")
  expect_equal(o$to_type, "output")

  expect_error(td_output("", depends_on = "X"), class = "trialdiff_error")
  expect_error(td_output("A", depends_on = character()), class = "trialdiff_error")
})

test_that("output_registry combines declarations", {
  reg <- output_registry(
    td_output("MMRM", depends_on = c("ADLB.AVAL", "ADLB.CHG")),
    td_output("Table_1", depends_on = "MMRM", type = "output")
  )
  expect_equal(nrow(reg), 3L)
  expect_true(all(reg$source == "registry"))
  expect_error(output_registry(), class = "trialdiff_error")
  expect_error(output_registry("nope"), class = "trialdiff_error")
})

test_that("add_outputs grafts analyses and outputs onto a graph", {
  lin <- define_lineage(
    lineage_edge("ADLB.AVAL", "ADLB.CHG", relationship = "derives")
  )
  reg <- output_registry(
    td_output("MMRM", depends_on = c("ADLB.AVAL", "ADLB.CHG")),
    td_output("Table_14_2_1", depends_on = "MMRM", type = "output")
  )
  lin2 <- add_outputs(lin, reg)
  expect_s3_class(lin2, "td_lineage")
  expect_equal(nrow(lin2$edges), 4L)
  tr <- trace_dependencies(lin2, from = "ADLB.AVAL")
  expect_true("MMRM" %in% tr$node)
  expect_true("Table_14_2_1" %in% tr$node)
  expect_true("output" %in% lin2$nodes$type)
})

test_that("add_edges supports a source override and preserves review", {
  lin <- lineage_from_metadata(list(
    ds_spec = data.frame(dataset = "ADSL"),
    ds_vars = data.frame(dataset = "ADSL", variable = "TRT01P"),
    value_spec = data.frame(
      dataset = "ADSL", variable = "TRT01P",
      derivation_id = "MT.ADSL.TRT01P", where = NA_character_
    ),
    derivations = data.frame(
      derivation_id = "MT.ADSL.TRT01P", derivation = "DM.ARM"
    )
  ))
  lin2 <- add_edges(
    lin,
    lineage_edge("DM.AGE", "ADSL.AGE"),
    source = "manual"
  )
  expect_true(any(lin2$edges$source == "manual"))
  expect_true("review" %in% names(lin2))
})

test_that("remove_edges filters by from, to, relationship and source", {
  reg <- output_registry(
    td_output("MMRM", depends_on = "ADLB.AVAL"),
    td_output("Table_1", depends_on = "MMRM", type = "output")
  )
  lin <- add_outputs(define_lineage(lineage_edge("ADLB.AVAL", "ADLB.CHG")), reg)

  expect_equal(nrow(remove_edges(lin, to = "MMRM")$edges), 2L)
  expect_equal(nrow(remove_edges(lin, source = "registry")$edges), 1L)
  expect_equal(nrow(remove_edges(lin, relationship = "reports")$edges), 2L)
  expect_equal(nrow(remove_edges(lin, from = "ADLB.AVAL")$edges), 1L)
})

test_that("edge helpers validate input", {
  expect_error(add_edges(list(), lineage_edge("A", "B")), class = "trialdiff_error")
  expect_error(remove_edges("x"), class = "trialdiff_error")
  lin <- define_lineage(lineage_edge("A", "B"))
  expect_error(add_edges(lin, "not a table"), class = "trialdiff_error")
})
