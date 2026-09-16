# Case study: data-cut review on public ADaM data

This case study runs the full `trialdiff` pipeline on the public
`pharmaverseadam` datasets: two data cuts are compared, changes are
classified, lineage is generated from metadata and an output registry,
downstream impact is assessed, and a review report is produced. No
proprietary data is used.

``` r

library(trialdiff)
```

## The two data cuts

We use `ADSL` and a subset of `ADLB` (three laboratory parameters) and
build a later cut that introduces the kinds of changes seen in practice:
two new subjects, a treatment-assignment correction, a corrected
laboratory value and a value that becomes missing.

``` r

params <- c("ALT", "AST", "CREAT")
adsl_full <- pharmaverseadam::adsl
adlb_full <- subset(pharmaverseadam::adlb, PARAMCD %in% params)

subjects <- unique(as.character(adsl_full$USUBJID))
new_subjects <- tail(subjects, 2)

adsl_cut1 <- adsl_full[!adsl_full$USUBJID %in% new_subjects, ]
adlb_cut1 <- adlb_full[!adlb_full$USUBJID %in% new_subjects, ]
adsl_cut2 <- adsl_full
adlb_cut2 <- adlb_full

trt_subject <- adsl_cut2$USUBJID[which(adsl_cut2$TRT01P == "Placebo")[1]]
for (v in c("TRT01P", "TRT01A")) {
  adsl_cut2[[v]][adsl_cut2$USUBJID == trt_subject] <- "Xanomeline Low Dose"
}
for (v in c("TRT01P", "TRTP")) {
  adlb_cut2[[v]][adlb_cut2$USUBJID == trt_subject] <- "Xanomeline Low Dose"
}

i <- which(adlb_cut2$USUBJID == trt_subject & adlb_cut2$PARAMCD == "ALT" &
             adlb_cut2$AVISIT == "Week 4")[1]
adlb_cut2$AVAL[i] <- adlb_cut2$AVAL[i] + 7
adlb_cut2$CHG[i] <- adlb_cut2$AVAL[i] - adlb_cut2$BASE[i]

j <- which(adlb_cut2$PARAMCD == "AST" & adlb_cut2$AVISIT == "Week 2")[1]
adlb_cut2$AVAL[j] <- NA_real_
adlb_cut2$CHG[j] <- NA_real_

c(adsl = nrow(adsl_cut2) - nrow(adsl_cut1), adlb = nrow(adlb_cut2) - nrow(adlb_cut1))
#> adsl adlb 
#>    2   51
```

## Lineage from metadata plus a registry

