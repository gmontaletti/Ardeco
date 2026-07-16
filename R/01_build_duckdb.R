# ==============================================================================
# 03_build_duckdb.R
# Scarica tutte le variabili ARDECO e le archivia in un database DuckDB.
# Output: data/ardeco.duckdb
# ==============================================================================

# 1. Librerie -----

library(ARDECO)
library(data.table)
library(duckdb)
library(DBI)
library(R.utils)

# 2. Configurazione -----

DB_PATH <- "data/ardeco.duckdb"
NUTSCODE <- "ITC4"
LEVEL <- "2,3"
VERSION <- 2024

# 3. Gruppi tematici -----

thematic_groups <- list(
  popolazione_demografia = c(
    "SNPTD",
    "SNPTN",
    "SNPTZ",
    "SNPBN",
    "SNPDN",
    "SNPDZ",
    "SNPNN",
    "SNMTN",
    "SNPCN",
    "SNPCNP",
    "SNMTNP",
    "SPPAN"
  ),
  mercato_lavoro = c(
    "SNETD",
    "SNETDP",
    "SNWTD",
    "RNECN",
    "RNUTN",
    "RNLCN",
    "RNLHT",
    "RNLHTP",
    "RNLHW",
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
    "SOVGDE",
    "SUVGDP",
    "SOVGDP",
    "SPVGD",
    "SPVGE"
  ),
  reddito_compensi = c(
    "RUWCD",
    "ROWCD",
    "ROWCDH",
    "RUWCDW",
    "ROWCDW",
    "RUWCDHH",
    "RUWCDWE",
    "RUWCZ",
    "ROWCZ"
  ),
  formazione_capitale = c(
    "RUIGT",
    "ROIGT",
    "RUIGZ",
    "ROIGZ",
    "ROKND",
    "SUKCT",
    "SOKCT",
    "SUKCZ",
    "SOKCZ"
  )
)

# Lookup inverso: da codice variabile a gruppo tematico
var_to_group <- character(0)
for (gn in names(thematic_groups)) {
  for (vc in thematic_groups[[gn]]) {
    var_to_group[vc] <- gn
  }
}

all_vars <- unique(unlist(thematic_groups, use.names = FALSE))

# 4. Tabelle etichette -----

