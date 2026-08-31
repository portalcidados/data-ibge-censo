# - Censo: 10329, 10330, 10331, 10332, 10333
# - tables are too large and complex to be downloaded via API
# Since it's a one-time pull, we did it mannually via SIDRA
# The Excel files were downloaded into data-raw

# Setup -------------------------------------------------------------------

library(dplyr)
library(stringr)
library(tidyr)
import::from(fs, dir_create, dir_ls)
import::from(here, here)

datadir <- here("data/deslocamento_trabalho")
datarawdir <- here("data-raw/deslocamento_trabalho")

fs::dir_create(datadir)
fs::dir_create(datarawdir)

path_files <- fs::dir_ls(datarawdir)

params <- tibble(
  path = path_files
)

params <- params |>
  mutate(
    name_file = str_remove(basename(path), "\\.xlsx$"),
    main_table = str_extract(name_file, "(?<=tabela)[0-9]{5}")
  )

col_sep <- " // "


# Dimensions --------------------------------------------------------------

col_names_time <- c(
  "Até cinco minutos",
  "De seis minutos até quinze minutos",
  "Mais de quinze minutos até meia hora",
  "Mais de meia hora até uma hora",
  "Mais de uma hora até duas horas",
  "Mais de duas horas até quatro horas",
  "Mais de quatro horas"
)

col_names_modes <- c(
  "A pé",
  "Bicicleta",
  "Motocicleta",
  "Mototáxi",
  "Automóvel",
  "Táxi ou assemelhados",
  "Van, perua ou assemelhados",
  "Ônibus",
  "BRT ou ônibus de trânsito rápido",
  "Trem ou metrô",
  "Caminhonete ou caminhão adaptado (pau de arara)",
  "Embarcação de médio e grande porte (acima de 20 pessoas)",
  "Embarcação de pequeno porte (até 20 pessoas)",
  "Outros"
)

dim_time <- tibble(
  time = col_names_time,
  time_inf = c(
    0,
    5,
    15,
    30,
    60,
    120,
    240
  ),
  time_max = c(
    5,
    15,
    30,
    60,
    120,
    240,
    480
  ),
  time_midpoint = c(
    2.5,
    10,
    22.5,
    45,
    90,
    180,
    240
  )
)

# OBS: need to review this classification in the future
dim_transport_mode <- tibble(
  transport_mode = col_names_modes,
  transport_group = case_when(
    transport_mode %in% c("A pé", "Bicicleta") ~ "Ativo",
    transport_mode == "Outros" ~ NA_character_,
    TRUE ~ "Motorizado"
  ),
  transport_type = case_when(
    str_detect(
      transport_mode,
      "Ônibus|Trem|Embarcação|Van|Caminhonete"
    ) ~ "Público",
    transport_mode == "Outros" ~ NA_character_,
    TRUE ~ "Privado"
  ),
  transport_mode_grouped = case_when(
    transport_mode %in% c("A pé", "Bicicleta") ~ "Ativo",
    transport_mode %in%
      c(
        "Automóvel",
        "Táxi ou assemelhados",
        "Motocicleta",
        "Mototáxi"
      ) ~ "Carro ou moto",
    transport_mode != "Outros" ~ "Transporte público"
  )
)

# minimum wage in 2022
# OBS: could not find which MW is used by the Census
mw <- 1212

dim_income_class <- tibble(
  income_class = c(
    "Até 1/4 de salário mínimo",
    "Mais de 1/4 a 1/2 salário mínimo",
    "Mais de 1/2 a 1 salário mínimo",
    "Mais de 1 a 2 salários mínimos",
    "Mais de 2 a 3 salários mínimos",
    "Mais de 3 a 5 salários mínimos",
    "Mais de 5 salários mínimos",
    "Sem rendimento"
  ),
  income_inf = c(0, 0.25, 0.5, 1, 2, 3, 5, NA),
  income_max = c(0.25, 0.5, 1, 2, 3, 5, 50, NA),
  income_midpoint = (income_max - income_inf) / 2 + income_inf,
  income_estimate = income_midpoint * mw,
  # Crude estimate based of household income using
  # UN's head of household method
  # Using table 4712 (average number of dwellers per household)
  income_indiviudal_est = income_estimate * sqrt(2.79)
)

# Functions ---------------------------------------------------------

# Draft -------------------------------------------------------------------

# x1 <- c(
#   "Total",
#   "Município de residência",
#   "Município de residência - no domicílio de residência",
#   "Município de residência - fora do domicílio de residência",
#   "Outro município",
#   "País estrangeiro",
#   "Mais de um município ou país"
# )

# x2 <- c("Homens", "Mulheres")

# x3 <- paste(rep(x1, each = 2), rep(x2, length(x1)), sep = " / ")

