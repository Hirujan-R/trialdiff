#' Produce a change-review report
#'
#' `report_diff()` renders a structured review report from a comparison, its
#' classification and (optionally) an impact assessment. Human-readable HTML or
#' Quarto output is supported alongside machine-readable JSON and list output
#' for automated QC pipelines.
#'
#' @param diff A `tdiff` object, ideally already passed through
#'   [classify_changes()].
#' @param impact Optional `td_impact` object from [assess_impact()].
#' @param classified Optional classified `tdiff` object. If supplied it takes
#'   precedence over `diff` for classification content.
#' @param output Either a format (`"html"`, `"quarto"`, `"json"`, `"list"`) or a
#'   file path. When a path is given the format is inferred from the extension.
#' @param format Report format. Ignored when `output` is a path.
#' @param title Report title.
#' @param max_rows Maximum number of rows shown per table in HTML output.
#' @param include_disclaimer Include the regulatory/statistical disclaimer.
#' @param ... Reserved for future extensions.
#'
#' @return An object of class `td_report`. When a file path is supplied the
#'   report is written and the path is stored in `$path`.
#' @export
report_diff <- function(diff,
                        impact = NULL,
                        classified = NULL,
                        output = "html",
                        format = c("html", "quarto", "json", "list"),
                        title = NULL,
                        max_rows = 25L,
                        include_disclaimer = TRUE,
                        ...) {
  format <- match.arg(format)
  path <- NULL
  if (is.character(output) && length(output) == 1L &&
      !output %in% c("html", "quarto", "json", "list")) {
    path <- output
    format <- td_format_from_path(path)
  } else if (is.character(output) && length(output) == 1L) {
    format <- output
  }

  source <- classified %||% diff
  if (!inherits(source, "tdiff")) {
    td_abort("{.arg diff} must be a {.cls tdiff} object.")
  }
  if (is.null(source$register)) {
    source <- classify_changes(source)
  }
  register <- source$register

  title <- title %||% td_default_title(source)

  data <- list(
    meta = source$meta,
    summary = source$summary,
    register = register,
    impacts = if (!is.null(impact)) impact$impacts else NULL,
    impact_summary = if (!is.null(impact)) impact$summary else NULL,
    unlinked = if (!is.null(impact)) impact$unlinked else NULL,
    review_items = td_review_items(source, impact),
    disclaimer = if (include_disclaimer) td_disclaimer() else NULL,
    title = title,
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  )

  html <- NULL
  if (format == "html") {
    html <- td_report_html(data, max_rows = max_rows)
  }

  if (!is.null(path)) {
    td_write_report(data, format = format, path = path, html = html)
  }

  structure(
    list(
      path = path,
      format = format,
      html = html,
      data = data
    ),
    class = "td_report"
  )
}

#' @noRd
td_format_from_path <- function(path) {
  ext <- tolower(tools::file_ext(path))
  switch(ext,
    html = "html",
    htm = "html",
    qmd = "quarto",
    json = "json",
    "html"
  )
}

#' @noRd
td_default_title <- function(diff) {
  ds <- diff$meta$dataset
  if (is.null(ds) || is.na(ds)) ds <- "dataset"
  sprintf(
    "Data-cut change review: %s (%s \u2192 %s)",
    ds, diff$meta$name_old, diff$meta$name_new
  )
}

#' @noRd
td_disclaimer <- function() {
  paste(
    "Impact assessment is a deterministic review signal derived from",
    "user-declared lineage. It does not establish statistical significance.",
    "Analyses flagged for review must be rerun before any conclusion is drawn."
  )
}

#' @noRd
td_review_items <- function(diff, impact = NULL) {
  items <- list()
  reg <- if (!is.null(diff$register)) diff$register else as_register(diff)
  if (!"category" %in% names(reg)) {
    reg$category <- "unclassified"
  }

  unclassified <- reg[reg$category == "unclassified", , drop = FALSE]
  if (nrow(unclassified) > 0L) {
    items[[length(items) + 1L]] <- tibble::tibble(
      item = "Unclassified change",
      detail = sprintf(
        "%d change(s) matched no classification rule (e.g. %s).",
        nrow(unclassified), unclassified$.change_id[[1L]]
      ),
      owner = "Programmer"
    )
  }

  if (!is.null(impact) && nrow(impact$impacts) > 0L) {
    rerun <- impact$impacts[impact$impacts$requires_rerun, , drop = FALSE]
    for (i in seq_len(nrow(rerun))) {
      items[[length(items) + 1L]] <- tibble::tibble(
        item = "Rerun required",
        detail = sprintf(
          "%s (%s) - %s", rerun$node[[i]], rerun$level[[i]],
          rerun$rationale[[i]]
        ),
        owner = "Statistician"
      )
    }
  }

  if (!is.null(impact) && nrow(impact$unlinked) > 0L) {
    items[[length(items) + 1L]] <- tibble::tibble(
      item = "Lineage gap",
      detail = sprintf(
        "%d changed node(s) have no declared lineage: %s.",
        nrow(impact$unlinked),
        paste(utils::head(impact$unlinked$node, 5), collapse = ", ")
      ),
      owner = "Programmer"
    )
  }

  if (length(items) == 0L) {
    return(tibble::tibble(item = character(), detail = character(),
                          owner = character()))
  }
  dplyr::bind_rows(items)
}