var_labels <- data.table(
  var_code = c(
    "SNPTD",
    "SNPTN",
    "SNPTZ",
    "SNPBN",
    "SNPDN",
    "SNPDZ",
    "SNPNN",
    "SNMTN",
    "SNPCN",
    "SNPCNP",
    "SNMTNP",
    "SPPAN",
    "SNETD",
    "SNETDP",
    "SNWTD",
    "RNECN",
    "RNUTN",
    "RNLCN",
    "RNLHT",
    "RNLHTP",
    "RNLHW",
    "RPECNP",
    "RPUCNP",
    "SNETZ",
    "RNLHZ",
    "SUVGD",
    "SOVGD",
    "SUVGE",
    "SOVGE",
    "SUVGZ",
    "SOVGZ",
    "SUVGDH",
    "SUVGDE",
    "SOVGDH",
    "SOVGDE",
    "SUVGDP",
    "SOVGDP",
    "SPVGD",
    "SPVGE",
    "RUWCD",
    "ROWCD",
    "ROWCDH",
    "RUWCDW",
    "ROWCDW",
    "RUWCDHH",
    "RUWCDWE",
    "RUWCZ",
    "ROWCZ",
    "RUIGT",
    "ROIGT",
    "RUIGZ",
    "ROIGZ",
    "ROKND",
    "SUKCT",
    "SOKCT",
    "SUKCZ",
    "SOKCZ"
  ),
  label_it = c(
    "Popolazione media annua",
    "Popolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso",
    "Popolazione al 1\u00b0 gennaio per classi quinquennali e sesso",
    "Nati vivi per sesso",
    "Decessi per fascia d\u2019et\u00e0 e sesso",
    "Decessi per classi quinquennali e sesso",
    "Variazione naturale della popolazione",
    "Migrazione netta per fascia d\u2019et\u00e0 e sesso",
    "Variazione della popolazione per fascia d\u2019et\u00e0 e sesso",
    "Variazione della popolazione per 1000 abitanti",
    "Migrazione netta per 1000 abitanti",
    "Indice di dipendenza (rapporto alla popolazione 20-64)",
    "Occupazione workplace-based",
    "Occupazione pro capite",
    "Dipendenti workplace-based",
    "Occupati per et\u00e0 e sesso",
    "Disoccupati",
    "Forza lavoro (15 anni e oltre)",
    "Ore lavorate (occupati)",
    "Ore lavorate pro capite",
    "Ore lavorate (dipendenti)",
    "Tasso di occupazione (20-64 anni)",
    "Tasso di disoccupazione (15-74 anni)",
    "Occupazione per settore NACE",
    "Ore lavorate per settore NACE",
    "PIL a prezzi correnti",
    "PIL a prezzi costanti",
    "Valore aggiunto a prezzi correnti",
    "Valore aggiunto a prezzi costanti",
    "Valore aggiunto per settore a prezzi correnti",
    "Valore aggiunto per settore a prezzi costanti",
    "Produttivit\u00e0 nominale per ora lavorata",
    "Produttivit\u00e0 nominale per occupato",
    "Produttivit\u00e0 reale per ora lavorata",
    "Produttivit\u00e0 reale per occupato",
    "PIL pro capite a prezzi correnti",
    "PIL pro capite a prezzi costanti",
    "Tasso di crescita del PIL (indice concatenato)",
    "Tasso di crescita del VA (indice concatenato)",
    "Compensi dei dipendenti a prezzi correnti",
    "Compensi dei dipendenti a prezzi costanti",
    "Compenso reale per ora lavorata",
    "Compenso nominale per dipendente",
    "Compenso reale per dipendente",
    "Costo del lavoro per unit\u00e0 di prodotto nominale (ore)",
    "Costo del lavoro per unit\u00e0 di prodotto nominale (persone)",
    "Compensi per settore a prezzi correnti",
    "Compensi per settore a prezzi costanti",
    "Investimenti fissi lordi a prezzi correnti",
    "Investimenti fissi lordi a prezzi costanti",
    "Investimenti fissi lordi per settore a prezzi correnti",
    "Investimenti fissi lordi per settore a prezzi costanti",
    "Stock di capitale a prezzi costanti",
    "Ammortamenti a prezzi correnti",
    "Ammortamenti a prezzi costanti",
    "Ammortamenti per settore a prezzi correnti",
    "Ammortamenti per settore a prezzi costanti"
  ),
  group_id = c(
    rep("popolazione_demografia", 12),
    rep("mercato_lavoro", 11),
    rep("occupazione_settore", 2),
    rep("pil_valore_aggiunto", 14),
    rep("reddito_compensi", 9),
    rep("formazione_capitale", 9)
  ),
  description_it = c(
    # Popolazione e demografia (12)
    "Popolazione media annua, calcolata come media aritmetica della popolazione al 1\u00b0 gennaio dell\u2019anno t e dell\u2019anno t+1. Fonte: Eurostat, statistiche demografiche regionali.",
    "Popolazione residente al 1\u00b0 gennaio, disaggregata per grandi fasce d\u2019et\u00e0 e sesso. Fonte: Eurostat, statistiche demografiche regionali.",
    "Popolazione residente al 1\u00b0 gennaio per classi quinquennali d\u2019et\u00e0 e sesso. Fonte: Eurostat, statistiche demografiche regionali.",
    "Numero di nati vivi nell\u2019anno, per sesso. Fonte: Eurostat, statistiche sulle nascite.",
    "Decessi nell\u2019anno per grandi fasce d\u2019et\u00e0 e sesso. Fonte: Eurostat, statistiche sulla mortalit\u00e0.",
    "Decessi nell\u2019anno per classi quinquennali d\u2019et\u00e0 e sesso. Fonte: Eurostat, statistiche sulla mortalit\u00e0.",
    "Variazione naturale della popolazione (nati vivi meno decessi). Indicatore derivato.",
    "Migrazione netta per grandi fasce d\u2019et\u00e0 e sesso, calcolata come differenza tra variazione totale e variazione naturale della popolazione. Indicatore derivato.",
    "Variazione totale della popolazione per grandi fasce d\u2019et\u00e0 e sesso (variazione naturale pi\u00f9 migrazione netta). Indicatore derivato.",
    "Variazione della popolazione per 1000 abitanti. Indicatore derivato.",
    "Migrazione netta per 1000 abitanti, per grandi fasce d\u2019et\u00e0. Indicatore derivato.",
    "Indice di dipendenza: rapporto tra popolazione in et\u00e0 non lavorativa (0-19 e 65+) e popolazione in et\u00e0 lavorativa (20-64). Indicatore derivato.",
    # Mercato del lavoro (11)
    "Occupazione totale workplace-based (persone occupate nel territorio), secondo la definizione dei conti nazionali. Fonte: conti regionali Eurostat (ESA 2010).",
    "Occupazione pro capite, calcolata come rapporto tra occupati workplace-based e popolazione media annua. Indicatore derivato.",
    "Dipendenti workplace-based (lavoratori subordinati nel territorio). Fonte: conti regionali Eurostat (ESA 2010).",
    "Occupazione residence-based per fascia d\u2019et\u00e0 (20-64 anni) e sesso, basata sulla Rilevazione sulle Forze di Lavoro (EU-LFS). Fonte: Eurostat, EU-LFS.",
    "Disoccupati per fascia d\u2019et\u00e0 (15-74 anni), dato sperimentale. Fonte: Eurostat, EU-LFS.",
    "Forza lavoro (occupati pi\u00f9 disoccupati), popolazione di 15 anni e oltre. Fonte: Eurostat, EU-LFS.",
    "Ore lavorate totali (tutte le persone occupate). Fonte: conti regionali Eurostat (ESA 2010), con integrazioni JRC.",
    "Ore lavorate pro capite, calcolate come rapporto tra ore totali e popolazione media annua. Indicatore derivato.",
    "Ore lavorate dei soli dipendenti. Fonte: conti regionali Eurostat (ESA 2010), con integrazioni JRC.",
    "Tasso di occupazione: percentuale di occupati sulla popolazione in et\u00e0 20-64 anni. Fonte: Eurostat, EU-LFS.",
    "Tasso di disoccupazione: percentuale di disoccupati sulla forza lavoro in et\u00e0 15-74 anni. Dato sperimentale. Fonte: Eurostat, EU-LFS.",
    # Occupazione per settore (2)
    "Occupazione per settore di attivit\u00e0 economica (classificazione NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat (ESA 2010).",
    "Ore lavorate per settore di attivit\u00e0 economica (classificazione NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat (ESA 2010), con integrazioni JRC.",
    # PIL e valore aggiunto (14)
    "Prodotto interno lordo (PIL) a prezzi correnti di mercato. Fonte: conti regionali Eurostat (ESA 2010), integrati con stime JRC.",
    "PIL a prezzi costanti (anno base 2015), calcolato applicando i tassi di crescita regionali in volume. Fonte: Eurostat (nama_10r_2gdp), con deflatori JRC.",
    "Valore aggiunto lordo (VAL) ai prezzi base. Fonte: conti regionali Eurostat (ESA 2010).",
    "Valore aggiunto lordo a prezzi costanti (anno base 2015). Fonte: Eurostat, con deflatori JRC.",
    "Valore aggiunto per settore di attivit\u00e0 economica a prezzi correnti (NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat.",
    "Valore aggiunto per settore a prezzi costanti (NACE Rev. 2, 10 settori). Fonte: Eurostat, con deflatori JRC.",
    "Produttivit\u00e0 nominale del lavoro per ora lavorata (PIL a prezzi correnti / ore totali). Indicatore derivato.",
    "Produttivit\u00e0 nominale del lavoro per occupato (PIL a prezzi correnti / occupati). Indicatore derivato.",
    "Produttivit\u00e0 reale del lavoro per ora lavorata (PIL a prezzi costanti / ore totali). Indicatore derivato.",
    "Produttivit\u00e0 reale del lavoro per occupato (PIL a prezzi costanti / occupati). Indicatore derivato.",
    "PIL pro capite a prezzi correnti (PIL / popolazione media annua). Indicatore derivato.",
    "PIL pro capite a prezzi costanti (PIL reale / popolazione media annua). Indicatore derivato.",
    "Tasso di crescita del PIL, calcolato come indice concatenato in volume. Indicatore derivato.",
    "Tasso di crescita del valore aggiunto, calcolato come indice concatenato in volume. Indicatore derivato.",
    # Reddito e compensi (9)
    "Compensi dei dipendenti a prezzi correnti, inclusi salari e contributi sociali a carico del datore di lavoro. Fonte: conti regionali Eurostat (ESA 2010).",
    "Compensi dei dipendenti a prezzi costanti (anno base 2015). Fonte: Eurostat, con deflatori JRC.",
    "Compenso reale per ora lavorata (compensi a prezzi costanti / ore dipendenti). Indicatore derivato.",
    "Compenso nominale per dipendente (compensi totali / numero di dipendenti). Indicatore derivato.",
    "Compenso reale per dipendente (compensi a prezzi costanti / numero di dipendenti). Indicatore derivato.",
    "Costo del lavoro per unit\u00e0 di prodotto (CLUP) nominale basato sulle ore: rapporto tra compenso orario e produttivit\u00e0 oraria. Indicatore derivato.",
    "Costo del lavoro per unit\u00e0 di prodotto (CLUP) nominale basato sulle persone: rapporto tra compenso per dipendente e produttivit\u00e0 per occupato. Indicatore derivato.",
    "Compensi dei dipendenti per settore a prezzi correnti (NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat.",
    "Compensi dei dipendenti per settore a prezzi costanti (NACE Rev. 2, 10 settori). Fonte: Eurostat, con deflatori JRC.",
    # Formazione del capitale (9)
    "Investimenti fissi lordi (FBCF) a prezzi correnti. Fonte: conti regionali Eurostat (ESA 2010).",
    "Investimenti fissi lordi a prezzi costanti (anno base 2015). Fonte: Eurostat, con deflatori JRC.",
    "Investimenti fissi lordi per settore a prezzi correnti (NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat.",
    "Investimenti fissi lordi per settore a prezzi costanti (NACE Rev. 2, 10 settori). Fonte: Eurostat, con deflatori JRC.",
    "Stock di capitale netto a prezzi costanti (anno base 2015). Stima JRC basata sul metodo dell\u2019inventario permanente (PIM).",
    "Ammortamenti (consumo di capitale fisso) a prezzi correnti. Fonte: conti regionali Eurostat (ESA 2010).",
    "Ammortamenti a prezzi costanti (anno base 2015). Fonte: Eurostat, con deflatori JRC.",
    "Ammortamenti per settore a prezzi correnti (NACE Rev. 2, 10 settori). Fonte: conti regionali Eurostat.",
    "Ammortamenti per settore a prezzi costanti (NACE Rev. 2, 10 settori). Fonte: Eurostat, con deflatori JRC."
  ),
  help_it = c(
    # Popolazione e demografia (12)
    "Rappresenta la popolazione di riferimento per calcolare gli indicatori pro capite (PIL, occupazione, compensi) e va letta come base demografica dell\u2019anno, non come stock puntuale. \u00c8 espressa in numero di persone (unit\u00e0 NR): un aumento indica crescita demografica, una diminuzione spopolamento o saldo migratorio negativo. Va confrontata con \u00abPopolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso\u00bb e \u00abPopolazione al 1\u00b0 gennaio per classi quinquennali e sesso\u00bb, tenendo conto che quelle sono uno stock a una data precisa, non una media.",
    "Fotografia della popolazione residente a inizio anno, disaggregata per grandi fasce d\u2019et\u00e0 e sesso (valori in numero di persone, unit\u00e0 NR): utile per costruire piramidi demografiche o tassi di dipendenza per fascia. Va letta come stock, non come flusso: le variazioni tra un anno e l\u2019altro derivano dalla combinazione di natalit\u00e0, mortalit\u00e0 e migrazione (si vedano \u00abVariazione naturale della popolazione\u00bb e \u00abMigrazione netta per fascia d\u2019et\u00e0 e sesso\u00bb).",
    "Stessa logica di \u00abPopolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso\u00bb, ma con dettaglio per classi quinquennali (0-4, 5-9, \u2026), utile per analisi di invecchiamento della popolazione o per stimare con precisione la popolazione in et\u00e0 lavorativa. Valori in numero di persone (NR). La somma delle classi quinquennali deve coincidere con il totale TOTAL della stessa fascia in \u00abPopolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso\u00bb; scostamenti segnalano filtri applicati in fase di estrazione.",
    "Flusso annuale delle nascite, disaggregato per sesso (unit\u00e0 NR). Va letto insieme a \u00abDecessi per fascia d\u2019et\u00e0 e sesso\u00bb per ricavare il saldo naturale (\u00abVariazione naturale della popolazione\u00bb = nati vivi meno decessi); da solo indica solo la natalit\u00e0 e non il tasso di crescita della popolazione. Un valore in calo prolungato \u00e8 tipico segnale di invecchiamento strutturale, non necessariamente di crisi demografica improvvisa.",
    "Flusso annuale dei decessi per grandi fasce d\u2019et\u00e0 e sesso (unit\u00e0 NR). Va interpretato tenendo conto della struttura per et\u00e0 della popolazione di riferimento (\u00abPopolazione al 1\u00b0 gennaio per fascia d\u2019et\u00e0 e sesso\u00bb): un aumento dei decessi assoluti pu\u00f2 riflettere semplicemente l\u2019invecchiamento della popolazione pi\u00f9 che un peggioramento della mortalit\u00e0. Utile in combinazione con \u00abNati vivi per sesso\u00bb per il saldo naturale.",
    "Come \u00abDecessi per fascia d\u2019et\u00e0 e sesso\u00bb ma con dettaglio quinquennale, utile per calcolare tassi di mortalit\u00e0 specifici per et\u00e0 se rapportato a \u00abPopolazione al 1\u00b0 gennaio per classi quinquennali e sesso\u00bb. Valori in numero di persone (NR). Le classi pi\u00f9 anziane concentrano la maggior parte dei decessi in condizioni demografiche normali: valori elevati nelle classi giovani segnalano eventi eccezionali pi\u00f9 che rumore statistico.",
    "Indicatore derivato (nati vivi meno decessi, \u00abNati vivi per sesso\u00bb meno \u00abDecessi per fascia d\u2019et\u00e0 e sesso\u00bb), non scaricato direttamente da Eurostat. Un valore positivo indica saldo naturale positivo (pi\u00f9 nascite che decessi), negativo un saldo naturale negativo, condizione ormai diffusa in gran parte delle regioni italiane. Va letto insieme a \u00abMigrazione netta per fascia d\u2019et\u00e0 e sesso\u00bb: la variazione totale della popolazione (\u00abVariazione della popolazione per fascia d\u2019et\u00e0 e sesso\u00bb) \u00e8 la somma dei due componenti.",
    "Indicatore derivato calcolato come differenza tra variazione totale della popolazione e variazione naturale, per fascia d\u2019et\u00e0 e sesso. Un valore positivo indica saldo migratorio netto in ingresso, negativo un saldo in uscita. Essendo un residuo di calcolo, ne eredita eventuali discontinuit\u00e0 statistiche presenti nei dati di popolazione di partenza (es. revisioni censuarie): variazioni brusche da un anno all\u2019altro vanno verificate prima di essere interpretate come fenomeni migratori reali.",
    "Indicatore derivato: variazione totale della popolazione (naturale pi\u00f9 migratoria) per fascia d\u2019et\u00e0 e sesso, disponibile sia in numero di persone (NR) sia come tasso di crescita (unit\u00e0 GROWRT, per mille). Un valore positivo segnala crescita della fascia, negativo contrazione; usare la versione GROWRT per confronti tra territori di dimensione demografica molto diversa, la versione NR per quantificare l\u2019impatto assoluto.",
    "Variante normalizzata di \u00abVariazione della popolazione per fascia d\u2019et\u00e0 e sesso\u00bb, espressa per 1000 abitanti: permette il confronto diretto tra territori di dimensione diversa senza normalizzazioni manuali. Valori vicini allo zero indicano popolazione stabile; valori negativi persistenti nel tempo segnalano un territorio in spopolamento strutturale.",
    "Come \u00abMigrazione netta per fascia d\u2019et\u00e0 e sesso\u00bb ma normalizzata per 1000 abitanti, quindi direttamente confrontabile tra province o regioni di dimensione diversa. Valori positivi indicano attrattivit\u00e0 migratoria netta del territorio, negativi un saldo migratorio sfavorevole; va letta insieme al saldo naturale per capire se la dinamica demografica complessiva (\u00abVariazione della popolazione per 1000 abitanti\u00bb) \u00e8 trainata da nascite/decessi o da movimenti migratori.",
    "Rapporto tra popolazione non in et\u00e0 lavorativa (0-19 e 65+) e popolazione in et\u00e0 lavorativa (20-64), espresso in percentuale (unit\u00e0 PC). Valori pi\u00f9 alti indicano un maggior carico teorico sulla popolazione attiva; valori superiori al 50-60% sono tipici di territori con forte invecchiamento. \u00c8 un indicatore strutturale, da leggere in serie storica pi\u00f9 che nel singolo anno.",
    # Mercato del lavoro (11)
    "Numero di occupati nel luogo di lavoro (non di residenza), secondo la definizione dei conti nazionali, in migliaia di persone (unit\u00e0 THS). \u00c8 l\u2019occupazione \u201cprodotta\u201d dal territorio, utile per misurare l\u2019attrattivit\u00e0 economica di un\u2019area (poli industriali, citt\u00e0 con forte pendolarismo in entrata); si differenzia concettualmente da una misura residence-based, che conterebbe gli occupati residenti indipendentemente da dove lavorano (si veda \u00abOccupati per et\u00e0 e sesso\u00bb).",
    "Indicatore derivato: rapporto tra \u00abOccupazione workplace-based\u00bb (in migliaia di persone) e \u00abPopolazione media annua\u00bb, espresso come numero puro (unit\u00e0 NR, tipicamente tra 0 e 1). Valori pi\u00f9 alti indicano un territorio con forte capacit\u00e0 di attrarre occupazione rispetto alla propria popolazione residente (poli industriali o direzionali); valori bassi un\u2019area prevalentemente residenziale.",
    "Sottoinsieme dell\u2019\u00abOccupazione workplace-based\u00bb relativo ai soli lavoratori subordinati nel territorio, in migliaia di persone (unit\u00e0 THS). La differenza rispetto all\u2019occupazione complessiva approssima il lavoro autonomo/indipendente localizzato nell\u2019area; un\u2019incidenza dei dipendenti elevata sul totale degli occupati segnala un tessuto produttivo orientato al lavoro dipendente pi\u00f9 che al lavoro autonomo.",
    "Occupazione residence-based (occupati indipendentemente da dove lavorano) per fascia d\u2019et\u00e0 20-64 e sesso, in migliaia di persone (unit\u00e0 THS), fonte EU-LFS. Diversamente dall\u2019\u00abOccupazione workplace-based\u00bb, qui l\u2019occupato \u00e8 conteggiato nel territorio di residenza: utile per misurare la partecipazione al lavoro della popolazione residente, non l\u2019attrattivit\u00e0 occupazionale del territorio.",
    "Numero di persone in cerca di occupazione in et\u00e0 15-74 anni, in migliaia (unit\u00e0 THS), dato definito \u201csperimentale\u201d da Eurostat alla scala regionale: va usato con cautela nei confronti puntuali anno su anno, meglio leggerlo in tendenza pluriennale o insieme al \u00abTasso di disoccupazione (15-74 anni)\u00bb che ne attenua l\u2019effetto delle revisioni campionarie.",
    "Somma di occupati e disoccupati (offerta di lavoro) per la popolazione di 15 anni e oltre, in migliaia di persone (unit\u00e0 THS). \u00c8 il denominatore concettuale del \u00abTasso di disoccupazione (15-74 anni)\u00bb, calcolato come quota di \u00abDisoccupati\u00bb sulla forza lavoro: una crescita della forza lavoro senza corrispondente crescita occupazionale fa aumentare il tasso di disoccupazione anche a parit\u00e0 di occupati.",
    "Totale delle ore lavorate da tutte le persone occupate nell\u2019anno, in migliaia di ore (unit\u00e0 THS_HW). Da preferire all\u2019\u00abOccupazione workplace-based\u00bb quando si vuole tenere conto anche della variazione di orario medio (part-time, cassa integrazione, straordinari), non solo del numero di teste occupate; il rapporto tra ore lavorate e occupati approssima le ore medie annue per occupato.",
    "Indicatore derivato: \u00abOre lavorate (occupati)\u00bb rapportate alla \u00abPopolazione media annua\u00bb, espresso come numero puro (unit\u00e0 NR). Sintetizza in un solo valore sia il tasso di occupazione sia l\u2019intensit\u00e0 oraria del lavoro nel territorio; utile per confronti di \u201cvolume di lavoro per abitante\u201d tra aree con strutture occupazionali diverse (es. quota di part-time).",
    "Come le \u00abOre lavorate (occupati)\u00bb ma limitato alle sole ore dei lavoratori dipendenti (unit\u00e0 THS_HW). La sua incidenza sul totale delle ore lavorate indica il peso del lavoro dipendente nel territorio; \u00e8 coerente con i \u00abDipendenti workplace-based\u00bb pi\u00f9 che con gli \u00abOccupati per et\u00e0 e sesso\u00bb (misura residence-based).",
    "Percentuale di occupati sulla popolazione in et\u00e0 20-64 anni (unit\u00e0 PC), l\u2019indicatore standard usato nei target europei (es. Strategia Europa 2020/2030). Valori pi\u00f9 alti indicano maggiore partecipazione al mercato del lavoro della popolazione in et\u00e0 attiva; va confrontato con il dato nazionale/europeo di riferimento pi\u00f9 che letto in valore assoluto, e risente di composizione demografica e strutture familiari locali.",
    "Percentuale di disoccupati sulla forza lavoro in et\u00e0 15-74 anni (unit\u00e0 PC), dato sperimentale a livello regionale: le oscillazioni di pochi decimi di punto tra un anno e l\u2019altro possono rientrare nell\u2019errore campionario, quindi va interpretato in tendenza pluriennale. Un valore basso non implica necessariamente alta occupazione: pu\u00f2 riflettere anche bassa partecipazione alla forza lavoro (inattivit\u00e0, scoraggiamento).",
    # Occupazione per settore (2)
    "Occupati workplace-based disaggregati per settore di attivit\u00e0 economica (NACE Rev. 2, 10 settori aggregati), in migliaia di persone (unit\u00e0 THS). La somma dei settori per un dato territorio/anno deve coincidere con il totale dell\u2019\u00abOccupazione workplace-based\u00bb; il peso relativo dei settori (es. quota di industria vs servizi) \u00e8 l\u2019indicatore chiave per leggere la specializzazione produttiva del territorio.",
    "Ore lavorate totali disaggregate per settore NACE (10 settori aggregati), in migliaia di ore (unit\u00e0 THS_HW), con integrazioni JRC rispetto al dato Eurostat grezzo. Va letto come le \u00abOre lavorate (occupati)\u00bb scomposte per settore: utile per capire quali settori assorbono pi\u00f9 ore di lavoro, non necessariamente pi\u00f9 occupati (settori con orari medi pi\u00f9 lunghi pesano di pi\u00f9 qui che nell\u2019\u00abOccupazione per settore NACE\u00bb).",
    # PIL e valore aggiunto (14)
    "PIL a prezzi di mercato dell\u2019anno corrente, in milioni di euro (MIO_EUR) o, per le versioni pi\u00f9 recenti del dataset, anche in milioni di PPS EU27 2020 (MIO_PPS_EU27_2020) per confronti di potere d\u2019acquisto tra paesi. Include l\u2019effetto dell\u2019inflazione: le variazioni anno su anno non separano crescita reale e aumento dei prezzi. Per la crescita reale si veda \u00abPIL a prezzi costanti\u00bb.",
    "PIL depurato dall\u2019inflazione (anno base 2015 o 2020 a seconda della versione, unit\u00e0 MIO_EUR2015/MIO_EUR2020), calcolato applicando i tassi di crescita regionali in volume al livello base. Le variazioni tra anni riflettono la crescita economica reale del territorio: \u00e8 la serie da usare per confronti di crescita nel tempo o tra territori, mentre il \u00abPIL a prezzi correnti\u00bb resta preferibile per rapporti in valore corrente non deflazionato.",
    "Valore aggiunto lordo ai prezzi base (PIL al netto delle imposte nette sui prodotti), a prezzi correnti, in milioni di euro. \u00c8 concettualmente pi\u00f9 vicino alla produzione del sistema economico locale rispetto al PIL, che include anche la componente fiscale; il rapporto tra valore aggiunto e \u00abPIL a prezzi correnti\u00bb \u00e8 tipicamente stabile nel tempo per uno stesso territorio, salvo variazioni della fiscalit\u00e0 indiretta.",
    "Come il \u00abValore aggiunto a prezzi correnti\u00bb ma a prezzi costanti (anno base 2015/2020): misura la crescita reale del valore aggiunto, al netto dell\u2019inflazione. Da usare per il calcolo della produttivit\u00e0 reale (si vedano \u00abProduttivit\u00e0 reale per ora lavorata\u00bb e \u00abProduttivit\u00e0 reale per occupato\u00bb) e per confronti di crescita economica settoriale nel tempo.",
    "Valore aggiunto disaggregato per settore NACE (10 settori aggregati), a prezzi correnti, in milioni di euro. La somma dei settori approssima il \u00abValore aggiunto a prezzi correnti\u00bb complessivo (con eventuali scarti da arrotondamenti o rettifiche non allocate); il peso percentuale dei settori \u00e8 l\u2019indicatore chiave per leggere la struttura produttiva del territorio in termini di valore, non solo di occupati (si confronti con \u00abOccupazione per settore NACE\u00bb).",
    "Come il \u00abValore aggiunto per settore a prezzi correnti\u00bb ma a prezzi costanti: permette di confrontare la crescita reale dei singoli settori nel tempo, isolando l\u2019effetto prezzi, che pu\u00f2 differire molto da settore a settore (es. energia vs servizi).",
    "Indicatore derivato: \u00abPIL a prezzi correnti\u00bb diviso \u00abOre lavorate (occupati)\u00bb, in euro per ora. Misura quanto valore economico corrente viene prodotto in un\u2019ora di lavoro nel territorio; include sia l\u2019effetto di efficienza produttiva reale sia l\u2019effetto dei prezzi/inflazione, quindi non va confuso con la \u00abProduttivit\u00e0 reale per ora lavorata\u00bb.",
    "Come la \u00abProduttivit\u00e0 nominale per ora lavorata\u00bb ma calcolata come \u00abPIL a prezzi correnti\u00bb diviso \u00abOccupazione workplace-based\u00bb anzich\u00e9 diviso ore lavorate, espressa in euro per occupato. Risente anche della quota di part-time e dell\u2019intensit\u00e0 oraria media: due territori con la stessa produttivit\u00e0 oraria possono avere produttivit\u00e0 per occupato diverse se cambia il monte ore medio lavorato a testa.",
    "Come la \u00abProduttivit\u00e0 nominale per ora lavorata\u00bb ma calcolata a prezzi costanti (PIL a prezzi costanti diviso ore lavorate): \u00e8 la misura corretta per confrontare l\u2019efficienza produttiva nel tempo, perch\u00e9 esclude l\u2019effetto dell\u2019inflazione. \u00c8 l\u2019indicatore di riferimento per analisi di produttivit\u00e0 e convergenza economica tra territori.",
    "Come la \u00abProduttivit\u00e0 nominale per occupato\u00bb ma a prezzi costanti (PIL a prezzi costanti diviso occupati): misura la produttivit\u00e0 reale per occupato, comparabile nel tempo. Da leggere insieme alla \u00abProduttivit\u00e0 reale per ora lavorata\u00bb per capire se la dinamica \u00e8 trainata da maggiore efficienza oraria o da un diverso numero di ore lavorate per occupato.",
    "\u00abPIL a prezzi correnti\u00bb diviso \u00abPopolazione media annua\u00bb, in euro per abitante o PPS per abitante a seconda della versione. \u00c8 l\u2019indicatore pi\u00f9 comune per confronti di benessere economico tra territori, ma a prezzi correnti risente sia della crescita reale sia dell\u2019inflazione: per confronti temporali di lungo periodo \u00e8 preferibile il \u00abPIL pro capite a prezzi costanti\u00bb.",
    "Come il \u00abPIL pro capite a prezzi correnti\u00bb ma a prezzi costanti: misura il livello di reddito pro capite reale, al netto dell\u2019inflazione, ed \u00e8 l\u2019indicatore corretto per analisi di convergenza/divergenza economica territoriale nel tempo.",
    "Indice concatenato del PIL in volume (base 2015 = I15 o base 2020 = I20 a seconda della versione) oppure variazione percentuale sull\u2019anno precedente (unit\u00e0 PCH_PRE). Nella forma indice il valore va letto rispetto all\u2019anno base (=100): sopra 100 indica un\u2019economia pi\u00f9 grande in termini reali rispetto all\u2019anno base, sotto 100 una contrazione cumulata. Nella forma PCH_PRE il valore \u00e8 gi\u00e0 il tasso di crescita annuo in percentuale.",
    "Come il \u00abTasso di crescita del PIL (indice concatenato)\u00bb ma riferito al valore aggiunto anzich\u00e9 al PIL: stesse due letture possibili (indice concatenato I15/I20, oppure variazione percentuale annua PCH_PRE). Utile per isolare la dinamica della sola produzione economica dal PIL complessivo, che include anche le imposte nette sui prodotti.",
    # Reddito e compensi (9)
    "Massa salariale totale a prezzi correnti (retribuzioni lorde pi\u00f9 contributi sociali a carico del datore di lavoro), in milioni di euro o milioni di PPS EU27 a seconda della versione. \u00c8 il costo del lavoro complessivo sostenuto nel territorio, non il salario percepito dal singolo lavoratore: per quello si vedano \u00abCompenso nominale per dipendente\u00bb e \u00abCompenso reale per dipendente\u00bb.",
    "Come i \u00abCompensi dei dipendenti a prezzi correnti\u00bb ma a prezzi costanti (anno base 2015/2020): misura la crescita reale della massa salariale, al netto dell\u2019inflazione, utile per confronti di lungo periodo del costo del lavoro complessivo.",
    "Indicatore derivato: \u00abCompensi dei dipendenti a prezzi costanti\u00bb diviso \u00abOre lavorate (dipendenti)\u00bb, in euro reali per ora. Misura la retribuzione oraria media reale nel territorio; da confrontare con la \u00abProduttivit\u00e0 reale per ora lavorata\u00bb per valutare se le retribuzioni seguono la produttivit\u00e0 o se ne discostano.",
    "Indicatore derivato: \u00abCompensi dei dipendenti a prezzi correnti\u00bb diviso \u00abDipendenti workplace-based\u00bb, in euro o PPS per dipendente per anno. \u00c8 la retribuzione media annua lorda per dipendente in valore corrente; non va confusa con lo stipendio mensile netto percepito dal lavoratore, che \u00e8 un concetto diverso e non direttamente ricavabile da questi dati.",
    "Come il \u00abCompenso nominale per dipendente\u00bb ma a prezzi costanti: misura la retribuzione media annua reale per dipendente, al netto dell\u2019inflazione, indicatore corretto per confronti del potere d\u2019acquisto salariale nel tempo.",
    "CLUP (costo del lavoro per unit\u00e0 di prodotto) calcolato come rapporto tra compenso orario nominale e produttivit\u00e0 oraria nominale, in euro. Un CLUP in aumento indica che il costo del lavoro per ora cresce pi\u00f9 della produttivit\u00e0, con possibile perdita di competitivit\u00e0 di costo; un CLUP stabile o in calo indica che i guadagni di produttivit\u00e0 assorbono la dinamica salariale.",
    "Come il \u00abCosto del lavoro per unit\u00e0 di prodotto nominale (ore)\u00bb ma basato sul rapporto tra compenso per dipendente e produttivit\u00e0 per occupato, anzich\u00e9 sulle ore. Le due versioni del CLUP possono divergere se cambia l\u2019intensit\u00e0 oraria media: un aumento delle ore pro capite a parit\u00e0 di produttivit\u00e0 oraria migliora il CLUP per persona senza che cambi quello orario.",
    "Compensi dei dipendenti disaggregati per settore NACE (10 settori aggregati), a prezzi correnti, in milioni di euro. La somma dei settori approssima i \u00abCompensi dei dipendenti a prezzi correnti\u00bb complessivi; il confronto tra il peso di un settore nei compensi e il suo peso nell\u2019occupazione (\u00abOccupazione per settore NACE\u00bb) o nel valore aggiunto (\u00abValore aggiunto per settore a prezzi correnti\u00bb) indica se quel settore \u00e8 relativamente pi\u00f9 o meno labour-intensive/ad alta retribuzione.",
    "Come i \u00abCompensi per settore a prezzi correnti\u00bb ma a prezzi costanti: permette di confrontare nel tempo la dinamica reale della massa salariale settoriale, isolando l\u2019effetto prezzi.",
    # Formazione del capitale (9)
    "Formazione lorda di capitale fisso (FBCF) a prezzi correnti: acquisti di macchinari, impianti, costruzioni e altri beni capitali durevoli nell\u2019anno, in milioni di euro o PPS EU27. Misura il flusso di nuovi investimenti, non lo stock di capitale accumulato (per quello si veda \u00abStock di capitale a prezzi costanti\u00bb); valori elevati in rapporto al PIL segnalano un territorio in fase di espansione della capacit\u00e0 produttiva.",
    "Come gli \u00abInvestimenti fissi lordi a prezzi correnti\u00bb ma a prezzi costanti: misura il volume reale di investimenti, al netto delle variazioni dei prezzi dei beni capitali (spesso diverse dall\u2019inflazione generale), utile per confronti di sforzo di investimento nel tempo.",
    "Investimenti fissi lordi disaggregati per settore NACE (10 settori aggregati), a prezzi correnti. La distribuzione settoriale degli investimenti anticipa spesso l\u2019evoluzione futura della struttura produttiva: i settori che investono di pi\u00f9 oggi tendono a pesare di pi\u00f9 in valore aggiunto e occupazione negli anni successivi.",
    "Come gli \u00abInvestimenti fissi lordi per settore a prezzi correnti\u00bb ma a prezzi costanti: consente di confrontare nel tempo il volume reale di investimenti per settore, isolando l\u2019effetto dei prezzi dei beni capitali.",
    "Stock di capitale netto accumulato nel territorio, a prezzi costanti (anno base 2015/2020), stimato dal JRC con il metodo dell\u2019inventario permanente (stock storico rivalutato, sommato agli investimenti annui e depurato dagli ammortamenti). A differenza degli \u00abInvestimenti fissi lordi\u00bb (a prezzi correnti o costanti), che sono flussi annuali, questa \u00e8 una variabile di stock: conta pi\u00f9 la sua dinamica nel tempo e il rapporto tra capitale e PIL (intensit\u00e0 di capitale) del livello assoluto in s\u00e9.",
    "Consumo di capitale fisso (ammortamenti) a prezzi correnti, in milioni di euro: rappresenta la perdita di valore del capitale esistente per usura e obsolescenza nell\u2019anno. Il confronto tra gli \u00abInvestimenti fissi lordi a prezzi correnti\u00bb e questi ammortamenti indica se lo stock di capitale del territorio si sta espandendo (investimenti superiori agli ammortamenti) o si sta riducendo.",
    "Come gli \u00abAmmortamenti a prezzi correnti\u00bb ma a prezzi costanti: misura il consumo reale di capitale fisso, coerente con lo \u00abStock di capitale a prezzi costanti\u00bb e gli \u00abInvestimenti fissi lordi a prezzi costanti\u00bb per ricostruire la dinamica reale dello stock di capitale nel tempo.",
    "Ammortamenti disaggregati per settore NACE (10 settori aggregati), a prezzi correnti. Settori capital-intensive (es. industria, energia) mostrano tipicamente ammortamenti elevati in rapporto al valore aggiunto prodotto rispetto a settori labour-intensive (es. servizi alla persona).",
    "Come gli \u00abAmmortamenti per settore a prezzi correnti\u00bb ma a prezzi costanti: consente il confronto nel tempo della dinamica reale degli ammortamenti settoriali, isolando l\u2019effetto dei prezzi dei beni capitali."
  )
)

