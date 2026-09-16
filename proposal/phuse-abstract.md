# PHUSE abstract (draft)

Working title and structured abstract for a PHUSE conference paper or poster.
Adjust the track, length and author list to the current call for papers.

**Proposed track:** Data Science / Statistical Programming / Open Source

## Title

**Beyond `diffdf`: assessing the downstream impact of clinical trial data cuts**

## Authors

Hirujan Rangaraj (presenting author).
Co-authors welcome.

## Background

Clinical trial datasets are regenerated many times during a study. Between data
cuts, observations are added, removed or corrected, derivations change and
metadata evolves. Existing tools such as `diffdf`, `waldo` and SAS `PROC COMPARE`
reliably answer *whether* two datasets differ, but they stop at detection. The
clinical-programming question that follows is not answered: **what changed, what
does the change represent, and which downstream analyses and outputs might be
affected?** Today this triage is done with ad-hoc diffs, spreadsheets and
institutional macros, and the result is rarely reproducible or auditable.

## Objectives

To describe an open-source R framework, `trialdiff`, that adds clinical
classification, explicit lineage and transparent impact assessment on top of
deterministic data-frame comparison, and to demonstrate an end-to-end workflow
on public data.

## Methods

`trialdiff` is built in five deterministic layers:

1. **Compare** - keyed comparison of two data cuts, reporting added, removed and
   modified observations plus schema changes. Low-level comparison can be
   delegated to `diffdf`.
2. **Classify** - priority-ordered, user-extensible rules assign a clinical
   category (new subject, new visit, corrected value, missingness transition,
   derived-variable change, treatment-assignment change, metadata change, ...)
   with a plain-language rationale for every change.
3. **Trace** - a directed lineage graph of datasets, variables, analyses and
   outputs, authored explicitly or generated from `metacore` metadata, with
   provenance and a review list for unresolved references.
4. **Assess** - a policy-driven mapping of changes onto downstream nodes, graded
   as definitely, potentially or unlikely affected, with the path and triggering
   changes recorded. Analyses and outputs are flagged for review or rerun; the
   tool never claims statistical significance.
5. **Report** - self-contained HTML/Quarto for human review and JSON for
   automated QC pipelines.

There is no machine learning: every flag is traceable to an explicit rule, a
metadata derivation and a lineage path. The framework is tested with `testthat`
(>90% coverage) and validated by `R CMD check` across macOS, Windows and Linux.

## Results

On a worked example, a single treatment-assignment change in `ADSL`
(`TRT01P = "Placebo"` to `"Drug A"`) is detected, classified as a
treatment-assignment change, and traced through
`ADSL.TRT01P -> ADLB.TRT01P -> lab summary -> MMRM -> efficacy table`, flagging
each downstream object for review with a rationale. A case study on public
`pharmaverseadam` data reproduces the full workflow from metadata-derived
lineage through to a review report, and a generated lineage from the CDISC pilot
ADaM Define-XML yields 285 edges with 18 references surfaced for manual review -
demonstrating both the automation and its honest limits.

## Conclusions

`trialdiff` complements rather than duplicates existing comparison tools. It
provides clinical programmers and statisticians with a reproducible, auditable
answer to "what changed and what might this affect?", reducing rework and
improving documentation for QC and submissions. The main open challenges are
lineage completeness (particularly the analysis/output layer) and key
reconciliation for renamed visits or parameters. The package is open source (MIT)
and available via r-universe and GitHub.

## Keywords

clinical programming, data cut, change detection, data lineage, impact
assessment, pharmaverse, ADaM, reproducibility

## Take-home messages

1. Detection is solved; classification, lineage and impact are the unmet need.
2. Transparent rules beat black boxes for regulated clinical programming.
3. Never claim statistical impact without rerunning the analysis.
