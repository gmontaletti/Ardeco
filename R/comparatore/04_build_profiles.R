# ==============================================================================
# 04_build_profiles.R
# Motore di similarità regionale. Costruisce il profilo strutturale di ogni
# regione NUTS2 (composizione settoriale, demografia, taglia/densità,
# intensità di capitale), standardizza, applica PCA e calcola le distanze tra
# regioni nello spazio delle componenti principali.
# Output: tabelle region_* nel DuckDB + modello PCA in data/eu_pca_model.rds
# Uso: Rscript R/comparatore/04_build_profiles.R
#
# Vincolo: le variabili di similarità sono DISGIUNTE da quelle di confronto del
# mercato del lavoro (03_labour_indicators.R) per evitare circolarità.
# ==============================================================================

# 1. Config -----

source("R/comparatore/00_config_eu.R")
library(sf)

# Asserzione di disgiunzione tra benchmark e confronto
similarity_vars <- c(
  "SUVGZ",
  "SUVGE",
  "SPPAN",
  "SNMTNP",
  "SNPCNP",
  "SNPTN",
  "SNPTD",
  "RUIGT"
)
comparison_vars <- c(
  "RPECNP",
  "RPUCNP",
  "SOVGDE",
  "SOVGDH",
  "SUVGDP",
  "SOVGDP",
  "ROWCDH",
  "RUWCDHH",
  "SUVGD",
  "SNETD",
  "SNWTD",
  "RNLHT"
)
overlap <- intersect(similarity_vars, comparison_vars)
if (length(overlap) > 0L) {
  stop(
    "Variabili condivise tra similarità e confronto (circolarità): ",
    paste(overlap, collapse = ", "),
    call. = FALSE
  )
}
message("Disgiunzione benchmark/confronto verificata.")

con <- dbConnect(duckdb(), dbdir = EU_DB_PATH, read_only = FALSE)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

# 2. Anno di riferimento e finestra -----

meta <- as.data.table(dbReadTable(con, "eu_meta"))
year_ref <- as.integer(meta[key == "YEAR_REF", value])
if (is.na(year_ref)) {
  stop("YEAR_REF non disponibile in eu_meta.", call. = FALSE)
}
w0 <- year_ref - 2L
w1 <- year_ref
message(sprintf("Anno di riferimento: %d (finestra %d-%d)", year_ref, w0, w1))

# 3. Aree regionali dalla geometria -----

geo <- sf::st_read(EU_GEO_PATH, quiet = TRUE)
areas <- data.table(
  NUTSCODE = geo$NUTS_ID,
  CNTR_CODE = geo$CNTR_CODE,
  NAME = geo$NAME_LATN,
  area_km2 = geo$area_km2
)

# 4. Helper di estrazione (media sulla finestra, livello 2, totali) -----

#' Valore totale per regione (media sulla finestra), una riga per anno.
get_total_value <- function(con, var, w0, w1, unit = NULL) {
  unit_clause <- if (is.null(unit)) "" else "AND UNIT = ?"
  params <- if (is.null(unit)) {
    list(var, w0, w1)
  } else {
    list(var, unit, w0, w1)
  }
  q <- sprintf(
    "
    SELECT NUTSCODE, AVG(VALUE) AS v,
           COUNT(*) AS n, COUNT(DISTINCT YEAR) AS ny
    FROM ardeco_data
    WHERE VARIABLE = ? %s AND LEVEL = 2 AND YEAR BETWEEN ? AND ?
      AND SECTOR IS NULL
      AND (SEX IS NULL OR SEX = 'TOTAL')
      AND (AGE IS NULL OR AGE = 'TOTAL')
    GROUP BY NUTSCODE
    ",
    unit_clause
  )
  d <- as.data.table(dbGetQuery(con, q, params = params))
  if (nrow(d) == 0L) {
    return(NULL)
  }
  mult <- d[n > ny, .N]
  if (mult > 0L) {
    warning(sprintf(
      "%s: %d regioni con >1 riga/anno (dimensione residua?)",
      var,
      mult
    ))
  }
  d[, list(NUTSCODE, v)]
}