#' Write a report to disk
#' @noRd
td_write_report <- function(data, format, path, html = NULL) {
  dir <- dirname(path)
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  switch(format,
    html = writeLines(html, path, useBytes = TRUE),
    quarto = writeLines(td_report_quarto(data), path, useBytes = TRUE),
    json = writeLines(td_report_json(data, pretty = TRUE), path, useBytes = TRUE),
    list = saveRDS(data, path)
  )
  invisible(path)
}

#' @noRd
td_html_table <- function(df, max_rows = 25L, caption = NULL) {
  if (is.null(df) || nrow(df) == 0L) {
    return(htmltools::tags$p(class = "td-empty", "No rows."))
  }
  shown <- utils::head(df, max_rows)
  truncated <- nrow(df) > max_rows
  header <- htmltools::tags$tr(lapply(names(shown), htmltools::tags$th))
  body <- lapply(seq_len(nrow(shown)), function(i) {
    htmltools::tags$tr(lapply(shown[i, , drop = FALSE], function(col) {
      htmltools::tags$td(as.character(col))
    }))
  })
  tbl <- htmltools::tags$table(
    class = "td-table",
    if (!is.null(caption)) htmltools::tags$caption(caption),
    htmltools::tags$thead(header),
    htmltools::tags$tbody(body)
  )
  if (truncated) {
    tbl <- htmltools::tagList(
      tbl,
      htmltools::tags$p(
        class = "td-note",
        sprintf("Showing %d of %d rows.", max_rows, nrow(df))
      )
    )
  }
  tbl
}

#' @noRd
td_report_html <- function(data, max_rows = 25L) {
  reg <- data$register
  added <- reg[reg$record_type == "added", , drop = FALSE]
  removed <- reg[reg$record_type == "removed", , drop = FALSE]
  modified <- reg[reg$record_type == "modified", , drop = FALSE]
  schema <- reg[reg$record_type == "schema", , drop = FALSE]

  cat_summary <- if (nrow(reg) > 0L) {
    dplyr::count(reg, .data$category_label, .data$category, name = "n") |>
      dplyr::arrange(dplyr::desc(.data$n)) |>
      dplyr::select("category_label", "category", "n")
  } else {
    tibble::tibble(category_label = character(), category = character(),
                   n = integer())
  }

  sections <- list(
    htmltools::tags$section(
      htmltools::tags$h2("Comparison overview"),
      td_html_table(data$summary, max_rows = 100L)
    ),
    htmltools::tags$section(
      htmltools::tags$h2("Changes by category"),
      td_html_table(cat_summary, max_rows = 100L)
    ),
    htmltools::tags$section(
      htmltools::tags$h2("Added observations"),
      td_html_table(td_pick(added, c("dataset", "USUBJID", ".subject", ".key",
                                     "category_label")),
                    max_rows = max_rows)
    ),
    htmltools::tags$section(
      htmltools::tags$h2("Removed observations"),
      td_html_table(td_pick(removed, c("dataset", "USUBJID", ".subject", ".key",
                                       "category_label")),
                    max_rows = max_rows)
    ),
    htmltools::tags$section(
      htmltools::tags$h2("Modified values"),
      td_html_table(
        td_pick(modified, c("dataset", "USUBJID", ".subject", "variable",
                            "old_value", "new_value", "category_label",
                            "reason")),
        max_rows = max_rows
      )
    ),
    htmltools::tags$section(
      htmltools::tags$h2("Schema changes"),
      td_html_table(schema, max_rows = max_rows)
    )
  )

  if (!is.null(data$impacts)) {
    sections[[length(sections) + 1L]] <- htmltools::tags$section(
      htmltools::tags$h2("Downstream impact"),
      td_html_table(data$impact_summary, max_rows = 100L),
      htmltools::tags$h3("Affected objects"),
      td_html_table(
        td_pick(data$impacts, c("node", "node_type", "level", "depth", "path",
                                "triggering_changes", "requires_rerun")),
        max_rows = max_rows
      )
    )
    if (nrow(data$unlinked) > 0L) {
      sections[[length(sections) + 1L]] <- htmltools::tags$section(
        htmltools::tags$h2("Lineage gaps"),
        td_html_table(data$unlinked, max_rows = max_rows)
      )
    }
  }

  sections[[length(sections) + 1L]] <- htmltools::tags$section(
    htmltools::tags$h2("Items requiring review"),
    td_html_table(data$review_items, max_rows = 100L)
  )

  if (!is.null(data$disclaimer)) {
    sections[[length(sections) + 1L]] <- htmltools::tags$section(
      class = "td-disclaimer",
      htmltools::tags$h2("Disclaimer"),
      htmltools::tags$p(data$disclaimer)
    )
  }

  page <- htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "utf-8"),
      htmltools::tags$title(data$title),
      htmltools::tags$style(htmltools::HTML(td_report_css()))
    ),
    htmltools::tags$body(
      htmltools::tags$header(
        htmltools::tags$h1(data$title),
        htmltools::tags$p(class = "td-meta",
                          sprintf("Generated %s", data$generated))
      ),
      sections
    )
  )
  as.character(page)
}

