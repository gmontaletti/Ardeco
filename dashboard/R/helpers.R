# helpers.R
# Shared helper functions for the ARDECO Lombardia Quarto dashboard.
# Each function handles one concern: data loading, filtering, uniqueness
# checking, time-series visualisation, choropleth mapping, or tabular display.
#
# All data manipulation uses data.table with list() syntax (no .() alias).
# plotly and DT receive plain data.frames via as.data.frame().

# 1. Libraries -----

library(data.table)
library(arrow)
library(sf)
library(ggplot2)
library(plotly)
library(leaflet)
library(DT)
library(scales)
library(RColorBrewer)

# 2. Data loading -----

#' Read a single-variable Parquet file from the data directory.
#'
#' @param var_code Character. ARDECO variable code (e.g. "SNPTD").
#'   The file must exist at `../data/{var_code}.parquet`.
#' @return A data.table.
load_variable <- function(var_code) {
  stopifnot(
    is.character(var_code),
    length(var_code) == 1L,
    nchar(var_code) > 0L
  )
  path <- file.path("..", "data", paste0(var_code, ".parquet"))
  if (!file.exists(path)) {
    stop(
      "Parquet file not found: ",
      path,
      "\nVariable code '",
      var_code,
      "' may be invalid or the data ",
      "pipeline has not been run.",
      call. = FALSE
    )
  }
  as.data.table(arrow::read_parquet(path))
}

#' Read the labels lookup list.
#'
#' @return A named list containing label mappings (e.g. variable_labels,
#'   unit_labels, sector_labels).
load_labels <- function() {
  path <- file.path("..", "data", "labels.rds")
  if (!file.exists(path)) {
    stop(
      "Labels file not found: ",
      path,
      "\nRun the data pipeline to generate labels.rds.",
      call. = FALSE
    )
  }
  readRDS(path)
}

#' Read the Lombardia NUTS-3 GeoPackage.
#'
#' @return An sf object with provincial boundaries.
load_geo <- function() {
  path <- file.path("..", "data", "lombardia_nuts3.gpkg")
  if (!file.exists(path)) {
    stop(
      "GeoPackage not found: ",
      path,
      "\nRun R/02_download_geo.R first.",
      call. = FALSE
    )
  }
  sf::st_read(path, quiet = TRUE)
}

# 3. Filtering and validation -----

#' Apply dimension filters to a data.table.
#'
#' Each non-NULL argument filters the corresponding column, but only if
#' that column exists in the data. Columns that do not exist are silently
#' ignored.
#'
#' @param dt A data.table.
#' @param unit Character or NULL. Filter on UNIT column.
#' @param sex Character or NULL. Filter on SEX column.
#' @param age Character or NULL. Filter on AGE column.
#' @param sector Character or NULL. Filter on SECTOR column.
#' @return A filtered data.table.
filter_data <- function(
  dt,
  unit = NULL,
  sex = NULL,
  age = NULL,
  sector = NULL,
  isced11 = NULL
) {
  stopifnot(is.data.table(dt))

  filters <- list(
    UNIT = unit,
    SEX = sex,
    AGE = age,
    SECTOR = sector,
    ISCED11 = isced11
  )

  dt_cols <- names(dt)
  for (col_name in names(filters)) {
    val <- filters[[col_name]]
    if (!is.null(val) && col_name %in% dt_cols) {
      dt <- dt[get(col_name) == val]
    }
  }

  dt
}

#' Check that a data.table has at most one row per key combination.
#'
#' @param dt A data.table.
#' @param by_cols Character vector of column names that form the unique key
#'   (default: c("NUTSCODE", "YEAR")).
#' @return dt, invisibly, if no duplicates are found.
ensure_unique <- function(dt, by_cols = c("NUTSCODE", "YEAR")) {
  stopifnot(
    is.data.table(dt),
    is.character(by_cols),
    all(by_cols %in% names(dt))
  )

  dup_count <- dt[, list(n = .N), by = by_cols][n > 1L]
  if (nrow(dup_count) > 0L) {
    stop(
      "Data contains ",
      nrow(dup_count),
      " duplicate key combinations ",
      "(columns: ",
      paste(by_cols, collapse = ", "),
      "). ",
      "Apply filter_data() before plotting to ensure uniqueness.",
      call. = FALSE
    )
  }

  invisible(dt)
}

