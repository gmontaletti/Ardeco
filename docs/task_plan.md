# Task Plan: ARDECO Dashboard Refactoring

## Status: Planning

## Objective
Refactor the ARDECO project to:
1. Store one table per ARDECO dataset (variable) instead of grouped thematic parquet files
2. Add proper Italian labels for all variables in the dashboard
3. Redesign dashboard timelines to show one value per time period, with filter controls for multi-dimensional datasets

## Phases

- [ ] Phase 1: Refactor data download (`R/01_download_data.R`)
- [ ] Phase 2: Create Italian label lookup table
- [ ] Phase 3: Refactor `dashboard/R/helpers.R`
- [ ] Phase 4: Redesign `dashboard/index.qmd`
- [ ] Phase 5: Verify dashboard renders correctly

## Decisions
- TBD
