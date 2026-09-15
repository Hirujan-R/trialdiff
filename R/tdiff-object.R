#' The `tdiff` object
#'
#' `compare_cut()` returns an object of class `tdiff`. It is a list with the
#' following elements:
#'
#' * `meta`: comparison metadata (dataset, cut names, keys, row counts, time).
#' * `added`: observations present in the new cut but not the old cut, with
#'   `.key` and `.subject` helper columns.
#' * `removed`: observations present in the old cut but not the new cut.
#' * `modified`: one row per changed cell, with `variable`, `old_value`,
#'   `new_value` and `change` (`"value"`, `"missing_to_value"` or
#'   `"value_to_missing"`).
#' * `schema`: variable-level changes (`variable_added`, `variable_removed`,
#'   `type_change`, `label_change`).
#' * `summary`: a tidy metric/value table.
#'
#' @name tdiff-object
#' @keywords internal
NULL

#' @noRd
new_tdiff <- function(meta, added, removed, modified, schema, summary) {
  structure(
    list(
      meta = meta,
      added = added,
      removed = removed,
      modified = modified,
      schema = schema,
      summary = summary
    ),
    class = "tdiff"
  )
}

#' @export
print.tdiff <- function(x, ...) {
  meta <- x$meta
  cli::cli_h1("trialdiff comparison")
  cli::cli_text(
    "{.strong {meta$dataset %||% 'dataset'}}: {meta$name_old} \u2192 {meta$name_new}"
  )
  cli::cli_text("Keys: {.val {meta$by}}")
  cli::cli_text(
    "Observations: {meta$n_old} \u2192 {meta$n_new} \\
    ({meta$n_common} matched)"
  )
  cli::cli_text(
    "Added: {.val {nrow(x$added)}}  Removed: {.val {nrow(x$removed)}}  \\
    Modified cells: {.val {nrow(x$modified)}}"
  )
  cli::cli_text("Schema changes: {.val {nrow(x$schema)}}")
  if ("category" %in% names(x$modified)) {
    cli::cli_text("Classified: {.val {length(unique(x$modified$category))}} \\
                   category{?ies} present")
  }
  invisible(x)
}

#' @export
summary.tdiff <- function(object, ...) {
  print(object)
  cli::cli_h2("Summary metrics")
  print(object$summary)
  invisible(object$summary)
}

#' @export
as.data.frame.tdiff <- function(x, ...) {
  as.data.frame(as_register(x))
}

#' Tidy register of every detected change
#'
#' Flattens a `tdiff` object into a single long table with one row per change
#' (added record, removed record, modified cell or schema change). This is the
#' machine-readable form intended for QC pipelines.
#'
#' @param x A `tdiff` object.
#' @param ... Unused.
#' @return A tibble.
#' @export
as_register <- function(x, ...) {
  UseMethod("as_register")
}

#' @export
as_register.tdiff <- function(x, ...) {
  meta <- x$meta
  by <- meta$by
  pieces <- list()

  key_tbl <- function(df, n) {
    if (length(by) == 0L) {
      return(tibble::tibble())
    }
    missing <- setdiff(by, names(df))
    for (m in missing) df[[m]] <- NA_character_
    out <- df[, by, drop = FALSE]
    out[] <- lapply(out, as.character)
    out
  }

  if (nrow(x$added) > 0L) {
    d <- key_tbl(x$added, nrow(x$added))
    d$record_type <- "added"
    d$variable <- NA_character_
    d$old_value <- NA_character_
    d$new_value <- NA_character_
    d$change <- "record_added"
    d$.subject <- x$added$.subject
    pieces[[length(pieces) + 1L]] <- d
  }
  if (nrow(x$removed) > 0L) {
    d <- key_tbl(x$removed, nrow(x$removed))
    d$record_type <- "removed"
    d$variable <- NA_character_
    d$old_value <- NA_character_
    d$new_value <- NA_character_
    d$change <- "record_removed"
    d$.subject <- x$removed$.subject
    pieces[[length(pieces) + 1L]] <- d
  }
  if (nrow(x$modified) > 0L) {
    d <- key_tbl(x$modified, nrow(x$modified))
    d$record_type <- "modified"
    d$variable <- x$modified$variable
    d$old_value <- x$modified$old_value
    d$new_value <- x$modified$new_value
    d$change <- x$modified$change
    d$.subject <- x$modified$.subject
    pieces[[length(pieces) + 1L]] <- d
  }
  if (nrow(x$schema) > 0L) {
    s <- x$schema
    d <- tibble::tibble(
      record_type = "schema",
      variable = s$variable,
      old_value = s$old_value,
      new_value = s$new_value,
      change = s$change
    )
    for (b in by) d[[b]] <- NA_character_
    d$.subject <- NA_character_
    pieces[[length(pieces) + 1L]] <- d
  }

  if (length(pieces) == 0L) {
    reg <- tibble::tibble(
      record_type = character(), variable = character(),
      old_value = character(), new_value = character(), change = character(),
      .subject = character()
    )
    for (b in by) reg[[b]] <- character()
  } else {
    reg <- dplyr::bind_rows(pieces)
  }

  reg <- dplyr::relocate(
    reg,
    dplyr::any_of(c("record_type", "dataset", by, "variable", "old_value",
                    "new_value", "change", ".subject"))
  )
  reg$dataset <- meta$dataset
  reg$.change_id <- sprintf("CHG%05d", seq_len(nrow(reg)))
  dplyr::relocate(reg, .change_id)
}
