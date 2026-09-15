#' Internal helpers
#'
#' Small, dependency-light utilities used across `trialdiff`.
#'
#' @param x An object.
#' @param nm A character scalar.
#' @name trialdiff-utils
#' @keywords internal
NULL

#' Coerce to a plain tibble without dropping column attributes
#' @noRd
td_as_tibble <- function(x, arg = "x") {
  if (!is.data.frame(x)) {
    td_abort(c(
      "{.arg {arg}} must be a data frame.",
      "x" = "You supplied {.cls {class(x)}}."
    ))
  }
  if (inherits(x, "tbl_df")) {
    return(x)
  }
  tibble::as_tibble(x, .name_repair = "minimal")
}

#' Variable label, if present
#' @noRd
td_var_label <- function(x) {
  lab <- attr(x, "label", exact = TRUE)
  if (is.null(lab)) {
    return(NA_character_)
  }
  as.character(lab)[[1L]]
}

#' A short human-readable description of a vector type
#' @noRd
td_type <- function(x) {
  cls <- class(x)
  if (length(cls) == 0L) {
    return(typeof(x))
  }
  cls[[1L]]
}

#' Format a single value for display in change registers
#' @noRd
td_format_value <- function(x) {
  if (length(x) == 0L) {
    return(NA_character_)
  }
  if (all(is.na(x))) {
    return("<NA>")
  }
  out <- format(x, trim = TRUE, justify = "none")
  out[is.na(x)] <- "<NA>"
  paste(out, collapse = ", ")
}

#' Vectorised "is missing" that respects NaN
#' @noRd
td_is_na <- function(x) {
  is.na(x) | (is.nan(x) & !is.character(x))
}

#' Compare two vectors element-wise, honouring tolerance for numerics
#'
#' Returns a logical vector: `TRUE` where the values are considered equal.
#' @noRd
td_values_equal <- function(old, new, tolerance = 1e-9) {
  if (length(old) != length(new)) {
    return(rep(FALSE, max(length(old), length(new))))
  }
  old_na <- td_is_na(old)
  new_na <- td_is_na(new)

  equal <- rep(TRUE, length(old))
  equal[old_na & new_na] <- TRUE
  equal[old_na != new_na] <- FALSE

  both <- !old_na & !new_na
  if (any(both)) {
    if (is.numeric(old) && is.numeric(new) && tolerance > 0) {
      equal[both] <- abs(old[both] - new[both]) <= tolerance
    } else {
      equal[both] <- as.character(old[both]) == as.character(new[both])
    }
  }
  equal
}

#' Collapse key columns of a data frame into a character key
#' @noRd
td_make_key <- function(data, by) {
  cols <- lapply(by, function(nm) {
    v <- data[[nm]]
    out <- as.character(v)
    out[td_is_na(v)] <- "<NA>"
    out
  })
  names(cols) <- by
  do.call(paste, c(cols, list(sep = "\u001f")))
}

#' Extract unique subjects from a change/record table
#' @noRd
td_subject_of <- function(data, subject_var = NULL, by = character()) {
  if (!is.null(subject_var) && subject_var %in% names(data)) {
    return(as.character(data[[subject_var]]))
  }
  if ("USUBJID" %in% names(data)) {
    return(as.character(data[["USUBJID"]]))
  }
  if (length(by) > 0L) {
    first <- by[[1L]]
    if (first %in% names(data)) {
      return(as.character(data[[first]]))
    }
  }
  rep(NA_character_, nrow(data))
}

#' Safely check whether a package is available
#' @noRd
td_has_package <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}
