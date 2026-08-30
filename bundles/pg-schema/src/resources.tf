resource "massdriver_resource" "table_set" {
  field = "table_set"
  name  = "Postgres schema ${local.schema}"

  resource = jsonencode({
    schema = postgresql_schema.app.name

    auth = {
      hostname = var.postgres_cluster.auth.hostname
      port     = var.postgres_cluster.auth.port
      database = var.postgres_cluster.auth.database
      username = postgresql_role.app.name
      password = random_password.app.result
    }

    # Republished rather than passed through untouched: what the app receives is
    # the set of grants that actually exist in the database, so a reader can trust
    # the canvas instead of reading the params of a bundle two hops away.
    shared_tables = [
      for key, t in local.shared_by_key : {
        schema = t.schema
        table  = t.table
        access = t.access
      }
    ]
  })
}
