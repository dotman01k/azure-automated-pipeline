module "windows_vm" {
  source              = "../../modules/windows-vm"
  resource_group_name = data.azurerm_resource_group.platform.name
  location            = var.location
  name                = var.name
  computer_name       = var.computer_name
  vm_size             = var.vm_size
  vnet_cidr           = var.vnet_cidr
  workload_cidr       = var.workload_cidr
  bastion_cidr        = var.bastion_cidr
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  os_disk_size_gb     = var.os_disk_size_gb
  install_iis         = var.install_iis
  tags                = { project = "azure-automated-pipeline", environment = "prod", managed_by = "terraform" }
}
output "vm_id" { value = module.windows_vm.vm_id }
output "private_ip" { value = module.windows_vm.private_ip }
output "bastion_id" { value = module.windows_vm.bastion_id }
