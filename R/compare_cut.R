#' Compare two data cuts of a clinical dataset
#'
#' `compare_cut()` performs a deterministic, key-based comparison of two
#' versions of the same clinical dataset (for example `ADSL` at two data cuts).
#' It reports observations added, removed and modified, and separately reports
#' schema-level changes (variables added/removed, type and label changes).
#'
#' The function is deliberately a *low-level* comparison engine. Clinical
#' meaning is added by [classify_changes()], lineage by [define_lineage()] and
#' impact by [assess_impact()].
#'
#' @param old,new Data frames (or tibbles) representing the earlier and later
#'   data cut. `new` is compared against `old`.
#' @param by Character vector of key variables that uniquely identify an
#'   observation within each dataset. Common clinical keys include
#'   `c("USUBJID", "PARAMCD", "AVISIT")` for `ADLB` or `c("USUBJID", "VISIT")`
#'   for `ADVS`. Must be present in both datasets.
#' @param compare_labels Logical. If `TRUE` (default) variable label changes are
#'   recorded in the schema comparison.
#' @param compare_types Logical. If `TRUE` (default) variable type changes are
#'   recorded in the schema comparison.
#' @param tolerance Numeric tolerance used when comparing numeric values. Set to
#'   `0` for exact comparison.
#' @param ignore_vars Character vector of variables to exclude from the value
#'   comparison (for example technical or audit columns).
#' @param name_old,name_new Character labels used in reports.
#' @param dataset Optional dataset name (for example `"ADSL"`). Inferred from
#'   the `old`/`new` expressions when not supplied.
#' @param subject_var Optional subject identifier variable. When `NULL` the
#'   function looks for `USUBJID`, then falls back to the first key.
#' @param backend Low-level comparison backend. `"trialdiff"` uses the built-in
#'   engine; `"waldo"` additionally uses \pkg{waldo} for whole-column equality
#'   short-circuiting when it is installed; `"diffdf"` delegates value
#'   comparison to \pkg{diffdf} and translates its output into a `tdiff`
#'   object (schema comparison remains built in). The `"diffdf"` backend
#'   requires the \pkg{diffdf} package.
#' @param ... Reserved for future extensions.
#'
#' @return An object of class `tdiff`: a list with elements `meta`, `added`,
#'   `removed`, `modified`, `schema`, `summary` and `register`. See
#'   [tdiff-object] for details.
#'
#' @examples
#' old <- data.frame(
#'   USUBJID = c("S1", "S2", "S3"),
#'   TRT01P = c("Placebo", "Drug A", "Placebo"),
#'   AGE = c(54, 61, 47),
#'   stringsAsFactors = FALSE
#' )
#' new <- old
#' new$TRT01P[1] <- "Drug A"
#' new$AGE[2] <- 62
#' diff <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL")
#' diff
#' @export
compare_cut <- function(old,
                        new,
                        by,
                        compare_labels = TRUE,
                        compare_types = TRUE,
                        tolerance = 1e-9,
                        ignore_vars = NULL,
                        name_old = "old",
                        name_new = "new",
                        dataset = NULL,
                        subject_var = NULL,
                        backend = c("trialdiff", "waldo", "diffdf"),
                        ...) {
  backend <- match.arg(backend)
  call <- match.call()
  dataset <- dataset %||% td_infer_dataset(call)

  old <- td_as_tibble(old, arg = "old")
  new <- td_as_tibble(new, arg = "new")

  if (missing(by) || length(by) == 0L) {
    td_abort(c(
      "{.arg by} must be supplied.",
      "i" = "Provide the key variable(s) that identify an observation, e.g. \\
             {.code by = c('USUBJID', 'PARAMCD', 'AVISIT')}."
    ))
  }
  if (!is.character(by)) {
    td_abort("{.arg by} must be a character vector of column names.")
  }

  td_check_keys(old, new, by)
  td_check_duplicate_keys(old, by, "old")
  td_check_duplicate_keys(new, by, "new")

  subject_var <- subject_var %||% td_pick_subject_var(old, new, by)

  schema <- td_compare_schema(
    old, new,
    compare_labels = compare_labels,
    compare_types = compare_types
  )

  common_vars <- intersect(names(old), names(new))
  compare_vars <- setdiff(common_vars, c(by, ignore_vars))

  key_old <- td_make_key(old, by)
  key_new <- td_make_key(new, by)

  dd <- NULL
  if (identical(backend, "diffdf")) {
    dd <- td_compare_diffdf(old, new, by, compare_vars, tolerance)
  }

  if (!is.null(dd)) {
    added <- dd$added
    removed <- dd$removed
    modified <- dd$modified
  } else {
    removed_keys <- setdiff(key_old, key_new)
    added_keys <- setdiff(key_new, key_old)

    removed <- old[match(removed_keys, key_old), , drop = FALSE]
    added <- new[match(added_keys, key_new), , drop = FALSE]

    modified <- td_compare_rows(
      old, new,
      by = by,
      compare_vars = compare_vars,
      key_old = key_old,
      key_new = key_new,
      tolerance = tolerance,
      backend = backend
    )
  }

  added <- td_annotate_records(added, by, subject_var)
  removed <- td_annotate_records(removed, by, subject_var)
  if (nrow(modified) > 0L && !".subject" %in% names(modified)) {
    modified$.subject <- td_subject_of(modified, subject_var = subject_var, by = by)
  } else if (nrow(modified) == 0L && !".subject" %in% names(modified)) {
    modified$.subject <- character()
  }
  if (nrow(modified) > 0L && !".key" %in% names(modified)) {
    modified$.key <- td_make_key(modified, by)
  }

  summary <- td_summary_table(
    old, new, by, added, removed, modified, schema,
    n_common = length(intersect(key_old, key_new))
  )

  new_tdiff(
    meta = list(
      dataset = dataset,
      name_old = name_old,
      name_new = name_new,
      by = by,
      subject_var = subject_var,
      n_old = nrow(old),
      n_new = nrow(new),
      n_common = length(intersect(key_old, key_new)),
      variables = union(names(old), names(new)),
      subjects_old = unique(as.character(old[[subject_var]])),
      subjects_new = unique(as.character(new[[subject_var]])),
      tolerance = tolerance,
      generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
    ),
    added = added,
    removed = removed,
    modified = modified,
    schema = schema,
    summary = summary
  )
}

