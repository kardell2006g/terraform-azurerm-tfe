# TFE on Azure - External (Public Facing) Application Gateway WAF_v2

This scenario deploys TFE with an Application Gateway WAF_v2 that has a public IP and is external-facing. This use case is good for users whose VCS and/or CI/CD tooling is a hosted SaaS. This scenario leverages the _airgap_ installation method, however _online_ would also work fine.

## Usage

```hcl
# --- Common --- #
location             = "East US"
friendly_name_prefix = "CloudTeam"
common_tags = {
  "App"       = "TFE"
  "Env"       = "test"
  "Terraform" = "cli"
  "Owner"     = "YourName"
}

# --- Prereqs --- #
vnet_id      = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-vnet"
vm_subnet_id = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-vm-subnet"
db_subnet_id = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-db-subnet"
lb_subnet_id = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-lb-subnet"

bootstrap_sa_name       = "mytfebootstrapsa"
bootstrap_sa_rg         = "tfe-prereqs-rg"
tfe_license_path        = "bootstrap/tfe-license.rli"
replicated_tarball_path = "bootstrap/replicated-2.54.0.tar.gz"
tfe_airgap_bundle_path  = "bootstrap/TFE-659.airgap"

bootstrap_kv_name      = "my-tfe-bootstrap-kv"
bootstrap_kv_rg        = "tfe-prereqs-rg"
tfe_cert_kv_id         = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/tfe--fullchain-cert/00000000000000000000000000000000"
tfe_privkey_kv_id      = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/tfe-privkey/11111111111111111111111111111111"
ca_bundle_kv_id        = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/tfe-ca-bundle/2222222222222222222222222222222"
console_password_kv_id = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/console-password/3333333333333333333333333333"
enc_password_kv_id     = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/enc-password/44444444444444444444444444444444"


# --- TFE Config --- #
tfe_fqdn = "my-tfe.azure.example.com"

# --- Networking --- #
availability_zones                                  = ["1", "2", "3"]
load_balancing_scheme                               = "external"
load_balancer_type                                  = "application_gateway"
app_gw_enable_http2                          = "true"
app_gw_sku_name                              = "WAF_v2"
app_gw_sku_tier                              = "WAF_v2"
app_gw_sku_capacity                          = "1"
app_gw_request_routing_rule_minimum_priority = 1000
app_gw_waf_file_upload_limit_mb              = 100
app_gw_firewall_mode                     = "Prevention"
app_gw_waf_rule_set_version                  = "3.1"
app_gw_private_ip                                   = "10.0.1.123"
lb_subnet_cidr                                      = "10.0.1.0/24"

certificate = {
  key_vault_id = "/subscriptions/000000000000000000000000/resourceGroups/tfe-prereqs-rg/providers/Microsoft.KeyVault/vaults/tfe-fullchain-pfx-cert"
  name         = "tfe-full-chain-pfx-cert"
  secret_id    = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/tfe-full-chain-pfx-cert/11111111111111111111111111111111"
}

ca_certificate_secret = {
  name  = "tfe-root-ca-cert"
  value = <<EOF
  "-----BEGIN CERTIFICATE-----
...abcdefghijklmnopqrstuvwxyz123456
789123456abcdefghijklmnospqrstuv...
-----END CERTIFICATE-----"
EOF
}

create_dns_record = true
dns_zone_name         = "azure.example.com"
dns_zone_rg           = "tfe-prereqs-rg"

# --- Compute --- #
vm_ssh_public_key = "ssh-rsa ThisIsMySSHPublicKey== someone@example-abcdefg1234567"

# --- PostgreSQL --- #
postgres_password                     = "Postgr3sPassw0rd!"
enable_postgres_ha                    = true #if supported in Azure region
postgres_geo_redundant_backup_enabled = true 

# --- Blob Storage --- #
storage_account_cidr_allow = ["1.2.3.4"]
```

## Supported Application Gateway SKUs

This module only supports the use of the `Standard_v2` or `WAF_v2` SKU by specifying the variables `app_gw_sku_name`

## Networking

In order for the Application Gateway and TFE to function properly, certain networking requirements must be taken into account.

### Network Security Groups

- The NSG on your Application Gateway Subnet must allow:
  - Inbound 65200-65535 TCP from GatewayManager
  - Inbound 443 TCP from your NAT GW IP Address attached to your TFE VM subnet
  - Outbound 443 TCP from the APP GW subnet to the TFE VM subnet
  - Outbound 8800 TCP from the APP GW subnet to the TFE VM subnet

- The NSG on your TFE VM subnet must allow:
  - Inbound 443 TCP from your APP GW subnet
  - Inbound 8800 TCP from your APP GW subnet

### Key Vault Networking with Application Gateway

In order for the Application Gateway to decrypt the TLS connection for inspection by the WAF, it must be able to reach the certificates stored in Azure Key Vault.

- Allow the subnet that contains your Application Gateway to access the Key Vault by adding its VNET/Subnet to the Key Vault ACL.
- Add the service delegation `Microsoft.Keyvault` to the load balancer subnet where the Application Gateway resides.

### Load Balancing Schemes

The module supports a variable named `load_balancing_scheme` with the possible values `external` and `internal`. This scenario is an external scenario. In an `internal` scenario a public IP address is required to be created and assigned to the App GW v2 SKUs, but it is not assigned a listener.

## TLS/SSL

### HTTPS Listeners Certs

- Store the TFE server certificate or (full chain certificate if included) as `.pfx` cert in AZ KV Certificate Store
- The command below will convert a `.pem` cert and `.pem` key into a `.pfx` cert:

```bash
openssl pkcs12 -inkey key.pem -in tfe-chain.pem -export -out tfe-chain-pfx.pfx
```

- This certificate is accessed by this modules `certificate` variable.

### Backend HTTP Settings Trusted Root Cert

- Get the root CA certificate that is included with the backend TFE server certificate to create a Trusted Root Certificate.
- On windows, export the CA cert as a base64 encoded x509 .cer cert <https://thomasthornton.cloud/2022/08/31/azure-application-gateway-data-for-certificate-is-invalid-error-fix/>
- This certificate is uploaded by this modules `ca_certificate_secret` variable

### TFE Server Certificates

Ensure the TFE server certificate includes the full chain `.pem` if applicable. If the CA certificate being presented by the TFE server does not match the one uploaded as the "Trusted Root Cert" of the application gateway, the backend connection will not work.

## WAF Configuration and Rules

Some WAF settings and rules are disabled to allow TFE to operate

### Disabled Rules

- `REQUEST-920-PROTOCOL-ENFORCEMENT` rules `920300, 920420` are disabled to allow proper operations and Terraform Applies.
- `REQUEST-942-APPLICATION-ATTACK-SQLI` rule `942450` is disabled to allow TFE access.

### Inspect Request Body Setting

- `inspect body request` is disabled to allow Terraform Plans
