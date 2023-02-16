#------------------------------------------------------------------------------
# AzureRM Client Config
#------------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

#------------------------------------------------------------------------------
# User Assigned Identity
#------------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "tfe" {
  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location
  name                = "${var.friendly_name_prefix}-tfe-msi"
}

#------------------------------------------------------------------------------
# "Bootstrap" Storage Account
#------------------------------------------------------------------------------
data "azurerm_storage_account" "bootstrap" {
  resource_group_name = var.bootstrap_sa_rg == null ? azurerm_resource_group.tfe.name : var.bootstrap_sa_rg
  name                = var.bootstrap_sa_name
}

resource "azurerm_role_assignment" "tfe_bootstrap_sa_reader" {
  scope                = data.azurerm_storage_account.bootstrap.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.tfe.principal_id
}

#------------------------------------------------------------------------------
# "Bootstrap" Key Vault
#------------------------------------------------------------------------------
data "azurerm_key_vault" "bootstrap" {
  resource_group_name = var.bootstrap_kv_rg == null ? azurerm_resource_group.tfe.name : var.bootstrap_kv_rg
  name                = var.bootstrap_kv_name
}

resource "azurerm_role_assignment" "tfe_kv_reader" {
  scope                = data.azurerm_key_vault.bootstrap.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.tfe.principal_id
}

resource "azurerm_key_vault_access_policy" "tfe_kv_reader" {
  key_vault_id = data.azurerm_key_vault.bootstrap.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.tfe.principal_id

  secret_permissions = [
    "Get",
  ]
}
#------------------------------------------------------------------------------
# "TFE" Storage Account
#------------------------------------------------------------------------------
resource "azurerm_role_assignment" "tfe_sa_owner" {
  count = var.azure_use_msi == true ? 1 : 0

  scope                = azurerm_storage_account.tfe[0].id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.tfe.principal_id
}