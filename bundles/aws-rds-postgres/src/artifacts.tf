resource "massdriver_artifact" "database" {
  field = "database"
  name  = "AWS RDS PostgreSQL ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id     = aws_db_instance.main.id
    arn    = aws_db_instance.main.arn
    region = var.vpc.region
    auth = {
      hostname = aws_db_instance.main.address
      port     = aws_db_instance.main.port
      database = var.database_name
      username = var.username
      password = random_password.master.result
    }
    policies = [
      {
        id   = "vpc-access"
        name = "VPC Access (${var.vpc.cidr})"
      }
    ]
  })
}
