output "url_mvp" {
  value = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}
output "resource_group" {
  value = azurerm_resource_group.rg.name
}
output "acr_name" {
  value = azurerm_container_registry.acr.name
}
output "acr_id" {
  value = azurerm_container_registry.acr.id
}
output "containerapp_name" {
  value = azurerm_container_app.app.name
}
