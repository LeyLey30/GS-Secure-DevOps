#!/usr/bin/env bash
# Rode no Azure Cloud Shell (Bash). Cria o Storage Account que guarda o STATE do Terraform
# (fora do repositorio) e registra os providers necessarios.
set -euo pipefail
LOCATION="${1:-brazilsouth}"
RG="rg-pisofirme-tfstate"
SA="stpfstate$(openssl rand -hex 4)"

echo ">> Registrando providers (pode levar alguns minutos)..."
for ns in Microsoft.App Microsoft.OperationalInsights Microsoft.ContainerRegistry \
          Microsoft.Insights Microsoft.ManagedIdentity Microsoft.Storage; do
  az provider register --namespace "$ns" --wait
done

echo ">> Criando grupo de recursos e storage do state em $LOCATION..."
az group create -n "$RG" -l "$LOCATION" -o none
az storage account create -n "$SA" -g "$RG" -l "$LOCATION" --sku Standard_LRS \
  --min-tls-version TLS1_2 --allow-blob-public-access false -o none
KEY=$(az storage account keys list -g "$RG" -n "$SA" --query "[0].value" -o tsv)
az storage container create --name tfstate --account-name "$SA" --account-key "$KEY" -o none

cat > "$(dirname "$0")/../terraform/backend.hcl" <<HCL
resource_group_name  = "$RG"
storage_account_name = "$SA"
container_name       = "tfstate"
key                  = "pisofirme.tfstate"
HCL

echo
echo "OK. backend.hcl criado (esta no .gitignore)."
echo "Rode agora:"
echo "  export ARM_SUBSCRIPTION_ID=\$(az account show --query id -o tsv)"
echo "  export ARM_ACCESS_KEY='$KEY'"
