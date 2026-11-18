# Arquitetura, seguranca, custo e observabilidade

## 1. Diagrama

```mermaid
flowchart LR
  Dev[Equipe] -->|git push| GH[GitHub]
  subgraph CI[GitHub Actions]
    G[Gitleaks] --> S[Semgrep] --> TC[Trivy config]
    B[Build + docker compose] --> TI[Trivy imagem]
  end
  GH --> CI
  CI -->|main + tudo verde| ACR[Azure Container Registry]
  ACR -->|AcrPull por identidade| CA[Azure Container Apps<br/>nginx + painel PisoFirme]
  TF[Terraform<br/>state no Storage Account] -.cria.-> ACR
  TF -.cria.-> CA
  TF -.cria.-> MON
  CA --> LAW[Log Analytics]
  CA --> MON[Azure Monitor<br/>metricas + alertas]
  AI[Application Insights<br/>teste de disponibilidade] --> CA
  U[Cidadao / avaliador] -->|HTTPS 443| CA
  PIPE[Pipeline Airflow<br/>disciplina 02] -.gera mvp/dados.js.-> GH
```

## 2. Responsabilidade compartilhada

| Camada | Quem cuida |
|---|---|
| Datacenter, hardware, hipervisor, rede fisica | Microsoft |
| Plataforma Container Apps (orquestracao, patch do host, TLS no ingress) | Microsoft |
| Imagem do container (base, dependencias, nginx.conf) | **Equipe** |
| Codigo do painel e dados publicados | **Equipe** |
| Identidades, permissoes (RBAC) e segredos (GitHub Secrets) | **Equipe** |
| Configuracao do Terraform, alertas, retencao de logs | **Equipe** |

## 3. Onde ficam os dados pessoais (LGPD)

- O painel publicado usa **dados simulados e agregados** (SP156, relatos, POIs, ensaios). Nao ha CPF, nome, e-mail ou telefone no MVP.
- O unico dado pessoal tratado na infraestrutura e o **e-mail do alerta** (Azure Monitor) e os **logs de acesso** (IP do visitante) no Log Analytics, com retencao de 30 dias e teto diario de 0,5 GB.
- Regiao padrao: `brazilsouth` (dados em territorio nacional). Se a conta de estudante exigir outra regiao, registrar aqui.
- Se o app real passar a receber fotos/localizacao de cidadaos: coleta com consentimento, minimizacao (arredondar coordenadas), base legal definida e Blob Storage privado com criptografia e prazo de retencao.
- Segredos: nenhum no codigo ou na imagem; credenciais do Azure so no GitHub Secrets.

## 4. Estimativa de custo (referencia mensal, a confirmar na Azure Pricing Calculator)

| Servico | Configuracao | Custo aprox. (US$/mes) |
|---|---|---|
| Container Apps | 0,25 vCPU, 0,5 GiB, 1 replica sempre ligada (consumo) | 2 a 6 |
| Container Registry | SKU Basic | ~5 |
| Log Analytics | teto 0,5 GB/dia (5 GB/mes gratis) | 0 a 2 |
| Application Insights | 1 teste de disponibilidade a cada 5 min | 0 a 3 |
| Storage Account (state) | LRS, poucos KB | < 0,1 |
| Azure Monitor alertas | 3 alertas de metrica | < 1,5 |
| **Total** | | **~10 a 18** |

Cobertos pelo credito do Azure for Students. Reduzir custo: `min_replicas = 0` e `terraform destroy` apos a correcao.
**Atualizar este numero com o valor real da calculadora (anexar print).**

## 5. Observabilidade: as 4 metricas de ouro

| Sinal | Onde ver | Metrica |
|---|---|---|
| Latencia | Application Insights > Metricas | `Availability test duration` (teste `ping-painel`) |
| Trafego | Container App > Metricas | `Requests` (Total) |
| Erros | Container App > Metricas | `Requests` dividido por `Status code category` (5xx) |
| Saturacao | Container App > Metricas | `CPU usage (nanocores)` e `Memory working set bytes` |

Alertas criados pelo Terraform: `alerta-trafego-alto` (usado na demonstracao), `alerta-erros-5xx`, `alerta-memoria-alta`.

## 6. Decisoes de seguranca ligadas ao enunciado

- **Porta admin nunca aberta para 0.0.0.0/0:** o Container Apps nao expoe SSH/RDP; o unico acesso publico e HTTPS 443. O ACR tem `admin_enabled = false`.
- **State e .tfvars fora do repo:** state em Storage Account remoto; `*.tfvars` e `backend.hcl` no `.gitignore`.
- **Pipeline:** Gitleaks (segredos), Semgrep (codigo), Trivy config (Dockerfile/Terraform) e Trivy image (imagem). Deploy so na `main` e so com tudo verde.
