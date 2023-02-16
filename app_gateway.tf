locals {
  # Determine private IP address based on CIDR range if not already supplied and if load balancer public is false
  private_ip_address = var.app_gw_private_ip == null && var.load_balancing_scheme == "internal" ? cidrhost(var.lb_subnet_cidr, 16) : var.app_gw_private_ip

  # Determine the resulting TFE IP
  load_balancer_ip = var.load_balancing_scheme == "external" && var.load_balancer_type == "application_gateway" ? azurerm_public_ip.tfe_app_gw_pip[0].ip_address : local.private_ip_address

  is_legacy_rule_set_version = var.app_gw_waf_rule_set_version == "2.2.9"

  # Application Gateway
  # -------------------
  gateway_ip_configuration_name          = "tfe-ag-gateway-ip-config"
  frontend_ip_configuration_name_public  = "tfe-ag-frontend-ip-config-pub"
  frontend_ip_configuration_name_private = "tfe-ag-frontend-ip-config-priv"
  frontend_ip_configuration_name         = var.load_balancing_scheme == "external" ? local.frontend_ip_configuration_name_public : local.frontend_ip_configuration_name_private
  backend_address_pool_name              = "tfe-ag-backend-address-pool"
  rewrite_rule_set_name                  = "tfe-ag-rewrite_rules"

  # TFE Application Configuration
  app_frontend_port_name          = "tfe-ag-frontend-port-app"
  app_frontend_http_listener_name = "tfe-ag-http-listener-frontend-port-app"
  app_backend_http_settings_name  = "tfe-ag-backend-http-settings-app"
  app_request_routing_rule_name   = "tfe-ag-routing-rule-app"

  # TFE Console Configuration (standalone only)
  console_frontend_port_name          = "tfe-ag-frontend-port-console"
  console_frontend_http_listener_name = "tfe-ag-http-listener-frontend-port-console"
  console_backend_http_settings_name  = "tfe-ag-backend-http-settings-console"
  console_request_routing_rule_name   = "tfe-ag-routing-rule-console"

  trusted_root_certificates      = var.ca_certificate_secret == null ? {} : { (var.ca_certificate_secret.name) = var.ca_certificate_secret.value }
  trusted_root_certificate_names = keys(local.trusted_root_certificates)
}

# Public IP
# ---------
resource "azurerm_public_ip" "tfe_app_gw_pip" {
  count = var.load_balancer_type == "application_gateway" ? 1 : 0

  name                = "${var.friendly_name_prefix}-app-gw-pip"
  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location

  sku               = "Standard"
  allocation_method = "Static"
  //domain_name_label = var.domain_name == null ? local.tfe_subdomain : null
  zones = var.availability_zones

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-lb-ip" },
    var.common_tags
  )
}

# Managed Service Identity
# ------------------------
resource "azurerm_user_assigned_identity" "tfe_ag_msi" {
  count = var.load_balancer_type == "application_gateway" ? 1 : 0

  name                = "${var.friendly_name_prefix}-app-gw-msi"
  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-lb-ip" },
    var.common_tags
  )
}

