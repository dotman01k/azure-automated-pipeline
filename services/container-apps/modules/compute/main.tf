resource "azurerm_virtual_network" "main" {

  name                = "${var.name}-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags

}

resource "azurerm_subnet" "main" {

  name                 = "container-apps"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
  delegation {
    name = "container-apps"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }

  }


}

resource "azurerm_log_analytics_workspace" "main" {

  name                = "${var.name}-logs"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1
  tags                = var.tags

}

resource "azurerm_container_app_environment" "main" {

  name                           = "${var.name}-environment"
  resource_group_name            = var.resource_group_name
  location                       = var.location
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id       = azurerm_subnet.main.id
  internal_load_balancer_enabled = true
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = var.tags

}

resource "azurerm_private_dns_zone" "main" {

  name                = azurerm_container_app_environment.main.default_domain
  resource_group_name = var.resource_group_name
  tags                = var.tags

}

resource "azurerm_private_dns_zone_virtual_network_link" "main" {

  name                  = "environment"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

}

resource "azurerm_private_dns_a_record" "main" {

  name                = "*"
  zone_name           = azurerm_private_dns_zone.main.name
  resource_group_name = var.resource_group_name
  ttl                 = 30
  records             = [azurerm_container_app_environment.main.static_ip_address]

}

resource "azurerm_container_app" "main" {

  name                         = "${var.name}-app"
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"
  identity {
    type = "SystemAssigned"
  }

  ingress {

    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 80
    transport                  = "auto"
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }


  }

  template {

    min_replicas = 0
    max_replicas = 3
    container {

      name   = "web"
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"
      readiness_probe {
        transport = "HTTP"
        port      = 80
        path      = "/"
      }


    }

    http_scale_rule {
      name                = "http"
      concurrent_requests = "20"
    }


  }

  tags = var.tags

}

output "contract" {
  value = {
    id = azurerm_container_app.main.id, private_url = "https://${azurerm_container_app.main.ingress[0].fqdn}", private_environment_ip = azurerm_container_app_environment.main.static_ip_address
  }

}