unit_labels <- data.table(
  code = c(
    "NR",
    "GROWRT",
    "THS",
    "MIO_EUR",
    "MIO_PPS_EU27_2020",
    "MIO_EUR2015",
    "MIO_EUR2020",
    "EUR_HAB",
    "EUR_HAB2015",
    "PPS_HAB",
    "PC",
    "THS_HW",
    "EUR",
    "PPS_EU27_2020",
    "EUR2015",
    "EUR2020",
    "I15",
    "I20",
    "PCH_PRE"
  ),
  label_it = c(
    "Numero",
    "Tasso di crescita (\u2030)",
    "Migliaia",
    "Milioni di euro",
    "Milioni di PPS (EU27 2020)",
    "Milioni di euro (prezzi 2015)",
    "Milioni di euro (prezzi 2020)",
    "Euro per abitante",
    "Euro per abitante (prezzi 2015)",
    "PPS per abitante",
    "Percentuale",
    "Migliaia di ore lavorate",
    "Euro",
    "PPS (EU27 2020)",
    "Euro (prezzi 2015)",
    "Euro (prezzi 2020)",
    "Indice concatenato (base 2015)",
    "Indice concatenato (base 2020)",
    "Variazione percentuale sull'anno precedente"
  )
)

sex_labels <- data.table(
  code = c("TOTAL", "F", "M"),
  label_it = c("Totale", "Femmine", "Maschi")
)

