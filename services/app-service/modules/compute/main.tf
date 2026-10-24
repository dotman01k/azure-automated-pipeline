resource "azurerm_service_plan" "main" {

  name                = "${var.name}-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.plan_sku
  tags                = var.tags

}

resource "azurerm_linux_web_app" "main" {

  name                                           = "${var.name}-${var.unique_suffix}"
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  service_plan_id                                = azurerm_service_plan.main.id
  https_only                                     = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  identity {
    type = "SystemAssigned"
  }

  site_config {

    always_on               = true
    minimum_tls_version     = "1.2"
    scm_minimum_tls_version = "1.2"
    ftps_state              = "Disabled"
    health_check_path       = "/healthz"
    app_command_line        = "gunicorn --bind 0.0.0.0:8000 app:application"
    application_stack {
      python_version = "3.12"
    }

    ip_restriction_default_action = "Deny"
    scm_use_main_ip_restriction   = true
    dynamic "ip_restriction" {

      for_each = {
        for i, cidr in var.allowed_cidrs : i => cidr
      }

      content {
        name       = "trusted-${ip_restriction.key}"
        priority   = 100 + tonumber(ip_restriction.key)
        action     = "Allow"
        ip_address = ip_restriction.value
      }


    }


  }

  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }

  tags = var.tags

}

output "contract" {
  value = {
    id = azurerm_linux_web_app.main.id, app_name = azurerm_linux_web_app.main.name, url = "https://${azurerm_linux_web_app.main.default_hostname}"
  }

}

