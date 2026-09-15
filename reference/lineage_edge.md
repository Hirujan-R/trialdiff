# Define a lineage edge

A lineage edge states that `to` depends on `from`. Node identifiers use
a simple convention:

## Usage

``` r
lineage_edge(
  from,
  to,
  from_type = NULL,
  to_type = NULL,
  relationship = "derives",
  condition = NA_character_,
  label = NA_character_
)
```

## Arguments

- from, to:

  Character node identifiers. `to` depends on `from`.

- from_type, to_type:

  Optional node types (`"dataset"`, `"variable"`, `"analysis"`,
  `"output"`). Inferred when `NULL`.

- relationship:

  Edge semantics. One of `"derives"`, `"groups_by"`, `"filters"`,
  `"summarises"`, `"models"`, `"reports"`, `"transports"` or a custom
  string.

- condition:

  Optional condition restricting when the edge applies (for example
  `"TRT01P == 'Drug A'"`). Recorded for transparency; not evaluated.

- label:

  Optional human-readable label.

## Value

A tibble with one row and class `td_edge`.

## Details

- a dataset is written as `"ADSL"`;

- a dataset variable is written as `"ADSL.TRT01P"`;

- an analysis is written as `"MMRM"`;

- an output (TLF) is written as `"Table_14_2_1"`.
