# Trace downstream dependencies

Performs a breadth-first traversal of the lineage graph starting from
`from` and returns every reachable node, its depth and the path taken.

## Usage

``` r
trace_dependencies(
  x,
  from,
  direction = c("downstream", "upstream"),
  max_depth = Inf,
  include_self = FALSE,
  ...
)
```

## Arguments

- x:

  A `td_lineage` object.

- from:

  Character vector of starting node identifiers.

- direction:

  `"downstream"` (default) or `"upstream"`.

- max_depth:

  Maximum traversal depth.

- include_self:

  Include the starting node(s) in the result.

- ...:

  Unused.

## Value

A tibble with `node`, `node_type`, `depth`, `path` and
`edge_relationship`.
