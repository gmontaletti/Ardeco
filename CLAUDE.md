# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Research and documentation project for working with the **ARDECO** (Annual Regional Database of the European Commission) R package. ARDECO provides European regional economic data covering demographics, labor market, GDP, income, and capital formation at NUTS 0-3 levels, from 1960 onwards.

This is **not** an R package — it is an RStudio project containing exploration scripts and technical documentation for the ARDECO CRAN package.

## Key Files

- `ARDECO_nota_tecnica.md` — comprehensive Italian-language technical documentation covering ARDECO's thematic domains, API functions, filtering options, batch downloads, and targets pipeline integration
- `00_test.R` — demonstration script showing ARDECO package workflow (variable exploration, data download with filters)

## ARDECO Package API (from CRAN)

Four main functions:
- `ardeco_get_variable_list()` — list available variables
- `ardeco_get_tercet_list()` — territorial typologies
- `ardeco_get_dataset_list()` — dataset metadata
- `ardeco_get_dataset_data()` — download data with filters (nutscode, level, unit, version, year)

## Conventions

- R script sections use `# 1. section name -----` format (no `####`-only rows)
- Use neutral technical language in documentation
- Use btw MCP tools for R library documentation, not for web sites or standard APIs
- Prefer `data.table` for large datasets; `arrow`/Parquet for storage
- ARDECO data updates follow JRC release schedule: March, May, November
