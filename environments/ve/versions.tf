terraform {
  required_version = "~> 1.14"
  required_providers {
    azurerm = {
      # Reference | https://registry.terraform.io/providers/hashicorp/azurerm/latest
      source  = "hashicorp/azurerm"
      version = "~> 4.59.0"
    }
  }
}
