# ==============================================================================
# 03_build_duckdb.R
# Scarica tutte le variabili ARDECO e le archivia in un database DuckDB.
# Output: data/ardeco.duckdb
# ==============================================================================

# 1. Librerie -----

library(ARDECO)
library(data.table)
library(duckdb)
library(DBI)
library(R.utils)

# 2. Configurazione -----

DB_PATH <- "data/ardeco.duckdb"
NUTSCODE <- "ITC4"
LEVEL <- "2,3"
VERSION <- 2024

# 3. Gruppi tematici -----

thematic_groups <- list(
  popolazione_demografia = c(
    "SNPTD",
    "SNPTN",
    "SNPTZ",
    "SNPBN",
    "SNPDN",
    "SNPDZ",
    "SNPNN",
    "SNMTN",
    "SNPCN",
    "SNPCNP",
    "SNMTNP",
    "SPPAN"
  ),
  mercato_lavoro = c(
    "SNETD",
    "SNETDP",
    "SNWTD",
    "RNECN",
    "RNUTN",
    "RNLCN",
    "RNLHT",
    "RNLHTP",
    "RNLHW",
    "RPECNP",
    "RPUCNP"
  ),
  occupazione_settore = c(
    "SNETZ",
    "RNLHZ"
  ),
  pil_valore_aggiunto = c(
    "SUVGD",
    "SOVGD",
    "SUVGE",
    "SOVGE",
    "SUVGZ",
    "SOVGZ",
    "SUVGDH",
    "SUVGDE",
    "SOVGDH",
    "SOVGDE",
    "SUVGDP",
    "SOVGDP",
    "SPVGD",
    "SPVGE"
  ),
  reddito_compensi = c(
    "RUWCD",
    "ROWCD",
    "ROWCDH",
    "RUWCDW",
    "ROWCDW",
    "RUWCDHH",
    "RUWCDWE",
    "RUWCZ",
    "ROWCZ"
  ),
  formazione_capitale = c(
    "RUIGT",
    "ROIGT",
    "RUIGZ",
    "ROIGZ",
    "ROKND",
    "SUKCT",
    "SOKCT",
    "SUKCZ",
    "SOKCZ"
  )
)

# Lookup inverso: da codice variabile a gruppo tematico
var_to_group <- character(0)
for (gn in names(thematic_groups)) {
  for (vc in thematic_groups[[gn]]) {
    var_to_group[vc] <- gn
  }
}

all_vars <- unique(unlist(thematic_groups, use.names = FALSE))

# 4. Tabelle etichette -----

