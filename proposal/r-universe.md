# r-universe listing

Status: **registry created; GitHub App installation pending**.

## What was done

* Created the registry repository
  [`Hirujan-R/hirujan-r.r-universe.dev`](https://github.com/Hirujan-R/hirujan-r.r-universe.dev)
  with a `packages.json` that tracks the latest GitHub release of `trialdiff`:

  ```json
  [
    {
      "package": "trialdiff",
      "url": "https://github.com/Hirujan-R/trialdiff",
      "branch": "*release"
    }
  ]
  ```

* Added `Config/Needs/website: pkgdown` to `DESCRIPTION` so r-universe builds the
  pkgdown site.
* Added r-universe version and check badges and r-universe install instructions
  to `README.md`.

## What you need to do (browser)

1. Install the r-universe GitHub App for your account:
   https://github.com/apps/r-universe/installations/new
   (choose **All repositories**, or at least `trialdiff` and the registry repo).
2. Wait for the first build (usually under an hour). The package will appear at:
   * Dashboard: https://hirujan-r.r-universe.dev
   * Package: https://hirujan-r.r-universe.dev/trialdiff
3. Confirm the badges in `README.md` resolve.

## Installing from r-universe (once built)

```r
options(repos = c(
  hirujan = "https://hirujan-r.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))
install.packages("trialdiff")
```

## Notes

* `branch: "*release"` tracks the most recent GitHub release (currently
  `v0.2.0`). Remove the `branch` field to track `main` instead.
* r-universe builds Windows, macOS (Intel and ARM) and Linux binaries, and runs
  `R CMD check` on release and devel across platforms - an additional CI signal
  beyond GitHub Actions.
* The registry repo is public and safe to delete if you change your mind; the
  listing disappears on the next build.
