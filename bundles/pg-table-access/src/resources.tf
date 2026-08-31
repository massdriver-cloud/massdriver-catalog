resource "massdriver_resource" "grants" {
  field = "grants"
  name  = "Postgres login ${var.login_name}"

  resource = jsonencode({
    auth = {
      # The private address, the same one every application uses. The management
      # address exists for this bundle's own connection and is not passed on.
      hostname = var.postgres_cluster.auth.hostname
      port     = var.postgres_cluster.auth.port
      database = var.postgres_cluster.auth.database
      username = postgresql_role.login.name
      password = random_password.login.result
    }

    # The grants that actually exist, not the ones that were asked for. A reader can
    # trust the canvas without going and checking the database.
    read       = [for k, t in local.granted : k if t.access == "read"]
    read_write = [for k, t in local.granted : k if t.access == "read_write"]
  })
}