var_labels <- data.table(
  var_code = c(
    "SNPTD",
    "SNPTN",
    "SNPTZ",
    "SNPBN",
    "SNPDN",
    "SNPDZ",
    "SNPNN",
    "SNMTN",
    "SNPCN",
    "SNPCNP",
    "SNMTNP",
    "SPPAN",
    "SNETD",
    "SNETDP",
    "SNWTD",
    "RNECN",
    "RNUTN",
    "RNLCN",
    "RNLHT",
    "RNLHTP",
    "RNLHW",
    "RPECNP",
    "RPUCNP",
    "SNETZ",
    "RNLHZ",
    "SUVGD",
    "SOVGD",
    "SUVGE",
    "SOVGE",
    "SUVGZ",
    "SOVGZ",
    "SUVGDH",
    "SUVGDE",
    "SOVGDH",
    "SOVGDE",
    "SUVGDP",
    "SOVGDP",
    "SPVGD",
    "SPVGE",
    "RUWCD",
    "ROWCD",
    "ROWCDH",
    "RUWCDW",
    "ROWCDW",
    "RUWCDHH",
    "RUWCDWE",
    "RUWCZ",
    "ROWCZ",
    "RUIGT",
    "ROIGT",
    "RUIGZ",
    "ROIGZ",
    "ROKND",
    "SUKCT",
    "SOKCT",
    "SUKCZ",
    "SOKCZ"
  ),
  label_it = c(
    "Popolazione media annua",
    "Popolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso",
    "Popolazione al 1\u00b0 gennaio per classi quinquennali e sesso",
    "Nati vivi per sesso",
    "Decessi per fascia d\u2019et\u00e0 e sesso",
    "Decessi per classi quinquennali e sesso",
    "Variazione naturale della popolazione",
    "Migrazione netta per fascia d\u2019et\u00e0 e sesso",
    "Variazione della popolazione per fascia d\u2019et\u00e0 e sesso",
    "Variazione della popolazione per 1000 abitanti",
    "Migrazione netta per 1000 abitanti",
    "Indice di dipendenza (rapporto alla popolazione 20-64)",
    "Occupazione workplace-based",
    "Occupazione pro capite",
    "Dipendenti workplace-based",
    "Occupati per et\u00e0 e sesso",
    "Disoccupati",
    "Forza lavoro (15 anni e oltre)",
    "Ore lavorate (occupati)",
    "Ore lavorate pro capite",
    "Ore lavorate (dipendenti)",
    "Tasso di occupazione (20-64 anni)",
    "Tasso di disoccupazione (15-74 anni)",
    "Occupazione per settore NACE",
    "Ore lavorate per settore NACE",
    "PIL a prezzi correnti",
    "PIL a prezzi costanti",
    "Valore aggiunto a prezzi correnti",
    "Valore aggiunto a prezzi costanti",
    "Valore aggiunto per settore a prezzi correnti",
    "Valore aggiunto per settore a prezzi costanti",
    "Produttivit\u00e0 nominale per ora lavorata",
    "Produttivit\u00e0 nominale per occupato",
    "Produttivit\u00e0 reale per ora lavorata",
    "Produttivit\u00e0 reale per occupato",
    "PIL pro capite a prezzi correnti",
    "PIL pro capite a prezzi costanti",
    "Tasso di crescita del PIL (indice concatenato)",
    "Tasso di crescita del VA (indice concatenato)",
    "Compensi dei dipendenti a prezzi correnti",
    "Compensi dei dipendenti a prezzi costanti",
    "Compenso reale per ora lavorata",
    "Compenso nominale per dipendente",
    "Compenso reale per dipendente",
    "Costo del lavoro per unit\u00e0 di prodotto nominale (ore)",
    "Costo del lavoro per unit\u00e0 di prodotto nominale (persone)",
    "Compensi per settore a prezzi correnti",
    "Compensi per settore a prezzi costanti",
    "Investimenti fissi lordi a prezzi correnti",
    "Investimenti fissi lordi a prezzi costanti",
    "Investimenti fissi lordi per settore a prezzi correnti",
    "Investimenti fissi lordi per settore a prezzi costanti",
    "Stock di capitale a prezzi costanti",
    "Ammortamenti a prezzi correnti",
    "Ammortamenti a prezzi costanti",
    "Ammortamenti per settore a prezzi correnti",
    "Ammortamenti per settore a prezzi costanti"
  ),
  group_id = c(
    rep("popolazione_demografia", 12),
    rep("mercato_lavoro", 11),
    rep("occupazione_settore", 2),
    rep("pil_valore_aggiunto", 14),
    rep("reddito_compensi", 9),
    rep("formazione_capitale", 9)
  ),
  description_it = c(
    # Popolazione e demografia (12)
    "Popolazione media annua, calcolata come media aritmetica della popolazione al 1\u00b0 gennaio dell\u2019anno t e dell\u2019anno t+1. Fonte: Eurostat, statistiche demografiche regionali.",
    "Popolazione residente al 1\u00b0 gennaio, disaggregata per grandi fasce d\u2019et\u00e0 e sesso. Fonte: Eurostat, statistiche demografiche regionali.",
    "Popolazione residente al 1\u00b0 gennaio per classi quinquennali d\u2019et\u00e0 e sesso. Fonte: Eurostat, statistiche demografiche regionali.",
    "Numero di nati vivi nell\u2019anno, per sesso. Fonte: Eurostat, statistiche sulle nascite.",
    "Decessi nell\u2019anno per grandi fasce d\u2019et\u00e0 e sesso. Fonte: Eurostat, statistiche sulla mortalit\u00e0.",
    "Decessi nell\u2019anno per classi quinquennali d\u2019et\u00e0 e sesso. Fonte: Eurostat, statistiche sulla mortalit\u00e0.",
    "Variazione naturale della popolazione (nati vivi meno decessi). Indicatore derivato.",
    "Migrazione netta per grandi fasce d\u2019et\u00e0 e sesso, calcolata come differenza tra variazione totale e variazione naturale della popolazione. Indicatore derivato.",
    "Variazione totale della popolazione per grandi fasce d\u2019et\u00e0 e sesso (variazione naturale pi\u00f9 migrazione netta). Indicatore derivato.",
    "Variazione della popolazione per 1000 abitanti. Indicatore derivato.",
    "Migrazione netta per 1000 abitanti, per grandi fasce d\u2019et\u00e0. Indicatore derivato.",
    "Indice di dipendenza: rapporto tra popolazione in et\u00e0 non lavorativa (0-19 e 65+) e popolazione in et\u00e0 lavorativa (20-64). Indicatore derivato.",
    # Mercato del lavoro (11)
    "Occupazione totale workplace-based (persone occupate nel territorio), secondo la definizione dei conti nazionali. Fonte: conti regionali Eurostat (ESA 2010).",
    "Occupazione pro capite, calcolata come rapporto tra occupati workplace-based e popolazione media annua. Indicatore derivato.",
    "Dipendenti workplace-based (lavoratori subordinati nel territorio). Fonte: conti regionali Eurostat (ESA 2010).",
    "Occupazione residence-based per fascia d\u2019et\u00e0 (20-64 anni) e sesso, basata sulla Rilevazione sulle Forze di Lavoro (EU-LFS). Fonte: Eurostat, EU-LFS.",
    "Disoccupati per fascia d\u2019et\u00e0 (15-74 anni), dato sperimentale. Fonte: Eurostat, EU-LFS.",
    "Forza lavoro (occupati pi\u00f9 disoccupati), popolazione di 15 anni e oltre. Fonte: Eurostat, EU-LFS.",
    "Ore lavorate totali (tutte le persone occupate). Fonte: conti regionali Eurostat (ESA 2010), con integrazioni JRC.",
    "Ore lavorate pro capite, calcolate come rapporto tra ore totali e popolazione media annua. Indicatore derivato.",
    "Ore lavorate dei soli dipendenti. Fonte: conti regionali Eurostat (ESA 2010), con integrazioni JRC.",
    "Tasso di occupazione: percentuale di occupati sulla popolazione in et\u00e0 20-64 anni. Fonte: Eurostat, EU-LFS.",
    "Tasso di disoccupazione: percentuale di disoccupati sulla forza lavoro in et\u00e0 15-74 anni. Dato sperimentale. Fonte: Eurostat, EU-LFS.",
    # Occupazione per settore (2)
    "Occupazione per settore di attivit\u00e0 economica (classificazione NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat (ESA 2010).",
    "Ore lavorate per settore di attivit\u00e0 economica (classificazione NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat (ESA 2010), con integrazioni JRC.",
    # PIL e valore aggiunto (14)
    "Prodotto interno lordo (PIL) a prezzi correnti di mercato. Fonte: conti regionali Eurostat (ESA 2010), integrati con stime JRC.",
    "PIL a prezzi costanti (anno base 2015), calcolato applicando i tassi di crescita regionali in volume. Fonte: Eurostat (nama_10r_2gdp), con deflatori JRC.",
    "Valore aggiunto lordo (VAL) ai prezzi base. Fonte: conti regionali Eurostat (ESA 2010).",
    "Valore aggiunto lordo a prezzi costanti (anno base 2015). Fonte: Eurostat, con deflatori JRC.",
    "Valore aggiunto per settore di attivit\u00e0 economica a prezzi correnti (NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat.",
    "Valore aggiunto per settore a prezzi costanti (NACE Rev. 2, 10 settori). Fonte: Eurostat, con deflatori JRC.",
    "Produttivit\u00e0 nominale del lavoro per ora lavorata (PIL a prezzi correnti / ore totali). Indicatore derivato.",
    "Produttivit\u00e0 nominale del lavoro per occupato (PIL a prezzi correnti / occupati). Indicatore derivato.",
    "Produttivit\u00e0 reale del lavoro per ora lavorata (PIL a prezzi costanti / ore totali). Indicatore derivato.",
    "Produttivit\u00e0 reale del lavoro per occupato (PIL a prezzi costanti / occupati). Indicatore derivato.",
    "PIL pro capite a prezzi correnti (PIL / popolazione media annua). Indicatore derivato.",
    "PIL pro capite a prezzi costanti (PIL reale / popolazione media annua). Indicatore derivato.",
    "Tasso di crescita del PIL, calcolato come indice concatenato in volume. Indicatore derivato.",
    "Tasso di crescita del valore aggiunto, calcolato come indice concatenato in volume. Indicatore derivato.",
    # Reddito e compensi (9)
    "Compensi dei dipendenti a prezzi correnti, inclusi salari e contributi sociali a carico del datore di lavoro. Fonte: conti regionali Eurostat (ESA 2010).",
    "Compensi dei dipendenti a prezzi costanti (anno base 2015). Fonte: Eurostat, con deflatori JRC.",
    "Compenso reale per ora lavorata (compensi a prezzi costanti / ore dipendenti). Indicatore derivato.",
    "Compenso nominale per dipendente (compensi totali / numero di dipendenti). Indicatore derivato.",
    "Compenso reale per dipendente (compensi a prezzi costanti / numero di dipendenti). Indicatore derivato.",
    "Costo del lavoro per unit\u00e0 di prodotto (CLUP) nominale basato sulle ore: rapporto tra compenso orario e produttivit\u00e0 oraria. Indicatore derivato.",
    "Costo del lavoro per unit\u00e0 di prodotto (CLUP) nominale basato sulle persone: rapporto tra compenso per dipendente e produttivit\u00e0 per occupato. Indicatore derivato.",
    "Compensi dei dipendenti per settore a prezzi correnti (NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat.",
    "Compensi dei dipendenti per settore a prezzi costanti (NACE Rev. 2, 10 settori). Fonte: Eurostat, con deflatori JRC.",
    # Formazione del capitale (9)
    "Investimenti fissi lordi (FBCF) a prezzi correnti. Fonte: conti regionali Eurostat (ESA 2010).",
    "Investimenti fissi lordi a prezzi costanti (anno base 2015). Fonte: Eurostat, con deflatori JRC.",
    "Investimenti fissi lordi per settore a prezzi correnti (NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat.",
    "Investimenti fissi lordi per settore a prezzi costanti (NACE Rev. 2, 10 settori). Fonte: Eurostat, con deflatori JRC.",
    "Stock di capitale netto a prezzi costanti (anno base 2015). Stima JRC basata sul metodo dell\u2019inventario permanente (PIM).",
    "Ammortamenti (consumo di capitale fisso) a prezzi correnti. Fonte: conti regionali Eurostat (ESA 2010).",
    "Ammortamenti a prezzi costanti (anno base 2015). Fonte: Eurostat, con deflatori JRC.",
    "Ammortamenti per settore a prezzi correnti (NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat.",
    "Ammortamenti per settore a prezzi costanti (NACE Rev. 2, 10 settori). Fonte: Eurostat, con deflatori JRC."
  )
)