resource "azurerm_key_vault_access_policy" "tfe_app_gw" {
  count = var.load_balancer_type == "application_gateway" ? 1 : 0

  key_vault_id = var.certificate.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.tfe_ag_msi[0].principal_id

  certificate_permissions = [
    "Get",
    "List"
  ]

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Application Gateway
# -------------------
resource "azurerm_application_gateway" "tfe_ag" {
  count = var.load_balancer_type == "application_gateway" ? 1 : 0

  depends_on = [
    # This explicit dependency is required to ensure that the access policy is created before the application gateway.
    # It is not possible to use the the object ID of the access policy as the identity ID of the application gateway
    # as they are required to be different values of the user assigned identity (principal ID versus ID).
    azurerm_key_vault_access_policy.tfe_app_gw
  ]

  name                = "${var.friendly_name_prefix}-tfe-ag"
  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location

  enable_http2 = var.app_gw_enable_http2
  zones        = var.availability_zones

  sku {
    name     = var.app_gw_sku_name
    tier     = var.app_gw_sku_tier
    capacity = var.app_gw_sku_capacity
  }

  rewrite_rule_set {
    name = local.rewrite_rule_set_name

    rewrite_rule {
      name          = "remove_port_from_headers"
      rule_sequence = 100
      request_header_configuration {
        header_name  = "X-Forwarded-For"
        header_value = "{var_add_x_forwarded_for_proxy}"
      }
    }
  }

  dynamic "waf_configuration" {
    for_each = var.app_gw_sku_name == "WAF_v2" ? [1] : []

    content {
      enabled          = true
      firewall_mode    = var.app_gw_firewall_mode
      rule_set_type    = "OWASP"
      rule_set_version = var.app_gw_waf_rule_set_version

      # Terraform plans will not work if this is enabled. They are too large for the max size limit. 
      request_body_check = false

      # Allow HTTP header "Content-Type: application/vnd.api+json" for API requests
      # 920300 must be disabled to allow Terraform Apply to run from TFE.
      disabled_rule_group {
        rule_group_name = local.is_legacy_rule_set_version ? "crs_30_http_policy" : "REQUEST-920-PROTOCOL-ENFORCEMENT"

        rules = local.is_legacy_rule_set_version ? [960010, 920300] : [920420, 920300]
      }

      # Access to TFE is forbidden unless this is disabled on WAF_v2 when using OWASP3.1
      disabled_rule_group {
        rule_group_name = "REQUEST-942-APPLICATION-ATTACK-SQLI"

        rules = [942450]
      }

      file_upload_limit_mb     = var.app_gw_waf_file_upload_limit_mb
      max_request_body_size_kb = var.app_gw_waf_max_request_body_size_kb
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.tfe_ag_msi[0].id]
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_configuration_name
    subnet_id = var.lb_subnet_id
  }

  ssl_certificate {
    name                = var.certificate.name
    key_vault_secret_id = var.certificate.secret_id
  }

  ssl_policy {
    # AppGwSslPolicy20170401S requires >= TLSv1_2
    policy_name = "AppGwSslPolicy20170401S"
    policy_type = "Predefined"
  }

  dynamic "trusted_root_certificate" {
    for_each = local.trusted_root_certificates
    content {
      name = trusted_root_certificate.key
      data = trusted_root_certificate.value
    }
  }

  # Public front end configuration
  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name_public
    public_ip_address_id = azurerm_public_ip.tfe_app_gw_pip[0].id
  }

  # Private front end configuration
  dynamic "frontend_ip_configuration" {
    for_each = var.load_balancing_scheme == "internal" ? [1] : []

    content {
      name                          = local.frontend_ip_configuration_name_private
      subnet_id                     = var.lb_subnet_id
      private_ip_address_allocation = "Static"
      private_ip_address            = local.private_ip_address
    }
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  # TFE Application
  frontend_port {
    name = local.app_frontend_port_name
    port = 443
  }

  http_listener {
    name                           = local.app_frontend_http_listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.app_frontend_port_name
    protocol                       = "Https"
    ssl_certificate_name           = var.certificate.name
  }

  probe {
    host                = var.tfe_fqdn
    name                = "tfe-app-lb-probe"
    protocol            = "Https"
    port                = 443
    path                = "/_health_check"
    interval            = 15
    timeout             = 45
    unhealthy_threshold = 3
  }

  backend_http_settings {
    name                  = local.app_backend_http_settings_name
    cookie_based_affinity = "Disabled"
    path                  = ""
    protocol              = "Https"
    port                  = 443
    request_timeout       = 60
    host_name             = var.tfe_fqdn
    probe_name            = "tfe-app-lb-probe"

    trusted_root_certificate_names = local.trusted_root_certificate_names
  }

  request_routing_rule {
    name                       = local.app_request_routing_rule_name
    priority                   = var.app_gw_request_routing_rule_minimum_priority
    rule_type                  = "Basic"
    http_listener_name         = local.app_frontend_http_listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.app_backend_http_settings_name
    rewrite_rule_set_name      = local.rewrite_rule_set_name
  }

  # TFE Console
  dynamic "frontend_port" {
    for_each = var.enable_active_active == false ? [1] : []

    content {
      name = local.console_frontend_port_name
      port = 8800
    }
  }

  dynamic "http_listener" {
    for_each = var.enable_active_active == false ? [1] : []

    content {
      name                           = local.console_frontend_http_listener_name
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = local.console_frontend_port_name
      protocol                       = "Https"
      ssl_certificate_name           = var.certificate.name
    }
  }

  dynamic "backend_http_settings" {
    for_each = var.enable_active_active == false ? [1] : []

    content {
      name                  = local.console_backend_http_settings_name
      cookie_based_affinity = "Disabled"
      path                  = ""
      protocol              = "Https"
      port                  = 8800
      request_timeout       = 60
      host_name             = var.tfe_fqdn
      probe_name            = "tfe-console-lb-probe"

      trusted_root_certificate_names = local.trusted_root_certificate_names
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.enable_active_active == false ? [1] : []

    content {
      name                       = local.console_request_routing_rule_name
      priority                   = (var.app_gw_request_routing_rule_minimum_priority + 1)
      rule_type                  = "Basic"
      http_listener_name         = local.console_frontend_http_listener_name
      backend_address_pool_name  = local.backend_address_pool_name
      backend_http_settings_name = local.console_backend_http_settings_name
    }
  }

  probe {
    name                = "tfe-console-lb-probe"
    host                = var.tfe_fqdn
    protocol            = "Https"
    port                = 8800
    path                = "/authenticate"
    interval            = 15
    timeout             = 45
    unhealthy_threshold = 3
  }

  lifecycle {
    ignore_changes = [identity[0].identity_ids]
  }

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}tfeblob" },
    var.common_tags
  )
}