# Declare an analysis or output and its inputs

`td_output()` is the building block of an analysis/output registry. It
states that an analysis or output depends on one or more upstream nodes
(typically `dataset.variable` identifiers, but any node is allowed).

## Usage

``` r
td_output(
  id,
  depends_on,
  type = c("analysis", "output"),
  relationship = NULL,
  condition = NA_character_,
  label = id
)
```

## Arguments

- id:

  Node identifier for the analysis or output (for example `"MMRM"` or
  `"Table_14_2_1"`).

- depends_on:

  Character vector of upstream node identifiers.

- type:

  Either `"analysis"` or `"output"`.

- relationship:

  Edge relationship. Defaults to `"models"` for analyses and `"reports"`
  for outputs.

- condition:

  Optional applicability condition (recorded, not evaluated).

- label:

  Human-readable label.

## Value

A tibble of registry edges.
