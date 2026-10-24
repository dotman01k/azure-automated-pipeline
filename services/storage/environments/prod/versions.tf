terraform {

  required_version = "= 1.13.0"
  backend "azurerm" {

  }

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm", version = "= 4.68.0"
    }

  }


}

provider "azurerm" {

  features {
    storage {
      data_plane_available = false
    }
  }

  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  storage_use_azuread             = true

}

