# ==============================================================================
# 03_labour_indicators.R
# Calcola gli indicatori del mercato del lavoro COMPARABILI cross-country
# (solo rapporti / serie normalizzate, mai livelli assoluti) e li archivia in
# forma tidy long nel database comparatore.
# Output: tabelle labour_indicators e labour_indicator_labels in ardeco_eu.duckdb
# Uso: Rscript R/comparatore/03_labour_indicators.R
#
# Nota metodologica: questo insieme di variabili e' DISGIUNTO da quello usato
# per la similarita' (04_build_profiles.R) per evitare circolarita'.
# ==============================================================================

# 1. Config -----

source("R/comparatore/00_config_eu.R")

con <- dbConnect(duckdb(), dbdir = EU_DB_PATH, read_only = FALSE)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

# 2. Helper: estrazione slice con unità a priorità -----

#' Fattore di scala verso l'unità base (persone, ore, euro/PPS).
unit_scale <- function(u) {
  if (length(u) == 0L || is.na(u)) {
    return(1)
  }
  if (grepl("^MIO", u)) {
    return(1e6)
  }
  if (grepl("^THS", u)) {
    return(1e3)
  }
  1
}

#' Estrae (NUTSCODE, YEAR, VALUE, UNIT) per una variabile, scegliendo la prima
#' unità disponibile tra quelle candidate. Filtra ai totali dimensionali e ai
#' livelli 0 (paese) e 2 (regioni).
get_slice <- function(con, var, units) {
  for (u in units) {
    d <- dbGetQuery(
      con,
      "
      SELECT NUTSCODE, YEAR, VALUE, UNIT, LEVEL
      FROM ardeco_data
      WHERE VARIABLE = ? AND UNIT = ? AND LEVEL IN (0, 2)
        AND (SEX IS NULL OR SEX = 'TOTAL')
        AND (AGE IS NULL OR AGE = 'TOTAL')
        AND SECTOR IS NULL
      ",
      params = list(var, u)
    )
    if (nrow(d) > 0L) {
      dt <- as.data.table(d)
      # difesa: una riga per (NUTSCODE, YEAR)
      setorder(dt, NUTSCODE, YEAR)
      dt <- dt[, .SD[1L], by = list(NUTSCODE, YEAR)]
      message(sprintf("  %-7s -> unità '%s' (%d righe)", var, u, nrow(dt)))
      return(dt)
    }
  }
  message(sprintf(
    "  %-7s -> NESSUNA unità tra: %s",
    var,
    paste(units, collapse = ", ")
  ))
  NULL
}

# 3. Specifiche indicatori diretti -----

direct_specs <- list(
  list(
    id = "tasso_occupazione",
    label = "Tasso di occupazione (20-64)",
    var = "RPECNP",
    units = "PC",
    unit_label = "%",
    is_rate = TRUE,
    direction = 1L,
    group = "Occupazione"
  ),
  list(
    id = "tasso_disoccupazione",
    label = "Tasso di disoccupazione (15-74)",
    var = "RPUCNP",
    units = "PC",
    unit_label = "%",
    is_rate = TRUE,
    direction = -1L,
    group = "Occupazione"
  ),
  list(
    id = "produttivita_occupato_reale",
    label = "Produttività per occupato (reale)",
    var = "SOVGDE",
    units = c("EUR2015", "EUR_HAB2015", "EUR"),
    unit_label = "euro (prezzi 2015) per occupato",
    is_rate = FALSE,
    direction = 1L,
    group = "Produttività"
  ),
  list(
    id = "produttivita_ora_reale",
    label = "Produttività per ora (reale)",
    var = "SOVGDH",
    units = c("EUR2015", "EUR"),
    unit_label = "euro (prezzi 2015) per ora",
    is_rate = FALSE,
    direction = 1L,
    group = "Produttività"
  ),
  list(
    id = "pil_procapite_pps",
    label = "PIL pro capite (PPS)",
    var = "SUVGDP",
    units = c("PPS_HAB", "PPS_EU27_2020"),
    unit_label = "PPS per abitante",
    is_rate = FALSE,
    direction = 1L,
    group = "Reddito"
  ),
  list(
    id = "pil_procapite_reale",
    label = "PIL pro capite (reale)",
    var = "SOVGDP",
    units = c("EUR_HAB2015", "EUR2015"),
    unit_label = "euro (prezzi 2015) per abitante",
    is_rate = FALSE,
    direction = 1L,
    group = "Reddito"
  ),
  list(
    id = "compenso_ora_reale",
    label = "Compenso reale per ora",
    var = "ROWCDH",
    units = c("EUR2015", "EUR2020", "EUR"),
    unit_label = "euro (prezzi 2015) per ora",
    is_rate = FALSE,
    direction = 1L,
    group = "Reddito"
  )
)

# 4. Specifiche indicatori derivati -----