unit_labels <- data.table(
  code = c(
    "NR",
    "GROWRT",
    "THS",
    "MIO_EUR",
    "MIO_PPS_EU27_2020",
    "MIO_EUR2015",
    "MIO_EUR2020",
    "EUR_HAB",
    "EUR_HAB2015",
    "PPS_HAB",
    "PC",
    "THS_HW",
    "EUR",
    "PPS_EU27_2020",
    "EUR2015",
    "EUR2020",
    "I15",
    "I20",
    "PCH_PRE"
  ),
  label_it = c(
    "Numero",
    "Tasso di crescita (\u2030)",
    "Migliaia",
    "Milioni di euro",
    "Milioni di PPS (EU27 2020)",
    "Milioni di euro (prezzi 2015)",
    "Milioni di euro (prezzi 2020)",
    "Euro per abitante",
    "Euro per abitante (prezzi 2015)",
    "PPS per abitante",
    "Percentuale",
    "Migliaia di ore lavorate",
    "Euro",
    "PPS (EU27 2020)",
    "Euro (prezzi 2015)",
    "Euro (prezzi 2020)",
    "Indice concatenato (base 2015)",
    "Indice concatenato (base 2020)",
    "Variazione percentuale sull'anno precedente"
  )
)

sex_labels <- data.table(
  code = c("TOTAL", "F", "M"),
  label_it = c("Totale", "Femmine", "Maschi")
)

