# Add an analysis/output registry to a lineage graph

Add an analysis/output registry to a lineage graph

## Usage

``` r
add_outputs(x, outputs, ...)
```

## Arguments

- x:

  A `td_lineage` object.

- outputs:

  A registry from
  [`output_registry()`](https://Hirujan-R.github.io/trialdiff/reference/output_registry.md)
  (or a single
  [`td_output()`](https://Hirujan-R.github.io/trialdiff/reference/td_output.md)
  result).

- ...:

  Additional registries.

## Value

A `td_lineage` object.

## Examples

``` r
lineage <- define_lineage(
  lineage_edge("ADLB.AVAL", "ADLB.CHG", relationship = "derives")
)
registry <- output_registry(
  td_output("MMRM", depends_on = c("ADLB.AVAL", "ADLB.CHG")),
  td_output("Table_14_2_1", depends_on = "MMRM", type = "output")
)
trace_dependencies(add_outputs(lineage, registry), from = "ADLB.AVAL")
#> # A tibble: 3 × 5
#>   node         node_type depth path                            edge_relationship
#>   <chr>        <chr>     <int> <chr>                           <chr>            
#> 1 ADLB.CHG     variable      1 ADLB.AVAL -> ADLB.CHG           derives          
#> 2 MMRM         analysis      1 ADLB.AVAL -> MMRM               models           
#> 3 Table_14_2_1 output        2 ADLB.AVAL -> MMRM -> Table_14_… reports          
```
