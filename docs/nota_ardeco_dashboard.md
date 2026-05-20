# ARDECO: contenuti della base dati e presentazione nella dashboard “Contesto territoriale”

## La base dati ARDECO

ARDECO (*Annual Regional Database of the European Commission*) è il database regionale annuale della Commissione Europea, gestito dal Joint Research Centre in coordinamento con la DG REGIO. Distribuisce serie storiche armonizzate di indicatori demografici e socioeconomici per tutte le regioni NUTS dell'Unione Europea, oltre ad alcune aree EFTA e dei paesi candidati. La copertura geografica si estende ai quattro livelli della nomenclatura territoriale (NUTS 0-3) e alle Regioni Metropolitane; le serie storiche partono dal 1980 per la maggior parte delle variabili e dal 1960 per la popolazione, con proiezioni a breve termine basate sui forecast AMECO della DG ECFIN.

Il contenuto tematico è organizzato in sei aree:

- **Popolazione e demografia**: popolazione totale, variazione naturale, migrazione netta
- **Mercato del lavoro**: occupazione *workplace-based* e *residence-based*, dipendenti, ore lavorate
- **Occupazione per settore**: dieci macro-settori NACE
- **Prodotto interno lordo e valore aggiunto**: PIL corrente, deflatori, parità di potere d'acquisto
- **Reddito e consumi**: reddito disponibile delle famiglie, consumi finali
- **Formazione del capitale**: investimenti fissi lordi

Per ciascuna variabile sono disponibili più unità di misura e, dove pertinente, disaggregazioni per sesso, classe d'età e settore economico. Gli aggiornamenti seguono il calendario JRC: marzo (allineamento ai conti regionali Eurostat), maggio e novembre (allineamento ai forecast AMECO). La fonte primaria è Eurostat, integrata da statistiche nazionali e regionali e da stime prodotte tramite interpolazione, proiezioni di quote regionali e variabili proxy.

## Utilità

ARDECO costituisce un riferimento unico per analisi comparative su scala provinciale ed europea perché combina tre caratteristiche difficilmente reperibili insieme: armonizzazione metodologica tra Stati membri, granularità sub-regionale fino al livello provinciale, profondità storica pluridecennale. Può essere usata per lo studio della convergenza regionale, il monitoraggio del mercato del lavoro provinciale, analisi della specializzazione settoriale, costruzione di scenari di crescita e benchmark territoriali. La distribuzione tramite  API pubbliche stabili rende la base dati direttamente integrabile in pipeline riproducibili.

## La dashboard

La presentazione in dashboard traduce la complessità multidimensionale di ARDECO in un'interfaccia interattiva orientata al territorio lombardo. I dati risiedono su uno schema PostgreSQL `ardeco` per consumatori esterni (Power BI, strumenti di reporting). Le etichette sono interamente in italiano.

L'interazione segue tre principi:

1. **Una sola serie temporale per variabile**, con selettori reattivi per le dimensioni rilevanti (unità di misura, sesso, classe d'età, settore NACE), così da evitare grafici sovraccarichi di linee
2. **Affiancamento di mappa e grafico** per sostenere il confronto sincrono tra dimensione spaziale (province) e dimensione temporale
3. **Value box con anno di riferimento** esplicito

La separazione fra livello dati PostgreSQL) e livello presentazione consente di aggiornare le serie con cadenza JRC senza interventi sulla dashboard, e di alimentare in parallelo strumenti di *business intelligence* a partire dal medesimo schema relazionale.
