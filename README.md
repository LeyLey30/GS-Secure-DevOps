# PisoFirme SP - MVP em producao (Secure DevOps & Cloud, "Deploy Blindado")

**MVP no ar:** https://ca-pisofirme-painel.bluerock-a4800c2b.eastus2.azurecontainerapps.io
**Repositorio (DevOps):** https://github.com/LeyLey30/GS-Secure-DevOps
**Repositorio (pipeline de dados):** https://github.com/tampa19/pisofirme-pipeline

## Ficha Tecnica do MVP

| Campo | Conteudo |
|---|---|
| **Nome do produto** | PisoFirme SP |
| **Cidadao e territorio** | Pedestres (em especial idosos e pessoas com deficiencia) que circulam por calcadas da cidade de Sao Paulo; gestao das 32 subprefeituras |
| **Problema, em uma frase** | Buracos e perdas de revestimento nas calcadas criam desniveis e risco de queda, e a prefeitura nao tem uma fila priorizada nem a medida certa para o reparo. |
| **Proposta de valor** | Modulo de reparo temporario (estrutura celular impressa em 3D + borracha cortada a laser) e um painel que prioriza quais buracos reparar primeiro e com que medidas fabricar cada peca. |
| **Arquitetura: componentes** | Pipeline de dados (Airflow, medalhao bronze/silver/gold) -> painel estatico (nginx) em container -> Azure Container Registry -> Azure Container Apps; GitHub Actions (DevSecOps); Terraform; Azure Monitor + Application Insights. Ver `docs/ARQUITETURA.md`. |
| **Fontes de dados** | SP156 (solicitacoes sobre calcadas), relatos do app PisoFirme, pontos de interesse (hospital, UBS, escola, metro), subprefeituras e ensaios de bancada. **Dados simulados de forma reprodutivel e justificada** (ver repositorio do pipeline). |
| **Modelos de IA utilizados** | Tabela de features `feat_modelo_severidade` para o modelo de severidade da equipe (classifica a severidade a partir da foto + contexto). _Confirmar o nome do modelo com a disciplina de GenAI._ |
| **URL do MVP e repositorio** | MVP: https://ca-pisofirme-painel.bluerock-a4800c2b.eastus2.azurecontainerapps.io - Repo: https://github.com/LeyLey30/GS-Secure-DevOps |
| **Indicadores de impacto** | Tempo medio de conclusao de protocolos (dias) por subprefeitura; % de protocolos concluidos; nº de ocorrencias elegiveis ao modulo; custo estimado dos modulos; reducao do tempo entre relato e reparo (antes/depois). |
| **ODS conectados** | ODS 11 (cidades e comunidades sustentaveis: acessibilidade e seguranca no espaco publico), ODS 10 (reducao das desigualdades: idosos e PcD), ODS 3 (saude e bem-estar: menos quedas), ODS 9 (inovacao e infraestrutura). _Confirmar com a equipe._ |

## Como rodar local (reprodutivel)

```bash
docker compose up --build
# abra http://localhost:8080
```

## Como publicar

1. `scripts/01-bootstrap-backend.sh <regiao>` - cria o storage do state do Terraform (fora do repo) e registra os providers.
2. `cd terraform && cp terraform.tfvars.example terraform.tfvars` (editar o e-mail), depois `terraform init -backend-config=backend.hcl && terraform apply`.
3. `scripts/02-credencial-github.sh` - gera o secret `AZURE_CREDENTIALS`; cadastre tambem `ACR_NAME`, `RESOURCE_GROUP` e `CONTAINERAPP_NAME` em Settings > Secrets and variables > Actions.
4. `git push` na `main` dispara o pipeline `.github/workflows/pipeline.yml`.
5. `scripts/03-disparar-alerta.sh <URL>` gera trafego para disparar o alerta.
6. Ao final da correcao: `terraform destroy` e apagar o grupo `rg-pisofirme-tfstate` (evita custo).

> A regiao padrao e `brazilsouth`, mas a conta de estudante usada aqui so permitia outras regioes; o projeto foi publicado em `eastus2`.

## Seguranca e LGPD (resumo)

- Sem segredo no codigo: Gitleaks a cada push; credenciais so no GitHub Secrets e como secret do Container App.
- Container sem root, filesystem somente leitura, sem capabilities.
- Pipeline barra vulnerabilidades: Semgrep (codigo), Trivy (Dockerfile, Terraform e imagem) e acoes do GitHub fixadas por commit SHA.
- Unico ponto de entrada: HTTPS 443. Nao ha SSH/RDP expostos.
- **Decisao registrada:** o usuario admin do ACR esta habilitado porque o ambiente Container Apps "express" (preview) nao suporta identidade gerenciada para puxar imagem. Detalhes e mitigacao em `docs/ARQUITETURA.md`.
- O painel mostra dados agregados e simulados; nao ha dado pessoal.
