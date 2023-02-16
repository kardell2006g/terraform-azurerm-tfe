# TFE on Azure - External Multi Region
This scenario is for deploying TFE with cross region Diaster Recovery. This is for deploying TFE to one Azure region, and being able to failover to the paired Azure region. This example is an external with an Azure Load Balancer and Public IP, however it will work with an internal deployment as well. This scenario leverages the _online_ installation method, however _airgap_ would also work fine.

## Usage

There are some differences between a regular TFE deployment and this multi-region example.

- The pre-requisites must be deployed to each region separately
- The DNS Zone for TFE (if managed through Azure) should only be deployed to 1 region. Azure DNS is a global service
- In the secondary region, the TFE resources are not deployed until a failover is going to be tested or a diaster recovery is needed
- While the TFE  module could be called twice in the same root or deployment, it is recommended to have them separate
- Parts of the failover process can only be completed from the Azure portal or Azure CLI

### Fail Over Steps

1. If the primary region is still accessible, scale VMSS to 0
2. Remove the TFE DNS record, whether in Azure DNS or another location
3. If the Azure portal is still responding in the failed region, go to the Storage account and intiate a geo restore failoever.
   1. If the region is not accessible, Microsoft should fail over any storage accounts that have geo recovery. However they will need to be set to read/write and not just read only
4. Do a target terraform plan and apply to deploy the postgres dns zone, dns zone virtual network link, and the resource group in the secondary region. These resources are necessary to restore the flexible postgresql db 
   1. `terraform plan --target=module.tfe_secondary.azurerm_private_dns_zone_virtual_network_link.postgres -out drbuild && terraform apply drbuild`
5. In the Azure portal or CLI start a Geo redundant restore of the flexible postgresql  db.
   1. Ensure to chose Geo restore, set the name to the name the db would have when deployed in secondary region, and on the networking tab, select the postgres dns zone that was built out above
   2. Start Restore
6. Once the restore is complete, import flexible postgresql db into terraform state
   1. `terraform import module.tfe_secondary.azurerm_postgresql_flexible_server.tfe "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/cloudteam-tfe-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/cloudteam-tfe-postgres-db"`
7. Terraform apply the rest of the secondary build out
