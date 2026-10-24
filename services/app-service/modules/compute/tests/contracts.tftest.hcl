mock_provider "azurerm" {

}

variables {

  name                = "webtest"
  resource_group_name = "rg-compute-tests"
  location            = "eastus"
  environment         = "dev"
  unique_suffix       = "12345678"
  tags = {
    "test" : "offline"
  }

  allowed_cidrs = ["192.0.2.10/32"]
  plan_sku      = "B1"

}

run "security_contract" {

  command = plan
  assert {

    condition     = azurerm_linux_web_app.main.https_only
    error_message = "HTTPS must be enforced."

  }

  assert {

    condition     = !azurerm_linux_web_app.main.webdeploy_publish_basic_authentication_enabled
    error_message = "Publishing basic auth must remain disabled."

  }

  assert {

    condition     = azurerm_linux_web_app.main.site_config[0].ip_restriction_default_action == "Deny"
    error_message = "Unlisted clients must be denied."

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

