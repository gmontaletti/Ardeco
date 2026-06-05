# ==============================================================================
# 00_config_eu.R
# Configurazione condivisa per l'esercizio comparatore cross-country.
# Definisce paesi, percorsi, gruppi tematici, tabelle di etichette e la funzione
# download_variable(). I blocchi di definizione (gruppi, etichette, funzione di
# download) sono COPIATI deliberatamente da R/01_build_duckdb.R: quel file ha
# effetti collaterali a livello top (cancella il DB ed esegue il download), quindi
# non puo' essere sourced. Sono dati di riferimento statici: la duplicazione e'
# accettabile e mantiene invariata la pipeline di produzione.
# Sourced da: 01_download_eu.R, 03_labour_indicators.R, 04_build_profiles.R,
#             99_smoke_test_eu.R
# ==============================================================================

# 1. Librerie -----

library(ARDECO)
library(data.table)
library(duckdb)
library(DBI)
library(R.utils)

# 2. Configurazione comparatore -----

EU_DB_PATH <- "data/ardeco_eu.duckdb"
EU_GEO_PATH <- "data/eu_nuts2.gpkg"
EU_PCA_PATH <- "data/eu_pca_model.rds"
# Tutti i paesi coperti da ARDECO: UE27 + EFTA (CH, IS, LI, NO) +
# candidati/Balcani occidentali (AL, ME, MK, RS, TR). 'EL' = Grecia (codifica
# Eurostat). La copertura per regione varia: micro-stati (CY, LU, MT, LI, EE,
# IS) sono un'unica regione NUTS2; i paesi candidati hanno serie di contabilità
# nazionale più sparse.
EU_COUNTRIES <- c(
  "AL",
  "AT",
  "BE",
  "BG",
  "CH",
  "CY",
  "CZ",
  "DE",
  "DK",
  "EE",
  "EL",
  "ES",
  "FI",
  "FR",
  "HR",
  "HU",
  "IE",
  "IS",
  "IT",
  "LI",
  "LT",
  "LU",
  "LV",
  "ME",
  "MK",
  "MT",
  "NL",
  "NO",
  "PL",
  "PT",
  "RO",
  "RS",
  "SE",
  "SI",
  "SK",
  "TR"
)
EU_NUTSCODE <- paste(EU_COUNTRIES, collapse = ",")
EU_LEVEL <- "0,2" # 2 = regioni NUTS2; 0 = aggregati paese (linee di contesto)
EU_VERSION <- 2024
REF_DEFAULT <- "ITC4" # Lombardia

# Raggruppamento delle regioni e rilevamento outlier.
# Le regioni europee formano un continuum strutturale (nessun gruppo denso ben
# separato), quindi il RAGGRUPPAMENTO usa il clustering partizionale ward in
# WARD_K tipi leggibili. HDBSCAN serve solo per il punteggio di atipicità (GLOSH
# outlier_score): le regioni con score >= OUTLIER_THRESHOLD sono segnalate come
# strutturalmente anomale. HDBSCAN_MINPTS è il parametro di densità del GLOSH
# (più alto = stima più liscia); dbscan richiede minPts >= 2.
WARD_K <- 6L
HDBSCAN_MINPTS <- 8L
OUTLIER_THRESHOLD <- 0.7

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
    "Popolazione al 1° gennaio per fascia d’età e sesso",
    "Popolazione al 1° gennaio per classi quinquennali e sesso",
    "Nati vivi per sesso",
    "Decessi per fascia d’età e sesso",
    "Decessi per classi quinquennali e sesso",
    "Variazione naturale della popolazione",
    "Migrazione netta per fascia d’età e sesso",
    "Variazione della popolazione per fascia d’età e sesso",
    "Variazione della popolazione per 1000 abitanti",
    "Migrazione netta per 1000 abitanti",
    "Indice di dipendenza (rapporto alla popolazione 20-64)",
    "Occupazione workplace-based",
    "Occupazione pro capite",
    "Dipendenti workplace-based",
    "Occupati per età e sesso",
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
    "Produttività nominale per ora lavorata",
    "Produttività nominale per occupato",
    "Produttività reale per ora lavorata",
    "Produttività reale per occupato",
    "PIL pro capite a prezzi correnti",
    "PIL pro capite a prezzi costanti",
    "Tasso di crescita del PIL (indice concatenato)",
    "Tasso di crescita del VA (indice concatenato)",
    "Compensi dei dipendenti a prezzi correnti",
    "Compensi dei dipendenti a prezzi costanti",
    "Compenso reale per ora lavorata",
    "Compenso nominale per dipendente",
    "Compenso reale per dipendente",
    "Costo del lavoro per unità di prodotto nominale (ore)",
    "Costo del lavoro per unità di prodotto nominale (persone)",
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
    "Tasso di crescita (‰)",
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
    "Attività finanziarie e assicurative",
    "Attività finanziarie, immobiliari, professionali",
    "Attività immobiliari",
    "Attività professionali, scientifiche e tecniche",
    "PA, istruzione, sanità",
    "PA, istruzione, sanità e altri servizi",
    "Altre attività di servizi"
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

#' Scarica una singola variabile ARDECO con schema normalizzato.
#'
#' Avvolge ardeco_get_dataset_data() con gestione errori e normalizzazione
#' colonne. Restituisce una data.table con schema fisso a 12 colonne, oppure
#' NULL in caso di errore/timeout. Copiata verbatim da R/01_build_duckdb.R.
#'
#' @param var_code Character. Codice variabile ARDECO.
#' @param nutscode Character. Filtro NUTS (lista CSV ammessa, es. "IT,DE,FR,PL,ES").
#' @param level Character. Livelli NUTS da scaricare (es. "0,2").
#' @param version Numeric. Anno versione NUTS.
#' @param timeout_sec Numeric. Timeout in secondi.
#' @return data.table a 12 colonne, oppure NULL.
download_variable <- function(
  var_code,
  nutscode = EU_NUTSCODE,
  level = EU_LEVEL,
  version = EU_VERSION,
  timeout_sec = 600
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
        message("  [WARN] Nessun dato restituito per ", var_code)
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
      message("  [TIMEOUT] ", var_code, " ha superato ", timeout_sec, "s")
      NULL
    },
    error = function(e) {
      message(
        "  [ERROR] Download fallito per ",
        var_code,
        ": ",
        conditionMessage(e)
      )
      NULL
    }
  )
}
