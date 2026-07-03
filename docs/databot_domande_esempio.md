# Domande di esempio per un databot ARDECO (Lombardia)

Raccolta di domande tipiche che un utente potrebbe rivolgere a un databot
appoggiato alla base dati ARDECO scaricata nel ramo `main` del progetto. L'ambito
è la regione **Lombardia (`ITC4`, livello NUTS2)** e le sue **12 province
(livello NUTS3)**:

Varese (`ITC41`), Como (`ITC42`), Lecco (`ITC43`), Sondrio (`ITC44`),
Bergamo (`ITC46`), Brescia (`ITC47`), Pavia (`ITC48`), Lodi (`ITC49`),
Cremona (`ITC4A`), Mantova (`ITC4B`), Milano (`ITC4C`),
Monza e della Brianza (`ITC4D`).

Le serie coprono la demografia dal 1960 e le grandezze economiche dal 1980
(disaggregazioni settoriali NACE dal 1995). La fonte è ARDECO (Annual Regional
Database della Commissione europea, JRC). L'elenco completo delle 57 variabili e
dei relativi indicatori derivati è in [`dashboard_variabili.md`](dashboard_variabili.md).

Ogni domanda riporta due annotazioni:

- **Tipo** — categoria della domanda (comparativa, convergenza, trend,
  settoriale, effetto, causa, combinata).
- **Dati** — codici ARDECO e livello territoriale necessari per costruire la
  risposta.

> Nota sui codici: il prefisso indica il dominio (es. `SN*` demografia/lavoro,
> `S*VG*` PIL e valore aggiunto, `R*WC*` redditi e compensi, `R*IG*`/`*OK*`
> capitale). Le varianti `U`/`O` distinguono prezzi correnti da prezzi costanti
> (base 2015).

---

## 1. Domande comparative

Confronto tra una provincia e la regione, oppure tra province nello stesso anno.

**D1.** Quale provincia lombarda ha il PIL pro capite più alto e quale più basso
rispetto alla media regionale nell'ultimo anno disponibile?
*Tipo:* comparativa · *Dati:* `SUVGDP` (NUTS3 vs `ITC4`).

**D2.** In quali province il tasso di occupazione 20-64 anni supera quello medio
della Lombardia?
*Tipo:* comparativa · *Dati:* `RPECNP` (NUTS3 vs `ITC4`).

**D3.** Quanto pesa la provincia di Milano sul totale regionale del valore
aggiunto e dell'occupazione?
*Tipo:* comparativa · *Dati:* `SUVGE`, `SNETD` (quota `ITC4C` su `ITC4`).

**D4.** Qual è la differenza nel compenso medio per dipendente tra Milano e
Sondrio?
*Tipo:* comparativa · *Dati:* `RUWCDW` (confronto `ITC4C` vs `ITC44`).

**D5.** Quali province hanno un tasso di disoccupazione superiore alla media
lombarda nell'ultimo anno?
*Tipo:* comparativa · *Dati:* `RPUCNP` (NUTS3 vs `ITC4`).

**D6.** Come si ordinano le province per produttività reale per occupato rispetto
al valore regionale?
*Tipo:* comparativa · *Dati:* `SOVGDE` (graduatoria NUTS3 vs `ITC4`).

---

## 2. Domande sulla convergenza territoriale nel tempo

Avvicinamento o allontanamento delle province dalla media regionale lungo gli anni.

**D7.** Negli ultimi vent'anni le province lombarde hanno teso a convergere o a
divergere in termini di PIL pro capite?
*Tipo:* convergenza · *Dati:* `SUVGDP` (dispersione tra NUTS3 nel tempo).

**D8.** Il divario di produttività per occupato tra la provincia più produttiva e
quella meno produttiva si è ampliato o ridotto dal 1995 a oggi?
*Tipo:* convergenza · *Dati:* `SOVGDE` (range/varianza tra NUTS3 per anno).

**D9.** Quali province hanno recuperato terreno rispetto alla media regionale nel
tasso di occupazione e quali lo hanno perso?
*Tipo:* convergenza · *Dati:* `RPECNP` (scarto NUTS3 − `ITC4` nel tempo).

**D10.** Il compenso per dipendente delle province periferiche si sta avvicinando
a quello di Milano oppure il distacco aumenta?
*Tipo:* convergenza · *Dati:* `RUWCDW` (rapporto NUTS3 / `ITC4C` nel tempo).

**D11.** Misurando la dispersione del PIL pro capite tra province, in quali anni
la disuguaglianza territoriale è stata massima e minima?
*Tipo:* convergenza · *Dati:* `SUVGDP` (coefficiente di variazione tra NUTS3 per anno).

---

## 3. Domande sull'andamento nel tempo (trend)

Traiettorie di lungo periodo di una grandezza per la regione o una provincia.

**D12.** Come è evoluto il PIL a prezzi costanti della Lombardia dal 1980 a oggi?
*Tipo:* trend · *Dati:* `SOVGD` (`ITC4`, serie storica).

**D13.** Qual è stato l'andamento del tasso di disoccupazione regionale durante e
dopo la crisi del 2008-2013?
*Tipo:* trend · *Dati:* `RPUCNP` (`ITC4`, serie storica).

**D14.** Come è cambiata la popolazione media annua di Milano e di Bergamo negli
ultimi trent'anni?
*Tipo:* trend · *Dati:* `SNPTD` (`ITC4C`, `ITC46`, serie storica).

**D15.** Gli investimenti fissi lordi a prezzi costanti della Lombardia sono
tornati ai livelli pre-pandemia?
*Tipo:* trend · *Dati:* `ROIGT` (`ITC4`, serie storica).

