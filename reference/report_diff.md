# Produce a change-review report

`report_diff()` renders a structured review report from a comparison,
its classification and (optionally) an impact assessment. Human-readable
HTML or Quarto output is supported alongside machine-readable JSON and
list output for automated QC pipelines.

## Usage

``` r
report_diff(
  diff,
  impact = NULL,
  classified = NULL,
  output = "html",
  format = c("html", "quarto", "json", "list"),
  title = NULL,
  max_rows = 25L,
  include_disclaimer = TRUE,
  ...
)
```

## Arguments

- diff:

  A `tdiff` object, ideally already passed through
  [`classify_changes()`](https://Hirujan-R.github.io/trialdiff/reference/classify_changes.md).

- impact:

  Optional `td_impact` object from
  [`assess_impact()`](https://Hirujan-R.github.io/trialdiff/reference/assess_impact.md).

- classified:

  Optional classified `tdiff` object. If supplied it takes precedence
  over `diff` for classification content.

- output:

  Either a format (`"html"`, `"quarto"`, `"json"`, `"list"`) or a file
  path. When a path is given the format is inferred from the extension.

- format:

  Report format. Ignored when `output` is a path.

- title:

  Report title.

- max_rows:

  Maximum number of rows shown per table in HTML output.

- include_disclaimer:

  Include the regulatory/statistical disclaimer.

- ...:

  Reserved for future extensions.

## Value

An object of class `td_report`. When a file path is supplied the report
is written and the path is stored in `$path`.
