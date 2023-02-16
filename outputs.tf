#------------------------------------------------------------------------------
# TFE URLs
#------------------------------------------------------------------------------
output "url" {
  value       = "https://${var.tfe_fqdn}"
  description = "URL of TFE application based on `tfe_fqdn` input."
}

output "admin_console_url" {
  value       = "https://${var.tfe_fqdn}:8800"
  description = "URL of TFE (Replicated) Admin Console based on `tfe_fqdn` input."
}

#------------------------------------------------------------------------------
# External Services
#------------------------------------------------------------------------------
output "azurerm_storage_account_name" {
  value       = try(azurerm_storage_account.tfe[0].name, null)
  description = "Name of TFE Azure Storage Account."
}

output "azurerm_storage_container_name" {
  value       = try(azurerm_storage_container.tfe[0].name, null)
  description = "Name of TFE Azure Storage Container."
}

output "azurerm_postgresql_flexible_server_id" {
  value       = azurerm_postgresql_flexible_server.tfe.id
  description = "ID of Azurerm PostgreSQL Flexible server."
}

output "azurerm_postgresql_flexible_server_fqdn" {
  value       = azurerm_postgresql_flexible_server.tfe.fqdn
  description = "FQDN of Azurerm PostgreSQL Flexible server."
}

