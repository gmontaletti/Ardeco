#!/usr/bin/env Rscript
# ==============================================================================
# run_pipeline.R
# Pipeline monolitica ARDECO -> PostgreSQL per esecuzione in container.
# Scarica le variabili ARDECO, le valida in un DuckDB di staging, le scrive
# su uno schema _stg di PostgreSQL e infine esegue uno swap atomico con lo
# schema di produzione. Log strutturato su stdout/stderr.
# Uscita: 0 se tutto ok, 1 in caso di errore.
# ==============================================================================

# 1. Librerie -----

suppressPackageStartupMessages({
  library(ARDECO)
  library(data.table)
  library(duckdb)
  library(DBI)
  library(RPostgres)
  library(R.utils)
})

# 2. Logging helpers -----

.log <- function(level, step, msg) {
  ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  line <- sprintf("%s | %-5s | %-12s | %s\n", ts, level, step, msg)
  con <- if (level %in% c("WARN", "ERROR")) stderr() else stdout()
  cat(line, file = con)
  flush(con)
}
log_info <- function(step, msg) .log("INFO", step, msg)
log_warn <- function(step, msg) .log("WARN", step, msg)
log_error <- function(step, msg) .log("ERROR", step, msg)
log_step <- function(step, msg) {
  .log("INFO", step, paste0("===== ", msg, " ====="))
}

fatal <- function(step, msg) {
  log_error(step, msg)
  quit(status = 1L, save = "no")
}

# 3. Configurazione -----

getenv_default <- function(name, default = NA_character_) {
  v <- Sys.getenv(name, unset = NA_character_)
  if (is.na(v) || !nzchar(v)) default else v
}

cfg <- list(
  pg_host = getenv_default("PG_HOST"),
  pg_port = getenv_default("PG_PORT", "5432"),
  pg_dbname = getenv_default("PG_DBNAME"),
  pg_user = getenv_default("PG_USER"),
  pg_password = getenv_default("PG_PASSWORD"),
  pg_schema = getenv_default("PG_SCHEMA", "ardeco"),
  nutscode = getenv_default("ARDECO_NUTSCODE", "ITC4"),
  level = getenv_default("ARDECO_LEVEL", "2,3"),
  version = as.integer(getenv_default("ARDECO_VERSION", "2024")),
  staging = getenv_default("ARDECO_STAGING_PATH", "/tmp/ardeco_staging.duckdb"),
  timeout_sec = as.integer(getenv_default("ARDECO_DOWNLOAD_TIMEOUT", "300"))
)

log_step("config", "Avvio pipeline ARDECO -> PostgreSQL")
log_info(
  "config",
  sprintf(
    "host=%s port=%s dbname=%s user=%s schema=%s",
    cfg$pg_host,
    cfg$pg_port,
    cfg$pg_dbname,
    cfg$pg_user,
    cfg$pg_schema
  )
)
log_info(
  "config",
  sprintf(
    "nutscode=%s level=%s version=%d staging=%s timeout=%ds",
    cfg$nutscode,
    cfg$level,
    cfg$version,
    cfg$staging,
    cfg$timeout_sec
  )
)

required <- c("pg_host", "pg_dbname", "pg_user", "pg_password")
missing_cfg <- required[vapply(cfg[required], is.na, logical(1))]
if (length(missing_cfg) > 0L) {
  fatal(
    "config",
    paste(
      "Variabili d'ambiente mancanti:",
      paste(toupper(sub("pg_", "PG_", missing_cfg)), collapse = ", ")
    )
  )
}

# 4. Definizione variabili e label -----

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
  occupazione_settore = c("SNETZ", "RNLHZ"),
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

var_to_group <- character(0)
for (gn in names(thematic_groups)) {
  for (vc in thematic_groups[[gn]]) {
    var_to_group[vc] <- gn
  }
}
all_vars <- unique(unlist(thematic_groups, use.names = FALSE))

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
    "ZINACT15",
    "ZTINACT15",
    "ZNOCC2064",
    "ZTNOCC2064",
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
    "Popolazione inattiva 15+ (indicatore calcolato, non ARDECO)",
    "Tasso di inattività 15+ (indicatore calcolato, non ARDECO)",
    "Popolazione non occupata 20-64 anni (indicatore calcolato: disoccupati e inattivi, non tasso di inattività)",
    "Tasso di non occupazione 20-64 anni (indicatore calcolato, non tasso di inattività)",
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
    rep("mercato_lavoro", 15),
    rep("occupazione_settore", 2),
    rep("pil_valore_aggiunto", 14),
    rep("reddito_compensi", 9),
    rep("formazione_capitale", 9)
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
    "R-U",
    "TOTAL"
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
    "Altre attivit\u00e0 di servizi",
    "Totale (tutti i settori)"
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

# 5. Download da ARDECO -----

download_attempt <- function(var_code, nutscode, level, version, timeout_sec) {
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
        list(ok = FALSE, reason = "nessun dato restituito")
      } else {
        list(ok = TRUE, data = dl)
      }
    },
    TimeoutException = function(e) {
      list(ok = FALSE, reason = sprintf("timeout dopo %ds", timeout_sec))
    },
    error = function(e) {
      list(ok = FALSE, reason = sprintf("errore: %s", conditionMessage(e)))
    }
  )
}

