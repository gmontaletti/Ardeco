# ARDECO DuckDB — Rapporto esplorativo

Database: `data/ardeco.duckdb` — dati regionali ARDECO per la Lombardia (NUTS2 ITC4) e le 12 province (NUTS3).

## 1. Struttura del database

9 tabelle:

| Tabella | Righe | Descrizione |
|---|---|---|
| `ardeco_data` | 259.259 | Dati principali (59 variabili) |
| `variable_list` | 83 | Catalogo variabili ARDECO API |
| `var_labels` | 59 | Etichette e descrizioni variabili |
| `download_log` | 59 | Log di download (stato, tempi) |
| `unit_labels` | 16 | Etichette unità di misura |
| `sector_labels` | 13 | Etichette settori NACE |
| `age_labels` | 10 | Etichette classi di età |
| `group_labels` | 6 | Etichette gruppi tematici |
| `sex_labels` | 3 | Etichette sesso |

### Schema `ardeco_data`

| Colonna | Tipo | Nullable | Contenuto |
|---|---|---|---|
| VARIABLE | VARCHAR | NOT NULL | Codice variabile ARDECO |
| VERSIONS | INTEGER | sì | Versione NUTS |
| LEVEL | INTEGER | sì | Livello NUTS (2 o 3) |
| NUTSCODE | VARCHAR | NOT NULL | Codice territoriale |
| YEAR | INTEGER | NOT NULL | Anno di riferimento |
| UNIT | VARCHAR | sì | Unità di misura |
| VALUE | DOUBLE | sì | Valore numerico |
| SEX | VARCHAR | sì | Sesso (F, M, TOTAL) |
| AGE | VARCHAR | sì | Classe di età |
| SECTOR | VARCHAR | sì | Settore NACE |
| ISCED11 | VARCHAR | sì | Livello di istruzione (non utilizzato) |
| THEMATIC_GROUP | VARCHAR | NOT NULL | Gruppo tematico |

## 2. Inventario delle dimensioni

### Gruppi tematici (6)

| group_id | Etichetta | Variabili | Righe | % totale |
|---|---|---|---|---|
| popolazione_demografia | Popolazione e demografia | 12 | 140.192 | 54,1% |
| formazione_capitale | Formazione del capitale | 9 | 40.534 | 15,6% |
| pil_valore_aggiunto | PIL e valore aggiunto | 14 | 35.386 | 13,6% |
| reddito_compensi | Reddito e compensi | 10 | 27.053 | 10,4% |
| occupazione_settore | Occupazione per settore | 2 | 10.140 | 3,9% |
| mercato_lavoro | Mercato del lavoro | 12 | 5.954 | 2,3% |

### Unità di misura (15)

| Codice | Etichetta |
|---|---|
| NR | Numero |
| THS | Migliaia |
| PC | Percentuale |
| GROWRT | Tasso di crescita (‰) |
| MIO_EUR | Milioni di euro |
| MIO_EUR2015 | Milioni di euro (prezzi 2015) |
| MIO_EUR2020 | Milioni di euro (prezzi 2020) |
| MIO_PPS_EU27_2020 | Milioni di PPS (EU27 2020) |
| EUR | Euro |
| EUR2015 | Euro (prezzi 2015) |
| EUR2020 | Euro (prezzi 2020) |
| EUR_HAB | Euro per abitante |
| EUR_HAB2015 | Euro per abitante (prezzi 2015) |
| PPS_HAB | PPS per abitante |
| PPS_EU27_2020 | PPS (EU27 2020) |

### Sesso (3)

TOTAL, F, M

### Classi di età (32 valori distinti nei dati)

Classi con etichetta definita (10): TOTAL, Y15-39, Y15-64, Y20-64, Y40-64, Y_GE15, Y_GE65, Y_LT15, Y_LT20, Y_LT15-GE65.

Classi aggiuntive presenti nei dati (22): Y10-14, Y15-19, Y15-29, Y20-24, Y20-29, Y25-29, Y25-64, Y30-34, Y35-39, Y40-44, Y45-49, Y5-9, Y50-54, Y55-59, Y60-64, Y65-69, Y70-74, Y75-79, Y80-84, Y85-89, Y_GE85, Y_GE90.

