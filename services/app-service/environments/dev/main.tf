data "azurerm_resource_group" "platform" {
  name = var.resource_group_name
}

module "compute" {

  source              = "../../modules/compute"
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  allowed_cidrs       = var.allowed_cidrs
  plan_sku            = var.plan_sku
  environment         = "dev"
  unique_suffix       = substr(sha256("${var.subscription_id}/${var.resource_group_name}/${var.name}"), 0, 8)
  tags = {
    project = "azure-automated-pipeline", service = "app-service", environment = "dev", managed_by = "terraform"
  }


}

output "contract" {
  value = module.compute.contract
}

