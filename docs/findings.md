# Findings

## Current Data Structure
- 6 thematic parquet files, each containing multiple ARDECO variables (combined with `var_code` column)
- Columns: VARIABLE, VERSIONS, LEVEL, NUTSCODE, YEAR, UNIT, VALUE, var_code, plus optional SEX, AGE, SECTOR
- variable_list.parquet has: code, description (English only)

## Variable Dimensions
| Dataset | Variables | Extra Dims | Units |
|---------|-----------|------------|-------|
| popolazione_demografia | 7 vars | SEX, AGE | NR, GROWRT |
| mercato_lavoro | 6 vars | SEX, AGE | THS |
| occupazione_settore | 2 vars | SECTOR | THS |
| pil_valore_aggiunto | 6 vars | SECTOR | MIO_EUR, MIO_PPS, MIO_EUR2015, MIO_EUR2020 |
| reddito_compensi | 2 vars | none | MIO_EUR, MIO_PPS, MIO_EUR2015, MIO_EUR2020 |
| formazione_capitale | 4 vars | SECTOR | MIO_EUR, MIO_PPS, MIO_EUR2015, MIO_EUR2020 |

## Dashboard Issues (current)
- Tab labels show raw variable codes (e.g., "SNPTD") instead of meaningful Italian names
- `dedup_filter()` hides multi-value dimensions (SEX, AGE, SECTOR) with hardcoded defaults
- Timelines may show multiple values per time period when filters don't fully deduplicate
- No user controls for selecting UNIT, SEX, AGE, or SECTOR

## Variables Used (27 total)
- SNPTD: Popolazione media annua
- SNPTN: Popolazione al 1 gennaio per fascia d'età e sesso
- SNPBN: Nati vivi per sesso
- SNPDN: Decessi per fascia d'età e sesso
- SNPNN: Variazione naturale della popolazione
- SNMTN: Migrazione netta per fascia d'età e sesso
- SNPCN: Variazione della popolazione per fascia d'età e sesso
- SNETD: Occupazione workplace-based
- SNWTD: Dipendenti workplace-based
- RNECN: Occupazione residence-based (20-64)
- RNUTN: Disoccupazione (15-74, sperimentale)
- RNLCN: Forza lavoro (15+)
- RNLHT: Ore lavorate (occupati)
- SNETZ: Occupazione per settore NACE
- RNLHZ: Ore lavorate per settore NACE
- SUVGD: PIL a prezzi correnti
- SOVGD: PIL a prezzi costanti
- SUVGE: VAL a prezzi base correnti
- SOVGE: VAL a prezzi base costanti
- SUVGZ: VAL per settore a prezzi correnti
- SOVGZ: VAL per settore a prezzi costanti
- RUWCD: Compensi dei dipendenti a prezzi correnti
- ROWCD: Compensi dei dipendenti a prezzi costanti
- RUIGT: FBCF a prezzi correnti
- ROIGT: FBCF a prezzi costanti
- RUIGZ: FBCF per settore a prezzi correnti
- ROIGZ: FBCF per settore a prezzi costanti
