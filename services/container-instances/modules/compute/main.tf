resource "azurerm_virtual_network" "main" {

  name                = "${var.name}-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags

}

resource "azurerm_subnet" "main" {

  name                 = "containers"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
  delegation {
    name = "container-instances"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }

  }


}

resource "azurerm_public_ip" "egress" {

  name                = "${var.name}-egress"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags

}

resource "azurerm_nat_gateway" "main" {

  name                = "${var.name}-nat"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "Standard"
  tags                = var.tags

}

resource "azurerm_nat_gateway_public_ip_association" "main" {

  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.egress.id

}

resource "azurerm_subnet_nat_gateway_association" "main" {

  subnet_id      = azurerm_subnet.main.id
  nat_gateway_id = azurerm_nat_gateway.main.id
  depends_on     = [azurerm_nat_gateway_public_ip_association.main]

}

resource "azurerm_container_group" "main" {

  name                = "${var.name}-group"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  restart_policy      = "Always"
  ip_address_type     = "Private"
  subnet_ids          = [azurerm_subnet.main.id]
  identity {
    type = "SystemAssigned"
  }

  container {

    name   = "web"
    image  = var.container_image
    cpu    = 1
    memory = 1.5
    ports {
      port     = 80
      protocol = "TCP"
    }

    readiness_probe {
      http_get {
        path   = "/"
        port   = 80
        scheme = "http"
      }

      initial_delay_seconds = 10
      period_seconds        = 10
    }


  }

  tags       = var.tags
  depends_on = [azurerm_subnet_nat_gateway_association.main]

}

output "contract" {
  value = {
    id = azurerm_container_group.main.id, private_ip = azurerm_container_group.main.ip_address, egress_ip = azurerm_public_ip.egress.ip_address
  }

}

