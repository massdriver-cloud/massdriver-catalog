terraform {
  required_version = ">= 1.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

variable "project_name" {
  type = string
}

resource "random_pet" "project" {
  keepers = {
    name = var.project_name
  }
}


resource "random_pet" "network" {
  keepers = {
    name = var.project_name
  }
}


resource "random_pet" "service_account" {
  keepers = {
    name = var.project_name
  }
}


locals {
  project_id         = random_pet.project.id
  network_id         = random_pet.network.id
  service_account_id = random_pet.service_account.id
}
