# Impact-assessment policy

Controls how aggressively changes are mapped onto downstream analyses.
The policy is explicit and auditable: no statistical significance is
ever claimed. Analyses and outputs are flagged as *requiring
review/rerun*, never as "statistically affected".

## Usage

``` r
impact_policy(
  value_direct = "definitely_affected",
  value_indirect = "potentially_affected",
  record = "potentially_affected",
  schema = "potentially_affected",
  label = "unlikely",
  max_depth = Inf
)
```

## Arguments

- value_direct:

  Level for a variable derived directly from a changed variable.

- value_indirect:

  Level for more distant value changes.

- record:

  Level for added/removed observations.

- schema:

  Level for schema changes other than label changes.

- label:

  Level for label-only changes.

- max_depth:

  Maximum lineage depth to traverse.

## Value

An object of class `td_policy`.