age_labels <- data.table(
  code = c(
    "TOTAL",
    "Y_LT5",
    "Y5-9",
    "Y10-14",
    "Y15-19",
    "Y15-39",
    "Y15-64",
    "Y20-24",
    "Y20-29",
    "Y20-64",
    "Y25-29",
    "Y30-34",
    "Y35-39",
    "Y40-44",
    "Y40-64",
    "Y45-49",
    "Y50-54",
    "Y55-59",
    "Y60-64",
    "Y65-69",
    "Y70-74",
    "Y75-79",
    "Y80-84",
    "Y85-89",
    "Y_GE15",
    "Y_GE65",
    "Y_GE85",
    "Y_GE90",
    "Y_LT15",
    "Y_LT20",
    "Y_LT15-GE65",
    "Y_LT20-GE65"
  ),
  label_it = c(
    "Totale",
    "Meno di 5 anni",
    "5-9 anni",
    "10-14 anni",
    "15-19 anni",
    "15-39 anni",
    "15-64 anni",
    "20-24 anni",
    "20-29 anni",
    "20-64 anni",
    "25-29 anni",
    "30-34 anni",
    "35-39 anni",
    "40-44 anni",
    "40-64 anni",
    "45-49 anni",
    "50-54 anni",
    "55-59 anni",
    "60-64 anni",
    "65-69 anni",
    "70-74 anni",
    "75-79 anni",
    "80-84 anni",
    "85-89 anni",
    "15 anni e oltre",
    "65 anni e oltre",
    "85 anni e oltre",
    "90 anni e oltre",
    "Meno di 15 anni",
    "Meno di 20 anni",
    "Meno di 15 e 65 anni e oltre",
    "Meno di 20 e 65 anni e oltre"
  )
)