# 4. Regional time-series plotly chart -----

#' Create an interactive time-series chart with regional total and provinces.
#'
#' Receives pre-filtered data (one value per NUTSCODE + YEAR) and builds a
#' plotly chart with the NUTS-2 regional total as a visible thick line and
#' NUTS-3 provinces as hidden traces togglable via legend or buttons.
#'
#' @param dt A data.table with columns NUTSCODE, YEAR, VALUE. Must already
#'   be filtered so that each NUTSCODE-YEAR pair is unique.
#' @param var_label Character. Italian label for the variable (used as title).
#' @param unit_label Character. Italian label for the unit (used as y-axis).
#' @param nuts2_code Character. NUTS-2 code for the regional total
#'   (default "ITC4" for Lombardia).
#' @return A plotly object.
ts_plotly_regional <- function(dt, var_label, unit_label, nuts2_code = "ITC4") {
  stopifnot(
    is.data.table(dt),
    is.character(var_label),
    length(var_label) == 1L,
    is.character(unit_label),
    length(unit_label) == 1L,
    is.character(nuts2_code),
    length(nuts2_code) == 1L
  )

  ensure_unique(dt)

  # Split into NUTS-2 (regional total) and NUTS-3 (provinces)
  nuts2 <- dt[NUTSCODE == nuts2_code]
  nuts3 <- dt[nchar(NUTSCODE) == 5L]

  if (nrow(nuts2) == 0L && nrow(nuts3) == 0L) {
    warning(
      "No data to plot for '",
      var_label,
      "'.",
      call. = FALSE
    )
    return(plotly::plotly_empty())
  }

  # Sort by year
  setorder(nuts2, YEAR)
  setorder(nuts3, NUTSCODE, YEAR)

  # Province palette
  province_codes <- sort(unique(nuts3$NUTSCODE))
  n_prov <- length(province_codes)
  if (n_prov > 0L) {
    pal_n <- max(3L, min(n_prov, 12L))
    prov_colors <- RColorBrewer::brewer.pal(pal_n, "Set3")[seq_len(n_prov)]
  }

  # Build plotly figure

  fig <- plotly::plot_ly()

  # NUTS-2 regional total: thick red line, always visible
  if (nrow(nuts2) > 0L) {
    fig <- fig |>
      plotly::add_trace(
        data = as.data.frame(nuts2),
        x = ~YEAR,
        y = ~VALUE,
        type = "scatter",
        mode = "lines",
        name = paste0(nuts2_code, " (regione)"),
        line = list(width = 3, color = "#d62728"),
        visible = TRUE,
        hovertemplate = paste0(
          nuts2_code,
          " (regione)",
          "<br>Anno: %{x}<br>Valore: %{y:,.2f}<extra></extra>"
        )
      )
  }

  # NUTS-3 province traces: thinner lines, hidden by default
  for (i in seq_along(province_codes)) {
    prov_code <- province_codes[i]
    prov_data <- nuts3[NUTSCODE == prov_code]
    if (nrow(prov_data) > 0L) {
      fig <- fig |>
        plotly::add_trace(
          data = as.data.frame(prov_data),
          x = ~YEAR,
          y = ~VALUE,
          type = "scatter",
          mode = "lines",
          name = prov_code,
          line = list(width = 1.5, color = prov_colors[i]),
          visible = "legendonly",
          hovertemplate = paste0(
            prov_code,
            "<br>Anno: %{x}<br>Valore: %{y:,.2f}<extra></extra>"
          )
        )
    }
  }

  fig <- fig |>
    plotly::layout(
      title = list(text = var_label, x = 0.05),
      xaxis = list(title = ""),
      yaxis = list(title = unit_label),
      legend = list(orientation = "h", y = -0.15)
    )

  fig
}

# 5. Leaflet choropleth map -----

