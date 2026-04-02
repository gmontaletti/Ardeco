# ARDECO: nota tecnica e automazione dello scarico dati in R

## Cos'è ARDECO

ARDECO (Annual Regional Database of the European Commission) è il database regionale annuale della Commissione Europea. Lo gestisce il Joint Research Centre (JRC) in coordinamento con la Direzione Generale per la Politica Regionale e Urbana (DG REGIO). Contiene serie storiche armonizzate di variabili demografiche e socioeconomiche a livello sub-nazionale, con copertura geografica che comprende tutte le regioni NUTS dell'UE, più alcune aree di paesi EFTA e candidati all'adesione.

La struttura geografica copre quattro livelli della nomenclatura NUTS:

- NUTS0 (livello nazionale)
- NUTS1 (macroregioni)
- NUTS2 (regioni)
- NUTS3 (province/sub-regioni)

Sono disponibili anche dati per le Regioni Metropolitane.

## Contenuto tematico

Il database copre sei aree principali:

- **Popolazione e demografia**: popolazione totale, variazione naturale, migrazione netta
- **Mercato del lavoro**: occupazione (workplace-based e residence-based), dipendenti, ore lavorate
- **Occupazione per settore**: 10 macro-settori NACE (variabile `SNETZ`)
- **Prodotto interno lordo e valore aggiunto**: PIL corrente, deflatori, PPS
- **Reddito e consumi**: reddito disponibile delle famiglie, consumi finali
- **Formazione del capitale**: investimenti fissi lordi

Per ciascuna variabile sono disponibili più unità di misura (es. migliaia di persone, milioni di euro, indici) e, ove pertinente, disaggregazioni per sesso, classi d'età e settore economico.

## Copertura temporale e aggiornamento

Le serie storiche partono dal 1980 per la maggior parte delle variabili e dal 1960 per i dati di popolazione. Il database include proiezioni a breve termine (2-3 anni) basate sui forecast AMECO della DG ECFIN.

Gli aggiornamenti seguono questo calendario:

- **Marzo**: aggiornamento annuale dei conti regionali Eurostat
- **Maggio**: rilascio principale, allineato ai forecast primaverili AMECO
- **Novembre**: rilascio principale, allineato ai forecast autunnali AMECO

Il database è disponibile in accesso libero e gratuito.

## Metodologia e fonti

La fonte primaria è Eurostat (conti regionali). Il JRC integra i dati con fonti nazionali e regionali, e con stime prodotte tramite interpolazione, proiezioni di quote regionali e variabili proxy. I dati storici della European Regional Database di Cambridge Econometrics (dismessa nel 2016) hanno contribuito alle serie più lontane nel tempo.

Le versioni NUTS mantenute sono le due più recenti (attualmente NUTS 2021 e NUTS 2016). Eventuali discontinuità di livello legate ai cambiamenti di perimetro geografico vengono corrette applicando i tassi di crescita delle serie precedenti ai livelli delle serie correnti.

## Automazione dello scarico dati: il pacchetto R `ARDECO`

Il JRC distribuisce un pacchetto R ufficiale su CRAN che espone direttamente le API pubbliche del database. L'automazione è quindi nativamente supportata e non richiede scraping o workaround.

**Versione corrente**: 2.2.3 (ultimo aggiornamento: luglio 2025)  
**Dipendenze principali**: `httr`, `jsonlite`, `dplyr`, `tibble`, `arrow`

### Installazione

```r
install.packages("ARDECO")
library(ARDECO)
```

### Funzioni principali

Il pacchetto espone quattro funzioni:

| Funzione | Descrizione |
|---|---|
| `ardeco_get_variable_list()` | Restituisce l'elenco di tutte le variabili disponibili (codice + descrizione) |
| `ardeco_get_dataset_list(var)` | Restituisce i dataset di una variabile con le dimensioni disponibili |
| `ardeco_get_tercet_list(var)` | Restituisce le tipologie territoriali (tercet) per aggregazione |
| `ardeco_get_dataset_data(var, ...)` | Scarica i dati, con filtri opzionali |

### Workflow tipico

