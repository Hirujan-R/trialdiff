# trialdiff: Clinical Trial Data-Cut Change Detection and Downstream Impact Assessment

**Project proposal and technical design**
Version 0.0.0.9000 (development) · Status: experimental

---

## 1. Executive summary

Clinical trial datasets are regenerated repeatedly throughout a study. Between
data cuts, changes arise from new patients, updated records, data corrections,
derivation changes, protocol amendments and upstream data revisions. Detecting
*that* two datasets differ is a solved problem: `diffdf`, `waldo`, `dplyr` set
operations and SAS `PROC COMPARE` all do it well. The unmet need is the
clinical-programming question that follows:

> **What changed, what does the change represent, and which downstream analyses
> or outputs might be affected?**

`trialdiff` is an open-source R package that answers this question in five
deterministic, composable layers:

1. **Compare** - keyed comparison of two data cuts (`compare_cut()`).
2. **Classify** - a transparent, rule-based clinical change taxonomy
   (`classify_changes()`).
3. **Trace** - an explicit lineage graph of datasets, variables, analyses and
   outputs (`define_lineage()`, `trace_dependencies()`).
4. **Assess** - policy-driven downstream impact graded as *definitely*,
   *potentially* or *unlikely* affected (`assess_impact()`).
5. **Report** - human-readable HTML/Quarto and machine-readable JSON/list
   (`report_diff()`, `as_json()`).

The package deliberately does **not** reinvent low-level dataframe comparison,
does **not** use machine learning, and never claims statistical impact without a
rerun. Its value is auditable clinical context. A working prototype with tests,
synthetic data, documentation and CI is implemented alongside this proposal.

---

## 2. Problem statement

A typical study produces dozens of data cuts across SDTM and ADaM. When a new
cut arrives, a clinical programmer must answer, often under time pressure:

* Which subjects, visits, records and variables changed?
* Was the change a data correction, a new observation, a derivation change, or a
  metadata change?
* Which derived variables, analyses and TLFs consume the changed data?
* What must be rerun, and what can be left alone?
* How do I document and defend those decisions for QC and audit?

Today this is done with ad-hoc diffs, spreadsheets, institutional SAS macros and
tribal knowledge. The output is rarely reproducible, rarely linked to lineage,
and rarely auditable end-to-end. The cost is rework, missed downstream updates,
late-identified discrepancies and weak documentation.

`trialdiff` formalises the workflow into a reproducible pipeline with explicit
metadata and a written rationale for every flag.

---

## 3. Target users

| Persona | Primary need |
|---|---|
| **Clinical programmer (SDTM/ADaM)** | Understand a new data cut quickly; know what to rerun. |
| **Statistician** | Judge whether a change can plausibly affect an analysis; decide on reruns. |
| **QC reviewer / independent programmer** | Verify that a change was assessed and that decisions are documented. |
| **Data manager** | Confirm that corrections and new data were received as expected. |
| **Statistical programming lead** | Maintain lineage metadata and an impact policy across a study. |
| **Regulatory/audit reviewer** | Trace a TLF back to the data change that triggered its update. |
| **Automation/QC pipeline author** | Consume machine-readable change and impact output. |

---

## 4. Real-world clinical programming use cases

1. **Interim analysis data cut.** A new cut adds subjects and visits. The
   programmer must know which efficacy and safety TLFs need rerunning before the
   IDMC meeting.
2. **Data correction round-trip.** A site corrects a baseline lab value. The
   change propagates to `BASE`, `CHG` and an MMRM. `trialdiff` flags the chain.
3. **Treatment mis-randomisation correction.** `TRT01P` changes for one subject.
   This affects treatment-grouped summaries, exposure tables and models.
4. **Protocol amendment.** A new variable is added to `ADSL`; downstream
   derivations and outputs that should consume it are identified (and missing
   lineage is surfaced).
5. **Derivation refactor.** An `admiral` derivation changes, altering `AVAL`
   for a parameter. `trialdiff` distinguishes this from a raw-data change.
6. **Population flag change.** A subject moves in/out of `SAFFL`/`ITTFL`,
   affecting which analyses include them.