age_labels <- data.table(
  code = c(
    "TOTAL",
    "Y_LT5",
    "Y5-9",
    "Y10-14",
    "Y15-19",
    "Y15-39",
    "Y15-64",
    "Y20-24",
    "Y20-29",
    "Y20-64",
    "Y25-29",
    "Y30-34",
    "Y35-39",
    "Y40-44",
    "Y40-64",
    "Y45-49",
    "Y50-54",
    "Y55-59",
    "Y60-64",
    "Y65-69",
    "Y70-74",
    "Y75-79",
    "Y80-84",
    "Y85-89",
    "Y_GE15",
    "Y_GE65",
    "Y_GE85",
    "Y_GE90",
    "Y_LT15",
    "Y_LT20",
    "Y_LT15-GE65",
    "Y_LT20-GE65"
  ),
  label_it = c(
    "Totale",
    "Meno di 5 anni",
    "5-9 anni",
    "10-14 anni",
    "15-19 anni",
    "15-39 anni",
    "15-64 anni",
    "20-24 anni",
    "20-29 anni",
    "20-64 anni",
    "25-29 anni",
    "30-34 anni",
    "35-39 anni",
    "40-44 anni",
    "40-64 anni",
    "45-49 anni",
    "50-54 anni",
    "55-59 anni",
    "60-64 anni",
    "65-69 anni",
    "70-74 anni",
    "75-79 anni",
    "80-84 anni",
    "85-89 anni",
    "15 anni e oltre",
    "65 anni e oltre",
    "85 anni e oltre",
    "90 anni e oltre",
    "Meno di 15 anni",
    "Meno di 20 anni",
    "Meno di 15 e 65 anni e oltre",
    "Meno di 20 e 65 anni e oltre"
  )
)

