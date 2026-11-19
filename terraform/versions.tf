terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      # Lets `terraform destroy` remove the group even if extensions left extra resources behind.
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
}
