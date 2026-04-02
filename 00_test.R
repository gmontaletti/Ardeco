# install.packages("ARDECO")
library(ARDECO)
library(ARDECO)

# 1. Esplora le variabili disponibili
vars <- ardeco_get_variable_list()
print(vars, n = 30)

# 2. Verifica i dataset e le dimensioni di una variabile
# Esempio: occupazione per settore NACE

tlist <- ardeco_get_tercet_list("SOVGDH")

ds <- ardeco_get_dataset_list("SOVGDH")
print(ds)

# 3. Scarica i dati con filtri
# Occupazione totale (tutti i settori) per le regioni italiane NUTS2
# anni 2010-2023
dati <- ardeco_get_dataset_data(
  "SOVGDH",
  nutscode  = "IT",
  level     = "2",
  unit      = "EUR2015"
  , version = 2024
  , verbose = TRUE
)

# 4. Il risultato è un tibble pronto all'uso
str(dati)
