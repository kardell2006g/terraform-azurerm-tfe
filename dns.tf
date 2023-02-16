#------------------------------------------------------------------------------
# DNS Zone lookup
#------------------------------------------------------------------------------
data "azurerm_dns_zone" "tfe" {
  count = var.dns_zone_name != null ? 1 : 0

  resource_group_name = var.dns_zone_rg == null ? azurerm_resource_group.tfe.name : var.dns_zone_rg
  name                = var.dns_zone_name
}

#------------------------------------------------------------------------------
# DNS A Record
#------------------------------------------------------------------------------
locals {
  tfe_hostname = (var.create_dns_record == true && var.dns_zone_name != null ? trim(split(var.dns_zone_name, var.tfe_fqdn)[0], ".") : var.tfe_fqdn)
}

resource "azurerm_dns_a_record" "tfe" {
  count = var.create_dns_record == true && var.dns_zone_name != null && var.load_balancer_type == "load_balancer" ? 1 : 0

  resource_group_name = var.dns_zone_rg == null ? azurerm_resource_group.tfe.name : var.dns_zone_rg
  name                = local.tfe_hostname
  zone_name           = data.azurerm_dns_zone.tfe[0].name
  ttl                 = 300
  records             = var.load_balancing_scheme == "internal" && var.load_balancer_type == "load_balancer" ? [azurerm_lb.tfe[0].private_ip_address] : null
  target_resource_id  = var.load_balancing_scheme == "external" && var.load_balancer_type == "load_balancer" ? azurerm_public_ip.tfe_lb[0].id : null

  tags = var.common_tags
}

resource "azurerm_dns_a_record" "tfe_app_gw" {
  count = var.create_dns_record == true && var.dns_zone_name != null && var.load_balancer_type == "application_gateway" ? 1 : 0

  resource_group_name = var.dns_zone_rg == null ? azurerm_resource_group.tfe.name : var.dns_zone_rg
  name                = local.tfe_hostname
  zone_name           = data.azurerm_dns_zone.tfe[0].name
  ttl                 = 300
  records             = var.load_balancing_scheme == "internal" && var.load_balancer_type == "application_gateway" ? [tolist(azurerm_application_gateway.tfe_ag[0].frontend_ip_configuration).1.private_ip_address] : null
  target_resource_id  = var.load_balancing_scheme == "external" && var.load_balancer_type == "application_gateway" ? azurerm_public_ip.tfe_app_gw_pip[0].id : null

  tags = var.common_tags
}
