#------------------------------------------------------------------------------
# Public IP (optional)
#------------------------------------------------------------------------------
resource "azurerm_public_ip" "tfe_lb" {
  count = var.load_balancing_scheme == "external" && var.load_balancer_type == "load_balancer" ? 1 : 0

  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location
  name                = "${var.friendly_name_prefix}-tfe-lb-ip"
  zones               = var.availability_zones
  sku                 = "Standard"
  allocation_method   = "Static"

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-lb-ip" },
    var.common_tags
  )
}

#------------------------------------------------------------------------------
# Azure Load Balancer
#------------------------------------------------------------------------------
# locals {

#   lb_subnet_rg   = element(split(var.lb_subnet_id, "/"), 4)
#   lb_subnet_name = element(split(var.lb_subnet_id, "/"), 10)
#   lb_subnet_vnet   = element(split(var.lb_subnet_id, "/"), 8)
# }

# data "azurerm_subnet" "lb" {
#   count = var.lb_subnet_id != null ? 1 : 0

#   name                 = local.lb_subnet_name
#   virtual_network_name = local.lb_subnet_vnet
#   resource_group_name  = local.lb_subnet_rg
# }

resource "azurerm_lb" "tfe" {
  count = var.load_balancer_type == "load_balancer" ? 1 : 0

  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location
  name                = "${var.friendly_name_prefix}-tfe-lb"
  sku                 = "Standard"
  sku_tier            = "Regional"

  frontend_ip_configuration {
    name                          = "tfe-frontend-${var.load_balancing_scheme}"
    zones                         = var.load_balancing_scheme == "internal" ? var.availability_zones : null
    public_ip_address_id          = var.load_balancing_scheme == "external" ? azurerm_public_ip.tfe_lb[0].id : null
    subnet_id                     = var.load_balancing_scheme == "internal" ? var.lb_subnet_id : null
    private_ip_address_allocation = var.load_balancing_scheme == "internal" ? "Static" : null
    private_ip_address            = var.load_balancing_scheme == "internal" ? var.lb_private_ip : null
  }

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-tfe-lb" },
    var.common_tags
  )
}

resource "azurerm_lb_backend_address_pool" "tfe_servers" {
  count = var.load_balancer_type == "load_balancer" ? 1 : 0

  name            = "${var.friendly_name_prefix}-tfe-backend"
  loadbalancer_id = azurerm_lb.tfe[0].id
}

resource "azurerm_lb_probe" "app" {
  count = var.load_balancer_type == "load_balancer" ? 1 : 0

  loadbalancer_id     = azurerm_lb.tfe[0].id
  name                = "tfe-app-lb-probe"
  protocol            = "Https"
  port                = 443
  request_path        = "/_health_check"
  interval_in_seconds = 15
  number_of_probes    = 3
}

resource "azurerm_lb_probe" "console" {
  count = var.enable_active_active == false && var.load_balancer_type == "load_balancer" ? 1 : 0

  loadbalancer_id     = azurerm_lb.tfe[0].id
  name                = "tfe-console-lb-probe"
  protocol            = "Https"
  request_path        = "/authenticate"
  port                = 8800
  interval_in_seconds = 15
  number_of_probes    = 3
}

resource "azurerm_lb_rule" "app" {
  count = var.load_balancer_type == "load_balancer" ? 1 : 0

  name                           = "${var.friendly_name_prefix}-tfe-lb-rule-app"
  loadbalancer_id                = azurerm_lb.tfe[0].id
  probe_id                       = azurerm_lb_probe.app[0].id
  protocol                       = "Tcp"
  frontend_ip_configuration_name = azurerm_lb.tfe[0].frontend_ip_configuration[0].name
  frontend_port                  = 443
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.tfe_servers[0].id]
  backend_port                   = 443
}

resource "azurerm_lb_rule" "console" {
  count = var.enable_active_active == false && var.load_balancer_type == "load_balancer" ? 1 : 0

  name                           = "${var.friendly_name_prefix}-tfe-lb-rule-console"
  loadbalancer_id                = azurerm_lb.tfe[0].id
  probe_id                       = azurerm_lb_probe.console[0].id
  protocol                       = "Tcp"
  frontend_ip_configuration_name = azurerm_lb.tfe[0].frontend_ip_configuration[0].name
  frontend_port                  = 8800
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.tfe_servers[0].id]
  backend_port                   = 8800
}