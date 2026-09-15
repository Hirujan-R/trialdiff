# Compare two data cuts of a clinical dataset

`compare_cut()` performs a deterministic, key-based comparison of two
versions of the same clinical dataset (for example `ADSL` at two data
cuts). It reports observations added, removed and modified, and
separately reports schema-level changes (variables added/removed, type
and label changes).

## Usage

``` r
compare_cut(
  old,
  new,
  by,
  compare_labels = TRUE,
  compare_types = TRUE,
  tolerance = 1e-09,
  ignore_vars = NULL,
  name_old = "old",
  name_new = "new",
  dataset = NULL,
  subject_var = NULL,
  backend = c("trialdiff", "waldo"),
  ...
)
```

## Arguments

- old, new:

  Data frames (or tibbles) representing the earlier and later data cut.
  `new` is compared against `old`.

- by:

  Character vector of key variables that uniquely identify an
  observation within each dataset. Common clinical keys include
  `c("USUBJID", "PARAMCD", "AVISIT")` for `ADLB` or
  `c("USUBJID", "VISIT")` for `ADVS`. Must be present in both datasets.

- compare_labels:

  Logical. If `TRUE` (default) variable label changes are recorded in
  the schema comparison.

- compare_types:

  Logical. If `TRUE` (default) variable type changes are recorded in the
  schema comparison.

- tolerance:

  Numeric tolerance used when comparing numeric values. Set to `0` for
  exact comparison.

- ignore_vars:

  Character vector of variables to exclude from the value comparison
  (for example technical or audit columns).

- name_old, name_new:

  Character labels used in reports.

- dataset:

  Optional dataset name (for example `"ADSL"`). Inferred from the
  `old`/`new` expressions when not supplied.

- subject_var:

  Optional subject identifier variable. When `NULL` the function looks
  for `USUBJID`, then falls back to the first key.

- backend:

  Low-level comparison backend. `"trialdiff"` uses the built-in engine;
  `"waldo"` additionally uses waldo for whole-column equality
  short-circuiting when it is installed.

- ...:

  Reserved for future extensions.

## Value

An object of class `tdiff`: a list with elements `meta`, `added`,
`removed`, `modified`, `schema`, `summary` and `register`. See
[tdiff-object](https://Hirujan-R.github.io/trialdiff/reference/tdiff-object.md)
for details.

## Details

The function is deliberately a *low-level* comparison engine. Clinical
meaning is added by
[`classify_changes()`](https://Hirujan-R.github.io/trialdiff/reference/classify_changes.md),
lineage by
[`define_lineage()`](https://Hirujan-R.github.io/trialdiff/reference/define_lineage.md)
and impact by
[`assess_impact()`](https://Hirujan-R.github.io/trialdiff/reference/assess_impact.md).

## Examples

``` r
old <- data.frame(
  USUBJID = c("S1", "S2", "S3"),
  TRT01P = c("Placebo", "Drug A", "Placebo"),
  AGE = c(54, 61, 47),
  stringsAsFactors = FALSE
)
new <- old
new$TRT01P[1] <- "Drug A"
new$AGE[2] <- 62
diff <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
diff
#> 
#> ── trialdiff comparison ────────────────────────────────────────────────────────
#> ADSL: old → new
#> Keys: "USUBJID"
#> Observations: 3 → 3 (3 matched)
#> Added: 0 Removed: 0 Modified cells: 2
#> Schema changes: 0
```
