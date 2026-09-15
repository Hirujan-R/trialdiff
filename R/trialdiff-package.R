#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang .data
#' @importFrom rlang %||%
#' @importFrom tibble tibble as_tibble
## usethis namespace: end
NULL

# Suppress R CMD check notes for tidy-evaluation column references.
utils::globalVariables(c(
  ".change_id", ".subject", ".category", ".reason", ".key",
  "variable", "old_value", "new_value", "change", "record_type",
  "node", "node_type", "depth", "path", "edge_relationship",
  "level", "requires_rerun", "rationale", "triggering_changes",
  "from", "to", "from_type", "to_type", "relationship", "condition",
  "n", "metric", "value", "dataset", "label", "type", "length",
  "value_changed", "n_old", "n_new", "prop"
))
