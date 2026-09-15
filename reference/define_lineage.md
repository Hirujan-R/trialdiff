# Define a data lineage graph

`define_lineage()` collects lineage edges into an auditable graph that
can be queried with
[`trace_dependencies()`](https://Hirujan-R.github.io/trialdiff/reference/trace_dependencies.md)
and used by
[`assess_impact()`](https://Hirujan-R.github.io/trialdiff/reference/assess_impact.md).
The graph is stored as a tidy edge list plus a node table; no external
graph library is required, although
[`as_igraph()`](https://Hirujan-R.github.io/trialdiff/reference/as_igraph.md)
is provided for users who prefer one.

## Usage

``` r
define_lineage(
  ...,
  edges = NULL,
  nodes = NULL,
  dataset = NULL,
  variable = NULL,
  downstream = NULL,
  relationship = "derives"
)
```

## Arguments

- ...:

  One or more edge tibbles created by
  [`lineage_edge()`](https://Hirujan-R.github.io/trialdiff/reference/lineage_edge.md),
  or a single data frame of edges.

- edges:

  Optional data frame of edges with columns `from`, `to` and optionally
  `from_type`, `to_type`, `relationship`, `condition`.

- nodes:

  Optional node table with columns `node` and `type`, used to override
  inferred types and to attach labels.

- dataset, variable, downstream:

  Convenience arguments matching the common workflow: declare that
  `downstream` objects depend on `dataset.variable`.

- relationship:

  Relationship used with the convenience arguments.

## Value

An object of class `td_lineage`.

## Examples

``` r
lineage <- define_lineage(
  lineage_edge("ADSL.TRT01P", "ADLB.TRT01P", relationship = "derives"),
  lineage_edge("ADLB.AVAL", "MMRM", relationship = "models"),
  lineage_edge("MMRM", "Table_14_2_1", relationship = "reports")
)
trace_dependencies(lineage, from = "ADSL.TRT01P")
#> # A tibble: 1 × 5
#>   node        node_type depth path                       edge_relationship
#>   <chr>       <chr>     <int> <chr>                      <chr>            
#> 1 ADLB.TRT01P variable      1 ADSL.TRT01P -> ADLB.TRT01P derives          
```
