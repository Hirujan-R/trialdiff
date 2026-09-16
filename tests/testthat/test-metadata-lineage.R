fake_metadata <- function() {
  list(
    ds_spec = data.frame(
      dataset = c("ADSL", "ADLB"),
      label = c("Subject-Level", "Lab"),
      stringsAsFactors = FALSE
    ),
    ds_vars = data.frame(
      dataset = c("ADSL", "ADSL", "ADLB", "ADLB", "ADLB", "ADLB"),
      variable = c("USUBJID", "TRT01P", "USUBJID", "PARAMCD", "AVAL", "CHG"),
      stringsAsFactors = FALSE
    ),
    value_spec = data.frame(
      dataset = c("ADSL", "ADLB", "ADLB"),
      variable = c("TRT01P", "AVAL", "CHG"),
      derivation_id = c("MT.ADSL.TRT01P", "MT.ADLB.AVAL", "MT.ADLB.CHG"),
      where = c(NA, "PARAMCD == 'ALT'", NA),
      stringsAsFactors = FALSE
    ),
    derivations = data.frame(
      derivation_id = c("MT.ADSL.TRT01P", "MT.ADLB.AVAL", "MT.ADLB.CHG"),
      derivation = c("DM.ARM", "ADSL.TRT01P", "AVAL - BASE"),
      stringsAsFactors = FALSE
    )
  )
}

edge_exists <- function(lin, from, to, relationship = NULL) {
  e <- lin$edges
  hit <- e$from == from & e$to == to
  if (!is.null(relationship)) {
    hit <- hit & e$relationship == relationship
  }
  any(hit)
}

test_that("lineage_from_metadata builds nodes and edges", {
  lin <- lineage_from_metadata(fake_metadata())
  expect_s3_class(lin, "td_lineage")
  expect_true(edge_exists(lin, "DM.ARM", "ADSL.TRT01P"))
  expect_true(edge_exists(lin, "ADSL.TRT01P", "ADLB.AVAL"))
  expect_true(edge_exists(lin, "ADLB.AVAL", "ADLB.CHG"))
  expect_true(edge_exists(lin, "ADLB.PARAMCD", "ADLB.AVAL", "filters"))
  expect_true(all(c("ADSL", "ADLB", "ADSL.TRT01P") %in% lin$nodes$node))
  expect_equal(nrow(lineage_review(lin)), 0L)
})

test_that("lineage_from_metadata honours include_where and include_sdtm", {
  no_where <- lineage_from_metadata(fake_metadata(), include_where = FALSE)
  expect_false(edge_exists(no_where, "ADLB.PARAMCD", "ADLB.AVAL", "filters"))
  expect_equal(nrow(no_where$edges), 3L)

  no_sdtm <- lineage_from_metadata(fake_metadata(), include_sdtm = FALSE)
  expect_false(edge_exists(no_sdtm, "DM.ARM", "ADSL.TRT01P"))
  expect_equal(nrow(no_sdtm$edges), 3L)
})

test_that("lineage_from_metadata records provenance", {
  lin <- lineage_from_metadata(fake_metadata())
  prov <- lineage_provenance(lin)
  expect_true(all(c("source", "derivation_id", "derivation") %in% names(prov)))
  expect_setequal(unique(prov$source),
                  c("metacore:derivation", "metacore:where"))
  expect_true(any(prov$derivation_id == "MT.ADLB.CHG"))
})

test_that("ambiguous and prose derivations are sent for review", {
  meta <- fake_metadata()
  meta$ds_vars <- rbind(
    meta$ds_vars,
    data.frame(dataset = "ADSL", variable = "FOO", stringsAsFactors = FALSE)
  )
  meta$value_spec <- rbind(
    meta$value_spec,
    data.frame(
      dataset = "ADLB", variable = "NEWVAR",
      derivation_id = c("MT.ADLB.NEWVAR"),
      where = NA_character_, stringsAsFactors = FALSE
    )
  )
  meta$derivations <- rbind(
    meta$derivations,
    data.frame(
      derivation_id = "MT.ADLB.NEWVAR",
      derivation = "FOO + 1",
      stringsAsFactors = FALSE
    )
  )
  # FOO exists in two other datasets (not ADLB) -> ambiguous
  meta$ds_vars <- rbind(
    meta$ds_vars,
    data.frame(dataset = "ADSL", variable = "FOO", stringsAsFactors = FALSE),
    data.frame(dataset = "ADAE", variable = "FOO", stringsAsFactors = FALSE)
  )

  lin <- lineage_from_metadata(meta)
  rev <- lineage_review(lin)
  expect_true(any(grepl("ambiguous", rev$reason)))
})

test_that("lineage_from_metadata warns when nothing can be parsed", {
  meta <- fake_metadata()
  meta$derivations$derivation <- "Assigned per SAP."
  expect_warning(
    lineage_from_metadata(meta, include_where = FALSE),
    class = "trialdiff_warning_metadata"
  )
})

