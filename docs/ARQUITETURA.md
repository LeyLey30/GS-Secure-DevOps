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
  ACR -->|usuario e senha do registro<br/>guardados como secret do app| CA[Azure Container Apps<br/>nginx + painel PisoFirme]
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
| Identidades, permissoes (RBAC) e segredos (GitHub Secrets, secret do app) | **Equipe** |
| Configuracao do Terraform, alertas, retencao de logs | **Equipe** |

## 3. Onde ficam os dados pessoais (LGPD)

- O painel publicado usa **dados simulados e agregados** (SP156, relatos, POIs, ensaios). Nao ha CPF, nome, e-mail ou telefone no MVP.
- O unico dado pessoal tratado na infraestrutura e o **e-mail do alerta** (Azure Monitor) e os **logs de acesso** (IP do visitante) no Log Analytics, com retencao de 30 dias e teto diario de 0,5 GB.
- **Regiao: `eastus2` (Estados Unidos).** A regiao padrao do projeto era `brazilsouth`, mas a politica da assinatura de estudante bloqueou a criacao de recursos nela (erro `RequestDisallowedByAzure`). Como nao ha dado pessoal no painel, o impacto de LGPD e pequeno; em producao real, a hospedagem seria no Brasil ou haveria base legal para a transferencia internacional.
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

Cobertos pelo credito do Azure for Students (saldo observado: R$ 537,42, 0,03% usado no inicio do projeto). Reduzir custo: `min_replicas = 0` e `terraform destroy` apos a correcao.
**Anexar o print da Azure Pricing Calculator com o valor real.**

## 5. Observabilidade: as 4 metricas de ouro

| Sinal | Onde ver | Metrica |
|---|---|---|
| Latencia | Application Insights > Metricas | `Availability test duration` (teste `ping-painel`) |
| Trafego | Container App > Metricas | `Requests` (Total) |
| Erros | Container App > Metricas | `Requests` dividido por `Status code category` (5xx) |
| Saturacao | Container App > Metricas | `CPU usage (nanocores)` e `Memory working set bytes` |

Alertas criados pelo Terraform: `alerta-trafego-alto` (usado na demonstracao), `alerta-erros-5xx`, `alerta-memoria-alta`.
**Evidencia:** o `alerta-trafego-alto` foi **acionado em 19/11/2026 as 09:36** apos 80 requisicoes em cerca de 40 s (limite: 30 requisicoes em 5 min).

## 6. Decisoes de seguranca ligadas ao enunciado

- **Porta admin nunca aberta para 0.0.0.0/0:** o Container Apps nao expoe SSH/RDP; o unico acesso publico e HTTPS 443.
- **State e .tfvars fora do repo:** state em Storage Account remoto; `*.tfvars` e `backend.hcl` no `.gitignore`.
- **Pipeline:** Gitleaks (segredos), Semgrep (codigo), Trivy config (Dockerfile/Terraform) e Trivy image (imagem). Deploy so na `main` e so com tudo verde.
- **Execucao barrada e corrigida:** a primeira execucao foi barrada pelo Trivy (vulnerabilidades HIGH/CRITICAL no `zlib`, `pcre2` e outros pacotes da imagem base) e pelo Semgrep (acoes do GitHub nao fixadas por commit SHA). Correcoes: `apk upgrade` no Dockerfile e acoes fixadas por SHA no workflow. A execucao seguinte passou e fez o deploy.

## 7. Desvio registrado: usuario admin do ACR

O projeto previa o ACR **sem** usuario admin, com o Container App puxando a imagem por identidade gerenciada (`AcrPull`). Na pratica:

1. O Azure recusou a configuracao com o erro `ExpressRegistrySystemIdentityNotSupported` ("System-assigned managed identity ... is not supported ... on express environments").
2. A documentacao da Microsoft indica que o modelo **express** (em preview) nao suporta identidade gerenciada, e que aceita imagem anonima ou por token.
3. Foi testado que as credenciais do registro funcionam (HTTP 200 no login e na listagem de tags) e o app foi recriado com usuario e senha.

**Mitigacoes:** a senha nao esta no codigo nem na imagem (e lida pelo Terraform e guardada como secret do Container App); pode ser rotacionada com `az acr credential renew`; o GitHub usa uma identidade propria com permissoes minimas (Contributor so no grupo de recursos do projeto e `AcrPush` so no registro). **Proximo passo em producao:** voltar para identidade gerenciada quando o ambiente suportar, ou migrar para um ambiente Container Apps com perfis de carga de trabalho.