7. **Missingness review.** A value goes missing or is recovered. Clinical review
   is required before downstream summaries are trusted.
8. **Submission readiness.** Before a submission, prove that every change
   between the previous and final cut was classified, assessed and signed off.
9. **Cross-dataset consistency.** A subject-level change in `ADSL` is traced to
   subject-level records in `ADLB`, `ADAE`, `ADVS`.
10. **Automated QC gate.** A CI/CD job runs `trialdiff` on each new cut and
    fails or warns based on the impact summary.

---

## 5. Existing ecosystem / gap analysis

### 5.1 Low-level comparison

* **`diffdf`** (CRAN, MIT) compares two data frames with keys and returns a
  detailed breakdown of value, type, length, label and missingness differences.
  It is the de-facto R tool for this. It stops at detection: it has no clinical
  taxonomy, no lineage and no impact model. It is used by several `admiral`
  packages for tests.
* **`waldo`** (r-lib) is a general object-comparison engine used by `testthat`.
  It is general purpose, not clinical.
* **`datareportR`** wraps `diffdf` plus `skimr` to produce an R Markdown summary
  and diff of a dataset. It is a reporting convenience, not an impact framework.
* **`dplyr`/base R** provide joins and set operations but no semantics.
* **SAS `PROC COMPARE`** reports value, label, length, format and type
  differences with `out`, `outbase`, `outcomp`, `outdiff` datasets. It is the
  conceptual ancestor of all of the above and stops at detection.

### 5.2 Validation, metadata and lineage

* **`metacore`/`metatools`** (pharmaverse) manage ADaM/SDTM metadata and check
  datasets against it. They describe *what the data should look like*, not *what
  changed between cuts*.
* **`sdtmchecks`**, **`data.validator`**, **`pointblank`** validate conformance.
  Complementary: validation finds rule violations; `trialdiff` finds
  cut-to-cut changes.
* **`admiral`** derives ADaM. It does not compare cuts, but its derivations are
  natural lineage nodes.
* **`cards`** produces Analysis Results Data; **`tern`/`rtables`** produce TLGs.
  These are natural impact targets.
* **`xportr`/`haven`** handle transport; **`envsetup`/`renv`** handle
  reproducibility.

### 5.3 Commercial / SAS ecosystem

* SAS `PROC COMPARE` and home-grown "data cut comparison" macros report
  differences but not clinical meaning or impact.
* Commercial clinical data platforms (Pinnacle 21, CluePoints, SAS Clinical Data
  Integration, eClinical/IRV platforms) provide validation, discrepancy
  management and some review workflows, but are closed, licence-bound and not
  scriptable in the pharmaverse sense. None offers a general, open, metadata-
  driven lineage/impact model for R.

### 5.4 Gap

No existing open tool combines: (a) clinical change classification, (b)
explicit user-declared lineage from data to TLFs, and (c) a transparent,
policy-driven impact assessment with machine-readable output. That is the gap
`trialdiff` targets. It is a **thin, well-defined layer on top of** `diffdf`/
`waldo`/`dplyr`, not a replacement.

---

## 6. Comparison with existing R and SAS tools

| Capability | PROC COMPARE | diffdf | waldo | datareportR | metacore | admiral | cards/tern | **trialdiff** |
|---|---|---|---|---|---|---|---|---|
| Detect value differences | Yes | Yes | Yes | Yes | No | No | No | Yes |
| Keys / row matching | Yes | Yes | n/a | Yes | n/a | n/a | n/a | Yes |
| Type/label/length diffs | Yes | Yes | Partial | Via diffdf | Metadata | No | No | Yes |
| Clinical change categories | No | No | No | No | No | No | No | **Yes** |
| Explicit lineage graph | No | No | No | No | No | Partial (code) | Partial | **Yes** |
| Downstream impact grading | No | No | No | No | No | No | No | **Yes** |
| Machine-readable impact | No | Partial | No | No | Yes | No | ARD | **Yes** |
| Human review report | Yes (SAS) | No | No | Yes | No | No | TLGs | **Yes** |
| Open source / scriptable | No | Yes | Yes | Yes | Yes | Yes | Yes | **Yes** |

