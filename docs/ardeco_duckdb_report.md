# ARDECO DuckDB — Rapporto esplorativo

Database: `data/ardeco.duckdb` — dati regionali ARDECO per la Lombardia (NUTS2 ITC4) e le 12 province (NUTS3).

## 1. Struttura del database

9 tabelle:

| Tabella | Righe | Descrizione |
|---|---|---|
| `ardeco_data` | 257.855 | Dati principali (57 variabili) |
| `variable_list` | 83 | Catalogo variabili ARDECO API |
| `var_labels` | 57 | Etichette e descrizioni variabili |
| `download_log` | 57 | Log di download (stato, tempi) |
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
| popolazione_demografia | Popolazione e demografia | 12 | 140.192 | 54,4% |
| formazione_capitale | Formazione del capitale | 9 | 40.534 | 15,7% |
| pil_valore_aggiunto | PIL e valore aggiunto | 14 | 35.386 | 13,7% |
| reddito_compensi | Reddito e compensi | 9 | 26.273 | 10,2% |
| occupazione_settore | Occupazione per settore | 2 | 10.140 | 3,9% |
| mercato_lavoro | Mercato del lavoro | 11 | 5.330 | 2,1% |

### Unità di misura (15)

| Codice | Etichetta |
|---|---|
| NR | Numero |
| THS | Migliaia |
| THS_HW | Migliaia di ore lavorate |
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

Classi con etichetta definita (10): TOTAL, Y15-39, Y15-64, Y20-64, Y40-64, Y_GE15, Y_GE65, Y_LT15, Y_LT15-GE65, Y_LT20.

Classi aggiuntive presenti nei dati (22): Y5-9, Y10-14, Y15-19, Y20-24, Y20-29, Y25-29, Y30-34, Y35-39, Y40-44, Y45-49, Y50-54, Y55-59, Y60-64, Y65-69, Y70-74, Y75-79, Y80-84, Y85-89, Y_GE85, Y_GE90, Y_LT5, Y_LT20-GE65.

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
| NUTS 2 (regione) | ITC4 | 19.861 | 7,7% |
| NUTS 3 (province) | ITC41–ITC4D (12) | 237.994 | 92,3% |

Tutte le 57 variabili sono disponibili a entrambi i livelli NUTS.

Righe per codice NUTS3:

| NUTSCODE | Righe |
|---|---|
| ITC41 | 19.833 |
| ITC42 | 19.833 |
| ITC43 | 19.833 |
| ITC44 | 19.833 |
| ITC46 | 19.833 |
| ITC47 | 19.833 |
| ITC48 | 19.833 |
| ITC49 | 19.833 |
| ITC4A | 19.833 |
| ITC4B | 19.833 |
| ITC4C | 19.833 |
| ITC4D | 19.831 |

La distribuzione è uniforme tra le province (~19.833 righe ciascuna).

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
| NUTS 2 (regione) | 505 |
| NUTS 3 (province) | 6.048 |
| **Totale** | **6.553** |

Rapporto NUTS3/NUTS2: 12,0 (coerente con le 12 province).

## 6. Completezza dei dati e analisi dei NULL

### Completezza VALUE

Tutte le 257.855 righe hanno VALUE non nullo (100%).

### Dimensioni opzionali: copertura

| Dimensione | Righe con valore | Righe NULL | % con valore |
|---|---|---|---|
| UNIT | 257.855 | 0 | 100% |
| SEX | 138.712 | 119.143 | 53,8% |
| AGE | 138.361 | 119.494 | 53,7% |
| SECTOR | 85.852 | 172.003 | 33,3% |

### NULL per gruppo tematico

| Gruppo | NULL SEX | NULL AGE | NULL SECTOR |
|---|---|---|---|
| popolazione_demografia | 2.288 | 2.249 | 140.192 |
| mercato_lavoro | 4.522 | 4.912 | 5.330 |
| occupazione_settore | 10.140 | 10.140 | 0 |
| pil_valore_aggiunto | 35.386 | 35.386 | 15.106 |
| reddito_compensi | 26.273 | 26.273 | 5.993 |
| formazione_capitale | 40.534 | 40.534 | 5.382 |

Le dimensioni SEX e AGE sono popolate prevalentemente nelle variabili demografiche e del mercato del lavoro. SECTOR è presente nelle variabili disaggregate per settore (occupazione_settore al 100%, più le variabili con suffisso "Z" degli altri gruppi).

## 7. Statistiche descrittive di VALUE per gruppo tematico

| Gruppo | Min | Mediana | Media | Max | Dev. std. |
|---|---|---|---|---|---|
| popolazione_demografia | -87.870 | 4.092 | 81.366 | 10.033.918 | 427.537 |
| mercato_lavoro | 0,1 | 220 | 204.638 | 8.995.607 | 911.303 |
| occupazione_settore | 0,3 | 1.169 | 78.470 | 2.594.733 | 263.633 |
| pil_valore_aggiunto | -10,9 | 2.235 | 16.503 | 578.869 | 40.090 |
| reddito_compensi | 0,3 | 847 | 6.842 | 232.850 | 16.297 |
| formazione_capitale | 3,5 | 386 | 6.973 | 1.207.384 | 56.242 |

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
- La dimensione file (~10,8 MB) è contenuta grazie alla compressione colonnare di DuckDB.
- La colonna ISCED11 è presente nello schema ma non contiene valori per le 57 variabili attive.
- Rispetto alla versione precedente del database (59 variabili, 259.259 righe), sono state rimosse le variabili RUWCDH e RNLHTE (variabili provinciali invarianti), con una riduzione netta di 1.404 righe.

---

*Generato il 2026-04-12 da `data/ardeco.duckdb` (257.855 righe, 57 variabili, 6.553 serie temporali, 6 gruppi tematici).*
