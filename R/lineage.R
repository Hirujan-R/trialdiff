#' Define a lineage edge
#'
#' A lineage edge states that `to` depends on `from`. Node identifiers use a
#' simple convention:
#'
#' * a dataset is written as `"ADSL"`;
#' * a dataset variable is written as `"ADSL.TRT01P"`;
#' * an analysis is written as `"MMRM"`;
#' * an output (TLF) is written as `"Table_14_2_1"`.
#'
#' @param from,to Character node identifiers. `to` depends on `from`.
#' @param from_type,to_type Optional node types (`"dataset"`, `"variable"`,
#'   `"analysis"`, `"output"`). Inferred when `NULL`.
#' @param relationship Edge semantics. One of `"derives"`, `"groups_by"`,
#'   `"filters"`, `"summarises"`, `"models"`, `"reports"`, `"transports"` or a
#'   custom string.
#' @param condition Optional condition restricting when the edge applies (for
#'   example `"TRT01P == 'Drug A'"`). Recorded for transparency; not evaluated.
#' @param label Optional human-readable label.
#'
#' @return A tibble with one row and class `td_edge`.
#' @export
lineage_edge <- function(from, to, from_type = NULL, to_type = NULL,
                         relationship = "derives", condition = NA_character_,
                         label = NA_character_) {
  n <- max(length(from), length(to))
  if (length(from) == 1L && n > 1L) from <- rep(from, n)
  if (length(to) == 1L && n > 1L) to <- rep(to, n)
  if (length(from) != length(to)) {
    td_abort("{.arg from} and {.arg to} must be the same length.")
  }
  from_type <- from_type %||% td_infer_node_type(from)
  to_type <- to_type %||% td_infer_node_type(to)
  out <- tibble::tibble(
    from = as.character(from),
    from_type = as.character(from_type),
    to = as.character(to),
    to_type = as.character(to_type),
    relationship = as.character(relationship),
    condition = as.character(condition),
    label = as.character(label)
  )
  class(out) <- unique(c("td_edge", class(out)))
  out
}

#' Infer a node type from its identifier
#' @noRd
td_infer_node_type <- function(id) {
  id <- as.character(id)
  out <- rep("analysis", length(id))
  out[grepl("\\.", id)] <- "variable"
  out[grepl("^(Table|Figure|Listing|TFL|Output)", id, ignore.case = TRUE)] <- "output"
  out[grepl("^(AD|SD|DM|AE|LB|VS|EX|DS|SV|TU|RS|TR|SUPP)", id) &
        !grepl("\\.", id)] <- "dataset"
  out
}

#' Define a data lineage graph
#'
#' `define_lineage()` collects lineage edges into an auditable graph that can be
#' queried with [trace_dependencies()] and used by [assess_impact()]. The graph
#' is stored as a tidy edge list plus a node table; no external graph library is
#' required, although [as_igraph()] is provided for users who prefer one.
#'
#' @param ... One or more edge tibbles created by [lineage_edge()], or a single
#'   data frame of edges.
#' @param edges Optional data frame of edges with columns `from`, `to` and
#'   optionally `from_type`, `to_type`, `relationship`, `condition`.
#' @param nodes Optional node table with columns `node` and `type`, used to
#'   override inferred types and to attach labels.
#' @param dataset,variable,downstream Convenience arguments matching the common
#'   workflow: declare that `downstream` objects depend on `dataset.variable`.
#' @param relationship Relationship used with the convenience arguments.
#'
#' @return An object of class `td_lineage`.
#' @export
#'
#' @examples
#' lineage <- define_lineage(
#'   lineage_edge("ADSL.TRT01P", "ADLB.TRT01P", relationship = "derives"),
#'   lineage_edge("ADLB.AVAL", "MMRM", relationship = "models"),
#'   lineage_edge("MMRM", "Table_14_2_1", relationship = "reports")
#' )
#' trace_dependencies(lineage, from = "ADSL.TRT01P")
define_lineage <- function(...,
                           edges = NULL,
                           nodes = NULL,
                           dataset = NULL,
                           variable = NULL,
                           downstream = NULL,
                           relationship = "derives") {
  dots <- list(...)
  pieces <- list()

  if (!is.null(edges)) {
    pieces[[length(pieces) + 1L]] <- td_as_edges(edges)
  }
  for (d in dots) {
    if (is.data.frame(d)) {
      pieces[[length(pieces) + 1L]] <- td_as_edges(d)
    } else {
      td_abort("Each {.arg ...} element must be an edge tibble.")
    }
  }

  if (!is.null(dataset) && !is.null(variable) && !is.null(downstream)) {
    root <- paste0(dataset, ".", variable)
    pieces[[length(pieces) + 1L]] <- lineage_edge(
      from = root,
      to = downstream,
      relationship = relationship
    )
  }

  if (length(pieces) == 0L) {
    td_abort("No lineage edges supplied to {.fun define_lineage}.")
  }

  edge_tbl <- dplyr::bind_rows(pieces)
  edge_tbl <- dplyr::distinct(edge_tbl, .data$from, .data$to, .keep_all = TRUE)

  node_tbl <- td_build_nodes(edge_tbl, nodes)
  edge_tbl <- td_validate_edges(edge_tbl, node_tbl)

  structure(
    list(edges = edge_tbl, nodes = node_tbl),
    class = "td_lineage"
  )
}

