# 02_download_geo.R
# Download NUTS3 provincial boundaries for Lombardia using giscoR.
# Output: data/lombardia_nuts3.gpkg

# 1. Libraries -----

library(giscoR)
library(sf)
library(dplyr)
library(stringr)

# 2. Download NUTS3 boundaries (provinces) -----

nuts3_it <- giscoR::gisco_get_nuts(
  year = "2021",
  resolution = "10",
  nuts_level = "3",
  country = "IT"
)

nuts3_lombardia <- nuts3_it |>
  dplyr::filter(stringr::str_starts(NUTS_ID, "ITC4")) |>
  dplyr::mutate(nuts_level = 3L)

# 3. Download NUTS2 boundary (region) -----

nuts2_it <- giscoR::gisco_get_nuts(
  year = "2021",
  resolution = "10",
  nuts_level = "2",
  country = "IT"
)

nuts2_lombardia <- nuts2_it |>
  dplyr::filter(NUTS_ID == "ITC4") |>
  dplyr::mutate(nuts_level = 2L)

# 4. Combine into a single sf object -----

lombardia_geo <- dplyr::bind_rows(nuts2_lombardia, nuts3_lombardia)

# 5. Save to GeoPackage -----

out_path <- file.path("data", "lombardia_nuts3.gpkg")

sf::st_write(
  lombardia_geo,
  dsn = out_path,
  delete_dsn = TRUE
)

message("Saved: ", out_path)

# 6. Summary -----

message("Number of features: ", nrow(lombardia_geo))
message("NUTS_ID list:")
message(paste(lombardia_geo$NUTS_ID, collapse = ", "))
