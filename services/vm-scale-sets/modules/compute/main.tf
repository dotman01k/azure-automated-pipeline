resource "azurerm_virtual_network" "main" {

  name                = "${var.name}-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags

}

resource "azurerm_subnet" "main" {

  name                 = "workers"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]

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

resource "azurerm_network_security_group" "main" {

  name                = "${var.name}-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location
  security_rule {

    name                       = "PrivateSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.management_cidr
    destination_address_prefix = "*"

  }

  security_rule {

    name                       = "InternalHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"

  }

  security_rule {

    name                       = "LoadBalancerProbe"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"

  }

  security_rule {

    name                       = "DenyOtherInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"

  }

  tags = var.tags

}

resource "azurerm_subnet_network_security_group_association" "main" {

  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id

}

resource "azurerm_lb" "main" {

  name                = "${var.name}-internal-lb"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  frontend_ip_configuration {

    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"

  }

  tags = var.tags

}

resource "azurerm_lb_backend_address_pool" "main" {

  name            = "workers"
  loadbalancer_id = azurerm_lb.main.id

}

resource "azurerm_lb_probe" "main" {

  name            = "http"
  loadbalancer_id = azurerm_lb.main.id
  protocol        = "Http"
  port            = 80
  request_path    = "/"

}

resource "azurerm_lb_rule" "main" {

  name                           = "http"
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "internal"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.main.id
  disable_outbound_snat          = true

}

resource "azurerm_linux_virtual_machine_scale_set" "main" {

  name                            = "${var.name}-vmss"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  sku                             = var.vm_size
  instances                       = var.instances
  admin_username                  = "platformadmin"
  disable_password_authentication = true
  upgrade_mode                    = "Manual"
  overprovision                   = false
  health_probe_id                 = azurerm_lb_probe.main.id
  custom_data                     = base64encode(file("${path.module}/cloud-init.yaml"))
  admin_ssh_key {
    username   = "platformadmin"
    public_key = var.ssh_public_key
  }

  source_image_reference {

    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"

  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  network_interface {

    name    = "private"
    primary = true
    ip_configuration {

      name                                   = "private"
      primary                                = true
      subnet_id                              = azurerm_subnet.main.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.main.id]

    }


  }

  identity {
    type = "SystemAssigned"
  }

  tags       = var.tags
  depends_on = [azurerm_subnet_nat_gateway_association.main, azurerm_subnet_network_security_group_association.main]
  lifecycle {
    ignore_changes = [instances]
  }


}

resource "azurerm_monitor_autoscale_setting" "main" {

  name                = "${var.name}-autoscale"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.main.id
  profile {

    name = "cpu"
    capacity {
      default = var.instances
      minimum = 2
      maximum = 4
    }

    rule {

      metric_trigger {

        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70

      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }


    }

    rule {

      metric_trigger {

        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30

      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }


    }


  }

  tags = var.tags

}

output "contract" {

  value = {
    id = azurerm_linux_virtual_machine_scale_set.main.id, private_http_ip = azurerm_lb.main.private_ip_address, egress_ip = azurerm_public_ip.egress.ip_address
  }


}

