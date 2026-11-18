# Checklist de evidencias para o PDF (14 pontos)

## Container e IaC (5,0)
- [ ] Print do `Dockerfile` (usuario nao root, sem segredo) e `docker compose up` rodando (ou log do job "build")
- [ ] Print `terraform apply` concluido
- [ ] Print do `.gitignore` mostrando state/.tfvars fora do repo + print do state no Storage Account
- [ ] Print do portal: Container App com ingress apenas HTTPS; ACR com admin desabilitado

## Pipeline DevSecOps (4,0)
- [ ] Print da execucao **barrada** (Gitleaks falhando, deploy "skipped")
- [ ] Print da execucao **corrigida** (tudo verde + deploy)
- [ ] Print dos GitHub Secrets (apenas nomes, nunca valores)

## Observabilidade (3,0)
- [ ] Print do dashboard com as 4 metricas (latencia, trafego, erros, saturacao)
- [ ] Print do alerta **disparado** (Monitor > Alertas) e/ou e-mail recebido

## Documentacao (2,0)
- [ ] Diagrama de arquitetura (docs/ARQUITETURA.md)
- [ ] Responsabilidade compartilhada, LGPD, custo (com print da calculadora)
- [ ] README com Ficha Tecnica preenchida e reproduzivel

## Links clicaveis no PDF
- [ ] Repositorio publico - [ ] URL publica do MVP
