# helpers_eu.R
# Funzioni di supporto specifiche per il dashboard comparatore cross-country.
# Leggono il database parallelo ../data/ardeco_eu.duckdb e la geometria
# ../data/eu_nuts2.gpkg. Il file helpers.R di produzione resta INVARIATO; queste
# funzioni sono aggiuntive. Tutte le operazioni dati usano data.table.

# 1. Librerie -----

library(data.table)
library(duckdb)
library(DBI)
library(sf)
library(plotly)
library(leaflet)
library(DT)
library(scales)

# 2. Connessione DuckDB comparatore -----

.eu_db_env <- new.env(parent = emptyenv())

#' Apre o recupera la connessione DuckDB comparatore (read-only).
get_eu_con <- function() {
  if (is.null(.eu_db_env$con) || !DBI::dbIsValid(.eu_db_env$con)) {
    db_path <- file.path("..", "data", "ardeco_eu.duckdb")
    if (!file.exists(db_path)) {
      stop(
        "Database comparatore non trovato: ",
        db_path,
        "\nEseguire prima R/comparatore/01_download_eu.R.",
        call. = FALSE
      )
    }
    .eu_db_env$con <- DBI::dbConnect(
      duckdb::duckdb(),
      dbdir = db_path,
      read_only = TRUE
    )
  }
  .eu_db_env$con
}

#' Chiude la connessione DuckDB comparatore.
close_eu_con <- function() {
  if (!is.null(.eu_db_env$con) && DBI::dbIsValid(.eu_db_env$con)) {
    DBI::dbDisconnect(.eu_db_env$con, shutdown = TRUE)
    .eu_db_env$con <- NULL
  }
}

# 3. Caricamento dati -----

#' Legge la geometria NUTS2 dei paesi europei coperti.
load_eu_geo <- function() {
  path <- file.path("..", "data", "eu_nuts2.gpkg")
  if (!file.exists(path)) {
    stop(
      "GeoPackage non trovato: ",
      path,
      "\nEseguire prima R/comparatore/02_download_geo_eu.R.",
      call. = FALSE
    )
  }
  sf::st_read(path, quiet = TRUE)
}

#' Elenco regioni (codice, nome, paese) ordinato per paese e nome.
load_region_names <- function(geo) {
  dt <- data.table(
    NUTSCODE = geo$NUTS_ID,
    NAME = geo$NAME_LATN,
    CNTR_CODE = geo$CNTR_CODE
  )
  setorder(dt, CNTR_CODE, NAME)
  dt
}

#' Metadati eu_meta come lista nominata.
load_eu_meta <- function() {
  con <- get_eu_con()
  m <- as.data.table(DBI::dbReadTable(con, "eu_meta"))
  setNames(as.list(m$value), m$key)
}

#' Etichette degli indicatori del lavoro (ordinate).
load_eu_indicator_labels <- function() {
  con <- get_eu_con()
  dt <- as.data.table(DBI::dbReadTable(con, "labour_indicator_labels"))
  setorder(dt, sort_order)
  dt
}

#' Serie di un indicatore del lavoro per le regioni selezionate (livello 2).
load_labour_indicators <- function(indicator, nutscodes) {
  con <- get_eu_con()
  ph <- paste(rep("?", length(nutscodes)), collapse = ", ")
  q <- sprintf(
    "SELECT NUTSCODE, CNTR_CODE, YEAR, VALUE, UNIT, label_it, direction
     FROM labour_indicators
     WHERE INDICATOR = ? AND LEVEL = 2 AND NUTSCODE IN (%s)",
    ph
  )
  d <- DBI::dbGetQuery(con, q, params = c(list(indicator), as.list(nutscodes)))
  as.data.table(d)
}

#' Distanze (ranking) da una regione di riferimento.
load_distances <- function(ref) {
  con <- get_eu_con()
  d <- DBI::dbGetQuery(
    con,
    "SELECT NBR_NUTSCODE, distance, rank FROM region_distances
     WHERE REF_NUTSCODE = ? ORDER BY rank",
    params = list(ref)
  )
  as.data.table(d)
}

