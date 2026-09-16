# Lineage and impact assessment

## The lineage model

Lineage is a directed graph. An edge `from -> to` means “`to` depends on
`from`”. Node identifiers follow a simple convention:

| Identifier     | Type     |
|----------------|----------|
| `ADSL`         | dataset  |
| `ADSL.TRT01P`  | variable |
| `MMRM`         | analysis |
| `Table_14_2_1` | output   |

``` r

library(trialdiff)
lineage <- define_lineage(
  lineage_edge("ADSL.TRT01P", "ADLB.TRT01P", relationship = "groups_by"),
  lineage_edge("ADLB.AVAL", "ADLB.BASE", relationship = "derives"),
  lineage_edge("ADLB.AVAL", "ADLB.CHG", relationship = "derives"),
  lineage_edge("ADLB.AVAL", "MMRM", relationship = "models"),
  lineage_edge("MMRM", "Table_14_2_1", relationship = "reports")
)
lineage
#> 
#> ── trialdiff lineage ───────────────────────────────────────────────────────────
#> 5 edges, 7 nodes
#> analysis: 1
#> output: 1
#> variable: 5
```

Edges can carry a `condition`, for example `TRT01P == "Drug A"`, which
is recorded for transparency but not evaluated by the package.

## Tracing

[`trace_dependencies()`](https://Hirujan-R.github.io/trialdiff/reference/trace_dependencies.md)
performs a breadth-first traversal and returns the path taken, so every
flag can be explained.

``` r

trace_dependencies(lineage, from = "ADLB.AVAL")
#> # A tibble: 4 × 5
#>   node         node_type depth path                            edge_relationship
#>   <chr>        <chr>     <int> <chr>                           <chr>            
#> 1 ADLB.BASE    variable      1 ADLB.AVAL -> ADLB.BASE          derives          
#> 2 ADLB.CHG     variable      1 ADLB.AVAL -> ADLB.CHG           derives          
#> 3 MMRM         analysis      1 ADLB.AVAL -> MMRM               models           
#> 4 Table_14_2_1 output        2 ADLB.AVAL -> MMRM -> Table_14_… reports
```

Upstream tracing is also supported:

``` r

trace_dependencies(lineage, from = "Table_14_2_1", direction = "upstream")
#> # A tibble: 2 × 5
#>   node      node_type depth path                              edge_relationship
#>   <chr>     <chr>     <int> <chr>                             <chr>            
#> 1 MMRM      analysis      1 Table_14_2_1 -> MMRM              reports          
#> 2 ADLB.AVAL variable      2 Table_14_2_1 -> MMRM -> ADLB.AVAL models
```

## Impact assessment

[`assess_impact()`](https://Hirujan-R.github.io/trialdiff/reference/assess_impact.md)
maps classified changes onto the lineage graph. Each reached node is
graded and given a rationale.

``` r

classified <- classify_changes(
  compare_cut(adsl_cut1, adsl_cut2, by = "USUBJID", dataset = "ADSL")
)
impact <- assess_impact(classified, adsl_adlb_lineage)
impact$impacts[, c("node", "node_type", "level", "depth", "requires_rerun")]
#> # A tibble: 8 × 5
#>   node                     node_type level                depth requires_rerun
#>   <chr>                    <chr>     <chr>                <int> <lgl>         
#> 1 ADLB.TRT01P              variable  definitely_affected      1 FALSE         
#> 2 ADSL.TRT01A              variable  definitely_affected      1 FALSE         
#> 3 Efficacy_Set             analysis  potentially_affected     1 TRUE          
#> 4 Safety_Set               analysis  potentially_affected     1 TRUE          
#> 5 Lab_Summary_By_Treatment analysis  potentially_affected     2 TRUE          
#> 6 MMRM                     analysis  potentially_affected     2 TRUE          
#> 7 Table_14_2_1             output    potentially_affected     3 TRUE          
#> 8 Table_14_2_2             output    potentially_affected     3 TRUE
```

The grading rules are exposed through \[impact_policy()\], so a study
team can agree and document its own conventions.

``` r

impact_policy()
#> 
#> ── trialdiff impact policy
#> value_direct: "definitely_affected"
#> value_indirect: "potentially_affected"
#> record: "potentially_affected"
#> schema: "potentially_affected"
#> label: "unlikely"
#> max_depth: Inf
```

## Why “definitely” versus “potentially”?

A downstream *variable* that is derived directly from a changed variable
is marked `definitely_affected`, because the derivation
deterministically reads the changed value. Analyses and outputs are
marked `potentially_affected`: whether a summary or model result
actually changes depends on the data and the method, and can only be
confirmed by rerunning.

## Lineage gaps

If a changed node has no declared lineage, `trialdiff` does not guess.
It lists the gap and asks for review:

``` r

impact$unlinked
#> # A tibble: 5 × 2
#>   node        reason                                                            
#>   <chr>       <chr>                                                             
#> 1 ADSL        No lineage edge declared for this node; downstream impact cannot …
#> 2 ADSL.AGE    No lineage edge declared for this node; downstream impact cannot …
#> 3 ADSL.SEX    No lineage edge declared for this node; downstream impact cannot …
#> 4 ADSL.RACE   No lineage edge declared for this node; downstream impact cannot …
#> 5 ADSL.REGION No lineage edge declared for this node; downstream impact cannot …
```

This is a feature, not a limitation: the impact assessment is only as
complete as the lineage metadata, and the report makes that explicit.

## Generating lineage from metadata

Hand-authoring lineage does not scale. If you already maintain a object
(from Define-XML or a specification workbook),
[`lineage_from_metadata()`](https://Hirujan-R.github.io/trialdiff/reference/lineage_from_metadata.md)
derives the data and derived-variable portion of the graph from the
`derivations` and `where` metadata:

``` r

mc <- metacore::define_to_metacore("define.xml")
lin <- lineage_from_metadata(mc)
trace_dependencies(lin, from = "ADSL.TRT01P")
```

Edges carry their provenance, and anything that cannot be resolved is
listed for review rather than guessed:

``` r

lineage_provenance(lin)
lineage_review(lin)
```

Analysis and output dependencies are not described by data metadata, so
that part of the graph is still supplied by the study team and merged
in.
