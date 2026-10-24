data "azurerm_virtual_network" "existing" {
  name                = var.existing_vnet_name
  resource_group_name = var.network_resource_group_name
}

data "azurerm_subnet" "endpoint" {
  name                 = var.private_endpoint_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.network_resource_group_name
}
