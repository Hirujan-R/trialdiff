# Contributing to trialdiff

Thanks for your interest in `trialdiff`.

## Development workflow

1.  Fork and clone the repository.

2.  Install development dependencies:

    ``` r

    install.packages(c("devtools", "roxygen2", "testthat", "pkgdown",
                       "lintr", "styler", "covr"))
    ```

3.  Make your change, add tests, and update documentation:

    ``` r

    devtools::document()
    devtools::test()
    devtools::check()
    ```

4.  Style your code with
    [`styler::style_pkg()`](https://styler.r-lib.org/reference/style_pkg.html)
    and lint with
    [`lintr::lint_package()`](https://lintr.r-lib.org/reference/lint.html).

5.  Open a pull request describing the change and referencing any issue.

## Design constraints

- Deterministic comparison only - no machine learning in the core.
- Rules must be transparent and documented.
- Impact assessment must never claim statistical significance.
- No proprietary or real patient data may be committed. Use the
  synthetic generators in `data-raw/`.

## Code style

- `snake_case` for functions and variables, `SNAKE_CASE` for constants.
- Internal helpers are prefixed with `td_`.
- Every exported function needs a roxygen block, an example, and a test.