`trialdiff` is positioned as the **semantic layer**: it consumes the output
concepts of the comparison tools and the metadata concepts of the pharmaverse,
and adds classification, lineage and impact.

---

## 7. Novelty assessment

**What is not novel:** comparison of data frames; reporting diffs; metadata
validation; derivation; TLG generation. `trialdiff` must not claim these.

**What is novel:**

1. A **clinical change taxonomy** with priority-ordered, user-extensible rules
   and a retained record of *all* matching rules (not just the primary one).
2. An **explicit lineage model** whose nodes span data, variables, analyses and
   outputs, queryable in both directions.
3. A **policy-driven impact methodology** that grades impact and, critically,
   refuses to claim statistical significance; every affected analysis is a
   *review/rerun signal* with a rationale and the triggering change IDs.
4. **Lineage-gap reporting**: changes with no declared lineage are surfaced
   rather than silently ignored.
5. **End-to-end auditability**: from a TLF flag back to the data change, the
   rule that classified it, and the lineage path that reached it.

This is a genuine, if incremental, contribution. The honest framing is
"novel integration and clinical semantics", not "novel algorithm". Section 29
gives explicit go/no-go criteria.

---

## 8. Proposed package architecture

Five independent modules plus shared infrastructure:

```
trialdiff/
  compare_cut()        -> tdiff object
  classify_changes()   -> tdiff_classified (rule engine)
  define_lineage()     -> td_lineage (edge list + node table)
  trace_dependencies() -> tidy traversal result
  assess_impact()      -> td_impact (policy engine)
  report_diff()        -> td_report (HTML/Quarto/JSON/list)
```

Cross-cutting: conditions (`td_abort`/`td_warn`), utilities, S3 methods for
`print`/`summary`, and an optional `igraph` bridge.

Each layer can be used alone. A user with only a `tdiff` can classify it; a user
with only a register can classify and assess it; lineage can be defined and
traced without any comparison.

Dependency strategy: minimal hard dependencies (`cli`, `dplyr`, `glue`,
`htmltools`, `jsonlite`, `purrr`, `rlang`, `tibble`, `tidyr`). Heavier or
domain packages (`igraph`, `diffdf`, `waldo`, `haven`, `admiral`, `metacore`,
`cards`, `tern`, `rtables`) are `Suggests` and used only when present.

Class system: **S3**. The objects are lists of tibbles. S3 is sufficient, keeps
the API simple, avoids reference semantics, and is the dominant style in the
pharmaverse. R6/S4 are not justified; no mutable state is required.

---

## 9. Core data structures

### 9.1 `tdiff` (comparison)

```r
list(
  meta     = list(dataset, name_old, name_new, by, subject_var,
                  n_old, n_new, n_common, variables,
                  subjects_old, subjects_new, tolerance, generated),
  added    = tibble(keys..., .key, .subject),
  removed  = tibble(keys..., .key, .subject),
  modified = tibble(keys..., variable, old_value, new_value,
                    change, .key, .subject),
  schema   = tibble(variable, change, old_value, new_value),
  summary  = tibble(metric, value)
)
```

`change` is one of `value`, `missing_to_value`, `value_to_missing`. `schema`
`change` is one of `variable_added`, `variable_removed`, `type_change`,
`label_change`. Values are stored as display strings to keep the register
homogeneous; raw values remain in the source data.

### 9.2 Change register (`as_register()`)

A single long table, one row per change, with `.change_id` (`CHG00001`), keys,
`dataset`, `variable`, `old_value`, `new_value`, `change`, `record_type` and
`.subject`. This is the interchange format for classification, impact and JSON.

### 9.3 `tdiff_classified`

A `tdiff` with `category`, `category_label` and `reason` added to each component
table, plus `register` with `category`, `category_all`, `reason`.

### 9.4 `td_lineage`

```r
list(
  edges = tibble(from, from_type, to, to_type,
                 relationship, condition, label),
  nodes = tibble(node, type, label)
)
```

Node types: `dataset`, `variable`, `analysis`, `output`. Edges are directed
`from -> to` ("to depends on from").

### 9.5 `td_impact`

