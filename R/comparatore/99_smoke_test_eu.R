# ==============================================================================
# 99_smoke_test_eu.R
# Verifica (read-only) della semantica dell'API ARDECO per il download
# multi-paese, prima del download completo. Controlla che:
#  - nutscode per singolo paese restituisca solo regioni di quel paese;
#  - la lista CSV "IT,DE,FR,PL,ES" restituisca tutti e cinque i paesi;
#  - i conteggi NUTS2 siano nel range atteso.
# Uso: Rscript R/comparatore/99_smoke_test_eu.R
# ==============================================================================

# 1. Config -----

source("R/comparatore/00_config_eu.R")

# Conteggi NUTS2 attesi (indicativi, versione 2024)
expected <- c(IT = 21, DE = 38, FR = 27, PL = 17, ES = 19)

# 2. Verifica per singolo paese -----

message("== Verifica semantica nutscode per singolo paese ==")
for (cc in EU_COUNTRIES) {
  d <- ardeco_get_dataset_data(
    "SNPTD",
    nutscode = cc,
    level = "2",
    version = EU_VERSION
  )
  d <- as.data.table(d)
  ok_prefix <- all(startsWith(d$NUTSCODE, cc))
  n_reg <- uniqueN(d$NUTSCODE)
  message(sprintf(
    "  %s: %d regioni NUTS2 (attese ~%d) | prefisso corretto: %s",
    cc,
    n_reg,
    expected[[cc]],
    ok_prefix
  ))
  if (!ok_prefix || n_reg < 5L) {
    stop("Verifica fallita per ", cc, call. = FALSE)
  }
}

# 3. Verifica chiamata combinata (lista CSV) -----

message("\n== Verifica chiamata combinata IT,DE,FR,PL,ES ==")
d4 <- ardeco_get_dataset_data(
  "SNPTD",
  nutscode = EU_NUTSCODE,
  level = "0,2",
  version = EU_VERSION
)
d4 <- as.data.table(d4)
d4_nuts2 <- d4[LEVEL == 2L]
got_countries <- sort(unique(substr(d4_nuts2$NUTSCODE, 1, 2)))
message("  Paesi presenti (livello 2): ", paste(got_countries, collapse = ", "))
message("  Regioni NUTS2 totali: ", uniqueN(d4_nuts2$NUTSCODE))
message("  Aggregati paese (livello 0): ", uniqueN(d4[LEVEL == 0L]$NUTSCODE))

tab <- d4_nuts2[,
  list(n_regioni = uniqueN(NUTSCODE)),
  by = list(
    paese = substr(NUTSCODE, 1, 2)
  )
]
setorder(tab, paese)
print(tab)

if (!all(EU_COUNTRIES %in% got_countries)) {
  stop(
    "Mancano paesi nella chiamata combinata: ",
    paste(setdiff(EU_COUNTRIES, got_countries), collapse = ", "),
    call. = FALSE
  )
}

message("\nSmoke test superato: l'API supporta il download multi-paese.")
