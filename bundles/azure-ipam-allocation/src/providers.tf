terraform {
  required_version = ">= 1.8"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 2.0"
    }
  }
}
