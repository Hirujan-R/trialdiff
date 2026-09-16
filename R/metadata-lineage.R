#' Derive lineage from study metadata
#'
#' `lineage_from_metadata()` builds a [define_lineage()] graph from a
#' \pkg{metacore} object (or any list with the same tables). Dataset and
#' variable nodes come from `ds_vars`/`ds_spec`, and dependency edges are parsed
#' from the `derivations` and `where` columns of `value_spec`.
#'
#' Parsing is deterministic and conservative: only tokens that resolve to known
#' variables (or explicit `DATASET.VARIABLE` references) become edges. Every
#' edge records its provenance, and references that cannot be resolved uniquely
#' are returned in a review table rather than guessed. See [lineage_review()].
#'
#' @param metadata A `metacore` object (from \pkg{metacore}) or a list with
#'   elements `ds_vars`, `ds_spec`, `value_spec` and `derivations`.
#' @param include_where Logical. If `TRUE` (default), variables referenced in
#'   `value_spec$where` clauses are added as `"filters"` edges.
#' @param include_sdtm Logical. If `TRUE` (default), `DATASET.VARIABLE`
#'   references to non-ADaM domains (for example `DM.ARM`) are kept as source
#'   nodes.
#' @param ... Reserved for future extensions.
#'
#' @return A `td_lineage` object with additional elements `review` (references
#'   needing manual attention) and `provenance`.
#' @export
#'
#' @examples
#' metadata <- list(
#'   ds_spec = data.frame(dataset = c("ADSL", "ADLB"), stringsAsFactors = FALSE),
#'   ds_vars = data.frame(
#'     dataset = c("ADSL", "ADSL", "ADLB", "ADLB", "ADLB"),
#'     variable = c("USUBJID", "TRT01P", "USUBJID", "AVAL", "CHG"),
#'     stringsAsFactors = FALSE
#'   ),
#'   value_spec = data.frame(
#'     dataset = c("ADSL", "ADLB", "ADLB"),
#'     variable = c("TRT01P", "AVAL", "CHG"),
#'     derivation_id = c("MT.ADSL.TRT01P", "MT.ADLB.AVAL", "MT.ADLB.CHG"),
#'     where = c(NA, "PARAMCD == 'ALT'", NA),
#'     stringsAsFactors = FALSE
#'   ),
#'   derivations = data.frame(
#'     derivation_id = c("MT.ADSL.TRT01P", "MT.ADLB.AVAL", "MT.ADLB.CHG"),
#'     derivation = c("DM.ARM", "ADSL.TRT01P", "AVAL - BASE"),
#'     stringsAsFactors = FALSE
#'   )
#' )
#' lineage_from_metadata(metadata)
lineage_from_metadata <- function(metadata,
                                  include_where = TRUE,
                                  include_sdtm = TRUE,
                                  ...) {
  ds_vars <- td_meta_table(metadata, "ds_vars")
  value_spec <- td_meta_table(metadata, "value_spec")
  derivations <- td_meta_table(metadata, "derivations")
  ds_spec <- td_meta_table(metadata, "ds_spec")

  if (is.null(ds_vars) || !all(c("dataset", "variable") %in% names(ds_vars))) {
    td_abort(c(
      "{.arg metadata} must provide a {.val ds_vars} table with \\
       {.val dataset} and {.val variable} columns.",
      "i" = "Supply a {.pkg metacore} object or an equivalent list."
    ), class = "trialdiff_error_metadata")
  }

  known <- split(ds_vars$variable, ds_vars$dataset)
  var_index <- split(ds_vars$dataset, ds_vars$variable)
  var_index <- lapply(var_index, unique)

  edges <- list()
  review <- list()
  add_edge <- function(from, to, relationship, condition, label, source,
                       derivation_id, derivation) {
    if (identical(from, to)) {
      return(invisible(NULL))
    }
    edges[[length(edges) + 1L]] <<- tibble::tibble(
      from = from,
      from_type = td_infer_node_type(from),
      to = to,
      to_type = td_infer_node_type(to),
      relationship = relationship,
      condition = condition,
      label = label,
      source = source,
      derivation_id = derivation_id,
      derivation = derivation
    )
  }
  add_review <- function(dataset, variable, derivation_id, derivation, reason) {
    review[[length(review) + 1L]] <<- tibble::tibble(
      dataset = dataset,
      variable = variable,
      derivation_id = derivation_id %||% NA_character_,
      derivation = derivation %||% NA_character_,
      reason = reason
    )
  }

  if (!is.null(value_spec) &&
      all(c("dataset", "variable") %in% names(value_spec))) {
    has_did <- "derivation_id" %in% names(value_spec)
    has_where <- "where" %in% names(value_spec)

    for (i in seq_len(nrow(value_spec))) {
      ds <- value_spec$dataset[[i]]
      var <- value_spec$variable[[i]]
      target <- paste0(ds, ".", var)
      did <- if (has_did) value_spec$derivation_id[[i]] else NA_character_
      text <- td_lookup_derivation(did, derivations)
      where <- if (has_where) value_spec$where[[i]] else NA_character_

      parsed <- td_parse_derivation(text, var_index, ds, var)

      for (j in seq_len(nrow(parsed$refs))) {
        add_edge(
          from = parsed$refs$node[[j]], to = target,
          relationship = "derives", condition = NA_character_,
          label = did, source = "metacore:derivation",
          derivation_id = did, derivation = text
        )
      }

      if (nrow(parsed$refs) == 0L && !td_is_blank(text)) {
        add_review(ds, var, did, text, "No variable references detected.")
      }
      for (j in seq_len(nrow(parsed$unresolved))) {
        add_review(
          ds, var, did, text,
          sprintf(
            "Reference '%s' is ambiguous or unknown.",
            parsed$unresolved$token[[j]]
          )
        )
      }

      if (include_where && !td_is_blank(where)) {
        wrefs <- td_parse_where(where, known[[ds]] %||% character(), ds, var)
        for (w in wrefs) {
          add_edge(
            from = w, to = target,
            relationship = "filters", condition = where,
            label = NA_character_, source = "metacore:where",
            derivation_id = did, derivation = text
          )
        }
      }
    }
  }

  if (length(edges) == 0L) {
    td_warn(c(
      "No lineage edges could be derived from {.arg metadata}.",
      "i" = "Inspect {.fun lineage_review} for references that need attention."
    ), class = "trialdiff_warning_metadata")
    edge_tbl <- tibble::tibble(
      from = character(), from_type = character(),
      to = character(), to_type = character(),
      relationship = character(), condition = character(),
      label = character(), source = character(),
      derivation_id = character(), derivation = character()
    )
  } else {
    edge_tbl <- dplyr::distinct(
      dplyr::bind_rows(edges),
      .data$from, .data$to, .data$relationship, .data$condition,
      .keep_all = TRUE
    )
    if (!include_sdtm) {
      edge_tbl <- edge_tbl[edge_tbl$from_type == "variable" &
                             grepl("^(AD|SD)", edge_tbl$from), , drop = FALSE]
    }
  }

  node_tbl <- td_nodes_from_metadata(ds_vars, ds_spec)
  nodes <- td_build_nodes(edge_tbl, node_tbl)
  nodes <- dplyr::distinct(
    dplyr::bind_rows(nodes, node_tbl),
    .data$node, .keep_all = TRUE
  )

  structure(
    list(
      edges = edge_tbl,
      nodes = nodes,
      review = if (length(review) == 0L) {
        tibble::tibble(
          dataset = character(), variable = character(),
          derivation_id = character(), derivation = character(),
          reason = character()
        )
      } else {
        dplyr::distinct(dplyr::bind_rows(review))
      },
      provenance = edge_tbl
    ),
    class = "td_lineage"
  )
}

