# Synthetic ADLB data cuts

Two synthetic laboratory analysis datasets (`ADLB`) with a long
structure keyed by subject, parameter and visit. The later cut adds
records for new subjects and includes corrected, missing-to-value and
value-to-missing laboratory values.

## Usage

``` r
adlb_cut1

adlb_cut2
```

## Format

A data frame with one row per subject/parameter/visit and variables:

- USUBJID:

  Unique subject identifier.

- PARAMCD:

  Parameter code.

- PARAM:

  Parameter name.

- AVISIT:

  Analysis visit.

- TRT01P:

  Planned treatment for period 01.

- AVAL:

  Analysis value.

- BASE:

  Baseline value.

- CHG:

  Change from baseline.

- ABLFL:

  Baseline flag.

An object of class `data.frame` with 384 rows and 9 columns.
