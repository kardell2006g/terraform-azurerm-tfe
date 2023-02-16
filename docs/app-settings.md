# TFE Application Settings Updates
If you have used this module accelerator to deploy and install TFE, then your deployment is fully automated and should be managed as code. This means you should **not** make any TFE application settings changes manually (within the admin console/Replicated dashboard on port 8800 or via the `tfe-admin` CLI), unless it is for temporary testing/experimentation purposes. If a change is made manually via the GUI or CLI, it will be reverted the next time the VM Scale Set reimages or replaces the running VM instance (whether it be planned or unplanned activity). The VM and installation are treated as _stateless_ in that when you need to make a change, you would update the code and Terraform apply the change, which will reimage the running VM triggering a reinstallation to occur.
<p>&nbsp;</p>


## Background
In order to fully automate a TFE installation, a JSON file must exist on the server prior to the installation containing all of the application settings. Any configurable application install setting should exist within the JSON. See the [documentation](https://www.terraform.io/enterprise/install/automated/automating-the-installer#application-settings) on the TFE application settings for more details. This module accelerator generates that JSON file within the [tfe_custom_data.sh.tpl](../templates/tfe_custom_data.sh.tpl) script during the cloud-init process on the VM. This logic can be found within the `main()` function of the _custom_data_ script:

```bash
  echo "[INFO] Generating $TFE_SETTINGS_PATH file."
  cat > $TFE_SETTINGS_PATH << EOF
{
  "azure_account_key": {
    "value": "${azure_account_key}"
  },
  "azure_account_name": {
    "value": "${azure_account_name}"
  },
  "azure_container": {
    "value": "${azure_container}"
  },
  "azure_endpoint": {
    "value": "${azure_endpoint}"
  },
  "backup_token": {},
  "ca_certs": {
    "value": "$CA_CERTS"
  },
  "capacity_concurrency": {
      "value": "${capacity_concurrency}"
  },
  "capacity_cpus": {},
  "capacity_memory": {
      "value": "${capacity_memory}"
  },
  "custom_image_tag": {
    "value": ""
  },
  "enable_active_active": {
    "value": "${enable_active_active}"
  },
  "enable_metrics_collection": {
      "value": "${enable_metrics_collection}"
  },
  "metrics_endpoint_enabled": {
      "value": "${metrics_endpoint_enabled}"
  },
  "metrics_endpoint_port_http": {
      "value": "${metrics_endpoint_port_http}"
  },
  "metrics_endpoint_port_https": {
      "value": "${metrics_endpoint_port_https}"
  },
  "enc_password": {
      "value": $ENC_PASSWORD
  },
  "extra_no_proxy": {
    "value": "${extra_no_proxy}"
  },
  "force_tls": {
    "value": "${force_tls}"
  },
  "hairpin_addressing": {
    "value": "${hairpin_addressing}"
  },
  "hostname": {
      "value": "${hostname}"
  },
  "iact_subnet_list": {},
  "iact_subnet_time_limit": {
      "value": "60"
  },
  "installation_type": {
      "value": "production"
  },
  "log_forwarding_config": {
    "value": "$LOG_FORWARDING_CONFIG"
  },
  "log_forwarding_enabled": {
    "value": "${log_forwarding_enabled}"
  },
  "pg_dbname": {
      "value": "${pg_dbname}"
  },
  "pg_extra_params": {
      "value": "${pg_extra_params}"
  },
  "pg_netloc": {
      "value": "${pg_netloc}"
  },
  "pg_password": {
      "value": "${pg_password}"
  },
  "pg_user": {
      "value": "${pg_user}"
  },
  "placement": {
      "value": "placement_azure"
  },
  "production_type": {
      "value": "external"
  },
  "redis_host": {
    "value": ""
  },
  "redis_pass": {
    "value": ""
  },
  "redis_port": {
    "value": ""
  },
  "redis_use_password_auth": {
    "value": ""
  },
  "redis_use_tls": {
    "value": ""
  },
  "restrict_worker_metadata_access": {
    "value": "${restrict_worker_metadata_access}"
  },
  "tbw_image": {
      "value": "${tbw_image}"
  },
  "tls_ciphers": {},
  "tls_vers": {
      "value": "tls_1_2_tls_1_3"
  }
}
EOF
```

The values of these app settings are set by:
1. Hardcoded values directly within the _custom_data_ script
2. Interpolated values of attributes of other resources provisioned by the module and passed into the _custom_data_ script as arguments
3. Input variable values passed into the _custom_data_ script as arguments

>Note: for #2 and #3, you can find the _custom_data_ arguments by viewing the `custom_data_args` locals block within the [vmss.tf](../vmss.tf) file - that ultimately get passed in as arguments via the `custom_data` attribute of the `azurerm_linux_virtual_machine_scale_set` resource.
<p>&nbsp;</p>


## Changing/Updating a TFE Application Setting
1. Search for if an input variable already exists within this Terraform module for the setting you are looking to modify. The main [README](../README.md) has all of the available input variables, and so does the [variables.tf](../variables.tf) where they are actually defined in code. If you find an existing input variable, proceed to step 2 and stop after that. If you did not find an existing input variable, skip step 2 and go directly to step 3.

2. If you found an existing input variable for the setting you want to modify, then add it as an input to your Terraform deployment where you are calling this module from to deploy TFE (_i.e._ within your `main.tf` file). Then during a maintenance, run `terraform apply` which will trigger the Azure VM Scale Set to reimage the VM with the newly updated setting (similarly to the [upgrade](./upgrade-versions.md) procedures). If you did not find an existing input variable, then proceed to step 3.

3. At this point you need to codify the setting you are looking to modify. There are several options:
   
   a) Hardcode the setting and value within the [tfe_custom_data.sh.tpl](../templates/tfe_custom_data.sh.tpl) script, specifically within the section of code mentioned in the previous [Background](#background) section where the JSON is generated for the TFE application settings.
   
   b) Add a new Terraform input variable to the module, then add the variable reference into the `custom_data_args` locals block within the [vmss.tf](../vmss.tf) file so that it gets passed into the _custom_data_ script as an argument, and finally reference the variable from within the [tfe_custom_data.sh.tpl](../templates/tfe_custom_data.sh.tpl) script (specifically within the section of code mentioned in the previous [Background](#background) section where the JSON is generated for the TFE application settings).

   Either way, after the code update is complete, during a maintenance window run `terraform apply` which will trigger the Azure VM Scale Set to reimage the VM with the newly updated setting (similarly to the [upgrade](./upgrade-versions.md) procedures).
