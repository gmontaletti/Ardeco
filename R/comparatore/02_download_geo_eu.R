# ==============================================================================
# 02_download_geo_eu.R
# Scarica i confini regionali NUTS2 di IT, DE, FR, PL, ES tramite giscoR.
# Calcola l'area (km^2) di ciascuna regione, usata come densità nella similarità.
# Output: data/eu_nuts2.gpkg
# Uso: Rscript R/comparatore/02_download_geo_eu.R
# ==============================================================================

# 1. Librerie / config -----

library(giscoR)
library(sf)
source("R/comparatore/00_config_eu.R")

# 2. Download NUTS2 -----

nuts2 <- giscoR::gisco_get_nuts(
  year = "2021",
  resolution = "10",
  nuts_level = "2",
  country = EU_COUNTRIES
)

# 3. Pulizia colonne (subsetting base, no dplyr) -----

keep <- c("NUTS_ID", "NAME_LATN", "CNTR_CODE", "geometry")
nuts2 <- nuts2[, keep]
nuts2$nuts_level <- 2L

# 4. Area in km^2 (proiezione equivalente LAEA Europa, EPSG:3035) -----

area_m2 <- as.numeric(sf::st_area(sf::st_transform(nuts2, 3035)))
nuts2$area_km2 <- area_m2 / 1e6

# 5. Salvataggio -----

if (file.exists(EU_GEO_PATH)) {
  file.remove(EU_GEO_PATH)
}
sf::st_write(nuts2, dsn = EU_GEO_PATH, delete_dsn = TRUE, quiet = TRUE)
message("Salvato: ", EU_GEO_PATH)

# 6. Riepilogo -----

tab <- table(nuts2$CNTR_CODE)
message("Regioni NUTS2 per paese:")
for (cc in names(tab)) {
  message(sprintf("  %s: %d", cc, tab[[cc]]))
}
message("Totale: ", nrow(nuts2), " regioni")
