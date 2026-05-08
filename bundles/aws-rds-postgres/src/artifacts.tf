resource "massdriver_artifact" "database" {
  field = "database"
  name  = "AWS RDS PostgreSQL ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    auth = {
      hostname        = local.endpoint_host
      reader_endpoint = local.reader_host
      port            = 5432
      database        = var.database_name
      username        = var.username
      password        = local.password
    }
    id                = local.instance_id
    arn               = local.cluster_arn
    region            = var.vpc.region
    version           = var.engine_version
    iam_auth_enabled  = var.iam_database_auth
    security_group_id = "sg-${substr(md5("${random_pet.db.id}-rds"), 0, 17)}"
    secret_arn        = local.secret_arn
    policies          = local.policies
  })
}
