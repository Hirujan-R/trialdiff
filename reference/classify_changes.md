# Classify detected changes

`classify_changes()` turns the raw output of
[`compare_cut()`](https://Hirujan-R.github.io/trialdiff/reference/compare_cut.md)
into a clinically meaningful change register. Every change is assigned a
transparent, rule-based category (see
[`td_default_rules()`](https://Hirujan-R.github.io/trialdiff/reference/td_default_rules.md))
together with a human-readable explanation.

## Usage

``` r
classify_changes(x, rules = td_default_rules(), context = list(), ...)
```

## Arguments

- x:

  A `tdiff` object returned by
  [`compare_cut()`](https://Hirujan-R.github.io/trialdiff/reference/compare_cut.md),
  or a change register returned by
  [`as_register()`](https://Hirujan-R.github.io/trialdiff/reference/as_register.md).

- rules:

  A list of
  [`td_rule()`](https://Hirujan-R.github.io/trialdiff/reference/td_rule.md)
  objects. Defaults to
  [`td_default_rules()`](https://Hirujan-R.github.io/trialdiff/reference/td_default_rules.md).

- context:

  Optional named list of extra context passed to rules, for example
  `list(has_paramcd = TRUE)`. Context is merged with context derived
  from `x`.

- ...:

  Unused.

## Value

When `x` is a `tdiff`, the same object with classification columns added
to `$added`, `$removed`, `$modified` and `$schema`, a `$register`
element, and class `c("tdiff_classified", "tdiff")`. When `x` is a
register (data frame), a classified tibble.

## Examples

``` r
old <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Placebo", "Drug A"))
new <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Drug A", "Drug A"))
compare_cut(old, new, by = "USUBJID", dataset = "ADSL") |>
  classify_changes()
#> 
#> ── trialdiff comparison ────────────────────────────────────────────────────────
#> ADSL: old → new
#> Keys: "USUBJID"
#> Observations: 2 → 2 (2 matched)
#> Added: 0 Removed: 0 Modified cells: 1
#> Schema changes: 0
#> Classified: 1 category present
```