sector_labels <- data.table(
  code = c(
    "A",
    "B-E",
    "F",
    "G-I",
    "G-J",
    "J",
    "K",
    "K-N",
    "L",
    "M_N",
    "O-Q",
    "O-U",
    "R-U"
  ),
  label_it = c(
    "Agricoltura, silvicoltura e pesca",
    "Industria (escluse costruzioni)",
    "Costruzioni",
    "Commercio, trasporti, alloggio e ristorazione",
    "Commercio, trasporti, informazione e comunicazione",
    "Informazione e comunicazione",
    "Attivit\u00e0 finanziarie e assicurative",
    "Attivit\u00e0 finanziarie, immobiliari, professionali",
    "Attivit\u00e0 immobiliari",
    "Attivit\u00e0 professionali, scientifiche e tecniche",
    "PA, istruzione, sanit\u00e0",
    "PA, istruzione, sanit\u00e0 e altri servizi",
    "Altre attivit\u00e0 di servizi"
  )
)

group_labels <- data.table(
  group_id = c(
    "popolazione_demografia",
    "mercato_lavoro",
    "occupazione_settore",
    "pil_valore_aggiunto",
    "reddito_compensi",
    "formazione_capitale"
  ),
  label_it = c(
    "Popolazione e demografia",
    "Mercato del lavoro",
    "Occupazione per settore",
    "PIL e valore aggiunto",
    "Reddito e compensi",
    "Formazione del capitale"
  )
)

