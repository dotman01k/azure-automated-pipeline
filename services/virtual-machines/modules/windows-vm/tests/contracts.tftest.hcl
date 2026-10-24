mock_provider "azurerm" {}
variables {
  name                = "platform-dev"
  computer_name       = "windev01"
  resource_group_name = "rg-platform-vm-dev-eastus"
  location            = "eastus"
  vm_size             = "Standard_D2s_v3"
  vnet_cidr           = "10.30.0.0/16"
  workload_cidr       = "10.30.1.0/24"
  bastion_cidr        = "10.30.0.0/26"
  admin_password      = "Offline-Only-Not-A-Real-Credential-42!"
  install_iis         = true
  tags                = { environment = "test" }
}
run "private_windows_and_bastion" {
  command = plan
  assert {
    condition     = one(azurerm_network_interface.main.ip_configuration).public_ip_address_id == null
    error_message = "The Windows NIC must not have a public IP."
  }
  assert {
    condition     = azurerm_subnet.bastion.name == "AzureBastionSubnet" && azurerm_bastion_host.main.sku == "Basic"
    error_message = "Bastion must use its dedicated subnet."
  }
  assert {
    condition     = length([for r in azurerm_network_security_group.workload.security_rule : r if r.destination_port_range == "3389" && r.source_address_prefix == var.bastion_cidr && r.access == "Allow"]) == 1
    error_message = "Allow RDP from the Bastion subnet only."
  }
  assert {
    condition     = azurerm_windows_virtual_machine.main.secure_boot_enabled && azurerm_windows_virtual_machine.main.vtpm_enabled
    error_message = "Trusted Launch settings must remain enabled."
  }
}
run "iis_optional" {
  command = plan
  variables { install_iis = false }
  assert {
    condition     = length(azurerm_virtual_machine_extension.iis) == 0
    error_message = "Disabled IIS must not deploy an extension."
  }
}
run "short_password_rejected" {
  command = plan
  variables { admin_password = "short" }
  expect_failures = [var.admin_password]
}
run "long_computer_name_rejected" {
  command = plan
  variables { computer_name = "this-name-is-too-long" }
  expect_failures = [var.computer_name]
}
