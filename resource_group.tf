resource "azurerm_resource_group" "tfe" {
  name     = "${var.friendly_name_prefix}-${var.resource_group_name}"
  location = var.location

  tags = merge(
    { "Name" = "${var.friendly_name_prefix}-${var.resource_group_name}" },
    var.common_tags
  )
}