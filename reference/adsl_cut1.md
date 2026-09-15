# Synthetic ADSL data cuts

Two synthetic subject-level analysis datasets (`ADSL`) representing two
data cuts of the same study. No proprietary or real patient data is
used. The later cut contains new subjects, a withdrawn subject, a
treatment-assignment correction, age corrections, missingness changes, a
new variable (`REGION`) and a label change for `AGE`.

## Usage

``` r
adsl_cut1

adsl_cut2
```

## Format

A data frame with one row per subject and variables:

- STUDYID:

  Study identifier.

- USUBJID:

  Unique subject identifier.

- SUBJID:

  Subject identifier within study.

- SITEID:

  Investigator site identifier.

- AGE:

  Age.

- SEX:

  Sex.

- RACE:

  Race.

- TRT01P:

  Planned treatment for period 01.

- TRT01A:

  Actual treatment for period 01.

- SAFFL:

  Safety population flag.

- ITTFL:

  Intention-to-treat population flag.

- REGION:

  Geographic region (later cut only).

An object of class `data.frame` with 31 rows and 12 columns.