# Backoff: tentativo 1 immediato, tentativo 2 dopo 5-10s (jitter), tentativo 3
# dopo 1 minuto - assorbe i blip transitori dell'API JRC senza perdere la
# variabile dallo schema di produzione (vedi log FAILED del 2026-07-07:
# 12 variabili segnalate FAILED erano in realta' tutte scaricabili subito
# dopo, a conferma di un problema di rete/API transitorio, non di dati
# mancanti).
download_variable <- function(var_code, nutscode, level, version, timeout_sec) {
  delays <- c(0, stats::runif(1, min = 5, max = 10), 60)
  n_attempts <- length(delays)

  for (attempt in seq_len(n_attempts)) {
    if (delays[attempt] > 0) {
      log_warn(
        "download",
        sprintf(
          "%s: nuovo tentativo %d/%d tra %.1fs",
          var_code,
          attempt,
          n_attempts,
          delays[attempt]
        )
      )
      Sys.sleep(delays[attempt])
    }

    res <- download_attempt(var_code, nutscode, level, version, timeout_sec)

    if (isTRUE(res$ok)) {
      dt <- as.data.table(res$data)

      for (col in c("SEX", "AGE", "SECTOR", "ISCED11")) {
        if (!col %in% names(dt)) set(dt, j = col, value = NA_character_)
      }
      set(dt, j = "THEMATIC_GROUP", value = var_to_group[var_code])

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

      return(dt[, list(
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
      )])
    }

    esito <- if (attempt == n_attempts) {
      "abbandono"
    } else {
      "nuovo tentativo in arrivo"
    }
    log_warn(
      "download",
      sprintf(
        "%s: %s (tentativo %d/%d, %s)",
        var_code,
        res$reason,
        attempt,
        n_attempts,
        esito
      )
    )
  }

  NULL
}

# 6. Costruzione DuckDB di staging -----

