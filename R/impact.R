#' Impact-assessment policy
#'
#' Controls how aggressively changes are mapped onto downstream analyses. The
#' policy is explicit and auditable: no statistical significance is ever
#' claimed. Analyses and outputs are flagged as *requiring review/rerun*, never
#' as "statistically affected".
#'
#' @param value_direct Level for a variable derived directly from a changed
#'   variable.
#' @param value_indirect Level for more distant value changes.
#' @param record Level for added/removed observations.
#' @param schema Level for schema changes other than label changes.
#' @param label Level for label-only changes.
#' @param max_depth Maximum lineage depth to traverse.
#'
#' @return An object of class `td_policy`.
#' @export
impact_policy <- function(value_direct = "definitely_affected",
                          value_indirect = "potentially_affected",
                          record = "potentially_affected",
                          schema = "potentially_affected",
                          label = "unlikely",
                          max_depth = Inf) {
  levels <- c("definitely_affected", "potentially_affected", "unlikely")
  check_level <- function(x, nm) {
    if (!x %in% levels) {
      td_abort("{.arg {nm}} must be one of {.val {levels}}.")
    }
    x
  }
  structure(
    list(
      value_direct = check_level(value_direct, "value_direct"),
      value_indirect = check_level(value_indirect, "value_indirect"),
      record = check_level(record, "record"),
      schema = check_level(schema, "schema"),
      label = check_level(label, "label"),
      max_depth = max_depth
    ),
    class = "td_policy"
  )
}

#' @export
print.td_policy <- function(x, ...) {
  cli::cli_h3("trialdiff impact policy")
  for (nm in c("value_direct", "value_indirect", "record", "schema", "label")) {
    cli::cli_text("{.field {nm}}: {.val {x[[nm]]}}")
  }
  cli::cli_text("{.field max_depth}: {x$max_depth}")
  invisible(x)
}

