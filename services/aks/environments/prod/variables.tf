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

variable "allowed_cidrs" {

  type = list(string)
  validation {
    condition     = length(var.allowed_cidrs) > 0 && alltrue([for c in var.allowed_cidrs : can(cidrnetmask(c)) && c != "0.0.0.0/0"])
    error_message = "Supply explicit IPv4 CIDRs, never all internet."
  }


}

variable "admin_group_ids" {

  type = list(string)

}

variable "vnet_cidr" {

  type = string

}

variable "subnet_cidr" {

  type = string

}

variable "subscription_id" {

  type = string

}

