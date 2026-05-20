# Variabili della dashboard ARDECO Lombardia

Elenco delle variabili pubblicate nella dashboard (indetto da giugno 2026), raggruppate per pagina tematica. Per ogni variabile sono indicati il codice ARDECO, l’etichetta in italiano, i selettori dimensionali disponibili nella sidebar e una descrizione sintetica.

## Legenda dei selettori

- **Unità**: selettore *Unità di misura* (sempre presente). Tipici valori: numero, percentuale, milioni di euro a prezzi correnti o costanti, indice, tasso di crescita.
- **Sesso**: selettore *Sesso* (TOTAL / M / F).
- **Età**: selettore *Classe di età* (grandi fasce o classi quinquennali).
- **Settore**: selettore *Settore* (NACE Rev. 2, 10 settori).
- **ISCED11**: selettore *Livello di istruzione* (non utilizzato dalle variabili attualmente esposte).

Quando una colonna riporta `–` il selettore non viene mostrato dalla dashboard perché la variabile non ha quella dimensione.

---

## 1. Popolazione e demografia

| Codice | Etichetta | Unità | Sesso | Età | Settore | Descrizione |
|---|---|:---:|:---:|:---:|:---:|---|
| SNPTD | Popolazione media annua | ✓ | – | – | – | Popolazione media annua, calcolata come media aritmetica della popolazione al 1° gennaio degli anni t e t+1. Fonte: Eurostat, statistiche demografiche regionali. |
| SNPTN | Popolazione al 1° gennaio per fascia d’età e sesso | ✓ | ✓ | ✓ | – | Popolazione residente al 1° gennaio, disaggregata per grandi fasce d’età e sesso. Fonte: Eurostat. |
| SNPTZ | Popolazione al 1° gennaio per classi quinquennali e sesso | ✓ | ✓ | ✓ | – | Popolazione residente al 1° gennaio per classi quinquennali d’età e sesso. Fonte: Eurostat. |
| SNPBN | Nati vivi per sesso | ✓ | ✓ | – | – | Numero di nati vivi nell’anno, per sesso. Fonte: Eurostat, statistiche sulle nascite. |
| SNPDN | Decessi per fascia d’età e sesso | ✓ | ✓ | ✓ | – | Decessi nell’anno per grandi fasce d’età e sesso. Fonte: Eurostat, statistiche sulla mortalità. |
| SNPDZ | Decessi per classi quinquennali e sesso | ✓ | ✓ | ✓ | – | Decessi nell’anno per classi quinquennali d’età e sesso. Fonte: Eurostat. |
| SNPNN | Variazione naturale della popolazione | ✓ | ✓ | ✓ | – | Variazione naturale della popolazione (nati vivi meno decessi). Indicatore derivato. |
| SNMTN | Migrazione netta per fascia d’età e sesso | ✓ | ✓ | ✓ | – | Migrazione netta per grandi fasce d’età e sesso, calcolata come differenza tra variazione totale e variazione naturale della popolazione. Indicatore derivato. |
| SNPCN | Variazione della popolazione per fascia d’età e sesso | ✓ | ✓ | ✓ | – | Variazione totale della popolazione per fasce d’età e sesso (variazione naturale più migrazione netta). Indicatore derivato. |
| SNPCNP | Variazione della popolazione per 1000 abitanti | ✓ | ✓ | ✓ | – | Variazione della popolazione per 1000 abitanti. Indicatore derivato. |
| SNMTNP | Migrazione netta per 1000 abitanti | ✓ | ✓ | ✓ | – | Migrazione netta per 1000 abitanti, per grandi fasce d’età. Indicatore derivato. |
| SPPAN | Indice di dipendenza | ✓ | – | ✓ | – | Indice di dipendenza: rapporto tra popolazione in età non lavorativa (0-19 e 65+) e popolazione in età lavorativa (20-64). Indicatore derivato. |

## 2. Mercato del lavoro

