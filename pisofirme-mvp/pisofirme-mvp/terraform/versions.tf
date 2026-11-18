terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # State REMOTO (Storage Account criado por scripts/01-bootstrap-backend.sh).
  # Os valores ficam em backend.hcl, que esta no .gitignore.
  backend "azurerm" {}
}

# A assinatura vem da variavel de ambiente ARM_SUBSCRIPTION_ID (nada fixo no codigo).
provider "azurerm" {
  features {}
}