```r
list(
  impacts    = tibble(node, node_type, level, depth, path,
                      edge_relationship, seed, seed_category,
                      triggering_changes, requires_rerun, rationale),
  by_subject = tibble(subject, change_id, category, seed),
  unlinked   = tibble(node, reason),
  summary    = tibble(metric, value),
  policy     = td_policy,
  meta       = list(...)
)
```

### 9.6 `td_report`

`list(path, format, html, data)` where `data` holds every section for reuse.

---

## 10. Proposed API

```r
# Layer 1: compare
compare_cut(old, new, by,
            compare_labels = TRUE, compare_types = TRUE,
            tolerance = 1e-9, ignore_vars = NULL,
            name_old = "old", name_new = "new",
            dataset = NULL, subject_var = NULL,
            backend = c("trialdiff", "waldo"))

as_register(x)                 # long, machine-readable change table

# Layer 2: classify
classify_changes(x, rules = td_default_rules(), context = list())
td_rule(name, label, test, priority = 100L, reason = NULL)
td_default_rules()
td_categories()

# Layer 3: trace
lineage_edge(from, to, from_type = NULL, to_type = NULL,
             relationship = "derives", condition = NA, label = NA)
define_lineage(..., edges = NULL, nodes = NULL,
               dataset = NULL, variable = NULL, downstream = NULL)
trace_dependencies(x, from, direction = c("downstream", "upstream"),
                   max_depth = Inf, include_self = FALSE)
as_igraph(x)

# Layer 4: assess
impact_policy(value_direct, value_indirect, record, schema, label, max_depth)
assess_impact(changes, lineage, policy = impact_policy())

# Layer 5: report
report_diff(diff, impact = NULL, classified = NULL, output = "html",
            format = c("html", "quarto", "json", "list"))
as_json(x, pretty = TRUE)
```

The conceptual API in the brief is preserved (`compare_cut()`,
`classify_changes()`, `define_lineage()`, `trace_dependencies()`,
`assess_impact()`, `report_diff()`), with refinements: a real comparison backend
choice, a change-register interchange format, an explicit policy object, and
`as_json()` for pipelines.

---

## 11. Example workflows

### 11.1 Treatment-assignment change (the brief's example)

```r
diff <- compare_cut(adsl_cut1, adsl_cut2, by = "USUBJID", dataset = "ADSL")
classified <- classify_changes(diff)

lineage <- define_lineage(
  lineage_edge("ADSL.TRT01P", "ADLB.TRT01P", relationship = "groups_by"),
  lineage_edge("ADLB.TRT01P", "Lab_Summary", relationship = "summarises"),
  lineage_edge("Lab_Summary", "Table_14_2_1", relationship = "reports"),
  lineage_edge("ADLB.AVAL", "MMRM", relationship = "models"),
  lineage_edge("MMRM", "Table_14_2_2", relationship = "reports")
)

impact <- assess_impact(classified, lineage)
report_diff(diff, impact = impact, output = "report.html")
```

`ADSL.TRT01P` is classified as a treatment-assignment change and
`ADLB.TRT01P -> Lab_Summary -> Table_14_2_1` are flagged for review.

### 11.2 New cut gate in a QC pipeline

```r
impact <- compare_cut(prev, curr, by = keys, dataset = "ADLB") |>
  classify_changes() |>
  assess_impact(lineage)

if (any(impact$impacts$requires_rerun)) {
  writeLines(as_json(impact), "impact.json")
  stop("Reruns required; see impact.json")
}
```

### 11.3 Lineage-only tracing

```r
trace_dependencies(lineage, from = "ADLB.AVAL")
trace_dependencies(lineage, from = "Table_14_2_1", direction = "upstream")
```

---

## 12. Lineage / dependency model

**Graph, not a tree.** A variable can feed several analyses; an analysis can
feed several outputs; outputs can share inputs. A DAG is the right abstraction,
and the implementation stores an adjacency list so no graph library is required.

**Nodes** are identified by a convention (`ADSL`, `ADSL.TRT01P`, `MMRM`,
`Table_14_2_1`) and typed. Types can be overridden via a `nodes` table.

**Edges** carry:

