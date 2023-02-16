# Active/Active
TFE supports an Active/Active architecture, whereby more than one VM instance can run simultaneously within the VM scale set. This is made possible by provisioning Redis instances (Azure Cache for Redis) as well as a number of additional installation parameters.

## Deployment Steps
1. You must start by deploying and configuring a normal TFE standalone instance per the main [documentation](../README.md#Getting-Started) in this repository. If you already have a standalone TFE instance up and running with at least the Initial Admin User created, proceed to step 2.

2. Add the following input variables to your Terraform configuration:
```hcl
enable_active_active = true
redis_subnet_id      = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/tfe-prereqs-rg/providers/Microsoft.Network/virtualNetworks/tfe-vnet/subnets/tfe-vm-subnet"
```

3. `terraform apply` the changes to provision the Azure Cache for Redis and update the VM scale set.

4. The VM in the VM scale set will be reimaged in place. Keep instance count at 1 during this time.

5. Validate the TFE instance by logging in and executing at least one Terraform Run on a Workspace.

6. After the TFE instance is successfully validated, scale the instance count from 1 to 2 by modifying the value of the `vm_count` input variable.

7. Validate the TFE instances by logging in and executing at least one Terraform run on a workspace. 

>Note: once the input variable `enable_active_active = true` is applied, the Admin Console on port 8800 will no longer be accessible.