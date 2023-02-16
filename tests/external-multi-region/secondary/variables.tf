#-------------------------------------------------------------------------
# Common
#-------------------------------------------------------------------------
variable "resource_group_name" {
  type        = string
  description = "Name of Resource Group to create."
  default     = "tfe-rg"
}

variable "location" {
  type        = string
  description = "Azure region to deploy into."
}

variable "friendly_name_prefix" {
  type        = string
  description = "Friendly name prefix for unique Azure resource naming across deployments."

  validation {
    condition     = can(regex("^[[:alnum:]]+$", var.friendly_name_prefix)) && length(var.friendly_name_prefix) < 13
    error_message = "Must only contain alphanumeric characters and be less than 13 characters."
  }
}

variable "common_tags" {
  type        = map(string)
  description = "Map of common tags for taggable Azure resources."
  default     = {}
}

variable "is_government" {
  type        = bool
  description = "Define if this is a deployment in Azure Government or public."
  default     = false
}

variable "is_secondary_region" {
  type        = bool
  description = "Boolean indicating whether TFE instance deployment is for Primary region or Secondary region."
  default     = false
}

variable "tfe_resource_group_name_primary" {
  type        = string
  description = "The resource group name of the primary TFE deployment that TFE was deployed into"
  default     = null
}

variable "storage_account_name_primary" {
  type        = string
  description = "The storage account name of the TFE deployment that was already deployed"
  default     = null
}

variable "storage_container_name_primary" {
  type        = string
  description = "The storage container name of the TFE deployment that was already deployed"
  default     = null
}

variable "subnet_id_secondary" {
  type        = string
  description = "The subnet that the TFE will be deployed into the secondary region"
  default     = "null"
}

#-------------------------------------------------------------------------
# Prereqs
#-------------------------------------------------------------------------
variable "vnet_id" {
  type        = string
  description = "VNet ID where TFE resources will reside."
}

variable "lb_subnet_id" {
  type        = string
  description = "Subnet ID for TFE load balancer. Required if `load_balancing_scheme` is `internal`."
  default     = null
}

variable "vm_subnet_id" {
  type        = string
  description = "Subnet ID for TFE VMSS."
}

variable "db_subnet_id" {
  type        = string
  description = "Subnet ID for TFE PostgreSQL database."
}

variable "lb_private_ip" {
  type        = string
  description = "Static IP to assign to Azure Load Balancer. Required when `load_balancing_scheme` is `internal` (private). Must be a valid address from `lb_subnet_id`."
  default     = null
}

variable "bootstrap_sa_name" {
  type        = string
  description = "Name of existing 'Bootstrap' Blob Storage Account containing TFE prereq install files."
}

variable "bootstrap_sa_rg" {
  type        = string
  description = "Name of Resource Group where `bootstrap_sa_name` resides. If not set, Terraform will attempt to use the current TFE Resource Group."
  default     = null
}

variable "tfe_license_path" {
  type        = string
  description = "Path to TFE license file (`.rli` extension) in 'Bootstrap' Blob Storage account. Format is `<Container name>/<filename>`."
}

variable "replicated_tarball_path" {
  type        = string
  description = "Path to Replicated tarball (`replicated.tar.gz`) in 'Bootstrap' Blob Storage account. Required when `airgap_install` is `true`. Format is <Container name>/<filename>."
  default     = null
}

variable "tfe_airgap_bundle_path" {
  type        = string
  description = "Path to TFE airgap bundle in 'Bootstrap' Blob Storage account. Required when `airgap_install` is `true`. Format is <Container name>/<filename>."
  default     = null
}

variable "bootstrap_kv_name" {
  type        = string
  description = "Name of existing 'Bootstrap' Azure Key Vault containing TFE prereq install secrets and certificates."
}

variable "bootstrap_kv_rg" {
  type        = string
  description = "Name of Resource Group where `bootstrap_kv_name` resides. If not set, Terraform will attempt to use the current TFE Resource Group."
  default     = null
}

variable "tfe_cert_kv_id" {
  type        = string
  description = "ID of Azure Key Vault secret containing TFE server certificate in PEM format."
}

variable "tfe_privkey_kv_id" {
  type        = string
  description = "ID of Azure Key Vault secret containing TFE certificate private key in PEM format."
}

variable "console_password_kv_id" {
  type        = string
  description = "ID of Azure Key Vault secret named `console-password` for TFE Admin Console password."
}

variable "enc_password_kv_id" {
  type        = string
  description = "ID of Azure Key Vault secret named `enc-password` for TFE encryption password."
}

variable "ca_bundle_kv_id" {
  type        = string
  description = "Optional ID of Azure Key Vault secret containing custom CA bundle. New lines must be replaced by `\n` character prior to storing as a single-line secret."
  default     = null
}

#-------------------------------------------------------------------------
# TFE Config
#-------------------------------------------------------------------------
variable "pkg_repos_reachable_with_airgap" {
  type        = bool
  description = "Boolean to install prereq software dependencies even if airgapped. Only valid when `airgap_install` is `true`."
  default     = false
}