#' @noRd
td_as_edges <- function(x) {
  x <- tibble::as_tibble(x)
  if (!all(c("from", "to") %in% names(x))) {
    td_abort("An edge table must contain {.val from} and {.val to} columns.")
  }
  x$from_type <- x[["from_type"]] %||% td_infer_node_type(x$from)
  x$to_type <- x[["to_type"]] %||% td_infer_node_type(x$to)
  x$relationship <- x[["relationship"]] %||% rep("derives", nrow(x))
  x$condition <- x[["condition"]] %||% rep(NA_character_, nrow(x))
  x$label <- x[["label"]] %||% rep(NA_character_, nrow(x))
  x$source <- x[["source"]] %||% rep("user", nrow(x))
  x$derivation_id <- x[["derivation_id"]] %||% rep(NA_character_, nrow(x))
  x$derivation <- x[["derivation"]] %||% rep(NA_character_, nrow(x))
  x[, c("from", "from_type", "to", "to_type", "relationship",
        "condition", "label", "source", "derivation_id", "derivation")]
}

#' @noRd
td_build_nodes <- function(edge_tbl, nodes = NULL) {
  inferred <- tibble::tibble(
    node = c(edge_tbl$from, edge_tbl$to),
    type = c(edge_tbl$from_type, edge_tbl$to_type)
  )
  inferred <- dplyr::distinct(inferred, .data$node, .keep_all = TRUE)
  inferred$label <- inferred$node

  if (!is.null(nodes)) {
    nodes <- tibble::as_tibble(nodes)
    if (!all(c("node", "type") %in% names(nodes))) {
      td_abort("A node table must contain {.val node} and {.val type} columns.")
    }
    override <- match(inferred$node, nodes$node)
    has <- !is.na(override)
    inferred$type[has] <- nodes$type[override[has]]
    if ("label" %in% names(nodes)) {
      inferred$label[has] <- nodes$label[override[has]]
    }
  }
  inferred
}

#' @noRd
td_validate_edges <- function(edge_tbl, node_tbl) {
  known <- node_tbl$node
  bad <- unique(c(edge_tbl$from, edge_tbl$to)[
    !c(edge_tbl$from, edge_tbl$to) %in% known
  ])
  if (length(bad) > 0L) {
    td_warn(c(
      "Some lineage nodes were not declared.",
      "i" = "Types were inferred for: {.val {bad}}."
    ), class = "trialdiff_warning_lineage")
  }
  edge_tbl
}

#' @export
print.td_lineage <- function(x, ...) {
  cli::cli_h1("trialdiff lineage")
  cli::cli_text("{nrow(x$edges)} edge{?s}, {nrow(x$nodes)} node{?s}")
  counts <- table(x$nodes$type)
  for (nm in names(counts)) {
    cli::cli_text("  {.strong {nm}}: {counts[[nm]]}")
  }
  if (!is.null(x$review) && nrow(x$review) > 0L) {
    cli::cli_alert_warning(
      "{nrow(x$review)} metadata reference{?s} need review \\
       ({.fun lineage_review})."
    )
  }
  invisible(x)
}

