#' Classify detected changes
#'
#' `classify_changes()` turns the raw output of [compare_cut()] into a
#' clinically meaningful change register. Every change is assigned a
#' transparent, rule-based category (see [td_default_rules()]) together with a
#' human-readable explanation.
#'
#' @param x A `tdiff` object returned by [compare_cut()], or a change register
#'   returned by [as_register()].
#' @param rules A list of [td_rule()] objects. Defaults to
#'   [td_default_rules()].
#' @param context Optional named list of extra context passed to rules, for
#'   example `list(has_paramcd = TRUE)`. Context is merged with context derived
#'   from `x`.
#' @param ... Unused.
#'
#' @return When `x` is a `tdiff`, the same object with classification columns
#'   added to `$added`, `$removed`, `$modified` and `$schema`, a `$register`
#'   element, and class `c("tdiff_classified", "tdiff")`. When `x` is a
#'   register (data frame), a classified tibble.
#'
#' @examples
#' old <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Placebo", "Drug A"))
#' new <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Drug A", "Drug A"))
#' compare_cut(old, new, by = "USUBJID", dataset = "ADSL") |>
#'   classify_changes()
#' @export
classify_changes <- function(x, rules = td_default_rules(), context = list(),
                             ...) {
  if (inherits(x, "tdiff")) {
    return(td_classify_tdiff(x, rules = rules, context = context, ...))
  }
  if (is.data.frame(x)) {
    ctx <- utils::modifyList(td_context_default(), context)
    return(td_apply_rules(tibble::as_tibble(x), rules, ctx))
  }
  td_abort(c(
    "{.arg x} must be a {.cls tdiff} object or a change register.",
    "x" = "You supplied {.cls {class(x)}}."
  ))
}

#' @noRd
td_context_default <- function() {
  list(
    dataset = NA_character_,
    by = character(),
    subject_var = "USUBJID",
    subjects_old = character(),
    subjects_new = character(),
    variables = character(),
    has_paramcd = FALSE,
    has_visit = FALSE
  )
}

#' @noRd
td_classify_tdiff <- function(x, rules, context, ...) {
  register <- as_register(x)
  register$.source <- c(
    rep("added", nrow(x$added)),
    rep("removed", nrow(x$removed)),
    rep("modified", nrow(x$modified)),
    rep("schema", nrow(x$schema))
  )

  ctx <- td_context_default()
  ctx$dataset <- x$meta$dataset %||% NA_character_
  ctx$by <- x$meta$by %||% character()
  ctx$subject_var <- x$meta$subject_var %||% "USUBJID"
  ctx$subjects_old <- x$meta$subjects_old %||% character()
  ctx$subjects_new <- x$meta$subjects_new %||% character()
  ctx$variables <- x$meta$variables %||% character()
  ctx$has_paramcd <- "PARAMCD" %in% ctx$variables
  ctx$has_visit <- any(c("VISIT", "VISITNUM", "AVISIT") %in% ctx$variables)
  ctx <- utils::modifyList(ctx, context)

  classified <- td_apply_rules(register, rules, ctx)

  x$added <- td_attach_category(
    x$added, classified, "added"
  )
  x$removed <- td_attach_category(
    x$removed, classified, "removed"
  )
  x$modified <- td_attach_category(
    x$modified, classified, "modified"
  )
  x$schema <- td_attach_category(
    x$schema, classified, "schema"
  )
  x$register <- classified
  class(x) <- unique(c("tdiff_classified", class(x)))
  x
}

#' @noRd
td_attach_category <- function(component, classified, source) {
  rows <- classified[classified$.source == source, , drop = FALSE]
  if (nrow(component) != nrow(rows)) {
    td_abort("Internal error: classification rows do not align with component.")
  }
  component$category <- rows$category
  component$category_label <- rows$category_label
  component$reason <- rows$reason
  component
}

#' @noRd
td_apply_rules <- function(register, rules, context) {
  n <- nrow(register)
  category <- rep(NA_character_, n)
  reason <- rep(NA_character_, n)
  matched <- vector("list", n)

  rules <- rules[order(vapply(rules, function(r) r$priority, integer(1)))]

  for (rule in rules) {
    hit <- tryCatch(
      as.logical(rule$test(register, context)),
      error = function(e) rep(FALSE, n)
    )
    if (length(hit) != n) {
      hit <- rep(FALSE, n)
    }
    hit[is.na(hit)] <- FALSE
    if (any(hit)) {
      rsn <- tryCatch(rule$reason(register, context), error = function(e) NULL)
      if (is.null(rsn) || length(rsn) != n) {
        rsn <- rep(rule$label, n)
      }
      first <- hit & is.na(category)
      category[first] <- rule$name
      reason[first] <- rsn[first]
      for (i in which(hit)) {
        matched[[i]] <- c(matched[[i]], rule$name)
      }
    }
  }

  category[is.na(category)] <- "unclassified"
  reason[is.na(reason)] <- "No classification rule matched; manual review required."

  labels <- td_categories()
  register$category <- category
  register$category_label <- labels$label[match(category, labels$category)]
  register$reason <- reason
  register$category_all <- vapply(
    matched,
    function(x) if (length(x) == 0L) "" else paste(x, collapse = "; "),
    character(1)
  )
  register
}