#' Create a leaflet choropleth map for a single year.
#'
#' Displays NUTS-3 values on a map of Lombardia provinces.
#'
#' @param dt A data.table with columns NUTSCODE, YEAR, VALUE. Should
#'   already be filtered for the desired unit/sex/age dimensions.
#' @param geo An sf object returned by load_geo().
#' @param var_label Character. Italian label for the variable.
#' @param unit_label Character. Italian label for the measurement unit.
#' @param year Numeric or NULL. Reference year; if NULL the most recent
#'   available year is used.
#' @return A leaflet object.
map_leaflet <- function(dt, geo, var_label, unit_label, year = NULL) {
  stopifnot(
    is.data.table(dt),
    inherits(geo, "sf"),
    is.character(var_label),
    length(var_label) == 1L,
    is.character(unit_label),
    length(unit_label) == 1L
  )

  # Keep only NUTS-3 rows
  dt_nuts3 <- dt[nchar(NUTSCODE) == 5L]

  if (nrow(dt_nuts3) == 0L) {
    # Fallback: show NUTS-2 regional polygon
    dt_nuts2 <- dt[nchar(NUTSCODE) == 4L]
    if (nrow(dt_nuts2) == 0L) {
      return(leaflet::leaflet() |> leaflet::addTiles())
    }
    if (is.null(year)) {
      year <- max(dt_nuts2$YEAR, na.rm = TRUE)
    }
    dt_year <- dt_nuts2[YEAR == year]
    if (nrow(dt_year) == 0L) {
      return(leaflet::leaflet() |> leaflet::addTiles())
    }
    geo_nuts2 <- geo[nchar(geo$NUTS_ID) == 4L, ]
    geo_data <- merge(
      geo_nuts2,
      as.data.frame(dt_year[, list(NUTSCODE, VALUE)]),
      by.x = "NUTS_ID",
      by.y = "NUTSCODE",
      all.x = TRUE
    )
    popup_text <- paste0(
      "<strong>",
      geo_data$NUTS_ID,
      "</strong><br>",
      geo_data$NAME_LATN,
      "<br>",
      var_label,
      " (",
      year,
      "): ",
      scales::comma(geo_data$VALUE, accuracy = 0.01)
    )
    return(
      leaflet::leaflet(geo_data) |>
        leaflet::addTiles() |>
        leaflet::addPolygons(
          fillColor = "#4292c6",
          fillOpacity = 0.5,
          weight = 1,
          color = "#444444",
          popup = popup_text,
          highlightOptions = leaflet::highlightOptions(
            weight = 2,
            fillOpacity = 0.7,
            bringToFront = TRUE
          )
        )
    )
  }

  # Select year
  if (is.null(year)) {
    year <- max(dt_nuts3$YEAR, na.rm = TRUE)
  }
  dt_year <- dt_nuts3[YEAR == year]

  if (nrow(dt_year) == 0L) {
    warning(
      "No data for year ",
      year,
      ".",
      call. = FALSE
    )
    return(leaflet::leaflet() |> leaflet::addTiles())
  }

  # Join data to geometry
  geo_nuts3 <- geo[nchar(geo$NUTS_ID) == 5L, ]
  geo_data <- merge(
    geo_nuts3,
    as.data.frame(dt_year[, list(NUTSCODE, VALUE)]),
    by.x = "NUTS_ID",
    by.y = "NUTSCODE",
    all.x = TRUE
  )

  # Colour palette
  pal <- leaflet::colorNumeric(
    palette = "Blues",
    domain = geo_data$VALUE,
    na.color = "#cccccc"
  )

  # Popup text
  popup_text <- paste0(
    "<strong>",
    geo_data$NUTS_ID,
    "</strong>",
    "<br>",
    geo_data$NAME_LATN,
    "<br>",
    var_label,
    " (",
    year,
    "): ",
    scales::comma(geo_data$VALUE, accuracy = 0.01)
  )

  leaflet::leaflet(geo_data) |>
    leaflet::addTiles() |>
    leaflet::addPolygons(
      fillColor = ~ pal(VALUE),
      fillOpacity = 0.7,
      weight = 1,
      color = "#444444",
      popup = popup_text,
      highlightOptions = leaflet::highlightOptions(
        weight = 2,
        fillOpacity = 0.9,
        bringToFront = TRUE
      )
    )
}