#' Assess downstream impact of classified changes
#'
#' Combines a classified change set with a lineage graph to identify which
#' downstream variables, analyses and outputs *could* be affected. Impact is
#' graded as `"definitely_affected"`, `"potentially_affected"` or `"unlikely"`,
#' with an explicit rationale and the triggering change identifiers.
#'
#' `trialdiff` never claims statistical impact. Every affected analysis or
#' output is reported as requiring programmer/statistician review and, where
#' appropriate, a rerun.
#'
#' @param changes A classified `tdiff` object (output of [classify_changes()])
#'   or a change register with a `category` column.
#' @param lineage A `td_lineage` object from [define_lineage()].
#' @param policy An [impact_policy()] object.
#' @param ... Reserved for future extensions.
#'
#' @return An object of class `td_impact` with elements `impacts`, `by_subject`,
#'   `unlinked`, `summary`, `policy` and `meta`.
#' @export
#'
#' @examples
#' old <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Placebo", "Drug A"))
#' new <- data.frame(USUBJID = c("S1", "S2"), TRT01P = c("Drug A", "Drug A"))
#' diff <- compare_cut(old, new, by = "USUBJID", dataset = "ADSL") |>
#'   classify_changes()
#' lineage <- define_lineage(
#'   lineage_edge("ADSL.TRT01P", "ADLB.TRT01P", relationship = "groups_by"),
#'   lineage_edge("ADLB.TRT01P", "MMRM", relationship = "models"),
#'   lineage_edge("MMRM", "Table_14_2_1", relationship = "reports")
#' )
#' assess_impact(diff, lineage)
assess_impact <- function(changes, lineage, policy = impact_policy(), ...) {
  if (!inherits(lineage, "td_lineage")) {
    td_abort("{.arg lineage} must be created with {.fun define_lineage}.")
  }
  register <- td_change_register(changes)

  seeds <- td_impact_seeds(register, lineage)

  if (nrow(seeds) == 0L) {
    return(td_empty_impact(register, lineage, policy))
  }

  impacts <- list()
  for (i in seq_len(nrow(seeds))) {
    seed <- seeds[i, , drop = FALSE]
    traced <- trace_dependencies(
      lineage,
      from = seed$node,
      direction = "downstream",
      max_depth = policy$max_depth
    )
    if (nrow(traced) == 0L) {
      next
    }
    traced$seed <- seed$node
    traced$seed_kind <- seed$kind
    traced$seed_category <- seed$category
    traced$.change_id <- seed$.change_id
    impacts[[length(impacts) + 1L]] <- traced
  }

  if (length(impacts) == 0L) {
    return(td_empty_impact(register, lineage, policy))
  }

  raw <- dplyr::bind_rows(impacts)
  raw$level <- td_impact_level(
    kind = raw$seed_kind,
    node_type = raw$node_type,
    depth = raw$depth,
    relationship = raw$edge_relationship,
    policy = policy
  )
  raw$requires_rerun <- raw$node_type %in% c("analysis", "output") &
    raw$level %in% c("definitely_affected", "potentially_affected")

  grouped <- raw |>
    dplyr::group_by(.data$node) |>
    dplyr::summarise(
      node_type = dplyr::first(.data$node_type),
      level = td_worst_level(.data$level),
      depth = min(.data$depth),
      path = .data$path[which.max(td_level_rank(.data$level))],
      edge_relationship = dplyr::first(.data$edge_relationship),
      seed = paste(unique(.data$seed), collapse = "; "),
      seed_category = paste(unique(.data$seed_category), collapse = "; "),
      triggering_changes = paste(unique(.data$.change_id), collapse = "; "),
      requires_rerun = any(.data$requires_rerun),
      .groups = "drop"
    )

  grouped$rationale <- mapply(
    td_impact_rationale,
    node = grouped$node,
    level = grouped$level,
    path = grouped$path,
    category = grouped$seed_category,
    USE.NAMES = FALSE
  )
  grouped <- dplyr::arrange(
    grouped, dplyr::desc(td_level_rank(.data$level)), .data$depth, .data$node
  )
  grouped <- dplyr::select(
    grouped, "node", "node_type", "level", "depth", "path",
    "edge_relationship", "seed", "seed_category", "triggering_changes",
    "requires_rerun", "rationale"
  )

  unlinked <- td_unlinked_changes(register, lineage)

  structure(
    list(
      impacts = grouped,
      by_subject = td_impact_by_subject(register, seeds),
      unlinked = unlinked,
      summary = td_impact_summary(grouped, unlinked),
      policy = policy,
      meta = list(
        dataset = lineage_dataset(register),
        n_changes = nrow(register),
        generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
      )
    ),
    class = "td_impact"
  )
}

#' @noRd
td_change_register <- function(changes) {
  if (inherits(changes, "tdiff")) {
    reg <- if (!is.null(changes$register)) changes$register else as_register(changes)
  } else if (is.data.frame(changes)) {
    reg <- tibble::as_tibble(changes)
  } else {
    td_abort("{.arg changes} must be a classified {.cls tdiff} or a data frame.")
  }
  if (!"category" %in% names(reg)) {
    td_warn(
      "Change register has no {.val category} column; classify with \\
       {.fun classify_changes} first.",
      class = "trialdiff_warning_unclassified"
    )
    reg$category <- "unclassified"
  }
  if (!".change_id" %in% names(reg)) {
    reg$.change_id <- sprintf("CHG%05d", seq_len(nrow(reg)))
  }
  defaults <- list(
    record_type = NA_character_,
    variable = NA_character_,
    dataset = NA_character_,
    .subject = NA_character_
  )
  for (nm in names(defaults)) {
    if (!nm %in% names(reg)) {
      reg[[nm]] <- defaults[[nm]]
    }
  }
  reg
}