### Settori NACE (13)

| Codice | Etichetta |
|---|---|
| A | Agricoltura, silvicoltura e pesca |
| B-E | Industria (escluse costruzioni) |
| F | Costruzioni |
| G-I | Commercio, trasporti, alloggio e ristorazione |
| G-J | Commercio, trasporti, informazione e comunicazione |
| J | Informazione e comunicazione |
| K | Attività finanziarie e assicurative |
| K-N | Attività finanziarie, immobiliari, professionali |
| L | Attività immobiliari |
| M_N | Attività professionali, scientifiche e tecniche |
| O-Q | PA, istruzione, sanità |
| O-U | PA, istruzione, sanità e altri servizi |
| R-U | Altre attività di servizi |

## 3. Distribuzione per livello NUTS

| Livello | Codici | Righe | % totale |
|---|---|---|---|
| NUTS 2 (regione) | ITC4 | 19.969 | 7,7% |
| NUTS 3 (province) | ITC41–ITC4D (12) | 239.290 | 92,3% |

Tutte le 59 variabili sono disponibili a entrambi i livelli NUTS.

Righe per codice NUTS3:

| NUTSCODE | Righe |
|---|---|
| ITC41 | 19.941 |
| ITC42 | 19.941 |
| ITC43 | 19.941 |
| ITC44 | 19.941 |
| ITC46 | 19.941 |
| ITC47 | 19.941 |
| ITC48 | 19.941 |
| ITC49 | 19.941 |
| ITC4A | 19.941 |
| ITC4B | 19.941 |
| ITC4C | 19.941 |
| ITC4D | 19.939 |

La distribuzione è uniforme tra le province (~19.941 righe ciascuna).

## 4. Copertura temporale per variabile

