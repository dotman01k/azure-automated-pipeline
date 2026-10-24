mock_provider "azurerm" {

}

variables {

  name                = "akstest"
  resource_group_name = "rg-compute-tests"
  location            = "eastus"
  environment         = "dev"
  unique_suffix       = "12345678"
  tags = {
    "test" : "offline"
  }

  vm_size         = "Standard_D4s_v3"
  allowed_cidrs   = ["192.0.2.10/32"]
  admin_group_ids = ["00000000-0000-0000-0000-000000000003"]
  vnet_cidr       = "10.46.0.0/16"
  subnet_cidr     = "10.46.1.0/24"

}

run "security_contract" {

  command = plan
  assert {

    condition     = azurerm_kubernetes_cluster.main.local_account_disabled
    error_message = "Local cluster admin credentials must stay disabled."

  }

  assert {

    condition     = azurerm_kubernetes_cluster.main.workload_identity_enabled
    error_message = "Enable workload identity."

  }

  assert {

    condition     = !azurerm_container_registry.main.admin_enabled
    error_message = "Registry administrator account must stay disabled."

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


override_data {
  target = data.azurerm_client_config.current
  values = { tenant_id = "00000000-0000-0000-0000-000000000002" }
}