| Codice | Etichetta | Unità | Sesso | Età | Settore | Descrizione |
|---|---|:---:|:---:|:---:|:---:|---|
| RPECNP | Tasso di occupazione (20-64 anni) | ✓ | ✓ | – | – | Percentuale di occupati sulla popolazione in età 20-64 anni. Fonte: Eurostat, EU-LFS. |
| RPUCNP | Tasso di disoccupazione (15-74 anni) | ✓ | – | – | – | Percentuale di disoccupati sulla forza lavoro in età 15-74 anni. Dato sperimentale. Fonte: Eurostat, EU-LFS. |
| SNETD | Occupazione workplace-based | ✓ | – | – | – | Occupazione totale workplace-based (persone occupate nel territorio), conti nazionali. Fonte: Eurostat (ESA 2010). |
| SNETDP | Occupazione pro capite | ✓ | – | – | – | Occupati workplace-based rapportati alla popolazione media annua. Indicatore derivato. |
| SNWTD | Dipendenti workplace-based | ✓ | – | – | – | Dipendenti workplace-based (lavoratori subordinati nel territorio). Fonte: Eurostat (ESA 2010). |
| RNECN | Occupati per età e sesso | ✓ | ✓ | ✓ | – | Occupazione residence-based per fascia d’età (20-64) e sesso. Fonte: Eurostat, EU-LFS. |
| RNUTN | Disoccupati | ✓ | – | – | – | Disoccupati per fascia d’età (15-74 anni), dato sperimentale. Fonte: Eurostat, EU-LFS. |
| RNLCN | Forza lavoro (15 anni e oltre) | ✓ | – | – | – | Occupati più disoccupati, popolazione di 15 anni e oltre. Fonte: Eurostat, EU-LFS. |
| RNLHT | Ore lavorate (occupati) | ✓ | – | – | – | Ore lavorate totali (tutte le persone occupate). Fonte: Eurostat (ESA 2010) con integrazioni JRC. |
| RNLHTP | Ore lavorate pro capite | ✓ | – | – | – | Rapporto tra ore totali e popolazione media annua. Indicatore derivato. |
| RNLHW | Ore lavorate (dipendenti) | ✓ | – | – | – | Ore lavorate dei soli dipendenti. Fonte: Eurostat (ESA 2010) con integrazioni JRC. |

## 3. Occupazione per settore

| Codice | Etichetta | Unità | Sesso | Età | Settore | Descrizione |
|---|---|:---:|:---:|:---:|:---:|---|
| SNETZ | Occupazione per settore NACE | ✓ | – | – | ✓ | Occupazione per settore di attività economica (NACE Rev. 2, 10 settori). Fonte: Eurostat (ESA 2010). |
| RNLHZ | Ore lavorate per settore NACE | ✓ | – | – | ✓ | Ore lavorate per settore di attività economica (NACE Rev. 2, 10 settori). Fonte: Eurostat (ESA 2010) con integrazioni JRC. |

## 4. PIL e valore aggiunto

| Codice | Etichetta | Unità | Sesso | Età | Settore | Descrizione |
|---|---|:---:|:---:|:---:|:---:|---|
| SUVGD | PIL a prezzi correnti | ✓ | – | – | – | Prodotto interno lordo a prezzi correnti di mercato. Fonte: Eurostat (ESA 2010), integrato con stime JRC. |
| SOVGD | PIL a prezzi costanti | ✓ | – | – | – | PIL a prezzi costanti (anno base 2015), ottenuto applicando i tassi di crescita regionali in volume. Fonte: Eurostat con deflatori JRC. |
| SUVGE | Valore aggiunto a prezzi correnti | ✓ | – | – | – | Valore aggiunto lordo ai prezzi base. Fonte: Eurostat (ESA 2010). |
| SOVGE | Valore aggiunto a prezzi costanti | ✓ | – | – | – | Valore aggiunto lordo a prezzi costanti (anno base 2015). Fonte: Eurostat con deflatori JRC. |
| SUVGZ | Valore aggiunto per settore a prezzi correnti | ✓ | – | – | ✓ | Valore aggiunto per settore (NACE Rev. 2, 10 settori) a prezzi correnti. Fonte: Eurostat. |
| SOVGZ | Valore aggiunto per settore a prezzi costanti | ✓ | – | – | ✓ | Valore aggiunto per settore (NACE Rev. 2, 10 settori) a prezzi costanti. Fonte: Eurostat con deflatori JRC. |
| SUVGDH | Produttività nominale per ora lavorata | ✓ | – | – | – | PIL a prezzi correnti rapportato alle ore totali. Indicatore derivato. |
| SUVGDE | Produttività nominale per occupato | ✓ | – | – | – | PIL a prezzi correnti rapportato agli occupati. Indicatore derivato. |
| SOVGDH | Produttività reale per ora lavorata | ✓ | – | – | – | PIL a prezzi costanti rapportato alle ore totali. Indicatore derivato. |
| SOVGDE | Produttività reale per occupato | ✓ | – | – | – | PIL a prezzi costanti rapportato agli occupati. Indicatore derivato. |
| SUVGDP | PIL pro capite a prezzi correnti | ✓ | – | – | – | PIL a prezzi correnti rapportato alla popolazione media annua. Indicatore derivato. |
| SOVGDP | PIL pro capite a prezzi costanti | ✓ | – | – | – | PIL a prezzi costanti rapportato alla popolazione media annua. Indicatore derivato. |
| SPVGD | Tasso di crescita del PIL | ✓ | – | – | – | Tasso di crescita del PIL, calcolato come indice concatenato in volume. Indicatore derivato. |
| SPVGE | Tasso di crescita del VA | ✓ | – | – | – | Tasso di crescita del valore aggiunto, calcolato come indice concatenato in volume. Indicatore derivato. |

