terraform {
  required_version = ">= 0.14.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.92.0"
    }
    random = {
      version = "~> 2.2.1"
    }
    checkpoint = {
      source  = "CheckPointSW/checkpoint"
      version = "~> 2.6.0"
    }
  }
}
