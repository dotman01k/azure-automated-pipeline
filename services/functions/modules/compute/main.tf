resource "azurerm_storage_account" "main" {

  name                            = "${replace(var.name, "-", "")}${var.unique_suffix}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  tags                            = var.tags

}

resource "azurerm_storage_container" "deployment" {

  name                  = "deployment"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"

}

resource "azurerm_user_assigned_identity" "main" {

  name                = "${var.name}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

}

resource "azurerm_role_assignment" "storage" {

  for_each             = toset(["Storage Blob Data Owner", "Storage Queue Data Contributor"])
  scope                = azurerm_storage_account.main.id
  role_definition_name = each.key
  principal_id         = azurerm_user_assigned_identity.main.principal_id

}

resource "azurerm_service_plan" "main" {

  name                = "${var.name}-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = var.tags

}

resource "azurerm_function_app_flex_consumption" "main" {

  name                                           = "${var.name}-${var.unique_suffix}"
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  service_plan_id                                = azurerm_service_plan.main.id
  storage_container_type                         = "blobContainer"
  storage_container_endpoint                     = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.deployment.name}"
  storage_authentication_type                    = "UserAssignedIdentity"
  storage_user_assigned_identity_id              = azurerm_user_assigned_identity.main.id
  runtime_name                                   = "python"
  runtime_version                                = "3.12"
  maximum_instance_count                         = var.maximum_instances
  instance_memory_in_mb                          = 2048
  https_only                                     = true
  webdeploy_publish_basic_authentication_enabled = false
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  app_settings = {

    AzureWebJobsStorage__accountName = azurerm_storage_account.main.name
    AzureWebJobsStorage__credential  = "managedidentity"
    AzureWebJobsStorage__clientId    = azurerm_user_assigned_identity.main.client_id

  }

  site_config {

    minimum_tls_version           = "1.2"
    scm_minimum_tls_version       = "1.2"
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

  tags       = var.tags
  depends_on = [azurerm_role_assignment.storage]

}

output "contract" {
  value = {
    id = azurerm_function_app_flex_consumption.main.id, app_name = azurerm_function_app_flex_consumption.main.name, url = "https://${azurerm_function_app_flex_consumption.main.default_hostname}/api/hello"
  }

}

