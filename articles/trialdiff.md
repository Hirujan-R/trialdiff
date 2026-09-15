# Getting started with trialdiff

## Why trialdiff?

Clinical trial datasets are regenerated many times during a study.
Between two data cuts, observations are added, removed or corrected,
derivations change, and metadata evolves. Generic tools such as `diffdf`
and `waldo` can tell you *that* two datasets differ. `trialdiff` answers
the clinical-programming question that comes next:

> What changed, what does the change represent, and which downstream
> analyses or outputs might be affected?

`trialdiff` is organised into five layers, each usable on its own:

1.  **Compare** - \[compare_cut()\]
2.  **Classify** - \[classify_changes()\]
3.  **Trace** - \[define_lineage()\], \[trace_dependencies()\]
4.  **Assess** - \[assess_impact()\]
5.  **Report** - \[report_diff()\]

All five layers are deterministic and rule-based. Nothing is inferred by
an opaque model, and no statistical significance is ever claimed.

## The example data

The package ships synthetic `ADSL` and `ADLB` data cuts. No proprietary
data is used.

``` r

library(trialdiff)
str(adsl_cut1, max.level = 1)
#> 'data.frame':    30 obs. of  11 variables:
#>  $ STUDYID: chr  "TD001" "TD001" "TD001" "TD001" ...
#>  $ USUBJID: chr  "TD001-S001" "TD001-S002" "TD001-S003" "TD001-S004" ...
#>  $ SUBJID : chr  "S001" "S002" "S003" "S004" ...
#>  $ SITEID : chr  "01" "02" "03" "04" ...
#>  $ AGE    : int  46 74 50 55 62 64 44 61 53 65 ...
#>  $ SEX    : chr  "F" "M" "F" "M" ...
#>  $ RACE   : chr  "WHITE" "BLACK OR AFRICAN AMERICAN" "WHITE" "BLACK OR AFRICAN AMERICAN" ...
#>  $ TRT01P : chr  "Placebo" "Placebo" "Drug A" "Drug B" ...
#>  $ SAFFL  : chr  "Y" "Y" "Y" "Y" ...
#>  $ ITTFL  : chr  "Y" "Y" "Y" "Y" ...
#>  $ TRT01A : chr  "Placebo" "Placebo" "Drug A" "Drug B" ...
```

## 1. Compare two data cuts

``` r

diff <- compare_cut(
  old = adsl_cut1,
  new = adsl_cut2,
  by = "USUBJID",
  dataset = "ADSL"
)
diff
#> 
#> ── trialdiff comparison ────────────────────────────────────────────────────────
#> ADSL: old → new
#> Keys: "USUBJID"
#> Observations: 30 → 31 (29 matched)
#> Added: 2 Removed: 1 Modified cells: 6
#> Schema changes: 2
```

The result is a `tdiff` object with `added`, `removed`, `modified` and
`schema` tables. For example, the treatment-assignment change:

``` r

diff$modified[, c("USUBJID", "variable", "old_value", "new_value", "change")]
#> # A tibble: 6 × 5
#>   USUBJID    variable old_value                 new_value change          
#>   <chr>      <chr>    <chr>                     <chr>     <chr>           
#> 1 TD001-S007 AGE      44                        45        value           
#> 2 TD001-S011 AGE      22                        21        value           
#> 3 TD001-S014 SEX      M                         <NA>      value_to_missing
#> 4 TD001-S018 RACE     BLACK OR AFRICAN AMERICAN WHITE     value           
#> 5 TD001-S005 TRT01P   Placebo                   Drug A    value           
#> 6 TD001-S005 TRT01A   Placebo                   Drug A    value
```

## 2. Classify the changes

``` r

classified <- classify_changes(diff)
table(classified$register$category_label)
#> 
#>             Corrected value                 New subject 
#>                           3                           2 
#>      Non-missing to missing             Subject removed 
#>                           1                           1 
#> Treatment-assignment change                 Type change 
#>                           2                           1 
#>              Variable added 
#>                           1
```

