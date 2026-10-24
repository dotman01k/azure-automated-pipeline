mock_provider "azurerm" {

}

variables {

  name                = "acitest"
  resource_group_name = "rg-compute-tests"
  location            = "eastus"
  environment         = "dev"
  unique_suffix       = "12345678"
  tags = {
    "test" : "offline"
  }

  container_image = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
  vnet_cidr       = "10.50.0.0/16"
  subnet_cidr     = "10.50.1.0/24"

}

run "security_contract" {

  command = plan
  assert {

    condition     = azurerm_container_group.main.ip_address_type == "Private"
    error_message = "Container group must have a private address."

  }

  assert {

    condition     = azurerm_container_group.main.os_type == "Linux"
    error_message = "VNet reference uses Linux containers."

  }

  assert {

    condition     = azurerm_container_group.main.restart_policy == "Always"
    error_message = "Keep the web container running."

  }


}

run "invalid_prefix_rejected" {

  command = plan
  variables {
    name = "INVALID_NAME"
  }

  expect_failures = [var.name]

}

