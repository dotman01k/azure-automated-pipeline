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

variable "environment" {

  type = string

}

variable "unique_suffix" {

  type = string

}

variable "tags" {

  type = map(string)

}

variable "vm_size" {

  type = string

}

variable "node_count" {

  type = number

}

variable "allowed_cidrs" {
  validation {
    condition     = alltrue([for c in var.allowed_cidrs : !endswith(c, "/31")])
    error_message = "The pinned Batch API/provider accepts single hosts or prefixes up to /30; /32 is converted to a host address."
  }

  type = list(string)
  validation {
    condition     = length(var.allowed_cidrs) > 0 && alltrue([for c in var.allowed_cidrs : can(cidrnetmask(c)) && c != "0.0.0.0/0"])
    error_message = "Supply explicit IPv4 CIDRs, never all internet."
  }


}

variable "vnet_cidr" {

  type = string

}

variable "subnet_cidr" {

  type = string

}

