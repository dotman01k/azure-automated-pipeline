mock_provider "azurerm" {

}

variables {

  name                = "sftest"
  resource_group_name = "rg-compute-tests"
  location            = "eastus"
  environment         = "dev"
  unique_suffix       = "12345678"
  tags = {
    "test" : "offline"
  }

  vm_size                       = "Standard_D4s_v3"
  client_certificate_thumbprint = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  node_count                    = 3
  admin_password                = "Offline-Test-Only-Password-42!"

}

run "security_contract" {

  command = plan
  assert {

    condition     = one(azurerm_service_fabric_managed_cluster.main.node_type).primary
    error_message = "A primary node type is required."

  }

  assert {

    condition     = one(azurerm_service_fabric_managed_cluster.main.node_type).vm_instance_count >= 3
    error_message = "Do not undersize the primary node type."

  }


}

run "invalid_prefix_rejected" {

  command = plan
  variables {
    name = "INVALID_NAME"
  }

  expect_failures = [var.name]

}

