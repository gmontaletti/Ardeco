# Task Plan: ARDECO Dashboard Refactoring

> **ARCHIVIATO — 2026-06-05.** Documento di pianificazione della Session 1
> (2026-04-01), conservato come riferimento storico. Il lavoro è completato;
> l'architettura finale differisce dal piano iniziale (vedi nota sotto).

## Status: Completato (architettura rivista)

## Objective (piano originale)
Refactor the ARDECO project to:
1. Store one table per ARDECO dataset (variable) instead of grouped thematic parquet files
2. Add proper Italian labels for all variables in the dashboard
3. Redesign dashboard timelines to show one value per time period, with filter controls for multi-dimensional datasets

## Phases — esito

- [x] Phase 1: Refactor data download — sostituita da ETL DuckDB (`R/01_build_duckdb.R`)
- [x] Phase 2: Create Italian label lookup table — label completate (vedi `dashboard_variabili.md`)
- [x] Phase 3: Refactor `dashboard/R/helpers.R`
- [x] Phase 4: Redesign dashboard — `dashboard/index.Rmd` (flexdashboard+Shiny), layout map-left/chart-right
- [x] Phase 5: Verify dashboard renders correctly

## Scostamenti dal piano originale
- **Storage**: invece di "un parquet per variabile" il pipeline è stato unificato
  su **DuckDB** (`data/ardeco.duckdb`) come stage intermedio, con export verso
  **PostgreSQL** (schema `ardeco`, canale per consumatori esterni come Power BI)
  ed **Excel** (`output/ardeco_export.xlsx`).
- Aggiunto pipeline **containerizzato** (`output/ardeco-pipeline-container/`) e
  guida sviluppatore **Power BI** (`docs/dashboard_powerbi_guida.qmd`).
- Rimosse variabili solo-NUTS2 e gruppo "istruzione"; rimossa SNPTY.

## Decisions
- DuckDB come motore ETL intermedio; PostgreSQL come backend di pubblicazione.
- Separazione calcolo/presentazione: la dashboard legge dati precomputati.
