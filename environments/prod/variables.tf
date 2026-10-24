variable "subscription_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "Supply the target subscription GUID."
  }
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name" { type = string }
variable "computer_name" { type = string }
variable "vm_size" { type = string }
variable "vnet_cidr" { type = string }
variable "workload_cidr" { type = string }
variable "bastion_cidr" { type = string }
variable "admin_username" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "os_disk_size_gb" { type = number }
variable "install_iis" { type = bool }