#' @noRd
td_infer_dataset <- function(call) {
  for (arg in c("old", "new")) {
    expr <- call[[arg]]
    if (!is.null(expr)) {
      nm <- paste(deparse(expr), collapse = "")
      nm <- gsub("_cut[0-9]+$|_v[0-9]+$", "", nm)
      if (nzchar(nm) && !grepl("[()$\\[\\]]", nm)) {
        return(toupper(nm))
      }
    }
  }
  NA_character_
}

#' @noRd
td_check_keys <- function(old, new, by) {
  missing_old <- setdiff(by, names(old))
  missing_new <- setdiff(by, names(new))
  if (length(missing_old) > 0L) {
    td_abort(c(
      "Key variable{?s} missing from {.arg old}: {.val {missing_old}}.",
      "i" = "Available columns: {.val {names(old)}}."
    ), class = "trialdiff_error_key")
  }
  if (length(missing_new) > 0L) {
    td_abort(c(
      "Key variable{?s} missing from {.arg new}: {.val {missing_new}}.",
      "i" = "Available columns: {.val {names(new)}}."
    ), class = "trialdiff_error_key")
  }
  invisible(TRUE)
}

#' @noRd
td_check_duplicate_keys <- function(data, by, arg) {
  key <- td_make_key(data, by)
  dup <- unique(key[duplicated(key)])
  if (length(dup) > 0L) {
    td_abort(c(
      "Duplicate keys found in {.arg {arg}}.",
      "x" = "{length(dup)} duplicated key{?s}, e.g. {.val {utils::head(dup, 3)}}.",
      "i" = "Keys must uniquely identify an observation. \\
             Add variables to {.arg by} or de-duplicate the data."
    ), class = "trialdiff_error_duplicate_keys")
  }
  invisible(TRUE)
}

#' @noRd
td_pick_subject_var <- function(old, new, by) {
  if ("USUBJID" %in% intersect(names(old), names(new))) {
    return("USUBJID")
  }
  if ("SUBJID" %in% intersect(names(old), names(new))) {
    return("SUBJID")
  }
  by[[1L]]
}

