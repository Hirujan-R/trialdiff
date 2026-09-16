# pharmaverse application

Status: **prepared, not yet submitted** (requires a package co-lead from a
pharmaverse member organisation and a community review).

This document maps `trialdiff` against the pharmaverse
[minimum inclusion criteria](https://pharmaverse.org/contribute/lead/) and lists
the concrete steps and gaps. It is a working checklist, not a claim of
acceptance.

## Inclusion criteria checklist

| Criterion | Requirement | trialdiff status |
|---|---|---|
| License | Permissive (Apache-2.0 recommended, MIT acceptable) | **Met** - MIT |
| Hosting | Public source, public issue tracker | **Met** - GitHub, issues enabled |
| Documentation | All exports documented; passes `R CMD check` docs | **Met** - roxygen2, `Status: OK` |
| Website | Package site with context vignettes | **Met** - pkgdown, 5 articles |
| Hex logo | Preferable | **Met** - `man/figures/logo.png` |
| CI | `R CMD check` on latest R | **Met** - GitHub Actions, 5 platforms |
| Versioning | Semantic versioning | **Met** - `0.2.0`, tagged releases |
| Dependencies | Limited, intentional | **Met** - 6 Imports, rest `Suggests` |
| Maintenance | Active issue monitoring and bug fixes | **Committed** - needs an ongoing owner |
| Branching | Protected main; separate development branch | **Partial** - main protected; add a `dev` branch |
| Release CI | Extra testing on Windows/Linux/macOS for releases | **Met** - matrix on every push |
| CRAN | Not required; favourable; if on CRAN, stay on CRAN | **Gap** - not yet submitted |

## Remaining gaps

1. **Package co-lead** - a co-lead from a pharmaverse member organisation is
   required before submission. This is the blocking item.
2. **CRAN submission** - not started. The package is pure R with a small
   dependency set, so this is feasible (see `cran-comments.md`).
3. **Development branch** - create `dev` and adopt a main/dev workflow.
4. **Community testing** - recruit at least one external organisation to test on
   their environment (synthetic or their own data), as recommended.

## Submission process

1. Confirm no existing pharmaverse package already covers this scope. As of
   writing, no open tool combines clinical change classification, explicit
   lineage and policy-driven impact assessment; `diffdf` covers only low-level
   comparison.
2. Contact a pharmaverse council representative (via the
   [pharmaverse Slack](https://pharmaverse.slack.com)) to discuss scope and find
   a co-lead.
3. Once a co-lead is agreed, the website team shares the application with the
   community for review.
4. If accepted, add the pharmaverse hosted badge and consider moving hosting
   under `github.com/pharmaverse`.

## Draft application message

> **Package:** trialdiff - clinical-trial data-cut change detection and
> downstream impact assessment
>
> **Repository:** https://github.com/Hirujan-R/trialdiff
> **Site:** https://hirujan-r.github.io/trialdiff/
>
> **Scope:** trialdiff detects changes between two data cuts of a clinical
> dataset, classifies them with a transparent, rule-based clinical taxonomy,
> traces user-declared lineage (optionally generated from `metacore` metadata),
> and assesses which downstream analyses and outputs may be affected.
>
> **How it complements pharmaverse:** it does not replace `diffdf`; it can even
> use `diffdf` as its comparison backend. It consumes `metacore` metadata for
> lineage, and points at `admiral` derivations, `cards` ARDs and `tern`/`rtables`
> outputs as impact targets.
>
> **Uniqueness:** no existing package provides clinical change classification,
> explicit lineage and auditable impact assessment together. Impact is a review
> signal only; the tool never claims statistical significance.
>
> **Maturity:** v0.2.0, MIT, documented exports, pkgdown site, CI across
> macOS/Windows/Linux (release, devel, oldrel-1), >90% test coverage, synthetic
> and public example data only.
>
> **Ask:** a co-lead from a member organisation and community testing.

## Evidence to attach

* `R CMD check` status (0 errors / 0 warnings / 0 notes).
* CI matrix links.
* Coverage report (Codecov).
* The project proposal and gap analysis (`proposal/trialdiff-proposal.md`,
  section 5).
