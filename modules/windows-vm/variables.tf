variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "Use a 3..20 character lowercase resource prefix."
  }
}
variable "computer_name" {
  type = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,14}$", var.computer_name))
    error_message = "Windows computer name must start with a letter and be at most 15 characters."
  }
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vm_size" { type = string }
variable "vnet_cidr" { type = string }
variable "workload_cidr" { type = string }
variable "bastion_cidr" { type = string }
variable "admin_username" {
  type    = string
  default = "platformadmin"
}
variable "admin_password" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.admin_password) >= 16 && length(var.admin_password) <= 72
    error_message = "Supply a 16..72 character complex password through a secret variable."
  }
}
variable "os_disk_size_gb" {
  type    = number
  default = 128
  validation {
    condition     = var.os_disk_size_gb >= 128 && var.os_disk_size_gb <= 1024 && floor(var.os_disk_size_gb) == var.os_disk_size_gb
    error_message = "OS disk must be an integer from 128 through 1024 GiB."
  }
}
variable "install_iis" { type = bool }
variable "tags" { type = map(string) }
