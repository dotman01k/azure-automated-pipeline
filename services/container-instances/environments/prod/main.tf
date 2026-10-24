data "azurerm_resource_group" "platform" {
  name = var.resource_group_name
}

module "compute" {

  source              = "../../modules/compute"
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  container_image     = var.container_image
  vnet_cidr           = var.vnet_cidr
  subnet_cidr         = var.subnet_cidr
  environment         = "prod"
  unique_suffix       = substr(sha256("${var.subscription_id}/${var.resource_group_name}/${var.name}"), 0, 8)
  tags = {
    project = "azure-automated-pipeline", service = "container-instances", environment = "prod", managed_by = "terraform"
  }


}

output "contract" {
  value = module.compute.contract
}