#' @noRd
td_compare_schema <- function(old, new, compare_labels, compare_types) {
  vars_old <- names(old)
  vars_new <- names(new)

  out <- list()

  added_vars <- setdiff(vars_new, vars_old)
  if (length(added_vars) > 0L) {
    out[[length(out) + 1L]] <- tibble::tibble(
      variable = added_vars,
      change = "variable_added",
      old_value = NA_character_,
      new_value = vapply(added_vars, function(v) td_type(new[[v]]), character(1))
    )
  }

  removed_vars <- setdiff(vars_old, vars_new)
  if (length(removed_vars) > 0L) {
    out[[length(out) + 1L]] <- tibble::tibble(
      variable = removed_vars,
      change = "variable_removed",
      old_value = vapply(removed_vars, function(v) td_type(old[[v]]), character(1)),
      new_value = NA_character_
    )
  }

  common <- intersect(vars_old, vars_new)
  for (v in common) {
    if (compare_types) {
      to <- td_type(old[[v]])
      tn <- td_type(new[[v]])
      if (!identical(to, tn)) {
        out[[length(out) + 1L]] <- tibble::tibble(
          variable = v,
          change = "type_change",
          old_value = to,
          new_value = tn
        )
      }
    }
    if (compare_labels) {
      lo <- td_var_label(old[[v]])
      ln <- td_var_label(new[[v]])
      if (!identical(lo, ln) && !(is.na(lo) && is.na(ln))) {
        out[[length(out) + 1L]] <- tibble::tibble(
          variable = v,
          change = "label_change",
          old_value = lo,
          new_value = ln
        )
      }
    }
  }

  if (length(out) == 0L) {
    return(tibble::tibble(
      variable = character(),
      change = character(),
      old_value = character(),
      new_value = character()
    ))
  }
  dplyr::bind_rows(out)
}

#' @noRd
td_compare_rows <- function(old, new, by, compare_vars, key_old, key_new,
                            tolerance, backend) {
  common_keys <- intersect(key_old, key_new)
  empty <- tibble::tibble(
    !!!stats::setNames(rep(list(character()), length(by)), by),
    variable = character(),
    old_value = character(),
    new_value = character(),
    change = character(),
    .key = character(),
    .subject = character()
  )
  if (length(common_keys) == 0L || length(compare_vars) == 0L) {
    return(empty)
  }

  idx_old <- match(common_keys, key_old)
  idx_new <- match(common_keys, key_new)

  keys_tbl <- tibble::as_tibble(old[idx_old, by, drop = FALSE])

  pieces <- vector("list", 0L)
  for (v in compare_vars) {
    old_v <- old[[v]][idx_old]
    new_v <- new[[v]][idx_new]
    if (td_column_equal(old_v, new_v, tolerance = tolerance, backend = backend)) {
      next
    }
    changed <- !td_values_equal(old_v, new_v, tolerance = tolerance)
    if (!any(changed)) {
      next
    }
    old_na <- td_is_na(old_v)
    new_na <- td_is_na(new_v)
    kind <- rep("value", length(old_v))
    kind[old_na & !new_na] <- "missing_to_value"
    kind[!old_na & new_na] <- "value_to_missing"

    sel <- which(changed)
    pieces[[length(pieces) + 1L]] <- dplyr::bind_cols(
      keys_tbl[sel, , drop = FALSE],
      tibble::tibble(
        variable = v,
        old_value = vapply(old_v[sel], td_format_value, character(1)),
        new_value = vapply(new_v[sel], td_format_value, character(1)),
        change = kind[sel],
        .key = common_keys[sel]
      )
    )
  }

  if (length(pieces) == 0L) {
    return(empty)
  }
  dplyr::bind_rows(pieces)
}

#' @noRd
td_column_equal <- function(old, new, tolerance, backend) {
  if (identical(backend, "waldo") && td_has_package("waldo")) {
    diffs <- tryCatch(
      waldo::compare(old, new, tolerance = tolerance, max_diffs = 1L),
      error = function(e) NULL
    )
    if (!is.null(diffs)) {
      return(length(diffs) == 0L)
    }
  }
  all(td_values_equal(old, new, tolerance = tolerance))
}

#' @noRd
td_annotate_records <- function(data, by, subject_var) {
  if (nrow(data) == 0L) {
    data$.key <- character()
    data$.subject <- character()
    return(data)
  }
  data$.key <- td_make_key(data, by)
  data$.subject <- td_subject_of(data, subject_var = subject_var, by = by)
  data
}

