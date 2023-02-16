#------------------------------------------------------------------------------
# TFE URLs
#------------------------------------------------------------------------------
output "url" {
  value       = module.tfe.url
  description = "URL of TFE application based on `tfe_fqdn` input."
}

output "admin_console_url" {
  value       = module.tfe.admin_console_url
  description = "URL of TFE (Replicated) Admin Console based on `tfe_fqdn` input."
}

#------------------------------------------------------------------------------
# External Services
#------------------------------------------------------------------------------
output "azurerm_storage_account_name" {
  value       = module.tfe.azurerm_storage_account_name
  description = "Name of TFE Azure Storage Account."
}

output "azurerm_storage_container_name" {
  value       = module.tfe.azurerm_storage_container_name
  description = "Name of TFE Azure Storage Container."
}

output "azurerm_postgresql_flexible_server_id" {
  value       = module.tfe.azurerm_postgresql_flexible_server_id
  description = "ID of Azurerm PostgreSQL Flexible server."
}

output "azurerm_postgresql_flexible_server_fqdn" {
  value       = module.tfe.azurerm_postgresql_flexible_server_fqdn
  description = "FQDN of Azurerm PostgreSQL Flexible server."
}

