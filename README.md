# PisoFirme SP - MVP em producao (Secure DevOps & Cloud, "Deploy Blindado")

## Ficha Tecnica do MVP

| Campo | Conteudo |
|---|---|
| **Nome do produto** | PisoFirme SP |
| **Cidadao e territorio** | Pedestres (em especial idosos e pessoas com deficiencia) que circulam por calcadas da cidade de Sao Paulo; gestao das 32 subprefeituras |
| **Problema, em uma frase** | Buracos e perdas de revestimento nas calcadas criam desniveis e risco de queda, e a prefeitura nao tem uma fila priorizada nem a medida certa para o reparo. |
| **Proposta de valor** | Modulo de reparo temporario (estrutura celular impressa em 3D + borracha cortada a laser) e um painel que prioriza quais buracos reparar primeiro e com que medidas fabricar cada peca. |
| **Arquitetura: componentes** | Pipeline de dados (Airflow, medalhao bronze/silver/gold) -> painel estatico (nginx) em container -> Azure Container Registry -> Azure Container Apps; GitHub Actions (DevSecOps); Terraform; Azure Monitor + Application Insights. Ver `docs/ARQUITETURA.md`. |
| **Fontes de dados** | SP156 (solicitacoes sobre calcadas), relatos do app PisoFirme, pontos de interesse (hospital, UBS, escola, metro), subprefeituras e ensaios de bancada. **Dados simulados de forma reprodutivel e justificada** (ver repositorio do pipeline). |
| **Modelos de IA utilizados** | Tabela de features `feat_modelo_severidade` para o modelo de severidade da equipe (classifica a severidade a partir da foto + contexto). _Confirmar nome do modelo com a disciplina de GenAI._ |
| **URL do MVP e repositorio** | MVP: `PREENCHER_URL_DO_CONTAINER_APP` - Repo DevOps: `PREENCHER_URL_DESTE_REPO` - Repo do pipeline: https://github.com/tampa19/pisofirme-pipeline |
| **Indicadores de impacto** | Tempo medio de conclusao de protocolos (dias) por subprefeitura; % de protocolos concluidos; nº de ocorrencias elegiveis ao modulo; custo estimado dos modulos; reducao do tempo entre relato e reparo (antes/depois). |
| **ODS conectados** | ODS 11 (cidades e comunidades sustentaveis: acessibilidade e seguranca no espaco publico), ODS 10 (reducao das desigualdades: idosos e PcD), ODS 3 (saude e bem-estar: menos quedas), ODS 9 (inovacao e infraestrutura). _Confirmar com a equipe._ |

## Como rodar local (reprodutivel)

```bash
docker compose up --build
# abra http://localhost:8080
```

## Como publicar (resumo)

1. `scripts/01-bootstrap-backend.sh` - cria o storage do state do Terraform (fora do repo).
2. `cd terraform && terraform init -backend-config=backend.hcl && terraform apply`.
3. `scripts/02-credencial-github.sh` - gera o secret `AZURE_CREDENTIALS`; cadastre tambem `ACR_NAME`, `RESOURCE_GROUP`, `CONTAINERAPP_NAME` em Settings > Secrets and variables > Actions.
4. `git push` na `main` dispara o pipeline `.github/workflows/pipeline.yml`.
5. `scripts/03-disparar-alerta.sh <URL>` gera trafego para disparar o alerta.
6. Ao final da correcao: `terraform destroy` (evita custo).

## Seguranca e LGPD (resumo)

- Sem segredo no codigo: Gitleaks a cada push; credenciais so no GitHub Secrets.
- Container sem root, filesystem somente leitura, sem capabilities.
- ACR sem usuario admin; o app puxa imagem por identidade gerenciada (AcrPull).
- Unico ponto de entrada: HTTPS 443. Nao ha SSH/RDP expostos.
- O painel mostra dados agregados e simulados; nao ha dado pessoal. Detalhes em `docs/ARQUITETURA.md`.

Deploy em producao via GitHub Actions.
