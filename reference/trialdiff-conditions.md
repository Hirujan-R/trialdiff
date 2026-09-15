# Trialdiff conditions

Structured conditions used across the package so that callers (and
automated QC pipelines) can handle errors and warnings programmatically.

## Usage

``` r
td_abort(message, class = NULL, ..., call = rlang::caller_env())

td_warn(message, class = NULL, ..., call = rlang::caller_env())

td_inform(message, ...)
```

## Arguments

- message:

  A character scalar.

- class:

  Additional condition subclasses.

- ...:

  Additional data stored on the condition.

- call:

  The calling environment.
