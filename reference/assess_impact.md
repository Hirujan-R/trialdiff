# Assess downstream impact of classified changes

Combines a classified change set with a lineage graph to identify which
downstream variables, analyses and outputs *could* be affected. Impact
is graded as `"definitely_affected"`, `"potentially_affected"` or
`"unlikely"`, with an explicit rationale and the triggering change
identifiers.

## Usage

``` r
assess_impact(changes, lineage, policy = impact_policy(), ...)
```

## Arguments

- changes:

  A classified `tdiff` object (output of
  [`classify_changes()`](https://Hirujan-R.github.io/trialdiff/reference/classify_changes.md))
  or a change register with a `category` column.

- lineage:

  A `td_lineage` object from
  [`define_lineage()`](https://Hirujan-R.github.io/trialdiff/reference/define_lineage.md).

- policy:

  An
  [`impact_policy()`](https://Hirujan-R.github.io/trialdiff/reference/impact_policy.md)
  object.

- ...:

  Reserved for future extensions.

## Value

An object of class `td_impact` with elements `impacts`, `by_subject`,
`unlinked`, `summary`, `policy` and `meta`.

## Details

`trialdiff` never claims statistical impact. Every affected analysis or
output is reported as requiring programmer/statistician review and,
where appropriate, a rerun.

## Examples

``` r
old <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Placebo", "Drug A"))
new <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Drug A", "Drug A"))
diff <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL") |>
  classify_changes()
lineage <- define_lineage(
  lineage_edge("ADSL.TRT01P", "ADLB.TRT01P", relationship = "groups_by"),
  lineage_edge("ADLB.TRT01P", "MMRM", relationship = "models"),
  lineage_edge("MMRM", "Table_14_2_1", relationship = "reports")
)
assess_impact(diff, lineage)
#> 
#> ── trialdiff impact assessment ─────────────────────────────────────────────────
#> Dataset(s): "ADSL"
#> Changes assessed: 1
#> 
#> ── Impact summary ──
#> 
#> # A tibble: 5 × 2
#>   metric                              value
#>   <chr>                               <int>
#> 1 nodes_definitely_affected               1
#> 2 nodes_potentially_affected              2
#> 3 nodes_unlikely                          0
#> 4 analyses_or_outputs_requiring_rerun     2
#> 5 unlinked_changes                        1
#> ── Affected downstream objects ──
#> 
#> # A tibble: 3 × 4
#>   node         node_type level                depth
#>   <chr>        <chr>     <chr>                <int>
#> 1 ADLB.TRT01P  variable  definitely_affected      1
#> 2 MMRM         analysis  potentially_affected     2
#> 3 Table_14_2_1 output    potentially_affected     3
#> ! 1 changed node has no declared lineage.
#> ℹ Impact is a review signal only; statistical impact requires rerunning analyses.
```
