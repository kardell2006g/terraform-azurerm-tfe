#------------------------------------------------------------------------------
# Log Fowarding - Blob Storage
#------------------------------------------------------------------------------
data "azurerm_storage_account" "logging" {
  count = var.log_forwarding_enabled == true && var.log_forwarding_type == "blob_storage" ? 1 : 0

  resource_group_name = var.logging_rg == null ? azurerm_resource_group.tfe.name : var.logging_rg
  name                = var.logging_sa_name
}

data "azurerm_storage_container" "logging" {
  count = var.log_forwarding_enabled == true && var.log_forwarding_type == "blob_storage" ? 1 : 0

  name                 = var.logging_storage_container_name
  storage_account_name = var.logging_sa_name
}

#------------------------------------------------------------------------------
# Log Fowarding - Log Analytics Workspace
#------------------------------------------------------------------------------
data "azurerm_log_analytics_workspace" "logging" {
  count = var.log_forwarding_enabled == true && var.log_forwarding_type == "azure_log_analytics" ? 1 : 0

  resource_group_name = var.logging_rg == null ? azurerm_resource_group.tfe.name : var.logging_rg
  name                = var.logging_analytics_workspace_name
}

#------------------------------------------------------------------------------
# Log Fowarding arguments
#------------------------------------------------------------------------------
locals {
  fluent_bit_azure_log_analytics_args = {
    logs_analytics-workspace-id = var.log_forwarding_enabled == true && var.log_forwarding_type == "azure_log_analytics" ? data.azurerm_log_analytics_workspace.logging[0].workspace_id : null
    logs_access-key             = var.log_forwarding_enabled == true && var.log_forwarding_type == "azure_log_analytics" ? data.azurerm_log_analytics_workspace.logging[0].primary_shared_key : null
  }
  fluent_bit_azure_log_analytics_config = var.log_forwarding_enabled == true && var.log_forwarding_type == "azure_log_analytics" ? (templatefile("${path.module}/templates/fluent-bit-azure-log-analytics.conf.tpl", local.fluent_bit_azure_log_analytics_args)) : ""

  fluent_bit_blob_storage_args = {
    logs_account-name   = var.log_forwarding_enabled == true && var.log_forwarding_type == "blob_storage" ? data.azurerm_storage_account.logging[0].name : null
    logs_access-key     = var.log_forwarding_enabled == true && var.log_forwarding_type == "blob_storage" ? data.azurerm_storage_account.logging[0].primary_access_key : null
    logs_container-name = var.log_forwarding_enabled == true && var.log_forwarding_type == "blob_storage" ? data.azurerm_storage_container.logging[0].name : null
    logs_blob_endpoint  = var.log_forwarding_enabled == true && var.log_forwarding_type == "blob_storage" ? data.azurerm_storage_account.logging[0].primary_blob_endpoint : null
    is_government       = var.is_government
  }
  fluent_bit_blob_storage_config = var.log_forwarding_enabled == true && var.log_forwarding_type == "blob_storage" ? (templatefile("${path.module}/templates/fluent-bit-azure-blob.conf.tpl", local.fluent_bit_blob_storage_args)) : ""

  fluent_bit_custom_config = var.log_forwarding_type == "custom" ? var.custom_fluent_bit_config : ""

  fluent_bit_config = join("", [local.fluent_bit_azure_log_analytics_config, local.fluent_bit_blob_storage_config, local.fluent_bit_custom_config])
}

#------------------------------------------------------------------------------
# Secondary - Blob Storage
#------------------------------------------------------------------------------
data "azurerm_storage_account" "tfe" {
  count = var.is_secondary_region == true ? 1 : 0

  resource_group_name = var.tfe_resource_group_name_primary
  name                = var.storage_account_name_primary
}

data "azurerm_storage_container" "tfe" {
  count = var.is_secondary_region == true ? 1 : 0

  name                 = var.storage_container_name_primary
  storage_account_name = data.azurerm_storage_account.tfe[0].name
}

