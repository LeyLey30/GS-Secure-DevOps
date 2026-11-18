#!/usr/bin/env bash
# Rode no Cloud Shell DEPOIS do terraform apply.
# Cria uma identidade de servico com permissao SO no grupo de recursos do projeto
# e imprime o JSON que vai no GitHub Secret AZURE_CREDENTIALS.
set -euo pipefail
cd "$(dirname "$0")/../terraform"
SUB=$(az account show --query id -o tsv)
RG=$(terraform output -raw resource_group)
ACR_ID=$(terraform output -raw acr_id)

SP=$(az ad sp create-for-rbac --name "sp-github-pisofirme" --role Contributor \
      --scopes "/subscriptions/$SUB/resourceGroups/$RG" -o json)
APPID=$(echo "$SP" | jq -r .appId)

az role assignment create --assignee "$APPID" --role AcrPush --scope "$ACR_ID" -o none

echo
echo "=== Cole no GitHub Secret AZURE_CREDENTIALS ==="
echo "$SP" | jq --arg s "$SUB" '{clientId:.appId, clientSecret:.password, tenantId:.tenant, subscriptionId:$s}'
echo "==============================================="
echo "Outros secrets:"
echo "  ACR_NAME           = $(terraform output -raw acr_name)"
echo "  RESOURCE_GROUP     = $RG"
echo "  CONTAINERAPP_NAME  = $(terraform output -raw containerapp_name)"
