# TFE on Azure - Internal (Private-facing)
This scenario deploys TFE with an Azure Load Balancer on a private subnet that is internal-facing. This use case is good for users who do not require any external or Internet traffic inbound into TFE. This scenario leverages the _airgap_ installation method, however _online_ would also work fine (as long as the VM has the necessary outbound Internet connectivity via something like a NAT Gateway, etc.).

## Usage
```hcl
module "tfe" {
  source = "../.."

  # --- Common --- #
  location             = "East US"
  friendly_name_prefix = "cloudteam"
  common_tags = {
    "App"       = "TFE"
    "Env"       = "test"
    "Terraform" = "cli"
    "Owner"     = "YourName"
  }

  # --- Prereqs --- #
  vnet_id       = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-vnet"
  lb_subnet_id  = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-vnet/subnets/tfe-lb-subnet"
  vm_subnet_id  = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-vnet/subnets/tfe-vm-subnet"
  db_subnet_id  = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-vnet/subnets/tfe-db-subnet"
  lb_private_ip = "10.0.1.10"
  
  bootstrap_sa_name       = "mytfebootstrapsa"
  bootstrap_sa_rg         = "tfe-prereqs-rg"
  tfe_license_path        = "bootstrap/tfe-license.rli"
  tfe_airgap_bundle_path  = "bootstrap/tfe-590.airgap"
  replicated_tarball_path = "bootstrap/replicated.tar.gz"
  
  bootstrap_kv_name      = "my-tfe-bootstrap-kv"
  bootstrap_kv_rg        = "tfe-prereqs-rg"
  tfe_cert_kv_id         = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/tfe-cert/00000000000000000000000000000000"
  tfe_privkey_kv_id      = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/tfe-privkey/11111111111111111111111111111111"
  console_password_kv_id = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/console-password/22222222222222222222222222222222"
  enc_password_kv_id     = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/enc-password/33333333333333333333333333333333"
  ca_bundle_kv_id        = "https://my-tfe-bootstrap-kv.vault.azure.net/secrets/ca-bundle/44444444444444444444444444444444"

  # --- TFE Config --- #
  airgap_install                  = true
  pkg_repos_reachable_with_airgap = true
  tfe_fqdn                        = "my-tfe.azure.example.com"
  hairpin_addressing              = true

  # --- Networking --- #
  availability_zones    = ["1", "2", "3"]
  load_balancing_scheme = "internal"
  load_balancer_type    = "load_balancer"
  create_dns_record     = true
  dns_zone_name         = "azure.example.com"
  dns_zone_rg           = "tfe-prereqs-rg"

  # --- Compute --- #
  vm_count          = 1
  vm_ssh_public_key = "ssh-rsa ThisIsMySSHPublicKey== someone@example-abcdefg1234567"

  # --- PostgreSQL --- #
  postgres_password  = "Postgr3sPassw0rd!"
  enable_postgres_ha = true

  # --- Blob Storage --- #
  storage_account_cidr_allow = ["1.2.3.4"]

  # --- Active/Active --- #
  enable_active_active = false
  redis_subnet_id      = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-vnet/subnets/tfe-vm-subnet"
}
```


### Load Balancer Subnet and Private IP
The `lb_subnet_id` and `lb_private_ip` input variables are required in this scenario because when the Azure Load Balancer is provisioned without a Public IP associated, it must be given a subnet and a static IP address. The value of `lb_private_ip` must be a valid IP address from the subnet referenced in `lb_subnet_id`. 


### Hairpin Adressing
A critical configuration for this scenario to work properly is setting `hairpin_addressing` to `true`. This is because when the Azure Load Balancer does not have a Public IP associated and instead has a private IP, the loopback functionality does not work with TFE.  [Here](https://www.terraform.io/enterprise/install/automated/automating-the-installer#hairpin_addressing) is a reference to the setting in the TFE docs.