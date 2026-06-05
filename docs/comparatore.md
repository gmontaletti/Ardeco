# Comparatore regionale europeo

Esercizio di confronto tra le regioni NUTS2 dei paesi europei coperti da ARDECO
(UE27 + EFTA + candidati/Balcani occidentali; la lista è in
`R/comparatore/00_config_eu.R`, variabile `EU_COUNTRIES`). Individua le regioni
strutturalmente più simili a una di riferimento (default Lombardia, `ITC4`) e ne
confronta gli andamenti del mercato del lavoro.

La copertura per regione è disomogenea: i micro-stati (CY, LU, MT, LI, EE, IS)
sono un'unica regione NUTS2; i paesi candidati hanno serie di contabilità
nazionale più sparse. Il calcolo della similarità scarta automaticamente le
regioni con troppi valori mancanti e quelle prive di geometria GISCO.

Gli artefatti sono **paralleli** alla pipeline di produzione Lombardia e non la
modificano: database `data/ardeco_eu.duckdb`, geometrie `data/eu_nuts2.gpkg`,
modello `data/eu_pca_model.rds`, dashboard `dashboard/comparatore.Rmd` (tutti
esclusi dal versionamento).

## Pipeline

Eseguire in ordine dalla radice del progetto:

```
Rscript R/comparatore/99_smoke_test_eu.R   # verifica API multi-paese (opzionale)
Rscript R/comparatore/01_download_eu.R     # 57 variabili x livelli 0,2 -> ardeco_eu.duckdb
Rscript R/comparatore/02_download_geo_eu.R # geometrie NUTS2 -> eu_nuts2.gpkg
Rscript R/comparatore/03_labour_indicators.R # indicatori comparabili del lavoro
Rscript R/comparatore/04_build_profiles.R    # similarità: feature, PCA, distanze, cluster
```

Dashboard (dalla cartella `dashboard/`):

```
R -e 'rmarkdown::run("comparatore.Rmd")'
```

`00_config_eu.R` è la configurazione condivisa (paesi, percorsi, gruppi tematici,
etichette, `download_variable()`); i blocchi di definizione sono copiati da
`R/01_build_duckdb.R` per non accoppiarsi al codice di produzione.

## Principio metodologico: insiemi disgiunti

Le variabili che determinano la **similarità** sono disgiunte da quelle usate per
il **confronto** del mercato del lavoro, per evitare circolarità (selezionare
regioni simili su un esito e poi "scoprire" che condividono quell'esito).
`04_build_profiles.R` verifica a runtime che l'intersezione sia vuota.

## Indicatori del lavoro confrontati (solo rapporti / serie comparabili)

Per i confronti di livello tra paesi si usano valori in **PPS** (la Polonia non è
nell'area euro) o **reali** (prezzi 2015) per i trend; tassi e quote in punti
percentuali. Mai livelli assoluti.

| Indicatore | Fonte / formula | Unità |
|---|---|---|
| Tasso di occupazione (20-64) | RPECNP | % |
| Tasso di disoccupazione (15-74) | RPUCNP | % |
| Produttività per occupato (reale) | SOVGDE | euro 2015/occupato |
| Produttività per ora (reale) | SOVGDH | euro 2015/ora |
| Produttività per occupato (PPS) | SUVGD(PPS) / SNETD | PPS/occupato |
| PIL pro capite (PPS) | SUVGDP | PPS/abitante |
| PIL pro capite (reale) | SOVGDP | euro 2015/abitante |
| Compenso reale per ora | ROWCDH | euro 2015/ora |
| Quota dipendenti su occupati | SNWTD / SNETD | % |
| Ore lavorate per occupato | RNLHT / SNETD | ore/anno |

## Variabili strutturali per la similarità (benchmark)

Composizione settoriale del valore aggiunto (`SUVGZ`, trasformazione clr),
demografia (`SPPAN` dipendenza, `SNMTNP` migrazione netta, `SNPCNP` variazione,
quota 15-64 da `SNPTN`), taglia e densità (`SNPTD`, area dal gpkg) e intensità di
formazione del capitale (`RUIGT` pro capite). Circa 16 feature.

Metodo: standardizzazione z-score → PCA (componenti fino al 90% della varianza) →
distanza euclidea nello spazio delle componenti principali (equivalente a una
distanza di Mahalanobis denoised; pesatura empirica, nessun peso arbitrario). Le
prime 4 regioni più vicine alla regione di riferimento sono il suggerimento
automatico.

## Raggruppamento in tipi di regione e outlier

Le regioni europee formano un **continuum strutturale**, senza gruppi densi ben
separati: un metodo a densità (HDBSCAN) etichetterebbe come rumore gran parte del
campione. Il raggruppamento usa quindi il **clustering partizionale ward**
(`WARD_K = 6` gruppi, configurabile in `00_config_eu.R`) sullo spazio delle
componenti principali, che produce tipi di regione leggibili e coesi (le 4 aree
più simili al riferimento ricadono di norma nel suo stesso gruppo).

HDBSCAN è usato per ciò in cui è efficace su questi dati: il **punteggio di
atipicità** (GLOSH `outlier_score`). Le regioni con score ≥ `OUTLIER_THRESHOLD`
(0,7) sono segnalate come strutturalmente anomale — tipicamente capitali e
città-stato, territori d'oltremare, aree artiche. La tabella `cluster_assignments`
nel DuckDB contiene `cluster` (ward), `outlier_score`, `is_outlier` e, come
controllo di robustezza, `kmeans_cluster` e `density_cluster`.

## Dashboard

Due pagine (flexdashboard + Shiny):

1. **Selezione aree** — scelta della regione di riferimento, suggerimento
   automatico delle 4 più simili (modificabile a mano o cliccando sulla mappa),
   mappa coropletica europea e classifica di similarità con le feature
   che più contribuiscono alla distanza. La mappa ha due modalità (selettore
   «Colore mappa»): *Ruoli* evidenzia riferimento e aree selezionate; *Cluster*
   colora le regioni per tipo strutturale (gruppi ward) e mostra in grigio le
   aree atipiche (outlier). Il pulsante «Seleziona aree del cluster di …»
   riempie il confronto con le 6 regioni più vicine appartenenti allo stesso
   tipo del riferimento, e un value box riporta il cluster del riferimento e la
   sua numerosità (segnalando se è strutturalmente atipico). In fondo, una
   tabella «Profilo strutturale» riporta i valori delle aree selezionate per
   ogni variabile di similarità; lo sfondo di ciascuna cella ne segnala lo
   scostamento dalla regione di riferimento (blu = inferiore, arancio =
   superiore; intensità in deviazioni standard), così da evidenziare a colpo
   d'occhio le caratteristiche su cui le aree differiscono di più.
2. **Confronto mercato del lavoro** — per le aree selezionate, andamento storico
   di un indicatore comparabile (regione di riferimento evidenziata), confronto a
   barre dell'ultimo anno e tabella esportabile.