#' Sceglie l'unità con più righe tra le candidate per una variabile/livello.
pick_unit <- function(con, var, candidates) {
  d <- as.data.table(dbGetQuery(
    con,
    "SELECT UNIT, COUNT(*) n FROM ardeco_data WHERE VARIABLE = ? AND LEVEL = 2 GROUP BY UNIT",
    params = list(var)
  ))
  for (u in candidates) {
    if (u %in% d$UNIT) {
      return(u)
    }
  }
  if (nrow(d) > 0L) d[which.max(n), UNIT] else NA_character_
}

# 5. Feature A: composizione settoriale del valore aggiunto (clr) -----

va_unit <- pick_unit(con, "SUVGZ", c("MIO_EUR", "MIO_PPS_EU27_2020"))
message("Unità VA settoriale: ", va_unit)
sva <- as.data.table(dbGetQuery(
  con,
  "
  SELECT NUTSCODE, SECTOR, AVG(VALUE) AS v
  FROM ardeco_data
  WHERE VARIABLE = 'SUVGZ' AND UNIT = ? AND LEVEL = 2 AND YEAR BETWEEN ? AND ?
    AND SECTOR IS NOT NULL
  GROUP BY NUTSCODE, SECTOR
  ",
  params = list(va_unit, w0, w1)
))
sva_w <- dcast(sva, NUTSCODE ~ SECTOR, value.var = "v")

# Blocco commercio/informazione: G-J preferito, altrimenti G-I + J
coalesce_gj <- function(dt) {
  gj <- if ("G-J" %in% names(dt)) dt[["G-J"]] else rep(NA_real_, nrow(dt))
  gi <- if ("G-I" %in% names(dt)) dt[["G-I"]] else rep(NA_real_, nrow(dt))
  j <- if ("J" %in% names(dt)) dt[["J"]] else rep(NA_real_, nrow(dt))
  fifelse(!is.na(gj), gj, gi + j)
}
sva_w[, GJ := coalesce_gj(sva_w)]

covering <- c("A", "B-E", "F", "GJ", "K", "L", "M_N", "O-Q", "R-U")
present_cov <- intersect(covering, names(sva_w))
sector_mat <- as.matrix(sva_w[, ..present_cov])
rownames(sector_mat) <- sva_w$NUTSCODE

# Quote sul totale dei settori di copertura
tot_cov <- rowSums(sector_mat, na.rm = TRUE)
shares <- sector_mat / tot_cov

# clr: log della quota meno media dei log (clamp per evitare log(0))
shares[!is.finite(shares) | shares <= 0] <- NA
clr_transform <- function(m) {
  eps <- 1e-6
  m2 <- m
  m2[is.na(m2)] <- eps
  m2[m2 < eps] <- eps
  logm <- log(m2)
  sweep(logm, 1, rowMeans(logm), "-")
}
clr <- clr_transform(shares)
colnames(clr) <- paste0("clr_", gsub("[^A-Za-z0-9]", "", colnames(clr)))
clr_dt <- data.table(NUTSCODE = rownames(clr), clr)

# 6. Feature B: demografia -----

# SPPAN è disaggregato per AGE (Y_LT20, Y_GE65, Y_LT20-GE65); l'indice di
# dipendenza totale è la classe combinata 'Y_LT20-GE65'.
dep <- as.data.table(dbGetQuery(
  con,
  "
  SELECT NUTSCODE, AVG(VALUE) AS v
  FROM ardeco_data
  WHERE VARIABLE = 'SPPAN' AND LEVEL = 2 AND YEAR BETWEEN ? AND ?
    AND AGE = 'Y_LT20-GE65' AND SECTOR IS NULL
  GROUP BY NUTSCODE
  ",
  params = list(w0, w1)
))
if (nrow(dep) == 0L) {
  dep <- NULL
}
mig <- get_total_value(con, "SNMTNP", w0, w1)
pch <- get_total_value(con, "SNPCNP", w0, w1)
if (!is.null(dep)) {
  setnames(dep, "v", "dep_ratio")
}
if (!is.null(mig)) {
  setnames(mig, "v", "net_migr")
}
if (!is.null(pch)) {
  setnames(pch, "v", "pop_change")
}