```r
library(ARDECO)

# 1. Esplora le variabili disponibili
vars <- ardeco_get_variable_list()
print(vars, n = 30)

# 2. Verifica i dataset e le dimensioni di una variabile
# Esempio: occupazione per settore NACE
ds <- ardeco_get_dataset_list("SNETZ")
print(ds)

# 3. Scarica i dati con filtri
# Occupazione totale (tutti i settori) per le regioni italiane NUTS2
# anni 2010-2023
dati <- ardeco_get_dataset_data(
  "SNETZ",
  nutscode  = "IT",
  level     = "2",
  year      = "2010-2023",
  unit      = "Thousands Persons",
  sector    = "O-U"  # totale economia
)

# 4. Il risultato è un tibble pronto all'uso
str(dati)
```

### Opzioni di filtraggio

La funzione `ardeco_get_dataset_data()` accetta i parametri comuni a tutte le variabili:

- `nutscode`: codice NUTS, accetta prefissi multipli separati da virgola (es. `"IT,DE"`)
- `level`: livello NUTS, da 0 a 3 (accetta lista con `"0,2"` o intervallo con `"1-3"`)
- `year`: anno o intervallo (es. `"2000-2023"` oppure `"2015,2020"`)
- `unit`: unità di misura
- `vers`: versione NUTS (`"2016"`, `"2021"`, `"2024"`)
- `tercet_code` / `tercet_class_code`: aggregazione per tipologia territoriale (es. Urban-Rural Typology)
- `show_perc`: se `TRUE`, restituisce valori percentuali per le tercet

Parametri aggiuntivi variano per variabile (es. `sector`, `sex`, `age`) e sono documentati dall'output di `ardeco_get_dataset_list()`.

### Esempio di download batch

Il codice seguente scarica più variabili in un unico passaggio e le unisce in un dataset panel:

```r
library(ARDECO)
library(dplyr)

# Variabili di interesse per il mercato del lavoro lombardo
variabili <- c("SNETD", "SNECN", "RNLHTE")

panel <- lapply(variabili, function(v) {
  ardeco_get_dataset_data(
    v,
    nutscode = "ITC4",   # Lombardia NUTS2
    level    = "2",
    year     = "2000-2023",
    verbose  = FALSE
  ) |>
    mutate(var_code = v)
}) |>
  bind_rows()

# Salva in Parquet per uso downstream
arrow::write_parquet(panel, "ardeco_lombardia_labour.parquet")
```

### Integrazione con pipeline `targets`

Per aggiornamenti automatici periodici (allineati ai rilasci di marzo, maggio e novembre), il workflow si presta all'integrazione con `targets`:

```r
# _targets.R
library(targets)
library(ARDECO)

list(
  tar_target(
    ardeco_raw,
    ardeco_get_dataset_data(
      "SNETD",
      nutscode = "IT",
      level    = "2",
      year     = "2005-2025"
    )
  ),
  tar_target(
    ardeco_parquet,
    {
      arrow::write_parquet(ardeco_raw, "data/ardeco_employment.parquet")
      "data/ardeco_employment.parquet"
    },
    format = "file"
  )
)
```

## Limitazioni note

- Il portale web interattivo (`urban.jrc.ec.europa.eu/ardeco`) è periodicamente in manutenzione; le API sottostanti, su cui si basa il pacchetto R, restano disponibili.
- Il pacchetto non è ospitato su un repository pubblico GitHub ufficiale del JRC: per bug e richieste di supporto si può contattare il maintainer (davide.auteri@ec.europa.eu).
- Le versioni NUTS mantenute sono le ultime due: dati su classificazioni più vecchie (es. NUTS 2010) non sono disponibili direttamente.
- Le proiezioni a breve termine sono prodotte con metodologie di downscaling a partire da AMECO e non sostituiscono i dati ufficiali Eurostat.

## Conclusione

L'automazione dello scarico da ARDECO è pienamente fattibile in R tramite il pacchetto ufficiale CRAN. Le API pubbliche sono stabili, documentate e non richiedono autenticazione. Il pacchetto restituisce tibble compatibili con i principali strumenti dell'ecosistema tidyverse e si integra senza modifiche con pipeline `targets` e storage Parquet/DuckDB.
