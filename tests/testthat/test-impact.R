impact_lineage <- function() {
  define_lineage(
    lineage_edge("ADSL.TRT01P", "ADLB.TRT01P", relationship = "groups_by"),
    lineage_edge("ADLB.TRT01P", "Lab_Summary", relationship = "summarises"),
    lineage_edge("ADLB.AVAL", "ADLB.CHG", relationship = "derives"),
    lineage_edge("ADLB.AVAL", "MMRM", relationship = "models"),
    lineage_edge("MMRM", "Table_14_2_1", relationship = "reports")
  )
}

test_that("assess_impact flags direct derivations as definite", {
  old <- data.frame(USUBJID = "S1", TRT01P = "Placebo")
  new <- data.frame(USUBJID = "S1", TRT01P = "Drug A")
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  )
  imp <- assess_impact(changes, impact_lineage())
  expect_s3_class(imp, "td_impact")
  lvl <- imp$impacts$level[imp$impacts$node == "ADLB.TRT01P"]
  expect_equal(lvl, "definitely_affected")
})

test_that("assess_impact flags analyses and outputs as potential, not statistical", {
  old <- data.frame(USUBJID = "S1", AVAL = 1, BASE = 1, CHG = 0)
  new <- data.frame(USUBJID = "S1", AVAL = 2, BASE = 1, CHG = 1)
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADLB")
  )
  imp <- assess_impact(changes, impact_lineage())
  expect_true(all(
    imp$impacts$level[imp$impacts$node_type == "analysis"] ==
      "potentially_affected"
  ))
  expect_true(all(
    imp$impacts$level[imp$impacts$node_type == "output"] ==
      "potentially_affected"
  ))
  expect_true(all(imp$impacts$requires_rerun[imp$impacts$node == "MMRM"]))
  expect_match(
    imp$impacts$rationale[imp$impacts$node == "MMRM"],
    "Potentially affected"
  )
})

test_that("assess_impact reports unlinked changes", {
  old <- data.frame(USUBJID = "S1", FOO = 1)
  new <- data.frame(USUBJID = "S1", FOO = 2)
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  )
  imp <- assess_impact(changes, impact_lineage())
  expect_true("ADSL.FOO" %in% imp$unlinked$node)
})

test_that("assess_impact handles empty changes", {
  old <- data.frame(USUBJID = "S1", AVAL = 1)
  changes <- classify_changes(
    compare_cut(old, old, by = "USUBJID", dataset = "ADLB")
  )
  imp <- assess_impact(changes, impact_lineage())
  expect_equal(nrow(imp$impacts), 0L)
  expect_true(all(imp$summary$value == 0L))
})

test_that("impact_policy validates levels", {
  expect_s3_class(impact_policy(), "td_policy")
  expect_error(impact_policy(value_direct = "maybe"), class = "trialdiff_error")
})

test_that("impact_policy can downgrade direct effects", {
  old <- data.frame(USUBJID = "S1", TRT01P = "Placebo")
  new <- data.frame(USUBJID = "S1", TRT01P = "Drug A")
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  )
  imp <- assess_impact(
    changes, impact_lineage(),
    policy = impact_policy(value_direct = "potentially_affected")
  )
  lvl <- imp$impacts$level[imp$impacts$node == "ADLB.TRT01P"]
  expect_equal(lvl, "potentially_affected")
})

test_that("assess_impact records affected subjects", {
  old <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Placebo", "Drug A"))
  new <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Drug A", "Drug A"))
  changes <- classify_changes(
    compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
  )
  imp <- assess_impact(changes, impact_lineage())
  expect_true("S1" %in% imp$by_subject$subject)
})