# Quota popolazione 15-64
pop_1564 <- as.data.table(dbGetQuery(
  con,
  "
  SELECT NUTSCODE, AVG(VALUE) AS v
  FROM ardeco_data
  WHERE VARIABLE = 'SNPTN' AND LEVEL = 2 AND YEAR BETWEEN ? AND ?
    AND AGE = 'Y15-64' AND (SEX IS NULL OR SEX = 'TOTAL') AND SECTOR IS NULL
  GROUP BY NUTSCODE
  ",
  params = list(w0, w1)
))
pop_tot_age <- as.data.table(dbGetQuery(
  con,
  "
  SELECT NUTSCODE, AVG(VALUE) AS v
  FROM ardeco_data
  WHERE VARIABLE = 'SNPTN' AND LEVEL = 2 AND YEAR BETWEEN ? AND ?
    AND AGE = 'TOTAL' AND (SEX IS NULL OR SEX = 'TOTAL') AND SECTOR IS NULL
  GROUP BY NUTSCODE
  ",
  params = list(w0, w1)
))
share_1564 <- NULL
if (nrow(pop_1564) > 0L && nrow(pop_tot_age) > 0L) {
  share_1564 <- merge(
    pop_1564[, list(NUTSCODE, num = v)],
    pop_tot_age[, list(NUTSCODE, den = v)],
    by = "NUTSCODE"
  )
  share_1564[, share_1564 := num / den * 100]
  share_1564 <- share_1564[, list(NUTSCODE, share_1564)]
}

# 7. Feature C/D: taglia, densità, intensità di capitale -----

pop <- get_total_value(con, "SNPTD", w0, w1)
if (!is.null(pop)) {
  setnames(pop, "v", "pop")
}

invest_unit <- pick_unit(con, "RUIGT", c("MIO_EUR", "MIO_PPS_EU27_2020"))
invest <- get_total_value(con, "RUIGT", w0, w1, unit = invest_unit)
if (!is.null(invest)) {
  setnames(invest, "v", "invest")
}

# 8. Assemblaggio matrice feature -----

# Ancorato alle regioni con geometria (all.x = TRUE su areas): le regioni ARDECO
# prive di geometria GISCO non sono mappabili né selezionabili e restano escluse.
feat <- Reduce(
  function(x, y) merge(x, y, by = "NUTSCODE", all.x = TRUE),
  Filter(
    Negate(is.null),
    list(
      areas[, list(NUTSCODE, CNTR_CODE, NAME, area_km2)],
      clr_dt,
      dep,
      mig,
      pch,
      share_1564,
      pop,
      invest
    )
  )
)

# Derivate: densità e investimenti pro capite (con log)
feat[, density := pop / area_km2]
feat[,
  invest_pc := fifelse(
    !is.na(invest) & !is.na(pop) & pop > 0,
    invest * 1e6 / (pop * 1e3),
    NA_real_
  )
]
feat[, log_pop := log1p(pop)]
feat[, log_density := log1p(density)]
feat[, log_invest_pc := log1p(invest_pc)]

# Colonne feature finali (numeriche)
clr_cols <- grep("^clr_", names(feat), value = TRUE)
feature_cols <- c(
  clr_cols,
  "dep_ratio",
  "net_migr",
  "pop_change",
  "share_1564",
  "log_pop",
  "log_density",
  "log_invest_pc"
)
feature_cols <- intersect(feature_cols, names(feat))

# Scarta regioni extra-territoriali / con troppi NA
n_feat <- length(feature_cols)
feat[, n_na := rowSums(is.na(.SD)), .SDcols = feature_cols]
dropped <- feat[n_na > 0.4 * n_feat, NUTSCODE]
if (length(dropped) > 0L) {
  message("Regioni scartate (troppi NA): ", paste(dropped, collapse = ", "))
}
feat <- feat[n_na <= 0.4 * n_feat]

