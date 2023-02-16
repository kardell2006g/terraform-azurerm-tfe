#!/usr/bin/env bash
set -euo pipefail

determine_os_distro() {
  local os_distro_name=$(grep "^NAME=" /etc/os-release | cut -d"\"" -f2)

  case "$os_distro_name" in 
    "Ubuntu"*)
      os_distro="ubuntu"
      ;;
    "CentOS Linux"*)
      os_distro="centos"
      ;;
    "Red Hat"*)
      os_distro="rhel"
      ;;
    *)
      echo "[ERROR] '$os_distro_name' is an unsupported Linux OS distro."
      exit_script 1
  esac

  echo "$os_distro"
}

install_azcli() {
  if [[ -n "$(command -v az)" ]]; then 
    echo "[INFO] Detected 'az' (Azure CLI) is already installed. Skipping."
  else
    if [[ "$os_distro" == "ubuntu" ]]; then
      curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    elif [[ "$os_distro" == "centos" ]] || [[ "$os_distro" == "rhel" ]]; then
      rpm --import https://packages.microsoft.com/keys/microsoft.asc
      cat > /etc/yum.repos.d/azure-cli.repo << EOF
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
      dnf install -y azure-cli
    fi
  fi
}

install_docker() {
  local os_distro="$1"
  
  if [[ -n "$(command -v docker)" ]]; then
    echo "[INFO] Detected 'docker' is already installed. Skipping."
  else
    if [[ "$os_distro" == "ubuntu" ]]; then
      # https://docs.docker.com/engine/install/ubuntu/
      echo "[INFO] Installing Docker for Ubuntu (Focal)."
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update -y
      apt-get install -y docker-ce=5:20.10.7~3-0~ubuntu-focal docker-ce-cli=5:20.10.7~3-0~ubuntu-focal containerd.io
    elif [[ "$os_distro" == "centos" ]]; then
      # https://docs.docker.com/engine/install/centos/
      echo "[INFO] Installing Docker for CentOS."
      yum install -y yum-utils
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      yum install -y docker-ce-20.10.7-3.el7 docker-ce-cli-20.10.7-3.el7 containerd.io
    elif [[ "$os_distro" == "rhel" ]]; then
      # https://docs.docker.com/engine/install/rhel/ - currently broken
      echo "[ERROR] 'docker' must be installed as a prereq on RHEL. Exiting."
      exit_script 4
    fi
    systemctl enable --now docker.service
  fi
}

install_dependencies() {
  local airgap_install="$1"
  local os_distro="$2"
  local pkg_repos_reachable_with_airgap="$3"
  local install_docker_before="$4"

  if [[ "$airgap_install" == "true" ]] && [[ "$pkg_repos_reachable_with_airgap" == "false" ]]; then
    echo "[INFO] Checking if prereq software depedencies exist for 'airgap' install."
    if [[ -z "$(command -v jq)" ]]; then
      echo "[ERROR] 'jq' not detected on system. Ensure 'jq' is installed on image before running."
      exit_script 2
    fi
    if [[ -z "$(command -v unzip)" ]]; then
      echo "[ERROR] 'unzip' not detected on system. Ensure 'unzip' is installed on image before running."
      exit_script 3
    fi
    if [[ -z "$(command -v docker)" ]]; then
      echo "[ERROR] 'docker' was not detected on system. Ensure 'docker' is installed on image before running."
      exit_script 4
    fi
    if [[ -z "$(command -v az)" ]]; then
      echo "[ERROR] 'az' not detected on system. Ensure Azure CLI is installed on image before running."
      exit_script 5
    fi
  else
    echo "[INFO] Preparing to install prereq software dependecies."
    if [[ "$os_distro" == "ubuntu" ]]; then
      echo "[INFO] Installing software dependencies for Ubuntu."
      apt-get update -y
      apt-get install -y jq unzip
    elif [[ "$os_distro" == "centos" ]]; then 
      echo "[INFO] Installing software dependencies for CentOS."
      yum install -y epel-release
      yum update -y
      yum install -y jq unzip
    elif [[ "$os_distro" == "rhel" ]]; then 
      echo "[INFO] Installing software dependencies for RHEL."
      yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
      yum update -y
      yum install -y jq unzip
    fi
    
    if [[ "$install_docker_before" == "true" ]] || [[ "$airgap_install" == "true" ]]; then
      install_docker "$os_distro"
    fi
    
    install_azcli "$os_distro"
  fi
}

