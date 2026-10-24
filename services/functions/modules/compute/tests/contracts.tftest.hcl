mock_provider "azurerm" {

}

variables {

  name                = "functest"
  resource_group_name = "rg-compute-tests"
  location            = "eastus"
  environment         = "dev"
  unique_suffix       = "12345678"
  tags = {
    "test" : "offline"
  }

  allowed_cidrs     = ["192.0.2.10/32"]
  maximum_instances = 40

}

run "security_contract" {

  command = plan
  assert {

    condition     = azurerm_service_plan.main.sku_name == "FC1"
    error_message = "Use Flex Consumption, not legacy Linux Consumption."

  }

  assert {

    condition     = azurerm_function_app_flex_consumption.main.storage_authentication_type == "UserAssignedIdentity"
    error_message = "Deployment storage must use managed identity."

  }

  assert {

    condition     = !azurerm_storage_account.main.shared_access_key_enabled
    error_message = "Storage shared keys must remain disabled."

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