#------------------------------------------------------------------------------
# Custom Data (cloud-init) arguments
#------------------------------------------------------------------------------
locals {
  custom_data_args = {
    # used to install software package dependencies
    pkg_repos_reachable_with_airgap = var.pkg_repos_reachable_with_airgap
    install_docker_before           = var.install_docker_before

    # used for /etc/replicated.conf
    bootstrap_sa_name           = var.bootstrap_sa_name
    airgap_install              = var.airgap_install
    replicated_tarball_path     = var.replicated_tarball_path != null ? var.replicated_tarball_path : ""
    tfe_airgap_bundle_path      = var.tfe_airgap_bundle_path != null ? var.tfe_airgap_bundle_path : ""
    tfe_license_path            = var.tfe_license_path
    tfe_release_sequence        = var.tfe_release_sequence
    tls_bootstrap_type          = var.tls_bootstrap_type
    tfe_cert_kv_id              = var.tfe_cert_kv_id
    tfe_privkey_kv_id           = var.tfe_privkey_kv_id
    console_password_kv_id      = var.console_password_kv_id
    remove_import_settings_from = var.remove_import_settings_from

    # used for /etc/tfe-settings.json
    azure_account_key               = var.is_secondary_region == true ? data.azurerm_storage_account.tfe[0].primary_access_key : azurerm_storage_account.tfe[0].primary_access_key
    azure_account_name              = var.is_secondary_region == true ? data.azurerm_storage_account.tfe[0].name : azurerm_storage_account.tfe[0].name
    azure_container                 = var.is_secondary_region == true ? data.azurerm_storage_container.tfe[0].name : azurerm_storage_container.tfe[0].name
    azure_endpoint                  = var.is_government == true ? split(".blob.", azurerm_storage_account.tfe[0].primary_blob_host)[1] : ""
    azure_use_msi                   = var.azure_use_msi == true ? 1 : 0
    azure_client_id                 = var.azure_use_msi == true ? var.azure_client_id : ""
    is_government                   = var.is_government
    ca_bundle_kv_id                 = var.ca_bundle_kv_id != null ? var.ca_bundle_kv_id : ""
    capacity_concurrency            = var.capacity_concurrency
    capacity_memory                 = var.capacity_memory
    enable_metrics_collection       = var.enable_metrics_collection == true ? 1 : 0
    metrics_endpoint_enabled        = var.metrics_endpoint_enabled == true ? 1 : 0
    metrics_endpoint_port_http      = var.metrics_endpoint_port_http
    metrics_endpoint_port_https     = var.metrics_endpoint_port_https
    enc_password_kv_id              = var.enc_password_kv_id
    extra_no_proxy                  = var.extra_no_proxy
    force_tls                       = var.force_tls == true ? 1 : 0
    hairpin_addressing              = var.hairpin_addressing == true ? 1 : 0
    hostname                        = var.tfe_fqdn
    pg_dbname                       = "postgres"
    pg_extra_params                 = var.postgres_extra_params
    pg_netloc                       = "${azurerm_postgresql_flexible_server.tfe.fqdn}:5432"
    pg_password                     = azurerm_postgresql_flexible_server.tfe.administrator_password
    pg_user                         = azurerm_postgresql_flexible_server.tfe.administrator_login
    enable_active_active            = var.enable_active_active == true ? 1 : 0
    redis_host                      = var.enable_active_active == true ? azurerm_redis_cache.tfe[0].hostname : ""
    redis_pass                      = var.enable_active_active == true && var.enable_redis_authentication == true ? "${azurerm_redis_cache.tfe[0].primary_access_key}" : ""
    redis_port                      = var.enable_active_active == true ? var.redis_port : ""
    redis_use_password_auth         = var.enable_active_active == true && var.enable_redis_authentication == true ? 1 : 0
    redis_use_tls                   = var.enable_active_active == true && var.enable_redis_authentication == true ? 1 : 0
    restrict_worker_metadata_access = var.restrict_worker_metadata_access == true ? 1 : 0
    tbw_image                       = var.tbw_image
    log_forwarding_enabled          = var.log_forwarding_enabled == true ? 1 : 0
    fluent_bit_config               = local.fluent_bit_config

    # used for `install.sh` script arguments
    http_proxy = var.http_proxy != null ? var.http_proxy : ""
  }
}

