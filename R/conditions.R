#' Trialdiff conditions
#'
#' Structured conditions used across the package so that callers (and automated
#' QC pipelines) can handle errors and warnings programmatically.
#'
#' @param message A character scalar.
#' @param class Additional condition subclasses.
#' @param ... Additional data stored on the condition.
#' @param call The calling environment.
#'
#' @name trialdiff-conditions
#' @keywords internal
NULL

#' @rdname trialdiff-conditions
#' @keywords internal
td_abort <- function(message, class = NULL, ..., call = rlang::caller_env()) {
  cli::cli_abort(
    message,
    class = c(class, "trialdiff_error"),
    ...,
    call = call,
    .envir = call
  )
}

#' @rdname trialdiff-conditions
#' @keywords internal
td_warn <- function(message, class = NULL, ..., call = rlang::caller_env()) {
  cli::cli_warn(
    message,
    class = c(class, "trialdiff_warning"),
    ...,
    call = call,
    .envir = call
  )
}

#' @rdname trialdiff-conditions
#' @keywords internal
td_inform <- function(message, ...) {
  cli::cli_inform(message, ..., .envir = rlang::caller_env())
}
