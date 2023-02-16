#------------------------------------------------------------------------------
# PostgreSQL Private DNS Zone
#------------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "postgres" {
  resource_group_name = azurerm_resource_group.tfe.name
  name                = var.is_government == true ? "${var.friendly_name_prefix}-tfe.postgres.database.usgovcloudapi.net" : "${var.friendly_name_prefix}-tfe.postgres.database.azure.com"
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  resource_group_name   = azurerm_resource_group.tfe.name
  name                  = "${var.friendly_name_prefix}-tfe-postgres-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = var.vnet_id
}

#------------------------------------------------------------------------------
# PostgreSQL Flexible Server
#------------------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server" "tfe" {

  resource_group_name          = var.is_secondary_region == true ? var.tfe_resource_group_name_primary : azurerm_resource_group.tfe.name
  location                     = azurerm_resource_group.tfe.location
  name                         = "${var.friendly_name_prefix}-tfe-postgres-db"
  version                      = var.postgres_version
  sku_name                     = var.postgres_sku
  storage_mb                   = "65536"
  delegated_subnet_id          = var.db_subnet_id
  private_dns_zone_id          = azurerm_private_dns_zone.postgres.id
  zone                         = var.postgres_availability_zone_primary
  administrator_login          = "tfe"
  administrator_password       = var.postgres_password
  backup_retention_days        = 35
  geo_redundant_backup_enabled = var.postgres_geo_redundant_backup_enabled
  create_mode                  = "Default"

  dynamic "high_availability" {
    for_each = var.enable_postgres_ha == true ? [1] : []

    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.postgres_availability_zone_secondary
    }
  }

  maintenance_window {
    day_of_week  = 0
    start_hour   = 0
    start_minute = 0
  }

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-postgres-db" },
    var.common_tags
  )

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres
  ]

  # We ignore the create mode change, as the Azurerm provider and sdk don't support GeoRestore at this time
  lifecycle {
    ignore_changes = [
      create_mode,
    ]
  }

}

resource "azurerm_postgresql_flexible_server_configuration" "tfe" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.tfe.id
  value     = "CITEXT,HSTORE,UUID-OSSP"
}