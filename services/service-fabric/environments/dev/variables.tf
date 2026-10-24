variable "name" {

  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,11}$", var.name))
    error_message = "Use a 3..12 character lowercase prefix."
  }


}

variable "resource_group_name" {

  type = string

}

variable "location" {

  type = string

}

variable "vm_size" {

  type = string

}

variable "client_certificate_thumbprint" {

  type = string
  validation {
    condition     = can(regex("^[A-Fa-f0-9]{40}$", var.client_certificate_thumbprint))
    error_message = "Supply a 40 character certificate thumbprint."
  }


}

variable "node_count" {

  type = number

}

variable "admin_password" {

  type      = string
  sensitive = true
  validation {
    condition     = length(var.admin_password) >= 16 && length(var.admin_password) <= 72
    error_message = "Supply a 16..72 character complex secret password."
  }


}

variable "subscription_id" {

  type = string

}