| Variabile | Gruppo | Anno min | Anno max | Righe | Codici NUTS |
|---|---|---|---|---|---|
| SNPTD | popolazione_demografia | 1960 | 2027 | 884 | 13 |
| SNPTN | popolazione_demografia | 1960 | 2027 | 17.186 | 13 |
| SNPTZ | popolazione_demografia | 1960 | 2025 | 48.906 | 13 |
| SNPBN | popolazione_demografia | 1990 | 2024 | 1.365 | 13 |
| SNPDN | popolazione_demografia | 1990 | 2023 | 8.398 | 13 |
| SNPDZ | popolazione_demografia | 1990 | 2023 | 26.520 | 13 |
| SNPNN | popolazione_demografia | 1990 | 2023 | 7.956 | 13 |
| SNMTN | popolazione_demografia | 1990 | 2023 | 7.956 | 13 |
| SNPCN | popolazione_demografia | 1960 | 2026 | 16.107 | 13 |
| SNPCNP | popolazione_demografia | 1961 | 2026 | 858 | 13 |
| SNMTNP | popolazione_demografia | 1990 | 2023 | 2.652 | 13 |
| SPPAN | popolazione_demografia | 1990 | 2025 | 1.404 | 13 |
| SNETD | mercato_lavoro | 1980 | 2027 | 624 | 13 |
| SNETDP | mercato_lavoro | 1980 | 2027 | 624 | 13 |
| SNWTD | mercato_lavoro | 1995 | 2027 | 429 | 13 |
| RNECN | mercato_lavoro | 1995 | 2026 | 418 | 13 |
| RNUTN | mercato_lavoro | 1995 | 2027 | 428 | 13 |
| RNLCN | mercato_lavoro | 1995 | 2024 | 390 | 13 |
| RNLHT | mercato_lavoro | 1980 | 2027 | 624 | 13 |
| RNLHTP | mercato_lavoro | 1980 | 2027 | 624 | 13 |
| RNLHTE | mercato_lavoro | 1980 | 2027 | 624 | 13 |
| RNLHW | mercato_lavoro | 1995 | 2024 | 390 | 13 |
| RPECNP | mercato_lavoro | 1995 | 2024 | 390 | 13 |
| RPUCNP | mercato_lavoro | 1995 | 2024 | 389 | 13 |
| SNETZ | occupazione_settore | 1995 | 2024 | 5.070 | 13 |
| RNLHZ | occupazione_settore | 1995 | 2024 | 5.070 | 13 |
| SUVGD | pil_valore_aggiunto | 1980 | 2027 | 1.053 | 13 |
| SOVGD | pil_valore_aggiunto | 1980 | 2027 | 1.235 | 13 |
| SUVGE | pil_valore_aggiunto | 1980 | 2027 | 1.053 | 13 |
| SOVGE | pil_valore_aggiunto | 1980 | 2027 | 1.235 | 13 |
| SUVGZ | pil_valore_aggiunto | 1995 | 2024 | 10.140 | 13 |
| SOVGZ | pil_valore_aggiunto | 1995 | 2024 | 10.140 | 13 |
| SUVGDH | pil_valore_aggiunto | 1980 | 2027 | 1.053 | 13 |
| SUVGDE | pil_valore_aggiunto | 1980 | 2027 | 1.053 | 13 |
| SOVGDH | pil_valore_aggiunto | 1980 | 2027 | 1.235 | 13 |
| SOVGDE | pil_valore_aggiunto | 1980 | 2027 | 1.235 | 13 |
| SUVGDP | pil_valore_aggiunto | 1980 | 2027 | 1.053 | 13 |
| SOVGDP | pil_valore_aggiunto | 1980 | 2027 | 1.235 | 13 |
| SPVGD | pil_valore_aggiunto | 1980 | 2027 | 1.833 | 13 |
| SPVGE | pil_valore_aggiunto | 1980 | 2027 | 1.833 | 13 |
| RUWCD | reddito_compensi | 1980 | 2027 | 1.053 | 13 |
| ROWCD | reddito_compensi | 1980 | 2027 | 1.235 | 13 |
| RUWCDH | reddito_compensi | 1995 | 2024 | 780 | 13 |
| ROWCDH | reddito_compensi | 1980 | 2025 | 988 | 13 |
| RUWCDW | reddito_compensi | 1995 | 2027 | 858 | 13 |
| ROWCDW | reddito_compensi | 1980 | 2027 | 1.040 | 13 |
| RUWCDHH | reddito_compensi | 1995 | 2024 | 390 | 13 |
| RUWCDWE | reddito_compensi | 1995 | 2027 | 429 | 13 |
| RUWCZ | reddito_compensi | 1995 | 2024 | 10.140 | 13 |
| ROWCZ | reddito_compensi | 1995 | 2024 | 10.140 | 13 |
| RUIGT | formazione_capitale | 1980 | 2027 | 1.053 | 13 |
| ROIGT | formazione_capitale | 1980 | 2027 | 1.235 | 13 |
| RUIGZ | formazione_capitale | 1995 | 2024 | 10.140 | 13 |
| ROIGZ | formazione_capitale | 1995 | 2024 | 9.971 | 13 |
| ROKND | formazione_capitale | 1980 | 2027 | 1.235 | 13 |
| SUKCT | formazione_capitale | 1980 | 2027 | 624 | 13 |
| SOKCT | formazione_capitale | 1980 | 2027 | 1.235 | 13 |
| SUKCZ | formazione_capitale | 1995 | 2024 | 5.070 | 13 |
| SOKCZ | formazione_capitale | 1995 | 2024 | 9.971 | 13 |

Intervallo complessivo: 1960–2027 (68 anni). Le serie demografiche risalgono al 1960, quelle economiche in prevalenza al 1980.

## 5. Serie temporali uniche per livello NUTS

Una serie temporale è definita come una combinazione unica di (VARIABLE, NUTSCODE, UNIT, SEX, AGE, SECTOR, ISCED11).

| Livello | Serie temporali |
|---|---|
| NUTS 2 (regione) | 511 |
| NUTS 3 (province) | 6.084 |
| **Totale** | **6.595** |

Rapporto NUTS3/NUTS2: 11,9 (vicino a 12, il numero delle province).

## 6. Completezza dei dati e analisi dei NULL