#' @noRd
td_pick <- function(df, cols) {
  keep <- intersect(cols, names(df))
  if (length(keep) == 0L) {
    return(df)
  }
  df[, keep, drop = FALSE]
}

#' @noRd
td_report_css <- function() {
  paste(
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,",
    "Helvetica,Arial,sans-serif;margin:2rem auto;max-width:1100px;",
    "color:#1b1b1b;padding:0 1rem;line-height:1.5}",
    "h1{border-bottom:3px solid #0a5c8c;padding-bottom:.4rem}",
    "h2{color:#0a5c8c;margin-top:2rem}",
    ".td-meta{color:#666;font-size:.9rem}",
    ".td-table{border-collapse:collapse;width:100%;font-size:.85rem;",
    "margin:.5rem 0 1rem}",
    ".td-table th,.td-table td{border:1px solid #ddd;padding:.35rem .5rem;",
    "text-align:left;vertical-align:top}",
    ".td-table th{background:#f0f5f9}",
    ".td-note{color:#666;font-size:.8rem}",
    ".td-empty{color:#888;font-style:italic}",
    ".td-disclaimer{background:#fff8e1;border-left:4px solid #f0ad4e;",
    "padding:.5rem 1rem;margin-top:2rem}",
    sep = ""
  )
}

#' @noRd
td_report_quarto <- function(data) {
  template <- system.file("templates", "report.qmd", package = "trialdiff")
  if (nzchar(template) && file.exists(template)) {
    lines <- readLines(template, warn = FALSE)
    lines <- sub(
      '^title:.*$',
      sprintf('title: "%s"', data$title),
      lines
    )
    return(lines)
  }
  c(
    "---",
    sprintf('title: "%s"', data$title),
    "format: html",
    "---",
    "",
    "```{r}",
    "report <- readRDS('trialdiff_report_data.rds')",
    "knitr::kable(report$summary)",
    "```",
    ""
  )
}

#' Machine-readable report data
#'
#' @param x A `tdiff`, `td_impact` or `td_report` object.
#' @param pretty Pretty-print JSON.
#' @param ... Unused.
#' @return For `as_json()`, a JSON string. For `as_report_list()`, a list.
#' @export
as_json <- function(x, pretty = TRUE, ...) {
  UseMethod("as_json")
}

#' @export
as_json.tdiff <- function(x, pretty = TRUE, ...) {
  td_report_json(list(
    meta = x$meta,
    summary = x$summary,
    register = if (!is.null(x$register)) x$register else as_register(x)
  ), pretty = pretty)
}

#' @export
as_json.td_impact <- function(x, pretty = TRUE, ...) {
  td_report_json(list(
    impacts = x$impacts,
    summary = x$summary,
    unlinked = x$unlinked,
    meta = x$meta
  ), pretty = pretty)
}

#' @export
as_json.td_report <- function(x, pretty = TRUE, ...) {
  td_report_json(x$data, pretty = pretty)
}

#' @noRd
td_report_json <- function(data, pretty = TRUE) {
  clean <- lapply(data, td_json_safe)
  jsonlite::toJSON(
    clean,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    pretty = pretty,
    digits = NA
  )
}

#' @noRd
td_json_safe <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (is.data.frame(x)) {
    x <- as.data.frame(x, stringsAsFactors = FALSE)
    x[] <- lapply(x, td_json_safe)
    return(x)
  }
  if (is.list(x)) {
    return(lapply(x, td_json_safe))
  }
  if (inherits(x, c("Date", "POSIXct", "POSIXt"))) {
    return(as.character(x))
  }
  x
}

#' @export
print.td_report <- function(x, ...) {
  cli::cli_h1("trialdiff report")
  cli::cli_text("Format: {.val {x$format}}")
  if (!is.null(x$path)) {
    cli::cli_text("Written to: {.path {x$path}}")
  } else if (x$format == "html") {
    cli::cli_text("HTML report held in {.code $html} ({nchar(x$html)} characters).")
  }
  invisible(x)
}