#' @export
summary.td_lineage <- function(object, ...) {
  print(object)
  cli::cli_h2("Edges")
  print(object$edges)
  invisible(object)
}

#' Trace downstream dependencies
#'
#' Performs a breadth-first traversal of the lineage graph starting from `from`
#' and returns every reachable node, its depth and the path taken.
#'
#' @param x A `td_lineage` object.
#' @param from Character vector of starting node identifiers.
#' @param direction `"downstream"` (default) or `"upstream"`.
#' @param max_depth Maximum traversal depth.
#' @param include_self Include the starting node(s) in the result.
#' @param ... Unused.
#'
#' @return A tibble with `node`, `node_type`, `depth`, `path` and
#'   `edge_relationship`.
#' @export
trace_dependencies <- function(x, from, direction = c("downstream", "upstream"),
                               max_depth = Inf, include_self = FALSE, ...) {
  UseMethod("trace_dependencies")
}

#' @export
trace_dependencies.td_lineage <- function(x, from, direction = c("downstream", "upstream"),
                                          max_depth = Inf, include_self = FALSE, ...) {
  direction <- match.arg(direction)
  if (missing(from) || length(from) == 0L) {
    td_abort("{.arg from} must name at least one starting node.")
  }
  edges <- x$edges
  if (direction == "upstream") {
    edges <- tibble::tibble(
      from = edges$to,
      from_type = edges$to_type,
      to = edges$from,
      to_type = edges$from_type,
      relationship = edges$relationship,
      condition = edges$condition,
      label = edges$label
    )
  }
  adj <- split(edges, edges$from)

  results <- list()
  queue <- tibble::tibble(
    node = as.character(from),
    depth = 0L,
    path = as.character(from),
    edge_relationship = NA_character_
  )
  visited <- as.character(from)

  while (nrow(queue) > 0L) {
    current <- queue[1, , drop = FALSE]
    queue <- queue[-1, , drop = FALSE]

    if (include_self || current$depth > 0L) {
      results[[length(results) + 1L]] <- current
    }
    if (current$depth >= max_depth) {
      next
    }
    nxt <- adj[[current$node]]
    if (is.null(nxt) || nrow(nxt) == 0L) {
      next
    }
    for (i in seq_len(nrow(nxt))) {
      child <- nxt$to[[i]]
      if (child %in% visited) {
        next
      }
      visited <- c(visited, child)
      queue <- dplyr::bind_rows(queue, tibble::tibble(
        node = child,
        depth = current$depth + 1L,
        path = paste(current$path, child, sep = " -> "),
        edge_relationship = nxt$relationship[[i]]
      ))
    }
  }

  if (length(results) == 0L) {
    out <- tibble::tibble(
      node = character(), node_type = character(), depth = integer(),
      path = character(), edge_relationship = character()
    )
    return(out)
  }
  out <- dplyr::bind_rows(results)
  type_map <- stats::setNames(x$nodes$type, x$nodes$node)
  out$node_type <- unname(type_map[out$node])
  out$node_type[is.na(out$node_type)] <- "unknown"
  dplyr::select(out, "node", "node_type", "depth", "path", "edge_relationship")
}

#' Convert lineage to an igraph object
#'
#' Requires the \pkg{igraph} package.
#'
#' @param x A `td_lineage` object.
#' @param ... Unused.
#' @return An `igraph` object.
#' @export
as_igraph <- function(x, ...) {
  UseMethod("as_igraph")
}

#' @export
as_igraph.td_lineage <- function(x, ...) {
  if (!td_has_package("igraph")) {
    td_abort("Package {.pkg igraph} is required for {.fun as_igraph}.")
  }
  g <- igraph::graph_from_data_frame(
    x$edges[, c("from", "to", "relationship")],
    directed = TRUE,
    vertices = x$nodes
  )
  g
}
