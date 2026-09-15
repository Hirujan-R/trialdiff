# Change classification rules

Classification in `trialdiff` is transparent and rule-based. A *rule* is
a named predicate evaluated against the long change register produced by
[`as_register()`](https://Hirujan-R.github.io/trialdiff/reference/as_register.md).
Rules are applied in priority order; the first matching rule determines
the primary category, while every matched rule is retained in the
`category_all` column so that nothing is hidden.

## Usage

``` r
td_rule(name, label, test, priority = 100L, reason = NULL, description = NULL)
```

## Arguments

- name:

  Stable machine-readable category name (snake_case).

- label:

  Human-readable category label.

- test:

  A function `function(register, context)` returning a logical vector
  the same length as `nrow(register)`.

- priority:

  Integer priority; lower values are evaluated first.

- reason:

  Optional function `function(register, context)` returning a character
  vector of explanations.

- description:

  Optional longer description.

## Value

`td_rule()` returns an object of class `td_rule`.
