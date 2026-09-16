# trialdiff 0.2.0

* Added an analysis/output registry: `td_output()` and `output_registry()`
  declare analyses and outputs and their inputs, and `add_outputs()`,
  `add_edges()` and `remove_edges()` graft, extend or override a lineage graph.
* Added `lineage_from_metadata()`, which derives a lineage graph from a
  \pkg{metacore} object (or equivalent metadata tables), with provenance and a
  review list for ambiguous or unparsed references. `aliases` resolve tokens
  that would otherwise be ambiguous or unknown, and `overrides` merge an
  analysis/output registry into the generated graph.
* Added a `"diffdf"` comparison backend to `compare_cut()`, which delegates
  value comparison to the \pkg{diffdf} package and translates its output into a
  `tdiff` object (schema comparison remains built in).
* Added a case-study vignette using public `pharmaverseadam` data.
* `as_register()` now coerces key columns to character, fixing a failure when
  key columns were not character.
* New records in visit-based datasets are classified as `new_visit` rather than
  `new_assessment`.
* Added edge-case tests; package coverage now exceeds 90%.
* Bumped GitHub Actions and added Codecov configuration.

# trialdiff 0.1.0

* First tagged release. Five composable layers: compare, classify, trace,
  assess and report.
* `compare_cut()` compares two data cuts of a clinical dataset and reports
  added, removed and modified observations plus schema changes.
* `classify_changes()` applies transparent, prioritised rules to produce a
  clinical change taxonomy.
* `define_lineage()` and `trace_dependencies()` build and query a lineage graph.
* `assess_impact()` grades downstream impact as definitely/potentially/unlikely.
* `report_diff()` produces HTML, Quarto, JSON and list reports.
* Synthetic `ADSL`/`ADLB` data cuts and an example lineage are included.

# trialdiff 0.0.0.9000

* Initial development version.
