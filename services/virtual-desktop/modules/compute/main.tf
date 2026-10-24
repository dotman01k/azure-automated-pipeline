resource "azurerm_virtual_desktop_host_pool" "main" {

  name                     = "${var.name}-pool"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = 4
  preferred_app_group_type = "Desktop"
  custom_rdp_properties    = "enablerdsaadauth:i:1;targetisaadjoined:i:1;"
  tags                     = var.tags

}

resource "azurerm_virtual_desktop_application_group" "main" {

  name                         = "${var.name}-desktop"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  type                         = "Desktop"
  host_pool_id                 = azurerm_virtual_desktop_host_pool.main.id
  default_desktop_display_name = "Cloud desktop"
  tags                         = var.tags

}

resource "azurerm_virtual_desktop_workspace" "main" {

  name                = "${var.name}-workspace"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

}

resource "azurerm_virtual_desktop_workspace_application_group_association" "main" {

  workspace_id         = azurerm_virtual_desktop_workspace.main.id
  application_group_id = azurerm_virtual_desktop_application_group.main.id

}

resource "azurerm_virtual_network" "main" {

  name                = "${var.name}-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags

}

resource "azurerm_subnet" "main" {

  name                 = "session-hosts"
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

    name                       = "DenyInbound"
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

resource "azurerm_network_interface" "main" {

  name                = "${var.name}-host-nic"
  resource_group_name = var.resource_group_name
  location            = var.location
  ip_configuration {
    name                          = "private"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags

}

resource "azurerm_windows_virtual_machine" "main" {

  name                      = "${var.name}-host"
  computer_name             = "avdhost01"
  resource_group_name       = var.resource_group_name
  location                  = var.location
  size                      = var.vm_size
  admin_username            = "platformadmin"
  admin_password            = var.admin_password
  network_interface_ids     = [azurerm_network_interface.main.id]
  license_type              = "Windows_Client"
  provision_vm_agent        = true
  secure_boot_enabled       = true
  vtpm_enabled              = true
  automatic_updates_enabled = true
  patch_mode                = "AutomaticByOS"
  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-avd"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  boot_diagnostics {

  }

  tags       = var.tags
  depends_on = [azurerm_subnet_nat_gateway_association.main, azurerm_subnet_network_security_group_association.main]
  lifecycle {
    prevent_destroy = true
  }


}

resource "azurerm_virtual_machine_extension" "entra" {

  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.main.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true
  settings = jsonencode({
    mdmId = "0000000a-0000-0000-c000-000000000000"
    }
  )
  tags = var.tags

}

resource "azurerm_role_assignment" "desktop" {

  scope                = azurerm_virtual_desktop_application_group.main.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = var.user_group_object_id

}

resource "azurerm_role_assignment" "login" {

  scope                = azurerm_windows_virtual_machine.main.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = var.user_group_object_id

}

output "contract" {
  value = {
    id = azurerm_virtual_desktop_host_pool.main.id, host_pool_name = azurerm_virtual_desktop_host_pool.main.name, vm_name = azurerm_windows_virtual_machine.main.name, workspace_id = azurerm_virtual_desktop_workspace.main.id
  }

}

