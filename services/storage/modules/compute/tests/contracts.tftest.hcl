mock_provider "azurerm" {}
variables {
  name                         = "storetest"
  resource_group_name          = "rg-storage-tests"
  location                     = "eastus"
  environment                  = "dev"
  unique_suffix                = "12345678"
  tags                         = { test = "offline" }
  network_resource_group_name  = "rg-network-tests"
  existing_vnet_name           = "vnet-private"
  private_endpoint_subnet_name = "private-endpoints"
  data_principal_id            = "00000000-0000-0000-0000-000000000003"
  replication_type             = "LRS"
}
override_data {
  target = data.azurerm_virtual_network.existing
  values = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-network-tests/providers/Microsoft.Network/virtualNetworks/vnet-private" }
}
override_data {
  target = data.azurerm_subnet.endpoint
  values = { id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-network-tests/providers/Microsoft.Network/virtualNetworks/vnet-private/subnets/private-endpoints" }
}
run "private_identity_boundary" {
  command = plan
  assert {
    condition     = !azurerm_storage_account.main.public_network_access_enabled && !azurerm_storage_account.main.shared_access_key_enabled && !azurerm_storage_account.main.allow_nested_items_to_be_public
    error_message = "No public storage or shared key access."
  }
  assert {
    condition     = contains(azurerm_private_endpoint.blob.private_service_connection[0].subresource_names, "blob") && length(azurerm_private_endpoint.blob.private_service_connection[0].subresource_names) == 1
    error_message = "The private endpoint must target Blob."
  }
  assert {
    condition     = azurerm_storage_container.data.container_access_type == "private"
    error_message = "The container must remain private."
  }
}
run "recovery_contract" {
  command = plan
  assert {
    condition     = azurerm_storage_account.main.blob_properties[0].versioning_enabled && azurerm_storage_account.main.blob_properties[0].change_feed_enabled
    error_message = "Point in time recovery requires versioning and change feed."
  }
  assert {
    condition     = azurerm_storage_account.main.blob_properties[0].restore_policy[0].days < azurerm_storage_account.main.blob_properties[0].delete_retention_policy[0].days
    error_message = "Recovery must fit within soft-delete retention."
  }
}
run "unsupported_replication_rejected" {
  command = plan
  variables { replication_type = "INVALID" }
  expect_failures = [var.replication_type]
}
run "invalid_prefix_rejected" {
  command = plan
  variables { name = "INVALID_NAME" }
  expect_failures = [var.name]
}
