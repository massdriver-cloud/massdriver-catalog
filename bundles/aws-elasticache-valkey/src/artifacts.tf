resource "massdriver_resource" "cache" {
  field = "cache"
  name  = "Valkey Cache (${var.md_metadata.name_prefix})"
  resource = jsonencode({
    id          = aws_elasticache_replication_group.main.id
    engine      = "valkey"
    version     = var.engine_version
    tls_enabled = true
    region      = var.network.region
    auth = {
      hostname = aws_elasticache_replication_group.main.primary_endpoint_address
      port     = 6379
      password = random_password.auth_token.result
    }
  })
}
