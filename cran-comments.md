## R CMD check results

0 errors | 0 warnings | 0 notes

## Submission type

This is a new release.

## Test environments

* Local: macOS 27.0 (aarch64), R 4.5.1 (2025-06-13)
* GitHub Actions (continuous):
  * macOS (release)
  * Windows (release)
  * Ubuntu (release)
  * Ubuntu (devel)
  * Ubuntu (oldrel-1)

## R CMD check notes

The package uses only base and recommended packages plus a small set of
CRAN dependencies (`cli`, `dplyr`, `htmltools`, `jsonlite`, `rlang`,
`tibble`). Packages listed in `Suggests` (`igraph`, `diffdf`, `waldo`,
`haven`, `admiral`, `metacore`, `cards`, `tern`, `rtables`,
`pharmaverseadam`, `pharmaversesdtm`) are used only in optional examples,
tests or documentation and are guarded with `requireNamespace()`.

## Downstream dependencies

There are currently no downstream dependencies for this package.