* `relationship`: `derives`, `groups_by`, `filters`, `summarises`, `models`,
  `reports`, `transports`;
* `condition`: a free-text applicability condition (recorded, not evaluated);
* `label`.

**Traversal** is breadth-first, cycle-safe, depth-limited, and returns the full
path so every impact flag is explainable. Upstream traversal answers "what
feeds this TLF?".

**Why a graph is appropriate:** impact propagation is inherently transitive and
many-to-many. A graph gives correct reachability, supports both directions, and
maps cleanly onto `igraph` for visualisation if desired.

**Metadata sources:** edges can be authored directly, generated from `admiral`
derivation code (future), or derived from `metacore` metadata (future). The
current version keeps lineage explicit and user-owned, which is the only way to
guarantee auditability.

---

## 13. Change-classification system

Rules are predicates over the change register, evaluated in ascending priority;
the first match sets the primary category, and all matches are kept in
`category_all`. Built-in categories:

| Category | Trigger |
|---|---|
| `variable_added` / `variable_removed` | schema change |
| `type_change` | variable class changed |
| `label_change` | variable label changed |
| `new_subject` | added record whose subject is absent from the old cut |
| `subject_removed` | removed record whose subject is absent from the new cut |
| `new_assessment` | added record in a parameterised dataset |
| `new_visit` | added record in a visit-based dataset |
| `new_record` / `record_removed` | fallback row changes |
| `treatment_assignment_change` | modified treatment/randomisation variable |
| `missing_to_value` / `value_to_missing` | missingness transition |
| `derived_variable_change` | modified known derived variable |
| `corrected_value` | any other value change |
| `unclassified` | no rule matched; surfaced for review |

Priority resolves overlap: treatment assignment outranks missingness, which
outranks the generic derived-variable rule, which outranks `corrected_value`.
Rules are user-extensible via `td_rule()`; custom rules can be prepended or
interleaved. `unclassified` is never silently dropped.

---

## 14. Impact-assessment methodology

For every change, seeds are derived:

* **modified cell** -> `dataset.variable`;
* **record added/removed** -> the dataset node and every declared variable node
  of that dataset;
* **schema change** -> `dataset.variable` (plus the dataset for variable
  additions/removals).

Seeds are traced downstream. Each reached node is graded by
`impact_policy()`:

* a **variable** derived directly (depth 1, relationship in
  `derives`/`groups_by`/`filters`/`transports`) from a changed value is
  `definitely_affected`;
* other variable effects, and all analysis/output effects, are
  `potentially_affected`;
* label-only changes default to `unlikely`;
* schema changes default to `potentially_affected`.

Where a node is reachable via several changes, the worst level wins; the path
shown is the one that produced the worst level. Analyses and outputs graded
`definitely`/`potentially` get `requires_rerun = TRUE`.

**No statistical claims.** The methodology is explicitly a *review signal*. The
report states that statistical impact requires rerunning the analysis. This is a
deliberate epistemic boundary and a regulatory safeguard.

**Policy is documented and configurable** so a study team can record its
conventions, and the same change set can be re-assessed under a different policy
reproducibly.

---

## 15. Reporting design

`report_diff()` renders:

1. comparison overview (counts, keys, cuts);
2. changes by category;
3. added observations;
4. removed observations;
5. modified values with old/new, category and reason;
6. schema changes;
7. downstream impact summary and affected objects (with path, level, rerun
   flag);
8. lineage gaps;
9. items requiring review, with an owner (Programmer/Statistician);
10. a disclaimer.

Formats:

* **HTML** - self-contained, no external assets, suitable for emailing or
  archiving.
* **Quarto** - a template for teams that want to extend the report.
* **JSON** - machine-readable for QC pipelines (`as_json()`).
* **list** - in-memory for programmatic use.

Tables are truncated in HTML with an explicit "showing N of M" note so nothing
is hidden.

---

## 16. Integration with pharmaverse packages

