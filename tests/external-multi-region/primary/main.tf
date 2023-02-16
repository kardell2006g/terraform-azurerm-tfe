
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

module "tfe_primary" {
  source = "../../.."

  # --- Common --- #
  location             = var.location
  friendly_name_prefix = var.friendly_name_prefix
  common_tags          = var.common_tags
  is_government        = var.is_government

  # --- Prereqs --- #
  vnet_id                = var.vnet_id
  vm_subnet_id           = var.vm_subnet_id
  db_subnet_id           = var.db_subnet_id
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

  # --- Secondary --- #
  subnet_id_secondary = var.subnet_id_secondary

  # --- TFE Config --- #
  tfe_release_sequence = var.tfe_release_sequence
  tfe_fqdn             = var.tfe_fqdn
  hairpin_addressing   = var.hairpin_addressing

  # --- Networking --- #
  availability_zones    = var.availability_zones
  load_balancing_scheme = var.load_balancing_scheme
  create_dns_record     = var.create_dns_record
  dns_zone_name         = var.dns_zone_name
  dns_zone_rg           = var.dns_zone_rg

  # --- Compute --- #
  vm_sku            = var.vm_sku
  vm_ssh_public_key = var.vm_ssh_public_key

  # --- PostgreSQL --- #
  postgres_password                     = var.postgres_password
  enable_postgres_ha                    = var.enable_postgres_ha
  postgres_geo_redundant_backup_enabled = var.postgres_geo_redundant_backup_enabled
  postgres_availability_zone_primary    = var.postgres_availability_zone_primary

  # --- Blob Storage --- #
  storage_account_cidr_allow = var.storage_account_cidr_allow
  account_replication_type   = var.account_replication_type
}