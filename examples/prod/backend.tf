# Backend and provider for the engine's self-test project.
#
# The backend is partial on purpose: the resource group, storage account and
# container come from the TFPR_INIT_ARGS repository variable, which the engine
# appends to terraform init, so no tenant-specific name lives in this file.
# Authentication comes from the environment too (ARM_USE_OIDC and
# ARM_USE_AZUREAD on a runner, an Azure CLI login on a laptop), which is why
# neither block pins use_oidc.

terraform {
  required_version = ">= 1.9.0"

  backend "azurerm" {
    key              = "infra-prod.tfstate"
    use_azuread_auth = true
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}