run_pipeline <- function() {
  log_step("staging", sprintf("Apertura DuckDB staging: %s", cfg$staging))
  if (file.exists(cfg$staging)) {
    file.remove(cfg$staging)
    log_info("staging", "Rimosso staging DuckDB preesistente")
  }
  dir.create(dirname(cfg$staging), showWarnings = FALSE, recursive = TRUE)

  duck_con <- dbConnect(duckdb(), dbdir = cfg$staging)

  dbExecute(
    duck_con,
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
  dbWriteTable(duck_con, "variable_list", variable_list, overwrite = TRUE)
  log_info("staging", sprintf("variable_list: %d righe", nrow(variable_list)))

  # 6a. Download loop
  log_step(
    "download",
    sprintf("Download di %d variabili ARDECO", length(all_vars))
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
    log_info(
      "download",
      sprintf("[%2d/%d] %s (%s) avvio", i, length(all_vars), vc, gn)
    )
    t0 <- proc.time()
    dt <- download_variable(
      vc,
      cfg$nutscode,
      cfg$level,
      cfg$version,
      cfg$timeout_sec
    )
    elapsed <- (proc.time() - t0)[["elapsed"]]

    if (!is.null(dt)) {
      dbWriteTable(duck_con, "ardeco_data", dt, append = TRUE)
      log_info(
        "download",
        sprintf(
          "[%2d/%d] %s: %d righe in %.1fs",
          i,
          length(all_vars),
          vc,
          nrow(dt),
          elapsed
        )
      )
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

  # 6a2. Calcolo indicatori derivati (inattivita') -----
  # Codici sintetici (prefisso Z, mai usato da ARDECO - verificato via
  # ardeco_get_variable_list() sui 101 codici live) calcolati localmente
  # da SNPTN/RNLCN/RNECN gia' presenti in ardeco_data. Vanno PRIMA della
  # rimozione invarianza spaziale (6b) cosi' che il controllo generico
  # gia' esistente ripulisca automaticamente anche queste righe, senza
  # codice dedicato.
  #
  # Indicatore 1 - Popolazione inattiva (15+), definizione ILO/Eurostat:
  #   Popolazione(15+)   = SNPTN[AGE=TOTAL] - SNPTN[AGE=Y_LT15]  (SEX=TOTAL, UNIT=NR -> /1000 = THS)
  #   Forza lavoro(15+)  = RNLCN (SEX/AGE NULL, UNIT=THS, gia' scoped 15+)
  #   Inattiva(15+)      = Popolazione(15+) - Forza lavoro(15+)
  #   Tasso inattivita'  = Inattiva(15+) / Popolazione(15+) * 100
  #
  # Indicatore 2 - Popolazione NON occupata (20-64): NON e' inattivita'
  # vera (disoccupati+inattivi confusi insieme), perche' RNUTN non ha
  # breakdown per eta'. Etichettato in modo esplicito per non confondere
  # con l'indicatore 1.
  #   Popolazione(20-64) = SNPTN[AGE=Y20-64, SEX=TOTAL] (UNIT=NR -> /1000 = THS)
  #   Occupati(20-64)    = RNECN[AGE=Y20-64, SEX=TOTAL] (UNIT=THS)
  #   Non occupata       = Popolazione(20-64) - Occupati(20-64)
  #   Tasso non occ.     = Non occupata / Popolazione(20-64) * 100

  log_step(
    "derive",
    "Calcolo indicatori derivati (inattivita' 15+, non occupazione 20-64)"
  )

  n_pop_tot <- dbGetQuery(
    duck_con,
    "SELECT COUNT(*) n FROM ardeco_data WHERE VARIABLE='SNPTN' AND UNIT='NR' AND SEX='TOTAL' AND AGE='TOTAL'"
  )$n
  n_pop_lt15 <- dbGetQuery(
    duck_con,
    "SELECT COUNT(*) n FROM ardeco_data WHERE VARIABLE='SNPTN' AND UNIT='NR' AND SEX='TOTAL' AND AGE='Y_LT15'"
  )$n
  n_lf15 <- dbGetQuery(
    duck_con,
    "SELECT COUNT(*) n FROM ardeco_data WHERE VARIABLE='RNLCN' AND UNIT='THS' AND SEX IS NULL AND AGE IS NULL"
  )$n
  n_pop2064 <- dbGetQuery(
    duck_con,
    "SELECT COUNT(*) n FROM ardeco_data WHERE VARIABLE='SNPTN' AND UNIT='NR' AND SEX='TOTAL' AND AGE='Y20-64'"
  )$n
  n_emp2064 <- dbGetQuery(
    duck_con,
    "SELECT COUNT(*) n FROM ardeco_data WHERE VARIABLE='RNECN' AND UNIT='THS' AND SEX='TOTAL' AND AGE='Y20-64'"
  )$n

  log_info(
    "derive",
    sprintf(
      "Slice sorgenti: SNPTN[TOTAL]=%d SNPTN[Y_LT15]=%d RNLCN=%d SNPTN[Y20-64]=%d RNECN[Y20-64]=%d",
      n_pop_tot,
      n_pop_lt15,
      n_lf15,
      n_pop2064,
      n_emp2064
    )
  )

  # -- indicatore 1: inattivita' 15+ -------------------------------------
  dbExecute(duck_con, "DROP TABLE IF EXISTS calc_inact15")
  dbExecute(
    duck_con,
    "
    CREATE TEMP TABLE calc_inact15 AS
    WITH pop_total AS (
      SELECT NUTSCODE, YEAR, LEVEL, VERSIONS, VALUE AS POP_TOTAL_NR
      FROM ardeco_data
      WHERE VARIABLE = 'SNPTN' AND UNIT = 'NR' AND SEX = 'TOTAL' AND AGE = 'TOTAL'
    ),
    pop_lt15 AS (
      SELECT NUTSCODE, YEAR, LEVEL, VERSIONS, VALUE AS POP_LT15_NR
      FROM ardeco_data
      WHERE VARIABLE = 'SNPTN' AND UNIT = 'NR' AND SEX = 'TOTAL' AND AGE = 'Y_LT15'
    ),
    labour_force AS (
      SELECT NUTSCODE, YEAR, LEVEL, VERSIONS, VALUE AS LF15_THS
      FROM ardeco_data
      WHERE VARIABLE = 'RNLCN' AND UNIT = 'THS' AND SEX IS NULL AND AGE IS NULL
    ),
    pop15 AS (
      SELECT t.NUTSCODE, t.YEAR, t.LEVEL, t.VERSIONS,
             (t.POP_TOTAL_NR - l.POP_LT15_NR) / 1000.0 AS POP15_THS
      FROM pop_total t
      INNER JOIN pop_lt15 l
        ON l.NUTSCODE = t.NUTSCODE AND l.YEAR = t.YEAR AND l.LEVEL = t.LEVEL
       AND l.VERSIONS IS NOT DISTINCT FROM t.VERSIONS
    )
    SELECT p.NUTSCODE, p.YEAR, p.LEVEL, p.VERSIONS,
           p.POP15_THS,
           f.LF15_THS,
           (p.POP15_THS - f.LF15_THS)                     AS INACT15_THS,
           (p.POP15_THS - f.LF15_THS) / p.POP15_THS * 100  AS INACT15_RATE
    FROM pop15 p
    INNER JOIN labour_force f
      ON f.NUTSCODE = p.NUTSCODE AND f.YEAR = p.YEAR AND f.LEVEL = p.LEVEL
     AND f.VERSIONS IS NOT DISTINCT FROM p.VERSIONS
    "
  )

  n_inact15 <- dbGetQuery(duck_con, "SELECT COUNT(*) n FROM calc_inact15")$n
  if (n_inact15 < 0.95 * min(n_pop_tot, n_pop_lt15, n_lf15)) {
    log_warn(
      "derive",
      sprintf(
        paste0(
          "ZINACT15: solo %d righe calcolate a fronte di un input piu' ",
          "scarso di %d righe (RNLCN) - possibile mismatch di chiavi"
        ),
        n_inact15,
        n_lf15
      )
    )
  } else {
    log_info(
      "derive",
      sprintf("ZINACT15/ZTINACT15: %d righe calcolate", n_inact15)
    )
  }

  dbExecute(
    duck_con,
    "
    INSERT INTO ardeco_data
      (VARIABLE, VERSIONS, LEVEL, NUTSCODE, YEAR, UNIT, VALUE, SEX, AGE, SECTOR, ISCED11, THEMATIC_GROUP)
    SELECT 'ZINACT15', VERSIONS, LEVEL, NUTSCODE, YEAR, 'THS', INACT15_THS,
           'TOTAL', 'Y_GE15', NULL, NULL, 'mercato_lavoro'
    FROM calc_inact15
    "
  )
  dbExecute(
    duck_con,
    "
    INSERT INTO ardeco_data
      (VARIABLE, VERSIONS, LEVEL, NUTSCODE, YEAR, UNIT, VALUE, SEX, AGE, SECTOR, ISCED11, THEMATIC_GROUP)
    SELECT 'ZTINACT15', VERSIONS, LEVEL, NUTSCODE, YEAR, 'PC', INACT15_RATE,
           'TOTAL', 'Y_GE15', NULL, NULL, 'mercato_lavoro'
    FROM calc_inact15
    "
  )

  n_neg <- dbGetQuery(
    duck_con,
    "SELECT COUNT(*) n FROM ardeco_data WHERE VARIABLE='ZINACT15' AND VALUE < 0"
  )$n
  if (n_neg > 0L) {
    log_warn(
      "derive",
      sprintf(
        "ZINACT15: %d righe con valore negativo (anomalia dati sorgente?)",
        n_neg
      )
    )
  }
  dbExecute(duck_con, "DROP TABLE IF EXISTS calc_inact15")

  # -- indicatore 2: non occupazione 20-64 -------------------------------
  dbExecute(duck_con, "DROP TABLE IF EXISTS calc_nocc2064")
  dbExecute(
    duck_con,
    "
    CREATE TEMP TABLE calc_nocc2064 AS
    WITH pop2064 AS (
      SELECT NUTSCODE, YEAR, LEVEL, VERSIONS, VALUE / 1000.0 AS POP2064_THS
      FROM ardeco_data
      WHERE VARIABLE = 'SNPTN' AND UNIT = 'NR' AND SEX = 'TOTAL' AND AGE = 'Y20-64'
    ),
    emp2064 AS (
      SELECT NUTSCODE, YEAR, LEVEL, VERSIONS, VALUE AS EMP2064_THS
      FROM ardeco_data
      WHERE VARIABLE = 'RNECN' AND UNIT = 'THS' AND SEX = 'TOTAL' AND AGE = 'Y20-64'
    )
    SELECT p.NUTSCODE, p.YEAR, p.LEVEL, p.VERSIONS,
           p.POP2064_THS,
           e.EMP2064_THS,
           (p.POP2064_THS - e.EMP2064_THS)                     AS NOCC2064_THS,
           (p.POP2064_THS - e.EMP2064_THS) / p.POP2064_THS * 100 AS NOCC2064_RATE
    FROM pop2064 p
    INNER JOIN emp2064 e
      ON e.NUTSCODE = p.NUTSCODE AND e.YEAR = p.YEAR AND e.LEVEL = p.LEVEL
     AND e.VERSIONS IS NOT DISTINCT FROM p.VERSIONS
    "
  )

  n_nocc2064 <- dbGetQuery(duck_con, "SELECT COUNT(*) n FROM calc_nocc2064")$n
  if (n_nocc2064 < 0.95 * min(n_pop2064, n_emp2064)) {
    log_warn(
      "derive",
      sprintf(
        paste0(
          "ZNOCC2064: solo %d righe calcolate a fronte di un input piu' ",
          "scarso di %d righe - possibile mismatch di chiavi"
        ),
        n_nocc2064,
        min(n_pop2064, n_emp2064)
      )
    )
  } else {
    log_info(
      "derive",
      sprintf("ZNOCC2064/ZTNOCC2064: %d righe calcolate", n_nocc2064)
    )
  }

  dbExecute(
    duck_con,
    "
    INSERT INTO ardeco_data
      (VARIABLE, VERSIONS, LEVEL, NUTSCODE, YEAR, UNIT, VALUE, SEX, AGE, SECTOR, ISCED11, THEMATIC_GROUP)
    SELECT 'ZNOCC2064', VERSIONS, LEVEL, NUTSCODE, YEAR, 'THS', NOCC2064_THS,
           'TOTAL', 'Y20-64', NULL, NULL, 'mercato_lavoro'
    FROM calc_nocc2064
    "
  )
  dbExecute(
    duck_con,
    "
    INSERT INTO ardeco_data
      (VARIABLE, VERSIONS, LEVEL, NUTSCODE, YEAR, UNIT, VALUE, SEX, AGE, SECTOR, ISCED11, THEMATIC_GROUP)
    SELECT 'ZTNOCC2064', VERSIONS, LEVEL, NUTSCODE, YEAR, 'PC', NOCC2064_RATE,
           'TOTAL', 'Y20-64', NULL, NULL, 'mercato_lavoro'
    FROM calc_nocc2064
    "
  )
  dbExecute(duck_con, "DROP TABLE IF EXISTS calc_nocc2064")

  # -- registrazione sintetica in download_log per visibilita' operativa -
  derived_log <- data.table(
    var_code = c("ZINACT15", "ZTINACT15", "ZNOCC2064", "ZTNOCC2064"),
    group = "mercato_lavoro",
    n_rows = as.integer(c(n_inact15, n_inact15, n_nocc2064, n_nocc2064)),
    status = "DERIVED",
    elapsed_sec = 0
  )
  summary_log <- rbindlist(list(summary_log, derived_log), use.names = TRUE)
  log_info(
    "derive",
    sprintf(
      "Indicatori derivati: %d righe totali aggiunte a download_log",
      nrow(derived_log)
    )
  )

  # 6a3. Duplicazione totale settoriale (SECTOR='TOTAL') -----
  # 10 variabili scaricano solo la ripartizione NACE (SECTOR = 13 codici,
  # senza aggregato "tutti i settori" nella propria serie). Il totale
  # esiste gia', pubblicato sotto un nome diverso (la variabile "sibling"
  # non scomposta per settore). Verificato live (ITC4, versione 2024):
  # sommare i 10 settori del partizionamento standard ESA/Eurostat
  # (A, B-E, F, G-I, J, K, L, M_N, O-Q, R-U) NON riproduce sempre il
  # sibling: coincide esattamente per le variabili nominali, ma diverge
  # (fino a diversi punti percentuali) per SUKCZ (residuo non allocato)
  # e per le 4 variabili a prezzi costanti/volume concatenato (non
  # additivita' dei volumi concatenati, fenomeno noto Eurostat/OCSE, non
  # un errore). Percio' il totale NON viene calcolato per somma: viene
  # COPIATO cosi' com'e' dalla riga del sibling, garantendo coerenza
  # byte-per-byte con il dato gia' pubblicato altrove. Va PRIMA di 6b
  # cosi' che il controllo generico di invarianza spaziale copra anche
  # queste righe, per lo stesso motivo di 6a2.
  #
  # THEMATIC_GROUP: NON viene copiato dal sibling (per SNETZ/RNLHZ il
  # sibling appartiene a un gruppo tematico diverso, "mercato_lavoro",
  # mentre SNETZ/RNLHZ appartengono a "occupazione_settore" - vedi
  # thematic_groups) - si usa invece var_to_group[[zv]], cosi' le nuove
  # righe SECTOR='TOTAL' restano coerenti con le altre righe della
  # stessa variabile Z.

  log_step(
    "derive",
    "Duplicazione totale settoriale (SECTOR='TOTAL') per variabili NACE"
  )

  sector_total_pairs <- data.table(
    z_var = c(
      "SNETZ",
      "RNLHZ",
      "SUVGZ",
      "SOVGZ",
      "RUWCZ",
      "ROWCZ",
      "RUIGZ",
      "ROIGZ",
      "SUKCZ",
      "SOKCZ"
    ),
    total_var = c(
      "SNETD",
      "RNLHT",
      "SUVGE",
      "SOVGE",
      "RUWCD",
      "ROWCD",
      "RUIGT",
      "ROIGT",
      "SUKCT",
      "SOKCT"
    )
  )

  for (i in seq_len(nrow(sector_total_pairs))) {
    zv <- sector_total_pairs$z_var[i]
    tv <- sector_total_pairs$total_var[i]
    tg <- var_to_group[[zv]]

    n_sibling <- dbGetQuery(
      duck_con,
      sprintf("SELECT COUNT(*) AS n FROM ardeco_data WHERE VARIABLE = '%s'", tv)
    )$n

    dbExecute(
      duck_con,
      sprintf(
        "
        INSERT INTO ardeco_data
          (VARIABLE, VERSIONS, LEVEL, NUTSCODE, YEAR, UNIT, VALUE, SEX, AGE, SECTOR, ISCED11, THEMATIC_GROUP)
        SELECT '%s', VERSIONS, LEVEL, NUTSCODE, YEAR, UNIT, VALUE, SEX, AGE, 'TOTAL', ISCED11, '%s'
        FROM ardeco_data
        WHERE VARIABLE = '%s'
        ",
        zv,
        tg,
        tv
      )
    )

    n_copied <- dbGetQuery(
      duck_con,
      sprintf(
        "SELECT COUNT(*) AS n FROM ardeco_data WHERE VARIABLE = '%s' AND SECTOR = 'TOTAL'",
        zv
      )
    )$n

    if (n_copied != n_sibling) {
      log_warn(
        "derive",
        sprintf(
          paste0(
            "%s<-%s: righe copiate (%d) diverse dalle righe sorgente (%d) - ",
            "possibile problema di allineamento NUTSCODE/YEAR/LEVEL/VERSIONS/UNIT"
          ),
          zv,
          tv,
          n_copied,
          n_sibling
        )
      )
    } else {
      log_info(
        "derive",
        sprintf(
          "%s: aggiunte %d righe SECTOR='TOTAL' copiate da %s (gruppo %s)",
          zv,
          n_copied,
          tv,
          tg
        )
      )
    }
  }

  # 6b. Rimozione invarianza spaziale LEVEL=3 vs LEVEL=2 -----
  # Per alcune variabili ARDECO i valori NUTS3 (province) sono duplicati
  # esatti del valore del NUTS2 padre (LEFT(NUTSCODE, 4)) per una data
  # combinazione VARIABLE+UNIT+YEAR+SEX+AGE+SECTOR+ISCED11: falsa
  # granularita' provinciale, non dato reale. Puo' essere strutturale
  # (es. ROWCDH, quasi tutta la serie storica) o limitata agli ultimi
  # anni (es. SNPCNP, solo 2025-2026: il JRC non ha ancora nowcast/
  # proiezioni a livello di provincia e replica l'aggregato regionale
  # su ogni provincia figlia).
  #
  # Regola: per ogni gruppo (VARIABLE, VERSIONS, UNIT, YEAR, SEX, AGE,
  # SECTOR, ISCED11, NUTS2 padre) con almeno 3 righe LEVEL=3 associate,
  # se TUTTE hanno VALUE identico (tolleranza 1e-6) al VALUE della riga
  # LEVEL=2 padre, le righe LEVEL=3 sono duplicati e vengono rimosse.
  # La riga LEVEL=2 non viene MAI toccata (a differenza della vecchia
  # DELETE hardcoded su ROWCDH/EUR2020, che cancellava anche il dato
  # regionale legittimo).
  #
  # Soglia minima 3 province: con 1-2 sole province una coincidenza
  # numerica non e' escludibile; da 3 in su la probabilita' che tutte
  # coincidano per caso e' trascurabile. Il conteggio non e' hardcoded
  # sul numero "atteso" di province (varia da paese a paese e dipende
  # da cfg$nutscode/cfg$level), ma calcolato dinamicamente dal COUNT(*)
  # effettivo del gruppo.
  #
  # Limite noto: il controllo e' scoped a LEVEL=2 vs LEVEL=3, coerente
  # con cfg$level = "2,3" (default). Se in futuro la pipeline scaricasse
  # anche LEVEL=0/1, andrebbe generalizzato a ogni coppia di livelli
  # adiacenti effettivamente presente in ardeco_data.

  dbExecute(duck_con, "DROP TABLE IF EXISTS invariant_groups")
  dbExecute(
    duck_con,
    "
    CREATE TEMP TABLE invariant_groups AS
    WITH province_parent AS (
      SELECT
        p.VARIABLE, p.VERSIONS, p.UNIT, p.YEAR,
        p.SEX, p.AGE, p.SECTOR, p.ISCED11,
        p.NUTSCODE          AS PROVINCE_NUTSCODE,
        LEFT(p.NUTSCODE, 4) AS PARENT_NUTSCODE,
        p.VALUE             AS PROVINCE_VALUE
      FROM ardeco_data p
      WHERE p.LEVEL = 3
    ),
    matched AS (
      SELECT
        pp.*,
        (ABS(pp.PROVINCE_VALUE - r.VALUE) <= 1e-6) AS is_match
      FROM province_parent pp
      INNER JOIN ardeco_data r
        ON r.LEVEL    = 2
       AND r.VARIABLE = pp.VARIABLE
       AND r.NUTSCODE = pp.PARENT_NUTSCODE
       AND r.YEAR     = pp.YEAR
       AND r.UNIT     IS NOT DISTINCT FROM pp.UNIT
       AND r.VERSIONS IS NOT DISTINCT FROM pp.VERSIONS
       AND r.SEX      IS NOT DISTINCT FROM pp.SEX
       AND r.AGE      IS NOT DISTINCT FROM pp.AGE
       AND r.SECTOR   IS NOT DISTINCT FROM pp.SECTOR
       AND r.ISCED11  IS NOT DISTINCT FROM pp.ISCED11
    )
    SELECT
      VARIABLE, VERSIONS, UNIT, YEAR, SEX, AGE, SECTOR, ISCED11,
      PARENT_NUTSCODE,
      COUNT(*)                                  AS n_provinces,
      SUM(CASE WHEN is_match THEN 1 ELSE 0 END) AS n_matching
    FROM matched
    GROUP BY VARIABLE, VERSIONS, UNIT, YEAR, SEX, AGE, SECTOR, ISCED11,
             PARENT_NUTSCODE
    HAVING COUNT(*) >= 3
       AND SUM(CASE WHEN is_match THEN 1 ELSE 0 END) = COUNT(*)
    "
  )

  invariant_summary <- dbGetQuery(
    duck_con,
    "
    SELECT VARIABLE, UNIT, MIN(YEAR) AS y0, MAX(YEAR) AS y1,
           COUNT(DISTINCT YEAR) AS n_years,
           SUM(n_provinces)     AS n_rows
    FROM invariant_groups
    GROUP BY VARIABLE, UNIT
    ORDER BY VARIABLE, UNIT
    "
  )

  if (nrow(invariant_summary) > 0L) {
    for (i in seq_len(nrow(invariant_summary))) {
      r <- invariant_summary[i, ]
      yr_txt <- if (r$y0 == r$y1) {
        as.character(r$y0)
      } else {
        sprintf("%d-%d", r$y0, r$y1)
      }
      log_warn(
        "download",
        sprintf(
          paste0(
            "Invarianza spaziale rilevata: %s/%s, anni %s (%d anno/i): ",
            "%d record LEVEL=3 duplicati del NUTS2 padre saranno ",
            "rimossi (valore LEVEL=2 preservato)"
          ),
          r$VARIABLE,
          r$UNIT,
          yr_txt,
          r$n_years,
          r$n_rows
        )
      )
    }
  } else {
    log_info(
      "download",
      "Nessuna invarianza spaziale LEVEL=3 vs LEVEL=2 rilevata"
    )
  }

  n_del <- dbExecute(
    duck_con,
    "
    DELETE FROM ardeco_data AS d
    WHERE d.LEVEL = 3
      AND EXISTS (
        SELECT 1 FROM invariant_groups g
        WHERE g.VARIABLE        = d.VARIABLE
          AND g.PARENT_NUTSCODE = LEFT(d.NUTSCODE, 4)
          AND g.YEAR            = d.YEAR
          AND g.UNIT            IS NOT DISTINCT FROM d.UNIT
          AND g.VERSIONS        IS NOT DISTINCT FROM d.VERSIONS
          AND g.SEX             IS NOT DISTINCT FROM d.SEX
          AND g.AGE             IS NOT DISTINCT FROM d.AGE
          AND g.SECTOR          IS NOT DISTINCT FROM d.SECTOR
          AND g.ISCED11         IS NOT DISTINCT FROM d.ISCED11
      )
    "
  )
  log_info(
    "download",
    sprintf(
      "Rimossi %d record invarianti LEVEL=3 (duplicati del NUTS2 padre)",
      n_del
    )
  )
  if (
    nrow(invariant_summary) > 0L &&
      n_del != sum(invariant_summary$n_rows)
  ) {
    log_warn(
      "download",
      sprintf(
        "Discrepanza conteggio invarianza: attesi %d record, rimossi %d",
        sum(invariant_summary$n_rows),
        n_del
      )
    )
  }

  dbExecute(duck_con, "DROP TABLE IF EXISTS invariant_groups")

  dbExecute(duck_con, "CREATE INDEX idx_variable ON ardeco_data (VARIABLE)")
  dbExecute(
    duck_con,
    "CREATE INDEX idx_nuts_year ON ardeco_data (NUTSCODE, YEAR)"
  )

  dbWriteTable(duck_con, "var_labels", var_labels, overwrite = TRUE)
  dbWriteTable(duck_con, "unit_labels", unit_labels, overwrite = TRUE)
  dbWriteTable(duck_con, "sex_labels", sex_labels, overwrite = TRUE)
  dbWriteTable(duck_con, "age_labels", age_labels, overwrite = TRUE)
  dbWriteTable(duck_con, "sector_labels", sector_labels, overwrite = TRUE)
  dbWriteTable(duck_con, "group_labels", group_labels, overwrite = TRUE)
  dbWriteTable(duck_con, "download_log", summary_log, overwrite = TRUE)

  total_elapsed <- (proc.time() - t0_total)[["elapsed"]]
  n_ok <- summary_log[status == "OK", .N]
  n_failed <- summary_log[status == "FAILED", .N]
  log_info(
    "download",
    sprintf(
      "Totali: %d OK, %d FAILED su %d variabili (%.0fs)",
      n_ok,
      n_failed,
      length(all_vars),
      total_elapsed
    )
  )

  # 7. Verifica integrit\u00e0 -----
  log_step("verify", "Controlli di integrit\u00e0 su staging DuckDB")

  n_rows <- dbGetQuery(duck_con, "SELECT COUNT(*) AS n FROM ardeco_data")$n
  n_vars <- dbGetQuery(
    duck_con,
    "SELECT COUNT(DISTINCT VARIABLE) AS n FROM ardeco_data"
  )$n
  yr_rng <- dbGetQuery(
    duck_con,
    "SELECT MIN(YEAR) AS y0, MAX(YEAR) AS y1 FROM ardeco_data"
  )

  if (n_rows == 0L) {
    dbDisconnect(duck_con, shutdown = TRUE)
    fatal("verify", "ardeco_data vuoto dopo il download")
  }
  log_info(
    "verify",
    sprintf("ardeco_data: %d righe, %d variabili distinte", n_rows, n_vars)
  )
  log_info("verify", sprintf("Intervallo anni: %d-%d", yr_rng$y0, yr_rng$y1))

  current_year <- as.integer(format(Sys.Date(), "%Y"))
  if (yr_rng$y0 < 1960L || yr_rng$y1 > current_year + 1L) {
    log_warn(
      "verify",
      sprintf(
        "YEAR fuori intervallo atteso (1960..%d)",
        current_year + 1L
      )
    )
  }

  downloaded_vars <- dbGetQuery(
    duck_con,
    "SELECT DISTINCT VARIABLE FROM ardeco_data"
  )$VARIABLE
  missing_labels <- setdiff(downloaded_vars, var_labels$var_code)
  if (length(missing_labels) > 0L) {
    dbDisconnect(duck_con, shutdown = TRUE)
    fatal(
      "verify",
      sprintf(
        "Variabili senza etichetta in var_labels: %s",
        paste(missing_labels, collapse = ", ")
      )
    )
  }

  label_tables <- c(
    "var_labels",
    "unit_labels",
    "sex_labels",
    "age_labels",
    "sector_labels",
    "group_labels"
  )
  for (lt in label_tables) {
    n <- dbGetQuery(duck_con, sprintf("SELECT COUNT(*) AS n FROM %s", lt))$n
    if (n == 0L) {
      dbDisconnect(duck_con, shutdown = TRUE)
      fatal("verify", sprintf("Tabella label %s vuota", lt))
    }
  }

  # Soglia di sicurezza: anche una sola variabile fallita dopo tutti i
  # tentativi di retry (vedi download_variable) blocca la pipeline prima
  # dello swap in produzione. Un fallimento a questo punto non e' piu'
  # un blip transitorio (gia' assorbito dal retry), quindi non va
  # propagato silenziosamente allo schema PostgreSQL di produzione.
  if (n_failed > 0L) {
    failed_vars <- summary_log[status == "FAILED", var_code]
    dbDisconnect(duck_con, shutdown = TRUE)
    fatal(
      "verify",
      sprintf(
        "%d/%d variabili non scaricate dopo tutti i tentativi di retry: %s. Swap in produzione annullato.",
        n_failed,
        length(all_vars),
        paste(failed_vars, collapse = ", ")
      )
    )
  }

  # 8. Connessione PostgreSQL con retry -----
  log_step("pg-conn", "Connessione PostgreSQL")

  pg_connect <- function() {
    delays <- c(0, 5, 15)
    for (i in seq_along(delays)) {
      if (delays[i] > 0) {
        log_warn("pg-conn", sprintf("Retry %d dopo %ds", i - 1L, delays[i]))
        Sys.sleep(delays[i])
      }
      conn <- tryCatch(
        dbConnect(
          RPostgres::Postgres(),
          host = cfg$pg_host,
          port = as.integer(cfg$pg_port),
          dbname = cfg$pg_dbname,
          user = cfg$pg_user,
          password = cfg$pg_password
        ),
        error = function(e) {
          log_warn(
            "pg-conn",
            sprintf("Tentativo %d fallito: %s", i, conditionMessage(e))
          )
          NULL
        }
      )
      if (!is.null(conn)) return(conn)
    }
    NULL
  }

  pg_con <- pg_connect()
  if (is.null(pg_con)) {
    dbDisconnect(duck_con, shutdown = TRUE)
    fatal("pg-conn", "Connessione PostgreSQL fallita dopo 3 tentativi")
  }
  log_info(
    "pg-conn",
    sprintf("Connesso a %s:%s/%s", cfg$pg_host, cfg$pg_port, cfg$pg_dbname)
  )

  stg_schema <- paste0(cfg$pg_schema, "_stg")
  old_schema <- sprintf(
    "%s_old_%s",
    cfg$pg_schema,
    format(Sys.time(), "%Y%m%d_%H%M%S")
  )

  # 9. Scrittura su schema staging -----
  log_step("pg-write", sprintf("Scrittura su schema staging %s", stg_schema))

  qi <- function(x) DBI::dbQuoteIdentifier(pg_con, x)
  dbExecute(pg_con, sprintf("DROP SCHEMA IF EXISTS %s CASCADE", qi(stg_schema)))
  dbExecute(pg_con, sprintf("CREATE SCHEMA %s", qi(stg_schema)))

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

  for (tbl in tables_to_export) {
    dt <- as.data.table(dbReadTable(duck_con, tbl))
    dbWriteTable(
      pg_con,
      DBI::Id(schema = stg_schema, table = tbl),
      dt,
      overwrite = TRUE
    )
    log_info("pg-write", sprintf("%s: %d righe", tbl, nrow(dt)))
  }

  # 10. Indici -----
  log_step("pg-index", "Creazione indici su staging")
  dbExecute(
    pg_con,
    sprintf(
      'CREATE INDEX idx_ardeco_variable ON %s.ardeco_data ("VARIABLE")',
      qi(stg_schema)
    )
  )
  dbExecute(
    pg_con,
    sprintf(
      'CREATE INDEX idx_ardeco_nuts_year ON %s.ardeco_data ("NUTSCODE", "YEAR")',
      qi(stg_schema)
    )
  )
  log_info("pg-index", "Indici creati")

  # 11. Verifica row count PG vs DuckDB -----
  log_step("pg-verify", "Confronto row count DuckDB vs PostgreSQL")

  mismatches <- character(0)
  for (tbl in tables_to_export) {
    n_duck <- as.integer(
      dbGetQuery(
        duck_con,
        sprintf("SELECT COUNT(*) AS n FROM %s", tbl)
      )$n
    )
    n_pg <- as.integer(
      dbGetQuery(
        pg_con,
        sprintf(
          "SELECT COUNT(*) AS n FROM %s.%s",
          qi(stg_schema),
          qi(tbl)
        )
      )$n
    )
    status <- if (n_duck == n_pg) "OK" else "ERRORE"
    log_info(
      "pg-verify",
      sprintf("%-20s | duck=%7d | pg=%7d | %s", tbl, n_duck, n_pg, status)
    )
    if (status != "OK") mismatches <- c(mismatches, tbl)
  }
  if (length(mismatches) > 0L) {
    dbDisconnect(pg_con)
    dbDisconnect(duck_con, shutdown = TRUE)
    fatal(
      "pg-verify",
      sprintf(
        "Discrepanza row count: %s. Swap annullato.",
        paste(mismatches, collapse = ", ")
      )
    )
  }

  # 12. Swap atomico degli schemi -----
  log_step(
    "pg-swap",
    sprintf(
      "Swap schemi: %s -> %s (old=%s)",
      stg_schema,
      cfg$pg_schema,
      old_schema
    )
  )

  prod_exists <- dbGetQuery(
    pg_con,
    sprintf(
      "SELECT 1 FROM information_schema.schemata WHERE schema_name = %s",
      DBI::dbQuoteString(pg_con, cfg$pg_schema)
    )
  )

  dbBegin(pg_con)
  swap_ok <- tryCatch(
    {
      if (nrow(prod_exists) > 0L) {
        dbExecute(
          pg_con,
          sprintf(
            "ALTER SCHEMA %s RENAME TO %s",
            qi(cfg$pg_schema),
            qi(old_schema)
          )
        )
      }
      dbExecute(
        pg_con,
        sprintf(
          "ALTER SCHEMA %s RENAME TO %s",
          qi(stg_schema),
          qi(cfg$pg_schema)
        )
      )
      dbCommit(pg_con)
      TRUE
    },
    error = function(e) {
      dbRollback(pg_con)
      log_error("pg-swap", sprintf("Swap fallito: %s", conditionMessage(e)))
      FALSE
    }
  )
  if (!swap_ok) {
    dbDisconnect(pg_con)
    dbDisconnect(duck_con, shutdown = TRUE)
    fatal("pg-swap", "Transazione di swap annullata")
  }
  log_info("pg-swap", sprintf("Schema %s ora in produzione", cfg$pg_schema))

  if (nrow(prod_exists) > 0L) {
    dbExecute(pg_con, sprintf("DROP SCHEMA %s CASCADE", qi(old_schema)))
    log_info("pg-swap", sprintf("Schema precedente rimosso: %s", old_schema))
  }

  # 13. Cleanup -----
  log_step("cleanup", "Chiusura connessioni e rimozione staging")
  dbDisconnect(pg_con)
  dbDisconnect(duck_con, shutdown = TRUE)
  if (file.exists(cfg$staging)) {
    file.remove(cfg$staging)
    log_info("cleanup", sprintf("Rimosso staging DuckDB: %s", cfg$staging))
  }

  total_elapsed_all <- (proc.time() - t0_total)[["elapsed"]]
  log_info(
    "done",
    sprintf(
      "Pipeline completata: %d righe, %d OK / %d FAILED, %.0fs totali",
      n_rows,
      n_ok,
      n_failed,
      total_elapsed_all
    )
  )
}

# Top-level tryCatch: errori non gestiti -> exit 1
tryCatch(
  run_pipeline(),
  error = function(e) {
    log_error("fatal", sprintf("Errore non gestito: %s", conditionMessage(e)))
    quit(status = 1L, save = "no")
  }
)

quit(status = 0L, save = "no")
