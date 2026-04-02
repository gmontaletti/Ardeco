# labels.R
# Lookup tables con etichette italiane per il progetto ARDECO dashboard.
# Salva tutte le tabelle in data/labels.rds come lista nominata.

library(data.table)

# 1. Etichette variabili -----

var_labels <- data.table(
  var_code = c(
    "SNPTD",
    "SNPTN",
    "SNPBN",
    "SNPDN",
    "SNPNN",
    "SNMTN",
    "SNPCN",
    "SNETD",
    "SNWTD",
    "RNECN",
    "RNUTN",
    "RNLCN",
    "RNLHT",
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
    "RUWCD",
    "ROWCD",
    "RUIGT",
    "ROIGT",
    "RUIGZ",
    "ROIGZ"
  ),
  label_it = c(
    "Popolazione media annua",
    "Popolazione al 1\u00b0 gennaio per sesso ed et\u00e0",
    "Nati vivi per sesso",
    "Decessi per fascia d\u2019et\u00e0 e sesso",
    "Variazione naturale della popolazione",
    "Migrazione netta per fascia d\u2019et\u00e0 e sesso",
    "Variazione della popolazione per fascia d\u2019et\u00e0 e sesso",
    "Occupazione workplace-based",
    "Dipendenti workplace-based",
    "Occupati per et\u00e0 e sesso",
    "Disoccupati",
    "Forza lavoro (15 anni e oltre)",
    "Ore lavorate (occupati)",
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
    "Compensi dei dipendenti a prezzi correnti",
    "Compensi dei dipendenti a prezzi costanti",
    "Investimenti fissi lordi a prezzi correnti",
    "Investimenti fissi lordi a prezzi costanti",
    "Investimenti fissi lordi per settore a prezzi correnti",
    "Investimenti fissi lordi per settore a prezzi costanti"
  ),
  group_id = c(
    rep("popolazione_demografia", 7),
    rep("mercato_lavoro", 8),
    rep("occupazione_settore", 2),
    rep("pil_valore_aggiunto", 10),
    rep("reddito_compensi", 2),
    rep("formazione_capitale", 4)
  )
)

# 2. Etichette unità di misura -----

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
    "EUR2020"
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
    "Euro (prezzi 2020)"
  )
)

# 3. Etichette sesso -----

sex_labels <- data.table(
  code = c("TOTAL", "F", "M"),
  label_it = c("Totale", "Femmine", "Maschi")
)

# 4. Etichette classi di età -----

age_labels <- data.table(
  code = c(
    "TOTAL",
    "Y15-39",
    "Y15-64",
    "Y20-64",
    "Y40-64",
    "Y_GE15",
    "Y_GE65",
    "Y_LT15",
    "Y_LT20",
    "Y_LT15-GE65"
  ),
  label_it = c(
    "Totale",
    "15-39 anni",
    "15-64 anni",
    "20-64 anni",
    "40-64 anni",
    "15 anni e oltre",
    "65 anni e oltre",
    "Meno di 15 anni",
    "Meno di 20 anni",
    "Meno di 15 e 65 anni e oltre"
  )
)

# 5. Etichette settori NACE -----

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
    "Totale economia",
    "Altre attivit\u00e0 di servizi"
  )
)

# 6. Etichette gruppi tematici -----

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

# 7. Funzioni helper per recupero etichette -----

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
#'
#' @param code character(1) codice sesso (es. "F", "M", "TOTAL").
#' @param labels lista caricata da labels.rds.
#' @return character(1) etichetta italiana, oppure il codice stesso se non trovato.
get_sex_label <- function(code, labels) {
  stopifnot(is.character(code), length(code) == 1L)
  idx <- match(code, labels$sex_labels$code)
  if (is.na(idx)) {
    return(code)
  }
  labels$sex_labels$label_it[idx]
}

#' Restituisce l'etichetta italiana per la classe di età.
#'
#' @param code character(1) codice classe di età (es. "Y15-64").
#' @param labels lista caricata da labels.rds.
#' @return character(1) etichetta italiana, oppure il codice stesso se non trovato.
get_age_label <- function(code, labels) {
  stopifnot(is.character(code), length(code) == 1L)
  idx <- match(code, labels$age_labels$code)
  if (is.na(idx)) {
    return(code)
  }
  labels$age_labels$label_it[idx]
}

#' Restituisce l'etichetta italiana per il settore NACE.
#'
#' @param code character(1) codice settore (es. "B-E", "O-U").
#' @param labels lista caricata da labels.rds.
#' @return character(1) etichetta italiana, oppure il codice stesso se non trovato.
get_sector_label <- function(code, labels) {
  stopifnot(is.character(code), length(code) == 1L)
  idx <- match(code, labels$sector_labels$code)
  if (is.na(idx)) {
    return(code)
  }
  labels$sector_labels$label_it[idx]
}

# 8. Salvataggio -----

labels <- list(
  var_labels = var_labels,
  unit_labels = unit_labels,
  sex_labels = sex_labels,
  age_labels = age_labels,
  sector_labels = sector_labels,
  group_labels = group_labels
)

saveRDS(labels, "data/labels.rds")

message(
  "Salvate ",
  length(labels),
  " tabelle in data/labels.rds ",
  "(var_labels: ",
  nrow(var_labels),
  " righe, ",
  "unit_labels: ",
  nrow(unit_labels),
  " righe, ",
  "sector_labels: ",
  nrow(sector_labels),
  " righe)"
)
