# TFE on Azure Accelerator

Terraform module _accelerator_ to deploy TFE on Azure. There are several different configurations and scenarios supported that are detailed in the sections below. The [Operational Mode](https://www.terraform.io/docs/enterprise/before-installing/index.html#operational-mode-decision) is _External Services_, both _online_ and _airgap_ installation methods are supported, and Active/Active support is coming soon. Prior to deploying in production, the module code should be reviewed, potentially tweaked/customized, and tested in a non-production environment.
<p>&nbsp;</p>

## Disclaimer

This Terraform module _accelerator_ is intended to be used by HashiCorp Implementation Services (IS) in tandem with customers during Professional Services engagements in order to _accelerate_, codify, and automate the deployment of Terraform Enterprise via Terraform within the customers' cloud environments. After the Professional Services engagement finishes, the customer owns the code and is responsible for maintaining and supporting it.
<p>&nbsp;</p>

## Prerequisites

- Terraform `>= 1.3.2` installed on clients/workstations
- Azure subscription w/ admin-like permissions to provision resources in via Terraform CLI
- Azure Blob Storage Account container for [AzureRM Remote State backend](https://www.terraform.io/docs/language/settings/backends/azurerm.html) is recommended but not required
- Azure VNet with the following subnets:
  - Load balancer subnet (only required if load balancing scheme is _internal_)
  - VM subnet with Service Endpoints for `Microsoft.Sql`, `Microsoft.Storage`, and `Microsoft.KeyVault`
  - Database subnet with Service Delegation for `Microsoft.DBforPostgreSQL/flexibleServers`
- "Bootstrap" Azure Blob Storage Account container containing files for automating TFE install:
  - TFE license file from Replicated (`.rli` file extension) - obtain setup instructions from CSM
  - TFE airgap bundle (only if installation method is _airgap_) - obtain setup instructions from CSM
  - `replicated.tar.gz` tarball (only if installation method is _airgap_) - download from [Replicated site](https://help.replicated.com/docs/native/customer-installations/airgapped-installations/)
- "Bootstrap" Azure Key Vault containing the following for automating TFE install:
  - TFE install secrets
  - TFE TLS/SSL certificate files
- A mechanism for shell access to Azure Linux VM (SSH key pair, bastion host, username/password, etc.)  
  
>Note: An **Azure prereqs** helper module accelerator exists [here](https://github.com/hashicorp-services/terraform-azurerm-tfe-prereqs).
<p>&nbsp;</p>

## Usage

This section contains details on configurations and settings that this module supports. For more detailed procedures on "day 2 operations" types of tasks, see the [docs](./docs/) section.

### Getting Started

See the [example scenarios](./tests) in the **tests** directory. Each scenario contains a ready-made Terraform configuration. Aside from the prereqs, all that is required to deploy is populating your own input variable values in the `terraform.tfvars.example` template that is provided in the given scenario subdirectory (and removing the `.example` file extension).
<p>&nbsp;</p>

### Deployment

If you run `terraform apply` from a network outside of the TFE VNET, Terraform will stop and report access denied when attempting to configure the storage account container. This is controlled by the variable `sa_public_access_enabled` which defaults to `false`. To avoid this, **temporarily** specify the value `sa_public_access_enabled = true` before deployment. If you receive this error during the apply, **temporarily** modify `sa_public_access_enabled = true` and enable public access to the Storage Account in the Azure UI, and run `terraform apply` again. Revery the value to false after deployment is finished.

### Installation Method

Both _online_ and _airgap_ installation methods are supported.

#### Online

For _online_ installs, specify the desired TFE version via the input variable `tfe_release_sequence`.

```hcl
tfe_release_sequence = 660
```

#### Airgap

For _aigrap_ installs, specify the following input variables for the prereq install files:

```hcl
airgap_install          = true
tfe_airgap_bundle_path  = "<Bootstrap Blob Storage Container name>/tfe-660.airgap"
replicated_tarball_path = "<Bootstrap Blob Storage Container name>/replicated.tar.gz"
```

> Note: `tfe_release_sequence` is not required for _airgap_ installs because the TFE airgap bundle determines the application version that is installed.

By default, the _custom_data_ script (cloud-init process) assumes Linux package repositories cannot be reached when `airgap_install` is `true`. If however your VM does have outbound connectivity to package repositories, you may override this assumption by setting `pkg_repos_reachable_with_airgap` to `true`. Otherwise, if your network is fully airgapped and the VM has no outbound connectivity, then the following software packages must be installed on the VM image as prerequisites before deploying:

- `jq`
- `unzip`
- `docker` (version 20.10.x with `runc` v1.0.0-rc93 or greater)
- `azure-cli` (latest version recommended)

<p>&nbsp;</p>

### Load Balancing

This module supports the Azure Load Balancer and the Application Gateway. Application Gateway is only supported using the v2 SKUs. Both _external_ (public-facing) and _internal_ (private-facing) configurations are supported. Specify the desirable configuration via the input variables `load_balancer_type` and `load_balancing_scheme`. When `load_balancing_scheme` is set to `external`, an Azure Public IP address will be provisioned and associated with the Azure Load Balancer, therefore a load balancer subnet is not required as a prerequisite (`lb_subnet_id`). On the contrary, when set to `internal`, an Azure Public IP address will not be provisioned and so a load balancer subnet (`lb_subnet_id`) is required so that it can be associated with the Azure Load Balancer. A prerequisite subnet is required when using `load_balancer_type` of `application_gateway`.
<p>&nbsp;</p>

### "Bootstrap" Storage Account

This module expects the following TFE install files to exist in an Azure Blob Storage Account container as a prerequisite:

- TFE license file
- TFE airgap bundle (_airgap_ install only)
- Replicated tarball (_airgap_ install only)

<p>&nbsp;</p>

### "Bootstrap" Key Vault

This module expects TFE certificates and install secrets to exist in an Azure Key Vault as a prerequisite.

#### TLS/SSL Certificates

The following two input variables are required preqequisites. The certificate files must first be in PEM format and then base64 encoded before being created as individual Azure Key Vault **Secrets**.

```
cat tfe_cert.pem | base64 -w 0
```

- `tfe_cert_kv_id` - Key Vault Secret Identifier of TFE server certificate
- `tfe_privkey_kv_id` - Key Vault Secret Identifier of TFE server certificate private key

The CA bundle is optional. This secret must be stored in a different format than the previous two because it will be injected into the automated install process as a value in a JSON key/value pair, and JSON does not allow raw newline characters. New lines must be replaced with `\n`.

```
sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' ./custom_ca_bundle.pem
```

- `ca_bundle_kv_id` - Key Vault Secret Identifier of custom CA bundle.

#### Secrets

There are two required input variables for the install secrets:

- `console_password_kv_id` - Key Vault Secret Identifier of TFE Admin Console password. Secret should be named `console-password` in Azure Key Vault.
- `enc_password_kv_id` - Key Vault Secret Identifier of TFE encryption password. Secret should be named `enc-password` in Azure Key Vault.

<p>&nbsp;</p>

### Postgres Database

This module provisions Azure PostgreSQL Flexible Server for the database. To enable (zone redundant) high availability, set the following input variable:

```hcl
enable_postgres_ha = true
```

The default is `false` because not all Azure regions support HA at this time.
<p>&nbsp;</p>

### Active/Active

This module supports deploying TFE in the Active/Active architecture, including external Redis and multiple nodes within the VM scale set. For more detailed instructions on the upgrade path to Active/Active, see the [Active/Active](docs/active-active.md) page. In order to enable Active/Active, specify values for the following input variables:

```hcl
enable_active_active = true
redis_subnet_id      = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-vnet/subnets/tfe-vm-subnet"
```

<p>&nbsp;</p>

### Log Forwarding

This module supports automatically configuring Terraform Enterprise to send logs to Azure Log Analytics or Azure Blob Storage using fluentbit. A custom fluentbit config file can also be passed to the module to send logs to Splunk, Loki, etc. For a list of [supported logging destinations](https://www.terraform.io/enterprise/admin/infrastructure/logging#supported-external-destinations)

To enable this functionality, specify the following input variables:

```hcl
log_forwarding_enabled = true
```

and set the `log_forwarding_type` to either `blob_storage`, `azure_log_analytics`, or `custom`.

If Blob Storage or Log Analytics is to be used, the `logging_sa_name`, `logging_storage_container_name` and `logging_analytics_workspace_name`, `logging_rg` variables will need to answered as needed well.  

If a custom fluentbit destination is going to be used, the variable `custom_fluent_bit_config` should contain the contents of a fluentbit config file. The fluentbit config file should be located in the root module, and called like this example below.

```hcl
module "tfe" {
  source = "../.."
  
  custom_fluent_bit_config = file("${path.module}/templates/fluent-bit.conf")
}
```

>Note: TFE supports configuring multiple logging destinations, but this must be done with the custom config.
<p>&nbsp;</p>

### Monitoring

The TFE has a metrics endpoint that can be used for monitoring, alerting and troubleshooting. The metrics endpoint, once enabled, opens a http & https port that a Prometheus server can scrape information from one or more TFE deployments. A service like Grafana, can then be configured to pull these metrics from Prometheus server and display them in a dashboard for displaying information like the container information like CPU utilization, Memory, I/O, network traffic, counts, and workspace runs, concurrency, etc.

This module will only enable the metrics endpoint in TFE and can customize the ports and security group rules to allow access to this endpoint. An existing or a new Prometheus server will need to be deployed that can scrape the metrics from TFE. A Grafana Server or Grafana cloud will then need to be configured to pull from the Prometheus server. There is no authentication with the metrics endpoint, so the security group rules are used to control what can access the metrics endpoint. The https port will use the instance SSL certs, so if TFE is deployed with self signed certificates, the Prometheus server will need to be configured to not use https or to allow for SSL errors.

The following variables are used for the Metrics endpoint:

- `metrics_endpoint_enabled` enables the Metric endpoint in TFE
- `metrics_endpoint_port_http` defines the http port for the endpoint. Default is `9090`
- `metrics_endpoint_port_https` defines the https port for the endpoint. Default is `9091`

This module does not contain the Network Security Group (NSG) nor the rules for the NSG, so rules to allow a Prometheus server to scrape the metrics from TFE, must be created in that terraform workspace.

More information is located here [TFE Monitoring](https://www.terraform.io/enterprise/admin/infrastructure/monitoring#terraform-enterprise-metrics) and a pre-built [Grafana dashboard](https://grafana.com/grafana/dashboards/15630) is also available.
<p>&nbsp;</p>

### Custom VM Image

If a custom VM image is preferred over using a standard marketplace image, specify values for the following input variables:

```hcl
custom_vm_image_name = "<my-custom-rhel-8-4>"
custom_vm_image_rg   = "<my-custom-image-rg>"
```

<p>&nbsp;</p>

### Cross Region Diaster Recovery

This Module supports building out TFE with failover between regions. Please see the [README.md](tests/external-multi-region/README.md) for details and examples. Both `External` and `Internal` are supported, however the example is just showing `External`
<p>&nbsp;</p>


### Troubleshooting

By default the Virtual Machine Scale Set has `enable_boot_diagnostics` enabled which will enable the Serial Console and Boot diagnostics in the Azure Portal. These can be used to monitor the progress of the install (user_data script/cloud-init process). Alternatively, using SSH (or other similarly method of connectivity) into the VM instance and run journalctl -xu cloud-final -f to tail the logs (or remove the -f if the cloud-init process has finished). If the operating system is Ubuntu, logs can also be viewed via tail -f /var/log/cloud-init-output.log.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3.2 |
| azurerm | >= 3.33.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 3.33.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_application_gateway.tfe_ag](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway) | resource |
| [azurerm_dns_a_record.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_a_record) | resource |
| [azurerm_dns_a_record.tfe_app_gw](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_a_record) | resource |
| [azurerm_key_vault_access_policy.tfe_app_gw](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_access_policy) | resource |
| [azurerm_key_vault_access_policy.tfe_kv_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_access_policy) | resource |
| [azurerm_lb.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb) | resource |
| [azurerm_lb_backend_address_pool.tfe_servers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_backend_address_pool) | resource |
| [azurerm_lb_probe.app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_probe) | resource |
| [azurerm_lb_probe.console](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_probe) | resource |
| [azurerm_lb_rule.app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_rule) | resource |
| [azurerm_lb_rule.console](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_rule) | resource |
| [azurerm_linux_virtual_machine_scale_set.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) | resource |
| [azurerm_postgresql_flexible_server.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server) | resource |
| [azurerm_postgresql_flexible_server_configuration.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_configuration) | resource |
| [azurerm_private_dns_a_record.tfe_blob_dns](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_a_record) | resource |
| [azurerm_private_dns_zone.postgres](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.postgres](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_dns_zone_virtual_network_link.tfe_network_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.tfeblob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_public_ip.tfe_app_gw_pip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_public_ip.tfe_lb](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_redis_cache.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/redis_cache) | resource |
| [azurerm_resource_group.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.tfe_bootstrap_sa_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.tfe_kv_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.tfe_sa_owner](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_account.tfe_redis_storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_account_network_rules.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account_network_rules) | resource |
| [azurerm_storage_container.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_user_assigned_identity.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_user_assigned_identity.tfe_ag_msi](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_dns_zone.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/dns_zone) | data source |
| [azurerm_image.custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/image) | data source |
| [azurerm_key_vault.bootstrap](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_log_analytics_workspace.logging](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/log_analytics_workspace) | data source |
| [azurerm_storage_account.bootstrap](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account) | data source |
| [azurerm_storage_account.logging](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account) | data source |
| [azurerm_storage_account.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account) | data source |
| [azurerm_storage_container.logging](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_container) | data source |
| [azurerm_storage_container.tfe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_container) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| account\_replication\_type | Defines the type of replication to use for this storage account. | `string` | `"LRS"` | no |
| airgap\_install | Boolean for TFE installation method to be airgap. | `bool` | `false` | no |
| app\_gw\_enable\_http2 | Determine if HTTP2 enabled on Application Gateway | `bool` | `true` | no |
| app\_gw\_firewall\_mode | The Web Application Firewall mode (Detection or Prevention) | `string` | `"Prevention"` | no |
| app\_gw\_private\_ip | (optional) Private IP address to use for LB/AG endpoint | `string` | `null` | no |
| app\_gw\_request\_routing\_rule\_minimum\_priority | The minimum priority for request routing rule. Lower priotity numbered rules take precedence over higher priotity number rules. | `number` | `1000` | no |
| app\_gw\_sku\_capacity | The Capacity of the SKU to use for Application Gateway (1 to 125) | `number` | `2` | no |
| app\_gw\_sku\_name | The Name of the SKU to use for Application Gateway, Standard\_v2 or WAF\_v2 accepted | `string` | `"Standard_v2"` | no |
| app\_gw\_sku\_tier | The Tier of the SKU to use for Application Gateway, Standard\_v2 or WAF\_v2 accepted | `string` | `"Standard_v2"` | no |
| app\_gw\_waf\_file\_upload\_limit\_mb | The File Upload Limit in MB. Accepted values are in the range 1MB to 750MB for the WAF\_v2 SKU, and 1MB to 500MB for all other SKUs. Defaults to 100MB. | `number` | `100` | no |
| app\_gw\_waf\_max\_request\_body\_size\_kb | The Maximum Request Body Size in KB. Accepted values are in the range 1KB to 128KB. Defaults to 128KB. | `number` | `128` | no |
| app\_gw\_waf\_rule\_set\_version | The Version of the Rule Set used for this Web Application Firewall. Possible values are 2.2.9, 3.0, and 3.1. | `string` | `"3.1"` | no |
| availability\_zones | List of Azure Availability Zones to spread TFE resources across. | `set(string)` | <pre>[<br>  "1",<br>  "2",<br>  "3"<br>]</pre> | no |
| azure\_client\_id | The client ID of the user-assigned managed identity used for authentication. Leave blank to use the system-assigned managed identity. Only used when `azure_use_msi` is `true`. | `string` | `""` | no |
| azure\_use\_msi | Use a managed identity for authentication instead of a storage account key. Set to `true` to enable and `false` to disable. Defaults to `true`. | `bool` | `true` | no |
| bootstrap\_kv\_name | Name of existing 'Bootstrap' Azure Key Vault containing TFE prereq install secrets and certificates. | `string` | n/a | yes |
| bootstrap\_kv\_rg | Name of Resource Group where `bootstrap_kv_name` resides. If not set, Terraform will attempt to use the current TFE Resource Group. | `string` | `null` | no |
| bootstrap\_sa\_name | Name of existing 'Bootstrap' Blob Storage Account containing TFE prereq install files. | `string` | n/a | yes |
| bootstrap\_sa\_rg | Name of Resource Group where `bootstrap_sa_name` resides. If not set, Terraform will attempt to use the current TFE Resource Group. | `string` | `null` | no |
| ca\_bundle\_kv\_id | Optional ID of Azure Key Vault secret containing custom CA bundle. New lines must be replaced by `<br>` character prior to storing as a single-line secret. | `string` | `null` | no |
| ca\_certificate\_secret | A Key Vault secret which contains the Base64 encoded version of a PEM encoded public certificate of a<br>certificate authority (CA) to be trusted by the Application Gateway. | <pre>object({<br>    name  = string<br>    value = string<br>  })</pre> | <pre>{<br>  "name": "",<br>  "value": ""<br>}</pre> | no |
| capacity\_concurrency | Total concurrent Terraform Runs (Plans/Applies) allowed within TFE. | `string` | `"10"` | no |
| capacity\_memory | Maxium amount of memory (MB) that a Terraform Run (Plan/Apply) can consume within TFE. | `string` | `"512"` | no |
| certificate | The Azure Key Vault Certificate for the Application Gateway | <pre>object({<br>    key_vault_id = string<br>    name         = string<br>    secret_id    = string<br>  })</pre> | <pre>{<br>  "key_vault_id": "",<br>  "name": "",<br>  "secret_id": ""<br>}</pre> | no |
| common\_tags | Map of common tags for taggable Azure resources. | `map(string)` | `{}` | no |
| console\_password\_kv\_id | ID of Azure Key Vault secret named `console-password` for TFE Admin Console password. | `string` | n/a | yes |
| create\_dns\_record | Boolean to create Azure DNS A record with name `tfe_fqdn` resolving to load balancer IP. When `true`, `dns_zone_name` is also required. | `bool` | `false` | no |
| custom\_fluent\_bit\_config | A custom Fluent Bit config for TFE logging. | `string` | `null` | no |
| custom\_vm\_image\_name | Name of existing custom VM image to use instead of marketplace image. | `string` | `null` | no |
| custom\_vm\_image\_rg | Name of Resource Group where custom VM Image (`custom_vm_image_name`) resides. | `string` | `null` | no |
| db\_subnet\_id | Subnet ID for TFE PostgreSQL database. | `string` | n/a | yes |
| dns\_zone\_name | Name of existing Azure DNS zone to create DNS record in. Only valid if `create_dns_record` is `true`. | `string` | `null` | no |
| dns\_zone\_rg | Resource Group where `dns_zone_name` resides. | `string` | `null` | no |
| enable\_active\_active | Boolean to enable TFE Active/Active and in turn deploy Redis cluster. | `bool` | `false` | no |
| enable\_boot\_diagnostics | Enable boot diagnostics for instances in the VMSS | `bool` | `true` | no |
| enable\_metrics\_collection | Boolean to enable internal TFE metrics collection. | `bool` | `true` | no |
| enable\_non\_ssl\_port | Whether or not non-ssl can be used. Must be true if authentication is false. | `bool` | `false` | no |
| enable\_postgres\_ha | Boolean to enable `ZoneRedundant` high availability with PostgreSQL database. | `bool` | `false` | no |
| enable\_redis\_authentication | Whether or not to enable authentication to the redis cache. If set to false, the Redis instance will be accessible without authentication. | `bool` | `true` | no |
| enc\_password\_kv\_id | ID of Azure Key Vault secret named `enc-password` for TFE encryption password. | `string` | n/a | yes |
| extra\_no\_proxy | A comma-separated string of hostnames or IP addresses to add to the TFE no\_proxy list. Only set if a value for `http_proxy` is also set. | `string` | `""` | no |
| force\_tls | Boolean to require all internal TFE application traffic to use HTTPS by sending a 'Strict-Transport-Security' header value in responses, and marking cookies as secure. Only enable if `tls_bootstrap_type` is `server-path`. | `bool` | `false` | no |
| friendly\_name\_prefix | Friendly name prefix for unique Azure resource naming across deployments. | `string` | n/a | yes |
| hairpin\_addressing | Boolean to enable TFE services to direct requests to the servers' internal IP address rather than the TFE hostname/FQDN. Only enable if `tls_bootstrap_type` is `server-path`. | `bool` | `true` | no |
| http\_proxy | Proxy address for TFE to use for outbound connections/requests. | `string` | `null` | no |
| install\_docker\_before | Boolean to install docker before TFE install script is called. | `bool` | `false` | no |
| is\_government | Define if this is a deployment in Azure Government or public. | `bool` | `false` | no |
| is\_secondary\_region | Boolean indicating whether TFE instance deployment is for Primary region or Secondary region. | `bool` | `false` | no |
| lb\_private\_ip | Static IP to assign to Azure Load Balancer. Required when `load_balancing_scheme` is `internal` (private). Must be a valid address from `lb_subnet_id`. | `string` | `null` | no |
| lb\_subnet\_cidr | Public subnet CIDR range for Bastion | `string` | `""` | no |
| lb\_subnet\_id | Subnet ID for TFE load balancer. Required if `load_balancing_scheme` is `internal`. | `string` | `null` | no |
| load\_balancer\_type | Expected value of 'application\_gateway' or 'load\_balancer' | `string` | `"load_balancer"` | no |
| load\_balancing\_scheme | Determines if Azure Load Balancer is exposed as `external` or `internal`. | `string` | `"external"` | no |
| location | Azure region to deploy into. | `string` | `"East US 2"` | no |
| log\_forwarding\_enabled | Boolean to enable TFE log forwarding at the application level. | `bool` | `false` | no |
| log\_forwarding\_type | Which type of log forwarding destination to configure. For any of these,`var.log_forwarding_enabled` must be set to `true`. For Blob Storage, specify `blob_storage` and supply a value for `var.logging_sa_name` and `logging_rg` for the resource group of the Storage Account; for Azure Log Analytics specify `azure_log_analytics` and `var.logging_analytics_workspace_name` and `logging_rg` for the resource group of the Log Analytics Workspace; for custom, specify `custom` and supply a valid Fluent Bit config in `var.custom_fluent_bit_config`. | `string` | `"blob_storage"` | no |
| logging\_analytics\_workspace\_name | Name of existing 'logging' analytics workspace name. | `string` | `null` | no |
| logging\_rg | Name of Resource Group where either `logging_sa_name` or `logging_analytics_workspace_name' resides. If not set, Terraform will attempt to use the current TFE Resource Group.` | `string` | `null` | no |
| logging\_sa\_name | Name of existing 'logging' Blob Storage Account used for TFE logging. | `string` | `null` | no |
| logging\_storage\_container\_name | Name of existing 'logging' storage container used for TFE logging. | `string` | `null` | no |
| metrics\_endpoint\_enabled | Boolean to enable the TFE metrics endpoint. | `bool` | `false` | no |
| metrics\_endpoint\_port\_http | Defines the TCP port on which HTTP metrics requests will be handled. | `number` | `9090` | no |
| metrics\_endpoint\_port\_https | Defines the TCP port on which HTTPS metrics requests will be handled. | `number` | `9091` | no |
| pkg\_repos\_reachable\_with\_airgap | Boolean to install prereq software dependencies even if airgapped. Only valid when `airgap_install` is `true`. | `bool` | `false` | no |
| postgres\_availability\_zone\_primary | Number for the availability zone for the db to reside in | `number` | `1` | no |
| postgres\_availability\_zone\_secondary | Number for the availability zone for the db to reside in for the secondary node | `number` | `2` | no |
| postgres\_extra\_params | PostgreSQL extra parameters. | `string` | `"sslmode=require"` | no |
| postgres\_geo\_redundant\_backup\_enabled | Boolean to configure geo-redundant backup in paired region. | `bool` | `true` | no |
| postgres\_password | PostgreSQL database administrator password. | `string` | n/a | yes |
| postgres\_sku | PostgreSQL database SKU. | `string` | `"GP_Standard_D2ds_v4"` | no |
| postgres\_version | PostgreSQL database version. | `number` | `14` | no |
| redis\_capacity | The size of the Redis cache to deploy. Valid values for a SKU family of C (Basic/Standard) are 0, 1, 2, 3, 4, 5, 6, and for P (Premium) family are 1, 2, 3, 4. | `number` | `1` | no |
| redis\_family | The SKU family/pricing group to use. Valid values are C (for Basic/Standard SKU family) and P (for Premium). | `string` | `"P"` | no |
| redis\_min\_tls\_version | The Minimum TLS version to use when SSL authentication is used. | `string` | `"1.2"` | no |
| redis\_port | The port to access redis on. If ssl only access is enabled, the default port is 6380. The non-ssl defualt port is 6379. | `string` | `"6380"` | no |
| redis\_public\_network\_access | Whether or not public network access is allowed for this Redis Cache. | `bool` | `false` | no |
| redis\_rdb\_backup\_enabled | Enable or disable Redis Database Backup (Creates point in time snapshots of dataset). | `bool` | `true` | no |
| redis\_rdb\_backup\_frequency | The Backup Frequency in Minutes. Only supported on Premium SKUs. Possible values are: 15, 30, 60, 360, 720 and 1440. | `number` | `1440` | no |
| redis\_rdb\_backup\_max\_snapshot\_count | The maximum number of snapshots to create as a backup. Only supported for Premium SKUs. | `number` | `1` | no |
| redis\_sku\_name | The SKU of Redis to use. Possible values are Basic, Standard, and Premium. | `string` | `"Premium"` | no |
| redis\_subnet\_id | Network subnet id for redis. | `string` | `null` | no |
| redis\_version | Redis version. Only major version needed. Valid Values are 4 and 6. | `number` | `6` | no |
| remove\_import\_settings\_from | Boolean to automatically delete `/etc/tfe-settings.json` config file (referred to as `ImportSettingsFrom` by Replicated) after installation. | `bool` | `false` | no |
| replicated\_tarball\_path | Path to Replicated tarball (`replicated.tar.gz`) in 'Bootstrap' Blob Storage account. Required when `airgap_install` is `true`. Format is <Container name>/<filename>. | `string` | `null` | no |
| resource\_group\_name | Name of Resource Group to create. | `string` | `"tfe-rg"` | no |
| restrict\_worker\_metadata\_access | Boolean to block Terraform build worker containers' ability to access VM instance metadata endpoint. | `bool` | `false` | no |
| sa\_public\_access\_enabled | Enable or disable public access on the TFE Storage Account. | `bool` | `false` | no |
| storage\_account\_cidr\_allow | List of CIDRs allowed to interact with Azure Blob Storage Account. | `list(string)` | `[]` | no |
| storage\_account\_name\_primary | The storage account name of the TFE deployment that was already deployed | `string` | `null` | no |
| storage\_container\_name\_primary | The storage container name of the TFE deployment that was already deployed | `string` | `null` | no |
| subnet\_id\_secondary | The subnet that the TFE will be deployed into the secondary region | `string` | `null` | no |
| tbw\_image | Terraform Build Worker container image to use. Set this to `custom_image` to use alternative container image. | `string` | `"default_image"` | no |
| tfe\_airgap\_bundle\_path | Path to TFE airgap bundle in 'Bootstrap' Blob Storage account. Required when `airgap_install` is `true`. Format is <Container name>/<filename>. | `string` | `null` | no |
| tfe\_cert\_kv\_id | ID of Azure Key Vault secret containing TFE server certificate in PEM format. | `string` | n/a | yes |
| tfe\_fqdn | Hostname/FQDN of TFE instance. This name should resolve to the load balancer IP address and will be how clients should access TFE. | `string` | n/a | yes |
| tfe\_license\_path | Path to TFE license file (`.rli` extension) in 'Bootstrap' Blob Storage account. Format is `<Container name>/<filename>`. | `string` | n/a | yes |
| tfe\_privkey\_kv\_id | ID of Azure Key Vault secret containing TFE certificate private key in PEM format. | `string` | n/a | yes |
| tfe\_release\_sequence | TFE application release version to install. Only valid when `airgap_install` is `false`. Leaving at `0` will default to latest but is not recommended. | `number` | `0` | no |
| tfe\_resource\_group\_name\_primary | The resource group name of the primary TFE deployment that TFE was deployed into | `string` | `null` | no |
| tls\_bootstrap\_type | Defines how/where TLS/SSL is terminated. Set to `server-path` when using a layer 4 TCP load balancer to terminate at the instance-level. | `string` | `"server-path"` | no |
| vm\_count | Number of VMs to run in VMSS. | `number` | `1` | no |
| vm\_image\_offer | VMSS source image reference offer. | `string` | `"0001-com-ubuntu-server-focal"` | no |
| vm\_image\_publisher | VMSS source image reference publisher. | `string` | `"Canonical"` | no |
| vm\_image\_sku | VMSS source image reference SKU. | `string` | `"20_04-lts"` | no |
| vm\_image\_version | VMSS source image reference version. | `string` | `"latest"` | no |
| vm\_sku | Azure VM SKU (size). Ensure it is compatible with the `Premium_LRS` storage account tier. | `string` | `"Standard_D4s_v5"` | no |
| vm\_ssh\_public\_key | SSH public key to associate with VMSS. | `string` | n/a | yes |
| vm\_subnet\_id | Subnet ID for TFE VMSS. | `string` | n/a | yes |
| vnet\_id | VNet ID where TFE resources will reside. | `string` | n/a | yes |