# 6. DT summary table -----

#' Create an interactive wide-format data table.
#'
#' Pivots the data to wide format (one column per year) for comparison
#' across territories. Includes CSV and Excel export buttons.
#'
#' @param dt A data.table with columns NUTSCODE, YEAR, VALUE.
#' @param var_label Character. Italian label for the variable (used as caption).
#' @param unit_label Character. Italian label for the measurement unit.
#' @return A DT datatable object.
summary_dt <- function(dt, var_label, unit_label) {
  stopifnot(
    is.data.table(dt),
    is.character(var_label),
    length(var_label) == 1L,
    is.character(unit_label),
    length(unit_label) == 1L
  )

  # Keep NUTS-2 and NUTS-3 rows
  dt_sub <- dt[nchar(NUTSCODE) %in% c(4L, 5L)]

  if (nrow(dt_sub) == 0L) {
    warning("No NUTS-2/NUTS-3 data for table.", call. = FALSE)
    return(DT::datatable(data.frame(), caption = var_label))
  }

  # Select relevant columns and pivot wide
  dt_slim <- dt_sub[, list(NUTSCODE, YEAR, VALUE)]
  wide <- data.table::dcast(
    dt_slim,
    NUTSCODE ~ YEAR,
    value.var = "VALUE"
  )
  setorder(wide, NUTSCODE)

  # Year columns for formatting
  year_cols <- setdiff(names(wide), "NUTSCODE")

  caption_text <- paste0(var_label, " (", unit_label, ")")
  file_stem <- gsub("[^A-Za-z0-9_]", "_", var_label)

  DT::datatable(
    as.data.frame(wide),
    extensions = "Buttons",
    options = list(
      dom = "Bfrtip",
      buttons = list(
        list(extend = "csv", filename = file_stem),
        list(extend = "excel", filename = file_stem)
      ),
      scrollX = TRUE,
      pageLength = 20
    ),
    rownames = FALSE,
    caption = caption_text
  ) |>
    DT::formatRound(columns = year_cols, digits = 2)
}

# 7. Sector time-series plotly chart -----