variable "install_docker_before" {
  type        = bool
  description = "Boolean to install docker before TFE install script is called."
  default     = false
}

variable "airgap_install" {
  type        = bool
  description = "Boolean for TFE installation method to be airgap."
  default     = false
}

variable "tfe_release_sequence" {
  type        = number
  description = "TFE application release version to install. Only valid when `airgap_install` is `false`. Leaving at `0` will default to latest but is not recommended."
  default     = 0
}

variable "tls_bootstrap_type" {
  type        = string
  description = "Defines how/where TLS/SSL is terminated. Set to `server-path` when using a layer 4 TCP load balancer to terminate at the instance-level."
  default     = "server-path"

  validation {
    condition     = var.tls_bootstrap_type == "server-path"
    error_message = "Currently the only supported value is `server-path`."
  }
}

variable "remove_import_settings_from" {
  type        = bool
  description = "Boolean to automatically delete `/etc/tfe-settings.json` config file (referred to as `ImportSettingsFrom` by Replicated) after installation."
  default     = false
}

variable "capacity_concurrency" {
  type        = string
  description = "Total concurrent Terraform Runs (Plans/Applies) allowed within TFE."
  default     = "10"
}

variable "capacity_memory" {
  type        = string
  description = "Maxium amount of memory (MB) that a Terraform Run (Plan/Apply) can consume within TFE."
  default     = "512"
}

variable "enable_active_active" {
  type        = bool
  description = "Boolean to enable TFE Active/Active and in turn deploy Redis cluster."
  default     = false
}

variable "enable_metrics_collection" {
  type        = bool
  description = "Boolean to enable internal TFE metrics collection."
  default     = true
}

variable "metrics_endpoint_enabled" {
  type        = bool
  description = "Boolean to enable the TFE metrics endpoint."
  default     = false
}

variable "metrics_endpoint_port_http" {
  type        = number
  description = "Defines the TCP port on which HTTP metrics requests will be handled."
  default     = 9090
}

variable "metrics_endpoint_port_https" {
  type        = number
  description = "Defines the TCP port on which HTTPS metrics requests will be handled."
  default     = 9091
}

variable "extra_no_proxy" {
  type        = string
  description = "A comma-separated string of hostnames or IP addresses to add to the TFE no_proxy list. Only set if a value for `http_proxy` is also set."
  default     = ""
}

variable "force_tls" {
  type        = bool
  description = "Boolean to require all internal TFE application traffic to use HTTPS by sending a 'Strict-Transport-Security' header value in responses, and marking cookies as secure. Only enable if `tls_bootstrap_type` is `server-path`."
  default     = false
}

variable "hairpin_addressing" {
  type        = bool
  description = "Boolean to enable TFE services to direct requests to the servers' internal IP address rather than the TFE hostname/FQDN. Only enable if `tls_bootstrap_type` is `server-path`."
  default     = false
}

variable "tfe_fqdn" {
  type        = string
  description = "Hostname/FQDN of TFE instance. This name should resolve to the load balancer IP address and will be how clients should access TFE."
}

variable "log_forwarding_enabled" {
  type        = bool
  description = "Boolean to enable TFE log forwarding at the application level."
  default     = false
}

variable "log_forwarding_type" {
  type        = string
  description = "Which type of log forwarding destination to configure. For any of these,`var.log_forwarding_enabled` must be set to `true`. For Blob Storage, specify `blob_storage` and supply a value for `var.logging_sa_name` and `logging_rg` for the resource group of the Storage Account; for Azure Log Analytics specify `azure_log_analytics` and `var.logging_analytics_workspace_name` and `logging_rg` for the resource group of the Log Analytics Workspace; for custom, specify `custom` and supply a valid Fluent Bit config in `var.custom_fluent_bit_config`."
  default     = "blob_storage"

  validation {
    condition     = contains(["azure_log_analytics", "blob_storage", "custom"], var.log_forwarding_type)
    error_message = "Supported values are `blob_storage`, `azure_log_analytics` or `custom`."
  }
}

variable "logging_sa_name" {
  type        = string
  description = "Name of existing 'logging' Blob Storage Account used for TFE logging."
  default     = null
}

variable "logging_storage_container_name" {
  type        = string
  description = "Name of existing 'logging' storage container used for TFE logging."
  default     = null
}

variable "logging_analytics_workspace_name" {
  type        = string
  description = "Name of existing 'logging' analytics workspace name."
  default     = null
}

variable "logging_rg" {
  type        = string
  description = "Name of Resource Group where either `logging_sa_name` or `logging_analytics_workspace_name' resides. If not set, Terraform will attempt to use the current TFE Resource Group."
  default     = null
}

variable "custom_fluent_bit_config" {
  type        = string
  description = "A custom Fluent Bit config for TFE logging."
  default     = null
}

variable "restrict_worker_metadata_access" {
  type        = bool
  description = "Boolean to block Terraform build worker containers' ability to access VM instance metadata endpoint."
  default     = false
}

