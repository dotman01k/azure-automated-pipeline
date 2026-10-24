resource "azurerm_virtual_network" "main" {

  name                = "${var.name}-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags

}

resource "azurerm_subnet" "main" {

  name                 = "batch"
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

resource "azurerm_batch_account" "main" {

  name                          = "${replace(var.name, "-", "")}${var.unique_suffix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  pool_allocation_mode          = "BatchService"
  allowed_authentication_modes  = ["AAD", "TaskAuthenticationToken"]
  public_network_access_enabled = true
  network_profile {

    account_access {

      default_action = "Deny"
      dynamic "ip_rule" {

        for_each = toset(var.allowed_cidrs)
        content {
          ip_range = trimsuffix(ip_rule.value, "/32")
          action   = "Allow"
        }


      }


    }

    node_management_access {
      default_action = "Allow"
    }


  }

  tags = var.tags

}

resource "azurerm_batch_pool" "main" {

  name                           = "workers"
  resource_group_name            = var.resource_group_name
  account_name                   = azurerm_batch_account.main.name
  vm_size                        = var.vm_size
  node_agent_sku_id              = "batch.node.ubuntu 22.04"
  target_node_communication_mode = "Simplified"
  inter_node_communication       = "Disabled"
  fixed_scale {
    target_dedicated_nodes    = var.node_count
    target_low_priority_nodes = 0
    resize_timeout            = "PT15M"
    node_deallocation_method  = "TaskCompletion"
  }

  storage_image_reference {

    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"

  }

  network_configuration {

    subnet_id                        = azurerm_subnet.main.id
    public_address_provisioning_type = "NoPublicIPAddresses"

  }

  start_task {

    command_line       = "/bin/bash -c 'printf ready > /tmp/compute-ready'"
    wait_for_success   = true
    task_retry_maximum = 1
    user_identity {
      auto_user {
        scope           = "Task"
        elevation_level = "NonAdmin"
      }

    }


  }

  depends_on = [azurerm_subnet_nat_gateway_association.main]

}

output "contract" {
  value = {
    id = azurerm_batch_account.main.id, account_name = azurerm_batch_account.main.name, endpoint = azurerm_batch_account.main.account_endpoint, pool = azurerm_batch_pool.main.name
  }

}

