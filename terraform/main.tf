resource "random_string" "sufixo" {
  length  = 5
  upper   = false
  special = false
}

locals {
  tags = {
    projeto        = "pisofirme-sp"
    disciplina     = "secure-devops-cloud"
    ambiente       = var.ambiente
    gerenciado_por = "terraform"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-pisofirme-${var.ambiente}"
  location = var.location
  tags     = local.tags
}

# ---------- Observabilidade: base ----------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-pisofirme-${random_string.sufixo.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.5 # teto de custo
  tags                = local.tags
}

resource "azurerm_application_insights" "ai" {
  name                = "appi-pisofirme-${random_string.sufixo.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
  tags                = local.tags
}

# ---------- Registro de imagens ----------
# DECISAO REGISTRADA: o usuario admin do ACR fica HABILITADO porque o ambiente
# do Container Apps em uso (modelo "express", em preview) recusa identidade
# gerenciada para puxar imagem (erro ExpressRegistrySystemIdentityNotSupported).
# Mitigacao: a senha nunca vai para o codigo; ela e lida pelo Terraform, guardada
# como secret do Container App e pode ser rotacionada com
#   az acr credential renew --password-name password
# Quando o modelo express suportar identidade gerenciada, voltar para
# admin_enabled = false + AcrPull por identidade.
resource "azurerm_container_registry" "acr" {
  name                = "acrpisofirme${random_string.sufixo.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = local.tags
}

# ---------- Hospedagem ----------
resource "azurerm_container_app_environment" "env" {
  name                       = "cae-pisofirme-${var.ambiente}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  tags                       = local.tags
}

resource "azurerm_container_app" "app" {
  name                         = "ca-pisofirme-painel"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  tags                         = local.tags

  # Senha do registro guardada como secret do app (nao fica no codigo).
  secret {
    name  = "registry-senha"
    value = azurerm_container_registry.acr.admin_password
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "registry-senha" # gitleaks:allow (nome do secret, nao e senha)
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name   = "painel"
      image  = var.imagem_inicial
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  # Unico ponto de entrada: HTTPS 443 (o Container Apps nao expoe SSH/RDP).
  ingress {
    external_enabled           = true
    target_port                = 8080
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  # A imagem passa a ser controlada pelo pipeline (GitHub Actions).
  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}

# ---------- Observabilidade: teste de disponibilidade (LATENCIA) ----------
resource "azurerm_application_insights_standard_web_test" "ping" {
  name                    = "ping-painel"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  application_insights_id = azurerm_application_insights.ai.id
  geo_locations           = ["us-va-ash-azr", "us-tx-sn1-azr"]
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  retry_enabled           = true

  request {
    url = "https://${azurerm_container_app.app.ingress[0].fqdn}/healthz"
  }

  validation_rules {
    expected_status_code = 200
  }

  tags = merge(local.tags, {
    "hidden-link:${azurerm_application_insights.ai.id}" = "Resource"
  })
}

# ---------- Alertas ----------
resource "azurerm_monitor_action_group" "ag" {
  name                = "ag-pisofirme"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "pisofirme"

  email_receiver {
    name          = "equipe"
    email_address = var.alerta_email
  }
}

# TRAFEGO (usado para disparar o alerta na demonstracao)
resource "azurerm_monitor_metric_alert" "trafego" {
  name                = "alerta-trafego-alto"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_container_app.app.id]
  description         = "Mais requisicoes que o limite em 5 minutos"
  severity            = 3
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.App/containerapps"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.limite_requisicoes_alerta
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}

# ERROS
resource "azurerm_monitor_metric_alert" "erros_5xx" {
  name                = "alerta-erros-5xx"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_container_app.app.id]
  description         = "Qualquer resposta 5xx em 5 minutos"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.App/containerapps"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0

    dimension {
      name     = "statusCodeCategory"
      operator = "Include"
      values   = ["5xx"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}

# SATURACAO (memoria acima de ~80% dos 512 MiB)
resource "azurerm_monitor_metric_alert" "memoria" {
  name                = "alerta-memoria-alta"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_container_app.app.id]
  description         = "Memoria do container acima de 400 MB"
  severity            = 3
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.App/containerapps"
    metric_name      = "WorkingSetBytes"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 419430400
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}
