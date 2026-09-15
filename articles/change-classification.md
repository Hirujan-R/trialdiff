# The change-classification system

## Design principles

Classification in `trialdiff` is deliberately boring and auditable:

- every change is a row in a long *change register* (\[as_register()\]);
- every category comes from an explicit \[td_rule()\];
- the first matching rule (by priority) sets the primary category, but
  **all** matching rules are retained in `category_all`;
- each change carries a plain-language `reason`.

There is no machine learning and no hidden scoring.

## The built-in categories

``` r

library(trialdiff)
td_categories()
#> # A tibble: 16 × 2
#>    category                    label                         
#>    <chr>                       <chr>                         
#>  1 new_subject                 New subject                   
#>  2 subject_removed             Subject removed               
#>  3 new_visit                   New visit                     
#>  4 new_assessment              New assessment                
#>  5 new_record                  New record                    
#>  6 record_removed              Record removed                
#>  7 treatment_assignment_change Treatment-assignment change   
#>  8 derived_variable_change     Derived-variable change       
#>  9 corrected_value             Corrected value               
#> 10 missing_to_value            Missing to non-missing        
#> 11 value_to_missing            Non-missing to missing        
#> 12 variable_added              Variable added                
#> 13 variable_removed            Variable removed              
#> 14 type_change                 Type change                   
#> 15 label_change                Label change                  
#> 16 unclassified                Unclassified - requires review
```

## The change register

``` r

diff <- compare_cut(adsl_cut1, adsl_cut2, by = "USUBJID", dataset = "ADSL")
reg <- as_register(diff)
reg[, c(".change_id", "record_type", "USUBJID", "variable", "old_value",
        "new_value", "change")]
#> # A tibble: 11 × 7
#>    .change_id record_type USUBJID    variable old_value         new_value change
#>    <chr>      <chr>       <chr>      <chr>    <chr>             <chr>     <chr> 
#>  1 CHG00001   added       TD001-S031 NA       NA                NA        recor…
#>  2 CHG00002   added       TD001-S032 NA       NA                NA        recor…
#>  3 CHG00003   removed     TD001-S003 NA       NA                NA        recor…
#>  4 CHG00004   modified    TD001-S007 AGE      44                45        value 
#>  5 CHG00005   modified    TD001-S011 AGE      22                21        value 
#>  6 CHG00006   modified    TD001-S014 SEX      M                 <NA>      value…
#>  7 CHG00007   modified    TD001-S018 RACE     BLACK OR AFRICAN… WHITE     value 
#>  8 CHG00008   modified    TD001-S005 TRT01P   Placebo           Drug A    value 
#>  9 CHG00009   modified    TD001-S005 TRT01A   Placebo           Drug A    value 
#> 10 CHG00010   schema      NA         REGION   NA                character varia…
#> 11 CHG00011   schema      NA         AGE      integer           numeric   type_…
```

## Applying the default rules

``` r

classified <- classify_changes(diff)
classified$register[, c(".change_id", "category", "category_label", "reason")]
#> # A tibble: 11 × 4
#>    .change_id category                    category_label              reason    
#>    <chr>      <chr>                       <chr>                       <chr>     
#>  1 CHG00001   new_subject                 New subject                 Subject '…
#>  2 CHG00002   new_subject                 New subject                 Subject '…
#>  3 CHG00003   subject_removed             Subject removed             Subject '…
#>  4 CHG00004   corrected_value             Corrected value             Variable …
#>  5 CHG00005   corrected_value             Corrected value             Variable …
#>  6 CHG00006   value_to_missing            Non-missing to missing      Variable …
#>  7 CHG00007   corrected_value             Corrected value             Variable …
#>  8 CHG00008   treatment_assignment_change Treatment-assignment change Treatment…
#>  9 CHG00009   treatment_assignment_change Treatment-assignment change Treatment…
#> 10 CHG00010   variable_added              Variable added              Variable …
#> 11 CHG00011   type_change                 Type change                 Variable …
```

## Writing a custom rule

A rule is a predicate over the register. The `context` contains the
dataset name, keys and the sets of subjects present in each cut.

``` r

age_rule <- td_rule(
  name = "age_change",
  label = "Age change",
  priority = 1L,
  test = function(register, context) {
    register$record_type == "modified" & register$variable == "AGE"
  },
  reason = function(register, context) {
    sprintf("Age changed for %s.", register$.subject)
  }
)

custom <- classify_changes(
  diff,
  rules = c(list(age_rule), td_default_rules())
)
custom$register$category[custom$register$variable == "AGE"]
#> [1] NA            NA            NA            "age_change"  "age_change" 
#> [6] "type_change"
```

## Prioritisation

Rules are evaluated in ascending priority order. This matters when more
than one rule could apply. For example, `AVAL` is a derived variable
*and* a value can transition from missing to non-missing. Missingness
transitions have a higher priority than the generic derived-variable
rule, because they are more actionable for review:

``` r

old <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(NA, 5))
new <- data.frame(USUBJID = c("S1", "S2"), AVAL = c(3, NA))
classified_missing <- classify_changes(compare_cut(old, new, by = "USUBJID",
                                                    dataset = "ADLB"))
classified_missing$modified[, c("USUBJID", "variable", "change", "category")]
#> # A tibble: 2 × 4
#>   USUBJID variable change           category        
#>   <chr>   <chr>    <chr>            <chr>           
#> 1 S1      AVAL     missing_to_value missing_to_value
#> 2 S2      AVAL     value_to_missing value_to_missing
```

Any change that no rule matches is marked `unclassified` and surfaced in
the report as an item requiring manual review, so the rule set can never
silently hide a change.
