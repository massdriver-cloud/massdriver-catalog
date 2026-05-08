# IAM policies surfaced via the artifact's `policies` array. Bind one to a
# workload's IAM role to grant DB access without sharing the master password.

locals {
  db_resource_root = "arn:aws:rds-db:${var.vpc.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.main.resource_id}"
}

data "aws_iam_policy_document" "iam_auth_read" {
  statement {
    sid       = "ConnectAsAppReader"
    actions   = ["rds-db:connect"]
    resources = ["${local.db_resource_root}/app_reader"]
  }
  statement {
    sid       = "ReadSecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.master.arn]
  }
}

data "aws_iam_policy_document" "iam_auth_write" {
  source_policy_documents = [data.aws_iam_policy_document.iam_auth_read.json]
  statement {
    sid       = "ConnectAsAppWriter"
    actions   = ["rds-db:connect"]
    resources = ["${local.db_resource_root}/app_writer"]
  }
}

data "aws_iam_policy_document" "iam_auth_admin" {
  source_policy_documents = [data.aws_iam_policy_document.iam_auth_write.json]
  statement {
    sid       = "ConnectAsMaster"
    actions   = ["rds-db:connect"]
    resources = ["${local.db_resource_root}/${aws_db_instance.main.username}"]
  }
}

resource "aws_iam_policy" "read" {
  name        = "${local.identifier}-read"
  description = "Connect as the app_reader Postgres role on ${local.identifier}"
  policy      = data.aws_iam_policy_document.iam_auth_read.json
}

resource "aws_iam_policy" "write" {
  name        = "${local.identifier}-write"
  description = "Connect as the app_writer Postgres role on ${local.identifier}"
  policy      = data.aws_iam_policy_document.iam_auth_write.json
}

resource "aws_iam_policy" "admin" {
  name        = "${local.identifier}-admin"
  description = "Connect as the master account on ${local.identifier}"
  policy      = data.aws_iam_policy_document.iam_auth_admin.json
}
