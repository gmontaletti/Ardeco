# ==============================================================================
# 02_export_to_postgres.R
# Esporta tutte le tabelle dal database DuckDB locale a PostgreSQL.
# Input:  data/ardeco.duckdb
# Output: schema ardeco su PostgreSQL (credenziali da .Renviron)
# ==============================================================================

# 1. Configurazione -----

library(DBI)
library(duckdb)
library(RPostgres)
library(data.table)

db_path <- here::here("data", "ardeco.duckdb")

tables_to_export <- c(
  "ardeco_data",
  "var_labels",
  "unit_labels",
  "sex_labels",
  "age_labels",
  "sector_labels",
  "group_labels",
  "download_log",
  "variable_list"
)

# 2. Connessione DuckDB (lettura) -----

duck_con <- dbConnect(duckdb(), dbdir = db_path, read_only = TRUE)

on.exit(
  {
    if (dbIsValid(duck_con)) dbDisconnect(duck_con, shutdown = TRUE)
  },
  add = TRUE
)

message("Connessione DuckDB aperta: ", db_path)

# 3. Connessione PostgreSQL (scrittura) -----

pg_con <- dbConnect(
  RPostgres::Postgres(),
  host = Sys.getenv("PG_HOST"),
  port = as.integer(Sys.getenv("PG_PORT")),
  dbname = Sys.getenv("PG_DBNAME"),
  user = Sys.getenv("PG_USER"),
  password = Sys.getenv("PG_PASSWORD")
)

on.exit(
  {
    if (dbIsValid(pg_con)) dbDisconnect(pg_con)
  },
  add = TRUE
)

message(
  "Connessione PostgreSQL aperta: ",
  Sys.getenv("PG_HOST"),
  ":",
  Sys.getenv("PG_PORT"),
  "/",
  Sys.getenv("PG_DBNAME")
)

# 4. Creazione schema -----

dbExecute(pg_con, "CREATE SCHEMA IF NOT EXISTS ardeco")
message("Schema 'ardeco' verificato/creato")

# 5. Esportazione tabelle -----

message("\nEsportazione di ", length(tables_to_export), " tabelle:\n")

for (tbl in tables_to_export) {
  dt <- as.data.table(dbReadTable(duck_con, tbl))
  dbWriteTable(
    pg_con,
    DBI::Id(schema = "ardeco", table = tbl),
    dt,
    overwrite = TRUE
  )
  message(sprintf("  %s: %d righe", tbl, nrow(dt)))
}

message("\nTutte le tabelle esportate con successo")

# 6. Creazione indici -----

dbExecute(
  pg_con,
  "
  CREATE INDEX IF NOT EXISTS idx_ardeco_variable
  ON ardeco.ardeco_data (\"VARIABLE\")
"
)

dbExecute(
  pg_con,
  "
  CREATE INDEX IF NOT EXISTS idx_ardeco_nuts_year
  ON ardeco.ardeco_data (\"NUTSCODE\", \"YEAR\")
"
)

message("Indici creati su ardeco.ardeco_data (variable, nutscode+year)")

# 7. Verifica -----

message("\nVerifica conteggio righe:\n")

results <- data.table(
  tabella = character(length(tables_to_export)),
  duck_righe = integer(length(tables_to_export)),
  pg_righe = integer(length(tables_to_export)),
  esito = character(length(tables_to_export))
)

for (i in seq_along(tables_to_export)) {
  tbl <- tables_to_export[i]

  n_duck <- dbGetQuery(
    duck_con,
    sprintf("SELECT COUNT(*) AS n FROM %s", tbl)
  )$n

  n_pg <- dbGetQuery(
    pg_con,
    sprintf("SELECT COUNT(*) AS n FROM ardeco.%s", tbl)
  )$n

  esito <- if (n_duck == n_pg) "OK" else "ERRORE"

  set(results, i, "tabella", tbl)
  set(results, i, "duck_righe", as.integer(n_duck))
  set(results, i, "pg_righe", as.integer(n_pg))
  set(results, i, "esito", esito)
}

for (i in seq_len(nrow(results))) {
  row <- results[i]
  message(sprintf(
    "  %-20s | DuckDB: %7d | PG: %7d | %s",
    row$tabella,
    row$duck_righe,
    row$pg_righe,
    row$esito
  ))
}

n_ok <- results[esito == "OK", .N]
n_err <- results[esito == "ERRORE", .N]

if (n_err == 0L) {
  message(sprintf(
    "\nVerifica completata: tutte le %d tabelle corrispondono.",
    n_ok
  ))
} else {
  warning(sprintf(
    "Verifica completata: %d tabelle OK, %d con errori.",
    n_ok,
    n_err
  ))
}

# 8. Chiusura connessioni -----

dbDisconnect(duck_con, shutdown = TRUE)
dbDisconnect(pg_con)

message("Esportazione completata.")
