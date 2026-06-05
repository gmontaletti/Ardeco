# ==============================================================================
# 99_smoke_test_eu.R
# Verifica (read-only) della semantica dell'API ARDECO per il download
# multi-paese, prima del download completo. Controlla che:
#  - nutscode per singolo paese restituisca solo regioni di quel paese;
#  - la chiamata combinata (lista CSV) restituisca tutti i paesi richiesti;
#  - vengano segnalati eventuali paesi senza dati.
# Uso: Rscript R/comparatore/99_smoke_test_eu.R
# ==============================================================================

# 1. Config -----

source("R/comparatore/00_config_eu.R")

# 2. Verifica per singolo paese -----

message("== Verifica semantica nutscode per singolo paese ==")
missing <- character(0)
for (cc in EU_COUNTRIES) {
  d <- tryCatch(
    as.data.table(ardeco_get_dataset_data(
      "SNPTD",
      nutscode = cc,
      level = "2",
      version = EU_VERSION
    )),
    error = function(e) NULL
  )
  if (is.null(d) || nrow(d) == 0L) {
    message(sprintf("  %s: NESSUN dato a livello 2", cc))
    missing <- c(missing, cc)
    next
  }
  ok_prefix <- all(startsWith(d$NUTSCODE, cc))
  n_reg <- uniqueN(d$NUTSCODE)
  message(sprintf(
    "  %s: %d regioni NUTS2 | prefisso corretto: %s",
    cc,
    n_reg,
    ok_prefix
  ))
  if (!ok_prefix) {
    stop("Prefisso NUTS non coerente per ", cc, call. = FALSE)
  }
}
if (length(missing) > 0L) {
  message(
    "\nPaesi senza NUTS2 per SNPTD (verranno comunque tentati nel download): ",
    paste(missing, collapse = ", ")
  )
}

# 3. Verifica chiamata combinata (lista CSV) -----

message(
  "\n== Verifica chiamata combinata (",
  length(EU_COUNTRIES),
  " paesi) =="
)
d_all <- as.data.table(ardeco_get_dataset_data(
  "SNPTD",
  nutscode = EU_NUTSCODE,
  level = "0,2",
  version = EU_VERSION
))
d_nuts2 <- d_all[LEVEL == 2L]
got_countries <- sort(unique(substr(d_nuts2$NUTSCODE, 1, 2)))
message("  Paesi presenti (livello 2): ", paste(got_countries, collapse = ", "))
message("  Regioni NUTS2 totali: ", uniqueN(d_nuts2$NUTSCODE))
message("  Aggregati paese (livello 0): ", uniqueN(d_all[LEVEL == 0L]$NUTSCODE))

tab <- d_nuts2[,
  list(n_regioni = uniqueN(NUTSCODE)),
  by = list(paese = substr(NUTSCODE, 1, 2))
]
setorder(tab, -n_regioni)
print(tab)

not_returned <- setdiff(EU_COUNTRIES, got_countries)
if (length(not_returned) > 0L) {
  message(
    "\nPaesi richiesti senza regioni NUTS2 per questa variabile: ",
    paste(not_returned, collapse = ", ")
  )
}

message("\nSmoke test completato: l'API supporta il download multi-paese.")
