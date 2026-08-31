library(DBI)
import::from(here, here)

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = "geoserver",
  host = "plsql-insper-southbr-03-prod.chqyss0q4n8r.sa-east-1.rds.amazonaws.com",
  port = 5432,
  user = "viniciusor",
  password = "U$3R_G3o$@!#"
)

datadir <- here("data/deslocamento_trabalho")

path_files <- list.files(
  datadir,
  pattern = "\\.rds$",
  full.names = TRUE
)

name_files <- list.files(datadir, pattern = "\\.rds$")
name_files <- gsub("\\.rds$", "", name_files)
fact_tables <- lapply(path_files, readr::read_rds)
names(fact_tables) <- name_files

name_tables <- c(
  "tabela10329" = "workplace_renda_sexo",
  "tabela10330" = "tempo_modal_raca_workplace",
  "tabela10331" = "tempo_raca_renda_sexo",
  "tabela10332" = "modal_educ_raca",
  "tabela_10333" = "tempo_educ_idade_raca"
)

prefix <- "ibge_censo_deslocamento"
name_tables <- paste0(prefix, "_", name_tables)
names(name_tables) <- name_files

for (i in seq_along(name_tables)) {
  table_name <- names(name_tables)[i]
  cli::cli_alert_info("Exporting {.field {table_name}}")
  DBI::dbWriteTable(
    con,
    DBI::Id(schema = "portal_observatorio", table = name_tables[table_name]),
    fact_tables[[table_name]],
    overwrite = TRUE
  )
}

path_files <- list.files(datadir, pattern = "\\.csv$", full.names = TRUE)
name_files <- list.files(datadir, pattern = "\\.csv$")
name_files <- gsub("\\.csv$", "", name_files)

dim_tables <- lapply(path_files, readr::read_csv, show_col_types = FALSE)
names(dim_tables) <- name_files

name_dim_tables <- paste0(prefix, "_", name_files)
names(name_dim_tables) <- name_files

for (i in seq_along(name_dim_tables)) {
  table_name <- names(name_dim_tables)[i]
  cli::cli_alert_info("Exporting {.field {table_name}}")

  DBI::dbWriteTable(
    con,
    DBI::Id(
      schema = "portal_observatorio",
      table = name_dim_tables[table_name]
    ),
    dim_tables[[table_name]]
  )
}
