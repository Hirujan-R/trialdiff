# Tidy register of every detected change

Flattens a `tdiff` object into a single long table with one row per
change (added record, removed record, modified cell or schema change).
This is the machine-readable form intended for QC pipelines.

## Usage

``` r
as_register(x, ...)
```

## Arguments

- x:

  A `tdiff` object.

- ...:

  Unused.

## Value

A tibble.
