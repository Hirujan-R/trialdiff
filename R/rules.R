#' Change classification rules
#'
#' Classification in `trialdiff` is transparent and rule-based. A *rule* is a
#' named predicate evaluated against the long change register produced by
#' [as_register()]. Rules are applied in priority order; the first matching rule
#' determines the primary category, while every matched rule is retained in the
#' `category_all` column so that nothing is hidden.
#'
#' @param name Stable machine-readable category name (snake_case).
#' @param label Human-readable category label.
#' @param priority Integer priority; lower values are evaluated first.
#' @param test A function `function(register, context)` returning a logical
#'   vector the same length as `nrow(register)`.
#' @param reason Optional function `function(register, context)` returning a
#'   character vector of explanations.
#' @param description Optional longer description.
#'
#' @return `td_rule()` returns an object of class `td_rule`.
#' @export
td_rule <- function(name, label, test, priority = 100L, reason = NULL,
                    description = NULL) {
  stopifnot(
    is.character(name), length(name) == 1L,
    is.character(label), length(label) == 1L,
    is.function(test)
  )
  structure(
    list(
      name = name,
      label = label,
      priority = as.integer(priority),
      test = test,
      reason = reason,
      description = description
    ),
    class = "td_rule"
  )
}

#' @export
print.td_rule <- function(x, ...) {
  cli::cli_text(
    "{.strong {x$label}} ({.val {x$name}}), priority {x$priority}"
  )
  invisible(x)
}

#' Category label lookup
#'
#' @return A tibble with `category` and `label` columns.
#' @export
td_categories <- function() {
  tibble::tibble(
    category = c(
      "new_subject", "subject_removed", "new_visit", "new_assessment",
      "new_record", "record_removed", "treatment_assignment_change",
      "derived_variable_change", "corrected_value", "missing_to_value",
      "value_to_missing", "variable_added", "variable_removed",
      "type_change", "label_change", "unclassified"
    ),
    label = c(
      "New subject", "Subject removed", "New visit", "New assessment",
      "New record", "Record removed", "Treatment-assignment change",
      "Derived-variable change", "Corrected value",
      "Missing to non-missing", "Non-missing to missing",
      "Variable added", "Variable removed", "Type change", "Label change",
      "Unclassified - requires review"
    )
  )
}