# 5. Funzione download -----

#' Download a single ARDECO variable with normalized schema.
#'
#' Wraps ardeco_get_dataset_data() with error handling and column normalization.
#' Returns a data.table with a consistent 12-column schema on success, or NULL
#' on failure.
#'
#' @param var_code Character. ARDECO variable code.
#' @param nutscode Character. NUTS code filter (default "ITC4" for Lombardia).
#' @param level Character. NUTS levels to retrieve (default "2,3").
#' @param version Numeric. NUTS version year (default 2024).
#' @return A data.table with 12 columns or NULL on failure.
download_variable <- function(
  var_code,
  nutscode = "ITC4",
  level = "2,3",
  version = 2024,
  timeout_sec = 300
) {
  tryCatch(
    {
      dl <- R.utils::withTimeout(
        ardeco_get_dataset_data(
          var_code,
          nutscode = nutscode,
          level = level,
          version = version
        ),
        timeout = timeout_sec
      )
      if (is.null(dl) || nrow(dl) == 0L) {
        message("  [WARN] No data returned for ", var_code)
        return(NULL)
      }
      dt <- as.data.table(dl)

      # Normalizzazione colonne opzionali
      for (col in c("SEX", "AGE", "SECTOR", "ISCED11")) {
        if (!col %in% names(dt)) {
          set(dt, j = col, value = NA_character_)
        }
      }

      # Gruppo tematico
      set(dt, j = "THEMATIC_GROUP", value = var_to_group[var_code])

      # Conversione tipi
      if (!is.double(dt[["VALUE"]])) {
        set(dt, j = "VALUE", value = as.double(dt[["VALUE"]]))
      }
      if (!is.integer(dt[["YEAR"]])) {
        set(dt, j = "YEAR", value = as.integer(dt[["YEAR"]]))
      }
      if (!is.integer(dt[["LEVEL"]])) {
        set(dt, j = "LEVEL", value = as.integer(dt[["LEVEL"]]))
      }
      if (!is.integer(dt[["VERSIONS"]])) {
        set(dt, j = "VERSIONS", value = as.integer(dt[["VERSIONS"]]))
      }

      # Schema a 12 colonne in ordine fisso
      dt[, list(
        VARIABLE,
        VERSIONS,
        LEVEL,
        NUTSCODE,
        YEAR,
        UNIT,
        VALUE,
        SEX,
        AGE,
        SECTOR,
        ISCED11,
        THEMATIC_GROUP
      )]
    },
    TimeoutException = function(e) {
      message("  [TIMEOUT] ", var_code, " exceeded ", timeout_sec, "s")
      NULL
    },
    error = function(e) {
      message(
        "  [ERROR] Failed to download ",
        var_code,
        ": ",
        conditionMessage(e)
      )
      NULL
    }
  )
}

# 6. Inizializzazione DuckDB -----

if (file.exists(DB_PATH)) {
  file.remove(DB_PATH)
  message("Rimosso database esistente: ", DB_PATH)
}

con <- dbConnect(duckdb(), dbdir = DB_PATH)
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

# 7. Loop principale -----

message("\nDownloading ", length(all_vars), " variables\n")

