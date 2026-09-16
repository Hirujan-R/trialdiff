# Changelog

## trialdiff 0.2.0

- Added an analysis/output registry:
  [`td_output()`](https://Hirujan-R.github.io/trialdiff/reference/td_output.md)
  and
  [`output_registry()`](https://Hirujan-R.github.io/trialdiff/reference/output_registry.md)
  declare analyses and outputs and their inputs, and
  [`add_outputs()`](https://Hirujan-R.github.io/trialdiff/reference/add_outputs.md),
  [`add_edges()`](https://Hirujan-R.github.io/trialdiff/reference/add_edges.md)
  and
  [`remove_edges()`](https://Hirujan-R.github.io/trialdiff/reference/remove_edges.md)
  graft, extend or override a lineage graph.
- Added
  [`lineage_from_metadata()`](https://Hirujan-R.github.io/trialdiff/reference/lineage_from_metadata.md),
  which derives a lineage graph from a object (or equivalent metadata
  tables), with provenance and a review list for ambiguous or unparsed
  references. `aliases` resolve tokens that would otherwise be ambiguous
  or unknown, and `overrides` merge an analysis/output registry into the
  generated graph.
- Added a `"diffdf"` comparison backend to
  [`compare_cut()`](https://Hirujan-R.github.io/trialdiff/reference/compare_cut.md),
  which delegates value comparison to the package and translates its
  output into a `tdiff` object (schema comparison remains built in).
- Added a case-study vignette using public `pharmaverseadam` data.
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
