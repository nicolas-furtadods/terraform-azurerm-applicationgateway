terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.21.0"
    }
  }
}

data "azurerm_client_config" "current" {
}

provider "azurerm" {
  features {}
  alias           = "transversal"
  subscription_id = var.transversal_key_vault_subscription_id
}
