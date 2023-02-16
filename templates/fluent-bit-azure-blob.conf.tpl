[OUTPUT]
    name                   azure_blob
    match                  *
    account_name           ${logs_account-name}
    shared_key             ${logs_access-key}
    path                   logs
    container_name         ${logs_container-name}
    auto_create_container  on
    blob_type              appendblob
    tls                    on
%{ if is_government == true ~}
    endpoint               ${logs_blob_endpoint}
%{ endif ~}