| Package | Integration |
|---|---|
| `haven` | Import SAS/SPSS/Stata datasets; labels read from the `label` attribute. |
| `admiral` | Derivations become lineage nodes; no runtime dependency required. |
| `metacore`/`metatools` | Supply variable labels/types and (future) auto-generate lineage. |
| `cards` | ARD-producing analyses are lineage analysis nodes. |
| `tern`/`rtables` | TLF outputs are lineage output nodes. |
| `pharmaverseadam`/`pharmaversesdtm` | Public datasets for examples and tests. |
| `diffdf` | Alternative low-level comparison backend (planned adapter). |
| `waldo` | Optional whole-column equality backend (`backend = "waldo"`). |
| `xportr` | Transport of flagged datasets; no direct coupling. |

The package is designed to be **metadata-friendly**: if a study already has
`metacore` metadata and `admiral` code, lineage can be generated from them in a
future release. Until then, lineage is explicit, which is the safest default.

---

## 17. Testing strategy

* **`testthat` (edition 3)** across all layers.
* Unit tests for comparison (added/removed/modified, missingness, tolerance,
  labels, types, duplicate/missing keys, empty-safe, waldo backend).
* Classification tests including custom rules, priority resolution, and
  `unclassified` handling.
* Lineage tests for type inference, both traversal directions, depth limits,
  cycle safety, empty results, and the optional `igraph` bridge.
* Impact tests for definite/potential grading, policy overrides, unlinked
  changes, affected subjects and empty input.
* Reporting tests for HTML, JSON and file writing (using `withr` temp files).
* **End-to-end pipeline test** on the synthetic ADSL/ADLB data.
* Error conditions tested by class (`trialdiff_error_*`).
* Coverage target: > 90% for core logic, measured by `covr`.

---

## 18. Synthetic test-data strategy

All data are synthetic (`data-raw/synthetic-data.R`, seed 2026):

* `adsl_cut1`/`adsl_cut2`: 30 subjects, with two new subjects, one withdrawal, a
  treatment-assignment correction, age corrections, missingness transitions, a
  new variable (`REGION`) and a label change.
* `adlb_cut1`/`adlb_cut2`: long subject/parameter/visit data with added records,
  corrected values, and missingness transitions.
* `adsl_adlb_lineage`: a worked lineage graph.

Generators are committed and reproducible. No proprietary or real patient data
is used anywhere. Public datasets (`pharmaverseadam`) are `Suggests` for
optional, richer examples.

---

## 19. Documentation strategy

* **roxygen2** for all exported functions, with examples that run.
* **pkgdown** site with reference organised by layer and four articles.
* **Vignettes**: getting started, change classification, lineage and impact,
  ecosystem positioning.
* **README** with a quick start and a positioning table.
* **NEWS.md** maintained per release.
* **CONTRIBUTING.md** with design constraints (deterministic, transparent, no
  statistical claims).

---

## 20. CI/CD strategy

* **GitHub Actions**
  * `R-CMD-check.yaml`: matrix over macOS, Windows, Ubuntu (release, devel,
    oldrel-1) with `rcmdcheck`.
  * `test-coverage.yaml`: `covr` to Codecov.
  * `lint.yaml`: `lintr::lint_package()`.
  * `pkgdown.yaml`: build and deploy to GitHub Pages on push to `main`.
* **Local tooling**: `styler`, `lintr`, `covr`, `devtools` (documented in
  CONTRIBUTING).
* **Reproducibility**: pinned CI dependencies via `r-lib/actions`; `renv`
  recommended for study-level use.

---

## 21. Potential limitations

1. **Comparison is keyed and exact-ish.** Changes in key variables appear as
   remove+add, not modify. Fuzzy key matching is out of scope.
2. **No statistical impact.** By design; a rerun is required to confirm.
3. **Impact quality depends on lineage completeness.** Missing lineage yields
   "unlinked" warnings, not silent correctness.
4. **Row-level changes seed all dataset variables**, which can over-flag. The
   policy can tune levels but not the seeding; finer control is future work.
5. **Register stores display strings**, so very wide or list-column data may need
   care.
6. **Memory** scales with the number of changed cells, not total cells, but a
   complete rewrite of a large dataset will still be large.
7. **Lineage is manual** until metadata-driven generation lands.
8. **No cross-dataset referential comparison** (e.g. orphan records) beyond
   lineage propagation.

