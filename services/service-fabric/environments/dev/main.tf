module "compute" {

  source                        = "../../modules/compute"
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  vm_size                       = var.vm_size
  client_certificate_thumbprint = var.client_certificate_thumbprint
  node_count                    = var.node_count
  admin_password                = var.admin_password
  environment                   = "dev"
  unique_suffix                 = substr(sha256("${var.subscription_id}/${var.resource_group_name}/${var.name}"), 0, 8)
  tags = {
    project = "azure-automated-pipeline", service = "service-fabric", environment = "dev", managed_by = "terraform"
  }


}

output "contract" {
  value = module.compute.contract
}