#' Create a time-series chart for sector-disaggregated data.
#'
#' Aggregates province-level data by YEAR and SECTOR, maps sector codes to
#' Italian labels, and produces an interactive line chart.
#'
#' @param dt A data.table already filtered to a specific UNIT but containing
#'   all SECTOR values. Must have columns YEAR, SECTOR, VALUE.
#' @param var_label Character. Italian label for the variable.
#' @param unit_label Character. Italian label for the measurement unit.
#' @param labels Named list from load_labels(). Must contain a
#'   `sector_labels` element mapping sector codes to Italian names.
#' @return A plotly object.
ts_plotly_by_sector <- function(dt, var_label, unit_label, labels) {
  stopifnot(
    is.data.table(dt),
    is.character(var_label),
    length(var_label) == 1L,
    is.character(unit_label),
    length(unit_label) == 1L,
    is.list(labels),
    "sector_labels" %in% names(labels)
  )

  if (nrow(dt) == 0L || !"SECTOR" %in% names(dt)) {
    warning(
      "No sector data available for '",
      var_label,
      "'.",
      call. = FALSE
    )
    return(plotly::plotly_empty())
  }

  # Aggregate across provinces by year and sector
  agg <- dt[, list(VALUE = sum(VALUE, na.rm = TRUE)), by = list(YEAR, SECTOR)]

  if (nrow(agg) == 0L) {
    return(plotly::plotly_empty())
  }

  # Map sector codes to Italian labels via merge
  sector_map <- labels$sector_labels
  agg <- merge(
    agg,
    sector_map,
    by.x = "SECTOR",
    by.y = "code",
    all.x = TRUE
  )
  agg[is.na(label_it), label_it := SECTOR]
  setnames(agg, "label_it", "sector_label_it")

  setorder(agg, SECTOR, YEAR)

  # Build ggplot line chart
  p <- ggplot2::ggplot(
    as.data.frame(agg),
    ggplot2::aes(
      x = YEAR,
      y = VALUE,
      colour = sector_label_it
    )
  ) +
    ggplot2::geom_line(linewidth = 0.6) +
    ggplot2::labs(
      title = paste(var_label, "per settore"),
      x = NULL,
      y = unit_label,
      colour = "Settore"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  plotly::ggplotly(p, tooltip = c("x", "y", "colour"))
}

# 8. Variable metadata introspection -----

#' Return available dimensions for a data.table of ARDECO data.
#'
#' Inspects the columns of the supplied data.table and returns a named list
#' with the unique values of each dimension column that exists (UNIT, SEX,
#' AGE, SECTOR).
#'
#' @param dt A data.table loaded from an ARDECO parquet file.
#' @return A named list with elements `units` (always present), and
#'   optionally `sex`, `age`, `sector`.
get_var_dimensions <- function(dt) {
  stopifnot(is.data.table(dt))

  # Put "TOTAL" first so Shiny defaults to the aggregate value
  total_first <- function(vals) {
    if ("TOTAL" %in% vals) {
      c("TOTAL", sort(setdiff(vals, "TOTAL")))
    } else {
      sort(vals)
    }
  }

  dims <- list(units = total_first(unique(dt$UNIT)))
  if ("SEX" %in% names(dt)) {
    dims$sex <- total_first(unique(dt$SEX))
  }
  if ("AGE" %in% names(dt)) {
    dims$age <- total_first(unique(dt$AGE))
  }
  if ("SECTOR" %in% names(dt)) {
    dims$sector <- sort(unique(dt[!is.na(SECTOR), SECTOR]))
  }
  if ("ISCED11" %in% names(dt)) {
    dims$isced11 <- sort(unique(dt[!is.na(ISCED11), ISCED11]))
  }
  dims
}

# 9. Label helper functions -----

#' Restituisce l'etichetta italiana di una variabile ARDECO.
#'
#' @param code character(1) codice variabile (es. "SUVGD").
#' @param labels lista caricata da labels.rds.
#' @return character(1) etichetta italiana, oppure il codice stesso se non trovato.
get_var_label <- function(code, labels) {
  stopifnot(is.character(code), length(code) == 1L)
  row <- labels$var_labels[var_code == code]
  if (nrow(row) == 0L) {
    return(code)
  }
  row$label_it
}

#' Restituisce l'etichetta italiana di un'unità di misura ARDECO.
#'
#' @param code character(1) codice unità (es. "MIO_EUR").
#' @param labels lista caricata da labels.rds.
#' @return character(1) etichetta italiana, oppure il codice stesso se non trovato.
get_unit_label <- function(code, labels) {
  stopifnot(is.character(code), length(code) == 1L)
  idx <- match(code, labels$unit_labels$code)
  if (is.na(idx)) {
    return(code)
  }
  labels$unit_labels$label_it[idx]
}

#' Restituisce l'etichetta italiana per il sesso.
get_sex_label <- function(code, labels) {
  stopifnot(is.character(code), length(code) == 1L)
  idx <- match(code, labels$sex_labels$code)
  if (is.na(idx)) {
    return(code)
  }
  labels$sex_labels$label_it[idx]
}

#' Restituisce l'etichetta italiana per la classe di età.
get_age_label <- function(code, labels) {
  stopifnot(is.character(code), length(code) == 1L)
  idx <- match(code, labels$age_labels$code)
  if (is.na(idx)) {
    return(code)
  }
  labels$age_labels$label_it[idx]
}

#' Restituisce l'etichetta italiana per il settore NACE.
get_sector_label <- function(code, labels) {
  stopifnot(is.character(code), length(code) == 1L)
  idx <- match(code, labels$sector_labels$code)
  if (is.na(idx)) {
    return(code)
  }
  labels$sector_labels$label_it[idx]
}

#' Restituisce l'etichetta italiana per il livello di istruzione ISCED.
get_isced11_label <- function(code, labels) {
  stopifnot(is.character(code), length(code) == 1L)
  idx <- match(code, labels$isced11_labels$code)
  if (is.na(idx)) {
    return(code)
  }
  labels$isced11_labels$label_it[idx]
}
