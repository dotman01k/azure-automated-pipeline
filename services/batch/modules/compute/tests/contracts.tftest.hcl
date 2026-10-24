mock_provider "azurerm" {

}

variables {

  name                = "batchtest"
  resource_group_name = "rg-compute-tests"
  location            = "eastus"
  environment         = "dev"
  unique_suffix       = "12345678"
  tags = {
    "test" : "offline"
  }

  vm_size       = "Standard_D2s_v3"
  node_count    = 0
  allowed_cidrs = ["192.0.2.10/32"]
  vnet_cidr     = "10.54.0.0/16"
  subnet_cidr   = "10.54.1.0/24"

}

run "security_contract" {

  command = plan
  assert {

    condition     = !contains(azurerm_batch_account.main.allowed_authentication_modes, "SharedKey")
    error_message = "Batch account shared key authentication must stay disabled."

  }

  assert {

    condition     = azurerm_batch_pool.main.network_configuration[0].public_address_provisioning_type == "NoPublicIPAddresses"
    error_message = "Batch nodes must not have public IPs."

  }

  assert {

    condition     = azurerm_batch_pool.main.fixed_scale[0].target_dedicated_nodes == var.node_count
    error_message = "Respect explicit worker count."

  }


}

run "invalid_prefix_rejected" {

  command = plan
  variables {
    name = "INVALID_NAME"
  }

  expect_failures = [var.name]

}

run "internet_wide_access_rejected" {

  command = plan
  variables {
    allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.allowed_cidrs]

}