The data and derived-variable portion of the lineage comes from a small
metadata specification (the same shape as a `metacore` object). Analyses
and outputs are declared with
[`output_registry()`](https://Hirujan-R.github.io/trialdiff/reference/output_registry.md)
and grafted on with `overrides`.

``` r

metadata <- list(
  ds_spec = data.frame(
    dataset = c("ADSL", "ADLB"),
    label = c("Subject-Level Analysis", "Laboratory Analysis")
  ),
  ds_vars = data.frame(
    dataset = c("ADSL", "ADSL", "ADSL", "ADLB", "ADLB", "ADLB", "ADLB", "ADLB"),
    variable = c("USUBJID", "TRT01P", "SAFFL", "USUBJID", "PARAMCD",
                 "TRT01P", "AVAL", "CHG")
  ),
  value_spec = data.frame(
    dataset = c("ADSL", "ADLB", "ADLB", "ADLB", "ADLB"),
    variable = c("TRT01P", "TRT01P", "AVAL", "BASE", "CHG"),
    derivation_id = c("MT.ADSL.TRT01P", "MT.ADLB.TRT01P", "MT.ADLB.AVAL",
                      "MT.ADLB.BASE", "MT.ADLB.CHG"),
    where = c(NA, NA, "PARAMCD == 'ALT'", NA, NA)
  ),
  derivations = data.frame(
    derivation_id = c("MT.ADSL.TRT01P", "MT.ADLB.TRT01P", "MT.ADLB.AVAL",
                      "MT.ADLB.BASE", "MT.ADLB.CHG"),
    derivation = c("DM.ARM", "ADSL.TRT01P", "LB.LBSTRESN", "ADLB.AVAL",
                   "AVAL - BASE")
  )
)

registry <- output_registry(
  td_output("Lab_Summary_By_Treatment",
            depends_on = c("ADLB.TRT01P", "ADLB.AVAL"),
            type = "analysis", relationship = "summarises"),
  td_output("MMRM", depends_on = c("ADLB.AVAL", "ADLB.CHG")),
  td_output("Table_14_2_1", depends_on = "Lab_Summary_By_Treatment",
            type = "output"),
  td_output("Table_14_2_2", depends_on = "MMRM", type = "output")
)

lineage <- lineage_from_metadata(metadata, overrides = registry)
lineage
#> 
#> ── trialdiff lineage ───────────────────────────────────────────────────────────
#> 12 edges, 17 nodes
#> analysis: 2
#> dataset: 2
#> output: 2
#> variable: 11
```

The generated graph reaches from the raw source through derived
variables to analyses and TLFs, and every edge keeps its provenance:

``` r

lineage_provenance(lineage)[, c("from", "to", "relationship", "source")]
#> # A tibble: 12 × 4
#>    from                     to                       relationship source        
#>    <chr>                    <chr>                    <chr>        <chr>         
#>  1 DM.ARM                   ADSL.TRT01P              derives      metacore:deri…
#>  2 ADSL.TRT01P              ADLB.TRT01P              derives      metacore:deri…
#>  3 LB.LBSTRESN              ADLB.AVAL                derives      metacore:deri…
#>  4 ADLB.PARAMCD             ADLB.AVAL                filters      metacore:where
#>  5 ADLB.AVAL                ADLB.BASE                derives      metacore:deri…
#>  6 ADLB.AVAL                ADLB.CHG                 derives      metacore:deri…
#>  7 ADLB.TRT01P              Lab_Summary_By_Treatment summarises   registry      
#>  8 ADLB.AVAL                Lab_Summary_By_Treatment summarises   registry      
#>  9 ADLB.AVAL                MMRM                     models       registry      
#> 10 ADLB.CHG                 MMRM                     models       registry      
#> 11 Lab_Summary_By_Treatment Table_14_2_1             reports      registry      
#> 12 MMRM                     Table_14_2_2             reports      registry
```

## Compare and classify

``` r

adsl_diff <- compare_cut(adsl_cut1, adsl_cut2, by = "USUBJID",
                         dataset = "ADSL") |>
  classify_changes()
adlb_diff <- compare_cut(adlb_cut1, adlb_cut2,
                         by = c("USUBJID", "PARAMCD", "AVISIT"),
                         dataset = "ADLB") |>
  classify_changes()

knitr::kable(table(adsl_diff$register$category_label),
             col.names = c("Category", "ADSL"))
```

| Category                    | ADSL |
|:----------------------------|-----:|
| New subject                 |    2 |
| Treatment-assignment change |    2 |

``` r

knitr::kable(table(adlb_diff$register$category_label),
             col.names = c("Category", "ADLB"))
```

| Category                    | ADLB |
|:----------------------------|-----:|
| Derived-variable change     |    2 |
| New subject                 |   51 |
| Non-missing to missing      |    2 |
| Treatment-assignment change |   78 |

## Assess downstream impact

``` r

adlb_impact <- assess_impact(adlb_diff, lineage)
adlb_impact$impacts[, c("node", "node_type", "level", "depth", "requires_rerun")]
#> # A tibble: 7 × 5
#>   node                     node_type level                depth requires_rerun
#>   <chr>                    <chr>     <chr>                <int> <lgl>         
#> 1 ADLB.BASE                variable  definitely_affected      1 FALSE         
#> 2 ADLB.CHG                 variable  definitely_affected      1 FALSE         
#> 3 ADLB.AVAL                variable  potentially_affected     1 FALSE         
#> 4 Lab_Summary_By_Treatment analysis  potentially_affected     1 TRUE          
#> 5 MMRM                     analysis  potentially_affected     1 TRUE          
#> 6 Table_14_2_1             output    potentially_affected     2 TRUE          
#> 7 Table_14_2_2             output    potentially_affected     2 TRUE
```

A treatment-assignment change flows to `ADLB.TRT01P`, the by-treatment
summary and the MMRM, and every analysis or output is flagged for review
or rerun. No statistical impact is claimed.

## Review report

``` r

report <- report_diff(adsl_diff,
                      impact = assess_impact(adsl_diff, lineage),
                      output = "list")
report$data$review_items
#> # A tibble: 3 × 3
#>   item           detail                                                    owner
#>   <chr>          <chr>                                                     <chr>
#> 1 Rerun required Lab_Summary_By_Treatment (potentially_affected) - Potent… Stat…
#> 2 Rerun required Table_14_2_1 (potentially_affected) - Potentially affect… Stat…
#> 3 Lineage gap    1 changed node(s) have no declared lineage: ADSL.TRT01A.  Prog…
```

Writing `report_diff(..., output = "cut-review.html")` produces a
self-contained HTML report, and
[`as_json()`](https://Hirujan-R.github.io/trialdiff/reference/as_json.md)
produces machine-readable output for automated QC pipelines.

## What this demonstrates

- Deterministic comparison of two real data cuts, with clinical
  classification.
- Lineage generated from metadata, extended with an analysis/output
  registry.
- Transparent impact assessment that reaches TLFs and never claims
  statistical significance.
- A single workflow:
  [`compare_cut()`](https://Hirujan-R.github.io/trialdiff/reference/compare_cut.md)
  -\>
  [`classify_changes()`](https://Hirujan-R.github.io/trialdiff/reference/classify_changes.md)
  -\>
  [`lineage_from_metadata()`](https://Hirujan-R.github.io/trialdiff/reference/lineage_from_metadata.md) +
  [`output_registry()`](https://Hirujan-R.github.io/trialdiff/reference/output_registry.md)
  -\>
  [`assess_impact()`](https://Hirujan-R.github.io/trialdiff/reference/assess_impact.md)
  -\>
  [`report_diff()`](https://Hirujan-R.github.io/trialdiff/reference/report_diff.md).

## Limitations

- The metadata above is a compact illustration; a real study would load
  it from Define-XML with
  [`metacore::define_to_metacore()`](https://atorus-research.github.io/metacore/reference/define_to_metacore.html).
- Analysis/output dependencies are not described by data metadata and
  must be supplied by the study team (here, via
  [`output_registry()`](https://Hirujan-R.github.io/trialdiff/reference/output_registry.md)).
- Impact is a review signal. Confirming whether a summary or model
  result actually changes requires rerunning it.