#' @noRd
td_impact_seeds <- function(register, lineage) {
  known <- lineage$nodes$node
  seeds <- list()
  push <- function(node, kind, category, change_id) {
    if (is.na(node) || !nzchar(node)) {
      return(invisible(NULL))
    }
    seeds[[length(seeds) + 1L]] <<- tibble::tibble(
      node = node, kind = kind, category = category, .change_id = change_id
    )
  }

  for (i in seq_len(nrow(register))) {
    row <- register[i, , drop = FALSE]
    cat <- row$category[[1L]]
    cid <- row$.change_id[[1L]]
    dataset <- row$dataset[[1L]] %||% NA_character_

    if (identical(row$record_type[[1L]], "schema")) {
      kind <- "schema"
      if (cat %in% c("label_change")) kind <- "label"
      node <- if (!is.na(row$variable[[1L]]) && !is.na(dataset)) {
        paste0(dataset, ".", row$variable[[1L]])
      } else {
        NA_character_
      }
      push(node, kind, cat, cid)
      if (cat %in% c("variable_removed", "variable_added") && !is.na(dataset)) {
        push(dataset, kind, cat, cid)
      }
      next
    }

    if (identical(row$record_type[[1L]], "modified")) {
      kind <- "value"
      node <- if (!is.na(dataset) && !is.na(row$variable[[1L]])) {
        paste0(dataset, ".", row$variable[[1L]])
      } else {
        NA_character_
      }
      push(node, kind, cat, cid)
      next
    }

    kind <- "record"
    if (!is.na(dataset)) {
      push(dataset, kind, cat, cid)
      members <- known[startsWith(known, paste0(dataset, "."))]
      for (m in members) {
        push(m, kind, cat, cid)
      }
    }
  }

  if (length(seeds) == 0L) {
    return(tibble::tibble(
      node = character(), kind = character(),
      category = character(), .change_id = character()
    ))
  }
  out <- dplyr::distinct(dplyr::bind_rows(seeds), .data$node, .data$.change_id,
                         .keep_all = TRUE)
  out
}

#' @noRd
td_impact_level <- function(kind, node_type, depth, relationship, policy) {
  n <- length(kind)
  out <- rep(policy$schema, n)
  direct <- c("derives", "groups_by", "filters", "transports")

  value <- kind == "value"
  out[value & node_type == "variable" &
        depth == 1L & relationship %in% direct] <- policy$value_direct
  out[value & node_type == "variable" &
        !(depth == 1L & relationship %in% direct)] <- policy$value_indirect
  out[value & node_type %in% c("analysis", "output")] <- policy$value_indirect

  out[kind == "record" & node_type == "variable"] <- policy$record
  out[kind == "record" & node_type %in% c("analysis", "output")] <- policy$record
  out[kind == "label"] <- policy$label
  out
}

#' @noRd
td_level_rank <- function(level) {
  rank <- c(definitely_affected = 3L, potentially_affected = 2L,
            unlikely = 1L, not_affected = 0L)
  unname(rank[level])
}

#' @noRd
td_worst_level <- function(level) {
  level[which.max(td_level_rank(level))]
}

#' @noRd
td_impact_rationale <- function(node, level, path, category) {
  prefix <- switch(
    level,
    definitely_affected = "Definitely affected",
    potentially_affected = "Potentially affected",
    unlikely = "Unlikely to be affected",
    "Impact level unclear"
  )
  sprintf(
    "%s: %s. Path: %s. Triggering change category: %s.",
    prefix, node, path, category
  )
}

#' @noRd
td_unlinked_changes <- function(register, lineage) {
  known <- lineage$nodes$node
  datasets <- unique(stats::na.omit(register$dataset))
  candidates <- character()
  if (length(datasets) > 0L) {
    candidates <- datasets
    vars <- unique(stats::na.omit(register$variable))
    if (length(vars) > 0L) {
      candidates <- c(
        candidates,
        as.vector(outer(datasets, vars, paste, sep = "."))
      )
    }
  }
  unlinked <- setdiff(candidates, known)
  unlinked <- unlinked[!is.na(unlinked) & nzchar(unlinked)]
  tibble::tibble(
    node = unlinked,
    reason = "No lineage edge declared for this node; downstream impact cannot be traced."
  )
}

