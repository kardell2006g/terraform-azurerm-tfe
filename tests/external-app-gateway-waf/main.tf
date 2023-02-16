
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.33.0"
    }
  }
}

provider "azurerm" {
  environment = "public"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "tfe" {
  source = "../.."

  # --- Common --- #
  location             = var.location
  friendly_name_prefix = var.friendly_name_prefix
  common_tags          = var.common_tags
  is_government        = var.is_government

  # --- Prereqs --- #
  vnet_id                = var.vnet_id
  vm_subnet_id           = var.vm_subnet_id
  db_subnet_id           = var.db_subnet_id
  lb_subnet_id           = var.lb_subnet_id
  bootstrap_sa_name      = var.bootstrap_sa_name
  bootstrap_sa_rg        = var.bootstrap_sa_rg
  tfe_license_path       = var.tfe_license_path
  bootstrap_kv_name      = var.bootstrap_kv_name
  bootstrap_kv_rg        = var.bootstrap_kv_rg
  tfe_cert_kv_id         = var.tfe_cert_kv_id
  tfe_privkey_kv_id      = var.tfe_privkey_kv_id
  console_password_kv_id = var.console_password_kv_id
  enc_password_kv_id     = var.enc_password_kv_id
  ca_bundle_kv_id        = var.ca_bundle_kv_id
  azure_use_msi          = var.azure_use_msi
  azure_client_id        = var.azure_client_id

  # --- TFE Config --- #
  tfe_release_sequence = var.tfe_release_sequence
  tfe_fqdn             = var.tfe_fqdn
  hairpin_addressing   = var.hairpin_addressing

  # --- Networking --- #
  availability_zones                           = var.availability_zones
  load_balancing_scheme                        = var.load_balancing_scheme
  load_balancer_type                           = var.load_balancer_type
  app_gw_enable_http2                          = var.app_gw_enable_http2
  app_gw_sku_name                              = var.app_gw_sku_name
  app_gw_sku_tier                              = var.app_gw_sku_tier
  app_gw_sku_capacity                          = var.app_gw_sku_capacity
  app_gw_request_routing_rule_minimum_priority = var.app_gw_request_routing_rule_minimum_priority
  app_gw_waf_file_upload_limit_mb              = var.app_gw_waf_file_upload_limit_mb
  app_gw_firewall_mode                         = var.app_gw_firewall_mode
  app_gw_waf_max_request_body_size_kb          = var.app_gw_waf_max_request_body_size_kb
  app_gw_waf_rule_set_version                  = var.app_gw_waf_rule_set_version
  app_gw_private_ip                            = var.app_gw_private_ip
  certificate                                  = var.certificate
  ca_certificate_secret                        = var.ca_certificate_secret
  lb_subnet_cidr                               = var.lb_subnet_cidr
  create_dns_record                            = var.create_dns_record
  dns_zone_name                                = var.dns_zone_name
  dns_zone_rg                                  = var.dns_zone_rg

  # --- Compute --- #
  vm_sku            = var.vm_sku
  vm_ssh_public_key = var.vm_ssh_public_key

  # --- PostgreSQL --- #
  postgres_password                     = var.postgres_password
  enable_postgres_ha                    = var.enable_postgres_ha
  postgres_geo_redundant_backup_enabled = var.postgres_geo_redundant_backup_enabled

  # --- Blob Storage --- #
  storage_account_cidr_allow = var.storage_account_cidr_allow
  sa_public_access_enabled   = var.sa_public_access_enabled
}