# col_names <- c(
#   "code_muni",
#   "income_class",
#   "returns_home",
#   "Total / Homens",
#   "Total / Mulheres",
#   "Município de residência / Homens",
#   "Município de residência / Mulheres",
#   "Município de residência - no domicílio de residência / Homens",
#   "Município de residência - no domicílio de residência / Mulheres",
#   "Município de residência - fora do domicílio de residência / Homens",
#   "Município de residência - fora do domicílio de residência / Mulheres",
#   "Outro município / Homens",
#   "Outro município / Mulheres",
#   "País estrangeiro / Homens",
#   "País estrangeiro / Mulheres",
#   "Mais de um município ou país / Homens",
#   "Mais de um município ou país / Mulheres"
# )

# dat <- readxl::read_excel(
#   params$path[1],
#   skip = 6,
#   col_names = col_names,
#   col_types = "text",
#   na = "-"
# )

# id_cols <- c("code_muni", "income_class", "returns_home")

# clean_dat <- dat |>
#   mutate(code_muni = as.numeric(code_muni)) |>
#   pivot_longer(
#     cols = -all_of(id_cols),
#     names_to = c("work_location", "sex"),
#     names_sep = " / "
#   ) |>
#   mutate(value = as.numeric(value))

# col_names_variables <- paste(
#   rep(col_names_modes, times = length(col_names_time)),
#   rep(c("Total", col_names_time), each = length(col_names_modes)),
#   sep = col_sep
# )

# col_names_ids <- c("code_muni", "race", "work_location")

# col_names <- c(col_names_ids, col_names_variables)

# Functions --------------------------------------------------------------

import_excel <- function(path, col_names, skip) {
  dat <- readxl::read_excel(
    path = path,
    skip = skip,
    col_names = col_names,
    col_types = "text",
    na = "-"
  )

  return(dat)
}

pick_table_path <- function(table_name) {
  params |>
    filter(str_detect(name_file, !!table_name)) |>
    pull(path)
}

clean_tab_10330 <- function(dat) {
  dat |>
    pivot_longer(
      cols = -all_of(col_names_ids),
      names_to = c("transport_mode", "time"),
      names_sep = col_sep
    ) |>
    mutate(
      code_muni = as.numeric(code_muni),
      value = as.numeric(value)
    )
}


# Tabela 10330 -----------------------------------------------------------

col_names_variables <- c(
  c("Total", dim_time$time),
  dim_transport_mode$transport_mode
)

col_names_variables <- str_c(
  rep(
    c("Total", dim_time$time),
    each = length(dim_transport_mode$transport_mode)
  ),
  col_sep,
  rep(dim_transport_mode$transport_mode, times = length(dim_time$time) + 1)
)

id_cols <- c("code_muni", "race", "workplace")

col_names <- c(id_cols, col_names_variables)

paths <- params |>
  filter(str_detect(name_file, "tabela10330")) |>
  pull(path)

files <- parallel::mclapply(
  paths,
  import_excel,
  col_names = col_names,
  skip = 6
)

tab_10330 <- bind_rows(files)

clean_dat <- tab_10330 |>
  # Removes "Fonte" lines
  filter(!is.na(workplace)) |>
  fill(code_muni, race) |>
  pivot_longer(
    cols = -all_of(id_cols),
    names_to = c("time", "transport_mode"),
    names_sep = col_sep
  ) |>
  mutate(
    code_muni = as.numeric(code_muni),
    value = as.numeric(value)
  )

clean_dat <- left_join(clean_dat, dim_time, by = "time")

readr::write_rds(
  clean_dat,
  here(datadir, "tabela10330.rds"),
  compress = "gz"
)

# unique(clean_tab_10330$workplace)

# tempos_totais <- clean_tab_10330 |>
#   filter(
#     workplace == "Município de residência - fora do domicílio de residência"
#   ) |>
#   summarise(
#     total = sum(value, na.rm = TRUE),
#     .by = c("code_muni", "time", "transport_mode")
#   )

# tempos_totais |>
#   filter(time != "Total") |>
#   left_join(dim_time, by = "time") |>
#   summarise(
#     tempo_medio = weighted.mean(time_midpoint, total, na.rm = TRUE),
#     nobs = sum(total, na.rm = TRUE),
#     .by = c("code_muni", "transport_mode")
#   ) |>
#   filter(code_muni %in% c(3550308, 4314902)) |>
#   pivot_wider(
#     id_cols = "transport_mode",
#     names_from = "code_muni",
#     values_from = "tempo_medio"
#   )

# Tabela 10331 -----------------------------------------------------------

col_names_variables <- c("Total", dim_time$time)
id_cols <- c("code_muni", "race", "income_class")

col_names <- c(id_cols, col_names_variables)

paths <- params |>
  filter(str_detect(name_file, "tabela10331")) |>
  pull(path)

clean_tab_10331 <- function(dat) {
  dat |>
    fill(code_muni, race) |>
    pivot_longer(
      cols = -all_of(id_cols),
      names_to = "time"
    ) |>
    mutate(
      code_muni = as.numeric(code_muni),
      value = as.numeric(value)
    )
}

tab_10331_male <- import_excel(
  paths[1],
  col_names = col_names,
  skip = 6
)

tab_10331_female <- import_excel(
  paths[2],
  col_names = col_names,
  skip = 6
)

