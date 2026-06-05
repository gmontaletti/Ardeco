# ==============================================================================
# 01_download_eu.R
# Scarica le 57 variabili ARDECO per tutte le regioni NUTS2 (livello 2) e gli
# aggregati paese (livello 0) di IT, DE, FR, PL, ES, archiviandole in un database
# DuckDB parallelo a quello di produzione.
# Output: data/ardeco_eu.duckdb
# Uso: Rscript R/comparatore/01_download_eu.R
# ==============================================================================

# 1. Config -----

source("R/comparatore/00_config_eu.R")

EU_OBS_CUTOFF <- 2024L # ultimo anno considerato "osservato" (esclude previsioni)

# 2. Inizializzazione DuckDB -----

if (file.exists(EU_DB_PATH)) {
  file.remove(EU_DB_PATH)
  message("Rimosso database esistente: ", EU_DB_PATH)
}
if (file.exists(paste0(EU_DB_PATH, ".wal"))) {
  file.remove(paste0(EU_DB_PATH, ".wal"))
}

con <- dbConnect(duckdb(), dbdir = EU_DB_PATH)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

dbExecute(
  con,
  "
  CREATE TABLE ardeco_data (
    VARIABLE       VARCHAR NOT NULL,
    VERSIONS       INTEGER,
    LEVEL          INTEGER,
    NUTSCODE       VARCHAR NOT NULL,
    YEAR           INTEGER NOT NULL,
    UNIT           VARCHAR,
    VALUE          DOUBLE,
    SEX            VARCHAR,
    AGE            VARCHAR,
    SECTOR         VARCHAR,
    ISCED11        VARCHAR,
    THEMATIC_GROUP VARCHAR NOT NULL
  )
"
)

variable_list <- as.data.table(ardeco_get_variable_list())
dbWriteTable(con, "variable_list", variable_list, overwrite = TRUE)
message("Tabella variable_list: ", nrow(variable_list), " righe")

# 3. Loop principale -----

message(
  "\nDownload di ",
  length(all_vars),
  " variabili per ",
  EU_NUTSCODE,
  "\n"
)

summary_log <- data.table(
  var_code = character(length(all_vars)),
  group = character(length(all_vars)),
  n_rows = integer(length(all_vars)),
  status = character(length(all_vars)),
  elapsed_sec = numeric(length(all_vars))
)

t0_total <- proc.time()

for (i in seq_along(all_vars)) {
  vc <- all_vars[i]
  gn <- var_to_group[vc]
  message(sprintf("[%2d/%d] %s (%s)", i, length(all_vars), vc, gn))

  t0 <- proc.time()
  dt <- download_variable(
    vc,
    nutscode = EU_NUTSCODE,
    level = EU_LEVEL,
    version = EU_VERSION,
    timeout_sec = 600
  )
  elapsed <- (proc.time() - t0)[["elapsed"]]

  if (!is.null(dt)) {
    dbWriteTable(con, "ardeco_data", dt, append = TRUE)
    message(sprintf("  Inserite %d righe (%.1fs)", nrow(dt), elapsed))
    set(summary_log, i, "status", "OK")
    set(summary_log, i, "n_rows", nrow(dt))
  } else {
    set(summary_log, i, "status", "FAILED")
    set(summary_log, i, "n_rows", 0L)
  }
  set(summary_log, i, "var_code", vc)
  set(summary_log, i, "group", gn)
  set(summary_log, i, "elapsed_sec", elapsed)
}

# Rimozione combinazioni invarianti tra territori (coerente con produzione)
n_del <- dbExecute(
  con,
  "DELETE FROM ardeco_data WHERE VARIABLE = 'ROWCDH' AND UNIT = 'EUR2020'"
)
message(sprintf("Rimossi %d record invarianti (ROWCDH EUR2020)", n_del))

# 4. Indici -----

dbExecute(con, "CREATE INDEX idx_variable ON ardeco_data (VARIABLE)")
dbExecute(con, "CREATE INDEX idx_nuts_year ON ardeco_data (NUTSCODE, YEAR)")

# 5. Tabelle etichette + log -----

dbWriteTable(con, "var_labels", var_labels, overwrite = TRUE)
dbWriteTable(con, "unit_labels", unit_labels, overwrite = TRUE)
dbWriteTable(con, "sex_labels", sex_labels, overwrite = TRUE)
dbWriteTable(con, "age_labels", age_labels, overwrite = TRUE)
dbWriteTable(con, "sector_labels", sector_labels, overwrite = TRUE)
dbWriteTable(con, "group_labels", group_labels, overwrite = TRUE)
dbWriteTable(con, "download_log", summary_log, overwrite = TRUE)

# 6. Copertura per paese -----