## 5. Reddito e compensi

| Codice | Etichetta | Unità | Sesso | Età | Settore | Descrizione |
|---|---|:---:|:---:|:---:|:---:|---|
| RUWCD | Compensi dei dipendenti a prezzi correnti | ✓ | – | – | – | Compensi dei dipendenti a prezzi correnti, inclusi salari e contributi sociali a carico del datore di lavoro. Fonte: Eurostat (ESA 2010). |
| ROWCD | Compensi dei dipendenti a prezzi costanti | ✓ | – | – | – | Compensi dei dipendenti a prezzi costanti (anno base 2015). Fonte: Eurostat con deflatori JRC. |
| ROWCDH | Compenso reale per ora lavorata | ✓ | – | – | – | Compensi a prezzi costanti rapportati alle ore dei dipendenti. Indicatore derivato. |
| RUWCDW | Compenso nominale per dipendente | ✓ | – | – | – | Compensi totali rapportati al numero di dipendenti. Indicatore derivato. |
| ROWCDW | Compenso reale per dipendente | ✓ | – | – | – | Compensi a prezzi costanti rapportati al numero di dipendenti. Indicatore derivato. |
| RUWCDHH | Costo del lavoro per unità di prodotto nominale (ore) | ✓ | – | – | – | CLUP nominale basato sulle ore: rapporto tra compenso orario e produttività oraria. Indicatore derivato. |
| RUWCDWE | Costo del lavoro per unità di prodotto nominale (persone) | ✓ | – | – | – | CLUP nominale basato sulle persone: rapporto tra compenso per dipendente e produttività per occupato. Indicatore derivato. |
| RUWCZ | Compensi per settore a prezzi correnti | ✓ | – | – | ✓ | Compensi dei dipendenti per settore (NACE Rev. 2, 10 settori) a prezzi correnti. Fonte: Eurostat. |
| ROWCZ | Compensi per settore a prezzi costanti | ✓ | – | – | ✓ | Compensi dei dipendenti per settore (NACE Rev. 2, 10 settori) a prezzi costanti. Fonte: Eurostat con deflatori JRC. |

## 6. Formazione del capitale

| Codice | Etichetta | Unità | Sesso | Età | Settore | Descrizione |
|---|---|:---:|:---:|:---:|:---:|---|
| RUIGT | Investimenti fissi lordi a prezzi correnti | ✓ | – | – | – | Investimenti fissi lordi (FBCF) a prezzi correnti. Fonte: Eurostat (ESA 2010). |
| ROIGT | Investimenti fissi lordi a prezzi costanti | ✓ | – | – | – | Investimenti fissi lordi a prezzi costanti (anno base 2015). Fonte: Eurostat con deflatori JRC. |
| RUIGZ | Investimenti fissi lordi per settore a prezzi correnti | ✓ | – | – | ✓ | Investimenti fissi lordi per settore (NACE Rev. 2, 10 settori) a prezzi correnti. Fonte: Eurostat. |
| ROIGZ | Investimenti fissi lordi per settore a prezzi costanti | ✓ | – | – | ✓ | Investimenti fissi lordi per settore (NACE Rev. 2, 10 settori) a prezzi costanti. Fonte: Eurostat con deflatori JRC. |
| ROKND | Stock di capitale a prezzi costanti | ✓ | – | – | – | Stock di capitale netto a prezzi costanti (anno base 2015). Stima JRC basata sul metodo dell’inventario permanente (PIM). |
| SUKCT | Ammortamenti a prezzi correnti | ✓ | – | – | – | Ammortamenti (consumo di capitale fisso) a prezzi correnti. Fonte: Eurostat (ESA 2010). |
| SOKCT | Ammortamenti a prezzi costanti | ✓ | – | – | – | Ammortamenti a prezzi costanti (anno base 2015). Fonte: Eurostat con deflatori JRC. |
| SUKCZ | Ammortamenti per settore a prezzi correnti | ✓ | – | – | ✓ | Ammortamenti per settore (NACE Rev. 2, 10 settori) a prezzi correnti. Fonte: Eurostat. |
| SOKCZ | Ammortamenti per settore a prezzi costanti | ✓ | – | – | ✓ | Ammortamenti per settore (NACE Rev. 2, 10 settori) a prezzi costanti. Fonte: Eurostat con deflatori JRC. |

---

## Note

- Fonte primaria: Annual Regional Database of the European Commission (ARDECO), JRC, con dati Eurostat (`nama_10r_*`, EU-LFS, statistiche demografiche regionali).
