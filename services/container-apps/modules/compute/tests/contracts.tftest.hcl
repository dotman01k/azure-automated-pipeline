mock_provider "azurerm" {

}

variables {

  name                = "acatest"
  resource_group_name = "rg-compute-tests"
  location            = "eastus"
  environment         = "dev"
  unique_suffix       = "12345678"
  tags = {
    "test" : "offline"
  }

  container_image = "mcr.microsoft.com/k8se/quickstart:latest"
  vnet_cidr       = "10.48.0.0/16"
  subnet_cidr     = "10.48.2.0/23"

}

run "security_contract" {

  command = plan
  assert {

    condition     = azurerm_container_app_environment.main.internal_load_balancer_enabled
    error_message = "The environment must use an internal load balancer."

  }

  assert {

    condition     = !azurerm_container_app.main.ingress[0].allow_insecure_connections
    error_message = "Require TLS ingress."

  }

  assert {

    condition     = azurerm_container_app.main.template[0].max_replicas == 3
    error_message = "Bound scale out."

  }


}

run "invalid_prefix_rejected" {

  command = plan
  variables {
    name = "INVALID_NAME"
  }

  expect_failures = [var.name]

}