sector_labels <- data.table(
  code = c(
    "A",
    "B-E",
    "F",
    "G-I",
    "G-J",
    "J",
    "K",
    "K-N",
    "L",
    "M_N",
    "O-Q",
    "O-U",
    "R-U",
    "TOTAL"
  ),
  label_it = c(
    "Agricoltura, silvicoltura e pesca",
    "Industria (escluse costruzioni)",
    "Costruzioni",
    "Commercio, trasporti, alloggio e ristorazione",
    "Commercio, trasporti, informazione e comunicazione",
    "Informazione e comunicazione",
    "Attivit\u00e0 finanziarie e assicurative",
    "Attivit\u00e0 finanziarie, immobiliari, professionali",
    "Attivit\u00e0 immobiliari",
    "Attivit\u00e0 professionali, scientifiche e tecniche",
    "PA, istruzione, sanit\u00e0",
    "PA, istruzione, sanit\u00e0 e altri servizi",
    "Altre attivit\u00e0 di servizi",
    "Totale (tutti i settori)"
  )
)

group_labels <- data.table(
  group_id = c(
    "popolazione_demografia",
    "mercato_lavoro",
    "occupazione_settore",
    "pil_valore_aggiunto",
    "reddito_compensi",
    "formazione_capitale"
  ),
  label_it = c(
    "Popolazione e demografia",
    "Mercato del lavoro",
    "Occupazione per settore",
    "PIL e valore aggiunto",
    "Reddito e compensi",
    "Formazione del capitale"
  )
)

