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
    # Mercato del lavoro (15)
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
    "Popolazione inattiva di 15 anni e oltre, calcolata come popolazione 15+ (SNPTN, totale meno la fascia Y_LT15) meno la forza lavoro 15+ (RNLCN). Indicatore derivato, non presente nel dataset ARDECO.",
    "Tasso di inattivit\u00e0 15+, calcolato come rapporto percentuale tra popolazione inattiva 15+ (ZINACT15) e popolazione 15+. Indicatore derivato, non presente nel dataset ARDECO.",
    "Popolazione non occupata in et\u00e0 20-64 anni, calcolata come popolazione 20-64 (SNPTN, fascia Y20-64) meno occupati 20-64 (RNECN, fascia Y20-64). Include sia disoccupati sia inattivi. Indicatore derivato, non presente nel dataset ARDECO.",
    "Tasso di non occupazione 20-64 anni, calcolato come rapporto percentuale tra popolazione non occupata 20-64 (ZNOCC2064) e popolazione 20-64. Indicatore derivato, non presente nel dataset ARDECO.",
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
  ),
  help_it = c(
    # Popolazione e demografia (12)
    "Rappresenta la popolazione di riferimento per calcolare gli indicatori pro capite (PIL, occupazione, compensi) e va letta come base demografica dell\u2019anno, non come stock puntuale. \u00c8 espressa in numero di persone (unit\u00e0 NR): un aumento indica crescita demografica, una diminuzione spopolamento o saldo migratorio negativo. Va confrontata con \u00abPopolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso\u00bb e \u00abPopolazione al 1\u00b0 gennaio per classi quinquennali e sesso\u00bb, tenendo conto che quelle sono uno stock a una data precisa, non una media.",
    "Fotografia della popolazione residente a inizio anno, disaggregata per grandi fasce d\u2019et\u00e0 e sesso (valori in numero di persone, unit\u00e0 NR): utile per costruire piramidi demografiche o tassi di dipendenza per fascia. Va letta come stock, non come flusso: le variazioni tra un anno e l\u2019altro derivano dalla combinazione di natalit\u00e0, mortalit\u00e0 e migrazione (si vedano \u00abVariazione naturale della popolazione\u00bb e \u00abMigrazione netta per fascia d\u2019et\u00e0 e sesso\u00bb).",
    "Stessa logica di \u00abPopolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso\u00bb, ma con dettaglio per classi quinquennali (0-4, 5-9, \u2026), utile per analisi di invecchiamento della popolazione o per stimare con precisione la popolazione in et\u00e0 lavorativa. Valori in numero di persone (NR). La somma delle classi quinquennali deve coincidere con il totale TOTAL della stessa fascia in \u00abPopolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso\u00bb; scostamenti segnalano filtri applicati in fase di estrazione.",
    "Flusso annuale delle nascite, disaggregato per sesso (unit\u00e0 NR). Va letto insieme a \u00abDecessi per fascia d\u2019et\u00e0 e sesso\u00bb per ricavare il saldo naturale (\u00abVariazione naturale della popolazione\u00bb = nati vivi meno decessi); da solo indica solo la natalit\u00e0 e non il tasso di crescita della popolazione. Un valore in calo prolungato \u00e8 tipico segnale di invecchiamento strutturale, non necessariamente di crisi demografica improvvisa.",
    "Flusso annuale dei decessi per grandi fasce d\u2019et\u00e0 e sesso (unit\u00e0 NR). Va interpretato tenendo conto della struttura per et\u00e0 della popolazione di riferimento (\u00abPopolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso\u00bb): un aumento dei decessi assoluti pu\u00f2 riflettere semplicemente l\u2019invecchiamento della popolazione pi\u00f9 che un peggioramento della mortalit\u00e0. Utile in combinazione con \u00abNati vivi per sesso\u00bb per il saldo naturale.",
    "Come \u00abDecessi per fascia d\u2019et\u00e0 e sesso\u00bb ma con dettaglio quinquennale, utile per calcolare tassi di mortalit\u00e0 specifici per et\u00e0 se rapportato a \u00abPopolazione al 1\u00b0 gennaio per classi quinquennali e sesso\u00bb. Valori in numero di persone (NR). Le classi pi\u00f9 anziane concentrano la maggior parte dei decessi in condizioni demografiche normali: valori elevati nelle classi giovani segnalano eventi eccezionali pi\u00f9 che rumore statistico.",
    "Indicatore derivato (nati vivi meno decessi, \u00abNati vivi per sesso\u00bb meno \u00abDecessi per fascia d\u2019et\u00e0 e sesso\u00bb), non scaricato direttamente da Eurostat. Un valore positivo indica saldo naturale positivo (pi\u00f9 nascite che decessi), negativo un saldo naturale negativo, condizione ormai diffusa in gran parte delle regioni italiane. Va letto insieme a \u00abMigrazione netta per fascia d\u2019et\u00e0 e sesso\u00bb: la variazione totale della popolazione (\u00abVariazione della popolazione per fascia d\u2019et\u00e0 e sesso\u00bb) \u00e8 la somma dei due componenti.",
    "Indicatore derivato calcolato come differenza tra variazione totale della popolazione e variazione naturale, per fascia d\u2019et\u00e0 e sesso. Un valore positivo indica saldo migratorio netto in ingresso, negativo un saldo in uscita. Essendo un residuo di calcolo, ne eredita eventuali discontinuit\u00e0 statistiche presenti nei dati di popolazione di partenza (es. revisioni censuarie): variazioni brusche da un anno all\u2019altro vanno verificate prima di essere interpretate come fenomeni migratori reali.",
    "Indicatore derivato: variazione totale della popolazione (naturale pi\u00f9 migratoria) per fascia d\u2019et\u00e0 e sesso, disponibile sia in numero di persone (NR) sia come tasso di crescita (unit\u00e0 GROWRT, per mille). Un valore positivo segnala crescita della fascia, negativo contrazione; usare la versione GROWRT per confronti tra territori di dimensione demografica molto diversa, la versione NR per quantificare l\u2019impatto assoluto.",
    "Variante normalizzata di \u00abVariazione della popolazione per fascia d\u2019et\u00e0 e sesso\u00bb, espressa per 1000 abitanti: permette il confronto diretto tra territori di dimensione diversa senza normalizzazioni manuali. Valori vicini allo zero indicano popolazione stabile; valori negativi persistenti nel tempo segnalano un territorio in spopolamento strutturale.",
    "Come \u00abMigrazione netta per fascia d\u2019et\u00e0 e sesso\u00bb ma normalizzata per 1000 abitanti, quindi direttamente confrontabile tra province o regioni di dimensione diversa. Valori positivi indicano attrattivit\u00e0 migratoria netta del territorio, negativi un saldo migratorio sfavorevole; va letta insieme al saldo naturale per capire se la dinamica demografica complessiva (\u00abVariazione della popolazione per 1000 abitanti\u00bb) \u00e8 trainata da nascite/decessi o da movimenti migratori.",
    "Rapporto tra popolazione non in et\u00e0 lavorativa (0-19 e 65+) e popolazione in et\u00e0 lavorativa (20-64), espresso in percentuale (unit\u00e0 PC). Valori pi\u00f9 alti indicano un maggior carico teorico sulla popolazione attiva; valori superiori al 50-60% sono tipici di territori con forte invecchiamento. \u00c8 un indicatore strutturale, da leggere in serie storica pi\u00f9 che nel singolo anno.",
    # Mercato del lavoro (15)
    "Numero di occupati nel luogo di lavoro (non di residenza), secondo la definizione dei conti nazionali, in migliaia di persone (unit\u00e0 THS). \u00c8 l\u2019occupazione \u201cprodotta\u201d dal territorio, utile per misurare l\u2019attrattivit\u00e0 economica di un\u2019area (poli industriali, citt\u00e0 con forte pendolarismo in entrata); si differenzia concettualmente da una misura residence-based, che conterebbe gli occupati residenti indipendentemente da dove lavorano (si veda \u00abOccupati per et\u00e0 e sesso\u00bb).",
    "Indicatore derivato: rapporto tra \u00abOccupazione workplace-based\u00bb (in migliaia di persone) e \u00abPopolazione media annua\u00bb, espresso come numero puro (unit\u00e0 NR, tipicamente tra 0 e 1). Valori pi\u00f9 alti indicano un territorio con forte capacit\u00e0 di attrarre occupazione rispetto alla propria popolazione residente (poli industriali o direzionali); valori bassi un\u2019area prevalentemente residenziale.",
    "Sottoinsieme dell\u2019\u00abOccupazione workplace-based\u00bb relativo ai soli lavoratori subordinati nel territorio, in migliaia di persone (unit\u00e0 THS). La differenza rispetto all\u2019occupazione complessiva approssima il lavoro autonomo/indipendente localizzato nell\u2019area; un\u2019incidenza dei dipendenti elevata sul totale degli occupati segnala un tessuto produttivo orientato al lavoro dipendente pi\u00f9 che al lavoro autonomo.",
    "Occupazione residence-based (occupati indipendentemente da dove lavorano) per fascia d\u2019et\u00e0 20-64 e sesso, in migliaia di persone (unit\u00e0 THS), fonte EU-LFS. Diversamente dall\u2019\u00abOccupazione workplace-based\u00bb, qui l\u2019occupato \u00e8 conteggiato nel territorio di residenza: utile per misurare la partecipazione al lavoro della popolazione residente, non l\u2019attrattivit\u00e0 occupazionale del territorio.",
    "Numero di persone in cerca di occupazione in et\u00e0 15-74 anni, in migliaia (unit\u00e0 THS), dato definito \u201csperimentale\u201d da Eurostat alla scala regionale: va usato con cautela nei confronti puntuali anno su anno, meglio leggerlo in tendenza pluriennale o insieme al \u00abTasso di disoccupazione (15-74 anni)\u00bb che ne attenua l\u2019effetto delle revisioni campionarie.",
    "Somma di occupati e disoccupati (offerta di lavoro) per la popolazione di 15 anni e oltre, in migliaia di persone (unit\u00e0 THS). \u00c8 il denominatore concettuale del \u00abTasso di disoccupazione (15-74 anni)\u00bb, calcolato come quota di \u00abDisoccupati\u00bb sulla forza lavoro: una crescita della forza lavoro senza corrispondente crescita occupazionale fa aumentare il tasso di disoccupazione anche a parit\u00e0 di occupati.",
    "Totale delle ore lavorate da tutte le persone occupate nell\u2019anno, in migliaia di ore (unit\u00e0 THS_HW). Da preferire all\u2019\u00abOccupazione workplace-based\u00bb quando si vuole tenere conto anche della variazione di orario medio (part-time, cassa integrazione, straordinari), non solo del numero di teste occupate; il rapporto tra ore lavorate e occupati approssima le ore medie annue per occupato.",
    "Indicatore derivato: \u00abOre lavorate (occupati)\u00bb rapportate alla \u00abPopolazione media annua\u00bb, espresso come numero puro (unit\u00e0 NR). Sintetizza in un solo valore sia il tasso di occupazione sia l\u2019intensit\u00e0 oraria del lavoro nel territorio; utile per confronti di \u201cvolume di lavoro per abitante\u201d tra aree con strutture occupazionali diverse (es. quota di part-time).",
    "Come le \u00abOre lavorate (occupati)\u00bb ma limitato alle sole ore dei lavoratori dipendenti (unit\u00e0 THS_HW). La sua incidenza sul totale delle ore lavorate indica il peso del lavoro dipendente nel territorio; \u00e8 coerente con i \u00abDipendenti workplace-based\u00bb pi\u00f9 che con gli \u00abOccupati per et\u00e0 e sesso\u00bb (misura residence-based).",
    "Percentuale di occupati sulla popolazione in et\u00e0 20-64 anni (unit\u00e0 PC), l\u2019indicatore standard usato nei target europei (es. Strategia Europa 2020/2030). Valori pi\u00f9 alti indicano maggiore partecipazione al mercato del lavoro della popolazione in et\u00e0 attiva; va confrontato con il dato nazionale/europeo di riferimento pi\u00f9 che letto in valore assoluto, e risente di composizione demografica e strutture familiari locali.",
    "Percentuale di disoccupati sulla forza lavoro in et\u00e0 15-74 anni (unit\u00e0 PC), dato sperimentale a livello regionale: le oscillazioni di pochi decimi di punto tra un anno e l\u2019altro possono rientrare nell\u2019errore campionario, quindi va interpretato in tendenza pluriennale. Un valore basso non implica necessariamente alta occupazione: pu\u00f2 riflettere anche bassa partecipazione alla forza lavoro (inattivit\u00e0, scoraggiamento).",
    "Indicatore derivato localmente (prefisso Z, non un codice ARDECO), calcolato come differenza tra la popolazione di 15 anni e oltre (ricavata da \u00abPopolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso\u00bb, SNPTN, sottraendo la fascia under-15 al totale) e la \u00abForza lavoro (15 anni e oltre)\u00bb (RNLCN). Espresso in migliaia di persone (unit\u00e0 THS). Un valore in aumento segnala una quota crescente di popolazione fuori dal mercato del lavoro (studenti, pensionati, scoraggiati); va letto insieme al \u00abTasso di inattivit\u00e0 15+\u00bb per il confronto tra territori di dimensione diversa.",
    "Indicatore derivato localmente (prefisso Z): \u00abPopolazione inattiva 15+\u00bb (ZINACT15) rapportata alla popolazione 15+ sottostante, in percentuale (unit\u00e0 PC). Segue la definizione ILO/Eurostat di inattivit\u00e0, complementare al tasso di occupazione: valori pi\u00f9 alti indicano una quota maggiore di popolazione fuori dal mercato del lavoro (n\u00e9 occupata n\u00e9 in cerca). Va confrontato con il \u00abTasso di occupazione (20-64 anni)\u00bb, di cui non \u00e8 l\u2019esatto complemento perch\u00e9 le fasce d\u2019et\u00e0 di riferimento sono diverse (15+ contro 20-64).",
    "Indicatore derivato localmente (prefisso Z), calcolato come differenza tra popolazione 20-64 anni (da \u00abPopolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso\u00bb, SNPTN) e \u00abOccupati per et\u00e0 e sesso\u00bb (RNECN) nella stessa fascia, in migliaia di persone (unit\u00e0 THS). A differenza di \u00abPopolazione inattiva 15+\u00bb (ZINACT15), qui il residuo comprende sia i disoccupati sia gli inattivi, perch\u00e9 RNUTN non \u00e8 disponibile disaggregato per fascia d\u2019et\u00e0: non va quindi interpretato come una misura pura di inattivit\u00e0, ma come popolazione 20-64 anni fuori dall\u2019occupazione in senso lato.",
    "Indicatore derivato localmente (prefisso Z): \u00abPopolazione non occupata 20-64 anni\u00bb (ZNOCC2064) rapportata alla popolazione 20-64 sottostante, in percentuale (unit\u00e0 PC). \u00c8 il complemento del \u00abTasso di occupazione (20-64 anni)\u00bb rispetto a 100 (a parit\u00e0 di fascia d\u2019et\u00e0 e fonte), ma non coincide con un tasso di inattivit\u00e0 perch\u00e9 somma disoccupati e inattivi: valori elevati possono riflettere sia difficolt\u00e0 di collocamento sia bassa partecipazione al mercato del lavoro. Per isolare la sola componente di inattivit\u00e0 strutturale usare il \u00abTasso di inattivit\u00e0 15+\u00bb (ZTINACT15), che per\u00f2 copre una fascia d\u2019et\u00e0 diversa (15+ anzich\u00e9 20-64).",
    # Occupazione per settore (2)
    "Occupati workplace-based disaggregati per settore di attivit\u00e0 economica (NACE Rev. 2, 10 settori aggregati), in migliaia di persone (unit\u00e0 THS). La somma dei settori per un dato territorio/anno deve coincidere con il totale dell\u2019\u00abOccupazione workplace-based\u00bb; il peso relativo dei settori (es. quota di industria vs servizi) \u00e8 l\u2019indicatore chiave per leggere la specializzazione produttiva del territorio.",
    "Ore lavorate totali disaggregate per settore NACE (10 settori aggregati), in migliaia di ore (unit\u00e0 THS_HW), con integrazioni JRC rispetto al dato Eurostat grezzo. Va letto come le \u00abOre lavorate (occupati)\u00bb scomposte per settore: utile per capire quali settori assorbono pi\u00f9 ore di lavoro, non necessariamente pi\u00f9 occupati (settori con orari medi pi\u00f9 lunghi pesano di pi\u00f9 qui che nell\u2019\u00abOccupazione per settore NACE\u00bb).",
    # PIL e valore aggiunto (14)
    "PIL a prezzi di mercato dell\u2019anno corrente, in milioni di euro (MIO_EUR) o, per le versioni pi\u00f9 recenti del dataset, anche in milioni di PPS EU27 2020 (MIO_PPS_EU27_2020) per confronti di potere d\u2019acquisto tra paesi. Include l\u2019effetto dell\u2019inflazione: le variazioni anno su anno non separano crescita reale e aumento dei prezzi. Per la crescita reale si veda \u00abPIL a prezzi costanti\u00bb.",
    "PIL depurato dall\u2019inflazione (anno base 2015 o 2020 a seconda della versione, unit\u00e0 MIO_EUR2015/MIO_EUR2020), calcolato applicando i tassi di crescita regionali in volume al livello base. Le variazioni tra anni riflettono la crescita economica reale del territorio: \u00e8 la serie da usare per confronti di crescita nel tempo o tra territori, mentre il \u00abPIL a prezzi correnti\u00bb resta preferibile per rapporti in valore corrente non deflazionato.",
    "Valore aggiunto lordo ai prezzi base (PIL al netto delle imposte nette sui prodotti), a prezzi correnti, in milioni di euro. \u00c8 concettualmente pi\u00f9 vicino alla produzione del sistema economico locale rispetto al PIL, che include anche la componente fiscale; il rapporto tra valore aggiunto e \u00abPIL a prezzi correnti\u00bb \u00e8 tipicamente stabile nel tempo per uno stesso territorio, salvo variazioni della fiscalit\u00e0 indiretta.",
    "Come il \u00abValore aggiunto a prezzi correnti\u00bb ma a prezzi costanti (anno base 2015/2020): misura la crescita reale del valore aggiunto, al netto dell\u2019inflazione. Da usare per il calcolo della produttivit\u00e0 reale (si vedano \u00abProduttivit\u00e0 reale per ora lavorata\u00bb e \u00abProduttivit\u00e0 reale per occupato\u00bb) e per confronti di crescita economica settoriale nel tempo.",
    "Valore aggiunto disaggregato per settore NACE (10 settori aggregati), a prezzi correnti, in milioni di euro. La somma dei settori approssima il \u00abValore aggiunto a prezzi correnti\u00bb complessivo (con eventuali scarti da arrotondamenti o rettifiche non allocate); il peso percentuale dei settori \u00e8 l\u2019indicatore chiave per leggere la struttura produttiva del territorio in termini di valore, non solo di occupati (si confronti con \u00abOccupazione per settore NACE\u00bb).",
    "Come il \u00abValore aggiunto per settore a prezzi correnti\u00bb ma a prezzi costanti: permette di confrontare la crescita reale dei singoli settori nel tempo, isolando l\u2019effetto prezzi, che pu\u00f2 differire molto da settore a settore (es. energia vs servizi).",
    "Indicatore derivato: \u00abPIL a prezzi correnti\u00bb diviso \u00abOre lavorate (occupati)\u00bb, in euro per ora. Misura quanto valore economico corrente viene prodotto in un\u2019ora di lavoro nel territorio; include sia l\u2019effetto di efficienza produttiva reale sia l\u2019effetto dei prezzi/inflazione, quindi non va confuso con la \u00abProduttivit\u00e0 reale per ora lavorata\u00bb.",
    "Come la \u00abProduttivit\u00e0 nominale per ora lavorata\u00bb ma calcolata come \u00abPIL a prezzi correnti\u00bb diviso \u00abOccupazione workplace-based\u00bb anzich\u00e9 diviso ore lavorate, espressa in euro per occupato. Risente anche della quota di part-time e dell\u2019intensit\u00e0 oraria media: due territori con la stessa produttivit\u00e0 oraria possono avere produttivit\u00e0 per occupato diverse se cambia il monte ore medio lavorato a testa.",
    "Come la \u00abProduttivit\u00e0 nominale per ora lavorata\u00bb ma calcolata a prezzi costanti (PIL a prezzi costanti diviso ore lavorate): \u00e8 la misura corretta per confrontare l\u2019efficienza produttiva nel tempo, perch\u00e9 esclude l\u2019effetto dell\u2019inflazione. \u00c8 l\u2019indicatore di riferimento per analisi di produttivit\u00e0 e convergenza economica tra territori.",
    "Come la \u00abProduttivit\u00e0 nominale per occupato\u00bb ma a prezzi costanti (PIL a prezzi costanti diviso occupati): misura la produttivit\u00e0 reale per occupato, comparabile nel tempo. Da leggere insieme alla \u00abProduttivit\u00e0 reale per ora lavorata\u00bb per capire se la dinamica \u00e8 trainata da maggiore efficienza oraria o da un diverso numero di ore lavorate per occupato.",
    "\u00abPIL a prezzi correnti\u00bb diviso \u00abPopolazione media annua\u00bb, in euro per abitante o PPS per abitante a seconda della versione. \u00c8 l\u2019indicatore pi\u00f9 comune per confronti di benessere economico tra territori, ma a prezzi correnti risente sia della crescita reale sia dell\u2019inflazione: per confronti temporali di lungo periodo \u00e8 preferibile il \u00abPIL pro capite a prezzi costanti\u00bb.",
    "Come il \u00abPIL pro capite a prezzi correnti\u00bb ma a prezzi costanti: misura il livello di reddito pro capite reale, al netto dell\u2019inflazione, ed \u00e8 l\u2019indicatore corretto per analisi di convergenza/divergenza economica territoriale nel tempo.",
    "Indice concatenato del PIL in volume (base 2015 = I15 o base 2020 = I20 a seconda della versione) oppure variazione percentuale sull\u2019anno precedente (unit\u00e0 PCH_PRE). Nella forma indice il valore va letto rispetto all\u2019anno base (=100): sopra 100 indica un\u2019economia pi\u00f9 grande in termini reali rispetto all\u2019anno base, sotto 100 una contrazione cumulata. Nella forma PCH_PRE il valore \u00e8 gi\u00e0 il tasso di crescita annuo in percentuale.",
    "Come il \u00abTasso di crescita del PIL (indice concatenato)\u00bb ma riferito al valore aggiunto anzich\u00e9 al PIL: stesse due letture possibili (indice concatenato I15/I20, oppure variazione percentuale annua PCH_PRE). Utile per isolare la dinamica della sola produzione economica dal PIL complessivo, che include anche le imposte nette sui prodotti.",
    # Reddito e compensi (9)
    "Massa salariale totale a prezzi correnti (retribuzioni lorde pi\u00f9 contributi sociali a carico del datore di lavoro), in milioni di euro o milioni di PPS EU27 a seconda della versione. \u00c8 il costo del lavoro complessivo sostenuto nel territorio, non il salario percepito dal singolo lavoratore: per quello si vedano \u00abCompenso nominale per dipendente\u00bb e \u00abCompenso reale per dipendente\u00bb.",
    "Come i \u00abCompensi dei dipendenti a prezzi correnti\u00bb ma a prezzi costanti (anno base 2015/2020): misura la crescita reale della massa salariale, al netto dell\u2019inflazione, utile per confronti di lungo periodo del costo del lavoro complessivo.",
    "Indicatore derivato: \u00abCompensi dei dipendenti a prezzi costanti\u00bb diviso \u00abOre lavorate (dipendenti)\u00bb, in euro reali per ora. Misura la retribuzione oraria media reale nel territorio; da confrontare con la \u00abProduttivit\u00e0 reale per ora lavorata\u00bb per valutare se le retribuzioni seguono la produttivit\u00e0 o se ne discostano.",
    "Indicatore derivato: \u00abCompensi dei dipendenti a prezzi correnti\u00bb diviso \u00abDipendenti workplace-based\u00bb, in euro o PPS per dipendente per anno. \u00c8 la retribuzione media annua lorda per dipendente in valore corrente; non va confusa con lo stipendio mensile netto percepito dal lavoratore, che \u00e8 un concetto diverso e non direttamente ricavabile da questi dati.",
    "Come il \u00abCompenso nominale per dipendente\u00bb ma a prezzi costanti: misura la retribuzione media annua reale per dipendente, al netto dell\u2019inflazione, indicatore corretto per confronti del potere d\u2019acquisto salariale nel tempo.",
    "CLUP (costo del lavoro per unit\u00e0 di prodotto) calcolato come rapporto tra compenso orario nominale e produttivit\u00e0 oraria nominale, in euro. Un CLUP in aumento indica che il costo del lavoro per ora cresce pi\u00f9 della produttivit\u00e0, con possibile perdita di competitivit\u00e0 di costo; un CLUP stabile o in calo indica che i guadagni di produttivit\u00e0 assorbono la dinamica salariale.",
    "Come il \u00abCosto del lavoro per unit\u00e0 di prodotto nominale (ore)\u00bb ma basato sul rapporto tra compenso per dipendente e produttivit\u00e0 per occupato, anzich\u00e9 sulle ore. Le due versioni del CLUP possono divergere se cambia l\u2019intensit\u00e0 oraria media: un aumento delle ore pro capite a parit\u00e0 di produttivit\u00e0 oraria migliora il CLUP per persona senza che cambi quello orario.",
    "Compensi dei dipendenti disaggregati per settore NACE (10 settori aggregati), a prezzi correnti, in milioni di euro. La somma dei settori approssima i \u00abCompensi dei dipendenti a prezzi correnti\u00bb complessivi; il confronto tra il peso di un settore nei compensi e il suo peso nell\u2019occupazione (\u00abOccupazione per settore NACE\u00bb) o nel valore aggiunto (\u00abValore aggiunto per settore a prezzi correnti\u00bb) indica se quel settore \u00e8 relativamente pi\u00f9 o meno labour-intensive/ad alta retribuzione.",
    "Come i \u00abCompensi per settore a prezzi correnti\u00bb ma a prezzi costanti: permette di confrontare nel tempo la dinamica reale della massa salariale settoriale, isolando l\u2019effetto prezzi.",
    # Formazione del capitale (9)
    "Formazione lorda di capitale fisso (FBCF) a prezzi correnti: acquisti di macchinari, impianti, costruzioni e altri beni capitali durevoli nell\u2019anno, in milioni di euro o PPS EU27. Misura il flusso di nuovi investimenti, non lo stock di capitale accumulato (per quello si veda \u00abStock di capitale a prezzi costanti\u00bb); valori elevati in rapporto al PIL segnalano un territorio in fase di espansione della capacit\u00e0 produttiva.",
    "Come gli \u00abInvestimenti fissi lordi a prezzi correnti\u00bb ma a prezzi costanti: misura il volume reale di investimenti, al netto delle variazioni dei prezzi dei beni capitali (spesso diverse dall\u2019inflazione generale), utile per confronti di sforzo di investimento nel tempo.",
    "Investimenti fissi lordi disaggregati per settore NACE (10 settori aggregati), a prezzi correnti. La distribuzione settoriale degli investimenti anticipa spesso l\u2019evoluzione futura della struttura produttiva: i settori che investono di pi\u00f9 oggi tendono a pesare di pi\u00f9 in valore aggiunto e occupazione negli anni successivi.",
    "Come gli \u00abInvestimenti fissi lordi per settore a prezzi correnti\u00bb ma a prezzi costanti: consente di confrontare nel tempo il volume reale di investimenti per settore, isolando l\u2019effetto dei prezzi dei beni capitali.",
    "Stock di capitale netto accumulato nel territorio, a prezzi costanti (anno base 2015/2020), stimato dal JRC con il metodo dell\u2019inventario permanente (stock storico rivalutato, sommato agli investimenti annui e depurato dagli ammortamenti). A differenza degli \u00abInvestimenti fissi lordi\u00bb (a prezzi correnti o costanti), che sono flussi annuali, questa \u00e8 una variabile di stock: conta pi\u00f9 la sua dinamica nel tempo e il rapporto tra capitale e PIL (intensit\u00e0 di capitale) del livello assoluto in s\u00e9.",
    "Consumo di capitale fisso (ammortamenti) a prezzi correnti, in milioni di euro: rappresenta la perdita di valore del capitale esistente per usura e obsolescenza nell\u2019anno. Il confronto tra gli \u00abInvestimenti fissi lordi a prezzi correnti\u00bb e questi ammortamenti indica se lo stock di capitale del territorio si sta espandendo (investimenti superiori agli ammortamenti) o si sta riducendo.",
    "Come gli \u00abAmmortamenti a prezzi correnti\u00bb ma a prezzi costanti: misura il consumo reale di capitale fisso, coerente con lo \u00abStock di capitale a prezzi costanti\u00bb e gli \u00abInvestimenti fissi lordi a prezzi costanti\u00bb per ricostruire la dinamica reale dello stock di capitale nel tempo.",
    "Ammortamenti disaggregati per settore NACE (10 settori aggregati), a prezzi correnti. Settori capital-intensive (es. industria, energia) mostrano tipicamente ammortamenti elevati in rapporto al valore aggiunto prodotto rispetto a settori labour-intensive (es. servizi alla persona).",
    "Come gli \u00abAmmortamenti per settore a prezzi correnti\u00bb ma a prezzi costanti: consente il confronto nel tempo della dinamica reale degli ammortamenti settoriali, isolando l\u2019effetto dei prezzi dei beni capitali."
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
