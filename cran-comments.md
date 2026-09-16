## R CMD check results

0 errors | 0 warnings | 2 notes

* This is a new submission.

## Resubmission

In response to the reviewer's comments:

* The invalid file URIs reported for `README.md` have been fixed. The links to
  `proposal/trialdiff-proposal.md` and `CODE_OF_CONDUCT.md` were relative, but
  those files are listed in `.Rbuildignore` and are therefore not present in the
  built tarball. Both links now use absolute URLs pointing to the GitHub
  repository, so no relative URI is checked against the package source.

* A methodological reference has been added to the `Description` field:
  van der Loo and de Jonge (2021) <doi:10.18637/jss.v097.i10>. This is the
  closest published reference to the rule-based data-checking approach used by
  `classify_changes()`; the package itself implements a new framework and does
  not reimplement that work.

## Notes

* `checking CRAN incoming feasibility ... NOTE` reports `New submission`.
  This is expected for a first submission.

* `checking HTML version of manual ... NOTE` reports that the local
  `tidy` is not recent enough to validate the HTML manual. This is a local
  tooling limitation; CRAN has a recent HTML Tidy. No action is required.

## Test environments

* Local: macOS (aarch64), R 4.6.1
* Local: macOS (aarch64), R 4.5.1
* GitHub Actions (continuous):
  * macOS (release)
  * Windows (release)
  * Ubuntu (release)
  * Ubuntu (devel)
  * Ubuntu (oldrel-1)
* r-universe: `R CMD check` on release and devel across macOS, Windows and Linux
  (checks OK)

## R CMD check notes

The package uses only base and recommended packages plus a small set of CRAN
dependencies (`cli`, `dplyr`, `htmltools`, `jsonlite`, `rlang`, `tibble`).
Packages listed in `Suggests` (`admiral`, `cards`, `covr`, `diffdf`, `haven`,
`igraph`, `knitr`, `lintr`, `metacore`, `pharmaverseadam`, `pkgdown`,
`rmarkdown`, `rtables`, `styler`, `tern`, `testthat`, `waldo`, `withr`,
`pharmaversesdtm`) are used only in optional tests, examples, documentation or
CI, and are guarded with `requireNamespace()` or `skip_if_not_installed()`.

## Downstream dependencies

There are currently no downstream dependencies for this package.