test_that("lineage_from_metadata validates input", {
  expect_error(
    lineage_from_metadata(list(ds_vars = data.frame(a = 1))),
    class = "trialdiff_error_metadata"
  )
})

test_that("lineage_review and lineage_provenance validate input", {
  expect_error(lineage_review(list()), class = "trialdiff_error")
  expect_error(lineage_provenance("x"), class = "trialdiff_error")
})

test_that("metadata-derived lineage feeds trace and impact", {
  lin <- lineage_from_metadata(fake_metadata())
  tr <- trace_dependencies(lin, from = "DM.ARM")
  expect_true("ADLB.CHG" %in% tr$node)

  old <- data.frame(USUBJID = "S1", TRT01P = "Placebo")
  new <- data.frame(USUBJID = "S1", TRT01P = "Drug A")
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  )
  imp <- assess_impact(changes, lin)
  expect_true("ADLB.AVAL" %in% imp$impacts$node)
})

test_that("aliases resolve otherwise unresolved tokens", {
  meta <- fake_metadata()
  meta$ds_vars <- rbind(
    meta$ds_vars,
    data.frame(dataset = "ADLB", variable = "VISITNUM",
               stringsAsFactors = FALSE)
  )
  meta$value_spec <- rbind(
    meta$value_spec,
    data.frame(
      dataset = "ADLB", variable = "NEWVAR", derivation_id = "MT.ADLB.NEWVAR",
      where = NA_character_, stringsAsFactors = FALSE
    )
  )
  meta$derivations <- rbind(
    meta$derivations,
    data.frame(
      derivation_id = "MT.ADLB.NEWVAR", derivation = "WINDOW + 1",
      stringsAsFactors = FALSE
    )
  )
  # WINDOW is unknown -> no edge without an alias
  no_alias <- lineage_from_metadata(meta)
  expect_false(edge_exists(no_alias, "ADLB.WINDOW", "ADLB.NEWVAR"))

  with_alias <- lineage_from_metadata(
    meta,
    aliases = data.frame(token = "WINDOW", node = "ADLB.AVISIT",
                         stringsAsFactors = FALSE)
  )
  expect_true(edge_exists(with_alias, "ADLB.AVISIT", "ADLB.NEWVAR"))
})

test_that("aliases can be scoped to a dataset", {
  meta <- fake_metadata()
  meta$value_spec <- rbind(
    meta$value_spec,
    data.frame(
      dataset = "ADLB", variable = "ZZZ", derivation_id = "MT.ADLB.ZZZ",
      where = NA_character_, stringsAsFactors = FALSE
    )
  )
  meta$derivations <- rbind(
    meta$derivations,
    data.frame(derivation_id = "MT.ADLB.ZZZ", derivation = "TOKEN + 1",
               stringsAsFactors = FALSE)
  )
  scoped <- lineage_from_metadata(
    meta,
    aliases = data.frame(token = "TOKEN", node = "ADSL.TRT01P",
                         dataset = "ADSL", stringsAsFactors = FALSE)
  )
  expect_false(edge_exists(scoped, "ADSL.TRT01P", "ADLB.ZZZ"))

  global <- lineage_from_metadata(
    meta,
    aliases = data.frame(token = "TOKEN", node = "ADSL.TRT01P",
                         stringsAsFactors = FALSE)
  )
  expect_true(edge_exists(global, "ADSL.TRT01P", "ADLB.ZZZ"))
})

test_that("overrides merge a registry into metadata lineage", {
  lin <- lineage_from_metadata(
    fake_metadata(),
    overrides = output_registry(
      td_output("MMRM", depends_on = "ADLB.AVAL"),
      td_output("Table_1", depends_on = "MMRM", type = "output")
    )
  )
  expect_true(any(lin$edges$source == "registry"))
  expect_true("Table_1" %in% lin$nodes$node)
})

test_that("lineage_from_metadata validates aliases", {
  expect_error(
    lineage_from_metadata(fake_metadata(),
                          aliases = data.frame(a = 1)),
    class = "trialdiff_error"
  )
})

test_that("lineage_from_metadata works with a metacore object", {
  skip_if_not_installed("metacore")
  path <- system.file("extdata", "ADaM_define_CDISC_pilot3.xml",
                      package = "metacore")
  skip_if(!nzchar(path))
  mc <- suppressWarnings(
    metacore::define_to_metacore(path, verbose = "silent")
  )
  lin <- lineage_from_metadata(mc)
  expect_gt(nrow(lin$edges), 50L)
  expect_true(edge_exists(lin, "ADLBC.AVAL", "ADLBC.CHG"))
  expect_true(edge_exists(lin, "ADSL.TRT01P", "ADLBC.TRTP"))
  expect_true(any(lin$edges$source == "metacore:derivation"))
})
