module "compute" {
  source                       = "../../modules/compute"
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  network_resource_group_name  = var.network_resource_group_name
  existing_vnet_name           = var.existing_vnet_name
  private_endpoint_subnet_name = var.private_endpoint_subnet_name
  data_principal_id            = var.data_principal_id
  replication_type             = var.replication_type
  environment                  = "prod"
  unique_suffix                = substr(sha256("${var.subscription_id}/${var.resource_group_name}/${var.name}"), 0, 8)
  tags                         = { project = "azure-automated-pipeline", service = "storage", environment = "prod", managed_by = "terraform" }
}
output "contract" { value = module.compute.contract }
