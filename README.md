# trialdiff

<!-- badges: start -->
[![R-CMD-check](https://github.com/Hirujan-R/trialdiff/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Hirujan-R/trialdiff/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/Hirujan-R/trialdiff/branch/main/graph/badge.svg)](https://app.codecov.io/gh/Hirujan-R/trialdiff?branch=main)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

`trialdiff` is a clinical-trial **data-cut change detection and downstream
impact assessment** framework for R, designed for the pharmaverse ecosystem.

Existing tools tell you *that* two datasets differ. `trialdiff` answers the
clinical-programming question that follows:

> **What changed, what does the change represent, and which downstream analyses
> or outputs might be affected?**

It does this in five transparent, composable layers:

| Layer | Function | Purpose |
|-------|----------|---------|
| Compare | `compare_cut()` | Added/removed/modified observations and schema changes |
| Classify | `classify_changes()` | Rule-based clinical change taxonomy |
| Trace | `define_lineage()`, `trace_dependencies()` | Explicit data lineage graph |
| Assess | `assess_impact()` | Definitely / potentially / unlikely impact |
| Report | `report_diff()` | HTML, Quarto and machine-readable JSON |

Everything is deterministic. There is no machine learning, and **no statistical
impact is ever claimed** - analyses are flagged for review and rerun.

## Installation

```r
# install.packages("remotes")
remotes::install_github("Hirujan-R/trialdiff")
```

## Quick start

```r
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

A treatment assignment change (`TRT01P = "Placebo"` -> `"Drug A"`) is detected,
classified as a treatment-assignment change, traced through
`ADSL.TRT01P -> ADLB.TRT01P -> lab summary -> MMRM -> efficacy table`, and every
downstream object is flagged for review with a rationale.

## Why not just `diffdf`?

`diffdf` (and `waldo`) are excellent low-level comparison tools, and
`trialdiff` deliberately does not reinvent them. `trialdiff` adds the layers
that are specific to clinical programming:

* a **clinical change taxonomy** (new subject, new visit, corrected value,
  missingness transitions, derived-variable change, treatment-assignment change,
  metadata change, ...);
* **explicit lineage** between datasets, variables, analyses and outputs;
* **auditable impact assessment** with a documented policy;
* **review reports** that name the objects a programmer or statistician must
  check.

## Design principles

* Deterministic comparison, not opaque inference.
* Transparent, user-extensible rules.
* Explicit, reproducible lineage metadata.
* Auditable impact assessment with a written rationale for every flag.
* Clinically meaningful reporting.

## Documentation

* `vignette("trialdiff")` - getting started.
* `vignette("change-classification")` - the rule system.
* `vignette("lineage-and-impact")` - lineage and impact.
* `vignette("ecosystem")` - relationship to `diffdf`, `admiral`, `metacore`,
  `cards`, `tern`, SAS `PROC COMPARE` and others.

## Project proposal

A full proposal covering the problem statement, ecosystem/gap analysis, novelty
assessment, architecture, testing and roadmap is available in
[`proposal/trialdiff-proposal.md`](proposal/trialdiff-proposal.md).

## Code of conduct

Please note that the `trialdiff` project is released with a
[Contributor Code of Conduct](CODE_OF_CONDUCT.md). By contributing you agree to
abide by its terms.

## License

MIT (c) Hirujan Rangaraj. No proprietary or real patient data is included;
all example datasets are synthetic.