#' Le feature che più contribuiscono alla distanza tra ref e un vicino.
load_feature_contrib <- function(ref, nbr, top_n = 3L) {
  con <- get_eu_con()
  d <- as.data.table(DBI::dbGetQuery(
    con,
    "SELECT c.FEATURE, c.gap, c.contrib, f.label_it
     FROM feature_contributions c
     LEFT JOIN feature_labels f ON c.FEATURE = f.FEATURE
     WHERE c.REF_NUTSCODE = ? AND c.NBR_NUTSCODE = ?
     ORDER BY c.contrib DESC LIMIT ?",
    params = list(ref, nbr, top_n)
  ))
  d
}

# 4. Bounding box dinamico -----

#' Riquadro che racchiude un sottoinsieme di regioni (per fitBounds leaflet).
bbox_for <- function(geo, nutscodes) {
  sub <- geo[geo$NUTS_ID %in% nutscodes, ]
  if (nrow(sub) == 0L) {
    sub <- geo
  }
  bb <- sf::st_bbox(sub)
  list(
    lng1 = unname(bb["xmin"]),
    lat1 = unname(bb["ymin"]),
    lng2 = unname(bb["xmax"]),
    lat2 = unname(bb["ymax"])
  )
}

# 5. Mappa di selezione -----

#' Mappa NUTS2 europea con evidenziazione di riferimento e selezione.
#'
#' I poligoni hanno layerId = NUTS_ID, così il click restituisce il codice
#' regione e il dashboard può aggiungere/togliere la regione dalla selezione.
map_eu_selection <- function(geo, ref, selected) {
  selected <- setdiff(selected, ref)
  role <- ifelse(
    geo$NUTS_ID == ref,
    "Riferimento",
    ifelse(geo$NUTS_ID %in% selected, "Selezionata", "Altra")
  )
  fill <- ifelse(
    role == "Riferimento",
    "#D55E00",
    ifelse(role == "Selezionata", "#0072B2", "#E8E8E8")
  )
  bweight <- ifelse(
    role == "Riferimento",
    2.5,
    ifelse(role == "Selezionata", 1.5, 0.4)
  )
  bcolor <- ifelse(role == "Altra", "#999999", "#333333")

  popup <- paste0(
    "<strong>",
    geo$NAME_LATN,
    "</strong><br>",
    geo$NUTS_ID,
    " (",
    geo$CNTR_CODE,
    ")<br>",
    "<em>",
    role,
    "</em>"
  )

  b <- bbox_for(geo, unique(c(ref, selected)))

  # Ricalcola dimensioni e riadatta i confini dopo il render (il contenitore
  # flexdashboard può non avere dimensioni definite al primo disegno).
  js_fit <- sprintf(
    "function(el, x) {
      var m = this;
      setTimeout(function() {
        m.invalidateSize();
        m.fitBounds([[%f, %f], [%f, %f]], {padding: [20, 20]});
      }, 250);
    }",
    b$lat1,
    b$lng1,
    b$lat2,
    b$lng2
  )

  leaflet::leaflet(geo) |>
    leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron) |>
    leaflet::addPolygons(
      layerId = ~NUTS_ID,
      fillColor = fill,
      fillOpacity = 0.75,
      weight = bweight,
      color = bcolor,
      popup = popup,
      highlightOptions = leaflet::highlightOptions(
        weight = 3,
        fillOpacity = 0.9,
        bringToFront = TRUE
      )
    ) |>
    leaflet::addLegend(
      position = "bottomright",
      colors = c("#D55E00", "#0072B2", "#E8E8E8"),
      labels = c("Riferimento", "Selezionata", "Altra"),
      opacity = 0.8
    ) |>
    leaflet::fitBounds(b$lng1, b$lat1, b$lng2, b$lat2) |>
    htmlwidgets::onRender(js_fit)
}

# 6. Grafico di confronto multi-regione -----

# Palette CVD-safe (Paul Tol Muted + Okabe-Ito)
.cvd_palette <- c(
  "#332288",
  "#117733",
  "#CC6677",
  "#DDCC77",
  "#88CCEE",
  "#882255",
  "#44AA99",
  "#999933",
  "#AA4499",
  "#E69F00",
  "#56B4E9",
  "#D55E00"
)
.cvd_dashes <- rep(c("solid", "dash", "dot", "dashdot"), length.out = 12L)

