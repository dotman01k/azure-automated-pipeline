data "azurerm_virtual_network" "existing" {
  name                = var.existing_vnet_name
  resource_group_name = var.network_resource_group_name
}
data "azurerm_subnet" "endpoint" {
  name                 = var.private_endpoint_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.network_resource_group_name
}
resource "azurerm_storage_account" "main" {
  name                              = "${replace(var.name, "-", "")}${var.unique_suffix}"
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = var.replication_type
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = false
  infrastructure_encryption_enabled = true
  blob_properties {
    versioning_enabled            = true
    change_feed_enabled           = true
    change_feed_retention_in_days = 30
    delete_retention_policy { days = 30 }
    container_delete_retention_policy { days = 14 }
    restore_policy { days = 7 }
  }
  tags = var.tags
  lifecycle { prevent_destroy = true }
}
resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
  lifecycle { prevent_destroy = true }
}
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${var.name}-blob-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = data.azurerm_virtual_network.existing.id
  registration_enabled  = false
  tags                  = var.tags
}
resource "azurerm_private_endpoint" "blob" {
  name                = "${var.name}-blob-pe"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = data.azurerm_subnet.endpoint.id
  private_service_connection {
    name                           = "blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
  tags = var.tags
}
resource "azurerm_role_assignment" "data" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.data_principal_id
}
resource "azurerm_storage_management_policy" "main" {
  storage_account_id = azurerm_storage_account.main.id
  rule {
    name    = "cool-data-after-30-days"
    enabled = true
    filters {
      prefix_match = ["data/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob { tier_to_cool_after_days_since_modification_greater_than = 30 }
    }
  }
}
output "contract" {
  value = {
    account_name         = azurerm_storage_account.main.name
    container_name       = azurerm_storage_container.data.name
    blob_endpoint        = azurerm_storage_account.main.primary_blob_endpoint
    private_endpoint_id  = azurerm_private_endpoint.blob.id
    recovery_window_days = 7
  }
}