#' References needing review after metadata-driven lineage
#'
#' @param x A `td_lineage` object, typically from [lineage_from_metadata()].
#' @return A tibble of unresolved or undetected references.
#' @export
lineage_review <- function(x) {
  if (!inherits(x, "td_lineage")) {
    td_abort("{.arg x} must be a {.cls td_lineage} object.")
  }
  x$review %||% tibble::tibble(
    dataset = character(), variable = character(),
    derivation_id = character(), derivation = character(),
    reason = character()
  )
}

#' Provenance of metadata-driven lineage edges
#'
#' @param x A `td_lineage` object.
#' @return A tibble with the metadata source of each edge.
#' @export
lineage_provenance <- function(x) {
  if (!inherits(x, "td_lineage")) {
    td_abort("{.arg x} must be a {.cls td_lineage} object.")
  }
  x$provenance %||% x$edges
}

#' @noRd
td_meta_table <- function(metadata, name) {
  if (is.null(metadata)) {
    return(NULL)
  }
  if (is.environment(metadata)) {
    return(metadata[[name]])
  }
  metadata[[name]]
}

#' @noRd
td_lookup_derivation <- function(derivation_id, derivations) {
  if (is.null(derivation_id) || is.na(derivation_id) ||
      is.null(derivations) || !"derivation" %in% names(derivations)) {
    return(NA_character_)
  }
  idx <- match(derivation_id, derivations$derivation_id)
  if (is.na(idx)) {
    return(NA_character_)
  }
  derivations$derivation[[idx]]
}

