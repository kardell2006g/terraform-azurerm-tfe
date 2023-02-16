resource "azurerm_storage_account" "tfe" {
  count = var.is_secondary_region == true ? 0 : 1

  resource_group_name             = azurerm_resource_group.tfe.name
  location                        = azurerm_resource_group.tfe.location
  name                            = "${var.friendly_name_prefix}tfeblob"
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  access_tier                     = "Hot"
  account_replication_type        = var.account_replication_type
  enable_https_traffic_only       = true
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = var.sa_public_access_enabled
  allow_nested_items_to_be_public = false

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}tfeblob" },
    var.common_tags
  )
}

resource "azurerm_storage_container" "tfe" {
  count = var.is_secondary_region == true ? 0 : 1

  name                  = "tfeblob"
  storage_account_name  = azurerm_storage_account.tfe[0].name
  container_access_type = "private"

  depends_on = [
    azurerm_storage_account.tfe
  ]
}

resource "azurerm_storage_account_network_rules" "tfe" {
  storage_account_id = azurerm_storage_account.tfe[0].id

  default_action             = "Deny"
  ip_rules                   = var.storage_account_cidr_allow
  virtual_network_subnet_ids = compact([var.vm_subnet_id, var.subnet_id_secondary])
  bypass                     = ["AzureServices"]

  depends_on = [
    azurerm_storage_container.tfe
  ]
}

resource "azurerm_private_endpoint" "tfeblob" {
  name                = "${var.friendly_name_prefix}tfeblob-endpoint"
  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location
  subnet_id           = var.vm_subnet_id

  private_service_connection {
    name                           = "psc-tfe-blob"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.tfe[0].id
    subresource_names              = ["blob"]
  }

  depends_on = [
    azurerm_storage_account.tfe,
    azurerm_storage_account_network_rules.tfe
  ]

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}tfeblob-private-endpoint" },
    var.common_tags
  )
}

resource "azurerm_private_dns_zone" "tfe" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.tfe.name

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}tfeblob-private-dns-zone" },
    var.common_tags
  )
}

resource "azurerm_private_dns_zone_virtual_network_link" "tfe_network_link" {
  name                  = "${var.friendly_name_prefix}tfe-link"
  resource_group_name   = azurerm_resource_group.tfe.name
  private_dns_zone_name = azurerm_private_dns_zone.tfe.name
  virtual_network_id    = var.vnet_id

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}tfeblob-private-net-link" },
    var.common_tags
  )

  depends_on = [
    azurerm_storage_account.tfe,
    azurerm_private_dns_zone.tfe,
  ]
}

resource "azurerm_private_dns_a_record" "tfe_blob_dns" {
  name                = "${var.friendly_name_prefix}tfeblob"
  zone_name           = azurerm_private_dns_zone.tfe.name
  resource_group_name = azurerm_resource_group.tfe.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.tfeblob.private_service_connection.0.private_ip_address]

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}tfeblob-private-dns" },
    var.common_tags
  )

  depends_on = [
    azurerm_private_dns_zone.tfe,
    azurerm_private_endpoint.tfeblob
  ]

}