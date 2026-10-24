variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,11}$", var.name))
    error_message = "Use a 3..12 character lowercase prefix."
  }
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "network_resource_group_name" { type = string }
variable "existing_vnet_name" { type = string }
variable "private_endpoint_subnet_name" { type = string }
variable "data_principal_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.data_principal_id))
    error_message = "Use an Entra principal object ID, not an application/client ID."
  }
}
variable "replication_type" {
  type = string
  validation {
    condition     = contains(["LRS", "ZRS"], var.replication_type)
    error_message = "This reference supports reviewed LRS or ZRS replication."
  }
}
variable "environment" { type = string }
variable "unique_suffix" { type = string }
variable "tags" { type = map(string) }