#' @noRd
td_is_blank <- function(x) {
  is.null(x) || length(x) == 0L || is.na(x[[1L]]) || !nzchar(trimws(x[[1L]]))
}

#' Parse a derivation string into resolved variable references
#' @noRd
td_parse_derivation <- function(text, var_index, dataset, target_var) {
  refs <- tibble::tibble(node = character(), token = character())
  unresolved <- tibble::tibble(token = character())
  if (td_is_blank(text)) {
    return(list(refs = refs, unresolved = unresolved))
  }

  txt <- gsub("[\r\n]+", " ", text)
  qualified <- td_match(txt, "\\b[A-Z][A-Z0-9]{0,7}\\.[A-Z][A-Z0-9]{0,7}\\b")
  txt_bare <- gsub("\\b[A-Z][A-Z0-9]{0,7}\\.[A-Z][A-Z0-9]{0,7}\\b", " ", txt)
  bare <- td_match(txt_bare, "\\b[A-Z][A-Z0-9]{1,7}\\b")

  nodes <- character()
  tokens <- character()
  unresolved_tokens <- character()

  target <- paste0(dataset, ".", target_var)
  for (q in qualified) {
    if (!identical(q, target)) {
      nodes <- c(nodes, q)
      tokens <- c(tokens, q)
    }
  }
  for (b in bare) {
    if (identical(b, target_var)) {
      next
    }
    candidates <- var_index[[b]]
    if (is.null(candidates)) {
      next
    }
    if (dataset %in% candidates) {
      nodes <- c(nodes, paste0(dataset, ".", b))
      tokens <- c(tokens, b)
    } else if (length(candidates) == 1L) {
      nodes <- c(nodes, paste0(candidates, ".", b))
      tokens <- c(tokens, b)
    } else {
      unresolved_tokens <- c(unresolved_tokens, b)
    }
  }

  keep <- !duplicated(nodes)
  if (any(keep)) {
    refs <- tibble::tibble(node = nodes[keep], token = tokens[keep])
  }
  if (length(unresolved_tokens) > 0L) {
    unresolved <- tibble::tibble(token = unique(unresolved_tokens))
  }
  list(refs = refs, unresolved = unresolved)
}

#' Parse a where clause into same-dataset variable references
#' @noRd
td_parse_where <- function(text, dataset_vars, dataset, target_var) {
  if (td_is_blank(text)) {
    return(character())
  }
  tokens <- unique(td_match(text, "\\b[A-Z][A-Z0-9]{1,7}\\b"))
  tokens <- tokens[tokens %in% dataset_vars & tokens != target_var]
  if (length(tokens) == 0L) {
    return(character())
  }
  paste0(dataset, ".", tokens)
}

#' @noRd
td_match <- function(text, pattern) {
  m <- regmatches(text, gregexpr(pattern, text))[[1]]
  m[nzchar(m)]
}

#' @noRd
td_nodes_from_metadata <- function(ds_vars, ds_spec) {
  var_nodes <- tibble::tibble(
    node = paste0(ds_vars$dataset, ".", ds_vars$variable),
    type = "variable",
    label = ds_vars$variable
  )
  pieces <- list(var_nodes)
  if (!is.null(ds_spec) && "dataset" %in% names(ds_spec)) {
    label <- if ("label" %in% names(ds_spec)) ds_spec$label else ds_spec$dataset
    pieces[[length(pieces) + 1L]] <- tibble::tibble(
      node = ds_spec$dataset,
      type = "dataset",
      label = label
    )
  }
  dplyr::distinct(dplyr::bind_rows(pieces), .data$node, .keep_all = TRUE)
}
