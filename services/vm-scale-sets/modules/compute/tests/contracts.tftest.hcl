mock_provider "azurerm" {

}

variables {

  name                = "vmsstest"
  resource_group_name = "rg-compute-tests"
  location            = "eastus"
  environment         = "dev"
  unique_suffix       = "12345678"
  tags = {
    "test" : "offline"
  }

  vm_size         = "Standard_D2s_v3"
  instances       = 2
  ssh_public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Kc6rgmAdrQjuBywrOByjtJs7QLG8r3YD6347fU0XLrw6rpwtVZ3zUKV7Gz7mno9bx1XzCiidQ7BImbyAFgUf9V3kvMfTvkQ9yImDdRCytmVG7L6FF1+hKSN24TCoDfBBGdUhspajJ5iFNKhyQlX+6iW8H1115p2kU/p+E6mNAuERFVmWHtueNGFKvJYfYqi8Zay1Thgqg9k+drzTfN5ezWln36bUDF4E1yVikzOOj58+4GElveoUtiyY2/YnzCmi3LL4qFEvyhDdufQnxuUBq0XYN7ACu8293H0BBSP1sbBxkIBl1di7maACp0eB+sEdQSN51FSOYew1e1FQ9YzD offline-example"
  management_cidr = "10.90.0.0/16"
  vnet_cidr       = "10.40.0.0/16"
  subnet_cidr     = "10.40.1.0/24"

}

run "security_contract" {

  command = plan
  assert {

    condition     = azurerm_linux_virtual_machine_scale_set.main.disable_password_authentication
    error_message = "SSH password authentication must remain disabled."

  }

  assert {

    condition     = azurerm_lb.main.sku == "Standard"
    error_message = "Internal load balancer must use Standard SKU."

  }


}

run "invalid_prefix_rejected" {

  command = plan
  variables {
    name = "INVALID_NAME"
  }

  expect_failures = [var.name]

}

