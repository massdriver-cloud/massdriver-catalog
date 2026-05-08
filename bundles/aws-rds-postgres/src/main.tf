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

resource "random_pet" "db" {
  length = 2
  keepers = {
    database_name  = var.database_name
    engine_version = var.engine_version
    instance_class = var.instance_class
    multi_az       = tostring(var.multi_az)
    vpc_id         = var.vpc.id
  }
}

resource "random_password" "master" {
  length  = 32
  special = false
}

locals {
  instance_id   = "rds-${random_pet.db.id}"
  cluster_arn   = "arn:aws:rds:${var.vpc.region}:${var.vpc.account_id}:db:${local.instance_id}"
  endpoint_host = "${local.instance_id}.${substr(md5(random_pet.db.id), 0, 12)}.${var.vpc.region}.rds.amazonaws.com"
  reader_host   = var.read_replica_count > 0 ? "${local.instance_id}-ro.${substr(md5(random_pet.db.id), 0, 12)}.${var.vpc.region}.rds.amazonaws.com" : null
  password      = var.master_password != null && var.master_password != "" ? var.master_password : random_password.master.result
  secret_arn    = "arn:aws:secretsmanager:${var.vpc.region}:${var.vpc.account_id}:secret:rds/${local.instance_id}-${substr(md5(random_pet.db.id), 0, 6)}"

  policies = [
    {
      id   = "arn:aws:iam::${var.vpc.account_id}:policy/${local.instance_id}-read"
      name = "Read"
    },
    {
      id   = "arn:aws:iam::${var.vpc.account_id}:policy/${local.instance_id}-write"
      name = "Write"
    },
    {
      id   = "arn:aws:iam::${var.vpc.account_id}:policy/${local.instance_id}-admin"
      name = "Admin"
    },
  ]
}