derived_specs <- list(
  list(
    id = "produttivita_occupato_pps",
    label = "Produttività per occupato (PPS)",
    num_var = "SUVGD",
    num_units = "MIO_PPS_EU27_2020",
    den_var = "SNETD",
    den_units = c("THS", "NR"),
    mult = 1,
    unit_label = "PPS per occupato",
    is_rate = FALSE,
    direction = 1L,
    group = "Produttività"
  ),
  list(
    id = "quota_dipendenti",
    label = "Quota dipendenti su occupati",
    num_var = "SNWTD",
    num_units = c("THS", "NR"),
    den_var = "SNETD",
    den_units = c("THS", "NR"),
    mult = 100,
    unit_label = "%",
    is_rate = TRUE,
    direction = 0L,
    group = "Struttura occupazione"
  ),
  list(
    id = "ore_per_occupato",
    label = "Ore lavorate per occupato",
    num_var = "RNLHT",
    num_units = c("THS_HW", "THS"),
    den_var = "SNETD",
    den_units = c("THS", "NR"),
    mult = 1,
    unit_label = "ore per anno",
    is_rate = FALSE,
    direction = 0L,
    group = "Struttura occupazione"
  )
)

# 5. Costruzione indicatori diretti -----

message("== Indicatori diretti ==")
direct_dt <- rbindlist(
  lapply(direct_specs, function(s) {
    sl <- get_slice(con, s$var, s$units)
    if (is.null(sl)) {
      return(NULL)
    }
    sl[, list(
      NUTSCODE,
      LEVEL,
      YEAR,
      INDICATOR = s$id,
      VALUE,
      UNIT = s$unit_label,
      label_it = s$label,
      is_rate = s$is_rate,
      direction = s$direction,
      ind_group = s$group
    )]
  }),
  use.names = TRUE
)

# 6. Costruzione indicatori derivati -----

message("\n== Indicatori derivati ==")
derived_dt <- rbindlist(
  lapply(derived_specs, function(s) {
    num <- get_slice(con, s$num_var, s$num_units)
    den <- get_slice(con, s$den_var, s$den_units)
    if (is.null(num) || is.null(den)) {
      return(NULL)
    }
    num[, base_num := VALUE * unit_scale(UNIT[1L])]
    den[, base_den := VALUE * unit_scale(UNIT[1L])]
    m <- merge(
      num[, list(NUTSCODE, LEVEL, YEAR, base_num)],
      den[, list(NUTSCODE, YEAR, base_den)],
      by = c("NUTSCODE", "YEAR")
    )
    m <- m[is.finite(base_num) & is.finite(base_den) & base_den != 0]
    m[, list(
      NUTSCODE,
      LEVEL,
      YEAR,
      INDICATOR = s$id,
      VALUE = base_num / base_den * s$mult,
      UNIT = s$unit_label,
      label_it = s$label,
      is_rate = s$is_rate,
      direction = s$direction,
      ind_group = s$group
    )]
  }),
  use.names = TRUE
)

# 7. Unione e scrittura -----

labour <- rbindlist(list(direct_dt, derived_dt), use.names = TRUE)
labour[, CNTR_CODE := substr(NUTSCODE, 1, 2)]
setcolorder(
  labour,
  c(
    "NUTSCODE",
    "CNTR_CODE",
    "LEVEL",
    "YEAR",
    "INDICATOR",
    "VALUE",
    "UNIT",
    "label_it",
    "is_rate",
    "direction",
    "ind_group"
  )
)
setorder(labour, INDICATOR, NUTSCODE, YEAR)

dbWriteTable(con, "labour_indicators", labour, overwrite = TRUE)

# Tabella etichette indicatori (un record per indicatore)
ind_labels <- unique(labour[, list(
  INDICATOR,
  label_it,
  unit_label = UNIT,
  is_rate,
  direction,
  ind_group
)])
all_specs <- c(direct_specs, derived_specs)
sort_order <- data.table(
  INDICATOR = vapply(all_specs, function(s) s$id, character(1)),
  sort_order = seq_along(all_specs)
)
ind_labels <- merge(ind_labels, sort_order, by = "INDICATOR")
setorder(ind_labels, sort_order)
dbWriteTable(con, "labour_indicator_labels", ind_labels, overwrite = TRUE)

# 8. Riepilogo -----

message("\n========== Indicatori del lavoro ==========")
summ <- labour[
  LEVEL == 2L,
  list(
    n_regioni = uniqueN(NUTSCODE),
    anno_min = min(YEAR),
    anno_max = max(YEAR),
    paesi = uniqueN(CNTR_CODE)
  ),
  by = INDICATOR
]
summ <- merge(summ, sort_order, by = "INDICATOR")
setorder(summ, sort_order)
print(summ[, !"sort_order"])

message(sprintf(
  "\nScritte %d righe (%d indicatori) in labour_indicators.",
  nrow(labour),
  uniqueN(labour$INDICATOR)
))
