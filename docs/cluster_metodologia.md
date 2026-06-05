# Come si formano i cluster di regioni

Guida didattica al raggruppamento delle regioni NUTS2 nel comparatore europeo.
Spiega che cosa è un cluster, quali variabili ARDECO entrano nel calcolo e in
quali passaggi i dati grezzi diventano gruppi di regioni «dello stesso tipo».

## 1. Che cosa è un cluster

Un cluster è un insieme di regioni con un **profilo strutturale simile**: stessa
composizione dei settori produttivi, demografia comparabile, dimensione e
intensità di investimento analoghe. Non è un raggruppamento geografico né
politico: due regioni finiscono nello stesso cluster perché si assomigliano nei
dati, non perché sono vicine o appartengono allo stesso paese.

Il comparatore individua **6 tipi di regione** (cluster) e, separatamente,
segnala una dozzina di regioni **atipiche** (outlier) la cui struttura non
rientra bene in nessun tipo.

## 2. Le variabili usate

I cluster si basano su **variabili strutturali** (la «base di confronto»), tenute
deliberatamente distinte dagli indicatori del mercato del lavoro usati nella
seconda pagina della dashboard: si evita così la circolarità (raggruppare le
regioni su un esito e poi «scoprire» che lo condividono).

Le variabili ARDECO necessarie, scaricate a livello NUTS2:

| Codice | Descrizione | A che cosa serve |
|---|---|---|
| `SUVGZ` | Valore aggiunto per settore (prezzi correnti) | Composizione settoriale dell'economia |
| `SPPAN` | Indice di dipendenza (sulla popolazione 20-64) | Carico demografico |
| `SNMTNP` | Migrazione netta per 1000 abitanti | Attrattività/spopolamento |
| `SNPCNP` | Variazione della popolazione per 1000 abitanti | Dinamica demografica |
| `SNPTN` | Popolazione per fascia d'età | Quota di popolazione in età lavorativa |
| `SNPTD` | Popolazione media annua | Taglia e (con l'area) densità |
| `RUIGT` | Investimenti fissi lordi (prezzi correnti) | Intensità di formazione del capitale |

Serve inoltre la **geometria NUTS2** (`eu_nuts2.gpkg`), da cui si ricava l'area in
km² per calcolare la densità abitativa.

Da queste variabili si costruiscono **16 caratteristiche numeriche** (feature):

- **Struttura settoriale del valore aggiunto** (9 quote, da `SUVGZ`):
  agricoltura, industria, costruzioni, commercio/trasporti/ICT, finanza,
  immobiliare, servizi professionali, PA/istruzione/sanità, altri servizi.
- **Demografia** (4): indice di dipendenza, migrazione netta, variazione della
  popolazione, quota di popolazione 15-64.
- **Taglia e densità** (2): popolazione (in logaritmo), densità abitativa (in
  logaritmo).
- **Capitale** (1): investimenti pro capite (in logaritmo).

## 3. Come vengono elaborate

I dati grezzi attraversano una sequenza di passaggi prima di arrivare ai cluster.

1. **Finestra temporale.** Per stabilizzare i valori si usa la media degli ultimi
   tre anni disponibili (anno di riferimento e i due precedenti), a livello NUTS2.

2. **Quote settoriali e trasformazione clr.** Il valore aggiunto di ogni settore
   è convertito in quota sul totale. Le quote sono poi trasformate con il
   *centered log-ratio* (clr): un accorgimento standard per i dati
   composizionali (quote che sommano a 1), che evita la distorsione dovuta al
   vincolo di somma.

3. **Rapporti e logaritmi.** Gli indicatori demografici restano rapporti (per
   1000 o punti percentuali). Popolazione, densità e investimenti pro capite sono
   presi in logaritmo, perché molto asimmetrici (poche regioni enormi, molte
   piccole).

4. **Pulizia dei dati.** Le regioni con più del 40% di caratteristiche mancanti
   sono scartate (tipicamente aree extra-territoriali o con serie incomplete). I
   valori mancanti residui sono imputati con la mediana del paese e, in mancanza,
   con la mediana europea.

5. **Standardizzazione (z-score).** Ogni caratteristica è riportata a media 0 e
   deviazione standard 1, così che variabili su scale diverse pesino allo stesso
   modo.

6. **Riduzione delle dimensioni (PCA).** L'analisi delle componenti principali
   comprime le 16 caratteristiche in poche componenti indipendenti, mantenendone
   abbastanza da spiegare almeno il 90% della varianza (nei dati attuali: 8
   componenti, 92,3%). Si lavora poi in questo spazio «ripulito dal rumore».

7. **Formazione dei gruppi (ward).** Nello spazio delle componenti principali si
   applica il **clustering gerarchico di Ward**, tagliato a **6 gruppi**. È un
   metodo *partizionale*: assegna ogni regione a un gruppo minimizzando la
   varianza interna. I gruppi risultano coesi — di norma le 4 regioni più simili
   a una di riferimento ricadono nel suo stesso gruppo.

8. **Segnalazione degli outlier (HDBSCAN).** Le regioni europee formano un
   *continuum* strutturale, senza gruppi nettamente separati: un metodo a densità
   come HDBSCAN, se usato per raggruppare, etichetterebbe come «rumore» la maggior
   parte delle regioni. Lo si usa quindi solo per ciò in cui è efficace: il
   **punteggio di atipicità** (GLOSH). Le regioni con punteggio ≥ 0,7 sono marcate
   come strutturalmente anomale — tipicamente capitali e città-stato, territori
   d'oltremare, aree artiche.

9. **Controllo di robustezza (k-means).** In parallelo si calcola anche un
   raggruppamento k-means, conservato come verifica indipendente dei gruppi ward.

## 4. Il risultato

Il calcolo produce, per ogni regione, una riga nella tabella
`cluster_assignments` del database:

- `cluster` — il tipo di regione (gruppo ward, da 1 a 6);
- `outlier_score` — il punteggio di atipicità (0-1);
- `is_outlier` — 1 se la regione è segnalata come atipica;
- `kmeans_cluster`, `density_cluster` — raggruppamenti alternativi, di controllo.

Nella dashboard, la mappa in modalità «Cluster» colora le regioni per tipo
(outlier in grigio) e il pulsante «Seleziona aree del cluster» riempie il
confronto con le 6 regioni più vicine dello stesso tipo.

## 5. Parametri configurabili

I tre parametri di taratura sono in `R/comparatore/00_config_eu.R`:

- `WARD_K` (= 6) — numero di tipi di regione;
- `HDBSCAN_MINPTS` (= 8) — parametro di densità del punteggio di atipicità;
- `OUTLIER_THRESHOLD` (= 0,7) — soglia oltre la quale una regione è un outlier.

Tutta l'elaborazione è nello script `R/comparatore/04_build_profiles.R`; per
rigenerare i cluster è sufficiente rieseguirlo (`Rscript
R/comparatore/04_build_profiles.R`).