#' Serie storica di confronto: una linea per regione, riferimento in nero.
ts_plotly_compare <- function(dt, ind_label, unit_label, ref, geo) {
  if (nrow(dt) == 0L) {
    return(plotly::plotly_empty())
  }
  name_lookup <- setNames(geo$NAME_LATN, geo$NUTS_ID)
  lookup <- function(code) {
    nm <- name_lookup[code]
    if (is.na(nm)) code else nm
  }

  others <- sort(setdiff(unique(dt$NUTSCODE), ref))
  fig <- plotly::plot_ly()

  # Riferimento: linea nera spessa
  ref_data <- dt[NUTSCODE == ref]
  if (nrow(ref_data) > 0L) {
    setorder(ref_data, YEAR)
    fig <- fig |>
      plotly::add_trace(
        data = as.data.frame(ref_data),
        x = ~YEAR,
        y = ~VALUE,
        type = "scatter",
        mode = "lines",
        name = paste0(lookup(ref), " (rif.)"),
        line = list(width = 3.5, color = "#000000"),
        hovertemplate = paste0(
          lookup(ref),
          "<br>%{x}: %{y:,.1f}<extra></extra>"
        )
      )
  }

  for (i in seq_along(others)) {
    code <- others[i]
    d <- dt[NUTSCODE == code]
    if (nrow(d) == 0L) {
      next
    }
    setorder(d, YEAR)
    fig <- fig |>
      plotly::add_trace(
        data = as.data.frame(d),
        x = ~YEAR,
        y = ~VALUE,
        type = "scatter",
        mode = "lines",
        name = lookup(code),
        line = list(
          width = 2,
          color = .cvd_palette[(i - 1L) %% length(.cvd_palette) + 1L],
          dash = .cvd_dashes[(i - 1L) %% length(.cvd_dashes) + 1L]
        ),
        hovertemplate = paste0(
          lookup(code),
          "<br>%{x}: %{y:,.1f}<extra></extra>"
        )
      )
  }

  fig |>
    plotly::layout(
      title = list(text = ind_label, x = 0.05),
      xaxis = list(title = ""),
      yaxis = list(title = unit_label),
      legend = list(orientation = "h", y = -0.15)
    )
}

# 7. Barre ultimo anno -----

#' Barre orizzontali del valore all'ultimo anno comune, riferimento evidenziato.
bar_eu_latest <- function(dt, ind_label, unit_label, ref, geo) {
  if (nrow(dt) == 0L) {
    return(plotly::plotly_empty())
  }
  # Ultimo anno con dati per tutte le regioni presenti
  yr_cov <- dt[, list(n = uniqueN(NUTSCODE)), by = YEAR]
  target_year <- yr_cov[n == max(n), max(YEAR)]
  d <- dt[YEAR == target_year]
  if (nrow(d) == 0L) {
    return(plotly::plotly_empty())
  }

  name_lookup <- setNames(geo$NAME_LATN, geo$NUTS_ID)
  d[,
    region := vapply(
      NUTSCODE,
      function(c) {
        nm <- name_lookup[c]
        if (is.na(nm)) c else nm
      },
      character(1)
    )
  ]
  setorder(d, VALUE)
  d[, region := factor(region, levels = region)]
  d[, is_ref := NUTSCODE == ref]
  bar_col <- ifelse(d$is_ref, "#000000", "#0072B2")

  plotly::plot_ly(
    data = as.data.frame(d),
    x = ~VALUE,
    y = ~region,
    type = "bar",
    orientation = "h",
    marker = list(color = bar_col),
    hovertemplate = paste0(
      "%{y}<br>",
      target_year,
      ": %{x:,.1f}<extra></extra>"
    )
  ) |>
    plotly::layout(
      title = list(text = paste0(ind_label, " (", target_year, ")"), x = 0.05),
      xaxis = list(title = unit_label),
      yaxis = list(title = "")
    )
}

# 8. Profilo strutturale delle aree (pagina 1) -----

# Ordine tematico delle feature: composizione VA settoriale, demografia,
# taglia/densità/capitale. Coerente con feature_cols di 04_build_profiles.R.
.feature_order <- c(
  "clr_A",
  "clr_BE",
  "clr_F",
  "clr_GJ",
  "clr_K",
  "clr_L",
  "clr_MN",
  "clr_OQ",
  "clr_RU",
  "dep_ratio",
  "net_migr",
  "pop_change",
  "share_1564",
  "log_pop",
  "log_density",
  "log_invest_pc"
)