**D16.** Qual è stata la traiettoria della migrazione netta regionale negli ultimi
quindici anni?
*Tipo:* trend · *Dati:* `SNMTN` o `SNMTNP` (`ITC4`, serie storica).

---

## 4. Domande settoriali

Composizione e dinamica per settore NACE.

**D17.** Qual è la composizione settoriale dell'occupazione in Lombardia e come è
cambiata dal 1995?
*Tipo:* settoriale · *Dati:* `SNETZ` (`ITC4`, dimensione settore NACE).

**D18.** Quali settori generano la quota maggiore di valore aggiunto regionale e
quali sono in calo?
*Tipo:* settoriale · *Dati:* `SUVGZ` / `SOVGZ` (`ITC4`, per settore).

**D19.** Quanto è cresciuta o diminuita l'occupazione nel manifatturiero rispetto
ai servizi nelle province a vocazione industriale come Brescia e Bergamo?
*Tipo:* settoriale · *Dati:* `SNETZ` (`ITC47`, `ITC46`, per settore).

**D20.** In quali settori si concentrano gli investimenti fissi lordi della
regione?
*Tipo:* settoriale · *Dati:* `RUIGZ` / `ROIGZ` (`ITC4`, per settore).

**D21.** Come si distribuiscono i compensi dei dipendenti tra i settori NACE e
quale settore offre la retribuzione complessiva più alta?
*Tipo:* settoriale · *Dati:* `RUWCZ` / `ROWCZ` (`ITC4`, per settore).

---

## 5. Domande sugli effetti di una dinamica

Conseguenze di un fenomeno (es. invecchiamento) su altre grandezze.

**D22.** Cosa comporta la dinamica di invecchiamento della popolazione lombarda
per l'indice di dipendenza e per la quota di popolazione in età lavorativa?
*Tipo:* effetto · *Dati:* `SPPAN`, `SNPTZ` (`ITC4`, struttura per età).

**D23.** Come incide l'aumento della popolazione anziana sulla dimensione della
forza lavoro e sull'occupazione potenziale?
*Tipo:* effetto · *Dati:* `SNPTZ`, `RNLCN`, `RNECN` (`ITC4`, classi di età).

**D24.** Quale effetto ha la migrazione netta sulla variazione complessiva della
popolazione provinciale, distinta dalla componente naturale?
*Tipo:* effetto · *Dati:* `SNMTN`, `SNPNN`, `SNPCN` (NUTS3, scomposizione).

**D25.** Se le ore lavorate pro capite calano mentre l'occupazione cresce, quale
effetto si osserva sul monte ore complessivo della regione?
*Tipo:* effetto · *Dati:* `RNLHTP`, `SNETD`, `RNLHT` (`ITC4`).

---

## 6. Domande sulle cause di una dinamica

Scomposizione contabile di un fenomeno per individuarne i fattori.

**D26.** Da cosa è causata la caduta della produttività reale per occupato in una
provincia: dalla riduzione del valore aggiunto o dall'aumento degli occupati?
*Tipo:* causa · *Dati:* `SOVGDE`, `SOVGE`, `SNETD` (NUTS3, scomposizione).

**D27.** La stagnazione della produttività oraria dipende più dall'andamento del
valore aggiunto o dalle ore lavorate?
*Tipo:* causa · *Dati:* `SOVGDH`, `SOVGE`, `RNLHT` (`ITC4`, scomposizione).

**D28.** L'aumento del costo del lavoro per unità di prodotto è dovuto a compensi
in crescita o a una produttività che ristagna?
*Tipo:* causa · *Dati:* `RUWCDWE`, `RUWCDW`, `SUVGDE` (`ITC4`).

**D29.** Il calo della popolazione di una provincia è determinato dal saldo
naturale negativo o da una migrazione netta in uscita?
*Tipo:* causa · *Dati:* `SNPNN`, `SNMTN`, `SNPCN` (NUTS3, scomposizione).

---

## 7. Domande combinate

Domande che incrociano più tipi (comparativa + trend + settoriale + causa/effetto).

**D30.** Quale provincia ha spostato più occupati dal manifatturiero ai servizi
negli ultimi vent'anni e con quale effetto sulla produttività per occupato?
*Tipo:* combinata (settoriale + trend + effetto) · *Dati:* `SNETZ`, `SOVGDE` (NUTS3).

**D31.** Confrontando Milano e Brescia, quale ha avuto la crescita del PIL pro
capite più sostenuta dal 1995 e quanto di questa crescita è attribuibile alla
produttività piuttosto che all'aumento dell'occupazione?
*Tipo:* combinata (comparativa + trend + causa) · *Dati:* `SUVGDP`, `SOVGDE`,
`SNETD` (`ITC4C`, `ITC47`).

**D32.** Le province con la maggiore intensità di investimento (FBCF per occupato)
hanno anche registrato la crescita della produttività più alta nel decennio
successivo?
*Tipo:* combinata (comparativa + causa) · *Dati:* `ROIGT`, `SNETD`, `SOVGDE`
(NUTS3, serie storica).

**D33.** Nelle province dove l'indice di dipendenza è cresciuto di più, il tasso
di occupazione è calato e i compensi reali per dipendente hanno ristagnato?
*Tipo:* combinata (effetto + comparativa + trend) · *Dati:* `SPPAN`, `RPECNP`,
`ROWCDW` (NUTS3, serie storica).

**D34.** Come si è modificato il divario di compenso reale per ora lavorata tra le
province nel tempo, e questo divario segue la specializzazione settoriale del
valore aggiunto?
*Tipo:* combinata (convergenza + settoriale) · *Dati:* `ROWCDH`, `SOVGZ` (NUTS3).

