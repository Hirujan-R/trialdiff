# Add edges to a lineage graph

Merges edges (from
[`lineage_edge()`](https://Hirujan-R.github.io/trialdiff/reference/lineage_edge.md),
[`td_output()`](https://Hirujan-R.github.io/trialdiff/reference/td_output.md),
a registry or any edge data frame) into an existing `td_lineage` object
and rebuilds the node table. Existing provenance and review information
is preserved.

## Usage

``` r
add_edges(x, ..., source = NULL)
```

## Arguments

- x:

  A `td_lineage` object.

- ...:

  Edge tables to add.

- source:

  Optional value used to tag the source of every added edge.

## Value

A `td_lineage` object.
