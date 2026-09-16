# Derive lineage from study metadata

`lineage_from_metadata()` builds a
[`define_lineage()`](https://Hirujan-R.github.io/trialdiff/reference/define_lineage.md)
graph from a metacore object (or any list with the same tables). Dataset
and variable nodes come from `ds_vars`/`ds_spec`, and dependency edges
are parsed from the `derivations` and `where` columns of `value_spec`.

## Usage

``` r
lineage_from_metadata(
  metadata,
  include_where = TRUE,
  include_sdtm = TRUE,
  aliases = NULL,
  overrides = NULL,
  ...
)
```

## Arguments

- metadata:

  A `metacore` object (from metacore) or a list with elements `ds_vars`,
  `ds_spec`, `value_spec` and `derivations`.

- include_where:

  Logical. If `TRUE` (default), variables referenced in
  `value_spec$where` clauses are added as `"filters"` edges.

- include_sdtm:

  Logical. If `TRUE` (default), `DATASET.VARIABLE` references to
  non-ADaM domains (for example `DM.ARM`) are kept as source nodes.

- aliases:

  Optional data frame with columns `token` and `node`, and an optional
  `dataset` column to scope the alias to one dataset. Aliases resolve
  tokens that would otherwise be ambiguous or unknown.

- overrides:

  Optional edge table (for example from
  [`output_registry()`](https://Hirujan-R.github.io/trialdiff/reference/output_registry.md))
  merged into the generated graph with
  [`add_edges()`](https://Hirujan-R.github.io/trialdiff/reference/add_edges.md).

- ...:

  Reserved for future extensions.

## Value

A `td_lineage` object with additional elements `review` (references
needing manual attention) and `provenance`.

## Details

Parsing is deterministic and conservative: only tokens that resolve to
known variables (or explicit `DATASET.VARIABLE` references) become
edges. Every edge records its provenance, and references that cannot be
resolved uniquely are returned in a review table rather than guessed.
See
[`lineage_review()`](https://Hirujan-R.github.io/trialdiff/reference/lineage_review.md).

## Examples

``` r
metadata <- list(
  ds_spec = data.frame(dataset = c("ADSL", "ADLB"), stringsAsFactors = FALSE),
  ds_vars = data.frame(
    dataset = c("ADSL", "ADSL", "ADLB", "ADLB", "ADLB"),
    variable = c("USUBJID", "TRT01P", "USUBJID", "AVAL", "CHG"),
    stringsAsFactors = FALSE
  ),
  value_spec = data.frame(
    dataset = c("ADSL", "ADLB", "ADLB"),
    variable = c("TRT01P", "AVAL", "CHG"),
    derivation_id = c("MT.ADSL.TRT01P", "MT.ADLB.AVAL", "MT.ADLB.CHG"),
    where = c(NA, "PARAMCD == 'ALT'", NA),
    stringsAsFactors = FALSE
  ),
  derivations = data.frame(
    derivation_id = c("MT.ADSL.TRT01P", "MT.ADLB.AVAL", "MT.ADLB.CHG"),
    derivation = c("DM.ARM", "ADSL.TRT01P", "AVAL - BASE"),
    stringsAsFactors = FALSE
  )
)
lineage_from_metadata(metadata)
#> 
#> ── trialdiff lineage ───────────────────────────────────────────────────────────
#> 3 edges, 8 nodes
#> dataset: 2
#> variable: 6
```
