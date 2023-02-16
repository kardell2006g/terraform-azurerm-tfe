# Azure Government 

Normal Azure accounts go through the Global/Public Azure datacenters. Azure government uses isolated hardware in isolated datacenters to meet US federal standards. The seperation of these environments means that some internal Azure API endpoints, dns addresses, and more will differ. This also impacts some Terraform operations. 

https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-welcome

## Variable `is_government`

This module includes a boolean variable named `is_government` that defaults to `false`. Specifying this as `true` in `*.tfvars` will interact with the items outlined in this document to adjust for deploying in Azure Government. 

## Using the azurerm Provider with Azure Government

When using an Azure government account, the azurerm provider block must include an `environment` argument that specifies `usgovernment`:

```
provider "azurerm" {
  environment = usgovernment
  features {}
}
```
>Note: This is an optional argument that defaults to `public` if not provided.

https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#environment


## Using azurerm Backend Configuration with Azure Government

When using an Azure government storageaccount as the backend for state management, the terraform backend block must include an `environment` argument that specifies `usgovernment`:

```
terraform {
  backend "azurerm" {
    resource_group_name  = "StorageAccount-ResourceGroup"
    storage_account_name = "abcd1234"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
    environment          = usgovernment
  }
}
```
>Note: This is an optional argument that defaults to `public` if not provided.

https://www.terraform.io/language/settings/backends/azurerm#environment

## API Endpoint Differences in Azure Government VS Public

Some of the resources in this module depend on certain API endpoints. The only one known to be impacted by Azure Government at this time is the Postgresql database due to the change in API endpoint from:

When `is_government` is set true in *.tfvars, the postgresql api endpoint will be changed to match the Azure Government environment. 

### PostgreSQL
`postgres.database.azure.com`

to

`postgres.database.usgovcloudapi.net`

### Blob Storage

When using external services in Azure Government, you cannot specify just the storage account. You must specify an endpoint. TFE will default to looking for the storage account at `*.blob.core.windows.net` API endpoint. This will cause VCS configuration of workspaces to error out with slug errors because it cannot locate the storage accont. 

This module uses the line below ( found in `vmss.tf` ) when the `is_government` variable is defined `true` in `*.tfvars` . This function will interpolate the endpoint into the `tfe_custom_data.sh.tpl` script to create `tfe-settings.json` the way TFE expects it. 
```
azure_endpoint = split(".blob.", azurerm_storage_account.tfe.primary_blob_host)[1]
```

Under the admin settings of TFE, the Azure external services "Object Storage" section, verify the Azure Govcloud Endpoint: `core.usgovcloudapi.net`

To see a full list of endpoint differences between Azure Public and Azure Government, see the link below:

https://docs.microsoft.com/en-us/azure/azure-government/compare-azure-government-global-azure

## Azure CLI Considerations

When using the Azure CLI inside of the `tfe_custom_data` script, or any other scripts, you must specify to the Azure CLI which cloud you want to connect to. By default Azure CLI will attempt to look for your subsciprtions inside the public cloud. For government, include the following command in your scripts:

When `is_government` is set true in *.tfvars, the tfe_custom_data.sh.tpl script will run the command below. 
```
az cloud set --name AzureUSGovernment
```

https://docs.microsoft.com/en-us/azure/azure-government/documentation-government-get-started-connect-with-cli


