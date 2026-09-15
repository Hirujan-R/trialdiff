# Changelog

## trialdiff 0.1.0.9000

- [`as_register()`](https://Hirujan-R.github.io/trialdiff/reference/as_register.md)
  now coerces key columns to character, fixing a failure when key
  columns were not character.
- New records in visit-based datasets are classified as `new_visit`
  rather than `new_assessment`.
- Added edge-case tests; package coverage now exceeds 90%.
- Bumped GitHub Actions and added Codecov configuration.

## trialdiff 0.1.0

- First tagged release. Five composable layers: compare, classify,
  trace, assess and report.
- [`compare_cut()`](https://Hirujan-R.github.io/trialdiff/reference/compare_cut.md)
  compares two data cuts of a clinical dataset and reports added,
  removed and modified observations plus schema changes.
- [`classify_changes()`](https://Hirujan-R.github.io/trialdiff/reference/classify_changes.md)
  applies transparent, prioritised rules to produce a clinical change
  taxonomy.
- [`define_lineage()`](https://Hirujan-R.github.io/trialdiff/reference/define_lineage.md)
  and
  [`trace_dependencies()`](https://Hirujan-R.github.io/trialdiff/reference/trace_dependencies.md)
  build and query a lineage graph.
- [`assess_impact()`](https://Hirujan-R.github.io/trialdiff/reference/assess_impact.md)
  grades downstream impact as definitely/potentially/unlikely.
- [`report_diff()`](https://Hirujan-R.github.io/trialdiff/reference/report_diff.md)
  produces HTML, Quarto, JSON and list reports.
- Synthetic `ADSL`/`ADLB` data cuts and an example lineage are included.

## trialdiff 0.0.0.9000

- Initial development version.
