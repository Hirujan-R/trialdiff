example_lineage <- function() {
  define_lineage(
    lineage_edge("ADSL.TRT01P", "ADLB.TRT01P", relationship = "groups_by"),
    lineage_edge("ADLB.AVAL", "ADLB.CHG", relationship = "derives"),
    lineage_edge("ADLB.AVAL", "MMRM", relationship = "models"),
    lineage_edge("MMRM", "Table_14_2_1", relationship = "reports")
  )
}

test_that("lineage_edge infers node types", {
  e <- lineage_edge("ADSL.TRT01P", "MMRM")
  expect_equal(e$from_type, "variable")
  expect_equal(e$to_type, "analysis")
  e2 <- lineage_edge("ADSL", "Table_1")
  expect_equal(e2$from_type, "dataset")
  expect_equal(e2$to_type, "output")
})

test_that("define_lineage builds a graph", {
  lin <- example_lineage()
  expect_s3_class(lin, "td_lineage")
  expect_equal(nrow(lin$edges), 4L)
  expect_true(all(c("ADSL.TRT01P", "ADLB.TRT01P", "ADLB.AVAL", "ADLB.CHG",
                    "MMRM", "Table_14_2_1") %in% lin$nodes$node))
})

test_that("define_lineage supports the convenience API", {
  lin <- define_lineage(
    dataset = "ADSL", variable = "TRT01P",
    downstream = c("MMRM", "Table_14_2_1")
  )
  expect_equal(nrow(lin$edges), 2L)
  expect_true(all(lin$edges$from == "ADSL.TRT01P"))
})

test_that("trace_dependencies walks downstream", {
  lin <- example_lineage()
  tr <- trace_dependencies(lin, from = "ADSL.TRT01P")
  expect_true("ADLB.TRT01P" %in% tr$node)
  expect_equal(tr$depth[tr$node == "ADLB.TRT01P"], 1L)

  tr2 <- trace_dependencies(lin, from = "ADLB.AVAL")
  expect_true("Table_14_2_1" %in% tr2$node)
  expect_match(tr2$path[tr2$node == "Table_14_2_1"], "ADLB.AVAL")
})

test_that("trace_dependencies walks upstream", {
  lin <- example_lineage()
  up <- trace_dependencies(lin, from = "Table_14_2_1", direction = "upstream")
  expect_true("MMRM" %in% up$node)
  expect_true("ADLB.AVAL" %in% up$node)
})

test_that("trace_dependencies respects max_depth and include_self", {
  lin <- example_lineage()
  shallow <- trace_dependencies(lin, from = "ADSL.TRT01P", max_depth = 1)
  expect_true(all(shallow$depth <= 1L))
  self <- trace_dependencies(lin, from = "ADSL.TRT01P", include_self = TRUE)
  expect_true("ADSL.TRT01P" %in% self$node)
  expect_equal(self$depth[self$node == "ADSL.TRT01P"], 0L)
})

test_that("trace_dependencies is cycle safe", {
  lin <- define_lineage(
    lineage_edge("A.V", "B.V"),
    lineage_edge("B.V", "A.V")
  )
  tr <- trace_dependencies(lin, from = "A.V")
  expect_true("B.V" %in% tr$node)
  expect_true(nrow(tr) < 10)
})

test_that("as_igraph works when igraph is installed", {
  skip_if_not_installed("igraph")
  g <- as_igraph(example_lineage())
  expect_s3_class(g, "igraph")
})

test_that("empty lineage traces return empty tibbles", {
  lin <- example_lineage()
  tr <- trace_dependencies(lin, from = "NOPE.V")
  expect_equal(nrow(tr), 0L)
  expect_true(all(c("node", "depth", "path") %in% names(tr)))
})
