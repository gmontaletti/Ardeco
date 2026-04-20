# syntax=docker/dockerfile:1.7
#
# ARDECO ETL pipeline image.
# Runs R/run_pipeline.R as a one-shot batch job. Targets Azure Container
# Apps Jobs or Container Instances. Postgres credentials come from env
# vars at runtime (e.g. --env-file .env locally, ACA secrets in Azure).

FROM rocker/r-ver:4.5.2

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Europe/Rome \
    RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.posit.co/cran/__linux__/noble/2026-01-15

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl \
      libpq5 \
      locales tzdata \
 && rm -rf /var/lib/apt/lists/*

RUN Rscript -e 'options(repos = c(CRAN = Sys.getenv("RENV_CONFIG_REPOS_OVERRIDE"))); \
                options(Ncpus = parallel::detectCores()); \
                install.packages(c("ARDECO","data.table","duckdb","DBI","RPostgres","R.utils")); \
                invisible(lapply(c("ARDECO","data.table","duckdb","DBI","RPostgres","R.utils"), \
                         function(p) library(p, character.only = TRUE)))' \
 && rm -rf /tmp/Rtmp* /tmp/downloaded_packages /root/.cache

RUN groupadd --system --gid 1000 app \
 && useradd  --system --uid 1000 --gid app --home /app --create-home app

WORKDIR /app
COPY --chown=app:app R/run_pipeline.R /app/R/run_pipeline.R

USER app
ENTRYPOINT ["Rscript", "/app/R/run_pipeline.R"]