#' @noRd
td_impact_by_subject <- function(register, seeds) {
  if (!".subject" %in% names(register)) {
    return(tibble::tibble(
      subject = character(), change_id = character(),
      category = character(), seed = character()
    ))
  }
  subj <- register[!is.na(register$.subject), , drop = FALSE]
  if (nrow(subj) == 0L) {
    return(tibble::tibble(
      subject = character(), change_id = character(),
      category = character(), seed = character()
    ))
  }
  dataset <- subj$dataset
  node <- ifelse(
    is.na(subj$variable),
    as.character(dataset),
    paste0(dataset, ".", subj$variable)
  )
  tibble::tibble(
    subject = subj$.subject,
    change_id = subj$.change_id,
    category = subj$category,
    seed = node
  )
}

#' @noRd
td_impact_summary <- function(grouped, unlinked) {
  counts <- if (nrow(grouped) == 0L) {
    tibble::tibble(level = character(), n = integer())
  } else {
    dplyr::count(grouped, .data$level, name = "n")
  }
  tibble::tibble(
    metric = c(
      "nodes_definitely_affected", "nodes_potentially_affected",
      "nodes_unlikely", "analyses_or_outputs_requiring_rerun",
      "unlinked_changes"
    ),
    value = c(
      sum(counts$n[counts$level == "definitely_affected"]),
      sum(counts$n[counts$level == "potentially_affected"]),
      sum(counts$n[counts$level == "unlikely"]),
      sum(grouped$requires_rerun %||% logical()),
      nrow(unlinked)
    )
  )
}

#' @noRd
td_empty_impact <- function(register, lineage, policy) {
  structure(
    list(
      impacts = tibble::tibble(
        node = character(), node_type = character(), level = character(),
        depth = integer(), path = character(), edge_relationship = character(),
        seed = character(), seed_category = character(),
        triggering_changes = character(), requires_rerun = logical(),
        rationale = character()
      ),
      by_subject = tibble::tibble(
        subject = character(), change_id = character(),
        category = character(), seed = character()
      ),
      unlinked = td_unlinked_changes(register, lineage),
      summary = tibble::tibble(
        metric = c(
          "nodes_definitely_affected", "nodes_potentially_affected",
          "nodes_unlikely", "analyses_or_outputs_requiring_rerun",
          "unlinked_changes"
        ),
        value = c(0L, 0L, 0L, 0L, nrow(td_unlinked_changes(register, lineage)))
      ),
      policy = policy,
      meta = list(
        dataset = lineage_dataset(register),
        n_changes = nrow(register),
        generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
      )
    ),
    class = "td_impact"
  )
}

#' @noRd
lineage_dataset <- function(register) {
  if ("dataset" %in% names(register)) {
    ds <- unique(stats::na.omit(register$dataset))
    if (length(ds) > 0L) {
      return(paste(ds, collapse = ", "))
    }
  }
  NA_character_
}

#' @export
print.td_impact <- function(x, ...) {
  cli::cli_h1("trialdiff impact assessment")
  if (!is.null(x$meta$dataset) && !is.na(x$meta$dataset)) {
    cli::cli_text("Dataset(s): {.val {x$meta$dataset}}")
  }
  cli::cli_text("Changes assessed: {x$meta$n_changes}")
  cli::cli_h2("Impact summary")
  print(x$summary)
  if (nrow(x$impacts) > 0L) {
    cli::cli_h2("Affected downstream objects")
    print(x$impacts[, c("node", "node_type", "level", "depth")])
  }
  if (nrow(x$unlinked) > 0L) {
    cli::cli_alert_warning(
      "{nrow(x$unlinked)} changed node{?s} ha{?s/ve} no declared lineage."
    )
  }
  cli::cli_alert_info(
    "Impact is a review signal only; statistical impact requires rerunning analyses."
  )
  invisible(x)
}

#' @export
summary.td_impact <- function(object, ...) {
  print(object)
  invisible(object$summary)
}