# Palette diverging CVD-safe per lo scostamento standardizzato rispetto al
# riferimento: blu = inferiore, neutro = simile, arancio = superiore.
.zgap_breaks <- c(-2, -1, -0.4, 0.4, 1, 2)
.zgap_bg <- c(
  "#0072B2",
  "#6BAED6",
  "#D6E6F0",
  "#FFFFFF",
  "#FBE3C2",
  "#E69F00",
  "#D55E00"
)
.zgap_txt_breaks <- c(-2, 2)
.zgap_txt <- c("#FFFFFF", "#222222", "#FFFFFF")

#' Costruisce la tabella di confronto strutturale per la pagina di selezione.
#'
#' Una riga per feature (etichetta italiana), una colonna di valori grezzi per
#' ciascuna area (riferimento + selezionate) e, affiancata, una colonna nascosta
#' con lo scostamento standardizzato (z) rispetto al riferimento — la stessa
#' quantità che determina la distanza di similarità — usata per colorare le celle.
#'
#' @return list(df, value_cols, z_cols, ref_col) oppure NULL se non ci sono dati.
build_feature_table <- function(ref, regions, geo) {
  con <- get_eu_con()
  codes <- unique(c(ref, regions))
  ph <- paste(rep("?", length(codes)), collapse = ", ")
  q <- sprintf(
    "SELECT l.NUTSCODE, l.FEATURE, l.value_raw, l.value_z, f.label_it
     FROM region_features_long l
     LEFT JOIN feature_labels f ON l.FEATURE = f.FEATURE
     WHERE l.NUTSCODE IN (%s)",
    ph
  )
  d <- as.data.table(DBI::dbGetQuery(con, q, params = as.list(codes)))
  if (nrow(d) == 0L) {
    return(NULL)
  }

  # Scostamento z rispetto al riferimento (= gap usato nella distanza)
  ref_z <- d[NUTSCODE == ref, list(FEATURE, ref_z = value_z)]
  d <- merge(d, ref_z, by = "FEATURE", all.x = TRUE)
  d[, zgap := value_z - ref_z]

  # Ordine tematico delle feature
  d[, ord := match(FEATURE, .feature_order)]
  d[is.na(ord), ord := 999L]
  feats <- unique(d[order(ord)][, list(FEATURE, label_it)])

  # Etichetta colonna = nome regione (codice NUTS come fallback)
  name_lookup <- setNames(geo$NAME_LATN, geo$NUTS_ID)
  col_label <- function(code) {
    nm <- name_lookup[code]
    lbl <- if (is.na(nm)) code else unname(nm)
    if (code == ref) paste0(lbl, " (rif.)") else lbl
  }

  out <- data.frame(Indicatore = feats$label_it, stringsAsFactors = FALSE)
  value_cols <- character(0)
  z_cols <- character(0)
  for (code in codes) {
    sub <- d[NUTSCODE == code]
    idx <- match(feats$FEATURE, sub$FEATURE)
    vname <- col_label(code)
    if (vname %in% names(out)) {
      vname <- paste0(vname, " ", code)
    }
    zname <- paste0(vname, "__z")
    out[[vname]] <- round(sub$value_raw[idx], 2)
    out[[zname]] <- sub$zgap[idx]
    value_cols <- c(value_cols, vname)
    z_cols <- c(z_cols, zname)
  }

  list(
    df = out,
    value_cols = value_cols,
    z_cols = z_cols,
    ref_col = col_label(ref)
  )
}

#' Applica la colorazione condizionale (sfondo per scostamento z) alla tabella.
style_feature_table <- function(dtable, value_cols, z_cols) {
  for (i in seq_along(value_cols)) {
    dtable <- DT::formatStyle(
      dtable,
      columns = value_cols[i],
      valueColumns = z_cols[i],
      backgroundColor = DT::styleInterval(.zgap_breaks, .zgap_bg),
      color = DT::styleInterval(.zgap_txt_breaks, .zgap_txt)
    )
  }
  dtable
}
