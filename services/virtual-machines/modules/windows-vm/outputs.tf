output "vm_id" { value = azurerm_windows_virtual_machine.main.id }
output "private_ip" { value = azurerm_network_interface.main.private_ip_address }
output "bastion_id" { value = azurerm_bastion_host.main.id }
output "vm_identity_principal_id" { value = azurerm_windows_virtual_machine.main.identity[0].principal_id }
