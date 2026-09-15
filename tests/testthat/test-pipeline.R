test_that("synthetic datasets have the expected structure", {
  expect_s3_class(adsl_cut1, "data.frame")
  expect_s3_class(adsl_cut2, "data.frame")
  expect_s3_class(adlb_cut1, "data.frame")
  expect_s3_class(adlb_cut2, "data.frame")
  expect_true(all(c("USUBJID", "TRT01P", "AGE") %in% names(adsl_cut1)))
  expect_true(all(c("USUBJID", "PARAMCD", "AVISIT", "AVAL", "CHG") %in%
                    names(adlb_cut1)))
  expect_false(anyDuplicated(adsl_cut1$USUBJID) > 0)
  expect_false(anyDuplicated(paste(adlb_cut1$USUBJID, adlb_cut1$PARAMCD,
                                   adlb_cut1$AVISIT)) > 0)
})

test_that("the example lineage is a valid td_lineage", {
  expect_s3_class(adsl_adlb_lineage, "td_lineage")
  expect_true(nrow(adsl_adlb_lineage$edges) > 0L)
})

test_that("the full pipeline runs end to end", {
  diff <- compare_cut(adsl_cut1, adsl_cut2, by = "USUBJID", dataset = "ADSL")
  classified <- classify_changes(diff)
  impact <- assess_impact(classified, adsl_adlb_lineage)
  report <- report_diff(diff, impact = impact, output = "list")

  expect_gt(nrow(classified$register), 0L)
  expect_gt(nrow(impact$impacts), 0L)
  expect_true(any(impact$impacts$requires_rerun))
  expect_s3_class(report, "td_report")
})

test_that("ADLB treatment grouping is reachable from an ADSL treatment change", {
  diff <- compare_cut(adsl_cut1, adsl_cut2, by = "USUBJID", dataset = "ADSL")
  classified <- classify_changes(diff)
  impact <- assess_impact(classified, adsl_adlb_lineage)
  expect_true("ADLB.TRT01P" %in% impact$impacts$node)
  expect_true("MMRM" %in% impact$impacts$node)
  expect_true("Table_14_2_2" %in% impact$impacts$node)
})