retrieve_obj_from_blob_storage() {
  local ACCOUNT="$1"
  local OBJ_PATH="$2"
  local CONTAINER="$(echo $OBJ_PATH | cut -d "/" -f 1)"
  local FILENAME="$(echo $OBJ_PATH | cut -d "/" -f 2)"
  local DEST="$3"

  if [[ "$OBJ_PATH" == "" ]]; then
    echo "[ERROR] Did not detect a valid blob path."
    exit_script 10
  else
    echo "[INFO] Copying '$OBJ_PATH' to '$DEST'..."
    az storage blob download --account-name "$ACCOUNT" --container-name "$CONTAINER" --name "$FILENAME" --file "$DEST" --auth-mode login
  fi
}

retrieve_certs_from_kv() {
  az keyvault secret show --id "${tfe_cert_kv_id}" --query value --output tsv | base64 -d > $TFE_CONFIG_DIR/tfe_cert.pem
  az keyvault secret show --id "${tfe_privkey_kv_id}" --query value --output tsv | base64 -d > $TFE_CONFIG_DIR/tfe_privkey.pem
}

retrieve_secret_from_kv() {
  local SECRET_ID="$1"

  SECRET=$(az keyvault secret show --id "$SECRET_ID" --query value)
  
  echo "$SECRET"
}

configure_log_forwarding() {
  echo "[INFO]: Configuring Fluent Bit log forwarding."
  cat > "$TFE_CONFIG_DIR/fluent-bit.conf" << EOF
${fluent_bit_config}
EOF

  LOG_FORWARDING_CONFIG=$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $TFE_CONFIG_DIR/fluent-bit.conf)
}

exit_script() { 
  if [[ "$1" == 0 ]]; then
    echo "[INFO] TFE user_data script finished successfully!"
  else
    echo "[ERROR] TFE user_data script finished with error code $1."
  fi
  
  exit "$1"
}

