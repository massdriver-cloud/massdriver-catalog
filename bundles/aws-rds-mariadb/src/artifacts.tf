resource "massdriver_artifact" "writer" {
  field = "writer"
  name  = "MariaDB Writer - ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    auth = {
      hostname = local.writer_hostname
      port     = 3306
      database = var.database_name
      username = var.username
      password = random_password.master.result
    }
    id                  = aws_db_instance.main.id
    security_group_id   = aws_security_group.rds.id
    secrets_manager_arn = aws_secretsmanager_secret.master_credentials.arn
    policies = [
      {
        id   = "read-write"
        name = "Read/Write"
      },
      {
        id   = "admin"
        name = "Admin"
      }
    ]
  })
}

resource "massdriver_artifact" "reader" {
  field = "reader"
  name  = "MariaDB Reader - ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    auth = {
      hostname = local.reader_hostname
      port     = 3306
      database = var.database_name
      username = var.username
      password = random_password.master.result
    }
    id                  = var.multi_az ? aws_db_instance.reader[0].id : aws_db_instance.main.id
    security_group_id   = aws_security_group.rds.id
    secrets_manager_arn = aws_secretsmanager_secret.master_credentials.arn
    policies = [
      {
        id   = "read-only"
        name = "Read Only"
      }
    ]
  })
}
