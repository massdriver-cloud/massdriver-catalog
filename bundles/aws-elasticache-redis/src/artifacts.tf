resource "massdriver_artifact" "redis" {
  field = "redis"
  name  = "Redis - ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    auth = {
      hostname   = aws_elasticache_replication_group.main.primary_endpoint_address
      port       = var.port
      auth_token = local.auth_token_enabled ? random_password.auth_token[0].result : null
    }
    id                = aws_elasticache_replication_group.main.id
    security_group_id = aws_security_group.redis.id
    policies = [
      {
        id   = "read-write"
        name = "Read/Write"
      }
    ]
  })
}