variable "tbw_image" {
  type        = string
  description = "Terraform Build Worker container image to use. Set this to `custom_image` to use alternative container image."
  default     = "default_image"

  validation {
    condition     = contains(["default_image", "custom_image"], var.tbw_image)
    error_message = "Value must be `default_image` or `custom_image`."
  }
}

variable "http_proxy" {
  type        = string
  description = "Proxy address for TFE to use for outbound connections/requests."
  default     = null
}

variable "azure_use_msi" {
  type        = bool
  description = "Use a managed identity for authentication instead of a storage account key. Set to `true` to enable and `false` to disable. Defaults to `true`."
  default     = true
}

variable "azure_client_id" {
  type        = string
  description = "The client ID of the user-assigned managed identity used for authentication. Leave blank to use the system-assigned managed identity. Only used when `azure_use_msi` is `true`."
  default     = ""
}
#-------------------------------------------------------------------------
# Networking
#-------------------------------------------------------------------------
variable "availability_zones" {
  type        = set(string)
  description = "List of Azure Availability Zones to spread TFE resources across."
  default     = ["1", "2", "3"]
}

variable "load_balancing_scheme" {
  type        = string
  description = "Determines if Azure Load Balancer is exposed as `external` or `internal`."
  default     = "external"

  validation {
    condition     = anytrue([var.load_balancing_scheme == "external", var.load_balancing_scheme == "internal"])
    error_message = "Value must be `external` or `internal`."
  }
}

variable "create_dns_record" {
  type        = bool
  description = "Boolean to create Azure DNS A record with name `tfe_fqdn` resolving to load balancer IP. When `true`, `dns_zone_name` is also required."
  default     = false
}

variable "dns_zone_name" {
  type        = string
  description = "Name of existing Azure DNS zone to create DNS record in. Only valid if `create_dns_record` is `true`."
  default     = null
}

variable "dns_zone_rg" {
  type        = string
  description = "Resource Group where `dns_zone_name` resides."
  default     = null
}

#-------------------------------------------------------------------------
# Virtual Machine Scale Set (VMSS)
#-------------------------------------------------------------------------
variable "vm_count" {
  type        = number
  description = "Number of VMs to run in VMSS."
  default     = 1
}

variable "vm_sku" {
  type        = string
  description = "Azure VM SKU (size). Ensure it is compatible with the `Premium_LRS` storage account tier."
  default     = "Standard_D4s_v5"
}

variable "vm_ssh_public_key" {
  type        = string
  description = "SSH public key to associate with VMSS."
}

variable "vm_image_publisher" {
  type        = string
  description = "VMSS source image reference publisher."
  default     = "Canonical"
}

variable "vm_image_offer" {
  type        = string
  description = "VMSS source image reference offer."
  default     = "0001-com-ubuntu-server-focal"
}

variable "vm_image_sku" {
  type        = string
  description = "VMSS source image reference SKU."
  default     = "20_04-lts"
}

variable "vm_image_version" {
  type        = string
  description = "VMSS source image reference version."
  default     = "latest"
}

variable "custom_vm_image_name" {
  type        = string
  description = "Name of existing custom VM image to use instead of marketplace image."
  default     = null
}

variable "custom_vm_image_rg" {
  type        = string
  description = "Name of Resource Group where custom VM Image (`custom_vm_image_name`) resides."
  default     = null
}

#-------------------------------------------------------------------------
# PostgreSQL
#-------------------------------------------------------------------------
variable "postgres_version" {
  type        = number
  description = "PostgreSQL database version."
  default     = 14
}

variable "postgres_sku" {
  type        = string
  description = "PostgreSQL database SKU."
  default     = "GP_Standard_D2ds_v4"
}

variable "postgres_password" {
  type        = string
  description = "PostgreSQL database administrator password."

  validation {
    condition     = !can(regex("\\$", var.postgres_password))
    error_message = "The PostgreSQL password cannot contain the '$' character."
  }
}

variable "enable_postgres_ha" {
  type        = bool
  description = "Boolean to enable `ZoneRedundant` high availability with PostgreSQL database."
  default     = false
}

variable "postgres_extra_params" {
  type        = string
  description = "PostgreSQL extra parameters."
  default     = "sslmode=require"
}

variable "postgres_geo_redundant_backup_enabled" {
  type        = bool
  description = "Boolean to configure geo-redundant backup in paired region."
  default     = true
}

variable "postgres_availability_zone_primary" {
  type        = number
  description = "Number for the availability zone for the db to reside in"
  default     = 0
}

variable "postgres_availability_zone_secondary" {
  type        = number
  description = "Number for the availability zone for the db to reside in for the secondary node"
  default     = 1
}

#-------------------------------------------------------------------------
# Blob Storage
#-------------------------------------------------------------------------
variable "storage_account_cidr_allow" {
  type        = list(string)
  description = "List of CIDRs allowed to interact with Azure Blob Storage Account."
  default     = []
}

variable "account_replication_type" {
  type        = string
  description = "Defines the type of replication to use for this storage account."
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.account_replication_type)
    error_message = "Must be one of 'LRS', 'GRS', 'RAGRS', 'ZRS', 'GZRS', or 'RAGZRS'."
  }
}