#' Default rule set
#'
#' @return A list of [td_rule()] objects ordered by priority.
#' @export
td_default_rules <- function() {
  rules <- list(
    td_rule(
      "variable_added", "Variable added",
      priority = 5L,
      test = function(register, context) {
        register$record_type == "schema" & register$change == "variable_added"
      },
      reason = function(register, context) {
        sprintf("Variable '%s' is new in the later cut.", register$variable)
      }
    ),
    td_rule(
      "variable_removed", "Variable removed",
      priority = 6L,
      test = function(register, context) {
        register$record_type == "schema" & register$change == "variable_removed"
      },
      reason = function(register, context) {
        sprintf("Variable '%s' is absent from the later cut.", register$variable)
      }
    ),
    td_rule(
      "type_change", "Type change",
      priority = 7L,
      test = function(register, context) {
        register$record_type == "schema" & register$change == "type_change"
      },
      reason = function(register, context) {
        sprintf(
          "Variable '%s' changed type from %s to %s.",
          register$variable, register$old_value, register$new_value
        )
      }
    ),
    td_rule(
      "label_change", "Label change",
      priority = 8L,
      test = function(register, context) {
        register$record_type == "schema" & register$change == "label_change"
      },
      reason = function(register, context) {
        sprintf(
          "Variable '%s' label changed from '%s' to '%s'.",
          register$variable, register$old_value, register$new_value
        )
      }
    ),
    td_rule(
      "new_subject", "New subject",
      priority = 10L,
      test = function(register, context) {
        register$record_type == "added" &
          !is.na(register$.subject) &
          !(register$.subject %in% context$subjects_old)
      },
      reason = function(register, context) {
        sprintf(
          "Subject '%s' appears in the later cut but not in the earlier cut.",
          register$.subject
        )
      }
    ),
    td_rule(
      "subject_removed", "Subject removed",
      priority = 11L,
      test = function(register, context) {
        register$record_type == "removed" &
          !is.na(register$.subject) &
          !(register$.subject %in% context$subjects_new)
      },
      reason = function(register, context) {
        sprintf(
          "Subject '%s' was present in the earlier cut but is absent from the later cut.",
          register$.subject
        )
      }
    ),
    td_rule(
      "new_assessment", "New assessment",
      priority = 20L,
      test = function(register, context) {
        register$record_type == "added" & td_context_has_param(context)
      },
      reason = function(register, context) {
        sprintf(
          "A new assessment record was added for subject '%s'.",
          register$.subject
        )
      }
    ),
    td_rule(
      "new_visit", "New visit",
      priority = 21L,
      test = function(register, context) {
        register$record_type == "added" & td_context_has_visit(context)
      },
      reason = function(register, context) {
        sprintf("A new visit record was added for subject '%s'.", register$.subject)
      }
    ),
    td_rule(
      "new_record", "New record",
      priority = 29L,
      test = function(register, context) {
        register$record_type == "added"
      },
      reason = function(register, context) {
        sprintf("A new record was added for subject '%s'.", register$.subject)
      }
    ),
    td_rule(
      "record_removed", "Record removed",
      priority = 30L,
      test = function(register, context) {
        register$record_type == "removed"
      },
      reason = function(register, context) {
        sprintf("A record was removed for subject '%s'.", register$.subject)
      }
    ),
    td_rule(
      "treatment_assignment_change", "Treatment-assignment change",
      priority = 40L,
      test = function(register, context) {
        register$record_type == "modified" &
          td_is_treatment_var(register$variable)
      },
      reason = function(register, context) {
        sprintf(
          "Treatment variable '%s' changed from '%s' to '%s' for subject '%s'.",
          register$variable, register$old_value, register$new_value,
          register$.subject
        )
      }
    ),
    td_rule(
      "derived_variable_change", "Derived-variable change",
      priority = 50L,
      test = function(register, context) {
        register$record_type == "modified" &
          td_is_derived_var(register$variable)
      },
      reason = function(register, context) {
        sprintf(
          "Derived variable '%s' changed from '%s' to '%s' for subject '%s'.",
          register$variable, register$old_value, register$new_value,
          register$.subject
        )
      }
    ),
    td_rule(
      "missing_to_value", "Missing to non-missing",
      priority = 45L,
      test = function(register, context) {
        register$record_type == "modified" & register$change == "missing_to_value"
      },
      reason = function(register, context) {
        sprintf(
          "Variable '%s' changed from missing to '%s' for subject '%s'.",
          register$variable, register$new_value, register$.subject
        )
      }
    ),
    td_rule(
      "value_to_missing", "Non-missing to missing",
      priority = 46L,
      test = function(register, context) {
        register$record_type == "modified" & register$change == "value_to_missing"
      },
      reason = function(register, context) {
        sprintf(
          "Variable '%s' changed from '%s' to missing for subject '%s'.",
          register$variable, register$old_value, register$.subject
        )
      }
    ),
    td_rule(
      "corrected_value", "Corrected value",
      priority = 70L,
      test = function(register, context) {
        register$record_type == "modified" & register$change == "value"
      },
      reason = function(register, context) {
        sprintf(
          "Variable '%s' changed from '%s' to '%s' for subject '%s'.",
          register$variable, register$old_value, register$new_value,
          register$.subject
        )
      }
    )
  )
  rules[order(vapply(rules, function(r) r$priority, integer(1)))]
}

#' Common treatment/randomisation variables
#' @noRd
td_treatment_vars <- function() {
  c(
    "ARM", "ARMCD", "ACTARM", "ACTARMCD", "TRT01P", "TRT01A",
    "TRT02P", "TRT02A", "TRTP", "TRTA", "TRTSEQP", "TRTSEQA",
    "RANDTRT", "RANDOM", "PLANTRT", "TRT01PN", "TRT01AN"
  )
}

#' @noRd
td_is_treatment_var <- function(variable) {
  toupper(variable) %in% td_treatment_vars()
}

#' Common derived analysis variables
#' @noRd
td_derived_vars <- function() {
  c(
    "AVAL", "AVALC", "BASE", "BASEC", "CHG", "PCHG", "ABLFL",
    "ONTRTFL", "ANL01FL", "ANL02FL", "DTYPE", "AVALCAT1", "AVALCA1N",
    "CRIT1FL", "CRIT1", "PARAMN", "ANLzzFL", "SHIFT1", "SHIFT2"
  )
}

#' @noRd
td_is_derived_var <- function(variable) {
  v <- toupper(variable)
  v %in% toupper(td_derived_vars()) |
    grepl("^(CHG|PCHG|BASE|AVAL|ABLFL|ONTRTFL|ANL[0-9]*FL|SHIFT[0-9]*)$", v)
}

#' @noRd
td_context_has_param <- function(context) {
  isTRUE(context$has_paramcd) || grepl("^(ADLB|ADVS|ADEG|ADTTE|ADQS|ADPC)", context$dataset %||% "")
}

#' @noRd
td_context_has_visit <- function(context) {
  isTRUE(context$has_visit) || grepl("^(ADVS|ADLB|ADEG|ADQS|ADPC|SV|VS|LB)", context$dataset %||% "")
}
