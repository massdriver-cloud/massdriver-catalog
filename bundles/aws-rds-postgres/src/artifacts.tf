resource "massdriver_artifact" "database" {
  field = "database"
  name  = "AWS RDS PostgreSQL ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    auth = {
      hostname        = aws_db_instance.main.address
      reader_endpoint = local.reader_endpoint != null ? local.reader_endpoint : aws_db_instance.main.address
      port            = tonumber(aws_db_instance.main.port)
      database        = aws_db_instance.main.db_name
      username        = aws_db_instance.main.username
      password        = local.use_master_pw ? var.master_password : random_password.master[0].result
    }
    id                = aws_db_instance.main.identifier
    arn               = aws_db_instance.main.arn
    region            = var.vpc.region
    version           = aws_db_instance.main.engine_version
    iam_auth_enabled  = var.iam_database_auth
    security_group_id = aws_security_group.db.id
    secret_arn        = aws_secretsmanager_secret.master.arn
    policies = [
      {
        id   = aws_iam_policy.read.arn
        name = "Read"
      },
      {
        id   = aws_iam_policy.write.arn
        name = "Write"
      },
      {
        id   = aws_iam_policy.admin.arn
        name = "Admin"
      },
    ]
  })
}