# Conteggio regioni NUTS2 distinte per (variabile, paese), in forma long: con
# molti paesi una tabella wide a colonne fisse non è praticabile.
coverage <- as.data.table(dbGetQuery(
  con,
  "
  SELECT VARIABLE,
         substr(NUTSCODE, 1, 2) AS CNTR_CODE,
         COUNT(DISTINCT NUTSCODE) AS n_regioni
  FROM ardeco_data
  WHERE LEVEL = 2
  GROUP BY VARIABLE, substr(NUTSCODE, 1, 2)
  ORDER BY VARIABLE, CNTR_CODE
"
))
dbWriteTable(con, "eu_coverage", coverage, overwrite = TRUE)

# 7. Anni di riferimento (esclude previsioni) -----

#' Ultimo anno (<= cutoff) con copertura adeguata per un set di variabili.
#'
#' Con paesi a copertura disomogenea non si può richiedere la presenza di TUTTI
#' i paesi. Per ciascuna variabile si prende l'anno in cui il numero di regioni
#' con dati è almeno `min_frac` del massimo storico della variabile; poi si
#' interseca tra variabili e si prende il massimo.
latest_year_covered <- function(con, vars, cutoff, min_frac = 0.8) {
  qualifying <- NULL
  for (v in vars) {
    yrs <- as.data.table(dbGetQuery(
      con,
      "
      SELECT YEAR, COUNT(DISTINCT NUTSCODE) AS nr
      FROM ardeco_data
      WHERE VARIABLE = ? AND LEVEL = 2 AND YEAR <= ?
      GROUP BY YEAR
      ",
      params = list(v, cutoff)
    ))
    if (nrow(yrs) == 0L) {
      next
    }
    yrs_ok <- yrs[nr >= min_frac * max(nr), YEAR]
    if (length(yrs_ok) == 0L) {
      next
    }
    qualifying <- if (is.null(qualifying)) {
      yrs_ok
    } else {
      intersect(qualifying, yrs_ok)
    }
  }
  if (is.null(qualifying) || length(qualifying) == 0L) {
    return(NA_integer_)
  }
  max(qualifying)
}

sim_vars <- c("SUVGZ", "SPPAN", "SNPTD", "RUIGT", "SNMTNP", "SNPCNP", "SNPTN")
lab_vars <- c("RPECNP", "RPUCNP", "SOVGDE", "SOVGDP", "SNETD", "SNWTD", "RNLHT")

year_ref <- latest_year_covered(con, sim_vars, EU_OBS_CUTOFF)
year_latest_obs <- latest_year_covered(con, lab_vars, EU_OBS_CUTOFF)

# nota: 'key' è un argomento riservato di data.table(); si crea con un nome
# temporaneo e si rinomina in 'key' (colonna letta dal dashboard).
eu_meta <- data.table(
  metric = c("YEAR_REF", "YEAR_LATEST_OBS", "OBS_CUTOFF", "N_COUNTRIES"),
  value = c(year_ref, year_latest_obs, EU_OBS_CUTOFF, length(EU_COUNTRIES))
)
setnames(eu_meta, "metric", "key")
dbWriteTable(con, "eu_meta", eu_meta, overwrite = TRUE)

# 8. Riepilogo -----

message("\n========== Riepilogo download ==========")
n_ok <- summary_log[status == "OK", .N]
n_failed <- summary_log[status == "FAILED", .N]
message(sprintf(
  "Totale: %d OK, %d FALLITE su %d variabili.",
  n_ok,
  n_failed,
  nrow(summary_log)
))
if (n_failed > 0L) {
  message(
    "Variabili fallite: ",
    paste(summary_log[status == "FAILED", var_code], collapse = ", ")
  )
}

# Sintesi copertura: numero massimo di regioni NUTS2 per paese
cov_summary <- coverage[, list(max_regioni = max(n_regioni)), by = CNTR_CODE]
setorder(cov_summary, -max_regioni)
message("\nRegioni NUTS2 per paese (max tra le variabili):")
print(cov_summary)

row_count <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM ardeco_data")$n
var_count <- dbGetQuery(
  con,
  "SELECT COUNT(DISTINCT VARIABLE) AS n FROM ardeco_data"
)$n
nuts2_count <- dbGetQuery(
  con,
  "SELECT COUNT(DISTINCT NUTSCODE) AS n FROM ardeco_data WHERE LEVEL = 2"
)$n

message(sprintf("\nDuckDB: %s", EU_DB_PATH))
message(sprintf(
  "  ardeco_data: %d righe, %d variabili, %d regioni NUTS2",
  row_count,
  var_count,
  nuts2_count
))
message(sprintf("  YEAR_REF (similarità): %s", year_ref))
message(sprintf("  YEAR_LATEST_OBS (lavoro): %s", year_latest_obs))
message(sprintf("  Dimensione file: %.1f MB", file.size(EU_DB_PATH) / 1e6))

total_elapsed <- (proc.time() - t0_total)[["elapsed"]]
message(sprintf(
  "  Tempo totale: %.0f secondi (%.1f minuti)",
  total_elapsed,
  total_elapsed / 60
))
