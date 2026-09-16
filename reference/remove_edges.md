# Remove edges from a lineage graph

Removes edges matching any supplied filter. Useful for overriding or
replacing automatically generated lineage.

## Usage

``` r
remove_edges(x, from = NULL, to = NULL, relationship = NULL, source = NULL)
```

## Arguments

- x:

  A `td_lineage` object.

- from, to, relationship, source:

  Optional character vectors of values to match. `NULL` (default)
  ignores that field.

## Value

A `td_lineage` object.