Every classification carries a plain-language explanation:

``` r

classified$register$reason[classified$register$category == "treatment_assignment_change"]
#> [1] "Treatment variable 'TRT01P' changed from 'Placebo' to 'Drug A' for subject 'TD001-S005'."
#> [2] "Treatment variable 'TRT01A' changed from 'Placebo' to 'Drug A' for subject 'TD001-S005'."
```

## 3. Define lineage

Lineage is explicit metadata. Nodes are datasets (`ADSL`), variables
(`ADSL.TRT01P`), analyses (`MMRM`) or outputs (`Table_14_2_1`).

``` r

lineage <- define_lineage(
  lineage_edge("ADSL.TRT01P", "ADLB.TRT01P", relationship = "groups_by"),
  lineage_edge("ADLB.AVAL", "MMRM", relationship = "models"),
  lineage_edge("MMRM", "Table_14_2_1", relationship = "reports")
)
trace_dependencies(lineage, from = "ADSL.TRT01P")
#> # A tibble: 1 × 5
#>   node        node_type depth path                       edge_relationship
#>   <chr>       <chr>     <int> <chr>                      <chr>            
#> 1 ADLB.TRT01P variable      1 ADSL.TRT01P -> ADLB.TRT01P groups_by
```

## 4. Assess impact

``` r

impact <- assess_impact(classified, adsl_adlb_lineage)
impact$impacts[, c("node", "node_type", "level", "requires_rerun")]
#> # A tibble: 8 × 4
#>   node                     node_type level                requires_rerun
#>   <chr>                    <chr>     <chr>                <lgl>         
#> 1 ADLB.TRT01P              variable  definitely_affected  FALSE         
#> 2 ADSL.TRT01A              variable  definitely_affected  FALSE         
#> 3 Efficacy_Set             analysis  potentially_affected TRUE          
#> 4 Safety_Set               analysis  potentially_affected TRUE          
#> 5 Lab_Summary_By_Treatment analysis  potentially_affected TRUE          
#> 6 MMRM                     analysis  potentially_affected TRUE          
#> 7 Table_14_2_1             output    potentially_affected TRUE          
#> 8 Table_14_2_2             output    potentially_affected TRUE
```

Impact is graded as `definitely_affected`, `potentially_affected` or
`unlikely`. Analyses and outputs are flagged as requiring review/rerun;
the package never claims statistical impact.

## 5. Report

``` r

report <- report_diff(diff, impact = impact, output = "list")
report$data$review_items
#> # A tibble: 7 × 3
#>   item           detail                                                    owner
#>   <chr>          <chr>                                                     <chr>
#> 1 Rerun required Efficacy_Set (potentially_affected) - Potentially affect… Stat…
#> 2 Rerun required Safety_Set (potentially_affected) - Potentially affected… Stat…
#> 3 Rerun required Lab_Summary_By_Treatment (potentially_affected) - Potent… Stat…
#> 4 Rerun required MMRM (potentially_affected) - Potentially affected: MMRM… Stat…
#> 5 Rerun required Table_14_2_1 (potentially_affected) - Potentially affect… Stat…
#> 6 Rerun required Table_14_2_2 (potentially_affected) - Potentially affect… Stat…
#> 7 Lineage gap    5 changed node(s) have no declared lineage: ADSL, ADSL.A… Prog…
```

Use `output = "report.html"` to write a self-contained HTML report, or
[`as_json()`](https://Hirujan-R.github.io/trialdiff/reference/as_json.md)
for machine-readable output suitable for automated QC pipelines.

## Next steps

- [`vignette("change-classification")`](https://Hirujan-R.github.io/trialdiff/articles/change-classification.md)
  for the rule system.
- [`vignette("lineage-and-impact")`](https://Hirujan-R.github.io/trialdiff/articles/lineage-and-impact.md)
  for the lineage model.
- [`vignette("ecosystem")`](https://Hirujan-R.github.io/trialdiff/articles/ecosystem.md)
  for how `trialdiff` complements existing tools.