### Completezza VALUE

Tutte le 259.259 righe hanno VALUE non nullo (100%).

### Dimensioni opzionali: copertura

| Dimensione | Righe con valore | Righe NULL | % con valore |
|---|---|---|---|
| UNIT | 259.259 | 0 | 100% |
| SEX | 138.712 | 120.547 | 53,5% |
| AGE | 138.412 | 120.847 | 53,4% |
| SECTOR | 85.852 | 173.407 | 33,1% |

### NULL per gruppo tematico

| Gruppo | NULL SEX | NULL AGE | NULL SECTOR |
|---|---|---|---|
| popolazione_demografia | 2.288 | 2.249 | 140.192 |
| mercato_lavoro | 5.146 | 5.536 | 5.954 |
| occupazione_settore | 10.140 | 10.140 | 0 |
| pil_valore_aggiunto | 35.386 | 35.386 | 15.106 |
| reddito_compensi | 27.053 | 27.053 | 6.773 |
| formazione_capitale | 40.534 | 40.534 | 5.382 |

Le dimensioni SEX e AGE sono popolate prevalentemente nelle variabili demografiche e del mercato del lavoro. SECTOR è presente nelle variabili disaggregate per settore (occupazione_settore al 100%, più le variabili con suffisso "Z" degli altri gruppi).

## 7. Statistiche descrittive di VALUE per gruppo tematico

| Gruppo | Min | Mediana | Media | Max | Dev. std. |
|---|---|---|---|---|---|
| popolazione_demografia | -87.870 | 4.092 | 81.366 | 10.033.918 | 427.535 |
| mercato_lavoro | 0,1 | 349 | 183.376 | 8.995.607 | 864.383 |
| occupazione_settore | 0,3 | 1.169 | 78.470 | 2.594.733 | 263.620 |
| pil_valore_aggiunto | -10,9 | 2.235 | 16.503 | 578.869 | 40.090 |
| reddito_compensi | 0,3 | 790 | 6.645 | 232.850 | 18.116 |
| formazione_capitale | 3,5 | 386 | 6.973 | 1.207.384 | 56.241 |

I valori negativi in popolazione_demografia corrispondono a saldi migratori e variazioni di popolazione. La dispersione elevata nel mercato del lavoro riflette la compresenza di unità di misura diverse (numeri assoluti, percentuali, ore).

## 8. Top 10 variabili per numero di righe

| # | Variabile | Gruppo | Righe |
|---|---|---|---|
| 1 | SNPTZ | popolazione_demografia | 48.906 |
| 2 | SNPDZ | popolazione_demografia | 26.520 |
| 3 | SNPTN | popolazione_demografia | 17.186 |
| 4 | SNPCN | popolazione_demografia | 16.107 |
| 5 | SUVGZ | pil_valore_aggiunto | 10.140 |
| 6 | SOVGZ | pil_valore_aggiunto | 10.140 |
| 7 | RUWCZ | reddito_compensi | 10.140 |
| 8 | ROWCZ | reddito_compensi | 10.140 |
| 9 | RUIGZ | formazione_capitale | 10.140 |
| 10 | ROIGZ | formazione_capitale | 9.971 |

Le variabili con suffisso "Z" (disaggregazione settoriale) e le demografiche per classi di età generano il maggior volume di dati per la moltiplicazione delle dimensioni.

## 9. Osservazioni

- 22 classi di età presenti nei dati (classi quinquennali Eurostat) non hanno una corrispondenza nella tabella `age_labels`, che contiene solo 10 aggregazioni. Valutare l'integrazione delle etichette mancanti.
- Le unità I15, I20 e PCH_PRE presenti nei dati non compaiono nella tabella `unit_labels`.
- La dimensione file (~2,4 MB) è contenuta grazie alla compressione colonnare di DuckDB.
- La colonna ISCED11 è presente nello schema ma non contiene valori per le 59 variabili attive.

---

*Generato il 2026-04-10 da `data/ardeco.duckdb` (259.259 righe, 59 variabili, 6.595 serie temporali, 6 gruppi tematici).*
