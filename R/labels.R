# labels.R
# Lookup tables con etichette italiane per il progetto ARDECO dashboard.
# Salva tutte le tabelle in data/labels.rds come lista nominata.

library(data.table)

# 1. Etichette variabili -----

var_labels <- data.table(
  var_code = c(
    "SNPTD",
    "SNPTN",
    "SNPTZ",
    "SNPTY",
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
    "RNLHTE",
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
    "RUWCDH",
    "ROWCDH",
    "RUWCDW",
    "ROWCDW",
    "RUWCDHH",
    "RUWCDWE",
    "RUWCZ",
    "ROWCZ",
    "RUVNH",
    "RUYNH",
    "RUONH",
    "RUTYH",
    "RUIGT",
    "ROIGT",
    "RUIGZ",
    "ROIGZ",
    "ROKND",
    "SUKCT",
    "SOKCT",
    "SUKCZ",
    "SOKCZ",
    "RPDTN",
    "RPDEN",
    "RPDNN"
  ),
  label_it = c(
    "Popolazione media annua",
    "Popolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso",
    "Popolazione al 1\u00b0 gennaio per classi quinquennali e sesso",
    "Popolazione al 1\u00b0 gennaio per anno di et\u00e0 e sesso",
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
    "Ore lavorate per occupato",
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
    "Compenso nominale per ora lavorata",
    "Compenso reale per ora lavorata",
    "Compenso nominale per dipendente",
    "Compenso reale per dipendente",
    "Costo del lavoro per unit\u00e0 di prodotto nominale (ore)",
    "Costo del lavoro per unit\u00e0 di prodotto nominale (persone)",
    "Compensi per settore a prezzi correnti",
    "Compensi per settore a prezzi costanti",
    "Reddito disponibile netto delle famiglie",
    "Redditi netti da propriet\u00e0",
    "Risultato netto di gestione e reddito misto",
    "Imposte correnti su reddito e patrimonio",
    "Investimenti fissi lordi a prezzi correnti",
    "Investimenti fissi lordi a prezzi costanti",
    "Investimenti fissi lordi per settore a prezzi correnti",
    "Investimenti fissi lordi per settore a prezzi costanti",
    "Stock di capitale a prezzi costanti",
    "Ammortamenti a prezzi correnti",
    "Ammortamenti a prezzi costanti",
    "Ammortamenti per settore a prezzi correnti",
    "Ammortamenti per settore a prezzi costanti",
    "Popolazione per livello di istruzione",
    "Abbandono precoce di istruzione e formazione (18-24 anni)",
    "Giovani NEET (15-29 anni)"
  ),
  group_id = c(
    rep("popolazione_demografia", 13),
    rep("mercato_lavoro", 12),
    rep("occupazione_settore", 2),
    rep("pil_valore_aggiunto", 14),
    rep("reddito_compensi", 14),
    rep("formazione_capitale", 9),
    rep("istruzione", 3)
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

# 5. Etichette livelli di istruzione ISCED -----

isced11_labels <- data.table(
  code = c("ED0-2", "ED3_4", "ED5-8"),
  label_it = c(
    "Istruzione primaria e secondaria inferiore",
    "Istruzione secondaria superiore e post-secondaria",
    "Istruzione terziaria"
  )
)

# 6. Etichette settori NACE -----

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

# 7. Etichette gruppi tematici -----

group_labels <- data.table(
  group_id = c(
    "popolazione_demografia",
    "mercato_lavoro",
    "occupazione_settore",
    "pil_valore_aggiunto",
    "reddito_compensi",
    "formazione_capitale",
    "istruzione"
  ),
  label_it = c(
    "Popolazione e demografia",
    "Mercato del lavoro",
    "Occupazione per settore",
    "PIL e valore aggiunto",
    "Reddito e compensi",
    "Formazione del capitale",
    "Istruzione e capitale umano"
  )
)

# 8. Funzioni helper per recupero etichette -----

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

#' Restituisce l'etichetta italiana per il livello di istruzione ISCED.
#'
#' @param code character(1) codice ISCED (es. "ED5-8").
#' @param labels lista caricata da labels.rds.
#' @return character(1) etichetta italiana, oppure il codice stesso se non trovato.
get_isced11_label <- function(code, labels) {
  stopifnot(is.character(code), length(code) == 1L)
  idx <- match(code, labels$isced11_labels$code)
  if (is.na(idx)) {
    return(code)
  }
  labels$isced11_labels$label_it[idx]
}

# 9. Salvataggio -----

labels <- list(
  var_labels = var_labels,
  unit_labels = unit_labels,
  sex_labels = sex_labels,
  age_labels = age_labels,
  isced11_labels = isced11_labels,
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
  " righe, ",
  "isced11_labels: ",
  nrow(isced11_labels),
  " righe)"
)