main() {
  echo "[INFO] Beginning TFE user_data script."
  OS_DISTRO=$(determine_os_distro)
  echo "[INFO] Detected OS distro is '$OS_DISTRO'."
  install_dependencies "${airgap_install}" "$OS_DISTRO" "${pkg_repos_reachable_with_airgap}" "${install_docker_before}"

  PRIVATE_IP=$(curl -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r .network.interface[0].ipv4.ipAddress[0].privateIpAddress)
  TFE_INSTALLER_DIR="/opt/tfe/installer"
  TFE_CONFIG_DIR="/etc"
  TFE_SETTINGS_PATH="$TFE_CONFIG_DIR/tfe-settings.json"
  TFE_LICENSE_PATH="$TFE_CONFIG_DIR/license.rli"
  TFE_AIRGAP_PATH="$TFE_INSTALLER_DIR/tfe-bundle.airgap"
  REPL_TARBALL_PATH="$TFE_INSTALLER_DIR/replicated.tar.gz"
  REPL_CONF_PATH="$TFE_CONFIG_DIR/replicated.conf"
  
  mkdir -p $TFE_INSTALLER_DIR
  
  # resize partitions for RHEL
  if [[ "$OS_DISTRO" == "rhel" ]]; then
    echo "[INFO] Resizing / and /var partitions for RHEL."
    lvresize -r -L +8G /dev/mapper/rootvg-rootlv
    lvresize -r -L +32G /dev/mapper/rootvg-varlv
  fi

  # check the is_government value and set cloud to proper environment if true
  if [[ "${is_government}" == "true" ]]; then
    echo "[INFO] Setting azure-cli to AzureUSGovernment environment."
    az cloud set --name AzureUSGovernment
  fi
  
  # auth the Azure CLI via UserAssigned MSI
  az login --identity
  
  echo "[INFO] Retrieving TFE license file from blob storage."
  retrieve_obj_from_blob_storage "${bootstrap_sa_name}" "${tfe_license_path}" "$TFE_LICENSE_PATH"
  
  if [[ "${airgap_install}" == "true" ]]; then
    # retrieve TFE install files from 'Bootstrap' Blob Storage account for 'airgap' install
    echo "[INFO] Retrieving TFE airgap bundle from blob storage."
    retrieve_obj_from_blob_storage "${bootstrap_sa_name}" "${tfe_airgap_bundle_path}" "$TFE_AIRGAP_PATH"
    echo "[INFO] Retrieving Replicated tarball from blob storage."
    retrieve_obj_from_blob_storage "${bootstrap_sa_name}" "${replicated_tarball_path}" "$REPL_TARBALL_PATH"
  else
    # retrieve 'install.sh' script for 'online' install
    echo "[INFO] Retrieving TFE installer script directly from Replicated."
    curl https://install.terraform.io/ptfe/stable -o "$TFE_INSTALLER_DIR/install.sh"
  fi

  # retrieve and generate certificate files
  echo "[INFO] Retrieving TFE certificates from Key Vault."
  retrieve_certs_from_kv

  if [[ "${ca_bundle_kv_id}" != "" ]]; then
    echo "[INFO] Retrieving custom CA bundle from Key Vault."
    CA_CERTS=$(az keyvault secret show --id "${ca_bundle_kv_id}" --query value --output tsv)
  else
    CA_CERTS=""
  fi

  # retrieve install secrets
  echo "[INFO] Retrieving TFE install secret 'console-password' from Key Vault."
  CONSOLE_PASSWORD=$(retrieve_secret_from_kv "${console_password_kv_id}")
  echo "[INFO] Retrieving TFE install secret 'enc-password' from Key Vault."
  ENC_PASSWORD=$(retrieve_secret_from_kv "${enc_password_kv_id}")
  
  # enable & configure log forwarding with Fluent Bit
  # https://www.terraform.io/docs/enterprise/admin/logging.html#enable-log-forwarding
  if [[ "${log_forwarding_enabled}" == "1" ]]; then
    configure_log_forwarding
  else
    LOG_FORWARDING_CONFIG=""
  fi
  
  # generate Replicated config file
  # https://help.replicated.com/docs/native/customer-installations/automating/
  echo "[INFO] Generating $REPL_CONF_PATH file."
  cat > $REPL_CONF_PATH << EOF
{
  "DaemonAuthenticationType": "password",
  "DaemonAuthenticationPassword": $CONSOLE_PASSWORD,
  "ImportSettingsFrom": "$TFE_SETTINGS_PATH",
%{ if airgap_install == true ~}
  "LicenseBootstrapAirgapPackagePath": "$TFE_AIRGAP_PATH",
%{ else ~}
  "ReleaseSequence": ${tfe_release_sequence},
%{ endif ~}
  "LicenseFileLocation": "$TFE_LICENSE_PATH",
  "TlsBootstrapHostname": "${hostname}",
  "TlsBootstrapType": "${tls_bootstrap_type}",
%{ if tls_bootstrap_type == "server-path" ~}
  "TlsBootstrapCert": "$TFE_CONFIG_DIR/tfe_cert.pem",
  "TlsBootstrapKey": "$TFE_CONFIG_DIR/tfe_privkey.pem",
%{ endif ~}
  "RemoveImportSettingsFrom": ${remove_import_settings_from},
  "BypassPreflightChecks": true
}
EOF

  # generate TFE app settings JSON file
  # https://www.terraform.io/docs/enterprise/install/automating-the-installer.html#available-settings
  echo "[INFO] Generating $TFE_SETTINGS_PATH file."
  cat > $TFE_SETTINGS_PATH << EOF
{
%{ if azure_use_msi == 0 ~}
  "azure_account_key": {
    "value": "${azure_account_key}"
  },
%{ else ~}
  "azure_account_key": {
    "value": ""
  },
%{ endif ~}
%{ if azure_use_msi == 0 ~}
  "azure_use_msi": {
    "value": "0"
  },
%{ else ~}
  "azure_use_msi": {
    "value": "1"
  },
%{ endif ~}
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
    "value": "${redis_host}"
  },
  "redis_pass": {
    "value": "${redis_pass}"
  },
  "redis_port": {
    "value": "${redis_port}"
  },
  "redis_use_password_auth": {
    "value": "${redis_use_password_auth}"
  },
  "redis_use_tls": {
    "value": "${redis_use_tls}"
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

  # execute the TFE installer script
  cd $TFE_INSTALLER_DIR
  if [[ "${airgap_install}" == "true" ]]; then
    echo "[INFO] Extracting Replicated tarball for 'airgap' install."
    tar xzf $REPL_TARBALL_PATH -C $TFE_INSTALLER_DIR
    echo "[INFO] Executing TFE install in 'airgap' mode."
  else
    echo "[INFO] Executing TFE install in 'online' mode."
  fi

  bash ./install.sh \
%{ if airgap_install == true ~}
    airgap \
%{ endif ~}
%{ if http_proxy != "" ~}
    http-proxy=${http_proxy} \
%{ else ~}
    no-proxy \
%{ endif ~}
%{ if extra_no_proxy != "" ~}
    additional-no-proxy=${extra_no_proxy} \
%{ endif ~}
%{ if enable_active_active == 1 ~}
    disable-replicated-ui \
%{ endif ~}
%{ if install_docker_before == true ~}
    no-docker \
%{ endif ~}
    private-address=$PRIVATE_IP \
    public-address=$PRIVATE_IP

  echo "[INFO] Sleeping for a minute while TFE initializes."
  sleep 60

  echo "[INFO] Polling TFE health check endpoint until app becomes ready..."
  while ! curl -ksfS --connect-timeout 5 https://$PRIVATE_IP/_health_check; do
    sleep 5
  done

  exit_script 0
}

main "$@"