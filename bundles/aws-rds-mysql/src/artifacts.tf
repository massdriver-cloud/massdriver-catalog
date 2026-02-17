resource "massdriver_artifact" "database" {
  field = "database"
  name  = "AWS RDS MySQL ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id = aws_db_instance.main.id
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
