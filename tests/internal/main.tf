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
  features {}
}

module "tfe" {
  source = "../.."

  # --- Common --- #
  location             = var.location
  friendly_name_prefix = var.friendly_name_prefix
  common_tags          = var.common_tags
  is_government        = var.is_government

  # --- Prereqs --- #
  vnet_id                 = var.vnet_id
  lb_subnet_id            = var.lb_subnet_id
  vm_subnet_id            = var.vm_subnet_id
  db_subnet_id            = var.db_subnet_id
  lb_private_ip           = var.lb_private_ip
  bootstrap_sa_name       = var.bootstrap_sa_name
  bootstrap_sa_rg         = var.bootstrap_sa_rg
  tfe_license_path        = var.tfe_license_path
  tfe_airgap_bundle_path  = var.tfe_airgap_bundle_path
  replicated_tarball_path = var.replicated_tarball_path
  bootstrap_kv_name       = var.bootstrap_kv_name
  bootstrap_kv_rg         = var.bootstrap_kv_rg
  tfe_cert_kv_id          = var.tfe_cert_kv_id
  tfe_privkey_kv_id       = var.tfe_privkey_kv_id
  console_password_kv_id  = var.console_password_kv_id
  enc_password_kv_id      = var.enc_password_kv_id
  ca_bundle_kv_id         = var.ca_bundle_kv_id
  azure_use_msi           = var.azure_use_msi
  azure_client_id         = var.azure_client_id

  # --- TFE Config --- #
  airgap_install                  = var.airgap_install
  pkg_repos_reachable_with_airgap = var.pkg_repos_reachable_with_airgap
  tfe_fqdn                        = var.tfe_fqdn

  # --- Networking --- #
  availability_zones    = var.availability_zones
  load_balancing_scheme = var.load_balancing_scheme
  create_dns_record     = var.create_dns_record
  dns_zone_name         = var.dns_zone_name
  dns_zone_rg           = var.dns_zone_rg

  # --- Compute --- #
  vm_sku               = var.vm_sku
  vm_ssh_public_key    = var.vm_ssh_public_key
  custom_vm_image_name = var.custom_vm_image_name
  custom_vm_image_rg   = var.custom_vm_image_rg

  # --- PostgreSQL --- #
  postgres_password                     = var.postgres_password
  enable_postgres_ha                    = var.enable_postgres_ha
  postgres_geo_redundant_backup_enabled = var.postgres_geo_redundant_backup_enabled

  # --- Blob Storage --- #
  storage_account_cidr_allow = var.storage_account_cidr_allow

  # --- Active/Active --- #
  enable_active_active = var.enable_active_active
  redis_subnet_id      = var.redis_subnet_id
}