# Pre-allocate summary log
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
  dt <- download_variable(vc)
  elapsed <- (proc.time() - t0)[["elapsed"]]

  if (!is.null(dt)) {
    dbWriteTable(con, "ardeco_data", dt, append = TRUE)
    message(sprintf("  Inserted %d rows (%.1fs)", nrow(dt), elapsed))

    set(summary_log, i, "var_code", vc)
    set(summary_log, i, "group", gn)
    set(summary_log, i, "n_rows", nrow(dt))
    set(summary_log, i, "status", "OK")
    set(summary_log, i, "elapsed_sec", elapsed)
  } else {
    set(summary_log, i, "var_code", vc)
    set(summary_log, i, "group", gn)
    set(summary_log, i, "n_rows", 0L)
    set(summary_log, i, "status", "FAILED")
    set(summary_log, i, "elapsed_sec", elapsed)
  }
}

# Rimozione combinazioni invarianti tra province
n_del <- dbExecute(
  con,
  "DELETE FROM ardeco_data WHERE VARIABLE = 'ROWCDH' AND UNIT = 'EUR2020'"
)
message(sprintf("Rimossi %d record invarianti (ROWCDH EUR2020)", n_del))

# Creazione indici
dbExecute(con, "CREATE INDEX idx_variable ON ardeco_data (VARIABLE)")
dbExecute(con, "CREATE INDEX idx_nuts_year ON ardeco_data (NUTSCODE, YEAR)")

# 8. Scrittura tabelle etichette -----

dbWriteTable(con, "var_labels", var_labels, overwrite = TRUE)
dbWriteTable(con, "unit_labels", unit_labels, overwrite = TRUE)
dbWriteTable(con, "sex_labels", sex_labels, overwrite = TRUE)
dbWriteTable(con, "age_labels", age_labels, overwrite = TRUE)
dbWriteTable(con, "sector_labels", sector_labels, overwrite = TRUE)
dbWriteTable(con, "group_labels", group_labels, overwrite = TRUE)
dbWriteTable(con, "download_log", summary_log, overwrite = TRUE)
message("Tabelle etichette e log scritte nel database")

# 9. Riepilogo -----

message("\n========== Download summary ==========")
for (i in seq_len(nrow(summary_log))) {
  row <- summary_log[i]
  msg <- sprintf(
    "  %-6s | %-25s | %7d rows | %6.1fs | %s",
    row$var_code,
    row$group,
    row$n_rows,
    row$elapsed_sec,
    row$status
  )
  message(msg)
}

n_ok <- summary_log[status == "OK", .N]
n_failed <- summary_log[status == "FAILED", .N]

message(sprintf(
  "\nTotal: %d OK, %d FAILED out of %d variables.",
  n_ok,
  n_failed,
  nrow(summary_log)
))

if (n_failed > 0L) {
  failed_vars <- summary_log[status == "FAILED", var_code]
  message("Failed variables: ", paste(failed_vars, collapse = ", "))
} else {
  message("All variables downloaded successfully.")
}

# Verifica DuckDB
row_count <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM ardeco_data")$n
var_count <- dbGetQuery(
  con,
  "SELECT COUNT(DISTINCT VARIABLE) AS n FROM ardeco_data"
)$n
tbl_list <- dbGetQuery(con, "SHOW TABLES")

message(sprintf("\nDuckDB: %s", DB_PATH))
message(sprintf("  Tabelle: %s", paste(tbl_list[[1]], collapse = ", ")))
message(sprintf("  ardeco_data: %d righe, %d variabili", row_count, var_count))
message(sprintf("  Dimensione file: %.1f MB", file.size(DB_PATH) / 1e6))

total_elapsed <- (proc.time() - t0_total)[["elapsed"]]
message(sprintf(
  "  Tempo totale: %.0f secondi (%.1f minuti)",
  total_elapsed,
  total_elapsed / 60
))
