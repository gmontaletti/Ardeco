# ==============================================================================
# 03_export_to_excel.R
# Esporta tutte le tabelle dal database DuckDB locale a un file Excel.
# Input:  data/ardeco.duckdb
# Output: output/ardeco_export.xlsx
# ==============================================================================

# 1. Configurazione -----

library(DBI)
library(duckdb)
library(data.table)
library(openxlsx2)

db_path <- here::here("data", "ardeco.duckdb")
out_dir <- here::here("output")
out_file <- file.path(out_dir, "ardeco_export.xlsx")

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

# 3. Esportazione -----

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
  message("Directory creata: ", out_dir)
}

wb <- wb_workbook()

message("\nEsportazione di ", length(tables_to_export), " tabelle:\n")

for (tbl in tables_to_export) {
  dt <- as.data.table(dbReadTable(duck_con, tbl))
  wb$add_worksheet(sheet = tbl)
  wb$add_data(sheet = tbl, x = dt)
  message(sprintf("  %-20s %7d righe", tbl, nrow(dt)))
}

wb$save(out_file)

message("\nFile Excel salvato: ", out_file)

# 4. Chiusura -----

dbDisconnect(duck_con, shutdown = TRUE)

message("Esportazione completata.")
