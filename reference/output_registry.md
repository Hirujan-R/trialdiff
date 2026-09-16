# Build an analysis/output registry

Collects one or more
[`td_output()`](https://Hirujan-R.github.io/trialdiff/reference/td_output.md)
declarations into a single registry table that can be grafted onto a
lineage graph with
[`add_outputs()`](https://Hirujan-R.github.io/trialdiff/reference/add_outputs.md).

## Usage

``` r
output_registry(...)
```

## Arguments

- ...:

  One or more
  [`td_output()`](https://Hirujan-R.github.io/trialdiff/reference/td_output.md)
  results.

## Value

A tibble of registry edges.

## Examples

``` r
registry <- output_registry(
  td_output("MMRM", depends_on = c("ADLB.AVAL", "ADLB.CHG")),
  td_output("Table_14_2_1", depends_on = "MMRM", type = "output")
)
registry
#> # A tibble: 3 × 10
#>   from      from_type to           to_type  relationship condition label  source
#>   <chr>     <chr>     <chr>        <chr>    <chr>        <chr>     <chr>  <chr> 
#> 1 ADLB.AVAL variable  MMRM         analysis models       NA        MMRM   regis…
#> 2 ADLB.CHG  variable  MMRM         analysis models       NA        MMRM   regis…
#> 3 MMRM      analysis  Table_14_2_1 output   reports      NA        Table… regis…
#> # ℹ 2 more variables: derivation_id <chr>, derivation <chr>
```
