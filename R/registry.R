#' Declare an analysis or output and its inputs
#'
#' `td_output()` is the building block of an analysis/output registry. It states
#' that an analysis or output depends on one or more upstream nodes (typically
#' `dataset.variable` identifiers, but any node is allowed).
#'
#' @param id Node identifier for the analysis or output (for example `"MMRM"` or
#'   `"Table_14_2_1"`).
#' @param depends_on Character vector of upstream node identifiers.
#' @param type Either `"analysis"` or `"output"`.
#' @param relationship Edge relationship. Defaults to `"models"` for analyses
#'   and `"reports"` for outputs.
#' @param condition Optional applicability condition (recorded, not evaluated).
#' @param label Human-readable label.
#'
#' @return A tibble of registry edges.
#' @export
td_output <- function(id, depends_on, type = c("analysis", "output"),
                      relationship = NULL, condition = NA_character_,
                      label = id) {
  type <- match.arg(type)
  if (missing(id) || length(id) != 1L || !nzchar(id)) {
    td_abort("{.arg id} must be a single non-empty node identifier.")
  }
  if (missing(depends_on) || length(depends_on) == 0L) {
    td_abort("{.arg depends_on} must name at least one upstream node.")
  }
  relationship <- relationship %||%
    if (identical(type, "analysis")) "models" else "reports"
  tibble::tibble(
    from = as.character(depends_on),
    from_type = td_infer_node_type(depends_on),
    to = as.character(id),
    to_type = type,
    relationship = as.character(relationship),
    condition = as.character(condition),
    label = as.character(label),
    source = "registry"
  )
}

#' Build an analysis/output registry
#'
#' Collects one or more [td_output()] declarations into a single registry table
#' that can be grafted onto a lineage graph with [add_outputs()].
#'
#' @param ... One or more [td_output()] results.
#'
#' @return A tibble of registry edges.
#' @export
#'
#' @examples
#' registry <- output_registry(
#'   td_output("MMRM", depends_on = c("ADLB.AVAL", "ADLB.CHG")),
#'   td_output("Table_14_2_1", depends_on = "MMRM", type = "output")
#' )
#' registry
output_registry <- function(...) {
  dots <- list(...)
  if (length(dots) == 0L) {
    td_abort("Supply at least one {.fun td_output} declaration.")
  }
  pieces <- lapply(dots, function(d) {
    if (!is.data.frame(d)) {
      td_abort("Each {.arg ...} element must be a {.fun td_output} result.")
    }
    td_as_edges(d)
  })
  dplyr::bind_rows(pieces)
}

#' Add edges to a lineage graph
#'
#' Merges edges (from [lineage_edge()], [td_output()], a registry or any edge
#' data frame) into an existing `td_lineage` object and rebuilds the node table.
#' Existing provenance and review information is preserved.
#'
#' @param x A `td_lineage` object.
#' @param ... Edge tables to add.
#' @param source Optional value used to tag the source of every added edge.
#'
#' @return A `td_lineage` object.
#' @export
add_edges <- function(x, ..., source = NULL) {
  if (!inherits(x, "td_lineage")) {
    td_abort("{.arg x} must be a {.cls td_lineage} object.")
  }
  dots <- list(...)
  if (length(dots) == 0L) {
    return(x)
  }
  pieces <- lapply(dots, function(d) {
    if (!is.data.frame(d)) {
      td_abort("Each {.arg ...} element must be an edge table.")
    }
    td_as_edges(d)
  })
  new_edges <- dplyr::bind_rows(pieces)
  if (!is.null(source)) {
    new_edges$source <- source
  }

  edges <- dplyr::distinct(
    dplyr::bind_rows(x$edges, new_edges),
    .data$from, .data$to, .data$relationship, .data$condition,
    .keep_all = TRUE
  )
  nodes <- td_build_nodes(edges, x$nodes)
  nodes <- dplyr::distinct(
    dplyr::bind_rows(nodes, x$nodes),
    .data$node, .keep_all = TRUE
  )
  td_lineage_object(edges, nodes, review = x$review, provenance = edges)
}

#' Add an analysis/output registry to a lineage graph
#'
#' @param x A `td_lineage` object.
#' @param outputs A registry from [output_registry()] (or a single
#'   [td_output()] result).
#' @param ... Additional registries.
#'
#' @return A `td_lineage` object.
#' @export
#'
#' @examples
#' lineage <- define_lineage(
#'   lineage_edge("ADLB.AVAL", "ADLB.CHG", relationship = "derives")
#' )
#' registry <- output_registry(
#'   td_output("MMRM", depends_on = c("ADLB.AVAL", "ADLB.CHG")),
#'   td_output("Table_14_2_1", depends_on = "MMRM", type = "output")
#' )
#' trace_dependencies(add_outputs(lineage, registry), from = "ADLB.AVAL")
add_outputs <- function(x, outputs, ...) {
  add_edges(x, outputs, ...)
}

#' Remove edges from a lineage graph
#'
#' Removes edges matching any supplied filter. Useful for overriding or
#' replacing automatically generated lineage.
#'
#' @param x A `td_lineage` object.
#' @param from,to,relationship,source Optional character vectors of values to
#'   match. `NULL` (default) ignores that field.
#'
#' @return A `td_lineage` object.
#' @export
remove_edges <- function(x, from = NULL, to = NULL, relationship = NULL,
                         source = NULL) {
  if (!inherits(x, "td_lineage")) {
    td_abort("{.arg x} must be a {.cls td_lineage} object.")
  }
  edges <- x$edges
  keep <- rep(TRUE, nrow(edges))
  if (!is.null(from)) keep <- keep & edges$from %in% from
  if (!is.null(to)) keep <- keep & edges$to %in% to
  if (!is.null(relationship)) keep <- keep & edges$relationship %in% relationship
  if (!is.null(source)) {
    if ("source" %in% names(edges)) {
      keep <- keep & edges$source %in% source
    } else {
      keep <- rep(FALSE, nrow(edges))
    }
  }
  edges <- edges[!keep, , drop = FALSE]

  nodes <- td_build_nodes(edges, x$nodes)
  nodes <- dplyr::distinct(
    dplyr::bind_rows(nodes, x$nodes),
    .data$node, .keep_all = TRUE
  )
  td_lineage_object(edges, nodes, review = x$review, provenance = edges)
}

#' @noRd
td_lineage_object <- function(edges, nodes, review = NULL, provenance = NULL) {
  structure(
    list(
      edges = edges,
      nodes = nodes,
      review = review %||% tibble::tibble(
        dataset = character(), variable = character(),
        derivation_id = character(), derivation = character(),
        reason = character()
      ),
      provenance = provenance %||% edges
    ),
    class = "td_lineage"
  )
}
