resource "azurerm_service_fabric_managed_cluster" "main" {

  name                   = "${var.name}-${var.unique_suffix}"
  resource_group_name    = var.resource_group_name
  location               = var.location
  dns_name               = "${var.name}-${var.unique_suffix}"
  sku                    = var.environment == "prod" ? "Standard" : "Basic"
  username               = "platformadmin"
  password               = var.admin_password
  client_connection_port = 19000
  http_gateway_port      = 19080
  authentication {

    certificate {
      thumbprint = var.client_certificate_thumbprint
      type       = "AdminClient"
    }


  }

  lb_rule {

    frontend_port  = 443
    backend_port   = 8443
    protocol       = "tcp"
    probe_protocol = "tcp"

  }

  node_type {

    name                   = "primary"
    primary                = true
    vm_size                = var.vm_size
    vm_instance_count      = var.node_count
    data_disk_size_gb      = 128
    data_disk_type         = "StandardSSD_LRS"
    application_port_range = "20000-30000"
    ephemeral_port_range   = "49152-65534"
    vm_image_publisher     = "MicrosoftWindowsServer"
    vm_image_offer         = "WindowsServer"
    vm_image_sku           = "2022-datacenter-azure-edition"
    vm_image_version       = "latest"

  }

  tags = var.tags
  lifecycle {

    prevent_destroy = true
    precondition {

      condition     = var.node_count >= (var.environment == "prod" ? 5 : 3)
      error_message = "Basic requires at least 3 primary nodes; Standard requires at least 5."

    }


  }


}

output "contract" {
  value = {
    id = azurerm_service_fabric_managed_cluster.main.id, management_host_hint = "${var.name}-${var.unique_suffix}.${var.location}.cloudapp.azure.com", client_port = 19000, explorer_port = 19080
  }

}

