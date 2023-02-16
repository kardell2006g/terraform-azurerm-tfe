#-------------------------------------------------------------------------
# Storage Account for Redis backup
#-------------------------------------------------------------------------
resource "azurerm_storage_account" "tfe_redis_storage_account" {
  count = var.enable_active_active && var.redis_rdb_backup_enabled == true ? 1 : 0

  name                      = "${var.friendly_name_prefix}tferedisrdb"
  resource_group_name       = azurerm_resource_group.tfe.name
  location                  = azurerm_resource_group.tfe.location
  account_kind              = "StorageV2"
  account_tier              = "Standard"
  access_tier               = "Hot"
  account_replication_type  = var.account_replication_type
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-redis-backup-sa" },
    var.common_tags
  )
}

#-------------------------------------------------------------------------
# Redis Cache
#-------------------------------------------------------------------------
resource "azurerm_redis_cache" "tfe" {
  count = var.enable_active_active ? 1 : 0

  name                = "${var.friendly_name_prefix}-tfe-redis"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name

  subnet_id = var.redis_subnet_id
  capacity  = var.redis_capacity
  family    = var.redis_family
  sku_name  = var.redis_sku_name

  enable_non_ssl_port           = var.enable_non_ssl_port
  minimum_tls_version           = var.redis_min_tls_version
  public_network_access_enabled = var.redis_public_network_access
  redis_version                 = var.redis_version
  zones                         = var.availability_zones

  redis_configuration {
    enable_authentication         = var.enable_redis_authentication
    rdb_backup_enabled            = var.redis_rdb_backup_enabled
    rdb_storage_connection_string = var.redis_rdb_backup_enabled == true ? "${azurerm_storage_account.tfe_redis_storage_account[0].primary_blob_connection_string}" : ""
    rdb_backup_frequency          = var.redis_rdb_backup_enabled == true ? "${var.redis_rdb_backup_frequency}" : ""
    rdb_backup_max_snapshot_count = var.redis_rdb_backup_enabled == true ? "${var.redis_rdb_backup_max_snapshot_count}" : ""
  }

  lifecycle {
    ignore_changes = [
      redis_configuration[0].rdb_backup_frequency,
      redis_configuration[0].rdb_backup_max_snapshot_count,
      redis_configuration[0].rdb_storage_connection_string,
    ]
  }

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-redis" },
    var.common_tags
  )
}