#------------------------------------------------------------------------------
# Custom VM Image
#------------------------------------------------------------------------------
data "azurerm_image" "custom" {
  count = var.custom_vm_image_name == null ? 0 : 1

  name                = var.custom_vm_image_name
  resource_group_name = var.custom_vm_image_rg
}

#------------------------------------------------------------------------------
# Virtual Machine Scale Set (VMSS)
#------------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine_scale_set" "tfe" {
  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location
  name                = "${var.friendly_name_prefix}-tfe-vmss"
  instances           = var.vm_count
  sku                 = var.vm_sku
  admin_username      = "tfeadmin"
  overprovision       = false
  upgrade_mode        = "Manual"
  zone_balance        = true
  zones               = var.availability_zones
  health_probe_id     = var.load_balancer_type == "load_balancer" ? azurerm_lb_probe.app[0].id : null
  custom_data         = base64encode(templatefile("${path.module}/templates/tfe_custom_data.sh.tpl", local.custom_data_args))

  scale_in {
    rule = "OldestVM"
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.tfe.id]
  }

  admin_ssh_key {
    username   = "tfeadmin"
    public_key = var.vm_ssh_public_key
  }

  source_image_id = var.custom_vm_image_name == null ? null : data.azurerm_image.custom[0].id

  dynamic "source_image_reference" {
    for_each = var.custom_vm_image_name == null ? [true] : []

    content {
      publisher = var.vm_image_publisher
      offer     = var.vm_image_offer
      sku       = var.vm_image_sku
      version   = var.vm_image_version
    }
  }

  network_interface {
    name    = "tfe-vm-nic"
    primary = true

    ip_configuration {
      name                                         = "internal"
      primary                                      = true
      subnet_id                                    = var.vm_subnet_id
      load_balancer_backend_address_pool_ids       = var.load_balancer_type == "load_balancer" ? [azurerm_lb_backend_address_pool.tfe_servers[0].id] : null
      application_gateway_backend_address_pool_ids = var.load_balancer_type == "application_gateway" ? [tolist(azurerm_application_gateway.tfe_ag[0].backend_address_pool).0.id] : null
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  automatic_instance_repair {
    enabled      = true
    grace_period = "PT15M"

  }

  dynamic "extension" {
    for_each = var.load_balancer_type == "application_gateway" ? [1] : []

    content {
      name                       = "${var.friendly_name_prefix}-vmss-ext"
      publisher                  = "Microsoft.ManagedServices"
      type                       = "ApplicationHealthLinux"
      auto_upgrade_minor_version = true
      type_handler_version       = "1.0"
      settings = jsonencode({
        "protocol" : "https",
        "port" : 443,
        "requestPath" : "/_health_check"
      })
    }
  }

  dynamic "boot_diagnostics" {
    for_each = var.enable_boot_diagnostics == true ? [1] : []

    content {}
  }

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-vmss" },
    var.common_tags
  )
}

// Moved inside of vmss resource in order to enable automatic_instance_repair

# resource "azurerm_virtual_machine_scale_set_extension" "main" {
#   count = var.load_balancer_type == "application_gateway" ? 1 : 0

#   name                         = "${var.friendly_name_prefix}-vmss-ext"
#   virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.tfe.id
#   publisher                    = "Microsoft.ManagedServices"
#   type                         = "ApplicationHealthLinux"
#   auto_upgrade_minor_version   = true
#   type_handler_version         = "1.0"
#   settings = jsonencode({
#     "protocol" : "https",
#     "port" : 443,
#     "requestPath" : "/_health_check"
#   })
# }