# Imputazione NA residui con mediana di paese (fallback mediana globale)
for (col in feature_cols) {
  feat[,
    (col) := {
      x <- get(col)
      med_c <- median(x, na.rm = TRUE)
      x[is.na(x)] <- med_c
      x
    },
    by = CNTR_CODE
  ]
  gmed <- median(feat[[col]], na.rm = TRUE)
  feat[is.na(get(col)), (col) := gmed]
}

# 9. Standardizzazione (z-score) -----

X <- as.matrix(feat[, ..feature_cols])
rownames(X) <- feat$NUTSCODE
center <- colMeans(X)
scale_sd <- apply(X, 2, sd)
scale_sd[scale_sd == 0] <- 1
Z <- sweep(sweep(X, 2, center, "-"), 2, scale_sd, "/")

# 10. PCA (>= 90% varianza) -----

pca <- prcomp(Z, center = FALSE, scale. = FALSE)
var_expl <- cumsum(pca$sdev^2) / sum(pca$sdev^2)
k <- which(var_expl >= 0.90)[1]
if (is.na(k)) {
  k <- ncol(pca$x)
}
message(sprintf("PCA: %d componenti per %.1f%% varianza", k, 100 * var_expl[k]))
PC <- pca$x[, seq_len(k), drop = FALSE]

# 11. Distanze nello spazio PC + ranking -----

dmat <- as.matrix(dist(PC, method = "euclidean"))
codes <- rownames(PC)
dist_long <- rbindlist(lapply(codes, function(ref) {
  d <- data.table(
    REF_NUTSCODE = ref,
    NBR_NUTSCODE = codes,
    distance = dmat[ref, ]
  )
  setorder(d, distance)
  d[, rank := seq_len(.N)]
  d
}))
dbWriteTable(con, "region_distances", dist_long, overwrite = TRUE)

# 12. Contributi per feature (spazio standardizzato) -----

contrib <- rbindlist(lapply(codes, function(ref) {
  rbindlist(lapply(setdiff(codes, ref), function(nbr) {
    gap <- Z[nbr, ] - Z[ref, ]
    data.table(
      REF_NUTSCODE = ref,
      NBR_NUTSCODE = nbr,
      FEATURE = feature_cols,
      gap = as.numeric(gap),
      contrib = as.numeric(gap^2)
    )
  }))
}))
dbWriteTable(con, "feature_contributions", contrib, overwrite = TRUE)

# 13. Cross-check cluster (hclust + kmeans) -----

n_clusters <- max(4L, round(sqrt(nrow(PC) / 2)))
hc <- hclust(dist(PC), method = "ward.D2")
hc_cl <- cutree(hc, k = n_clusters)
set.seed(42)
km <- kmeans(PC, centers = n_clusters, nstart = 25, iter.max = 100)
cluster_dt <- data.table(
  NUTSCODE = codes,
  hclust_cluster = hc_cl,
  kmeans_cluster = km$cluster
)
dbWriteTable(con, "cluster_assignments", cluster_dt, overwrite = TRUE)

# Accordo kNN vs cluster per il riferimento di default
ref0 <- REF_DEFAULT
if (ref0 %in% codes) {
  top4 <- dist_long[REF_NUTSCODE == ref0 & NBR_NUTSCODE != ref0][order(rank)][
    1:4,
    NBR_NUTSCODE
  ]
  ref_hc <- cluster_dt[NUTSCODE == ref0, hclust_cluster]
  same_cl <- cluster_dt[NUTSCODE %in% top4, sum(hclust_cluster == ref_hc)]
  message(sprintf("Top-4 di %s nello stesso cluster: %d/4", ref0, same_cl))
}

# 14. Tabelle feature (wide raw, z, long) + etichette -----

