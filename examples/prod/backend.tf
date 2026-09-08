terraform {
  required_version = ">= 1.9.0"

  backend "azurerm" {
    use_oidc             = true
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatenrit"
    container_name       = "tfstate"
    key                  = "infra-prod.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  use_oidc = true
  features {}
}
