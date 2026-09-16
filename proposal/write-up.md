# Beyond `diffdf`: what changed between data cuts, and what does it affect?

*A short write-up / blog post.*

Every clinical programmer knows the ritual. A new data cut lands. You diff it
against the last one. `diffdf` (or `PROC COMPARE`, or a home-grown macro) tells
you that 412 cells changed across `ADSL`, `ADLB` and `ADAE`. And then the real
work starts, because the tool cannot tell you the three things you actually need
to know:

1. What do those changes *mean* clinically?
2. Which downstream analyses and TLFs consume the changed data?
3. What has to be rerun, and what can be left alone?

That triage is where the time goes, and it is usually done with a mix of memory,
spreadsheets and tribal knowledge. It is rarely reproducible, and it is rarely
documented in a way that would satisfy an audit.

`trialdiff` is an open-source R package that fills that gap. It does not try to
replace `diffdf`; it sits on top of deterministic comparison and adds three
things that are specific to clinical programming.

**Classification.** Every detected change is categorised by transparent,
priority-ordered rules: new subject, new visit, corrected value,
missing-to-value, derived-variable change, treatment-assignment change, metadata
change, and so on. Every change carries a plain-language reason. There is no
machine learning and no hidden scoring - you can read the rule that fired.

**Lineage.** You declare how datasets, variables, analyses and outputs depend on
one another - or generate the data and derived-variable portion automatically
from a `metacore` object. Either way, the graph is explicit, reproducible and
carries provenance. A treatment change in `ADSL.TRT01P` can be traced through
`ADLB.TRT01P`, a by-treatment summary and an MMRM to the efficacy table that
reports it.

**Impact.** Changes are mapped onto the lineage graph and graded as definitely,
potentially or unlikely affected, with the path and the triggering changes
recorded. Crucially, `trialdiff` never claims statistical impact: analyses are
flagged for review or rerun. Whether a model result actually moves can only be
answered by rerunning it, and the package says so.

The output is a review report - HTML for humans, JSON for automated QC
pipelines - listing what changed, how it was classified, what it touches, and
what a programmer or statistician must check.

A concrete example. A subject's planned treatment is corrected from Placebo to
Drug A. `trialdiff` detects the cell change, classifies it as a
treatment-assignment change, follows the lineage through the laboratory data to
the by-treatment summary and the MMRM, and flags each downstream object for
review. The report shows the path and the reason, so the decision to rerun is
documented rather than remembered.

The package is deliberately boring in the best way. Comparison is exact and
keyed. Classification is rule-based and extensible. Lineage is metadata, not
guesswork. Impact is a policy you can read, agree and version. Nothing is
inferred by a model, which is exactly what you want in a regulated environment.

It also plays nicely with the existing ecosystem. It can use `diffdf` as its
comparison backend, it reads `metacore` metadata to generate lineage, and
`admiral` derivations, `cards` ARDs and `tern`/`rtables` outputs are natural
lineage nodes. It complements these tools rather than competing with them.

`trialdiff` is MIT-licensed and available via r-universe and GitHub. There is a
full project proposal with a gap analysis, a worked case study on public
`pharmaverseadam` data, and a live documentation site. If you write or review
clinical code, the question it answers is one you have almost certainly had to
answer by hand.

*The package and proposal are at https://github.com/Hirujan-R/trialdiff and
https://hirujan-r.github.io/trialdiff/.*