---

## 22. Regulatory / GxP considerations

* **Deterministic and auditable.** Every flag has a rule, a path and a reason.
  Nothing is inferred by an opaque model, which is essential for validation.
* **No statistical claims.** The tool explicitly defers statistical judgement to
  a rerun, avoiding overstatement.
* **Reproducibility.** Comparison, classification and impact are pure functions
  of inputs, policy and lineage metadata; reports embed a timestamp and can
  embed session information (future).
* **Validation.** For GxP use, a study would need installation qualification,
  an operational qualification script (the test suite is a starting point), and
  documented SOPs. `trialdiff` should be treated as a programming aid, not a
  replacement for validated QC.
* **Audit trail.** JSON output and the register provide a record of what was
  detected and decided; signatures/version control remain the responsibility of
  the study's eTMF/QC process.
* **Version pinning.** Studies should pin the package version (e.g. `renv`) so
  classification behaviour is stable across cuts.

---

## 23. Security and data-privacy considerations

* **No data leaves the machine.** The package performs no network calls and
  transmits nothing.
* **No proprietary data in the repository.** Only synthetic generators and
  public datasets are used.
* **Reports contain patient-level identifiers** (e.g. `USUBJID`). HTML/JSON
  output must be handled under the study's data-protection policy; reports
  should be stored in controlled locations.
* **No secrets.** The package requires no credentials and reads no environment
  secrets.
* **Safe defaults.** No file is written unless the user passes a path; nothing
  is executed from data (conditions in lineage are recorded, not evaluated).

---

## 24. Roadmap from MVP to production

**v0.0.x (implemented prototype)**
* `compare_cut()`, `classify_changes()`, `define_lineage()`,
  `trace_dependencies()`, `assess_impact()`, `report_diff()`.
* Synthetic data, tests, vignettes, CI.

**v0.1 - hardening**
* `diffdf` backend adapter.
* `metacore`-driven variable type/label enrichment.
* Session-info and package-version stamping in reports.
* Quarto template completed.
* Property-based tests (e.g. `quickcheck`) for comparison invariants.

**v0.2 - lineage at scale**
* Lineage import from a tidy specification (CSV/YAML) and from `metacore`.
* Lineage visualisation via `igraph`/`visNetwork`.
* Per-variable seeding granularity and edge weights/sensitivity.

**v0.3 - pharmaverse integration**
* Adapters for `admiral` derivation metadata and `cards` ARDs.
* `tern`/`rtables` output registry helper.
* `sdtmchecks`/`data.validator` complementary reporting.

**v1.0 - production**
* Stable API, CRAN submission, comprehensive validation documentation.
* Signed releases, pkgdown site, case studies on public data.
* Performance work for large SDTM/ADaM datasets.

---

## 25. Suggested GitHub repository structure

```
trialdiff/
├── DESCRIPTION, NAMESPACE, LICENSE, LICENSE.md
├── README.md, NEWS.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md
├── _pkgdown.yml, .lintr, .Rbuildignore, .gitignore
├── .github/workflows/{R-CMD-check,test-coverage,lint,pkgdown}.yaml
├── R/
│   ├── trialdiff-package.R, conditions.R, utils.R
│   ├── compare_cut.R, tdiff-object.R
│   ├── rules.R, classify_changes.R
│   ├── lineage.R, impact.R, report.R, data.R
├── man/                      # generated by roxygen2
├── tests/testthat/           # unit + pipeline tests
├── vignettes/                # 4 articles
├── data/                     # synthetic .rda
├── data-raw/synthetic-data.R
├── inst/templates/           # report templates
└── docs/                     # pkgdown site + proposal
    └── proposal/trialdiff-proposal.md
```

---

## 26. Example README

See the repository [`README.md`](../../README.md). It contains the positioning
statement, installation, a quick start mirroring the brief's example, the
comparison-with-`diffdf` rationale, and design principles.

---

## 27. End-to-end demonstration

Using the shipped synthetic data:

