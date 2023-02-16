[OUTPUT]
    name         azure
    match        *
    Customer_ID  ${logs_analytics_workspace_id}
    Shared_Key   ${logs_access_key}