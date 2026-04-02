# ==============================================================================
# 01_download_data.R
# Download ARDECO data for Lombardia (NUTS2 ITC4) and its provinces (NUTS3).
# Output: one Parquet file per variable in data/
# ==============================================================================

# 1. Load libraries -----

library(ARDECO)
library(arrow)
library(data.table)

# 2. Download and save the variable list -----

variable_list <- ardeco_get_variable_list()
write_parquet(as.data.frame(variable_list), "data/variable_list.parquet")
message("Variable list saved to data/variable_list.parquet")

# 3. Define thematic groups -----

thematic_groups <- list(
  popolazione_demografia = c(
    "SNPTD",
    "SNPTN",
    "SNPBN",
    "SNPDN",
    "SNPNN",
    "SNMTN",
    "SNPCN"
  ),
  mercato_lavoro = c(
    "SNETD",
    "SNWTD",
    "RNECN",
    "RNUTN",
    "RNLCN",
    "RNLHT",
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
    "SOVGDE"
  ),
  reddito_compensi = c(
    "RUWCD",
    "ROWCD"
  ),
  formazione_capitale = c(
    "RUIGT",
    "ROIGT",
    "RUIGZ",
    "ROIGZ"
  )
)

# 4. Download function -----

#' Download a single ARDECO variable.
#'
#' Wraps ardeco_get_dataset_data() with error handling. Returns a data.table
#' on success or NULL on failure, logging the error message.
#'
#' @param var_code Character. ARDECO variable code.
#' @param nutscode Character. NUTS code filter (default "ITC4" for Lombardia).
#' @param level Character. NUTS levels to retrieve (default "2,3").
#' @param version Numeric. NUTS version year (default 2024).
#' @return A data.table or NULL on failure.
download_variable <- function(
  var_code,
  nutscode = "ITC4",
  level = "2,3",
  version = 2024
) {
  tryCatch(
    {
      dl <- ardeco_get_dataset_data(
        var_code,
        nutscode = nutscode,
        level = level,
        version = version
      )
      if (is.null(dl) || nrow(dl) == 0L) {
        message("  [WARN] No data returned for ", var_code)
        return(NULL)
      }
      as.data.table(dl)
    },
    error = function(e) {
      message(
        "  [ERROR] Failed to download ",
        var_code,
        ": ",
        conditionMessage(e)
      )
      NULL
    }
  )
}

# 5. Main loop: download and save each variable -----

all_vars <- unique(unlist(thematic_groups, use.names = FALSE))
message("\nDownloading ", length(all_vars), " variables\n")

# Build a lookup from variable code to group name
var_to_group <- character(0)
for (gn in names(thematic_groups)) {
  for (vc in thematic_groups[[gn]]) {
    var_to_group[vc] <- gn
  }
}

# Pre-allocate summary log
summary_log <- data.table(
  var_code = character(length(all_vars)),
  group = character(length(all_vars)),
  n_rows = integer(length(all_vars)),
  status = character(length(all_vars))
)

for (i in seq_along(all_vars)) {
  vc <- all_vars[i]
  gn <- var_to_group[vc]
  message(sprintf("[%2d/%d] %s (%s)", i, length(all_vars), vc, gn))

  dt <- download_variable(vc)

  if (!is.null(dt)) {
    out_path <- file.path("data", paste0(vc, ".parquet"))
    write_parquet(dt, out_path)
    message("  Saved ", nrow(dt), " rows to ", out_path)

    set(summary_log, i, "var_code", vc)
    set(summary_log, i, "group", gn)
    set(summary_log, i, "n_rows", nrow(dt))
    set(summary_log, i, "status", "OK")
  } else {
    set(summary_log, i, "var_code", vc)
    set(summary_log, i, "group", gn)
    set(summary_log, i, "n_rows", 0L)
    set(summary_log, i, "status", "FAILED")
  }
}

# 6. Generate labels -----

source("R/labels.R", local = FALSE)

# 7. Summary -----

message("\n========== Download summary ==========")
for (i in seq_len(nrow(summary_log))) {
  row <- summary_log[i]
  msg <- sprintf(
    "  %-6s | %-25s | %7d rows | %s",
    row$var_code,
    row$group,
    row$n_rows,
    row$status
  )
  message(msg)
}

n_ok <- summary_log[status == "OK", .N]
n_failed <- summary_log[status == "FAILED", .N]

message(sprintf(
  "\nTotal: %d OK, %d FAILED out of %d variables.",
  n_ok,
  n_failed,
  nrow(summary_log)
))

if (n_failed > 0L) {
  failed_vars <- summary_log[status == "FAILED", var_code]
  message("Failed variables: ", paste(failed_vars, collapse = ", "))
} else {
  message("All variables downloaded successfully.")
}