# 5. Funzione download -----

#' Download a single ARDECO variable with normalized schema.
#'
#' Wraps ardeco_get_dataset_data() with error handling and column normalization.
#' Returns a data.table with a consistent 12-column schema on success, or NULL
#' on failure.
#'
#' @param var_code Character. ARDECO variable code.
#' @param nutscode Character. NUTS code filter (default "ITC4" for Lombardia).
#' @param level Character. NUTS levels to retrieve (default "2,3").
#' @param version Numeric. NUTS version year (default 2024).
#' @return A data.table with 12 columns or NULL on failure.
download_variable <- function(
  var_code,
  nutscode = "ITC4",
  level = "2,3",
  version = 2024,
  timeout_sec = 300
) {
  tryCatch(
    {
      dl <- R.utils::withTimeout(
        ardeco_get_dataset_data(
          var_code,
          nutscode = nutscode,
          level = level,
          version = version
        ),
        timeout = timeout_sec
      )
      if (is.null(dl) || nrow(dl) == 0L) {
        message("  [WARN] No data returned for ", var_code)
        return(NULL)
      }
      dt <- as.data.table(dl)

      # Normalizzazione colonne opzionali
      for (col in c("SEX", "AGE", "SECTOR", "ISCED11")) {
        if (!col %in% names(dt)) {
          set(dt, j = col, value = NA_character_)
        }
      }

      # Gruppo tematico
      set(dt, j = "THEMATIC_GROUP", value = var_to_group[var_code])

      # Conversione tipi
      if (!is.double(dt[["VALUE"]])) {
        set(dt, j = "VALUE", value = as.double(dt[["VALUE"]]))
      }
      if (!is.integer(dt[["YEAR"]])) {
        set(dt, j = "YEAR", value = as.integer(dt[["YEAR"]]))
      }
      if (!is.integer(dt[["LEVEL"]])) {
        set(dt, j = "LEVEL", value = as.integer(dt[["LEVEL"]]))
      }
      if (!is.integer(dt[["VERSIONS"]])) {
        set(dt, j = "VERSIONS", value = as.integer(dt[["VERSIONS"]]))
      }

      # Schema a 12 colonne in ordine fisso
      dt[, list(
        VARIABLE,
        VERSIONS,
        LEVEL,
        NUTSCODE,
        YEAR,
        UNIT,
        VALUE,
        SEX,
        AGE,
        SECTOR,
        ISCED11,
        THEMATIC_GROUP
      )]
    },
    TimeoutException = function(e) {
      message("  [TIMEOUT] ", var_code, " exceeded ", timeout_sec, "s")
      NULL
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

# 6. Inizializzazione DuckDB -----

if (file.exists(DB_PATH)) {
  file.remove(DB_PATH)
  message("Rimosso database esistente: ", DB_PATH)
}

con <- dbConnect(duckdb(), dbdir = DB_PATH)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

dbExecute(
  con,
  "
  CREATE TABLE ardeco_data (
    VARIABLE       VARCHAR NOT NULL,
    VERSIONS       INTEGER,
    LEVEL          INTEGER,
    NUTSCODE       VARCHAR NOT NULL,
    YEAR           INTEGER NOT NULL,
    UNIT           VARCHAR,
    VALUE          DOUBLE,
    SEX            VARCHAR,
    AGE            VARCHAR,
    SECTOR         VARCHAR,
    ISCED11        VARCHAR,
    THEMATIC_GROUP VARCHAR NOT NULL
  )
"
)

variable_list <- as.data.table(ardeco_get_variable_list())
dbWriteTable(con, "variable_list", variable_list, overwrite = TRUE)
message("Tabella variable_list: ", nrow(variable_list), " righe")

# 7. Loop principale -----

message("\nDownloading ", length(all_vars), " variables\n")

# Pre-allocate summary log
summary_log <- data.table(
  var_code = character(length(all_vars)),
  group = character(length(all_vars)),
  n_rows = integer(length(all_vars)),
  status = character(length(all_vars)),
  elapsed_sec = numeric(length(all_vars))
)

t0_total <- proc.time()

for (i in seq_along(all_vars)) {
  vc <- all_vars[i]
  gn <- var_to_group[vc]
  message(sprintf("[%2d/%d] %s (%s)", i, length(all_vars), vc, gn))

  t0 <- proc.time()
  dt <- download_variable(vc)
  elapsed <- (proc.time() - t0)[["elapsed"]]

  if (!is.null(dt)) {
    dbWriteTable(con, "ardeco_data", dt, append = TRUE)
    message(sprintf("  Inserted %d rows (%.1fs)", nrow(dt), elapsed))

    set(summary_log, i, "var_code", vc)
    set(summary_log, i, "group", gn)
    set(summary_log, i, "n_rows", nrow(dt))
    set(summary_log, i, "status", "OK")
    set(summary_log, i, "elapsed_sec", elapsed)
  } else {
    set(summary_log, i, "var_code", vc)
    set(summary_log, i, "group", gn)
    set(summary_log, i, "n_rows", 0L)
    set(summary_log, i, "status", "FAILED")
    set(summary_log, i, "elapsed_sec", elapsed)
  }
}

# Duplicazione totale settoriale (SECTOR='TOTAL') -----
# 10 variabili scaricano solo la ripartizione NACE (SECTOR = 13 codici,
# senza aggregato "tutti i settori" nella propria serie). Il totale
# esiste gia', pubblicato sotto un nome diverso (la variabile "sibling"
# non scomposta per settore). Verificato live (ITC4, versione 2024) in
# R/run_pipeline.R: sommare i 10 settori del partizionamento standard
# ESA/Eurostat (A, B-E, F, G-I, J, K, L, M_N, O-Q, R-U) NON riproduce
# sempre il sibling: coincide esattamente per le variabili nominali, ma
# diverge (fino a diversi punti percentuali) per SUKCZ (residuo non
# allocato) e per le variabili a prezzi costanti/volume concatenato
# (non additivita' dei volumi concatenati, fenomeno noto Eurostat/OCSE,
# non un errore). Percio' il totale NON viene calcolato per somma: viene
# COPIATO cosi' com'e' dalla riga del sibling.
#
# THEMATIC_GROUP: NON viene copiato dal sibling (per SNETZ/RNLHZ il
# sibling appartiene a "mercato_lavoro", mentre SNETZ/RNLHZ appartengono
# a "occupazione_settore") - si usa invece var_to_group[[zv]].

sector_total_pairs <- data.table(
  z_var = c(
    "SNETZ",
    "RNLHZ",
    "SUVGZ",
    "SOVGZ",
    "RUWCZ",
    "ROWCZ",
    "RUIGZ",
    "ROIGZ",
    "SUKCZ",
    "SOKCZ"
  ),
  total_var = c(
    "SNETD",
    "RNLHT",
    "SUVGE",
    "SOVGE",
    "RUWCD",
    "ROWCD",
    "RUIGT",
    "ROIGT",
    "SUKCT",
    "SOKCT"
  )
)

for (i in seq_len(nrow(sector_total_pairs))) {
  zv <- sector_total_pairs$z_var[i]
  tv <- sector_total_pairs$total_var[i]
  tg <- var_to_group[[zv]]

  n_sibling <- dbGetQuery(
    con,
    sprintf("SELECT COUNT(*) AS n FROM ardeco_data WHERE VARIABLE = '%s'", tv)
  )$n

  dbExecute(
    con,
    sprintf(
      "
      INSERT INTO ardeco_data
        (VARIABLE, VERSIONS, LEVEL, NUTSCODE, YEAR, UNIT, VALUE, SEX, AGE, SECTOR, ISCED11, THEMATIC_GROUP)
      SELECT '%s', VERSIONS, LEVEL, NUTSCODE, YEAR, UNIT, VALUE, SEX, AGE, 'TOTAL', ISCED11, '%s'
      FROM ardeco_data
      WHERE VARIABLE = '%s'
      ",
      zv,
      tg,
      tv
    )
  )

  n_copied <- dbGetQuery(
    con,
    sprintf(
      "SELECT COUNT(*) AS n FROM ardeco_data WHERE VARIABLE = '%s' AND SECTOR = 'TOTAL'",
      zv
    )
  )$n

  if (n_copied != n_sibling) {
    message(sprintf(
      "ATTENZIONE %s<-%s: righe copiate (%d) diverse dalle righe sorgente (%d)",
      zv,
      tv,
      n_copied,
      n_sibling
    ))
  } else {
    message(sprintf(
      "%s: aggiunte %d righe SECTOR='TOTAL' copiate da %s (gruppo %s)",
      zv,
      n_copied,
      tv,
      tg
    ))
  }
}

# Rimozione combinazioni invarianti tra province
n_del <- dbExecute(
  con,
  "DELETE FROM ardeco_data WHERE VARIABLE = 'ROWCDH' AND UNIT = 'EUR2020'"
)
message(sprintf("Rimossi %d record invarianti (ROWCDH EUR2020)", n_del))

# Creazione indici
dbExecute(con, "CREATE INDEX idx_variable ON ardeco_data (VARIABLE)")
dbExecute(con, "CREATE INDEX idx_nuts_year ON ardeco_data (NUTSCODE, YEAR)")

# 8. Scrittura tabelle etichette -----

dbWriteTable(con, "var_labels", var_labels, overwrite = TRUE)
dbWriteTable(con, "unit_labels", unit_labels, overwrite = TRUE)
dbWriteTable(con, "sex_labels", sex_labels, overwrite = TRUE)
dbWriteTable(con, "age_labels", age_labels, overwrite = TRUE)
dbWriteTable(con, "sector_labels", sector_labels, overwrite = TRUE)
dbWriteTable(con, "group_labels", group_labels, overwrite = TRUE)
dbWriteTable(con, "download_log", summary_log, overwrite = TRUE)
message("Tabelle etichette e log scritte nel database")

# 9. Riepilogo -----

message("\n========== Download summary ==========")
for (i in seq_len(nrow(summary_log))) {
  row <- summary_log[i]
  msg <- sprintf(
    "  %-6s | %-25s | %7d rows | %6.1fs | %s",
    row$var_code,
    row$group,
    row$n_rows,
    row$elapsed_sec,
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

# Verifica DuckDB
row_count <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM ardeco_data")$n
var_count <- dbGetQuery(
  con,
  "SELECT COUNT(DISTINCT VARIABLE) AS n FROM ardeco_data"
)$n
tbl_list <- dbGetQuery(con, "SHOW TABLES")

message(sprintf("\nDuckDB: %s", DB_PATH))
message(sprintf("  Tabelle: %s", paste(tbl_list[[1]], collapse = ", ")))
message(sprintf("  ardeco_data: %d righe, %d variabili", row_count, var_count))
message(sprintf("  Dimensione file: %.1f MB", file.size(DB_PATH) / 1e6))

total_elapsed <- (proc.time() - t0_total)[["elapsed"]]
message(sprintf(
  "  Tempo totale: %.0f secondi (%.1f minuti)",
  total_elapsed,
  total_elapsed / 60
))
