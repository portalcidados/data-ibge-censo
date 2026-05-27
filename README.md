# data-ibge-censo

Pipeline em R para processar tabelas do Censo 2022 (IBGE/SIDRA) sobre
deslocamento para o trabalho.

## Tabelas

- 10329, 10330, 10331, 10332, 10333

Os arquivos `.xlsx` foram baixados manualmente do SIDRA (a API não suporta
tabelas com essa complexidade) e ficam em `data-raw/`. O script
`R/pipeline_censo_mobilidade.R` gera os dados processados em `data/`.

## Estrutura

- `R/` — scripts de processamento
- `data-raw/` — xlsx originais baixados do SIDRA
- `data/` — saídas processadas
