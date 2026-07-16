# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Research and documentation project for working with the **ARDECO** (Annual Regional Database of the European Commission) R package. ARDECO provides European regional economic data covering demographics, labor market, GDP, income, and capital formation at NUTS 0-3 levels, from 1960 onwards.

This is **not** an R package — it is an RStudio project containing exploration scripts and technical documentation for the ARDECO CRAN package.

## Conventions

- R script sections use `# 1. section name -----` format (no `####`-only rows)
- Use neutral technical language in documentation
- Use btw MCP tools for R library documentation, not for web sites or standard APIs
- Prefer `data.table` for large datasets; `arrow`/Parquet for storage
- ARDECO data updates follow JRC release schedule: March, May, November
