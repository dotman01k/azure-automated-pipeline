data "azurerm_resource_group" "platform" {
  name = var.resource_group_name
}

module "compute" {

  source              = "../../modules/compute"
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  vm_size             = var.vm_size
  instances           = var.instances
  ssh_public_key      = var.ssh_public_key
  management_cidr     = var.management_cidr
  vnet_cidr           = var.vnet_cidr
  subnet_cidr         = var.subnet_cidr
  environment         = "dev"
  unique_suffix       = substr(sha256("${var.subscription_id}/${var.resource_group_name}/${var.name}"), 0, 8)
  tags = {
    project = "azure-automated-pipeline", service = "vm-scale-sets", environment = "dev", managed_by = "terraform"
  }


}

output "contract" {
  value = module.compute.contract
}

