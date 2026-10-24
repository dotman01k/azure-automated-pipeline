module "compute" {

  source              = "../../modules/compute"
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  vm_size             = var.vm_size
  allowed_cidrs       = var.allowed_cidrs
  admin_group_ids     = var.admin_group_ids
  vnet_cidr           = var.vnet_cidr
  subnet_cidr         = var.subnet_cidr
  environment         = "prod"
  unique_suffix       = substr(sha256("${var.subscription_id}/${var.resource_group_name}/${var.name}"), 0, 8)
  tags = {
    project = "azure-automated-pipeline", service = "aks", environment = "prod", managed_by = "terraform"
  }


}

output "contract" {
  value = module.compute.contract
}
