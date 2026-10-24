resource "azurerm_virtual_network" "main" {

  name                = "${var.name}-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.vnet_cidr]
  tags                = var.tags

}

resource "azurerm_subnet" "main" {

  name                 = "nodes"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]

}

resource "azurerm_public_ip" "egress" {

  name                = "${var.name}-egress"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags

}

resource "azurerm_nat_gateway" "main" {

  name                = "${var.name}-nat"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "Standard"
  tags                = var.tags

}

resource "azurerm_nat_gateway_public_ip_association" "main" {

  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.egress.id

}

resource "azurerm_subnet_nat_gateway_association" "main" {

  subnet_id      = azurerm_subnet.main.id
  nat_gateway_id = azurerm_nat_gateway.main.id
  depends_on     = [azurerm_nat_gateway_public_ip_association.main]

}

resource "azurerm_user_assigned_identity" "main" {

  name                = "${var.name}-controlplane"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

}

resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "${var.name}-kubelet"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "kubelet_operator" {
  scope                = azurerm_user_assigned_identity.kubelet.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_role_assignment" "network" {

  scope                = azurerm_virtual_network.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id

}

resource "azurerm_container_registry" "main" {

  name                = "${replace(var.name, "-", "")}${var.unique_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags

}

resource "azurerm_kubernetes_cluster" "main" {

  name                              = "${var.name}-cluster"
  resource_group_name               = var.resource_group_name
  location                          = var.location
  dns_prefix                        = var.name
  local_account_disabled            = true
  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  sku_tier                          = "Free"
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  azure_active_directory_role_based_access_control {

    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = var.admin_group_ids
    azure_rbac_enabled     = true

  }

  api_server_access_profile {
    authorized_ip_ranges = distinct(concat(var.allowed_cidrs, ["${azurerm_public_ip.egress.ip_address}/32"]))
  }

  default_node_pool {

    name                         = "system"
    vm_size                      = var.vm_size
    node_count                   = 2
    vnet_subnet_id               = azurerm_subnet.main.id
    only_critical_addons_enabled = true
    upgrade_settings {
      max_surge = "33%"
    }


  }

  network_profile {

    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.240.0.0/16"
    dns_service_ip      = "10.240.0.10"
    outbound_type       = "userAssignedNATGateway"
    load_balancer_sku   = "standard"

  }

  tags       = var.tags
  depends_on = [azurerm_role_assignment.network, azurerm_role_assignment.kubelet_operator, azurerm_subnet_nat_gateway_association.main]

}



resource "azurerm_kubernetes_cluster_node_pool" "apps" {

  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.vm_size
  vnet_subnet_id        = azurerm_subnet.main.id
  mode                  = "User"
  node_count            = 1
  tags                  = var.tags

}

resource "azurerm_role_assignment" "pull" {

  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.kubelet.principal_id

}

output "contract" {
  value = {
    id = azurerm_kubernetes_cluster.main.id, cluster_name = azurerm_kubernetes_cluster.main.name, acr_name = azurerm_container_registry.main.name, egress_ip = azurerm_public_ip.egress.ip_address
  }

}
