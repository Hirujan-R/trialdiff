# trialdiff

`trialdiff` is a clinical-trial **data-cut change detection and
downstream impact assessment** framework for R, designed for the
pharmaverse ecosystem.

Existing tools tell you *that* two datasets differ. `trialdiff` answers
the clinical-programming question that follows:

> **What changed, what does the change represent, and which downstream
> analyses or outputs might be affected?**

It does this in five transparent, composable layers:

| Layer | Function | Purpose |
|----|----|----|
| Compare | [`compare_cut()`](https://Hirujan-R.github.io/trialdiff/reference/compare_cut.md) | Added/removed/modified observations and schema changes |
| Classify | [`classify_changes()`](https://Hirujan-R.github.io/trialdiff/reference/classify_changes.md) | Rule-based clinical change taxonomy |
| Trace | [`define_lineage()`](https://Hirujan-R.github.io/trialdiff/reference/define_lineage.md), [`trace_dependencies()`](https://Hirujan-R.github.io/trialdiff/reference/trace_dependencies.md), [`lineage_from_metadata()`](https://Hirujan-R.github.io/trialdiff/reference/lineage_from_metadata.md), [`output_registry()`](https://Hirujan-R.github.io/trialdiff/reference/output_registry.md) | Explicit data lineage graph |
| Assess | [`assess_impact()`](https://Hirujan-R.github.io/trialdiff/reference/assess_impact.md) | Definitely / potentially / unlikely impact |
| Report | [`report_diff()`](https://Hirujan-R.github.io/trialdiff/reference/report_diff.md) | HTML, Quarto and machine-readable JSON |

Everything is deterministic. There is no machine learning, and **no
statistical impact is ever claimed** - analyses are flagged for review
and rerun.

## Installation

``` r

# From r-universe (includes Windows/macOS binaries)
install.packages(
  "trialdiff",
  repos = c(
    hirujan = "https://hirujan-r.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
)

# Or from GitHub
# install.packages("remotes")
remotes::install_github("Hirujan-R/trialdiff")
```

## Quick start

``` r

library(trialdiff)

diff <- compare_cut(
  old = adsl_cut1,
  new = adsl_cut2,
  by = "USUBJID",
  dataset = "ADSL"
)

classified <- classify_changes(diff)

impact <- assess_impact(classified, adsl_adlb_lineage)

report_diff(diff, impact = impact, output = "report.html")
```

A treatment assignment change (`TRT01P = "Placebo"` -\> `"Drug A"`) is
detected, classified as a treatment-assignment change, traced through
`ADSL.TRT01P -> ADLB.TRT01P -> lab summary -> MMRM -> efficacy table`,
and every downstream object is flagged for review with a rationale.

## Why not just `diffdf`?

`diffdf` (and `waldo`) are excellent low-level comparison tools, and
`trialdiff` deliberately does not reinvent them. `trialdiff` adds the
layers that are specific to clinical programming:

- a **clinical change taxonomy** (new subject, new visit, corrected
  value, missingness transitions, derived-variable change,
  treatment-assignment change, metadata change, …);
- **explicit lineage** between datasets, variables, analyses and
  outputs;
- **auditable impact assessment** with a documented policy;
- **review reports** that name the objects a programmer or statistician
  must check.

It can even delegate the low-level comparison itself:
`compare_cut(..., backend = "diffdf")` uses `diffdf` to detect
differences and translates the result into the same `tdiff` object.

## Design principles

- Deterministic comparison, not opaque inference.
- Transparent, user-extensible rules.
- Explicit, reproducible lineage metadata.
- Auditable impact assessment with a written rationale for every flag.
- Clinically meaningful reporting.

## Documentation

- [`vignette("trialdiff")`](https://Hirujan-R.github.io/trialdiff/articles/trialdiff.md) -
  getting started.
- [`vignette("change-classification")`](https://Hirujan-R.github.io/trialdiff/articles/change-classification.md) -
  the rule system.
- [`vignette("lineage-and-impact")`](https://Hirujan-R.github.io/trialdiff/articles/lineage-and-impact.md) -
  lineage and impact.
- [`vignette("ecosystem")`](https://Hirujan-R.github.io/trialdiff/articles/ecosystem.md) -
  relationship to `diffdf`, `admiral`, `metacore`, `cards`, `tern`, SAS
  `PROC COMPARE` and others.
- [`vignette("case-study")`](https://Hirujan-R.github.io/trialdiff/articles/case-study.md) -
  end-to-end walkthrough on public `pharmaverseadam` data.

## Project proposal

A full proposal covering the problem statement, ecosystem/gap analysis,
novelty assessment, architecture, testing and roadmap is available in
[`proposal/trialdiff-proposal.md`](https://Hirujan-R.github.io/trialdiff/proposal/trialdiff-proposal.md).

## Code of conduct

Please note that the `trialdiff` project is released with a [Contributor
Code of
Conduct](https://Hirujan-R.github.io/trialdiff/CODE_OF_CONDUCT.md). By
contributing you agree to abide by its terms.

## License

MIT (c) Hirujan Rangaraj. No proprietary or real patient data is
included; all example datasets are synthetic.
