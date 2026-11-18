variable "location" {
  description = "Regiao do Azure (se sua conta de estudante bloquear, troque pela regiao permitida)"
  type        = string
  default     = "brazilsouth"
}

variable "ambiente" {
  description = "Nome curto do ambiente"
  type        = string
  default     = "prod"
}

variable "alerta_email" {
  description = "E-mail que recebe os alertas do Azure Monitor"
  type        = string
}

variable "limite_requisicoes_alerta" {
  description = "Requisicoes em 5 min que disparam o alerta de trafego (baixo de proposito, para demonstrar o alerta)"
  type        = number
  default     = 30
}

variable "imagem_inicial" {
  description = "Imagem publica usada so na criacao; o pipeline troca pela imagem do ACR"
  type        = string
  default     = "nginxinc/nginx-unprivileged:1.27-alpine"
}