tab_10331_male <- clean_tab_10331(tab_10331_male)
tab_10331_female <- clean_tab_10331(tab_10331_female)

tab_10331 <- bind_rows(
  list("Masculino" = tab_10331_male, "Feminino" = tab_10331_female),
  .id = "sex"
)

readr::write_rds(
  tab_10331,
  here(datadir, "tabela10331.rds"),
  compress = "gz"
)

# tab_10331 |>
#   summarise(
#     total = sum(value, na.rm = TRUE),
#     .by = c("code_muni", "income_class")
#   ) |>
#   mutate(
#     share = total / sum(total, na.rm = TRUE) * 100,
#     .by = "code_muni"
#   )

# Tabela 10332 -----------------------------------------------------------

dim_education <- tibble(
  education = c(
    "Sem instrução e fundamental incompleto",
    "Fundamental completo e médio incompleto",
    "Médio completo e superior incompleto",
    "Superior completo"
  ),
  education_group = c(
    "Fundamental incompleto ou menos",
    "Fundamental completo",
    "Médio completo",
    "Superior completo"
  )
)


col_names_variables <- paste(
  paste(rep(
    c("Total", dim_transport_mode$transport_mode),
    each = length(dim_education$education)
  )),
  rep(dim_education$education, length(dim_transport_mode$transport_mode) + 1),
  sep = col_sep
)

col_names_ids <- c("code_muni", "race")

col_names <- c(col_names_ids, col_names_variables)

paths <- params |>
  filter(str_detect(name_file, "tabela10332")) |>
  pull(path)

dat <- import_excel(paths, col_names = col_names, skip = 6)

clean_dat <- dat |>
  pivot_longer(
    cols = -all_of(col_names_ids),
    names_to = c("transport_mode", "education"),
    names_sep = col_sep
  ) |>
  mutate(
    code_muni = as.numeric(code_muni),
    value = as.numeric(value)
  )

clean_dat <- clean_dat |>
  left_join(dim_education, by = "education") |>
  left_join(dim_transport_mode, by = "transport_mode")

readr::write_rds(clean_dat, here(datadir, "tabela10332.rds"), compress = "gz")

# Tabela 10333 -----------------------------------------------------------

col_names_variables <- paste(
  rep(c("Total", dim_time$time), each = length(dim_education$education)),
  rep(dim_education$education, times = length(dim_time$time) + 1),
  sep = col_sep
)

col_names_ids <- c("code_muni", "age_group", "race")

col_names <- c(col_names_ids, col_names_variables)

paths <- params |>
  filter(str_detect(name_file, "tabela10333")) |>
  pull(path)

dat <- import_excel(paths, col_names = col_names, skip = 6)

clean_dat <- dat |>
  fill(code_muni, age_group, .direction = "down") |>
  pivot_longer(
    cols = -all_of(col_names_ids),
    names_to = c("time", "education"),
    names_sep = col_sep
  ) |>
  mutate(
    code_muni = as.numeric(code_muni),
    value = as.numeric(value)
  )

clean_dat <- clean_dat |>
  left_join(dim_education, by = "education") |>
  left_join(dim_time, by = "time")

readr::write_rds(clean_dat, here(datadir, "tabela10333.rds"), compress = "gz")

# Tabela 10329 -----------------------------------------------------------

dim_workplace <- tibble(
  workplace = c(
    "Município de residência",
    "Município de residência - no domicílio de residência",
    "Município de residência - fora do domicílio de residência",
    "Outro município",
    "País estrangeiro",
    "Mais de um município ou país"
  ),
  level = c(1, 2, 2, 1, 1, 1)
)

col_names_variables <- paste(
  rep(c("Total", dim_workplace$workplace), each = 2),
  rep(c("Masculino", "Feminino"), length(dim_workplace$workplace)),
  sep = col_sep
)

# - Retornam do trabalho para casa 3 (três) dias ou mais na semana
col_names_ids <- c("code_muni", "income_class", "is_comes_home")

col_names <- c(col_names_ids, col_names_variables)

paths <- params |>
  filter(str_detect(name_file, "tabela10329")) |>
  pull(path)

dat <- import_excel(paths, col_names = col_names, skip = 6)

clean_dat <- dat |>
  fill(code_muni, income_class, .direction = "down") |>
  pivot_longer(
    cols = -all_of(col_names_ids),
    names_to = c("place_of_work", "sex"),
    names_sep = col_sep
  ) |>
  mutate(
    code_muni = as.numeric(code_muni),
    value = as.numeric(value)
  )

clean_dat <- left_join(clean_dat, dim_income_class, by = "income_class")

readr::write_rds(clean_dat, here(datadir, "tabela10329.rds"), compress = "gz")

# Export dimension tables ------------------------------------------------

readr::write_csv(
  dim_income_class,
  here(datadir, "dim_income_class.csv"),
)

readr::write_csv(
  dim_time,
  here(datadir, "dim_time.csv"),
)

readr::write_csv(
  dim_transport_mode,
  here(datadir, "dim_transport_mode.csv"),
)