dbWriteTable(
  con,
  "region_features",
  feat[, c("NUTSCODE", "CNTR_CODE", "NAME", feature_cols), with = FALSE],
  overwrite = TRUE
)

z_dt <- data.table(NUTSCODE = rownames(Z), Z)
dbWriteTable(con, "region_features_z", z_dt, overwrite = TRUE)

feat_long <- melt(
  feat[, c("NUTSCODE", feature_cols), with = FALSE],
  id.vars = "NUTSCODE",
  variable.name = "FEATURE",
  value.name = "value_raw"
)
z_long <- melt(
  z_dt,
  id.vars = "NUTSCODE",
  variable.name = "FEATURE",
  value.name = "value_z"
)
feat_long <- merge(feat_long, z_long, by = c("NUTSCODE", "FEATURE"))
dbWriteTable(con, "region_features_long", feat_long, overwrite = TRUE)

# Etichette feature (italiano)
feature_labels <- data.table(
  FEATURE = c(
    paste0("clr_", c("A", "BE", "F", "GJ", "K", "L", "MN", "OQ", "RU")),
    "dep_ratio",
    "net_migr",
    "pop_change",
    "share_1564",
    "log_pop",
    "log_density",
    "log_invest_pc"
  ),
  label_it = c(
    "Quota VA: agricoltura",
    "Quota VA: industria",
    "Quota VA: costruzioni",
    "Quota VA: commercio/trasporti/ICT",
    "Quota VA: finanza",
    "Quota VA: immobiliare",
    "Quota VA: servizi professionali",
    "Quota VA: PA/istruzione/sanità",
    "Quota VA: altri servizi",
    "Indice di dipendenza",
    "Migrazione netta (per 1000)",
    "Variazione popolazione (per 1000)",
    "Quota popolazione 15-64",
    "Popolazione (log)",
    "Densità abitativa (log)",
    "Investimenti pro capite (log)"
  )
)
feature_labels <- feature_labels[FEATURE %in% feature_cols]
dbWriteTable(con, "feature_labels", feature_labels, overwrite = TRUE)

# 15. Aggiorna eu_meta e salva modello PCA -----

meta_new <- data.table(
  metric = c("PCA_K", "PCA_VAR_EXPLAINED", "N_FEATURES", "N_REGIONS"),
  value = c(k, round(100 * var_expl[k], 1), n_feat, nrow(PC))
)
setnames(meta_new, "metric", "key")
meta2 <- rbind(meta, meta_new)
dbWriteTable(con, "eu_meta", meta2, overwrite = TRUE)

pca_model <- list(
  prcomp = pca,
  center = center,
  scale = scale_sd,
  feature_names = feature_cols,
  log_features = c("log_pop", "log_density", "log_invest_pc"),
  k = k,
  year_ref = year_ref
)
saveRDS(pca_model, EU_PCA_PATH)

# 16. Riepilogo -----

message("\n========== Profili di similarità ==========")
message(sprintf(
  "Regioni: %d | feature: %d | PC: %d (%.1f%% var)",
  nrow(PC),
  n_feat,
  k,
  100 * var_expl[k]
))
if (ref0 %in% codes) {
  message(sprintf(
    "\nTop-4 regioni più simili a %s (%s):",
    ref0,
    areas[NUTSCODE == ref0, NAME]
  ))
  top <- dist_long[REF_NUTSCODE == ref0 & NBR_NUTSCODE != ref0][order(rank)][
    1:4
  ]
  top <- merge(
    top,
    areas[, list(NUTSCODE, NAME, CNTR_CODE)],
    by.x = "NBR_NUTSCODE",
    by.y = "NUTSCODE"
  )
  setorder(top, rank)
  for (i in seq_len(nrow(top))) {
    message(sprintf(
      "  %d. %s (%s) — distanza %.2f",
      top$rank[i],
      top$NAME[i],
      top$CNTR_CODE[i],
      top$distance[i]
    ))
  }
}
message(sprintf("\nModello PCA salvato: %s", EU_PCA_PATH))