```r
library(trialdiff)

diff <- compare_cut(adsl_cut1, adsl_cut2, by = "USUBJID", dataset = "ADSL")
classified <- classify_changes(diff)

impact <- assess_impact(classified, adsl_adlb_lineage)

impact$impacts[, c("node", "node_type", "level", "depth", "requires_rerun")]
# ADLB.TRT01P            variable definitely_affected 1  FALSE
# ADSL.TRT01A            variable definitely_affected 1  FALSE
# Lab_Summary_By_Treatment analysis potentially_affected 2 TRUE
# MMRM                   analysis potentially_affected 2 TRUE
# Table_14_2_1           output   potentially_affected 3 TRUE
# Table_14_2_2           output   potentially_affected 3 TRUE

report_diff(diff, impact = impact, output = "cut-review.html")
```

The report lists the detected treatment-assignment change, its classification
and reason, the affected downstream objects with paths, the rerun list and any
lineage gaps.

---

## 28. Potential research / technical challenges

1. **Key stability.** In long datasets, keys themselves can change (e.g. a visit
   renamed). Detecting renames versus remove+add is a matching problem; fuzzy or
   rules-based key reconciliation is an open design question.
2. **Lineage completeness.** The framework is only as good as its lineage.
   Generating lineage from `admiral` code or `metacore` metadata is the highest-
   value future work.
3. **Semantic equivalence.** A value can change representation without changing
   meaning (format, precision, controlled terminology). Distinguishing semantic
   from cosmetic change is hard and partly study-specific.
4. **Over- and under-flagging.** Record-level seeding is coarse. Edge
   sensitivity/weights and condition evaluation could refine it.
5. **Scale.** SDTM datasets can be millions of rows; the current implementation
   is vectorised but stores changed cells in memory. Streaming or chunked
   comparison may be needed.
6. **Rule conflicts.** As custom rule sets grow, overlaps increase. Priority plus
   `category_all` mitigates but does not eliminate the need for governance.
7. **Reproducibility across versions.** Rule changes alter classification; version
   stamping and pinned dependencies are required for regulatory defensibility.
8. **Terminology mapping.** `TRT01P`-style variable lists and derived-variable
   lists are hard-coded heuristics; they should become configurable metadata.

---

## 29. Criteria for deciding whether the project is novel enough to pursue

`trialdiff` should be pursued **only if** it clears all of the following bars.
If it fails more than one, reposition or stop.

**Go criteria**

1. **No existing open tool** provides clinical change classification *plus*
   explicit lineage *plus* policy-driven impact assessment with machine-readable
   output. (Current assessment: satisfied.)
2. **A real, recurring workflow** exists that people do manually today
   (data-cut review and rerun triage). (Satisfied.)
3. **Complementarity**: it can consume `diffdf`/`waldo` and pharmaverse metadata
   rather than compete with them. (Satisfied by design.)
4. **Auditability**: every output can be explained by explicit inputs, with no
   ML. (Satisfied.)
5. **Adoption path**: usable as a standalone script, embeddable in QC pipelines,
   and eventually integrable into pharmaverse metadata. (Plausible.)
6. **Credible as a portfolio project**: non-trivial graph, rule-engine,
   reporting and testing engineering, with a documented gap analysis.
   (Satisfied.)

**No-go / reposition triggers**

1. `diffdf` or a pharmaverse package ships an equivalent lineage/impact layer
   (would make `trialdiff` largely redundant).
2. Clinical programmers report that impact triage is already solved by existing
   SOPs and do not need tooling.
3. Lineage authoring proves so burdensome that nobody maintains it; in that
   case, reposition as a **lineage-generator** from `admiral`/`metacore` rather
   than an impact assessor.
4. The value collapses to "a nicer `diffdf` report"; in that case, contribute
   the reporting to `diffdf`/`datareportR` instead of a new package.

**Verdict.** The current evidence supports pursuit as a focused,
well-scoped semantic layer, with the honest caveat that the novelty is in
integration and clinical semantics rather than algorithms. The strongest
near-term differentiators to invest in are (a) metadata-driven lineage
generation and (b) the auditable impact policy, because those are the parts no
existing tool offers.

---

*No proprietary or real patient data was used in the preparation of this
proposal or in the accompanying package. All datasets are synthetic.*