#' @noRd
td_summary_table <- function(old, new, by, added, removed, modified, schema,
                             n_common) {
  n_subjects <- function(x) {
    if (is.null(x$.subject)) {
      return(0L)
    }
    length(unique(x$.subject[!is.na(x$.subject)]))
  }
  tibble::tibble(
    metric = c(
      "observations_old", "observations_new", "observations_common",
      "observations_added", "observations_removed",
      "cells_modified", "variables_modified",
      "subjects_added", "subjects_removed", "subjects_affected",
      "schema_changes"
    ),
    value = c(
      nrow(old), nrow(new), n_common,
      nrow(added), nrow(removed),
      nrow(modified), length(unique(modified$variable)),
      n_subjects(added), n_subjects(removed),
      length(unique(c(
        added$.subject[!is.na(added$.subject)],
        removed$.subject[!is.na(removed$.subject)],
        modified$.subject[!is.na(modified$.subject)]
      ))),
      nrow(schema)
    )
  )
}

#' Compare rows using the diffdf backend
#'
#' Delegates value comparison to \pkg{diffdf} and translates its result into
#' the same added/removed/modified tables produced by the built-in engine.
#' Returns `NULL` (with a warning) when diffdf is unavailable or errors, so
#' the caller can fall back to the built-in engine.
#' @noRd
td_compare_diffdf <- function(old, new, by, compare_vars, tolerance) {
  if (!td_has_package("diffdf")) {
    td_abort(c(
      "Package {.pkg diffdf} is required for {.code backend = \"diffdf\"}.",
      "i" = "Install it with {.run install.packages(\"diffdf\")}."
    ), class = "trialdiff_error_backend")
  }

  res <- tryCatch(
    suppressWarnings(diffdf::diffdf(
      base = as.data.frame(old, stringsAsFactors = FALSE),
      compare = as.data.frame(new, stringsAsFactors = FALSE),
      keys = by,
      tolerance = tolerance,
      suppress_warnings = TRUE
    )),
    error = function(e) e
  )

  if (inherits(res, "error")) {
    td_warn(c(
      "The {.pkg diffdf} backend failed; using the built-in engine instead.",
      "i" = "Reason: {conditionMessage(res)}"
    ), class = "trialdiff_warning_backend_fallback")
    return(NULL)
  }

  added <- td_rows_from_keys(res[["ExtRowsComp"]], new, by)
  removed <- td_rows_from_keys(res[["ExtRowsBase"]], old, by)

  modified <- td_diffdf_modified(res, by, compare_vars)

  list(added = added, removed = removed, modified = modified)
}

#' @noRd
td_rows_from_keys <- function(key_df, data, by) {
  if (is.null(key_df) || nrow(key_df) == 0L) {
    return(data[0L, , drop = FALSE])
  }
  missing <- setdiff(by, names(key_df))
  if (length(missing) > 0L) {
    return(data[0L, , drop = FALSE])
  }
  keys <- td_make_key(key_df, by)
  idx <- match(keys, td_make_key(data, by))
  idx <- idx[!is.na(idx)]
  data[idx, , drop = FALSE]
}

#' @noRd
td_diffdf_modified <- function(res, by, compare_vars) {
  var_names <- grep("^VarDiff_", names(res), value = TRUE)
  empty <- tibble::tibble(
    !!!stats::setNames(rep(list(character()), length(by)), by),
    variable = character(),
    old_value = character(),
    new_value = character(),
    change = character()
  )
  if (length(var_names) == 0L) {
    return(empty)
  }

  pieces <- list()
  for (nm in var_names) {
    variable <- sub("^VarDiff_", "", nm)
    if (!variable %in% compare_vars) {
      next
    }
    v <- res[[nm]]
    if (is.null(v) || nrow(v) == 0L) {
      next
    }
    base_vals <- v[["BASE"]]
    comp_vals <- v[["COMPARE"]]
    old_na <- td_is_na(base_vals)
    new_na <- td_is_na(comp_vals)
    kind <- rep("value", nrow(v))
    kind[old_na & !new_na] <- "missing_to_value"
    kind[!old_na & new_na] <- "value_to_missing"

    keys <- v[, by, drop = FALSE]
    pieces[[length(pieces) + 1L]] <- dplyr::bind_cols(
      keys,
      tibble::tibble(
        variable = variable,
        old_value = vapply(
          seq_along(base_vals),
          function(i) td_format_value(base_vals[i]),
          character(1)
        ),
        new_value = vapply(
          seq_along(comp_vals),
          function(i) td_format_value(comp_vals[i]),
          character(1)
        ),
        change = kind
      )
    )
  }

  if (length(pieces) == 0L) {
    return(empty)
  }
  dplyr::bind_rows(pieces)
}
