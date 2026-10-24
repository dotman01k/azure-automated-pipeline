resource "azurerm_virtual_network" "main" {
  name                = "${var.name}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}
resource "azurerm_subnet" "workload" {
  name                 = "workload"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.workload_cidr]
}
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.bastion_cidr]
}
resource "azurerm_network_security_group" "workload" {
  name                = "${var.name}-workload-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  security_rule {
    name                       = "RDPFromBastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.bastion_cidr
    destination_address_prefix = var.workload_cidr
  }
  security_rule {
    name                       = "HTTPFromVNet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = var.workload_cidr
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
resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}
resource "azurerm_public_ip" "bastion" {
  name                = "${var.name}-bastion-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}
resource "azurerm_bastion_host" "main" {
  name                = "${var.name}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  ip_configuration {
    name                 = "bastion"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
  tags = var.tags
}
resource "azurerm_network_interface" "main" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = "private"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }
  tags       = var.tags
  depends_on = [azurerm_subnet_network_security_group_association.workload]
}
resource "azurerm_windows_virtual_machine" "main" {
  name                      = "${var.name}-vm"
  computer_name             = var.computer_name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  size                      = var.vm_size
  admin_username            = var.admin_username
  admin_password            = var.admin_password
  network_interface_ids     = [azurerm_network_interface.main.id]
  provision_vm_agent        = true
  automatic_updates_enabled = true
  patch_mode                = "AutomaticByPlatform"
  patch_assessment_mode     = "AutomaticByPlatform"
  secure_boot_enabled       = true
  vtpm_enabled              = true
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }
  boot_diagnostics {}
  identity { type = "SystemAssigned" }
  tags = var.tags
  lifecycle { prevent_destroy = true }
}
resource "azurerm_virtual_machine_extension" "iis" {
  count                      = var.install_iis ? 1 : 0
  name                       = "ConfigureIIS"
  virtual_machine_id         = azurerm_windows_virtual_machine.main.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(file("${path.module}/Configure-IIS.ps1"), "UTF-16LE")}"
  })
  tags = var.tags
}
