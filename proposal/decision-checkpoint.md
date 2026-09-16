# Decision checkpoint: is trialdiff worth pursuing?

This is a structured checkpoint against the go/no-go criteria in
`proposal/trialdiff-proposal.md` (section 29). It is meant to be run with a
practising clinical programmer or statistician - ideally two or three, from
different organisations. It should take about 30-45 minutes.

The goal is to decide whether to keep investing, pivot, or stop. Be willing to
hear "no".

## Who to ask

* A clinical programmer who regularly compares data cuts on live studies.
* A statistician who decides which TLFs are rerun after a cut.
* Ideally someone responsible for QC or submission documentation.

## Interview guide

Ask open questions first, then the specific probes.

**Current practice**

1. Walk me through what you do when a new data cut arrives. What tools do you
   use, and what takes the most time?
2. How do you decide which TLFs to rerun? Is that decision documented anywhere?
3. Have you ever missed a downstream update that a data change should have
   triggered? What happened?
4. How do you currently record lineage from data to TLFs, if at all?

**The proposed tool**

5. If a tool classified every change and told you which analyses it touches,
   would that change your process? How?
6. Would you trust a rule-based classification you can inspect, over an ad-hoc
   diff? What would it take for you to trust it?
7. Who would maintain the lineage metadata, and how much effort is acceptable
   per study? (This is the key adoption question.)
8. Would generating lineage from `metacore`/Define-XML cover enough of your
   needs, or is the analysis/output layer the hard part?
9. What would make you *not* use this? (Licensing, validation, GxP, dependency
   policy, internal SOPs, IT restrictions.)

**Positioning**

10. Does this duplicate anything you already have? If so, what exactly?
11. Is "never claim statistical impact, flag for rerun" the right stance, or do
    you want a stronger statement?
12. Would it be more useful as a standalone package or as a feature contributed
    to `diffdf`/`datareportR`?

## Scorecard

Rate each from 1 (no) to 5 (yes). Record evidence, not just a number.

| # | Criterion (from proposal section 29) | Score | Evidence |
|---|---|---|---|
| 1 | No existing open tool does classification + lineage + impact | | |
| 2 | The workflow is real and recurring, and done manually today | | |
| 3 | It complements `diffdf`/pharmaverse rather than competing | | |
| 4 | Outputs are auditable and explainable with no ML | | |
| 5 | Adoptable as a script, in QC pipelines, and via metadata | | |
| 6 | Credible as a substantial portfolio project | | |
| 7 | Lineage authoring is sustainable in practice | | |

## Decision rules

* **Pursue** if criteria 1-6 average >= 4 **and** criterion 7 (lineage
  sustainability) is >= 3.
* **Pivot** to a lineage generator if criterion 7 is low (< 3) but criteria 1-2
  are high: the burden is metadata authoring, so generate it from
  `metacore`/`admiral` and de-emphasise manual impact assessment.
* **Contribute upstream** if criterion 1 is low (an existing tool already covers
  it) or the value collapses to "a nicer `diffdf` report": add the reporting and
  classification to `diffdf`/`datareportR` instead.
* **Stop** if criteria 1 and 2 are both low.

## Record of the session

| Field | Value |
|---|---|
| Date | |
| Participants | |
| Organisation(s) / role(s) | |
| Outcome | pursue / pivot / contribute upstream / stop |
| Top three reasons | |
| Conditions or follow-ups | |
| Owner and review date | |

## Known signals from the build (pre-interview)

* The CDISC pilot ADaM Define-XML generated 285 lineage edges but surfaced 18
  references for review, mostly prose derivations (windowing rules, population
  flags). Automation works for explicit derivations; free text still needs a
  human. This is the strongest argument for the "pivot to lineage generator"
  option if maintainers find authoring burdensome.
* The analysis/output layer is not described by data metadata and is always
  user-supplied. That is either a small, acceptable task or the adoption
  blocker - the interviews should decide which.
