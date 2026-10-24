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

variable "container_image" {

  type = string

}

variable "vnet_cidr" {

  type = string

}

variable "subnet_cidr" {

  type = string

}

