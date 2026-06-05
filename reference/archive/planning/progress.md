# Progress Log

> **ARCHIVIATO — 2026-06-05.** Log di avanzamento della fase di pianificazione.
> Conservato come riferimento storico. Lo stato corrente del progetto è
> ricostruibile dalla git history.

## 2026-04-01 — Session 1: Planning

- [x] Explored full codebase structure
- [x] Analyzed all 6 parquet files for dimensions and filtering needs
- [x] Mapped 27 ARDECO variables to Italian labels
- [x] Identified dashboard issues: raw codes as labels, hidden dimensions, no user controls
- [x] Design implementation plan
- [x] Get user approval

## 2026-04 — Implementazione (sintesi dalla git history)

- [x] ETL DuckDB (`R/01_build_duckdb.R`) — sostituisce il workflow parquet tematico
- [x] Copertura variabili estesa (istruzione, redditi, capitale, dimensione ISCED)
- [x] Rimozione variabili solo-NUTS2 e gruppo istruzione; rimossa SNPTY
- [x] Unificazione pipeline su DuckDB + export PostgreSQL (schema `ardeco`)
- [x] Export Excel (`output/ardeco_export.xlsx`) e geometrie NUTS3 Lombardia
- [x] Dashboard ridisegnata (flexdashboard+Shiny), layout map-left/chart-right
- [x] Pipeline containerizzato (`output/ardeco-pipeline-container/`)
- [x] Guida sviluppatore Power BI + riferimento variabili dashboard

## Stato finale
Pipeline e dashboard operativi. Workflow parquet originale archiviato in
`reference/archive/parquet_workflow/`. Questi doc di pianificazione archiviati
in `reference/archive/planning/`.
