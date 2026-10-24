mock_provider "azurerm" {

}

variables {

  name                = "avdtest"
  resource_group_name = "rg-compute-tests"
  location            = "eastus"
  environment         = "dev"
  unique_suffix       = "12345678"
  tags = {
    "test" : "offline"
  }

  vm_size              = "Standard_D4s_v3"
  user_group_object_id = "00000000-0000-0000-0000-000000000003"
  vnet_cidr            = "10.52.0.0/16"
  subnet_cidr          = "10.52.1.0/24"
  admin_password       = "Offline-Test-Only-Password-42!"

}

run "security_contract" {

  command = plan
  assert {

    condition     = azurerm_virtual_desktop_host_pool.main.type == "Pooled"
    error_message = "Use a pooled desktop host pool."

  }

  assert {

    condition     = one(azurerm_network_interface.main.ip_configuration).public_ip_address_id == null
    error_message = "Session host must not have a public IP."

  }

  assert {

    condition     = azurerm_windows_virtual_machine.main.identity[0].type == "SystemAssigned"
    error_message = "Entra join requires a VM identity."

  }


}

run "invalid_prefix_rejected" {

  command = plan
  variables {
    name = "INVALID_NAME"
  }

  expect_failures = [var.name]

}

